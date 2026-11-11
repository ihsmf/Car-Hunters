local C = Color3.fromRGB
local PartConfig = require(script.Parent.PartConfig)
local EconomyConfig = require(script.Parent.EconomyConfig)

local CarConfig = {}

CarConfig.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
CarConfig.Rarities = {
	Common = { index = 1, color = C(176, 184, 196), soft = C(232, 235, 240) },
	Uncommon = { index = 2, color = C(76, 201, 128), soft = C(214, 245, 226) },
	Rare = { index = 3, color = C(72, 152, 255), soft = C(214, 232, 255) },
	Epic = { index = 4, color = C(255, 77, 109), soft = C(255, 220, 226) },
	Legendary = { index = 5, color = C(255, 176, 32), soft = C(255, 238, 200) },
}

CarConfig.MaxLevel = 10
CarConfig.IncomeGrowth = 0.25
CarConfig.ValueMultiplier = 40
CarConfig.UpgradeCostBase = 0.5
CarConfig.UpgradeCostGrowth = 1.35

local list = {
	{ id = "rusty_compact", name = "Rusty Compact", rarity = "Common", style = "compact", income = 2, body = C(176, 108, 70), accent = C(80, 60, 48), tag = "Held together by hope." },
	{ id = "pocket_hatch", name = "Pocket Hatch", rarity = "Common", style = "compact", income = 3, body = C(120, 210, 180), accent = C(255, 255, 255), tag = "Tiny, cheerful, always parks." },
	{ id = "dusty_sedan", name = "Dusty Sedan", rarity = "Common", style = "sedan", income = 4, body = C(160, 162, 170), accent = C(70, 72, 80), tag = "Grandpa's daily driver." },
	{ id = "mule_pickup", name = "Mule Pickup", rarity = "Common", style = "pickup", income = 5, body = C(206, 170, 112), accent = C(90, 70, 50), tag = "Hauls anything, anywhere." },
	{ id = "street_runner", name = "Street Runner", rarity = "Uncommon", style = "sedan", income = 8, body = C(60, 128, 236), accent = C(250, 250, 250), tag = "Quick off the line." },
	{ id = "city_taxi", name = "City Taxi Mk2", rarity = "Uncommon", style = "taxi", income = 10, body = C(255, 206, 50), accent = C(30, 30, 30), tag = "The meter is always running." },
	{ id = "cargo_hopper", name = "Cargo Hopper", rarity = "Uncommon", style = "van", income = 12, body = C(80, 180, 110), accent = C(240, 240, 240), tag = "Delivers before you order." },
	{ id = "boulevard_gt", name = "Boulevard GT", rarity = "Uncommon", style = "sedan", income = 15, body = C(250, 146, 60), accent = C(40, 40, 46), spoiler = true, tag = "Sunday cruising, Monday racing." },
	{ id = "night_phantom", name = "Night Phantom", rarity = "Rare", style = "sport", income = 25, body = C(34, 32, 44), accent = C(40, 200, 255), neon = C(40, 200, 255), tag = "Seen only after midnight." },
	{ id = "iron_hauler", name = "Iron Hauler", rarity = "Rare", style = "truck", income = 32, body = C(118, 126, 140), accent = C(255, 160, 40), tag = "Eighteen tons of attitude." },
	{ id = "redline_coupe", name = "Redline Coupe", rarity = "Rare", style = "sport", income = 40, body = C(225, 46, 52), accent = C(255, 255, 255), spoiler = true, tag = "Lives at the rev limiter." },
	{ id = "volt_cruiser", name = "Volt Cruiser", rarity = "Rare", style = "sedan", income = 50, body = C(50, 178, 184), accent = C(30, 40, 50), neon = C(60, 240, 255), tag = "Silent, smooth, electric." },
	{ id = "turbo_vortex", name = "Turbo Vortex", rarity = "Epic", style = "sport", income = 100, body = C(255, 124, 36), accent = C(30, 30, 36), spoiler = true, neon = C(255, 150, 40), tag = "Spools up a storm." },
	{ id = "chrome_viper", name = "Chrome Viper", rarity = "Epic", style = "supercar", income = 125, body = C(206, 214, 226), accent = C(40, 44, 52), chrome = true, tag = "Mirror finish, venom bite." },
	{ id = "apex_predator", name = "Apex Predator", rarity = "Epic", style = "supercar", income = 150, body = C(36, 120, 70), accent = C(20, 20, 24), spoiler = true, neon = C(90, 255, 120), tag = "Top of the food chain." },
	{ id = "solar_flare", name = "Solar Flare", rarity = "Epic", style = "supercar", income = 200, body = C(255, 214, 50), accent = C(210, 60, 30), neon = C(255, 190, 40), tag = "Too bright to look at." },
	{ id = "neon_specter", name = "Neon Specter", rarity = "Legendary", style = "proto", income = 500, body = C(26, 30, 46), accent = C(40, 230, 255), neon = C(40, 230, 255), tag = "A ghost made of light." },
	{ id = "hyper_nova", name = "Hyper Nova", rarity = "Legendary", style = "proto", income = 650, body = C(40, 20, 24), accent = C(255, 60, 90), neon = C(255, 60, 90), tag = "Born in a dying star." },
	{ id = "quantum_drift", name = "Quantum Drift", rarity = "Legendary", style = "proto", income = 800, body = C(236, 240, 255), accent = C(80, 120, 255), neon = C(110, 150, 255), tag = "Everywhere at once." },
	{ id = "eclipse_titan", name = "Eclipse Titan", rarity = "Legendary", style = "proto", income = 1000, body = C(18, 18, 22), accent = C(255, 190, 40), neon = C(255, 190, 40), tag = "The final hunt." },
}

