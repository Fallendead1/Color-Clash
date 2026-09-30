-- Original R15 pose clips; no root translation, gameplay movement or marker-driven damage.
local C = require("./common")
local R = C.R
local N = C.new
local clips = {
	Glide = { 0.8, true, 0, -35, 55, -30 },
	Climb = { 0.8, true, 0, 5, -125, 50 },
	Mantle = { 0.55, false, 0.2, -25, -120, -50 },
	Attack_sprayline = { 0.12, false, 0, -5, -65, -15 },
	Attack_twin_jets = { 0.09, false, 0, -6, -65, -65 },
	Attack_lane_roller = { 0.8, false, 0.18, -20, -120, -110 },
	Attack_linecaster = { 0.35, false, 0, -5, -85, -65 },
	Attack_splash_pot = { 0.65, false, 0, -20, -85, -60 },
	Attack_street_sweeper = { 0.22, false, 0.05, -15, -95, -50 },
	Attack_popshot = { 0.8, false, 0, -15, -70, -40 },
	ChargeHold = { 1.1, false, 0, -5, -80, -75 },
	ChargeRelease = { 0.35, false, 0, -12, -95, -80 },
	Dash = { 0.18, false, 0, 12, -60, 35 },
	Throw = { 0.35, false, 0.15, -12, -145, 20 },
	UltPrep = { 0.25, false, 0.25, -10, -145, -20 },
	Gadget = { 0.4, false, 0, -25, -80, -75 },
	Eliminated = { 0.4, false, 0, 25, 65, 55 },
	Spawn = { 0.5, false, 0, -15, -30, -30 },
	Idle = { 2, true, 0, 0, -5, 5 },
	Walk = { 0.7, true, 0, 5, 25, -25 },
	Jump = { 0.4, false, 0, -10, -40, -40 },
	Fall = { 0.6, true, 0, 10, -35, -35 },
	GlideEntry = { 0.12, false, 0, -35, 55, -30 },
	GlideExit = { 0.12, false, 0, 0, -15, -15 },
	RollerSecondary = { 0.8, true, 0, 20, -65, -65 },
	BrushSecondary = { 0.65, true, 0, 25, -60, -50 },
}
local hierarchy = {
	HumanoidRootPart = {
		LowerTorso = {
			UpperTorso = {
				Head = {},
				LeftUpperArm = { LeftLowerArm = { LeftHand = {} } },
				RightUpperArm = { RightLowerArm = { RightHand = {} } },
			},
			LeftUpperLeg = { LeftLowerLeg = { LeftFoot = {} } },
			RightUpperLeg = { RightLowerLeg = { RightFoot = {} } },
		},
	},
}
return function()
	local root = N("Folder", "AnimationSources")
	for key, spec in clips do
		local duration, loop, fire, torso, right, left = table.unpack(spec)
		local seq = N("KeyframeSequence", key, root, {
			Loop = loop,
			Priority = if key == "Idle"
				then R.Enum.AnimationPriority.Idle
				elseif loop then R.Enum.AnimationPriority.Movement
				else R.Enum.AnimationPriority.Action,
		}, {
			AssetKey = key,
			ContractVersion = 1,
			Duration = duration,
			FireTime = fire,
			PublicationStatus = "UNPUBLISHED",
		})
		local times = { 0, math.max(duration * 0.35, fire), duration }
		if times[2] >= duration then
			times[2] = duration * 0.6
		end
		for index, time in times do
			local k = N(
				"Keyframe",
				if index == 1 then "Windup" elseif index == 2 then "Action" else "Recover",
				seq,
				{ Time = time }
			)
			local factor = if index == 2 then 1 elseif loop then 0.72 else 0.1
			local function pose(tree, parent)
				for name, children in tree do
					local angle = if name == "UpperTorso"
						then torso
						elseif name == "RightUpperArm" then right
						elseif name == "LeftUpperArm" then left
						elseif name == "RightLowerArm" or name == "LeftLowerArm" then -25
						elseif name == "RightUpperLeg" then (if key == "Climb" or key == "Walk" then 30 else 8)
						elseif name == "LeftUpperLeg" then (if key == "Climb" or key == "Walk" then -30 else -8)
						else 0
					local p = N("Pose", name, parent, {
						CFrame = R.CFrame.Angles(math.rad(angle * factor), 0, 0),
						Weight = if name == "HumanoidRootPart" or name == "LowerTorso" then 0 else 1,
						EasingStyle = R.Enum.PoseEasingStyle.Linear,
						EasingDirection = R.Enum.PoseEasingDirection.InOut,
					})
					pose(children, p)
				end
			end
			pose(hierarchy, k)
			N(
				"KeyframeMarker",
				if index == 1 then "Windup" elseif index == 3 then "Recover" else "Accent",
				k,
				{ Value = key }
			)
		end
		if not loop then
			local k = N("Keyframe", "FireMarker", seq, { Time = fire })
			N("KeyframeMarker", "Fire", k, { Value = key })
		end
	end
	return root
end
