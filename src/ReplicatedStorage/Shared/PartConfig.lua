local C = Color3.fromRGB

local PartConfig = {}

PartConfig.Order = { "bolts", "tire", "engine", "turbo", "core" }

PartConfig.Parts = {
	bolts = { id = "bolts", rarity = "Common", color = C(200, 205, 215) },
	tire = { id = "tire", rarity = "Uncommon", color = C(90, 220, 140) },
	engine = { id = "engine", rarity = "Rare", color = C(80, 170, 255) },
	turbo = { id = "turbo", rarity = "Epic", color = C(255, 77, 109) },
	core = { id = "core", rarity = "Legendary", color = C(255, 195, 50) },
}

PartConfig.PartForRarity = {
	Common = "bolts", Uncommon = "tire", Rare = "engine", Epic = "turbo", Legendary = "core",
}

PartConfig.SpawnTables = {
	city = {
		safe = { { "bolts", 85 }, { "tire", 15 } },
		risky = { { "bolts", 50 }, { "tire", 45 }, { "engine", 5 } },
	},
	highway = {
		safe = { { "tire", 70 }, { "engine", 30 } },
		risky = { { "tire", 30 }, { "engine", 60 }, { "turbo", 10 } },
	},
	industrial = {
		safe = { { "engine", 80 }, { "turbo", 20 } },
		risky = { { "engine", 55 }, { "turbo", 45 } },
	},
	neon = {
		safe = { { "turbo", 75 }, { "core", 25 } },
		risky = { { "turbo", 40 }, { "core", 60 } },
	},
}

PartConfig.PointCounts = {
	city = { safe = 18, risky = 8 },
	highway = { safe = 16, risky = 8 },
	industrial = { safe = 16, risky = 8 },
	neon = { safe = 14, risky = 8 },
}

PartConfig.Cooldowns = { safe = { 55, 85 }, risky = { 70, 110 } }

return PartConfig
