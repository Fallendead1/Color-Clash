-- MOVE-03 / MOVE-04 / CAM-02 climb sampler (real keyboard input: hold LeftShift+W ~3 s).
-- Scenario from LocalPlayer attribute CCClimbScenario, with placement by harness:Place:
--   "hostile" : "0,100,-17.6,0,-1"  paint_wall_north, lower 4 rows own, upper rows enemy -> safe detach, no stuck
--   "mantle"  : "0,100,12.4,0,1"    platform_climb_south (own, 5 high) -> clearance-tested mantle onto the platform
--   "blocked" : "-7.6,100,20,1,0"   platform_climb_west with a low overhang -> no mantle, no teleport through it
return function(t)
	local it, expect = t.it, t.expect
	local C = t.services
	local UIS = game:GetService("UserInputService")
	local RunService = game:GetService("RunService")
	local player = game.Players.LocalPlayer

	it("climb scenario", function()
		local scenario = player:GetAttribute("CCClimbScenario")
		local face = ({ hostile = Vector3.new(0, 0, -1), mantle = Vector3.new(0, 0, 1), blocked = Vector3.new(1, 0, 0) })[scenario]
		assert(face, "unknown scenario " .. tostring(scenario))
		C.CameraController.faceDirection(face)
		C.CameraController.setPitch(0.1)
		player:SetAttribute("CCSamplerReady", true)
		local sawClimbing, keyFrames, maxY, maxX, yawChanged = false, 0, -math.huge, -math.huge, false
		local detachedWhileHeld = false
		local yawTested = false
		local climbFrames, midClimb = 0, ""
		local onPlatform = false
		local states = {}
		local conn = RunService.PostSimulation:Connect(function()
			local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not r then
				return
			end
			local st = C.MovementController.state()
			if states[#states] ~= st then
				if states[#states] == "Climbing" and UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
					detachedWhileHeld = true
				end
				table.insert(states, st)
			end
			if st == "Climbing" then
				sawClimbing = true
				climbFrames += 1
				if climbFrames == 20 then
					midClimb = C.MovementController.climbDebug()
				end
				if not yawTested then
					-- CAM-02: rotate the view during the climb; control must stay with the player
					yawTested = true
					local y0 = C.CameraController.yaw()
					C.CameraController.addLook(0.05, 0)
					yawChanged = math.abs(C.CameraController.yaw() - y0) > 0.01 and C.MovementController.state() == "Climbing"
				end
			end
			if UIS:IsKeyDown(Enum.KeyCode.LeftShift) and UIS:IsKeyDown(Enum.KeyCode.W) then
				keyFrames += 1
			end
			maxY = math.max(maxY, r.Position.Y)
			maxX = math.max(maxX, r.Position.X)
			-- standing on the platform top (floor 105): root ~3 above it, inside the platform footprint
			if (st == "Standing" or st == "Gliding") and r.Position.Y > 107 and r.Position.Z > 14.2 and r.Position.Z < 25.8 and math.abs(r.Position.X) < 5.8 then
				onPlatform = true
			end
		end)
		task.wait(5)
		conn:Disconnect()
		player:SetAttribute("CCSamplerReady", false)
		local r = player.Character.HumanoidRootPart
		local final = C.MovementController.state()
		player:SetAttribute("CCClimbDiag", string.format("%s states=%s maxY=%.1f maxX=%.1f final=%s pos=%s keys=%d yaw=%s detach=%s climbFrames=%d onPlatform=%s mid={%s}", scenario, table.concat(states, ">"), maxY, maxX, final, tostring(r.Position), keyFrames, tostring(yawChanged), C.MovementController.lastDetach(), climbFrames, tostring(onPlatform), midClimb))
		assert(keyFrames > 60, "INPUT NOT DELIVERED — rerun")
		expect(sawClimbing):toBe(true)
		expect(yawChanged):toBe(true)
		expect(final ~= "Climbing"):toBe(true) -- keys released: never left stuck on the wall
		if scenario == "hostile" then
			-- own paint covers the bottom 4 rows (y 100..104); the root (3 above the feet) cannot climb far past it
			expect(maxY):toBeLessThan(109)
			expect(r.Position.Y):toBeLessThan(104) -- back on the floor
			-- the detach must happen because paint was lost, while Glide+W were still held (not on key release)
			expect(detachedWhileHeld):toBe(true)
		elseif scenario == "mantle" then
			expect(onPlatform):toBe(true) -- mantled and stood on the platform top (keys may carry it on afterwards)
		elseif scenario == "blocked" then
			expect(maxX):toBeLessThan(-6) -- never moved onto the platform under the overhang
			expect(onPlatform):toBe(false)
			expect(r.Position.Y):toBeLessThan(104)
		end
	end)
end
