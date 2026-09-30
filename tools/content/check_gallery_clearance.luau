-- Geometry review of the designated terrace-center firing positions and optional climb access.
local report = {}
for _, template in game.ServerStorage.ColorClashMaps:GetChildren() do
	local m = template:Clone()
	m.Parent = workspace
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { m.Geometry, m.PaintSurfaces }
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = params.FilterDescendantsInstances
	local data = { baseSightlines = {}, climbClearanceFailures = {}, baseRays = 0, climbSamples = 0 }
	for _, team in { "A", "B" } do
		local side = if team == "A" then -1 else 1
		local deck = m.PaintSurfaces["terrace_" .. team]
		local top = deck.Position.Y + deck.Size.Y / 2
		local eye = deck.Position + Vector3.new(0, deck.Size.Y / 2 + 4.5, 0)
		for _, spawn in m.Spawns:GetChildren() do
			local dir = spawn.Position + Vector3.new(0, 4.5, 0) - eye
			local hit = workspace:Raycast(eye, dir, params)
			data.baseRays += 1
			if not hit or hit.Distance >= dir.Magnitude - 0.1 then
				table.insert(data.baseSightlines, { from = team, to = spawn.Name })
			end
		end
		-- A capsule-sized column reaches the preserved climb face, then clears its mantle landing.
		for y = 0, deck.Size.Y, 0.5 do
			local at = Vector3.new(side * 54, 100 + y + 2.85, deck.Position.Z - side * 13.8)
			data.climbSamples += 1
			local hits = workspace:GetPartBoundsInBox(CFrame.new(at), Vector3.new(2.8, 5.5, 2.8), overlap)
			if #hits > 0 then
				table.insert(data.climbClearanceFailures, { team = team, height = y, hit = hits[1].Name })
			end
		end
		local at = Vector3.new(side * 54, top + 2.85, deck.Position.Z - side * 10.5)
		data.climbSamples += 1
		local hits = workspace:GetPartBoundsInBox(CFrame.new(at), Vector3.new(2.8, 5.5, 2.8), overlap)
		if #hits > 0 then
			table.insert(data.climbClearanceFailures, { team = team, mantle = true, hit = hits[1].Name })
		end
	end
	data.pass = #data.baseSightlines == 0 and #data.climbClearanceFailures == 0
	report[m:GetAttribute("MapId")] = data
	m:Destroy()
end
return game.HttpService:JSONEncode(report)
