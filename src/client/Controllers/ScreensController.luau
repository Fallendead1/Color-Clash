-- Player-facing screen behaviour driven by server state (GDD 12.1): Loading, Staging, Armory, Controls, Intro,
-- HUD timer/coverage, Results and Notices. Uses the UIKey adapter only; no visual hierarchy paths.
-- Timers are computed from authoritative server deadlines with workspace:GetServerTimeNow(); the UI never runs a
-- competing round clock.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Strings = require(Shared.UI.Strings)
local Weapons = require(Shared.Config.Weapons)
local Abilities = require(Shared.Config.Abilities)
local GameConfig = require(Shared.Config.GameConfig)

local ScreensController = {}

local player = Players.LocalPlayer
local ui, input, paintClient, remotes
local round = nil -- latest RoundState payload
local results = nil
local armorySelection = Weapons.Default
local kitButtons: { [string]: GuiButton } = {}
local noticeCount = 0
local onboardingDismissed = false
local loadingStage: string? = nil
local loadingFailed = false
local lastTimerText = ""

local function fmtTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function ScreensController.notice(text: string, seconds: number?)
	noticeCount += 1
	if noticeCount > 4 then
		return -- rate limit: never spam the screen (GDD 12.1 System notices)
	end
	local row = ui.cloneTemplate("Notices.Template", "Notices.Root")
	if not row then
		noticeCount -= 1
		return
	end
	row.Text = text
	task.delay(seconds or 3, function()
		row:Destroy()
		noticeCount -= 1
	end)
end

---------------------------------------------------------------------------------------------------------------
-- Loading (real stages only; never a fabricated percentage)
---------------------------------------------------------------------------------------------------------------

local function setLoading(stage: string?, detail: string?)
	loadingStage = stage
	ui.setVisible("Loading.Root", stage ~= nil)
	if stage then
		ui.setText("Loading.Stage", Strings.LoadingStages[stage] or stage)
		ui.setText("Loading.Detail", detail or "")
	end
	ui.setVisible("Loading.Retry", loadingFailed)
	ui.setVisible("Loading.Back", loadingFailed)
end

---------------------------------------------------------------------------------------------------------------
-- Armory
---------------------------------------------------------------------------------------------------------------

local function kitDetail(id: string): string
	local w = Weapons.Defs[id]
	local g = Abilities.Gadgets[w.Gadget]
	local u = Abilities.Ultimates[w.Ultimate]
	local lines = {
		w.DisplayName .. " — " .. w.Role,
		"Input: " .. w.Input,
		w.Description,
		string.format("Paint cost %s · cadence %.2f s · reach %d studs", tostring(w.Cost), w.Cadence, w.Range),
		"Gadget: " .. g.DisplayName .. " — " .. g.Description,
		"Ultimate: " .. u.DisplayName .. " — " .. u.Description,
		"Free. Every kit is a sidegrade.",
	}
	return table.concat(lines, "\n")
end

local function refreshArmory()
	local equipped = player:GetAttribute("CCWeapon") or Weapons.Default
	for id, b in kitButtons do
		local w = Weapons.Defs[id]
		b.Text = w.DisplayName .. (if id == equipped then "  ✓" else "") .. (if id == armorySelection then "  ◀" else "")
	end
	ui.setText("Armory.Detail", kitDetail(armorySelection))
	local locked = player:GetAttribute("CCParticipating") == true and round ~= nil and (round.state == "Live" or round.state == "Intro" or round.state == "Loading" or round.state == "VacancyPause")
	ui.setEnabled("Armory.Equip", not locked and armorySelection ~= equipped)
	if locked then
		ui.setText("Armory.Status", Strings.KitLocked)
	end
	ui.setText("Staging.Kit", (Weapons.Defs[equipped] or Weapons.Defs[Weapons.Default]).DisplayName)
end

local pendingEquip: thread? = nil
local function equip()
	local id = armorySelection
	ui.setText("Armory.Status", Strings.KitPending)
	remotes.SelectLoadout:FireServer(id)
	pendingEquip = coroutine.running()
	local result = task.delay(4, function()
		if pendingEquip then
			local t = pendingEquip
			pendingEquip = nil
			task.spawn(t, nil)
		end
	end)
	local answer = coroutine.yield()
	task.cancel(result)
	if answer == nil then
		ui.setText("Armory.Status", Strings.NoticeConnection)
	elseif answer.ok then
		ui.setText("Armory.Status", string.format(Strings.KitSelected, Weapons.Defs[answer.id].DisplayName))
	else
		ui.setText("Armory.Status", if answer.reason == "locked_in_match" then Strings.KitLocked else Strings.KitUnknown)
	end
	refreshArmory()