CarConfig.List = list
CarConfig.ById = {}
CarConfig.ByRarity = { Common = {}, Uncommon = {}, Rare = {}, Epic = {}, Legendary = {} }
for i, def in ipairs(list) do
	def.order = i
	def.value = def.income * CarConfig.ValueMultiplier
	def.maxLevel = CarConfig.MaxLevel
	CarConfig.ById[def.id] = def
	table.insert(CarConfig.ByRarity[def.rarity], def)
end

CarConfig.DropChances = {
	bolts = { Common = 55, Uncommon = 25, Rare = 13, Epic = 6, Legendary = 1 },
	tire = { Common = 40, Uncommon = 30, Rare = 18, Epic = 9, Legendary = 3 },
	engine = { Common = 22, Uncommon = 30, Rare = 26, Epic = 16, Legendary = 6 },
	turbo = { Common = 10, Uncommon = 22, Rare = 30, Epic = 26, Legendary = 12 },
	core = { Common = 4, Uncommon = 10, Rare = 26, Epic = 36, Legendary = 24 },
}

function CarConfig.IncomeAt(def, level)
	return math.floor(def.income * (1 + CarConfig.IncomeGrowth * (level - 1)) + 0.5)
end

function CarConfig.ValueAt(def, level)
	return math.floor(def.value * (1 + 0.3 * (level - 1)))
end

function CarConfig.SellPrice(def, level)
	return math.floor(CarConfig.ValueAt(def, level) * EconomyConfig.SellFraction)
end

function CarConfig.DiscoverBonus(def)
	return math.floor(def.value * EconomyConfig.DiscoverBonusMult)
end

function CarConfig.UpgradeCost(def, level)
	return math.ceil(def.value * CarConfig.UpgradeCostBase * (CarConfig.UpgradeCostGrowth ^ (level - 1)))
end

function CarConfig.UpgradeParts(def, level)
	return PartConfig.PartForRarity[def.rarity], 1 + math.floor((level - 1) / 3)
end

function CarConfig.IsHighTier(rarity)
	return rarity == "Epic" or rarity == "Legendary"
end

function CarConfig.PityRow(partId)
	local row = CarConfig.DropChances[partId]
	local e, l = row.Epic, row.Legendary
	local t = e + l
	return { Common = 0, Uncommon = 0, Rare = 0, Epic = e / t * 100, Legendary = l / t * 100 }
end

function CarConfig.Roll(partId, pity, r1, r2)
	local row = CarConfig.DropChances[partId]
	if pity and pity >= EconomyConfig.PityThreshold - 1 then
		row = CarConfig.PityRow(partId)
	end
	local total = 0
	for _, r in ipairs(CarConfig.RarityOrder) do
		total = total + row[r]
	end
	local target = r1 * total
	local acc = 0
	local rarity = "Legendary"
	for _, r in ipairs(CarConfig.RarityOrder) do
		acc = acc + row[r]
		if row[r] > 0 and target < acc then
			rarity = r
			break
		end
	end
	local pool = CarConfig.ByRarity[rarity]
	local def = pool[math.floor(r2 * #pool) + 1] or pool[#pool]
	return rarity, def
end

function CarConfig.IndexStats(discovered)
	local tiers, found = 0, 0
	for _, r in ipairs(CarConfig.RarityOrder) do
		local all = true
		for _, def in ipairs(CarConfig.ByRarity[r]) do
			if discovered[def.id] then
				found = found + 1
			else
				all = false
			end
		end
		if all then
			tiers = tiers + 1
		end
	end
	local mult = 1 + tiers * EconomyConfig.IndexTierBonus
	if found >= #list then
		mult = mult + EconomyConfig.IndexFullBonus
	end
	return found, #list, tiers, mult
end

function CarConfig.Validate()
	local errors = {}
	local count = 0
	for _, r in ipairs(CarConfig.RarityOrder) do
		if #CarConfig.ByRarity[r] ~= 4 then
			table.insert(errors, r .. ": expected 4 cars, got " .. #CarConfig.ByRarity[r])
		end
		count = count + #CarConfig.ByRarity[r]
	end
	if count ~= 20 then
		table.insert(errors, "expected 20 cars, got " .. count)
	end
	for partId, row in pairs(CarConfig.DropChances) do
		local sum = 0
		for _, r in ipairs(CarConfig.RarityOrder) do
			sum = sum + (row[r] or 0)
		end
		if math.abs(sum - 100) > 1e-9 then
			table.insert(errors, partId .. ": drop chances sum to " .. sum)
		end
	end
	return errors
end

return CarConfig
