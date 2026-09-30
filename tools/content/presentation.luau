local C = require("./common")
local R = C.R
local N = C.new
local graphite = { 31, 44, 53 }
local white = { 230, 233, 218 }
local mint = { 100, 213, 181 }
local amber = { 255, 186, 73 }
local function model(parent, name)
	return N("Model", name, parent, nil, { AssetKey = name, ContractVersion = 1 })
end
local function attach(p, name, pos)
	return N("Attachment", name, p, { CFrame = R.CFrame.new(table.unpack(pos or { 0, 0, 0 })) })
end
local function piece(m, name, size, pos, color, shape)
	local p = C.cosmetic(m, name, size, pos, color)
	p.Anchored = false
	if shape then
		p.Shape = shape
	end
	return p
end
local function weld(m, handle)
	m.PrimaryPart = handle
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") and p ~= handle then
			N("WeldConstraint", "ConstructionWeld", p, { Part0 = handle, Part1 = p })
		end
	end
end
local function gun(m, id, muzzle)
	local handle = piece(m, "Handle", { 0.45, 1.05, 0.55 }, { 0, 0, 0 }, graphite)
	attach(handle, "Grip")
	if id == "sprayline" or id == "twin_jets" then
		local dual = id == "twin_jets"
		piece(m, "PressureBody", { 0.9, 0.65, if dual then 1.3 else 2.1 }, { 0, 0.65, -0.6 }, white)
		piece(m, "PaintReservoir", { 0.7, 0.7, 0.75 }, { 0, 0.75, 0.5 }, mint)
		piece(m, "RearBrace", { 0.85, 0.25, 1.4 }, { 0, 0.15, 0.6 }, graphite)
		local barrel = piece(m, "Nozzle", { 0.5, 0.5, 0.7 }, { 0, 0.65, if dual then -1.5 else -2 }, graphite)
		attach(barrel, muzzle or "Muzzle", { 0, 0, -0.36 })
		piece(m, "Sight", { 0.18, 0.2, 0.7 }, { 0, 1.08, -0.7 }, amber)
		for _, x in { -0.47, 0.47 } do
			piece(m, "Inlay", { 0.08, 0.18, 1 }, { x, 0.68, -0.5 }, mint)
		end
	elseif id == "linecaster" then
		piece(m, "Receiver", { 0.85, 0.7, 1.8 }, { 0, 0.65, 0 }, white)
		for _, x in { -0.29, 0.29 } do
			piece(m, "ChargingRail", { 0.2, 0.3, 3.7 }, { x, 0.7, -2 }, graphite)
		end
		piece(m, "ChargeCore", { 0.25, 0.3, 3.3 }, { 0, 0.7, -2 }, mint)
		local barrel = piece(m, "Emitter", { 0.9, 0.9, 0.4 }, { 0, 0.7, -3.8 }, white)
		attach(barrel, "Muzzle", { 0, 0, -0.25 })
		piece(m, "Stock", { 0.65, 1, 0.8 }, { 0, 0.4, 1.2 }, graphite)
		piece(m, "Scope", { 0.5, 0.5, 1.2 }, { 0, 1.25, -0.5 }, amber)
	elseif id == "splash_pot" then
		piece(m, "Basin", { 1.8, 1.15, 1.6 }, { 0, 0.7, -0.75 }, white)
		piece(m, "OpenPaint", { 1.5, 0.12, 1.3 }, { 0, 1.3, -0.75 }, mint)
		for _, x in { -0.6, 0, 0.6 } do
			local spout = piece(m, "Spout", { 0.4, 0.5, 0.8 }, { x, 0.95, -1.65 }, graphite)
			if x == 0 then
				attach(spout, "Muzzle", { 0, 0, -0.45 })
			end
		end
		piece(m, "CarryBar", { 2.1, 0.2, 0.3 }, { 0, 1.8, -0.1 }, amber)
		for _, x in { -0.95, 0.95 } do
			piece(m, "CarrySide", { 0.15, 0.8, 0.3 }, { x, 1.4, -0.1 }, graphite)
		end
	elseif id == "popshot" then
		local b = piece(m, "ExpansionChamber", { 1.4, 1.4, 2.2 }, { 0, 0.8, -0.9 }, white)
		piece(m, "Mouth", { 1.15, 1.15, 0.15 }, { 0, 0.8, -2.08 }, graphite)
		attach(b, "Muzzle", { 0, 0, -1.23 })
		for _, z in { -1.4, -0.4 } do
			piece(m, "CompressionBand", { 1.5, 1.5, 0.16 }, { 0, 0.8, z }, amber)
		end
		piece(m, "PressureCanister", { 0.65, 1, 0.65 }, { 0, 0.8, 0.8 }, mint)
	else
		piece(m, "Shaft", { 0.28, 0.28, 3 }, { 0, 0.35, -1.2 }, white)
		if id == "lane_roller" then
			local roller = piece(m, "RollerDrum", { 4.8, 1.25, 1.25 }, { 0, 0.35, -3 }, mint, R.Enum.PartType.Cylinder)
			attach(roller, "EffectOrigin", { 0, -0.63, 0 })
			for _, x in { -2.5, 2.5 } do
				piece(m, "AxleCap", { 0.3, 1.35, 1.35 }, { x, 0.35, -3 }, graphite, R.Enum.PartType.Cylinder)
			end
			piece(m, "Fork", { 5.4, 0.2, 0.2 }, { 0, 0.35, -2.2 }, amber)
			for _, x in { -2.6, 2.6 } do
				piece(m, "ForkArm", { 0.15, 0.2, 0.9 }, { x, 0.35, -2.65 }, graphite)
			end
		else
			local head = piece(m, "BrushHead", { 2.8, 0.55, 0.8 }, { 0, 0.35, -2.8 }, graphite)
			attach(head, "EffectOrigin", { 0, -0.55, -0.25 })
			for i = -4, 4 do
				piece(m, "Bristle", { 0.25, 0.7, 0.45 }, { i * 0.29, -0.15, -2.9 }, if i % 2 == 0 then mint else white)
			end
			piece(m, "Heel", { 2.8, 0.16, 0.85 }, { 0, 0.7, -2.8 }, amber)
		end
	end
	weld(m, handle)