end

---------------------------------------------------------------------------------------------------------------
-- Controls text (device specific)
---------------------------------------------------------------------------------------------------------------

local function controlsText(): string
	local device = input.device()
	local lines = { table.concat(Strings.OnboardingLines, "  ") , "" }
	if device == "Gamepad" then
		table.insert(lines, "Move: left stick   Aim: right stick   Fire: RT   Secondary: LT")
		table.insert(lines, "Glide/Climb: hold RB   Jump: A   Gadget: LB   Ultimate: X")
		table.insert(lines, "Map / Team Launch: Y   Scoreboard: View   Shoulder: R3   Back: B")
	elseif device == "Touch" then
		table.insert(lines, "Left stick moves. Drag the right side to aim.")
		table.insert(lines, "FIRE shoots (hold). GLIDE toggles glide. ALT is your kit's secondary.")
		table.insert(lines, "GADGET, ULT and MAP buttons sit above FIRE.")
	else
		table.insert(lines, "Move: WASD   Aim: mouse   Fire: left mouse   Secondary: right mouse")
		table.insert(lines, "Glide/Climb: hold Shift   Jump: Space   Gadget: Q   Ultimate: E")
		table.insert(lines, "Map / Team Launch: M   Scoreboard: Tab   Shoulder swap: C")
	end
	return table.concat(lines, "\n")
end

---------------------------------------------------------------------------------------------------------------
-- Staging status, intro, HUD timer
---------------------------------------------------------------------------------------------------------------

local function stagingStatus(): string
	if not round then
		return ""
	end
	local now = Workspace:GetServerTimeNow()
	local s = round.state
	local participating = player:GetAttribute("CCParticipating") == true
	local readyCount = 0
	local total = #Players:GetPlayers()
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("CCReady") then
			readyCount += 1
		end
	end
	if s == "Waiting" then
		return string.format(Strings.StatusWaiting, readyCount, round.minimumReady or GameConfig.Match.PublicMinimumReady) .. string.format("  (%d here)", total)
	elseif s == "Countdown" then
		return string.format(Strings.StatusCountdown, math.ceil((round.deadline or now) - now), readyCount)
	elseif s == "Loading" then
		return Strings.StatusLoading
	elseif s == "Live" or s == "Intro" then
		local remaining = (round.roundEndTime or now) - now
		if participating then
			return ""
		end
		return if remaining > GameConfig.Match.BackfillMinimumRemainingSeconds then string.format(Strings.StatusLive, fmtTime(remaining)) else Strings.StatusLiveClosed
	elseif s == "VacancyPause" then
		return Strings.StatusPaused
	elseif s == "Results" then
		return Strings.StatusResults
	else
		return Strings.StatusIntermission
	end
end

local function refreshStaging()
	local participating = player:GetAttribute("CCParticipating") == true
	local inMatch = participating and round and (round.state == "Intro" or round.state == "Live" or round.state == "VacancyPause")
	ui.setVisible("Staging.Root", not inMatch)
	ui.setVisible("Staging.Onboarding", not inMatch and not onboardingDismissed)
	local ready = player:GetAttribute("CCReady") == true
	ui.setVisible("Staging.Ready", not ready)
	ui.setVisible("Staging.Unready", ready)
	ui.setText("Staging.Status", stagingStatus())
	ui.setVisible("HUD.Root", inMatch == true)
	ui.setVisible("TouchControlsRoot", false)
	local tc = ui.root() and ui.root():FindFirstChild("TouchControls")
	if tc then
		tc.Visible = inMatch == true and input.device() == "Touch"
	end
end

