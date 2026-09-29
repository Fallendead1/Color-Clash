-- Client weapon input and prediction (GDD 06.2, 07, 10.6). Sends one sequenced Action per legal shot at the kit's
-- cadence while Primary is held (never per rendered frame). Predicts muzzle flash/trajectory/paint locally; the server
-- decides everything. A denied shot removes its predicted paint immediately (within the 0.5 s tolerance).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Weapons = require(Shared.Config.Weapons)
local GameConfig = require(Shared.Config.GameConfig)
local Ballistics = require(Shared.Combat.Ballistics)
local Strings = require(Shared.UI.Strings)

local WeaponController = {}

local player = Players.LocalPlayer
local input, camera, movement, paintClient, effects, remotes, ui, hud
local seq = 0
local nextShot = 0
local pendingSpend = 0
local predictions: { [number]: { fx: any?, predictionId: any } } = {}
local lastDryCue = 0
local stats = { sent = 0, denied = 0, predictedCells = 0 }

local function kit()
	local id = player:GetAttribute("CCWeapon") or Weapons.Default
	return Weapons.Defs[id] or Weapons.Defs[Weapons.Default]
end

local function teamId(): number
	return player:GetAttribute("CCTeam") or 0
end

local function canFire(): boolean
	return input.context() == "Gameplay" and player:GetAttribute("CCAlive") == true and movement.state() ~= "Climbing"
end

local function predictedPaint(): number
	local res = hud.resource()
	return (res.paint or 0) - pendingSpend
end

local function callout(text: string)
	ui.setText("HUD.Callout", text)
	task.delay(0.8, function()
		if ui.get("HUD.Callout") and ui.get("HUD.Callout").Text == text then
			ui.setText("HUD.Callout", "")
		end
	end)
end

local function fireProjectile(k)
	local aim = camera.aim()
	local lifeId = player:GetAttribute("CCLifeId") or 0
	seq += 1
	local s = seq
	local origin = aim.muzzle
	local dir = aim.direction
	remotes.Action:FireServer({
		m = player:GetAttribute("CCMatchId") or 0,
		l = lifeId,
		s = s,
		a = "Fire",
		t = Workspace:GetServerTimeNow(),
		o = origin,
		d = dir,
	})
	stats.sent += 1
	pendingSpend += k.Cost
	movement.noteFired(k.MoveSpeedWhileFiring)
	-- the same deterministic spread the server applies
	local spread = Ballistics.spread(vector.create(dir.X, dir.Y, dir.Z), k.SpreadDegrees or 0, lifeId, s)
	local d3 = Vector3.new(spread.X, spread.Y, spread.Z)
	local predictionId = "shot:" .. lifeId .. ":" .. s
	local entry = { fx = nil, predictionId = predictionId }
	predictions[s] = entry
	entry.fx = effects.projectile(origin, d3, k.Id, teamId(), function(pos: Vector3, normal: Vector3)
		local grid = paintClient.grid()
		local renderer = paintClient.renderer()
		if not grid or not renderer or predictions[s] ~= entry then
			return
		end
		local cells = grid:previewSphere(vector.create(pos.X, pos.Y, pos.Z), k.ImpactPaintRadius, teamId(), {
			origin = vector.create(pos.X + normal.X * 0.3, pos.Y + normal.Y * 0.3, pos.Z + normal.Z * 0.3),
		})
		if #cells > 0 then
			stats.predictedCells += #cells
			renderer:Predict(predictionId, cells, teamId())
			-- authoritative chunks replace this within a few deltas; never let it outlive them
			renderer:ExpireIn(predictionId, 0.6)
		end
	end)
	task.delay(2, function()
		if predictions[s] == entry then
			predictions[s] = nil
		end
	end)
end

local function step()
	if not input.isHeld("Primary") or not canFire() then
		return
	end
	local k = kit()
	if k.Family ~= "projectile" then
		return -- other families are implemented in Phase 05
	end
	local now = os.clock()
	if now < nextShot then
		return
	end
	if predictedPaint() < k.Cost then
		if now - lastDryCue > GameConfig.Tank.DryCueMinInterval then
			lastDryCue = now
			callout(Strings.DryFire)
		end
		nextShot = now + k.Cadence
		return
	end
	nextShot = now + k.Cadence
	fireProjectile(k)
end

function WeaponController.stats()
	return stats
end

function WeaponController.start(deps)
	input, camera, movement, paintClient, effects, remotes, ui, hud = deps.input, deps.camera, deps.movement, deps.paint, deps.effects, deps.remotes, deps.ui, deps.hud
	RunService.RenderStepped:Connect(step)
	remotes.Resource.OnClientEvent:Connect(function(msg)
		if type(msg) == "table" and msg.paint ~= nil then
			pendingSpend = 0 -- the authoritative balance already includes processed shots
		end
	end)
	remotes.ActionResult.OnClientEvent:Connect(function(msg)
		if type(msg) ~= "table" or msg.k ~= "Action" or msg.ok then
			return
		end
		stats.denied += 1
		local entry = msg.s and predictions[msg.s]
		if entry then
			predictions[msg.s] = nil
			effects.cancel(entry.fx)
			local renderer = paintClient.renderer()
			if renderer then
				renderer:Deny(entry.predictionId) -- PAINT-12: denied prediction removed at once
			end
		end
		if msg.reason == "dry" then
			callout(Strings.DryFire)
		elseif msg.reason == "base" then
			callout(Strings.BaseShieldHint)
		end
	end)
	player:GetAttributeChangedSignal("CCLifeId"):Connect(function()
		seq = 0 -- sequences are per life on the server too
		nextShot = 0
		pendingSpend = 0
		for s, entry in predictions do
			predictions[s] = nil
			local renderer = paintClient.renderer()
			if renderer then
				renderer:Deny(entry.predictionId)
			end
		end
	end)
end

return WeaponController