end
return function()
	local assets = N("Folder", "ColorClashAssets", nil, nil, { ContractVersion = 1, ContentVersion = 1 })
	local weapons = N("Folder", "Weapons", assets)
	for _, id in { "sprayline", "twin_jets", "lane_roller", "linecaster", "splash_pot", "street_sweeper", "popshot" } do
		local m = model(weapons, id)
		if id == "twin_jets" then
			gun(model(m, "Left"), id, "MuzzleL")
			gun(model(m, "Right"), id, "MuzzleR")
		else
			gun(m, id)
		end
	end
	local character = N("Folder", "Character", assets)
	N("HumanoidDescription", "AthleteDescription", character, {
		HeightScale = 1,
		WidthScale = 1,
		DepthScale = 1,
		HeadScale = 1,
		BodyTypeScale = 0,
		ProportionScale = 0,
		HeadColor = R.Color3.fromRGB(211, 166, 121),
		LeftArmColor = R.Color3.fromRGB(211, 166, 121),
		RightArmColor = R.Color3.fromRGB(211, 166, 121),
		TorsoColor = R.Color3.fromRGB(31, 44, 53),
		LeftLegColor = R.Color3.fromRGB(45, 63, 72),
		RightLegColor = R.Color3.fromRGB(45, 63, 72),
	})
	local gear = model(character, "AthleteGear")
	local tank = piece(gear, "Tank", { 1.25, 1.5, 0.65 }, { 0, 0, 0.85 }, white)
	piece(gear, "TeamPaint", { 0.9, 1, 0.1 }, { 0, 0, 1.22 }, mint):SetAttribute("TeamTint", true)
	piece(gear, "TankCap", { 0.7, 0.25, 0.7 }, { 0, 0.87, 0.85 }, graphite)
	for _, x in { -0.63, 0.63 } do
		piece(gear, "TankFrame", { 0.16, 1.6, 0.72 }, { x, 0, 0.85 }, graphite)
	end
	for _, x in { -0.58, 0.58 } do
		piece(gear, "Harness", { 0.17, 1.65, 0.1 }, { x, 0, -0.58 }, amber)
	end
	piece(gear, "ChestBadge", { 0.6, 0.4, 0.08 }, { 0, 0.3, -0.61 }, white):SetAttribute("TeamTint", true)
	attach(tank, "BodyMount", { 0, 0, -0.85 })
	weld(gear, tank)
	local effects = N("Folder", "Effects", assets)
	for _, key in
		{
			"Muzzle_sprayline",
			"Muzzle_twin_jets",
			"Muzzle_linecaster",
			"Muzzle_splash_pot",
			"Muzzle_popshot",
			"Beam",
			"DashWake",
			"Burst",
			"Storm",
			"Fizzle",
			"LaunchMarker",
			"ScreenHit",
			"ScreenBreak",
			"ShieldHit",
			"ChargeReady",
			"Impact",
			"LaunchTransit",
			"LaunchLanding",
			"ResultsCue",
		}
	do
		local fx = model(effects, key)
		fx:SetAttribute("Lifetime", if string.find(key, "Muzzle") then 0.07 elseif key == "Storm" then 0.5 else 0.35)
		local count = if key == "Burst" then 8 elseif key == "Storm" then 12 elseif key == "LaunchMarker" then 4 else 3
		for i = 1, count do
			local a = i / count * math.pi * 2
			local radius = if key == "LaunchMarker"
				then 2.3
				elseif key == "Storm" then 4
				elseif key == "Burst" then 2
				else 0.4
			local p = C.cosmetic(
				fx,
				"Cue",
				if key == "Storm" then { 0.07, 1.5, 0.07 } else { 0.16, 0.16, 0.5 },
				{ math.cos(a) * radius, if key == "Storm" then 3 else 0.1, math.sin(a) * radius },
				white
			)
			p.Material = R.Enum.Material.Neon
			p.Transparency = 0.25
		end
		-- Explicit origin keeps scattered child geometry centered at the dispatched cue.
		local origin = C.cosmetic(fx, "Origin", { 0.05, 0.05, 0.05 }, { 0, 0, 0 }, white)
		origin.Transparency = 1
		fx.PrimaryPart = origin
	end
	for _, key in { "SplashCan", "ColorBurstCapsule", "PaintstormBeacon", "PaintScreen" } do
		local m = model(effects, key)
		m:SetAttribute("Lifetime", 1)
		local p =
			C.cosmetic(m, "Body", if key == "PaintScreen" then { 12, 8, 0.12 } else { 0.7, 1, 0.7 }, { 0, 0, 0 }, white)
		m.PrimaryPart = p
		if key == "PaintScreen" then
			p.Transparency = 0.75
			for _, x in { -6, 6 } do
				C.cosmetic(m, "Post", { 0.18, 8, 0.3 }, { x, 0, 0 }, white)
			end
			for _, y in { -4, 4 } do
				C.cosmetic(m, "Rail", { 12, 0.18, 0.3 }, { 0, y, 0 }, white)
			end
		else
			C.cosmetic(m, "Cap", { 0.8, 0.2, 0.8 }, { 0, 0.6, 0 }, graphite)
			C.cosmetic(m, "Band", { 0.74, 0.25, 0.74 }, { 0, 0.1, 0 }, amber)
			if key == "PaintstormBeacon" then
				C.cosmetic(m, "Antenna", { 0.12, 0.8, 0.12 }, { 0, 1, 0 }, graphite)
			end
			if key == "ColorBurstCapsule" then
				p.Size = R.Vector3.new(1.2, 1.4, 1.2)
				for _, x in { -0.7, 0.7 } do
					C.cosmetic(m, "Stabilizer", { 0.15, 0.8, 1.4 }, { x, 0, 0 }, amber)
				end
			end
		end
	end
	-- Published IDs are inserted only from a reviewed permission manifest; source assets are separate.
	N("Folder", "Animations", assets, nil, { PublicationStatus = "SOURCE_ONLY_UPLOAD_REQUIRED" })
	N("Folder", "Sounds", assets, nil, { PublicationStatus = "SOURCE_ONLY_UPLOAD_REQUIRED" })
	return assets
end
