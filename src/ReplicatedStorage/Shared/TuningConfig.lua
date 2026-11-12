-- Tuning parts: each car has one slot per category; parts add a % to that car's income.
-- Stage 1-2 are traded at Big Tony (contracts board), Stage 3 only drops in the last districts/arenas.
local TuningConfig = {}

TuningConfig.Categories = {
	{ id = "ecu", name = "ECU", icon = "💾" },
	{ id = "boost", name = "Boost", icon = "🌀" },
	{ id = "exhaust", name = "Exhaust", icon = "💨" },
	{ id = "intake", name = "Intake", icon = "🌬️" },
	{ id = "nitro", name = "Nitro", icon = "🧪" },
	{ id = "tires", name = "Tires", icon = "🛞" },
	{ id = "aero", name = "Aero", icon = "🪽" },
}

-- family -> { category, name, icon, bonus per stage }
local FAMILIES = {
	ecu = { cat = "ecu", name = "Chip Tune", icon = "💾", bonus = { 0.10, 0.20, 0.35 } },
	turbo = { cat = "boost", name = "Turbo Kit", icon = "🌀", bonus = { 0.25, 0.50, 0.90 } },
	super = { cat = "boost", name = "Supercharger", icon = "⚙️", bonus = { 0.30, 0.60, 1.00 } },
	exhaust = { cat = "exhaust", name = "Sport Exhaust", icon = "💨", bonus = { 0.08, 0.16, 0.28 } },
	intake = { cat = "intake", name = "Cold Air Intake", icon = "🌬️", bonus = { 0.06, 0.12, 0.20 } },
	nitro = { cat = "nitro", name = "Nitro Kit", icon = "🧪", bonus = { 0.12, 0.25, 0.45 } },
	tires = { cat = "tires", name = "Racing Tires", icon = "🛞", bonus = { 0.05, 0.10, 0.18 } },
	aero = { cat = "aero", name = "Aero Kit", icon = "🪽", bonus = { 0.06, 0.12, 0.22 } },
}
TuningConfig.Families = FAMILIES

TuningConfig.Items = {}
TuningConfig.Order = {}
for _, fam in ipairs({ "ecu", "turbo", "super", "exhaust", "intake", "nitro", "tires", "aero" }) do
	local F = FAMILIES[fam]
	for stage = 1, 3 do
		local id = fam .. stage
		TuningConfig.Items[id] = { id = id, family = fam, cat = F.cat, stage = stage, bonus = F.bonus[stage],
			name = F.name .. " " .. string.rep("I", stage), icon = F.icon }
		table.insert(TuningConfig.Order, id)
	end
end

-- Big Tony's exchange: parts (+ money) -> tuning part. Stage 2 consumes two Stage 1 of the same family.
TuningConfig.Recipes = {
	{ out = "ecu1", parts = { bolts = 15, tire = 6 }, money = 2000 },
	{ out = "intake1", parts = { bolts = 20, tire = 4 }, money = 1500 },
	{ out = "exhaust1", parts = { bolts = 10, tire = 8 }, money = 3000 },
	{ out = "tires1", parts = { tire = 12 }, money = 2500 },
	{ out = "aero1", parts = { bolts = 25, tire = 5 }, money = 4000 },
	{ out = "nitro1", parts = { engine = 3, turbo = 1 }, money = 10000 },
	{ out = "turbo1", parts = { engine = 4, turbo = 2 }, money = 15000 },
	{ out = "super1", parts = { engine = 5, turbo = 2 }, money = 20000 },
}
do
	local stage2 = {}
	for _, r in ipairs(TuningConfig.Recipes) do
		local fam = TuningConfig.Items[r.out].family
		table.insert(stage2, { out = fam .. "2", tune = { [r.out] = 2 }, parts = { core = 1 }, money = r.money * 8 })
	end
	for _, r in ipairs(stage2) do
		table.insert(TuningConfig.Recipes, r)
	end
	for i, r in ipairs(TuningConfig.Recipes) do
		r.id = "r" .. i
	end
end
TuningConfig.RecipeById = {}
for _, r in ipairs(TuningConfig.Recipes) do
	TuningConfig.RecipeById[r.id] = r
end

-- multiplier for one car's tune table { [category] = itemId }
function TuningConfig.CarMult(tune)
	local m = 1
	if type(tune) == "table" then
		for cat, itemId in pairs(tune) do
			local it = TuningConfig.Items[itemId]
			if it and it.cat == cat then
				m = m + it.bonus
			end
		end
	end
	return m
end

return TuningConfig
