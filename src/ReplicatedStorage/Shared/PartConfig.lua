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
		road = { { "tire", 50 }, { "engine", 40 }, { "turbo", 10 } },
		safe = { { "bolts", 85 }, { "tire", 15 } },
		risky = { { "bolts", 50 }, { "tire", 45 }, { "engine", 5 } },
	},
	highway = {
		road = { { "engine", 50 }, { "turbo", 40 }, { "core", 10 } },
		safe = { { "tire", 70 }, { "engine", 30 } },
		risky = { { "tire", 30 }, { "engine", 60 }, { "turbo", 10 } },
	},
	industrial = {
		road = { { "engine", 25 }, { "turbo", 55 }, { "core", 20 } },
		safe = { { "engine", 80 }, { "turbo", 20 } },
		risky = { { "engine", 55 }, { "turbo", 45 } },
	},
	neon = {
		road = { { "turbo", 45 }, { "core", 55 } },
		safe = { { "turbo", 75 }, { "core", 25 } },
		risky = { { "turbo", 40 }, { "core", 60 } },
	},
}

PartConfig.PointCounts = {
	city = { safe = 14, risky = 8, road = 4 },
	highway = { safe = 12, risky = 8, road = 4 },
	industrial = { safe = 12, risky = 8, road = 4 },
	neon = { safe = 10, risky = 8, road = 4 },
}

PartConfig.Cooldowns = { safe = { 45, 70 }, risky = { 60, 95 }, road = { 50, 80 } }
PartConfig.CrateAmount = { road = 2 } -- road crates hold several parts

return PartConfig
