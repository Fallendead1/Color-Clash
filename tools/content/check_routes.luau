-- Run with Studio execute_luau in Server mode. Temporary copies are 1000 studs above the arena.
-- Pathfinding is geometry evidence; time = path length / 16, NOT a measured human traversal.
local out = {}
for _, template in game.ServerStorage.ColorClashMaps:GetChildren() do
	local m = template:Clone()
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.CFrame += Vector3.new(0, 1000, 0)
		end
	end
	m.Parent = workspace
	task.wait(2)
	local data = { routes = {}, sightline = { length = 0 } }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { m.Geometry, m.PaintSurfaces }
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = params.FilterDescendantsInstances
	local floor = m.PaintSurfaces.arena_floor
	local y = floor.Position.Y + floor.Size.Y / 2
	for x = -floor.Size.X / 2 + 8, floor.Size.X / 2 - 8, 8 do
		for z = -floor.Size.Z / 2 + 8, floor.Size.Z / 2 - 8, 8 do
			local from = Vector3.new(x, y + 4.5, z)
			if #workspace:GetPartBoundsInBox(CFrame.new(from), Vector3.new(1, 5, 1), overlap) == 0 then
				for _, v in { Vector3.xAxis, Vector3.zAxis, Vector3.new(1, 0, 1).Unit, Vector3.new(1, 0, -1).Unit } do
					local hit = workspace:Raycast(from, v * 300, params)
					if hit and hit.Distance > data.sightline.length then
						data.sightline =
							{ length = hit.Distance, from = { x, z }, to = { hit.Position.X, hit.Position.Z } }
					end
				end
			end
		end
	end
	for _, team in { "A", "B" } do
		local start = m.Spawns[team .. (if team == "A" then "1" else "4")].Position + Vector3.new(0, 3, 0)
		for _, z in { -48, 0, 48 } do
			local radius = if z == 0 then 9 else 6
			local path = game:GetService("PathfindingService")
				:CreatePath({ AgentRadius = radius, AgentHeight = 5.5, AgentCanJump = false, WaypointSpacing = 4 })
			local ok, err = pcall(function()
				path:ComputeAsync(start, Vector3.new(0, y + 3, z))
			end)
			local points = path:GetWaypoints()
			local length = 0
			for i = 2, #points do
				length += (points[i].Position - points[i - 1].Position).Magnitude
			end
			table.insert(
				data.routes,
				{
					team = team,
					z = z,
					agentRadius = radius,
					status = if ok then path.Status.Name else tostring(err),
					length = length,
					secondsAt16 = length / 16,
					points = #points,
				}
			)
		end
	end
	out[template:GetAttribute("MapId")] = data
	m:Destroy()
end
return out
