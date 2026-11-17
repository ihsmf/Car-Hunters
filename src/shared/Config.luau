-- Game constants + UI tokens (mirrors the Figma file "Billiard Hunters — UI")
local C = {}
local rgb = Color3.fromRGB

C.UI = {
	Font = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold),
	Ink = rgb(40, 20, 60),
	Panel = rgb(255, 244, 222),
	Title = rgb(255, 190, 40),
	Money = rgb(140, 255, 120),
	Bad = rgb(255, 90, 90),
	-- key = { icon, label, gradient top, gradient bottom }
	Menu = {
		{ "Settings", "⚙️", "Settings", rgb(169, 183, 255), rgb(111, 130, 255) },
		{ "Inventory", "🎒", "Inventory", rgb(142, 227, 166), rgb(63, 191, 106) },
		{ "Bonus", "🎁", "Bonus", rgb(255, 158, 200), rgb(255, 92, 158) },
		{ "Shop", "💎", "Shop", rgb(255, 216, 107), rgb(255, 174, 31) },
	},
	Cues = { rgb(143, 223, 255), rgb(56, 174, 234) },
	Action = { rgb(255, 216, 107), rgb(255, 174, 31) },
	Red = { rgb(255, 138, 138), rgb(255, 71, 71) },
}

C.Sounds = { -- Roblox library audio; swap for your own IDs if any are unavailable
	Music = "rbxassetid://1837849285",
	Hit = "rbxassetid://9119720940",
	Pocket = "rbxassetid://9118823101",
	Click = "rbxassetid://6895079853",
	Reward = "rbxassetid://9125402735",
}

-- 25 rarities: name, colour, character theme. Income grows x2.2 per tier.
local R = {
	{ "Common", rgb(200, 200, 200), "Rookie" }, { "Uncommon", rgb(90, 220, 90), "Hustler" },
	{ "Rare", rgb(70, 150, 255), "Sniper" }, { "Epic", rgb(170, 80, 255), "Count" },
	{ "Legendary", rgb(255, 170, 0), "King" }, { "Mythic", rgb(255, 60, 90), "Dragon" },
	{ "Ancient", rgb(200, 150, 90), "Pharaoh" }, { "Frozen", rgb(160, 230, 255), "Yeti" },
	{ "Blazing", rgb(255, 110, 30), "Phoenix" }, { "Toxic", rgb(150, 255, 40), "Mutant" },
	{ "Cyber", rgb(0, 255, 200), "Robot" }, { "Pirate", rgb(150, 100, 50), "Captain" },
	{ "Samurai", rgb(230, 40, 60), "Ronin" }, { "Ghost", rgb(210, 225, 255), "Phantom" },
	{ "Divine", rgb(255, 240, 120), "Angel" }, { "Demonic", rgb(160, 0, 40), "Demon" },
	{ "Celestial", rgb(120, 255, 255), "Seraph" }, { "Stellar", rgb(255, 255, 190), "Stargazer" },
	{ "Cosmic", rgb(120, 70, 240), "Astronaut" }, { "Galactic", rgb(80, 30, 170), "Emperor" },
	{ "Rainbow", rgb(255, 120, 255), "Unicorn" }, { "Quantum", rgb(40, 200, 255), "Scientist" },
	{ "Secret", rgb(40, 40, 40), "Anonymous" }, { "Glitch", rgb(255, 0, 255), "Error" },
	{ "Absolute", rgb(255, 0, 140), "Billiard God" },
}
local titles = { "Young", "Swift", "Master", "Grand" }

C.Rarities, C.Characters = {}, {} -- C.Rarities[i] = { name, colour, base income }
for r, v in R do
	local inc = math.floor(2.2 ^ (r - 1))
	C.Rarities[r] = { v[1], v[2], inc }
	for i, t in titles do
		table.insert(C.Characters, {
			name = t .. " " .. v[3],
			rarity = r,
			income = math.floor(inc * (1 + (i - 1) * 0.3)),
			shirt = v[2]:Lerp(rgb(255, 255, 255), (i - 1) * 0.18),
		})
	end
end

C.Table = { Length = 2000, Width = 36, StartZ = 80, Lanes = 4 } -- tools/place.py reads these values
-- Luck multiplier: the long table keeps changing, cycling through these every LuckCycle seconds.
-- With luck L a shot has a (1 - 1/L) chance to land one rarity higher, and at L >= 5 a further (1 - 5/L) chance for +2.
C.LuckSteps = { 1, 2, 3, 5, 10 }
C.LuckCycle = 30
function C.LuckBonus(L, roll1, roll2)
	local bonus = roll1 < 1 - 1 / L and 1 or 0
	if bonus == 1 and L >= 5 and roll2 < 1 - 5 / L then bonus = 2 end
	return bonus
