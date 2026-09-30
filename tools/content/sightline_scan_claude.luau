-- Independent sightline scan (Claude, Phase 10 review). Run in Studio's EDIT datamodel (command bar or MCP).
-- For each map in ServerStorage.ColorClashMaps: clone into a scratch folder, take standing points on real walkable
-- floors (the first surface below is a registered PaintSurface facing up) on a 2-stud grid, cast 64 horizontal rays at
-- 4.5-stud eye height (max 250 studs) against Geometry + PaintSurfaces, and keep lines whose whole length stays out of
-- ProtectedBase / OutOfBounds volumes. Reports GROUND (floor below Y 101) and ELEVATED (ramps/terraces) separately.
-- A finite sample, not a proof over every position/angle.
local maps = game.ServerStorage.ColorClashMaps
local results = {}
for _, template in maps:GetChildren() do
	local folder = Instance.new("Folder")
	folder.Parent = workspace
	local m = template:Clone()
	m.Parent = folder
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { m.Geometry, m.PaintSurfaces }
	local vols = {}
	for _, v in m.Volumes:GetChildren() do
		if v:IsA("BasePart") then
			table.insert(vols, v)
		end
	end
	local function inVolume(p)
		for _, v in vols do
			local lp = v.CFrame:PointToObjectSpace(p)
			local h = v.Size / 2
			if math.abs(lp.X) <= h.X and math.abs(lp.Y) <= h.Y and math.abs(lp.Z) <= h.Z then
				return true
			end
		end
		return false
	end
	local cf, size = m:GetBoundingBox()
	local top = cf.Position.Y + size.Y / 2 + 5
	local dirs = {}
	for k = 0, 63 do
		local a = k * math.pi / 32
		table.insert(dirs, Vector3.new(math.cos(a), 0, math.sin(a)))
	end
	local stats = { ground = { max = 0, over = 0, where = "" }, elevated = { max = 0, over = 0, where = "" } }
	for x = cf.Position.X - size.X / 2 + 1, cf.Position.X + size.X / 2 - 1, 2 do
		for z = cf.Position.Z - size.Z / 2 + 1, cf.Position.Z + size.Z / 2 - 1, 2 do
			local down = workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -size.Y - 20, 0), params)
			if down and down.Normal.Y > 0.7 and down.Instance:IsDescendantOf(m.PaintSurfaces) then
				local eye = down.Position + Vector3.new(0, 4.5, 0)
				if not inVolume(eye) then
					local bucket = if down.Position.Y < 101 then stats.ground else stats.elevated
					for _, d in dirs do
						local hit = workspace:Raycast(eye, d * 250, params)
						local len = if hit then (hit.Position - eye).Magnitude else 250
						if len > 60 then
							local clean = true
							for s = 2, len - 0.5, 2 do
								if inVolume(eye + d * s) then
									clean = false
									break
								end
							end
							if clean and not inVolume(eye + d * (len - 0.5)) then
								if len > 95 then
									bucket.over += 1
								end
								if len > bucket.max then
									bucket.max = len
									bucket.where = string.format("%s (%.0f,%.0f)", down.Instance.Name, eye.X, eye.Z)
								end
							end
						end
					end
				end
			end
		end
	end
	folder:Destroy()
	table.insert(results, string.format("%s v%s: GROUND max %.1f (%d lines >95) | ELEVATED max %.1f from %s (%d lines >95)", template.Name, tostring(template:GetAttribute("MapVersion")), stats.ground.max, stats.ground.over, stats.elevated.max, stats.elevated.where, stats.elevated.over))
end
return table.concat(results, "\n")
