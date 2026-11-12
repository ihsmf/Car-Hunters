-- Pit Stop upgrades (in-game money). Effects are read on the server through ShopService.
local ShopConfig = {}

local function curve(base, growth, max)
	local t = {}
	for lvl = 1, max do
		t[lvl] = math.floor(base * growth ^ (lvl - 1) / 50 + 0.5) * 50
	end
	return t
end

ShopConfig.Perks = {
	{ id = "sneakers", icon = "👟", name = "Sneakers", desc = "+6% run speed", max = 5, costs = curve(800, 2.4, 5), per = 0.06 },
	{ id = "backpack", icon = "🎒", name = "Backpack", desc = "+5 loot capacity", max = 5, costs = curve(1500, 2.5, 5), per = 5 },
	{ id = "magnet", icon = "🧲", name = "Magnet", desc = "+2.5 studs pickup radius", max = 4, costs = curve(2000, 2.6, 4), per = 2.5 },
	{ id = "airbag", icon = "🛡️", name = "Airbag", desc = "Survive one car hit (recharges)", max = 3, costs = { 25000, 100000, 400000 }, cooldowns = { 180, 120, 60 } },
	{ id = "scanner", icon = "📡", name = "Scanner", desc = "Lv1: rare parts on the map. Lv2: Hot Drop alert 15s early", max = 2, costs = { 15000, 120000 } },
	{ id = "multi", icon = "🎰", name = "Multi Catch", desc = "+1 car per throw (up to 4)", max = 3, costs = { 6000, 80000, 900000 } },
	{ id = "lucky", icon = "🍀", name = "Lucky Trap", desc = "+1.5% better car rarity", max = 5, costs = curve(5000, 3, 5), per = 0.015 },
	{ id = "turbo", icon = "💰", name = "Turbo Garage", desc = "+8% garage income", max = 5, costs = curve(10000, 3, 5), per = 0.08 },
	{ id = "quick", icon = "⏱️", name = "Quick Start", desc = "Faster respawn, longer spawn shield", max = 3, costs = curve(4000, 3, 3), respawn = { 2.4, 1.9, 1.4 } },
}

ShopConfig.ById = {}
for i, p in ipairs(ShopConfig.Perks) do
	p.order = i
	ShopConfig.ById[p.id] = p
end

function ShopConfig.NextCost(id, level)
	local p = ShopConfig.ById[id]
	return p and p.costs[(level or 0) + 1] or nil
end

return ShopConfig
