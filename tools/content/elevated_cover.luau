-- Elevated gallery backstops. All dimensions are floor-relative; maps applies elevation afterwards.
local C = require("./common")
return function(root, canopy)
	local g, decor = root.Geometry, root.Decor
	local height = if canopy then 10 else 8
	local z = if canopy then 60 else 48
	local toe = 35 - math.sqrt(24 * 24 - height * height)
	local top = height + 8
	for _, team in { "A", "B" } do
		local side = if team == "A" then -1 else 1
		local function panel(name, x, cz, sx, bottom, h, sz)
			local p = C.part(
				g,
				"Gallery" .. name .. team,
				{ sx, h, sz },
				{ side * x, bottom + h / 2, side * cz },
				{ 36, 48, 54 }
			)
			C.cosmetic(
				decor,
				p.Name .. "Cap",
				{ sx, 0.15, sz },
				{ side * x, bottom + h + 0.075, side * cz },
				if canopy then { 62, 161, 161 } else { 245, 158, 66 }
			)
		end
		-- The ramp keeps its full 20-stud width. The deck keeps 22.5 studs across its open surface.
		panel("RampInner", (toe + 35) / 2, z - 10.75, 35 - toe, 0, top, 1.5)
		panel("RampOuter", (toe + 35) / 2, z + 10.375, 35 - toe, 0, top, 0.75)
		panel("DeckOuter", 47, z + 11.25, 24, 0, top, 1.5)
		panel("Rear", 59.75, z, 1.5, 0, top, 24)
		-- Elevated rays meet this supported entrance screen; ground walkers pass below 7.5 studs.
		panel("Entrance", toe - 2, z, 1.5, 7.5, top - 7.5, 24)
		for _, sign in { -1, 1 } do
			panel("EntranceArm" .. sign, toe - 1, z + sign * 10.75, 2, 7.5, 1.5, 1.5)
		end
		-- Arena backstops frame the gallery's open climb-side view without narrowing its deck.
		local names = {
			"OuterChicane" .. team,
			"SightScreen" .. team .. "1",
			"SightScreen" .. team .. "4",
			"UtilityIsland" .. team .. "3",
			"BaseBaffle" .. team,
		}
		if canopy then
			for _, name in
				if side == -1
					then { "UtilityBank20", "UtilityBank29", "UtilityBank18", "BaseCornerA1", "BaseCornerA2" }
					else { "UtilityBank59", "UtilityBank50", "UtilityBank61", "BaseCornerB1", "BaseCornerB2" }
			do
				table.insert(names, name)
			end
		end
		for _, name in names do
			local base = g:FindFirstChild(name)
			local at = base.CFrame.Position
			local depth = base.Size.Z
			-- Switchyard's existing low core meets the ramp at deck height. Its upper panel stops at the inner rail.
			if not canopy and name == "SightScreen" .. team .. "4" then
				depth = 10
				at = C.R.Vector3.new(at.X, at.Y, side * 33)
			end
			local p = C.part(
				g,
				"Backstop" .. name,
				{ base.Size.X, top - base.Size.Y, depth },
				{ at.X, base.Size.Y + (top - base.Size.Y) / 2, at.Z },
				{ 36, 48, 54 }
			)
			C.cosmetic(
				decor,
				p.Name .. "Cap",
				{ base.Size.X, 0.15, depth },
				{ at.X, top + 0.075, at.Z },
				if canopy then { 62, 161, 161 } else { 245, 158, 66 }
			)
		end
		if not canopy then
			panel("IslandEnd", 29, -17, 4, 0, 8, 6)
			panel("RearCorner", 59.75, z - 13, 1.5, 7.5, top - 7.5, 2)
		end
	end
end
