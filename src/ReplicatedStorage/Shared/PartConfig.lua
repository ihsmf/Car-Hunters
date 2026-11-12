local C = Color3.fromRGB

local PartConfig = {}

-- 10 parts, 2 per rarity (v13). points = how much a part adds to a throw (CarConfig.ChancesForPoints).
PartConfig.Order = { "bolts", "plugs", "tire", "filter", "engine", "gearbox", "turbo", "intercooler", "core", "chip" }

PartConfig.Parts = {
	bolts = { id = "bolts", rarity = "Common", color = C(200, 205, 215), points = 1, emoji = "🔩", name = "Bolts" },
	plugs = { id = "plugs", rarity = "Common", color = C(230, 230, 236), points = 2, emoji = "🕯️", name = "Spark Plugs" },
	tire = { id = "tire", rarity = "Uncommon", color = C(90, 220, 140), points = 4, emoji = "🛞", name = "Tire" },
	filter = { id = "filter", rarity = "Uncommon", color = C(120, 235, 170), points = 6, emoji = "🌀", name = "Air Filter" },
	engine = { id = "engine", rarity = "Rare", color = C(80, 170, 255), points = 10, emoji = "⚙️", name = "Engine" },
	gearbox = { id = "gearbox", rarity = "Rare", color = C(110, 190, 255), points = 14, emoji = "🔧", name = "Gearbox" },
	turbo = { id = "turbo", rarity = "Epic", color = C(255, 77, 109), points = 22, emoji = "💨", name = "Turbo" },
	intercooler = { id = "intercooler", rarity = "Epic", color = C(255, 120, 150), points = 30, emoji = "❄️", name = "Intercooler" },
	core = { id = "core", rarity = "Legendary", color = C(255, 195, 50), points = 50, emoji = "⚡", name = "Energy Core" },
	chip = { id = "chip", rarity = "Legendary", color = C(255, 225, 90), points = 70, emoji = "💎", name = "Quantum Chip" },
}

-- car upgrades cost the first part of the car's rarity
PartConfig.PartForRarity = {
	Common = "bolts", Uncommon = "tire", Rare = "engine", Epic = "turbo", Legendary = "core",
}

-- Spawns: smooth progression. Every district is centred one notch deeper in the part list
-- (city ~ bolts, colosseum ~ chip); risky spots sit 1 notch deeper, road crates 2 notches deeper.
local ZONES = { "city", "highway", "industrial", "neon", "scrapyard", "docks", "desert", "bridge", "airport", "canyon",
	"circuit", "drift", "storm", "rush", "colosseum" }
local ARENAS = { scrapyard = true, canyon = true, colosseum = true }
PartConfig.SpawnTables, PartConfig.PointCounts = {}, {}
local function table_for(centre)
	local out, sum = {}, 0
	for rank, id in ipairs(PartConfig.Order) do
		local w = math.exp(-((rank - centre) ^ 2) / (2 * 1.1 ^ 2))
		if w > 0.05 then
			table.insert(out, { id, w })
			sum = sum + w
		end
	end
	for _, e in ipairs(out) do
		e[2] = math.max(1, math.floor(e[2] / sum * 100 + 0.5))
	end
	return out
end
for zi, zone in ipairs(ZONES) do
	local c = 1 + (zi - 1) * 0.6
	PartConfig.SpawnTables[zone] = { safe = table_for(c), risky = table_for(c + 1), road = table_for(c + 2) }
	PartConfig.PointCounts[zone] = ARENAS[zone] and { safe = 18, risky = 10, road = 0 } or { safe = zi == 1 and 14 or 12, risky = 8, road = 4 }
end

-- chance that a pickup in this zone is a tuning part instead, and which stages can drop
PartConfig.TuningDrops = {
	scrapyard = { chance = 0.015, stages = { 1 } },
	canyon = { chance = 0.025, stages = { 1, 2 } },
	circuit = { chance = 0.03, stages = { 2 } }, drift = { chance = 0.03, stages = { 2 } },
	storm = { chance = 0.035, stages = { 2, 3 } }, rush = { chance = 0.04, stages = { 2, 3 } },
	colosseum = { chance = 0.06, stages = { 2, 3 } },
}

PartConfig.Cooldowns = { safe = { 45, 70 }, risky = { 60, 95 }, road = { 50, 80 } }
PartConfig.CrateAmount = { road = 2 } -- road crates hold several parts
PartConfig.CrateAmountTier = { [2] = 3, [3] = 4 } -- deeper districts: fatter crates

return PartConfig
