-- Gears (v24): timed boosts bought for money at Big Tony. A gear is applied to one car (car.gear = { id, exp }):
-- income gears boost that car, speed/luck gears boost the player while the geared car is parked (best one counts).
-- Tony's stock changes every Window seconds; every player has their own stock, seeded by userId + window + gear.
local GearConfig = {}

GearConfig.Window = 300

GearConfig.List = {
	{
		id = "nitro", name = "Nitro Can", icon = "💨", desc = "Run faster while this car is parked.",
		effects = { speed = 1.5 }, seconds = 300, tier = 1, color = Color3.fromRGB(80, 170, 255),
		k = 25, minPrice = 300, stock = { chance = 0.9, min = 1, max = 3 },
	},
	{
		id = "clover", name = "Lucky Clover", icon = "🍀", desc = "Better car odds while this car is parked.",
		effects = { luck = 1.5 }, seconds = 600, tier = 2, color = Color3.fromRGB(80, 220, 110),
		k = 60, minPrice = 800, stock = { chance = 0.7, min = 1, max = 2 },
	},
	{
		id = "cashturbo", name = "Cash Turbo", icon = "💵", desc = "This car earns more money.",
		effects = { income = 1.5 }, seconds = 600, tier = 2, color = Color3.fromRGB(120, 230, 90),
		k = 27, minPrice = 600, stock = { chance = 0.75, min = 1, max = 3 },
	},
	{
		id = "rocket", name = "Rocket Boots", icon = "🚀", desc = "Run MUCH faster while this car is parked.",
		effects = { speed = 2 }, seconds = 300, tier = 3, color = Color3.fromRGB(60, 230, 255),
		k = 50, minPrice = 1200, stock = { chance = 0.55, min = 1, max = 2 },
	},
	{
		id = "moneystorm", name = "Money Storm", icon = "💰", desc = "This car earns double money.",
		effects = { income = 2 }, seconds = 600, tier = 4, color = Color3.fromRGB(255, 200, 50),
		k = 65, minPrice = 2500, stock = { chance = 0.4, min = 1, max = 1 },
	},
	{
		id = "goldengine", name = "Golden Engine", icon = "👑", desc = "Double money on this car + better car odds while parked.",
		effects = { income = 2, luck = 1.5 }, seconds = 900, tier = 5, color = Color3.fromRGB(255, 215, 0),
		k = 150, minPrice = 5000, stock = { chance = 0.15, min = 1, max = 1 },
	},
}

GearConfig.ById = {}
for i, def in ipairs(GearConfig.List) do
	def.index = i
	GearConfig.ById[def.id] = def
end

-- the stock window a server time falls in
function GearConfig.WindowAt(t)
	return math.floor(t / GearConfig.Window)
end

-- this player's stock in one window: { [id] = qty } (0 when the gear is not offered). Same result on server and client.
function GearConfig.Stock(userId, window)
	local out = {}
	local uid = math.abs(math.floor(tonumber(userId) or 0)) % 2147483647
	window = math.floor(tonumber(window) or 0)
	for i, def in ipairs(GearConfig.List) do
		local rng = Random.new((uid * 31 + window) * 7 + i * 1000003)
		local st = def.stock
		if rng:NextNumber() < st.chance then
			out[def.id] = rng:NextInteger(st.min, st.max)
		else
			out[def.id] = 0
		end
	end
	return out
end

-- price follows the highest income the player has had (un-parking cars does not make gears cheaper)
function GearConfig.Price(def, peakIncome)
	return math.floor(math.max(def.minPrice, (tonumber(peakIncome) or 0) * def.k) + 0.5)
end

local function fmt(m)
	if m % 1 == 0 then
		return string.format("x%d", m)
	end
	return "x" .. string.format("%.2f", m):gsub("0+$", "")
end

-- "x2 INCOME" / "x1.5 LUCK" / "x2 SPEED" / "x2 INCOME + x1.5 LUCK"
function GearConfig.Label(def)
	local parts = {}
	for _, kind in ipairs({ "income", "luck", "speed" }) do
		local m = def.effects[kind]
		if m then
			table.insert(parts, fmt(m) .. " " .. string.upper(kind))
		end
	end
	return table.concat(parts, " + ")
end

-- the def of a car's gear if it is still running at time `now`, else nil
function GearConfig.Active(gear, now)
	if type(gear) ~= "table" or type(gear.exp) ~= "number" then
		return nil
	end
	local def = GearConfig.ById[gear.id]
	if def and gear.exp > (now or os.time()) then
		return def
	end
	return nil
end

-- income multiplier of one owned car (1 without an active income gear)
function GearConfig.CarMult(car, now)
	local def = car and GearConfig.Active(car.gear, now)
	return def and def.effects.income or 1
end

return GearConfig
