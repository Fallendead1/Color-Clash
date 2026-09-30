-- Studio Server Play: deterministic geometry review, no gameplay changes.
-- Raw rays and continuous combat segments outside protected bases are reported separately.
local root = Instance.new("Folder")
root.Name = "CCRouteReview"
root.Parent = workspace
local report = {}
for index, template in game.ServerStorage.ColorClashMaps:GetChildren() do
	local m = template:Clone()
	local ox = (index - 1) * 500
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.CFrame += Vector3.new(ox, 1000, 0)
		end
	end
	m.Parent = root
	local floor = m.PaintSurfaces.arena_floor
	local y = floor.Position.Y + floor.Size.Y / 2
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { m.Geometry, m.PaintSurfaces }
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = params.FilterDescendantsInstances
	local routes = game.HttpService:JSONDecode(m:GetAttribute("RouteReview"))
	local data = {
		mapVersion = m:GetAttribute("MapVersion"),
		routes = {},
		clearanceFailures = {},
		screenFailures = {},
		sightline = { samples = 0, rawMax = 0, combatMax = 0, wholeBaseCrossingsOver95 = 0 },
	}
	local function sweep(route, side, screen)
		local length = 0
		for i = 2, #route.points do
			local a, b = route.points[i - 1], route.points[i]
			local va, vb =
				Vector3.new(ox + side * a[1], y + 4, side * a[2]), Vector3.new(ox + side * b[1], y + 4, side * b[2])
			local radius = if i == 2 then route.spawnAccessRadius or route.radius else route.radius
			local n = math.ceil((vb - va).Magnitude)
			length += (vb - va).Magnitude
			for j = 0, n do
				local hits = workspace:GetPartBoundsInBox(
					CFrame.new(va:Lerp(vb, j / math.max(n, 1))),
					Vector3.new(radius * 2, 5.5, radius * 2),
					overlap
				)
				if #hits > 0 then
					table.insert(
						if screen then data.screenFailures else data.clearanceFailures,
						{ route = route.name, side = side, segment = i, hit = hits[1].Name }
					)
					break
				end
			end
		end
		return length
	end
	for _, r in routes do
		local a, b = sweep(r, -1, false), sweep(r, 1, false)
		table.insert(
			data.routes,
			{
				name = r.name,
				width = r.radius * 2,
				spawnAccessWidth = (r.spawnAccessRadius or r.radius) * 2,
				teamALength = a,
				teamBLength = b,
				estimatedSecondsAt16 = a / 16,
				estimatedParitySeconds = math.abs(a - b) / 16,
				teamBTarget = r.points[#r.points],
			}
		)
	end
	local screen = Instance.new("Part")
	screen.Name = "ReviewPaintScreen"
	screen.Anchored = true
	screen.Size = Vector3.new(12, 8, 0.5)
	screen.Parent = m.Geometry
	for _, at in
		{ CFrame.new(ox, y + 4, 0), CFrame.new(ox, y + 4, 0) * CFrame.Angles(0, math.pi / 2, 0), CFrame.new(
			ox + 62,
			y + 4,
			1
		) }
	do
		screen.CFrame = at
		for _, r in routes do
			if r.name ~= "center" then
				for _, side in { -1, 1 } do
					sweep(r, side, true)
				end
			end
		end
	end
	screen:Destroy()
	local bases = {}
	for _, p in m.Volumes:GetChildren() do
		if p:GetAttribute("VolumeKind") == "ProtectedBase" then
			table.insert(bases, p)
		end
	end
	local function interval(o, v, p)
		local a = p.CFrame:PointToObjectSpace(o)
		local b = p.CFrame:VectorToObjectSpace(v)
		local h = p.Size * 0.5
		local lo, hi = 0, 320
		for _, k in { "X", "Y", "Z" } do
			if math.abs(b[k]) < 1e-6 then
				if math.abs(a[k]) > h[k] then
					return nil
				end
			else
				local t1, t2 = (-h[k] - a[k]) / b[k], (h[k] - a[k]) / b[k]
				lo = math.max(lo, math.min(t1, t2))
				hi = math.min(hi, math.max(t1, t2))
				if lo > hi then
					return nil
				end
			end
		end
		return lo, hi
	end
	for x = -floor.Size.X / 2 + 2, floor.Size.X / 2 - 2, 2 do
		for z = -floor.Size.Z / 2 + 2, floor.Size.Z / 2 - 2, 2 do
			local o = Vector3.new(ox + x, y + 4.5, z)
			local inside = false
			for _, p in bases do
				local q = p.CFrame:PointToObjectSpace(o)
				if math.abs(q.X) <= p.Size.X / 2 and math.abs(q.Z) <= p.Size.Z / 2 then
					inside = true
				end
			end
			if not inside and #workspace:GetPartBoundsInBox(CFrame.new(o), Vector3.new(1, 5, 1), overlap) == 0 then
				for i = 0, 63 do
					local angle = i * math.pi / 32
					local v = Vector3.new(math.cos(angle), 0, math.sin(angle))
					local hit = workspace:Raycast(o, v * 320, params)
					if hit then
						local s = data.sightline
						s.samples += 1
						s.rawMax = math.max(s.rawMax, hit.Distance)
						local len = hit.Distance
						for _, p in bases do
							local enter, leave = interval(o, v, p)
							if enter and enter < len then
								if leave < len - 0.1 and len > 95 then
									s.wholeBaseCrossingsOver95 += 1
								end
								len = math.min(len, enter)
							end
						end
						s.combatMax = math.max(s.combatMax, len)
					end
				end
			end
		end
	end
	data.pass = #data.clearanceFailures == 0
		and #data.screenFailures == 0
		and data.sightline.combatMax <= 95
		and data.sightline.wholeBaseCrossingsOver95 == 0
	report[m:GetAttribute("MapId")] = data
	m:Destroy()
end
root:Destroy()
return game.HttpService:JSONEncode(report)
