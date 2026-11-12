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

-- Tier 2: engines/turbos/cores everywhere; Tier 3 + arenas also drop tuning parts (see TuningDrops)
do
	local T2 = { road = { { "turbo", 50 }, { "core", 50 } }, safe = { { "engine", 50 }, { "turbo", 40 }, { "core", 10 } }, risky = { { "turbo", 55 }, { "core", 45 } } }
	local T3 = { road = { { "turbo", 30 }, { "core", 70 } }, safe = { { "turbo", 60 }, { "core", 40 } }, risky = { { "turbo", 35 }, { "core", 65 } } }
	for _, id in ipairs({ "docks", "desert", "bridge", "airport", "scrapyard" }) do
		PartConfig.SpawnTables[id] = T2
		PartConfig.PointCounts[id] = { safe = 10, risky = 8, road = 4 }
	end
	for _, id in ipairs({ "circuit", "drift", "storm", "rush", "canyon", "colosseum" }) do
		PartConfig.SpawnTables[id] = T3
		PartConfig.PointCounts[id] = { safe = 10, risky = 8, road = 4 }
	end
	for _, id in ipairs({ "scrapyard", "canyon", "colosseum" }) do
		PartConfig.PointCounts[id] = { safe = 18, risky = 10, road = 0 }
	end
end

-- chance that a pickup in this zone is a tuning part instead, and which stages can drop
PartConfig.TuningDrops = {
	scrapyard = { chance = 0.05, stages = { 1 } },
	canyon = { chance = 0.08, stages = { 1, 2 } },
	circuit = { chance = 0.06, stages = { 2 } }, drift = { chance = 0.06, stages = { 2 } },
	storm = { chance = 0.07, stages = { 2, 3 } }, rush = { chance = 0.08, stages = { 2, 3 } },
	colosseum = { chance = 0.12, stages = { 2, 3 } },
}

PartConfig.Cooldowns = { safe = { 45, 70 }, risky = { 60, 95 }, road = { 50, 80 } }
PartConfig.CrateAmount = { road = 2 } -- road crates hold several parts

return PartConfig