end
C.ThrowCooldown = 1
C.MaxEquipped = 8
C.MaxInventory = 100
C.Anim = { Windup = 1.6, Slide = 0.8 }
function C.RollTime(dist) return 1.4 + dist / 260 end
function C.ThrowTime(dist) return C.Anim.Windup + C.RollTime(dist) + C.Anim.Slide end -- until the ball is pocketed

-- The 25 tables of the long table (one per zone): name + colour used by the flight camera
C.Tables = {
	{ "Oak Club", rgb(150, 220, 120) }, { "Walnut Lounge", rgb(120, 200, 110) }, { "Blue Velvet", rgb(110, 160, 255) },
	{ "Royal Hall", rgb(180, 120, 255) }, { "Golden Palace", rgb(255, 205, 80) }, { "Dragon Lair", rgb(255, 90, 60) },
	{ "Desert Temple", rgb(240, 200, 120) }, { "Frozen Peaks", rgb(170, 230, 255) }, { "Volcano", rgb(255, 120, 40) },
	{ "Toxic Swamp", rgb(150, 255, 60) }, { "Cyber City", rgb(60, 240, 230) }, { "Pirate Cove", rgb(90, 200, 220) },
	{ "Samurai Garden", rgb(255, 150, 190) }, { "Haunted Woods", rgb(170, 120, 230) }, { "Heaven", rgb(255, 250, 220) },
	{ "Underworld", rgb(220, 30, 50) }, { "Sky Islands", rgb(160, 220, 255) }, { "Starlight", rgb(255, 240, 150) },
	{ "Cosmos", rgb(150, 100, 255) }, { "Galaxy", rgb(90, 130, 255) }, { "Rainbow Land", rgb(255, 140, 230) },
	{ "Quantum Lab", rgb(60, 220, 255) }, { "Shadow Realm", rgb(120, 120, 140) }, { "Glitch Zone", rgb(255, 60, 255) },
	{ "Absolute", rgb(255, 80, 170) },
}


C.Cues = { -- name, distance multiplier, price, colour
	{ "Wooden", 1, 0, rgb(236, 196, 132) },
	{ "Maple", 1.3, 500, rgb(250, 220, 160) },
	{ "Carbon", 1.7, 5000, rgb(60, 60, 70) },
	{ "Golden", 2.3, 50000, rgb(255, 200, 40) },
	{ "Diamond", 3, 500000, rgb(140, 240, 255) },
	{ "Plasma", 4, 5e6, rgb(255, 60, 220) },
	{ "Lava", 5.5, 5e7, rgb(255, 80, 0) },
	{ "Starlight", 7.5, 5e8, rgb(255, 255, 180) },
	{ "Galaxy", 10, 5e9, rgb(90, 40, 200) },
	{ "Absolute", 14, 5e10, rgb(255, 0, 140) },
}
C.DragonCue = { "Dragon", 6, 0, rgb(80, 220, 120) }

function C.LiftCost(lvl) return math.floor(50 * 1.6 ^ (lvl - 1)) end
function C.CueMult(d)
	local base = C.Cues[d.cue][2]
	if d.passes.DragonCue then base = math.max(base, C.DragonCue[2]) end
	return base
end
function C.Distance(power, d)
	return math.min(C.Table.Length, power * (40 + d.strength * 0.6) * C.CueMult(d))
end

-- Replace 0 with real IDs from the Creator Dashboard (Monetization → Passes / Developer Products)
C.GamePasses = {
	{ key = "Cash2x", id = 0, icon = "💰", name = "x2 Cash", desc = "Double income" },
	{ key = "Luck2x", id = 0, icon = "🍀", name = "x2 Luck", desc = "50% chance +1 rarity" },
	{ key = "DragonCue", id = 0, icon = "🐉", name = "Dragon Cue", desc = "x6 shot distance" },
	{ key = "GoldStick", id = 0, icon = "🪄", name = "Golden Stick", desc = "+50% income, gold sticks" },
}
C.Products = {
	{ id = 0, cash = 5000, icon = "💵" },
	{ id = 0, cash = 50000, icon = "💰" },
	{ id = 0, cash = 500000, icon = "🏦" },
}

C.Daily = { 100, 250, 500, 1000, 2500, 5000, 15000 }
C.Playtime = { { 5, 300 }, { 15, 1000 }, { 30, 3000 }, { 60, 10000 } } -- minutes, reward

function C.Short(n)
	for _, s in { { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if n >= s[1] then return string.format("%.1f%s", n / s[1], s[2]) end
	end
	return tostring(math.floor(n))
end

return C
