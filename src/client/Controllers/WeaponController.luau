-- Client weapon input and prediction for all seven kits (GDD 06.2, 07, 10.6). Sends sequenced Actions (never per
-- rendered frame): one Fire per legal attack at the kit cadence, start/stop for continuous actions, charge start/
-- release/cancel for the Linecaster. Predicts trajectory/paint locally for projectile-like kits; the server decides
-- everything. A denied shot removes its predicted paint at once; forced input releases (panel, death, focus loss)
-- cancel continuous actions instead of completing them.

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
local predictions: { [number]: { fx: { any }, predictionId: any } } = {}
local lastDryCue = 0
local stats = { sent = 0, denied = 0, predictedCells = 0, byAction = {} }
local charging = false
local chargeStarted = 0
local lastHeldAim = 0
local rolling = false
local pushing = false
local muzzleLeft = false
local dashUntil = 0
local dashConstraint: LinearVelocity? = nil

local function kit()
	local id = player:GetAttribute("CCWeapon") or Weapons.Default
	return Weapons.Defs[id] or Weapons.Defs[Weapons.Default]
end

local function teamId(): number
	return player:GetAttribute("CCTeam") or 0
end

local function canAct(): boolean
	return input.context() == "Gameplay" and player:GetAttribute("CCAlive") == true and movement.state() ~= "Climbing"
end

local function predictedPaint(): number
	return (hud.resource().paint or 0) - pendingSpend
end

local function callout(text: string)
	ui.setText("HUD.Callout", text)
	task.delay(0.8, function()
		local c = ui.get("HUD.Callout")
		if c and c.Text == text then
			ui.setText("HUD.Callout", "")
		end
	end)
end

local function dryCue()
	local now = os.clock()
	if now - lastDryCue > GameConfig.Tank.DryCueMinInterval then
		lastDryCue = now
		callout(Strings.DryFire)
	end
end

-- Builds and sends one sequenced action. Returns the sequence number.
local function send(action: string, origin: Vector3?, dir: Vector3?): number
	local aim = camera.aim()
	seq += 1
	remotes.Action:FireServer({
		m = player:GetAttribute("CCMatchId") or 0,
		l = player:GetAttribute("CCLifeId") or 0,
		s = seq,
		a = action,
		t = Workspace:GetServerTimeNow(),
		o = origin or aim.muzzle,
		d = dir or aim.direction,
	})
	stats.sent += 1
	stats.byAction[action] = (stats.byAction[action] or 0) + 1
	return seq
end

local function predictImpact(s: number, predictionId: string, radius: number)
	return function(pos: Vector3, normal: Vector3)
		local grid = paintClient.grid()
		local renderer = paintClient.renderer()
		if not grid or not renderer or not predictions[s] then
			return
		end
		local cells = grid:previewSphere(vector.create(pos.X, pos.Y, pos.Z), radius, teamId(), {
			origin = vector.create(pos.X + normal.X * 0.3, pos.Y + normal.Y * 0.3, pos.Z + normal.Z * 0.3),
		})
		if #cells > 0 then
			stats.predictedCells += #cells
			local id = predictionId .. ":" .. math.floor(pos.X * 10) .. ":" .. math.floor(pos.Z * 10)
			renderer:Predict(id, cells, teamId())
			renderer:ExpireIn(id, 0.6) -- authoritative chunks replace predictions within a few deltas
			table.insert(predictions[s].ids, id)
		end
	end
end

local function trackPrediction(s: number)
	local entry = { fx = {}, predictionId = "shot:" .. (player:GetAttribute("CCLifeId") or 0) .. ":" .. s, ids = {} }
	predictions[s] = entry
	task.delay(2, function()
		if predictions[s] == entry then
			predictions[s] = nil
		end
	end)
	return entry
end

---------------------------------------------------------------------------------------------------------------
-- Families
---------------------------------------------------------------------------------------------------------------

local function fireProjectile(k)
	local aim = camera.aim()
	local origin = aim.muzzle
	if k.Muzzles and #k.Muzzles == 2 then
		-- Twin Jets alternate left/right attachments; each paid shot is one projectile
		muzzleLeft = not muzzleLeft
		local right = Workspace.CurrentCamera.CFrame.RightVector
		origin = origin + right * (if muzzleLeft then -0.6 else 0.3)
	end
	local s = send("Fire", origin, aim.direction)
	pendingSpend += k.Cost
	movement.noteFired(k.MoveSpeedWhileFiring)
	local lifeId = player:GetAttribute("CCLifeId") or 0
	local dir = aim.direction
	local spread = Ballistics.spread(vector.create(dir.X, dir.Y, dir.Z), k.SpreadDegrees or 0, lifeId, s)
	local entry = trackPrediction(s)
	local radius = k.ImpactPaintRadius or k.BurstPaintRadius or 2
	local fx = effects.projectile(origin, Vector3.new(spread.X, spread.Y, spread.Z), k.Id, teamId(), predictImpact(s, entry.predictionId, radius))
	if fx then
		table.insert(entry.fx, fx)
	end
