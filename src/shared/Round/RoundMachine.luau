--!strict
-- Pure round state machine (GDD 03.2, 03.5, 03.6). Time is injected so tests can simulate a whole round instantly.
-- Only RoundService drives an instance of this machine; nothing else may change round state.
--
-- Waiting -> Countdown -> Loading -> Intro -> Live -> Results -> Reset -> Intermission -> Countdown
-- Live <-> VacancyPause is the only pause path. Loading failure/timeout returns to Waiting.
--
-- Real time drives countdowns, intro, results, intermission and the vacancy grace. The match clock drives Live:
-- while paused, RoundEndTime is shifted forward by the actual paused duration on resumption.

local RoundMachine = {}
RoundMachine.__index = RoundMachine

export type State = "Waiting" | "Countdown" | "Loading" | "Intro" | "Live" | "VacancyPause" | "Results" | "Reset" | "Intermission"

export type Facts = {
	readyCount: number,
	teamA: number, -- players currently on team A (live match)
	teamB: number,
	loadDone: boolean?,
	loadFailed: boolean?,
	resetDone: boolean?,
}

export type Event = {
	kind: "Transition" | "CountdownShortened" | "CountdownCanceled" | "DeadlineShifted" | "NoContest" | "FinalCue",
	from: State?,
	to: State?,
	reason: string?,
	matchId: number?,
}

export type Settings = {
	MinimumReady: number,
	Capacity: number,
	CountdownSeconds: number,
	FullLobbyCountdownSeconds: number,
	LoadingTimeoutSeconds: number,
	IntroSeconds: number,
	LiveSeconds: number,
	ResultsSeconds: number,
	IntermissionSeconds: number,
	VacancyGraceSeconds: number,
	FinalCueSeconds: number,
}

export type Machine = typeof(setmetatable(
	{} :: {
		settings: Settings,
		state: State,
		enteredAt: number,
		deadline: number?, -- real-time deadline of timed non-live states
		roundEndTime: number?, -- authoritative live deadline (shifted by pauses)
		pauseStartedAt: number?,
		graceEnd: number?,
		matchId: number,
		outcome: string?, -- "Completed" | "NoContest"
		finalCueSent: boolean,
		countdownShortened: boolean,
	},
	RoundMachine
))

function RoundMachine.new(settings: Settings, now: number): Machine
	return setmetatable({
		settings = settings,
		state = "Waiting" :: State,
		enteredAt = now,
		deadline = nil,
		roundEndTime = nil,
		pauseStartedAt = nil,
		graceEnd = nil,
		matchId = 0,
		outcome = nil,
		finalCueSent = false,
		countdownShortened = false,
	}, RoundMachine)
end

local function go(self: Machine, to: State, now: number, events: { Event }, reason: string?)
	local from = self.state
	self.state = to
	self.enteredAt = now
	self.deadline = nil
	table.insert(events, { kind = "Transition", from = from, to = to, reason = reason, matchId = self.matchId })
end

-- Remaining live seconds by the match clock (frozen during VacancyPause).
function RoundMachine.remainingLive(self: Machine, now: number): number?
	if self.state == "Live" and self.roundEndTime then
		return math.max(0, self.roundEndTime - now)
	elseif self.state == "VacancyPause" and self.roundEndTime and self.pauseStartedAt then
		return math.max(0, self.roundEndTime - self.pauseStartedAt)
	end
	return nil
end

function RoundMachine.isCombatActive(self: Machine): boolean
	return self.state == "Live"
end