local function refreshHudTimer()
	if not round then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local text = ""
	if round.state == "Live" and round.roundEndTime then
		text = fmtTime(round.roundEndTime - now)
	elseif round.state == "VacancyPause" and round.remaining then
		text = fmtTime(round.remaining) .. " ⏸"
	elseif round.state == "Intro" then
		text = fmtTime(GameConfig.Match.LiveSeconds)
	end
	if text ~= lastTimerText then
		lastTimerText = text
		ui.setText("HUD.Timer", text)
	end
	-- intro 3-2-1 (combat disabled until Live)
	if round.state == "Intro" and round.deadline and player:GetAttribute("CCParticipating") then
		ui.setVisible("Intro.Root", true)
		local teamId = player:GetAttribute("CCTeam") or 0
		ui.setText("Intro.Title", (round.map and round.map.name or "") .. " — " .. (Strings.TeamNames[teamId] or ""))
		ui.setText("Intro.Count", tostring(math.max(1, math.ceil(round.deadline - now))))
	else
		ui.setVisible("Intro.Root", false)
	end
end

local function refreshCoverage()
	local grid = paintClient.grid()
	if not grid or grid.totalScoringArea == 0 then
		return
	end
	local total = grid.totalScoringArea
	local a, b = grid.totals[1], grid.totals[2]
	local aF, bF = a / total, b / total
	local ca, cb, cn = ui.get("HUD.CoverageA"), ui.get("HUD.CoverageB"), ui.get("HUD.Neutral")
	if ca and cb and cn then
		ca.Size = UDim2.fromScale(aF, 1)
		cb.Size = UDim2.fromScale(bF, 1)
		cb.Position = UDim2.fromScale(1 - bF, 0)
		cn.Size = UDim2.fromScale(math.max(0, 1 - aF - bF), 1)
		cn.Position = UDim2.fromScale(aF, 0)
	end
	ui.setText("HUD.CoverageText", string.format("A %.1f%%  ·  neutral %.1f%%  ·  B %.1f%%", 100 * aF, 100 * (1 - aF - bF), 100 * bF))
end

---------------------------------------------------------------------------------------------------------------
-- Results
---------------------------------------------------------------------------------------------------------------

local function showResults(r)
	results = r
	ui.closeAllPanels()
	ui.setVisible("Results.Root", true)
	local outcome
	if r.outcome == "NoContest" then
		outcome = Strings.OutcomeNoContest
	elseif r.outcome == "Draw" then
		outcome = Strings.OutcomeDraw
	else
		outcome = string.format(Strings.OutcomeWin, Strings.TeamNames[if r.outcome == "A" then 1 else 2])
	end
	if r.fixture then
		outcome ..= "  (fixture)"
	end
	ui.setText("Results.Outcome", outcome)
	if r.total and r.total > 0 then
		ui.setText("Results.CoverageText", string.format(Strings.CoverageLine, "A " .. r.aText, "B " .. r.bText, r.neutralText))
		local bar = ui.get("Results.Coverage")
		if bar then
			local fa, fb = r.a / r.total, r.b / r.total
			local A, B = bar:FindFirstChild("A"), bar:FindFirstChild("B")
			if A and B then
				A.Size = UDim2.fromScale(fa, 1)
				B.Size = UDim2.fromScale(fb, 1)
				B.Position = UDim2.fromScale(1 - fb, 0)
			end
		end
	else
		ui.setText("Results.CoverageText", "")
	end
	local stats = ui.get("Results.Stats")
	if stats then
		for _, c in stats:GetChildren() do
			if c:IsA("GuiObject") and c:GetAttribute("UIKey") == nil and c.Name == "StatRowTemplate" then
				c:Destroy()
			end
		end
	end
	for _, row in r.players or {} do
		local line = ui.cloneTemplate("Results.StatRowTemplate", "Results.Stats")
		if line then
			line.Text = string.format("[%s] %s — paint %d · E %d · A %d · D %d", row.team == 1 and "A" or "B", row.name, row.paint, row.eliminations, row.assists, row.deaths)
		end
	end
	local deadline = round and round.deadline
	task.delay(GameConfig.Match.ResultsSeconds, function()
		if results == r then
			ui.setVisible("Results.Root", false)
		end
	end)
	local _ = deadline
end

---------------------------------------------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------------------------------------------