end

local function fireVolley(k)
	local aim = camera.aim()
	local s = send("Fire", aim.muzzle, aim.direction)
	pendingSpend += k.Cost
	movement.noteFired(k.MoveSpeedWhileFiring)
	local entry = trackPrediction(s)
	for _, fx in effects.volley(aim.muzzle, aim.direction, k.Id, teamId(), predictImpact(s, entry.predictionId, k.LobePaintRadius)) do
		table.insert(entry.fx, fx)
	end
end

local function melee(k)
	-- roller flick / brush sweep: the server resolves the fan after its windup
	send("Fire")
	pendingSpend += k.Cost
	movement.noteFired(k.MoveSpeedWhileFiring)
	if rolling then
		rolling = false
		movement.setActivity("rolling", false)
	end
	if pushing then
		pushing = false
		movement.setActivity("pushing", false)
	end
end

local function startDash(k)
	local now = os.clock()
	if now < dashUntil + k.Dash.Cooldown - k.Dash.Duration or movement.state() == "Gliding" or movement.state() == "Climbing" then
		return
	end
	if predictedPaint() < k.Dash.Cost then
		dryCue()
		return
	end
	local c = player.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if not root or not h then
		return
	end
	local move = h.MoveDirection
	local dir = Vector3.new(move.X, 0, move.Z)
	if dir.Magnitude < 0.2 then
		local r = Workspace.CurrentCamera.CFrame.RightVector
		dir = Vector3.new(r.X, 0, r.Z)
	end
	dir = dir.Unit
	send("Dash", nil, dir)
	pendingSpend += k.Dash.Cost
	dashUntil = now + k.Dash.Duration
	-- physics dash: a horizontal velocity constraint; walls stop it (no passing through geometry)
	local att = Instance.new("Attachment")
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.PlaneVelocity = Vector2.new(dir.X, dir.Z) * (k.Dash.Distance / k.Dash.Duration)
	lv.MaxForce = 1e6
	lv.Parent = root
	dashConstraint = lv
	task.delay(k.Dash.Duration, function()
		lv:Destroy()
		att:Destroy()
		if dashConstraint == lv then
			dashConstraint = nil
		end
	end)
end

local function chargeStart(k)
	if charging or predictedPaint() < k.Cost then
		if not charging then
			dryCue()
		end
		return
	end
	if movement.state() == "Gliding" then
		return
	end
	charging = true
	chargeStarted = os.clock()
	movement.setActivity("charging", true)
	send("ChargeStart")
end

local function chargeEnd(k, forced: string?)
	if not charging then
		return
	end
	charging = false
	movement.setActivity("charging", false)
	if forced then
		send("ChargeCancel") -- panel entry / death / focus loss never fire a stored charge
		return
	end
	local held = os.clock() - chargeStarted
	if held < k.MinCharge then
		send("ChargeCancel")
		return
	end
	local aim = camera.aim()
	send("ChargeRelease", aim.muzzle, aim.direction)
	pendingSpend += k.Cost
	movement.noteFired(k.MoveSpeedWhileFiring)
	effects.beam(aim.muzzle, aim.muzzle + aim.direction * math.min(k.Range, aim.hitDistance + 0.5), teamId(), 0.12)
end

local function setContinuous(kind: string, on: boolean)
	if kind == "roll" then
		if rolling == on then
			return
		end
		rolling = on
		movement.setActivity("rolling", on)
	else
		if pushing == on then
			return
		end
		pushing = on
		movement.setActivity("pushing", on)
	end
	send(if on then "SecStart" else "SecStop")
end

---------------------------------------------------------------------------------------------------------------
-- Input routing
---------------------------------------------------------------------------------------------------------------

