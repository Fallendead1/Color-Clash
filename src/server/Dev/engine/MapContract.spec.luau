-- MAP-02..04 against CONTRACT FIXTURES (not production maps): both manifest slots validate; malformed content is
-- rejected with a precise report; spawns, symmetry and out-of-bounds rules hold. Loads into a temporary folder.
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local S = t.services
	local MapLoader = require(S.Dev.Parent.Map.MapLoader)
	local ContractMap = require(S.Dev.fixtures.ContractMap)
	local PaintLab = require(S.Dev.fixtures.PaintLab)
	local Workspace = game:GetService("Workspace")

	local function load(model: Model, isFixture: boolean)
		local folder = Instance.new("Folder")
		folder.Name = "CCMapContractTest"
		folder.Parent = Workspace
		model.Parent = folder
		local desc, errors = MapLoader.load(model, isFixture)
		local slotErrors = if desc then MapLoader.validateSlot(desc) else {}
		folder:Destroy()
		return desc, errors, slotErrors
	end
	local function has(list: { string }, needle: string): boolean
		for _, e in list do
			if string.find(e, needle, 1, true) then
				return true
			end
		end
		return false
	end

	describe("Map contract (contract fixtures)", function()
		it("MAP-03 both manifest slots validate (spawns, sightline, footprint, bases, mirrored area)", function()
			for _, slotId in { "switchyard", "canopy_courts" } do
				local desc, errors, slotErrors = load(ContractMap.build(slotId), true)
				if not desc then
					error(slotId .. ": " .. table.concat(errors, "; "))
				end
				expect(#slotErrors):toBe(0)
				expect(desc.mapId):toBe(slotId)
				expect(#desc.spawns[1]):toBe(4)
				expect(#desc.spawns[2]):toBe(4)
				expect(desc.manifest.scoringCells > 20000 and desc.manifest.scoringCells <= 50000):toBe(true)
			end
		end)

		it("MAP-02 manifest counts must match; production maps must declare them", function()
			local m = ContractMap.build("switchyard")
			m:SetAttribute("ExpectedScoringCells", 12345)
			local desc, errors = load(m, true)
			expect(desc):toBe(nil)
			expect(has(errors, "manifest ExpectedScoringCells = 12345 but the loader derives")):toBe(true)
			local d2, e2 = load(ContractMap.build("switchyard"), false) -- treated as production: attributes required
			expect(d2):toBe(nil)
			expect(has(e2, "manifest attribute ExpectedScoringCells missing")):toBe(true)
			expect(has(e2, "manifest attribute ExpectedPatches missing")):toBe(true)
			-- a production map declaring the derived values loads
			local ok = ContractMap.build("switchyard")
			local probe = load(ContractMap.build("switchyard"), true)
			ok:SetAttribute("ExpectedScoringCells", probe.manifest.scoringCells)
			ok:SetAttribute("ExpectedWallCells", probe.manifest.wallCells)
			ok:SetAttribute("ExpectedPatches", probe.manifest.patches)
			local d3, e3 = load(ok, false)
			if not d3 then
				error(table.concat(e3, "; "))
			end
			expect(d3.isFixture):toBe(false)
		end)

		it("MAP-02 missing/duplicate surface id and off-grid surface are rejected precisely", function()
			local m = PaintLab.build()
			m.PaintSurfaces.floor_center:SetAttribute("SurfaceId", nil)
			local _, e1 = load(m, true)
			expect(has(e1, "missing SurfaceId")):toBe(true)
			local m2 = PaintLab.build()
			m2.PaintSurfaces.floor_A_north:SetAttribute("SurfaceId", "floor_center")
			local _, e2 = load(m2, true)
			expect(has(e2, "duplicate SurfaceId floor_center")):toBe(true)
			local m3 = PaintLab.build()
			m3.PaintSurfaces.floor_center.Size = Vector3.new(64.5, 2, 64)
			local _, e3 = load(m3, true)
			expect(has(e3, "floor_center face 64.500x64.000 is not on the one-stud grid")):toBe(true)
		end)

		it("MAP-03 slot rules: unknown slot, off-centre base, unmirrored area, opposing spawn sightline", function()
			local m = ContractMap.build("switchyard")
			m:SetAttribute("MapId", "my_map")
			local _, _, s1 = load(m, true)
			expect(has(s1, "MapId my_map is not a manifest slot")):toBe(true)
			local m2 = ContractMap.build("switchyard")
			m2:SetAttribute("MapId", "canopy_courts") -- switchyard geometry declared as the other slot
			local _, _, s2 = load(m2, true)
			expect(has(s2, "base centre")):toBe(true)
			local m5 = ContractMap.build("switchyard")
			m5.Geometry.perimeter_e.CFrame += Vector3.new(40, 0, 0) -- 282 studs wide, off-centre
			local _, _, s5 = load(m5, true)
			expect(has(s5, "footprint 282 x 162 differs from slot 240 x 160")):toBe(true)
			expect(has(s5, "footprint is not centred")):toBe(true)
			local m3 = ContractMap.build("switchyard")
			local fb = m3.PaintSurfaces.floor_B
			fb.Size -= Vector3.new(10, 0, 0)
			fb.CFrame += Vector3.new(5, 0, 0)
			local _, _, s3 = load(m3, true)
			expect(has(s3, "scoring area is not mirrored")):toBe(true)
			local m4 = ContractMap.build("switchyard")
			m4.Geometry.spawn_screen_A:Destroy()
			m4.Geometry.spawn_screen_B:Destroy()
			m4.Geometry.center_cover_A:Destroy()
			m4.Geometry.center_cover_B:Destroy()
			local d4, e4 = load(m4, true)
			expect(d4):toBe(nil)
			expect(has(e4, "opposing spawns have a direct sightline")):toBe(true)
		end)

		it("MAP-04 out-of-bounds scoring, spawns and climb tops are rejected", function()
			local m = ContractMap.build("switchyard")
			local hidden = m.PaintSurfaces.platform_top_A:Clone()
			hidden:SetAttribute("SurfaceId", "hidden_floor")
			hidden.CFrame = CFrame.new(0, 70, 0) -- inside the OutOfBounds volume below the arena
			hidden.Parent = m.PaintSurfaces
			local _, e1 = load(m, true)
			expect(has(e1, "surface hidden_floor has")):toBe(true)
			expect(has(e1, "inside an OutOfBounds volume")):toBe(true)
			local m2 = ContractMap.build("switchyard")
			local oobRoof = Instance.new("Part")
			oobRoof.Name = "oob_roof"
			oobRoof.Anchored = true
			oobRoof.Size = Vector3.new(12, 6, 12)
			oobRoof.CFrame = m2.PaintSurfaces.platform_top_A.CFrame + Vector3.new(0, 3.5, 0)
			oobRoof:SetAttribute("VolumeKind", "OutOfBounds")
			oobRoof.Parent = m2.Volumes
			local _, e2 = load(m2, true)
			expect(has(e2, "climbable surface platform_climb_A tops out into an OutOfBounds volume")):toBe(true)
			local m3 = ContractMap.build("switchyard")
			local extraOob = Instance.new("Part")
			extraOob.Name = "oob_in_base"
			extraOob.Anchored = true
			extraOob.Size = Vector3.new(4, 4, 4)
			extraOob.CFrame = m3.Spawns.A1.CFrame
			extraOob:SetAttribute("VolumeKind", "OutOfBounds")
			extraOob.Parent = m3.Volumes
			local _, e3 = load(m3, true)
			expect(has(e3, "spawn A1 is inside an OutOfBounds volume")):toBe(true)
		end)
	end)
end