function ScreensController.start(deps)
	ui, input, paintClient, remotes = deps.ui, deps.input, deps.paint, deps.remotes

	setLoading("Remotes")

	ui.onActivated("Staging.Ready", function()
		remotes.Ready:FireServer({ ready = true })
		task.wait(0.25)
	end)
	ui.onActivated("Staging.Unready", function()
		remotes.Ready:FireServer({ ready = false })
		task.wait(0.25)
	end)
	ui.onActivated("Staging.OpenArmory", function()
		ui.openPanel("Armory")
		refreshArmory()
	end)
	ui.onActivated("Staging.OpenControls", function()
		ui.setText("Controls.Text", controlsText())
		ui.openPanel("Controls")
	end)
	ui.onActivated("Staging.OpenSettings", function()
		ui.openPanel("Settings")
	end)
	ui.onActivated("Staging.OnboardingDismiss", function()
		onboardingDismissed = true
		remotes.SettingsPatch:FireServer({ onboardingDismissed = true })
		refreshStaging()
	end)
	ui.onActivated("Armory.Close", function()
		ui.closePanel("Armory")
	end)
	ui.onActivated("Controls.Close", function()
		ui.closePanel("Controls")
	end)
	ui.onActivated("Settings.Close", function()
		ui.closePanel("Settings")
	end)
	ui.onActivated("Armory.Equip", equip)
	ui.onActivated("Loading.Retry", function()
		loadingFailed = false
		if paintClient.grid() then
			remotes.PaintResync:FireServer({ m = paintClient.matchId(), v = (paintClient.meta() or {}).version })
		end
		setLoading(nil)
	end)
	ui.onActivated("Loading.Back", function()
		loadingFailed = false
		setLoading(nil)
	end)

	-- kit list
	for i, id in Weapons.Order do
		local b = ui.cloneTemplate("Armory.KitTemplate", "Armory.KitList")
		if b then
			b.LayoutOrder = i
			b:SetAttribute("KitId", id)
			kitButtons[id] = b :: any
			b.Activated:Connect(function()
				armorySelection = id
				refreshArmory()
			end)
		end
	end

	remotes.ActionResult.OnClientEvent:Connect(function(msg)
		if type(msg) ~= "table" then
			return
		end
		if msg.k == "Loadout" and pendingEquip then
			local t = pendingEquip
			pendingEquip = nil
			task.spawn(t, msg)
		end
	end)

	remotes.RoundState.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.k == "Results" then
			showResults(payload.results)
			return
		end
		local previous = round and round.state
		round = payload
		if payload.state ~= previous then
			if payload.state == "Loading" and player:GetAttribute("CCReady") then
				setLoading("Map")
			elseif payload.state == "Reset" or payload.state == "Intermission" or payload.state == "Waiting" then
				ui.setVisible("Results.Root", payload.state == "Reset" and results ~= nil)
			end
		end
		refreshStaging()
		refreshArmory()
	end)

	remotes.Notice.OnClientEvent:Connect(function(msg)
		if type(msg) ~= "table" then
			return
		end
		local map = {
			IdleUnready = Strings.NoticeIdleUnready,
			BackfillClosed = Strings.NoticeBackfillClosed,
			MatchFull = Strings.NoticeMatchFull,
			VacancyPause = Strings.NoticeVacancy,
			FinalCue = Strings.FinalCue,
			NoContest = Strings.OutcomeNoContest,
		}
		if msg.k == "LoadingFailed" then
			loadingFailed = true
			setLoading("Map", string.format(Strings.LoadingFailed, tostring(msg.detail or "")))
			ScreensController.notice(Strings.NoticeLoadingFailed)
		elseif map[msg.k] then
			ScreensController.notice(map[msg.k])
		end
	end)

	paintClient.onChange(function(kind)
		if kind == "map" and player:GetAttribute("CCParticipating") then
			setLoading("Paint")
		elseif kind == "synced" and (loadingStage == "Paint" or loadingStage == "Map") then
			setLoading(nil)
		end
	end)

	for _, attr in { "CCReady", "CCParticipating", "CCTeam", "CCWeapon" } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			refreshStaging()
			refreshArmory()
		end)
	end

	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		refreshHudTimer()
		if acc >= 0.2 then -- 5 Hz for text/coverage; no full rebuild per frame (GDD 12.1 HUD)
			acc = 0
			ui.setText("Staging.Status", stagingStatus())
			refreshCoverage()
		end
	end)

	setLoading(nil)
	refreshStaging()
	refreshArmory()
end

function ScreensController.round()
	return round
end

return ScreensController
