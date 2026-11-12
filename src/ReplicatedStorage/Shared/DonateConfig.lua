-- Golden Magnate stall. Prices in Robux. Grants are performed on the server (DonateService).
local DonateConfig = {}

DonateConfig.Products = {
	{ id = "boost_income", tab = "boost", icon = "💸", name = "x2 Income", desc = "Double garage income for 30 min", price = 49, boost = "income", seconds = 1800 },
	{ id = "boost_luck", tab = "boost", icon = "🍀", name = "Lucky Hour", desc = "Better car rarity from the trap for 15 min", price = 39, boost = "luck", seconds = 900, random = true },
	{ id = "pity", tab = "boost", icon = "🎯", name = "Sure Shot", desc = "Next throw: Epic or better (odds in THROW menu)", price = 59, random = true },
	{ id = "hotdrop", tab = "boost", icon = "📦", name = "Call a Hot Drop", desc = "A rare crate lands in your best district right now", price = 25 },
	{ id = "revive", tab = "boost", icon = "❤️", name = "Insurance", desc = "Get back the loot you lost in your last crash", price = 19 },
	{ id = "cash_s", tab = "pack", icon = "💵", name = "Cash Stack", desc = "5 min of income (min $5K)", price = 25, cash = { 300, 5000 } },
	{ id = "cash_m", tab = "pack", icon = "💰", name = "Cash Bag", desc = "20 min of income (min $25K)", price = 75, cash = { 1200, 25000 } },
	{ id = "cash_l", tab = "pack", icon = "🏦", name = "Cash Vault", desc = "1 hour of income (min $100K)", price = 199, cash = { 3600, 100000 } },
	{ id = "cash_xl", tab = "pack", icon = "👑", name = "Magnate Fortune", desc = "3 hours of income (min $500K)", price = 499, cash = { 10800, 500000 } },
	{ id = "crate_engine", tab = "pack", icon = "⚙️", name = "Engine Crate", desc = "3 engines", price = 29, parts = { engine = 3 } },
	{ id = "crate_turbo", tab = "pack", icon = "🌀", name = "Turbo Crate", desc = "3 turbos", price = 69, parts = { turbo = 3 } },
	{ id = "crate_core", tab = "pack", icon = "⚡", name = "Core Crate", desc = "1 energy core + 2 turbos", price = 149, parts = { core = 1, turbo = 2 } },
	{ id = "offline_x2", tab = "pack", icon = "2x", name = "Double Offline Cash", desc = "Doubles the cash you earned while away", price = 29 },
	{ id = "slots", tab = "pack", icon = "🅿️", name = "+3 Parking", desc = "Three more garage slots", price = 99, slots = 3 },
}

DonateConfig.Passes = {
	{ id = "vip", tab = "pass", icon = "⭐", name = "VIP", desc = "x1.5 income forever + gold name tag", price = 299 },
	{ id = "big_backpack", tab = "pass", icon = "🎒", name = "Huge Backpack", desc = "Double loot capacity", price = 149 },
	{ id = "auto_collect", tab = "pass", icon = "🧲", name = "Mega Magnet", desc = "Double pickup radius", price = 199 },
	{ id = "golden_car", tab = "pass", icon = "🏎️", name = "Golden Magnat GT", desc = "Exclusive gold supercar, earns $2K/s", price = 499 },
	{ id = "double_contracts", tab = "pass", icon = "📜", name = "Contract Boss", desc = "x2 contract rewards", price = 149 },
	{ id = "fast_trap", tab = "pass", icon = "⚡", name = "Fast Trap", desc = "Throw parts twice as often", price = 99 },
	{ id = "golden_garage", tab = "pass", icon = "👑", name = "Golden Garage", desc = "Gold garage skin, +20% income", price = 249 },
}

DonateConfig.ById = {}
for _, list in ipairs({ DonateConfig.Products, DonateConfig.Passes }) do
	for i, it in ipairs(list) do
		it.order = i
		it.isPass = list == DonateConfig.Passes
		DonateConfig.ById[it.id] = it
	end
end

-- random = true: the item changes a random outcome. Roblox requires hiding paid random items where
-- PolicyService says ArePaidRandomItemsRestricted (client hides, server refuses).
function DonateConfig.Available(it, productIds, isStudio, randomRestricted)
	if it.random and randomRestricted then
		return false
	end
	local id = it.isPass and productIds.passes[it.id] or productIds.products[it.id]
	return isStudio or (id ~= nil and id > 0)
end

return DonateConfig
