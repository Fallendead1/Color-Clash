--!strict
-- The seven main weapons (GDD 07). IDs are permanent; display names may change. All values are the GDD's
-- initial balancing and must be tuned only with a logged DECISIONS.md reason and regression results.
--
-- Families:
--   "projectile" : held automatic fire, server-simulated swept projectiles (Sprayline, Twin Jets)
--   "roller"     : fan flick primary + rolling secondary (Lane Roller)
--   "charger"    : hold/release hitscan with server-measured charge (Linecaster)
--   "lobber"     : volleys of arcing lobes sharing one attack id (Splash Pot)
--   "brush"      : short sweep arc + push secondary (Street Sweeper)
--   "blaster"    : slow explosive projectile, direct OR splash (Popshot)

export type WeaponDef = {
	Id: string,
	DisplayName: string,
	Role: string,
	Family: string,
	Gadget: string,
	Ultimate: string,
	Cost: number,
	Cadence: number,
	MoveSpeedWhileFiring: number?,
	Range: number,
	[string]: any,
}

local Weapons: { [string]: WeaponDef } = {
	sprayline = {
		Id = "sprayline",
		DisplayName = "Sprayline",
		Role = "Balanced automatic shooter",
		Family = "projectile",
		Gadget = "splash_can",
		Ultimate = "color_burst",
		Cost = 1.8,
		Cadence = 0.12,
		Damage = 24,
		Range = 72,
		ProjectileSpeed = 180,
		Gravity = 44,
		SpreadDegrees = 2.5,
		ImpactPaintRadius = 2,
		TrailSampleSpacing = 4,
		TrailDripRadius = 0.75,
		MoveSpeedWhileFiring = 14,
		Muzzles = { "Muzzle" },
		Input = "Hold Primary",
		Description = "Reliable automatic fire. Five hits eliminate.",
	},
	twin_jets = {
		Id = "twin_jets",
		DisplayName = "Twin Jets",
		Role = "Mobile close-range dual sprayers",
		Family = "projectile",
		Gadget = "splash_can",
		Ultimate = "color_burst",
		Cost = 1.3,
		Cadence = 0.09,
		Damage = 18,
		Range = 50,
		ProjectileSpeed = 180,
		Gravity = 44,
		SpreadDegrees = 3,
		ImpactPaintRadius = 1.6,
		TrailSampleSpacing = 4,
		TrailDripRadius = 0.6,
		MoveSpeedWhileFiring = 14,
		Muzzles = { "MuzzleL", "MuzzleR" },
		Dash = {
			Distance = 7,
			Duration = 0.18,
			Cooldown = 2.5,
			Cost = 8,
		},
		Input = "Hold Primary; Secondary dashes",
		Description = "Fast alternating shots and a short lateral dash. Six hits eliminate.",
	},
	lane_roller = {
		Id = "lane_roller",
		DisplayName = "Lane Roller",
		Role = "Broad floor control",
		Family = "roller",
		Gadget = "paint_screen",
		Ultimate = "color_burst",
		Cost = 14, -- per flick
		Cadence = 0.8,
		Windup = 0.18,
		Range = 22,
		FanDegrees = 70,
		CloseRange = 10,
		CloseDamage = 65,
		FarDamage = 40,
		FlickPaintLength = 14,
		FlickPaintWidth = 8,
		Roll = {
			Width = 8,
			MaxSpeed = 12,
			CostPerSecond = 12,
			ContactDamage = 60,
			PerTargetCooldown = 0.65,
		},
		MoveSpeedWhileFiring = 16,
		Muzzles = { "Muzzle" },
		Input = "Primary flicks; hold Secondary to roll",
		Description = "Flick a wide fan or roll a broad strip. Rolling contact hits hard.",
	},
	linecaster = {
		Id = "linecaster",
		DisplayName = "Linecaster",
		Role = "Telegraphed precision charger",
		Family = "charger",
		Gadget = "splash_can",
		Ultimate = "paintstorm",
		Cost = 20,
		MinCharge = 0.15,
		FullCharge = 1.10,
		Recovery = 0.35,
		Cadence = 0.35, -- recovery between shots; charge time is enforced separately
		BaseDamage = 35,
		ChargeDamage = 75,
		Range = 120,
		TracePaintWidth = 2,
		ChargingSpeed = 10,
		FocusFieldOfView = 55,
		MoveSpeedWhileFiring = 10,
		Muzzles = { "Muzzle" },
		Input = "Hold and release Primary; Secondary focuses",
		Description = "Charge for up to 110 damage along a long line. Charging slows you.",
	},
	splash_pot = {
		Id = "splash_pot",
		DisplayName = "Splash Pot",
		Role = "Lobbed arcs over low cover",
		Family = "lobber",
		Gadget = "splash_can",
		Ultimate = "paintstorm",
		Cost = 12,
		Cadence = 0.65,
		VolleyDamageCap = 55,
		LobeAnglesDegrees = { -7, 0, 7 },
		LobeSpeed = 80,
		LobeUpSpeed = 30,
		Gravity = 98.1,
		Range = 52,
		LobePaintRadius = 3,
		MoveSpeedWhileFiring = 14,
		Muzzles = { "Muzzle" },
		Input = "Press or hold Primary",
		Description = "Three arcing lobes clear low cover. One volley deals at most 55.",
	},
	street_sweeper = {
		Id = "street_sweeper",
		DisplayName = "Street Sweeper",
		Role = "Fast short-range brush",
		Family = "brush",
		Gadget = "paint_screen",
		Ultimate = "paintstorm",
		Cost = 4,
		Cadence = 0.22,
		Windup = 0.05,
		Damage = 32,
		Range = 12,
		ArcDegrees = 80,
		SweepPaintLength = 10,
		SweepPaintWidth = 5,
		Push = {
			Width = 3,
			MaxSpeed = 22,
			CostPerSecond = 10,
		},
		MoveSpeedWhileFiring = 14,
		Muzzles = { "Muzzle" },
		Input = "Hold Primary; hold Secondary to push",
		Description = "Rapid short sweeps and a fast painting push.",
	},
	popshot = {
		Id = "popshot",
		DisplayName = "Popshot",
		Role = "Slow explosive pressure",
		Family = "blaster",
		Gadget = "paint_screen",
		Ultimate = "color_burst",
		Cost = 10,
		Cadence = 0.8,
		DirectDamage = 70,
		SplashInnerDamage = 40,
		SplashOuterDamage = 20,
		SplashInnerRadius = 3,
		SplashOuterRadius = 8,
		ProjectileSpeed = 80,
		Gravity = 24,
		Range = 56,
		BurstPaintRadius = 6,
		SpreadDegrees = 0,
		MoveSpeedWhileFiring = 14,
		Muzzles = { "Muzzle" },
		Input = "Press or hold Primary",
		Description = "Slow bursts: 70 direct or 40-20 splash, never both.",
	},
}

local Order = { "sprayline", "twin_jets", "lane_roller", "linecaster", "splash_pot", "street_sweeper", "popshot" }

local function deepFreeze(t: any): any
	for _, v in t do
		if type(v) == "table" and not table.isfrozen(v) then
			deepFreeze(v)
		end
	end
	return table.freeze(t)
end

return deepFreeze({
	Default = "sprayline",
	Order = Order,
	Defs = Weapons,
})
