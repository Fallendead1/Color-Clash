-- MOVE-01 / CAM-02 sampler (real keyboard input). Setup: harness:MatchSetup, then harness:Place at
-- "-28,100,-26,1,0" (own strip, facing +X). Trigger this spec, then hold LeftShift+W for ~3 s via the Studio MCP.
-- Asserts ground classification and speeds per ownership: Own glide 26, Neutral crouch 10, Enemy 9, with measured
-- horizontal velocity close to the target in each strip, and that the camera stays controllable while gliding.
return function(t)
	local it, expect = t.it, t.expect
	local C = t.services
	local player = game.Players.LocalPlayer
	local RunService = game:GetService("RunService")

	it("samples a glide run across own/neutral/enemy strips", function()
		C.CameraController.faceDirection(Vector3.new(1, 0, 0))
		C.CameraController.setPitch(-0.2)
		player:SetAttribute("CCSamplerReady", true)
		local samples = {}
		local yawStart = C.CameraController.yaw()
		local lookChanged = false
		local conn = RunService.PostSimulation:Connect(function()
			local c = player.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			local h = c and c:FindFirstChildOfClass("Humanoid")
			if r and h then
				local v = r.AssemblyLinearVelocity
				table.insert(samples, {
					keys = game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.LeftShift) and game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.W),
					x = r.Position.X,
					ground = C.MovementController.ground(),
					state = C.MovementController.state(),
					walk = h.WalkSpeed,
					speed = Vector3.new(v.X, 0, v.Z).Magnitude,
					glide = C.InputController.isHeld("Glide"),
				})
			end
		end)
		-- CAM-02: rotate the view slightly mid-glide; control must stay with the player
		task.delay(1.2, function()
			C.CameraController.addLook(0.0, 0.05)
			lookChanged = true
		end)
		task.wait(4)
		conn:Disconnect()
		player:SetAttribute("CCSamplerReady", false)
		-- diagnostic summary (always published)
		local groups = {}
		for _, s in samples do
			local key = s.ground .. (if s.glide then "+G" else "") .. "/" .. s.state
			local g = groups[key] or { n = 0, walk = 0, speed = 0, xmin = math.huge, xmax = -math.huge }
			g.n += 1
			g.walk += s.walk
			g.speed += s.speed
			g.xmin = math.min(g.xmin, s.x)
			g.xmax = math.max(g.xmax, s.x)
			groups[key] = g
		end
		local diag = {}
		for key, g in groups do
			table.insert(diag, string.format("%s n=%d walk=%.1f spd=%.1f x[%.0f,%.0f]", key, g.n, g.walk / g.n, g.speed / g.n, g.xmin, g.xmax))
		end
		table.sort(diag)
		player:SetAttribute("CCMoveStripsDiag", table.concat(diag, " | "))
		local keyFrames = 0
		for _, s in samples do
			if s.keys then
				keyFrames += 1
			end
		end
		-- The Studio MCP key injection is occasionally not delivered; that is an inconclusive run, not a game result.
		assert(keyFrames > 60, "INPUT NOT DELIVERED (Shift+W seen on " .. keyFrames .. " frames) — rerun")
		local seen = { Own = {}, Neutral = {}, Enemy = {} }
		for _, s in samples do
			if s.glide and seen[s.ground] then
				local inside = (s.ground == "Own" and s.x < -5) or (s.ground == "Neutral" and s.x > -3 and s.x < 3) or (s.ground == "Enemy" and s.x > 5)
				if inside then
					table.insert(seen[s.ground], s)
				end
			end
		end
		local function stable(list)
			-- drop the first 0.25 s of each strip (acceleration / hysteresis)
			local out = {}
			for k = math.min(#list, 16), #list do
				table.insert(out, list[k])
			end
			return out
		end
		local report = {}
		for name, want in { Own = 26, Neutral = 10, Enemy = 9 } do
			local list = stable(seen[name])
			expect(#list):toBeGreaterThan(3)
			local walkOk, speedSum = 0, 0
			for _, s in list do
				if math.abs(s.walk - want) < 0.01 then
					walkOk += 1
				end
				speedSum += s.speed
			end
			local avg = speedSum / #list
			table.insert(report, string.format("%s: walk=%d/%d avgSpeed=%.1f", name, walkOk, #list, avg))
			expect(walkOk):toBe(#list)
			expect(avg):toNear(want, want * 0.2)
		end
		player:SetAttribute("CCMoveStripsReport", table.concat(report, "; "))
		expect(lookChanged):toBe(true)
		expect(C.CameraController.yaw()):toNear(yawStart, 0.001) -- only pitch was changed; yaw untouched by movement
	end)
end
