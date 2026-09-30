--!strict
-- The two production map slots (GDD 09.2, 09.3, 09.5). Codex maps must declare one of these MapIds; the loader checks
-- each map against its slot (footprint, base centres, mirrored scoring parity) and against the model's own manifest
-- attributes (ExpectedScoringCells / ExpectedWallCells / ExpectedPatches). The rotation alternates slots in Order.

local function deepFreeze(t: any): any
	for _, v in t do
		if type(v) == "table" and not table.isfrozen(v) then
			deepFreeze(v)
		end
	end
	return table.freeze(t)
end

return deepFreeze({
	Slots = {
		switchyard = {
			Id = "switchyard",
			DisplayName = "Switchyard",
			Order = 1,
			Footprint = { X = 240, Z = 160 },
			BaseCenterX = 108,
		},
		canopy_courts = {
			Id = "canopy_courts",
			DisplayName = "Canopy Courts",
			Order = 2,
			Footprint = { X = 220, Z = 180 },
			BaseCenterX = 98,
		},
	},
	Order = { "switchyard", "canopy_courts" },
	-- Validation tolerances (studs / fraction). Footprint is measured from Geometry + PaintSurfaces bounds.
	FootprintTolerance = 0.1, -- +-10 % per axis
	BaseCenterTolerance = 8,
	SideParityTolerance = 0.03, -- scoring cells on the A half vs the B half
})
