-- Scoreboard (GDD 12.1): team grouping, names, eliminations, assists, deaths and Paint Contribution, sorted by
-- contribution first (kills never imply the winner). Data: the server Roster broadcast (every 2 s during a match).
-- Functional only: Codex restyles the Scoreboard.* keys.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Strings = require(Shared.UI.Strings)

local ScoreboardController = {}

local player = Players.LocalPlayer
local ui, input, remotes
local roster: { any } = {}
local rows: { GuiObject } = {}

-- Pure ordering used by the view and tests: participants by team, contribution desc, then name.
function ScoreboardController.order(list: { any }): { [number]: { any } }
	local byTeam = { [1] = {}, [2] = {} }
	for _, r in list do
		if (r.team == 1 or r.team == 2) and r.participating then
			table.insert(byTeam[r.team], r)
		end
	end
	for _, t in byTeam do
		table.sort(t, function(a, b)
			if (a.paint or 0) ~= (b.paint or 0) then
				return (a.paint or 0) > (b.paint or 0)
			end
			return tostring(a.name) < tostring(b.name)
		end)
	end
	return byTeam
end

local function render()
	for _, r in rows do
		r:Destroy()
	end
	table.clear(rows)
	ui.setText("Scoreboard.Header", Strings.ScoreboardHeader)
	local byTeam = ScoreboardController.order(roster)
	for team, list in byTeam do
		local parentKey = if team == 1 then "Scoreboard.TeamA" else "Scoreboard.TeamB"
		for k, r in list do
			local row = ui.cloneTemplate("Scoreboard.RowTemplate", parentKey)
			if row then
				row.Name = "Row_" .. tostring(r.userId)
				row.LayoutOrder = k
				row:SetAttribute("UserId", r.userId)
				if row:IsA("TextLabel") or row:IsA("TextButton") then
					row.Text = string.format(Strings.ScoreboardRow, r.name .. (if r.userId == player.UserId then " (you)" else ""), r.paint or 0, r.eliminations or 0, r.assists or 0, r.deaths or 0)
					row.TextTruncate = Enum.TextTruncate.AtEnd
				end
				table.insert(rows, row)
			end
		end
	end
end

function ScoreboardController.toggle()
	if ui.isOpen("Scoreboard") then
		ui.closePanel("Scoreboard")
	else
		ui.openPanel("Scoreboard")
		render()
	end
end

-- Tests: feed a synthetic roster (long names, eight players) and render it.
function ScoreboardController.renderRoster(list: { any })
	roster = list
	render()
end

function ScoreboardController.rows(): { GuiObject }
	return rows
end

function ScoreboardController.start(deps)
	ui, input, remotes = deps.ui, deps.input, deps.remotes
	input.onAction(function(action: string, down: boolean)
		if action == "Scoreboard" and down then
			ScoreboardController.toggle()
		end
	end)
	remotes.Roster.OnClientEvent:Connect(function(list)
		if type(list) ~= "table" then
			return
		end
		roster = list
		if ui.isOpen("Scoreboard") then
			render()
		end
	end)
end

return ScoreboardController