local function onAction(action: string, down: boolean, forced: string?)
	local k = kit()
	local fam = k.Family
	if action == "Primary" then
		if fam == "charger" then
			if down and canAct() then
				chargeStart(k)
			elseif not down then
				chargeEnd(k, forced)
			end
		end
	elseif action == "Secondary" then
		if fam == "charger" then
			camera.setFocus(down and canAct())
		elseif fam == "projectile" and k.Dash then
			if down and canAct() then
				startDash(k)
			end
		elseif fam == "roller" or fam == "brush" then
			local kind = if fam == "roller" then "roll" else "push"
			if down and canAct() then
				if predictedPaint() <= 0 then
					dryCue()
					return
				end
				setContinuous(kind, true)
			elseif not down then
				setContinuous(kind, false)
			end
		end
	elseif action == "Glide" and down and charging then
		chargeEnd(k, "glide") -- gliding cancels the stored charge
	end
end

local function step()
	local k = kit()
	local fam = k.Family
	if charging then
		-- charge glow / state readout; held aim relays the warning line at <= 10 Hz
		local factor = math.clamp((os.clock() - chargeStarted - k.MinCharge) / (k.FullCharge - k.MinCharge), 0, 1)
		ui.setText("HUD.ReticleState", string.format("Charge %d%%", math.floor(factor * 100)))
		if os.clock() - lastHeldAim > 0.1 then
			lastHeldAim = os.clock()
			local aim = camera.aim()
			remotes.HeldAim:FireServer({ l = player:GetAttribute("CCLifeId") or 0, o = aim.muzzle, d = aim.direction })
		end
		if not canAct() then
			chargeEnd(k, "state")
		end
		return
	end
	if (rolling or pushing) and not canAct() then
		setContinuous(if rolling then "roll" else "push", false)
	end
	if not input.isHeld("Primary") or not canAct() or fam == "charger" then
		return
	end
	local now = os.clock()
	if now < nextShot then
		return
	end
	nextShot = now + k.Cadence
	if predictedPaint() < k.Cost then
		dryCue()
		return
	end
	if fam == "projectile" or fam == "blaster" then
		fireProjectile(k)
	elseif fam == "lobber" then
		fireVolley(k)
	elseif fam == "roller" or fam == "brush" then
		melee(k)
	end
end

function WeaponController.stats()
	return stats
end

function WeaponController.state()
	return { charging = charging, rolling = rolling, pushing = pushing, dashing = os.clock() < dashUntil }
end

function WeaponController.start(deps)
	input, camera, movement, paintClient, effects, remotes, ui, hud = deps.input, deps.camera, deps.movement, deps.paint, deps.effects, deps.remotes, deps.ui, deps.hud
	input.onAction(onAction)
	RunService.RenderStepped:Connect(step)
	remotes.Resource.OnClientEvent:Connect(function(msg)
		if type(msg) == "table" and msg.paint ~= nil then
			pendingSpend = 0 -- the authoritative balance already includes processed actions
		end
	end)
	remotes.ActionResult.OnClientEvent:Connect(function(msg)
		if type(msg) ~= "table" then
			return
		end
		if msg.k == "Stop" then
			-- the server ended a continuous action (e.g. the tank ran out)
			if msg.what == "roll" and rolling then
				rolling = false
				movement.setActivity("rolling", false)
			elseif msg.what == "push" and pushing then
				pushing = false
				movement.setActivity("pushing", false)
			end
			dryCue()
			return
		end
		if msg.k ~= "Action" or msg.ok then
			return
		end
		stats.denied += 1
		local entry = msg.s and predictions[msg.s]
		if entry then
			predictions[msg.s] = nil
			local renderer = paintClient.renderer()
			for _, fx in entry.fx do
				effects.cancel(fx)
			end
			if renderer then
				for _, id in entry.ids do
					renderer:Deny(id) -- PAINT-12: denied prediction removed at once
				end
			end
		end
		if msg.a == "ChargeStart" and charging then
			charging = false
			movement.setActivity("charging", false)
		end
		if msg.reason == "dry" then
			dryCue()
		elseif msg.reason == "base" then
			callout(Strings.BaseShieldHint)
		end
	end)
	player:GetAttributeChangedSignal("CCLifeId"):Connect(function()
		seq = 0 -- sequences are per life on the server too
		nextShot = 0
		pendingSpend = 0
		charging, rolling, pushing = false, false, false
		movement.setActivity("charging", false)
		movement.setActivity("rolling", false)
		movement.setActivity("pushing", false)
		camera.setFocus(false)
		for s, entry in predictions do
			predictions[s] = nil
			local renderer = paintClient.renderer()
			if renderer then
				for _, id in entry.ids do
					renderer:Deny(id)
				end
			end
		end
	end)
	player:GetAttributeChangedSignal("CCWeapon"):Connect(function()
		charging, rolling, pushing = false, false, false
		camera.setFocus(false)
	end)
end

return WeaponController
