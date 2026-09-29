--!strict
-- Gadgets and ultimates (GDD 08). Values are the starting specification.

local function deepFreeze(t: any): any
	for _, v in t do
		if type(v) == "table" and not table.isfrozen(v) then
			deepFreeze(v)
		end
	end
	return table.freeze(t)
end

return deepFreeze({
	Gadgets = {
		splash_can = {
			Id = "splash_can",
			DisplayName = "Splash Can",
			Kind = "throwable",
			Cost = 55,
			Prep = 0.15,
			Fuse = 1.2,
			ThrowSpeed = 55,
			ThrowUpSpeed = 20,
			Gravity = 98.1,
			MaxActivePerOwner = 1,
			MinInterval = 0.75,
			InnerRadius = 4,
			OuterRadius = 10,
			InnerDamage = 70,
			OuterDamage = 25,
			PaintRadius = 8,
			MaxLifetime = 6,
			Description = "Throw a can that bursts after 1.2 s: 70 close, falling to 25 at 10 studs.",
		},
		paint_screen = {
			Id = "paint_screen",
			DisplayName = "Paint Screen",
			Kind = "screen",
			Cost = 55,
			Width = 12,
			Height = 8,
			Thickness = 0.6,
			ForwardDistance = 6,
			Lifetime = 5,
			Health = 250,
			MaxActivePerOwner = 1,
			MinInterval = 1,
			Description = "Place a 12-stud screen for 5 s that blocks enemy shots.",
		},
	},
	Ultimates = {
		color_burst = {
			Id = "color_burst",
			DisplayName = "Color Burst",
			Kind = "throwable",
			Prep = 0.25,
			Fuse = 0.7,
			ThrowSpeed = 55,
			ThrowUpSpeed = 20,
			Gravity = 98.1,
			PaintRadius = 18,
			InnerRadius = 5,
			OuterRadius = 12,
			InnerDamage = 80,
			OuterDamage = 40,
			MaxLifetime = 6,
			Description = "A large capsule: 18-stud paint burst, 80 close and 40 out to 12 studs.",
		},
		paintstorm = {
			Id = "paintstorm",
			DisplayName = "Paintstorm",
			Kind = "storm",
			Prep = 0.25, -- GDD 08.3 "same throw preparation" as Color Burst (D-007)
			Fuse = 0.5,
			ThrowSpeed = 55,
			ThrowUpSpeed = 20,
			Gravity = 98.1,
			Radius = 18,
			Duration = 6,
			TickInterval = 0.5,
			TickDamage = 5,
			RainHeight = 24,
			RainSampleSpacing = 2,
			MaxLifetime = 6,
			Description = "A beacon that rains paint for 6 s in an 18-stud circle. Roofs block it.",
		},
	},
})
