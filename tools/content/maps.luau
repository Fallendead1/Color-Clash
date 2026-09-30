-- Original, mirrored arena-sport layouts. Rebuild with tools/build_content.
local C = require("./common")
local R = C.R
local N = C.new
local charcoal = { 36, 48, 54 }
local cream = { 223, 226, 210 }
local orange = { 245, 158, 66 }
local teal = { 62, 161, 161 }
local function surface(parent, id, size, pos, kind, face, score, climb)
	return C.part(
		parent,
		id,
		size,
		pos,
		cream,
		{ SurfaceId = id, SurfaceKind = kind, Face = face, Scoreable = score, Climbable = climb }
	)
end
local function sign(parent, name, text, size, pos, color)
	local p = C.cosmetic(parent, name, size, pos, color)
	local gui = N("SurfaceGui", "Sign", p, { Face = R.Enum.NormalId.Front, PixelsPerStud = 24, LightInfluence = 1 })
	N("TextLabel", "Legend", gui, {
		Size = R.UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = text,
		TextScaled = true,
		Font = R.Enum.Font.GothamBold,
		TextColor3 = R.Color3.fromRGB(241, 243, 224),
	})
end
local function build(id, display, w, d, bx, canopy)
	local root = N("Model", display, nil, nil, {
		MapId = id,
		MapVersion = 3,
		ContractVersion = 1,
		DisplayName = display,
		IsFixture = false,
		FloorElevation = 100,
	})
	local g = N("Folder", "Geometry", root)
	local s = N("Folder", "PaintSurfaces", root)
	local sp = N("Folder", "Spawns", root)
	local vol = N("Folder", "Volumes", root)
	local marks = N("Folder", "Markers", root)
	local decor = N("Folder", "Decor", root)
	-- Ground cells underneath solid raised structures are masked by the runtime overlap bake.
	surface(s, "arena_floor", { w, 2, d }, { 0, -1, 0 }, "Floor", "Top", true, false)
	for _, z in { -d / 2, d / 2 } do
		C.part(g, "PerimeterRail", { w, 8, 2 }, { 0, 4, z }, charcoal)
		C.cosmetic(decor, "SafetyStripe", { w, 0.35, 2.15 }, { 0, 7.3, z }, orange)
		for x = -w / 2 + 8, w / 2 - 8, 16 do
			C.cosmetic(decor, "RailPost", { 0.6, 2, 0.6 }, { x, 9, z }, cream)
		end
	end
	for _, x in { -w / 2, w / 2 } do
		C.part(g, "EndWall", { 2, 12, d }, { x, 6, 0 }, charcoal)
	end
	for _, t in { { -1, "A", 1 }, { 1, "B", 2 } } do
		local side, team, owner = table.unpack(t)
		local base = surface(s, "base_" .. team, { 22, 1, 40 }, { side * bx, 0.5, 0 }, "Base", "Top", false, false)
		base:SetAttribute("InitialOwner", owner)
		local v = C.cosmetic(vol, "ProtectedBase" .. team, { 24, 20, 40 }, { side * bx, 9, 0 }, cream)
		v.Transparency = 1
		v:SetAttribute("VolumeKind", "ProtectedBase")
		v:SetAttribute("Team", team)
		for i, z in { -12, -4, 4, 12 } do
			local p = C.cosmetic(sp, team .. i, { 2, 0.2, 2 }, { side * bx, 1.1, z }, cream)
			p.CFrame = R.CFrame.lookAt(R.Vector3.new(side * bx, 1.1, z), R.Vector3.new(0, 1.1, z))
			p.Transparency = 1
			p:SetAttribute("Team", team)
			C.cosmetic(decor, "SpawnDisc" .. team .. i, { 4, 0.05, 4 }, { side * bx, 1.03, z }, charcoal)
		end
		-- Solid baffle blocks every opposing spawn eye ray; exits are 18+ studs around either end.
		C.part(g, "BaseBaffle" .. team, { 6, 10, 24 }, { side * (bx - 18), 5, 0 }, charcoal)
		C.cosmetic(decor, "BaseBaffleCap" .. team, { 6.1, 0.4, 24.1 }, { side * (bx - 18), 10.15, 0 }, orange)
		sign(decor, "TeamSign" .. team, team .. "  /  EXIT", { 0.3, 2.5, 18 }, { side * (bx - 21.1), 7, 0 }, charcoal)
		for _, z in { -26, 26 } do
			C.cosmetic(decor, "ExitLane" .. team, { 18, 0.025, 0.35 }, { side * (bx - 9), 0.025, z }, orange)
		end
		local height = if canopy then 10 else 8
		local z = if canopy then 60 else 48
		local px = side * 47
		-- Terraces are solid to the ground. The climb face is the inward-facing Z wall.
		local pl = surface(
			s,
			"terrace_" .. team,
			{ 24, height, 24 },
			{ px, height / 2, side * z },
			"Floor",
			"Top",
			true,
			false
		)
		pl.Color = R.Color3.fromRGB(192, 203, 188)
		local wall = surface(
			s,
			"climb_" .. team,
			{ 24, height, 0.25 },
			{ px, height / 2, side * (z - 12) - side * 0.13 },
			"Wall",
			if side == -1 then "Back" else "Front",
			false,
			true
		)
		wall.Color = R.Color3.fromRGB(151, 173, 161)
		-- Rotated rectangular paint ramp: 24-stud run along local Z, < 30 degrees.
		local length = 24
		local angle = math.asin(height / length)
		local projected = math.cos(angle) * length
		local ramp = surface(
			s,
			"ramp_" .. team,
			{ 20, 1, length },
			{ px, height / 2 - 0.5 * math.cos(angle), side * (z + 12 + projected / 2) },
			"Ramp",
			"Top",
			true,
			false
		)
		-- Put ramps inward in X instead, so they never run into perimeter.
		ramp.CFrame = R.CFrame.new(px - side * (12 + projected / 2), height / 2 - 0.5 * math.cos(angle), side * z)
			* R.CFrame.Angles(0, -side * math.pi / 2, 0)
			* R.CFrame.Angles(angle, 0, 0)
		-- Thin ramp underside blocked by a solid wedge, preventing hidden legal floor.
		N("WedgePart", "RampSolid" .. team, g, {
			Size = R.Vector3.new(20, height, projected),
			CFrame = R.CFrame.new(px - side * (12 + projected / 2), height / 2 - 0.5, side * z)
				* R.CFrame.Angles(0, side * math.pi / 2, 0),
			Anchored = true,
			CanTouch = false,
			Color = R.Color3.fromRGB(99, 120, 113),
			Material = R.Enum.Material.Concrete,
		})
		-- Raised deck trim and short grating connectors are visually distinct and non-scoring.
		C.cosmetic(decor, "TerraceLip" .. team, { 24, 0.22, 0.5 }, { px, height + 0.1, side * (z + 11.5) }, orange)
		local grate = C.part(g, "Grating" .. team, { 8, 0.15, 12 }, { side * 72, 0.075, side * 37 }, charcoal)
		grate.Material = R.Enum.Material.DiamondPlate
		for n = -3, 3 do
			C.cosmetic(decor, "GrateSlot", { 0.12, 0.02, 11 }, { side * 72 + n, 0.16, side * 37 }, { 95, 113, 111 })
		end
		-- Staggered cover creates approach decisions instead of one long corridor.
		for i, data in { { 62, -24, 10, 18 }, { 36, 30, 12, 16 }, { 24, -12, 14, 20 } } do
			local x, cz, sx, sz = table.unpack(data)
			local h = if i == 2 then 3.5 else 8
			C.part(g, "UtilityIsland" .. team .. i, { sx, h, sz }, { side * x, h / 2, side * cz }, charcoal)
			C.cosmetic(
				decor,
				"IslandCap" .. team .. i,
				{ sx + 0.05, 0.22, sz + 0.05 },
				{ side * x, h + 0.1, side * cz },
				if canopy then teal else orange
			)
			for j = -1, 1 do
				C.cosmetic(
					decor,
					"IslandRib",
					{ 0.3, h - 1, sz + 0.1 },
					{ side * x + j * (sx / 3), h / 2, side * cz },
					{ 72, 88, 90 }
				)
			end
		end
		-- Break long flank lines while preserving >18-stud passage around each end.
		C.part(g, "FlankBaffle" .. team, { 6, 8, 18 }, { side * 6, 4, side * (d / 2 - 15) }, charcoal)
		-- Mirrored sight screens leave the central approach open for an 18-stud agent.
		-- The low island retains half-cover wings around its full-height utility core.
		for i, spec in
			{
				{ side * 56, -side * 10, 10, 20 },
				{ 0, side * 34, 8, 8 },
				{ 0, side * (d / 2 - 10), 8, 20 },
				{ side * 36, side * 30, 4, 16 },
				{ side * 46, -side * 46, 24, 16 },
				{ side * bx, -40, 24, 8 },
				{ side * bx, 40, 24, 8 },
			}
		do
			local x, cz, sx, sz = table.unpack(spec)
			C.part(g, "SightScreen" .. team .. i, { sx, 8, sz }, { x, 4, cz }, charcoal)
			C.cosmetic(
				decor,
				"ScreenCap" .. team .. i,
				{ sx, 0.2, sz },
				{ x, 8.1, cz },
				if canopy then teal else orange
			)
		end
		if canopy then
			C.part(g, "CanopyRoof" .. team, { 28, 1, 24 }, { side * 46, 16, -side * 50 }, cream)
			for _, dx in { -12, 12 } do
				for _, dz in { -10, 10 } do
					C.part(g, "CanopySupport" .. team, { 2, 16, 2 }, { side * 46 + dx, 8, -side * 50 + dz }, teal)
				end
			end
			C.cosmetic(decor, "CanopyFascia" .. team, { 28, 1.2, 0.4 }, { side * 46, 16.1, -side * 50 - 12.2 }, teal)
		end
		sign(
			decor,
			"ArenaWordmark" .. team,
			string.upper(display) .. "  /  COLOR CLASH",
			{ 34, 3, 0.25 },
			{ side * 40, 6, -d / 2 + 1.15 },
			charcoal
		)
	end
	local below = C.cosmetic(vol, "RecoveryBelow", { w + 40, 12, d + 40 }, { 0, -18, 0 }, cream)
	below.Transparency = 1
	below:SetAttribute("VolumeKind", "OutOfBounds")
	for _, axis in { "X", "Z" } do
		for _, side in { -1, 1 } do
			local v = C.cosmetic(
				vol,
				"Outside" .. axis .. side,
				if axis == "X" then { 12, 100, d + 40 } else { w + 40, 100, 12 },
				if axis == "X" then { side * (w / 2 + 9), 30, 0 } else { 0, 30, side * (d / 2 + 9) },
				cream
			)
			v.Transparency = 1
			v:SetAttribute("VolumeKind", "OutOfBounds")
		end
	end
	local ret = C.cosmetic(marks, "StagingReturn", { 1, 1, 1 }, { 0, 5, 250 }, cream)
	ret.Transparency = 1
	-- Restrained court/lane lines are visual only and sit below ownership overlays.
	for _, z in { -28, 28 } do
		C.cosmetic(decor, "CenterLane", { 64, 0.018, 0.2 }, { 0, 0.01, z }, charcoal)
	end
	for _, x in { -32, 32 } do
		C.cosmetic(decor, "CenterEnd", { 0.2, 0.018, 56 }, { x, 0.01, 0 }, charcoal)
	end
	-- Match the established fixture elevation and preserve the Studio-owned baseplate below the recovery volume.
	for _, p in root:GetDescendants() do
		if p:IsA("BasePart") then
			p.CFrame = p.CFrame + R.Vector3.new(0, 100, 0)
		end
	end
	return root
end
return function()
	local root = N("Folder", "ColorClashMaps")
	build("switchyard", "Switchyard", 240, 160, 108, false).Parent = root
	build("canopy_courts", "Canopy Courts", 220, 180, 98, true).Parent = root
	local staging = N("Model", "ColorClashStaging")
	C.part(staging, "Deck", { 72, 3, 48 }, { 0, -1.5, 250 }, charcoal)
	local spawn = C.cosmetic(staging, "StagingSpawn", { 4, 1, 4 }, { 0, 1, 250 }, cream)
	spawn.Transparency = 1
	for _, x in { -36, 36 } do
		C.part(staging, "Rail", { 1, 7, 48 }, { x, 3.5, 250 }, teal)
	end
	for _, z in { 226, 274 } do
		C.part(staging, "Rail", { 72, 7, 1 }, { 0, 3.5, z }, teal)
	end
	sign(staging, "Welcome", "COLOR CLASH  /  PAINT. GLIDE. CONTROL.", { 60, 5, 0.3 }, { 0, 6, 227 }, charcoal)
	for _, p in staging:GetDescendants() do
		if p:IsA("BasePart") then
			p.CFrame = p.CFrame + R.Vector3.new(0, 100, 0)
		end
	end
	return root, staging
end
