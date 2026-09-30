-- Tactical map and Team Launch selection (GDD 08.4, 12.1 Map). Functional only: Codex restyles Map.* keys.
-- The map raster comes from the client's mirrored paint grid (TacticalMap.project), so it shows the same scoreable
-- surfaces and ownership as the world. Selecting a target and confirming sends ONLY a teammate id or "Base"; the
-- server picks the landing. The panel stays open during the 1 s channel (Menu context keeps the player still) and
-- shows the server's launch state.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local TacticalMap = require(Shared.Paint.TacticalMap)

local TacticalMapController = {}

local player = Players.LocalPlayer
local ui, input, paint, remotes
local selected: (number | string)? = nil
local targetButtons: { GuiObject } = {}
local pixels: { Frame } = {}
local markers: { Frame } = {}
local lastProj = nil
local launchState = "idle"
local lastStatus = ""
local stats = { sent = 0, lastReason = nil :: string?, lastState = nil :: string? }

local PIXEL_STUDS = 4
local MAX_SIDE = 40
local COLORS = {
	[0] = Color3.fromRGB(70, 70, 78),
	[1] = Color3.fromRGB(255, 138, 0),
	[2] = Color3.fromRGB(0, 150, 255),
}

local function setStatus(text: string)
	lastStatus = text
	ui.setText("Map.Status", text)
end

local function candidates()
	local list = {}
	for _, p in Players:GetPlayers() do
		table.insert(list, {
			id = p.UserId,
			team = p:GetAttribute("CCTeam") or 0,
			alive = p:GetAttribute("CCAlive") == true and p:GetAttribute("CCParticipating") == true,
			name = p.DisplayName,
		})
	end
	return list
end

local function refreshTargets()
	for _, b in targetButtons do
		b:Destroy()
	end
	table.clear(targetButtons)
	local list = TacticalMap.launchTargets(player.UserId, player:GetAttribute("CCTeam") or 0, candidates())
	local stillThere = false
	for k, tgt in list do
		local b = ui.cloneTemplate("Map.TargetTemplate", "Map.TargetList")
		if b then
			b.Name = "Target_" .. tostring(tgt.key)
			b.LayoutOrder = k
			b:SetAttribute("LaunchTarget", tgt.key)
			if b:IsA("TextButton") then
				b.Text = if tgt.key == selected then "> " .. tgt.label else tgt.label
			end
			if b:IsA("GuiButton") then
				b.Activated:Connect(function()
					selected = tgt.key
					refreshTargets()
				end)
			end
			table.insert(targetButtons, b)
		end
		if tgt.key == selected then
			stillThere = true
		end
	end
	if not stillThere then
		selected = nil -- a teammate who died or left can no longer be chosen
	end
	ui.setEnabled("Map.ConfirmLaunch", selected ~= nil and launchState == "idle")
end

-- Coarse raster in the wireframe (a production map image replaces this, keeping the same data).
local function drawMap()
	local image = ui.get("Map.Image")
	local grid = paint.grid()
	if not image or not grid then
		return
	end
	local proj = TacticalMap.project(grid, PIXEL_STUDS)
	local scale = math.max(1, math.ceil(math.max(proj.w, proj.h) / MAX_SIDE))
	lastProj = proj
	local w, h = math.ceil(proj.w / scale), math.ceil(proj.h / scale)
	local n = 0
	for pz = 0, h - 1 do
		for px = 0, w - 1 do
			-- sample the majority owner within the scaled block
			local c = { [0] = 0, [1] = 0, [2] = 0 }
			local any = false
			for dz = 0, scale - 1 do
				for dx = 0, scale - 1 do
					local x, z = px * scale + dx, pz * scale + dz
					if x < proj.w and z < proj.h then
						local o = TacticalMap.pixelOwner(proj, x, z)
						if o then
							c[o] += 1
							any = true
						end
					end
				end
			end
			if any then
				n += 1
				local f = pixels[n]
				if not f then
					f = Instance.new("Frame")
					f.BorderSizePixel = 0
					f.Name = "Px"
					pixels[n] = f
				end
				local owner = if c[1] >= c[2] and c[1] > c[0] then 1 elseif c[2] > c[0] then 2 else 0
				f.BackgroundColor3 = COLORS[owner]
				f.Size = UDim2.fromScale(1 / w, 1 / h)
				-- world +Z is drawn downward; world +X to the right
				f.Position = UDim2.fromScale(px / w, pz / h)
				f.Parent = image
			end
		end
	end
	for k = n + 1, #pixels do
		pixels[k].Parent = nil
	end
	image:SetAttribute("PixelsDrawn", n)
	-- teammate markers (and self)
	local m = 0
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root and p:GetAttribute("CCTeam") == player:GetAttribute("CCTeam") and p:GetAttribute("CCAlive") == true then
			m += 1
			local f = markers[m]
			if not f then
				f = Instance.new("Frame")
				f.Size = UDim2.fromOffset(8, 8)
				f.AnchorPoint = Vector2.new(0.5, 0.5)
				f.ZIndex = 5
				markers[m] = f
			end
			local u, v = TacticalMap.toMap(proj, root.Position.X, root.Position.Z)
			f.Name = "Mate_" .. p.UserId
			f.BackgroundColor3 = if p == player then Color3.new(1, 1, 1) else Color3.new(0.1, 0.1, 0.1)
			f.Position = UDim2.fromScale(u, v)
			f.Parent = image
		end
	end
	for k = m + 1, #markers do
		markers[k].Parent = nil
	end
