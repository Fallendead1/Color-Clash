-- Content-only checks for the actual exported Phase 09 maps and models. No fixture substitution.
return function(t)
	local it, expect = t.it, t.expect
	local L = require(game.ServerScriptService.Server.Map.MapLoader)
	local W = require(game.ServerScriptService.Server.Presentation.WeaponModels)
	local records = {}
	it("CONTENT-01 both production maps load, fit their slots and have no warnings", function()
		local maps = game.ServerStorage:FindFirstChild("ColorClashMaps")
		expect(maps ~= nil):toBe(true)
		expect(#maps:GetChildren()):toBe(2)
		for _, m in maps:GetChildren() do
			local clone = m:Clone()
			clone.Parent = workspace
			local desc, errors = L.load(clone, false)
			local slot = if desc then L.validateSlot(desc) else {}
			records[m:GetAttribute("MapId")] =
				{ errors = errors, slot = slot, manifest = desc and desc.manifest, warnings = desc and desc.warnings }
			clone:Destroy()
			expect(#errors):toBe(0)
			expect(desc ~= nil):toBe(true)
			expect(#slot):toBe(0)
			expect(#desc.warnings):toBe(0)
		end
		workspace:SetAttribute("CCProductionContent", game.HttpService:JSONEncode(records))
	end)
	it("CONTENT-03 seven original weapon attachments and welded parts", function()
		local lib = game.ReplicatedStorage.ColorClashAssets.Weapons
		expect(#lib:GetChildren()):toBe(7)
		for _, m in lib:GetChildren() do
			expect(#W.validate(m, m.Name)):toBe(0)
			for _, p in m:GetDescendants() do
				if p:IsA("BasePart") then
					expect(p.CanCollide or p.CanQuery or p.CanTouch or p.Anchored):toBe(false)
					expect(p.Massless):toBe(true)
					expect(p:FindFirstChild("Grip") ~= nil or p:FindFirstChildOfClass("WeldConstraint") ~= nil):toBe(
						true
					)
				end
			end
		end
	end)
	it("MAP-03 ramp high edge joins terrace; canopy collision blocks vertical rays", function()
		for _, m in game.ServerStorage.ColorClashMaps:GetChildren() do
			local clone = m:Clone()
			clone.Parent = workspace
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { clone.Geometry, clone.PaintSurfaces }
			for _, team in { "A", "B" } do
				local ramp = clone.PaintSurfaces["ramp_" .. team]
				local terrace = clone.PaintSurfaces["terrace_" .. team]
				local high = ramp.CFrame:PointToWorldSpace(Vector3.new(0, ramp.Size.Y / 2, -ramp.Size.Z / 2))
				expect(math.abs(high.Y - (terrace.Position.Y + terrace.Size.Y / 2)) < 0.01):toBe(true)
				expect(math.abs(math.abs(high.X - terrace.Position.X) - terrace.Size.X / 2) < 0.3):toBe(true)
				if m:GetAttribute("MapId") == "canopy_courts" then
					local roof = clone.Geometry["CanopyRoof" .. team]
					local hit = workspace:Raycast(roof.Position + Vector3.new(0, 20, 0), Vector3.new(0, -40, 0), params)
					expect(hit ~= nil and hit.Instance == roof):toBe(true)
				end
			end
			clone:Destroy()
		end
	end)
end
