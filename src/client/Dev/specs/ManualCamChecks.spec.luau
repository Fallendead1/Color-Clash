-- CAM-01 / CAM-03 (no keyboard input needed). Placement: harness:Place "0,100,30.8,0,-1" (back to the north
-- perimeter wall, looking -Z) for the near-wall check.
return function(t)
	local it, expect = t.it, t.expect
	local C = t.services
	local player = game.Players.LocalPlayer
	local cam = workspace.CurrentCamera

	local function rootPart()
		return player.Character.HumanoidRootPart
	end

	it("CAM-03 near a wall the camera pulls in and stays out of geometry", function()
		C.CameraController.faceDirection(Vector3.new(0, 0, -1))
		C.CameraController.setPitch(-0.1)
		task.wait(0.5)
		local r = rootPart()
		local dist = (cam.CFrame.Position - r.Position).Magnitude
		expect(dist):toBeLessThan(8)
		local probe = Instance.new("Part")
		probe.Size = Vector3.new(0.2, 0.2, 0.2)
		probe.Anchored = true
		probe.CanCollide = false
		probe.CFrame = CFrame.new(cam.CFrame.Position)
		probe.Parent = workspace
		local hits = workspace:GetPartsInPart(probe)
		probe:Destroy()
		local inside = {}
		for _, h in hits do
			if h.Anchored and h.CanCollide and not h:IsDescendantOf(player.Character) then
				table.insert(inside, h:GetFullName())
			end
		end
		player:SetAttribute("CCCamDiag", string.format("dist=%.2f cam=%s inside=%s", dist, tostring(cam.CFrame.Position), table.concat(inside, ",")))
		expect(#inside):toBe(0)
	end)

	it("CAM-03 shoulder swap moves the camera to the other side", function()
		C.CameraController.faceDirection(Vector3.new(1, 0, 0))
		C.CameraController.setPitch(-0.1)
		task.wait(0.4)
		local r = rootPart()
		local right = cam.CFrame.RightVector
		local side1 = (cam.CFrame.Position - r.Position):Dot(right)
		C.CameraController.swapShoulder()
		task.wait(0.4)
		local side2 = (cam.CFrame.Position - rootPart().Position):Dot(cam.CFrame.RightVector)
		C.CameraController.swapShoulder()
		expect(side1 * side2 < 0):toBe(true)
	end)

	it("CAM-01 a blocked muzzle is detected even when the camera sees past the obstacle", function()
		C.CameraController.faceDirection(Vector3.new(1, 0, 0))
		C.CameraController.setPitch(0.1)
		task.wait(0.3)
		local aim = C.CameraController.aim()
		local muzzle = aim.muzzle
		local look = Vector3.new(1, 0, 0)
		local arenaMap = workspace.ColorClashArena:GetChildren()[1]
		local block = Instance.new("Part")
		block.Name = "TestMuzzleBlock"
		block.Anchored = true
		block.Size = Vector3.new(0.4, 1.4, 1.4)
		block.CFrame = CFrame.new(muzzle + look * 0.7)
		block.Parent = arenaMap.Geometry
		task.wait(0.2)
		local blocked = C.CameraController.aim().blocked
		block:Destroy()
		task.wait(0.2)
		local clear = C.CameraController.aim().blocked
		expect(blocked):toBe(true)
		expect(clear):toBe(false)
	end)
end