end

function TacticalMapController.open()
	if ui.isOpen("Map") then
		return
	end
	ui.openPanel("Map")
	refreshTargets()
	drawMap()
	setStatus(if launchState == "idle" then "Choose a teammate or Base" else lastStatus)
	task.spawn(function()
		while ui.isOpen("Map") do
			task.wait(0.5)
			if ui.isOpen("Map") then
				drawMap()
			end
		end
	end)
end

function TacticalMapController.close()
	if ui.isOpen("Map") then
		ui.closePanel("Map")
	end
end

function TacticalMapController.confirm()
	if selected == nil or launchState ~= "idle" then
		return false
	end
	remotes.Launch:FireServer({ target = selected })
	stats.sent += 1
	launchState = "pending"
	setStatus("Requesting launch...")
	ui.setEnabled("Map.ConfirmLaunch", false)
	return true
end

function TacticalMapController.select(key: number | string)
	selected = key
	refreshTargets()
end

function TacticalMapController.state()
	return { launch = launchState, selected = selected, open = ui.isOpen("Map"), status = lastStatus, proj = lastProj }
end

function TacticalMapController.stats()
	return stats
end

local REASONS = {
	cooldown = "Launch is recharging",
	notOnOwnPaint = "Stand on your team's paint",
	illegalFloor = "Move off enemy paint",
	recentlyDamaged = "You were just hit",
	attacking = "Stop attacking first",
	badTarget = "That teammate can't be reached",
	notAlive = "Not available",
	inactive = "Not available now",
	alreadyLaunching = "Already launching",
	moved = "Cancelled: you moved",
	damaged = "Cancelled: you were hit",
	attacked = "Cancelled: you attacked",
	targetGone = "Cancelled: teammate lost",
	noLanding = "Cancelled: no safe landing",
	eliminated = "Cancelled",
	roundEnd = "Cancelled",
}

function TacticalMapController.start(deps)
	ui, input, paint, remotes = deps.ui, deps.input, deps.paint, deps.remotes
	input.onAction(function(action: string, down: boolean)
		if action ~= "Map" or not down then
			return
		end
		if ui.isOpen("Map") then
			TacticalMapController.close()
		elseif player:GetAttribute("CCParticipating") == true and player:GetAttribute("CCAlive") == true then
			TacticalMapController.open()
		end
	end)
	ui.onActivated("Map.Close", TacticalMapController.close)
	ui.onActivated("Map.ConfirmLaunch", TacticalMapController.confirm)
	remotes.ActionResult.OnClientEvent:Connect(function(msg)
		if type(msg) ~= "table" or msg.k ~= "Launch" then
			return
		end
		stats.lastState = msg.state
		stats.lastReason = msg.reason
		if msg.state == "channel" then
			launchState = "channel"
			setStatus("Launching...")
		elseif msg.state == "transit" then
			launchState = "transit"
			setStatus("In transit")
			TacticalMapController.close()
		elseif msg.state == "arrived" then
			launchState = "idle"
			setStatus("")
		else -- rejected / cancelled
			launchState = "idle"
			setStatus(REASONS[msg.reason] or "Launch unavailable")
			if ui.isOpen("Map") then
				refreshTargets()
			end
		end
	end)
	player:GetAttributeChangedSignal("CCAlive"):Connect(function()
		if player:GetAttribute("CCAlive") ~= true then
			launchState = "idle"
			TacticalMapController.close() -- death closes the map (no stale launch UI on the next life)
		end
	end)
end

return TacticalMapController
