-- Studio Server Play, after the soak: mirrored humanoid traversals at WalkSpeed 16.
-- Uses the current normalized player rig, no jump, with test walkers mutually non-colliding.
local Players = game:GetService("Players")
local Physics = game:GetService("PhysicsService")
pcall(function()
	Physics:RegisterCollisionGroup("CCRouteWalkers")
end)
Physics:CollisionGroupSetCollidable("CCRouteWalkers", "CCRouteWalkers", false)
local source = assert(Players:GetPlayers()[1].Character, "a normalized character is required")
local wasArchivable = source.Archivable
source.Archivable = true
local prototype = source:Clone()
source.Archivable = wasArchivable
for _, d in prototype:GetDescendants() do
	if d:IsA("LuaSourceContainer") then
		d:Destroy()
	elseif d:IsA("BasePart") then
		d.CollisionGroup = "CCRouteWalkers"
		d.Anchored = false
		d.CanTouch = false
	end
end
local root = Instance.new("Folder")
root.Name = "CCWalkReview"
root.Parent = workspace
local report = {}
local completed, total = 0, 0
for index, template in game.ServerStorage.ColorClashMaps:GetChildren() do
	local map = template:Clone()
	local ox = (index - 1) * 500
	for _, p in map:GetDescendants() do
		if p:IsA("BasePart") then
			p.CFrame += Vector3.new(ox, 1000, 0)
		end
	end
	map.Parent = root
	local records = {}
	report[template:GetAttribute("MapId")] = records
	local routes = game.HttpService:JSONDecode(map:GetAttribute("RouteReview"))
	local canopy = map:GetAttribute("MapId") == "canopy_courts"
	local height, z = if canopy then 10 else 8, if canopy then 60 else 48
	local toe = 35 - math.sqrt(24 * 24 - height * height)
	-- Center and both edges exercise the full 20-stud ramp and the deck in both directions.
	for _, offset in { -8.4, 0, 8.4 } do
		table.insert(
			routes,
			{
				name = "gallery_" .. offset,
				points = {
					{ toe - 5, z + offset, 0 },
					{ toe + 2, z + offset, 1 },
					{ 35, z + offset, height },
					{ 47, z + offset, height },
					{ 54, z + offset, height },
					{ 47, z + offset, height },
					{ 35, z + offset, height },
					{ toe + 2, z + offset, 1 },
					{ toe - 5, z + offset, 0 },
				},
			}
		)
	end
	for _, route in routes do
		local pair = { name = route.name, walks = {} }
		table.insert(records, pair)
		for _, side in { -1, 1 } do
			total += 1
			local npc = prototype:Clone()
			npc.Name = route.name .. side
			local hum = npc:FindFirstChildOfClass("Humanoid")
			hum.Health = hum.MaxHealth
			hum.WalkSpeed = 16
			hum.JumpPower = 0
			hum.AutoRotate = true
			hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
			local first = route.points[1]
			npc:PivotTo(CFrame.new(ox + side * first[1], 1104.5, side * first[2]))
			npc.Parent = root
			npc.HumanoidRootPart:SetNetworkOwner(nil)
			task.spawn(function()
				task.wait(1)
				local record = { side = side, reached = true }
				local started = os.clock()
				for i = 2, #route.points do
					local p = route.points[i]
					hum:MoveTo(Vector3.new(ox + side * p[1], 1103 + (p[3] or 0), side * p[2]))
					if not hum.MoveToFinished:Wait() then
						record.reached = false
						record.failedSegment = i
						break
					end
				end
				record.seconds = os.clock() - started
				table.insert(pair.walks, record)
				npc:Destroy()
				completed += 1
			end)
		end
	end
end
local deadline = os.clock() + 60
while completed < total and os.clock() < deadline do
	task.wait(0.1)
end
for _, records in report do
	for _, pair in records do
		pair.paritySeconds = if #pair.walks == 2 then math.abs(pair.walks[1].seconds - pair.walks[2].seconds) else -1
		pair.pass = #pair.walks == 2 and pair.walks[1].reached and pair.walks[2].reached and pair.paritySeconds <= 0.5
	end
end
root:Destroy()
prototype:Destroy()
Physics:UnregisterCollisionGroup("CCRouteWalkers")
return game.HttpService:JSONEncode(report)