-- Advances the machine to `now` given current facts. May perform several transitions in one call.
function RoundMachine.step(self: Machine, now: number, facts: Facts): { Event }
	local events: { Event } = {}
	local s = self.settings
	for _ = 1, 16 do -- bounded: each loop performs at most one transition
		local before = self.state
		if self.state == "Waiting" then
			if facts.readyCount >= s.MinimumReady then
				go(self, "Countdown", now, events)
				self.deadline = now + s.CountdownSeconds
				self.countdownShortened = false
			end
		elseif self.state == "Countdown" then
			if facts.readyCount < s.MinimumReady then
				table.insert(events, { kind = "CountdownCanceled", reason = "not enough ready players" })
				go(self, "Waiting", now, events, "ready count dropped")
			else
				if facts.readyCount >= s.Capacity and not self.countdownShortened then
					local target = now + s.FullLobbyCountdownSeconds
					if self.deadline and self.deadline > target then
						self.deadline = target
						table.insert(events, { kind = "CountdownShortened" })
					end
					self.countdownShortened = true
				end
				if self.deadline and now >= self.deadline then
					self.matchId += 1
					go(self, "Loading", now, events)
					self.deadline = now + s.LoadingTimeoutSeconds
					self.outcome = nil
					self.finalCueSent = false
				end
			end
		elseif self.state == "Loading" then
			if facts.loadFailed then
				go(self, "Waiting", now, events, "loading failed")
			elseif self.deadline and now >= self.deadline then
				go(self, "Waiting", now, events, "loading timed out")
			elseif facts.loadDone then
				go(self, "Intro", now, events)
				self.deadline = now + s.IntroSeconds
			end
		elseif self.state == "Intro" then
			if self.deadline and now >= self.deadline then
				go(self, "Live", now, events)
				self.roundEndTime = now + s.LiveSeconds
			end
		elseif self.state == "Live" then
			local endTime = self.roundEndTime :: number
			if now >= endTime then
				self.outcome = "Completed"
				go(self, "Results", now, events, "time")
				self.deadline = now + s.ResultsSeconds
			elseif facts.teamA == 0 or facts.teamB == 0 then
				self.pauseStartedAt = now
				self.graceEnd = now + s.VacancyGraceSeconds
				go(self, "VacancyPause", now, events, "team empty")
			elseif not self.finalCueSent and endTime - now <= s.FinalCueSeconds then
				self.finalCueSent = true
				table.insert(events, { kind = "FinalCue" })
			end
		elseif self.state == "VacancyPause" then
			if facts.teamA > 0 and facts.teamB > 0 then
				local paused = now - (self.pauseStartedAt :: number)
				self.roundEndTime = (self.roundEndTime :: number) + paused
				self.pauseStartedAt = nil
				self.graceEnd = nil
				go(self, "Live", now, events, "vacancy filled")
				table.insert(events, { kind = "DeadlineShifted", reason = string.format("%.3f", paused) })
			elseif now >= (self.graceEnd :: number) then
				self.outcome = "NoContest"
				self.pauseStartedAt = nil
				self.graceEnd = nil
				table.insert(events, { kind = "NoContest", reason = "Round ended — not enough players" })
				go(self, "Results", now, events, "no contest")
				self.deadline = now + s.ResultsSeconds
			end
		elseif self.state == "Results" then
			if self.deadline and now >= self.deadline then
				go(self, "Reset", now, events)
			end
		elseif self.state == "Reset" then
			if facts.resetDone then
				self.roundEndTime = nil
				go(self, "Intermission", now, events)
				self.deadline = now + s.IntermissionSeconds
			end
		elseif self.state == "Intermission" then
			if self.deadline and now >= self.deadline then
				if facts.readyCount >= s.MinimumReady then
					go(self, "Countdown", now, events)
					self.deadline = now + s.CountdownSeconds
					self.countdownShortened = false
				else
					go(self, "Waiting", now, events, "not enough ready players")
				end
			end
		end
		if self.state == before then
			break
		end
	end
	return events
end

-- Backfill rule (GDD 03.5): join live only with MORE than `minimum` seconds remaining, or during a vacancy grace.
function RoundMachine.allowsBackfill(self: Machine, now: number, minimumRemaining: number): boolean
	if self.state == "VacancyPause" then
		return true
	end
	if self.state == "Intro" or self.state == "Loading" then
		return true
	end
	local remaining = self:remainingLive(now)
	return self.state == "Live" and remaining ~= nil and remaining > minimumRemaining
end

return RoundMachine
