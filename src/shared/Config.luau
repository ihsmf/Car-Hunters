-- Game constants + UI tokens (mirrors the Figma file "Billiard Hunters — UI")
local C = {}
local rgb = Color3.fromRGB

C.UI = {
	Font = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold),
	Ink = rgb(40, 20, 60),
	Panel = rgb(27, 21, 48), -- dark panel background (#1B1530)
	Card = rgb(42, 34, 69), -- cards / rows inside panels (#2A2245)
	Line = rgb(78, 64, 120), -- thin borders on dark surfaces
	Muted = rgb(170, 160, 205), -- secondary text on dark
	Text = rgb(255, 255, 255),
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

-- 50 rarities: name, colour, character theme. Income grows x2.2 per tier.
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
	{ "Absolute", rgb(255, 0, 140), "Billiard God" }, { "Mega", rgb(255, 90, 0), "Titan" },
	{ "Ultra", rgb(0, 180, 255), "Warden" }, { "Hyper", rgb(255, 230, 0), "Sprinter" },
	{ "Nova", rgb(255, 150, 220), "Starborn" }, { "Nebula", rgb(150, 80, 255), "Voyager" },
	{ "Eclipse", rgb(70, 50, 100), "Shade" }, { "Solar", rgb(255, 200, 60), "Sunlord" },
	{ "Lunar", rgb(200, 210, 255), "Moonwalker" }, { "Abyssal", rgb(20, 80, 140), "Kraken" },
	{ "Volcanic", rgb(230, 70, 20), "Magma" }, { "Thunder", rgb(255, 240, 90), "Stormcaller" },
	{ "Crystal", rgb(170, 255, 240), "Gemsmith" }, { "Ethereal", rgb(230, 220, 255), "Spirit" },
	{ "Primal", rgb(120, 180, 60), "Beastmaster" }, { "Arcane", rgb(130, 60, 220), "Archmage" },
	{ "Mythril", rgb(180, 230, 230), "Paladin" }, { "Chrono", rgb(210, 170, 90), "Timekeeper" },
	{ "Void", rgb(45, 20, 70), "Voidwalker" }, { "Astral", rgb(90, 200, 255), "Starwalker" },
	{ "Infinity", rgb(255, 120, 180), "Infinite" }, { "Omega", rgb(255, 40, 40), "Omega" },
	{ "Supreme", rgb(255, 215, 0), "Sovereign" }, { "Eternal", rgb(240, 240, 255), "Immortal" },
	{ "Transcendent", rgb(255, 180, 255), "Ascended" }, { "Legend", rgb(255, 60, 160), "Cue Master" },
}
-- 50 prize balls, one per rarity: odd rarities are solid balls, even ones striped (like a real set); the white
-- spot carries the number. C.Rarities[i] = { name, colour, base income }.
C.Rarities, C.Balls = {}, {}
for r, v in R do
	local inc = math.floor(2.2 ^ (r - 1))
	C.Rarities[r] = { v[1], v[2], inc }
	local h, sat, val = v[2]:ToHSV()
	C.Balls[r] = {
		name = v[3] .. " Ball",
		rarity = r,
		income = inc,
		body = r % 2 == 1 and v[2] or Color3.fromRGB(250, 248, 240),
		band = v[2],
		ring = Color3.fromHSV((h + 0.5) % 1, math.min(1, sat + 0.2), math.max(0.6, val)), -- complementary trim
	}
end

-- Variants rolled on every pull (like Big / Huge / Gold ... animals): 50 balls x 7 variants = 350 to collect
C.Variants = { -- name, income multiplier, chance (1 in N, nil = default), size
	{ name = "Normal", mult = 1, scale = 1 },
	{ name = "Big", mult = 2, oneIn = 6, scale = 1.3 },
	{ name = "Huge", mult = 5, oneIn = 30, scale = 1.7 },
	{ name = "Gold", mult = 10, oneIn = 100, scale = 1, color = rgb(255, 200, 50), material = "Foil" },
	{ name = "Diamond", mult = 25, oneIn = 400, scale = 1, color = rgb(150, 235, 255), material = "Glass" },
	{ name = "Galaxy", mult = 60, oneIn = 1500, scale = 1.1, color = rgb(90, 40, 170), material = "ForceField" },
	{ name = "Rainbow", mult = 150, oneIn = 6000, scale = 1.1, color = rgb(255, 120, 220), material = "SmoothPlastic" },
}
function C.RollVariant(roll) -- roll in [0, 1); rarest first
	local acc = 0
	for v = #C.Variants, 2, -1 do
		acc += 1 / C.Variants[v].oneIn
		if roll < acc then return v end
	end
	return 1
end
-- mesh colours of a prize ball (PrizeBall palette): variants recolour the whole ball, the trim keeps the rarity hint
function C.BallOverrides(it)
	local b, V = C.Balls[it.id], C.Variants[it.v or 1]
	return {
		Body = V.color or b.body,
		Band = V.color and V.color:Lerp(Color3.new(1, 1, 1), 0.3) or b.band,
		Trim = b.ring,
		Spot = Color3.fromRGB(250, 248, 240),
	}
end
function C.ItemIncome(it) return C.Balls[it.id].income * C.Variants[it.v or 1].mult end
function C.ItemName(it)
	local v = C.Variants[it.v or 1]
	return (v.name ~= "Normal" and string.upper(v.name) .. " " or "") .. C.Balls[it.id].name
end

C.Table = { Length = 4000, Width = 36, StartZ = 80, Lanes = 4 } -- tools/place.py reads these values
-- Play area (tools/place.py builds floors/colliders from it, Map.luau surrounds it with Terrain block mountains)
C.Arena = { HallHalfWidth = 120, HallBack = -64, CorridorHalfWidth = 34 }
C.ThrowCooldown = 1
C.MaxEquipped = 8 -- balls on the base table
C.BallSize = 1.3 -- prize ball diameter on the table (Big / Huge variants scale it)
C.MaxInventory = 150

-- Luck grows along the ball's path: every shot starts at 1 (2 with the x2 Luck pass), every table crossed adds a
-- little, sometimes a "lucky table" adds a lot. The final value L upgrades the rarity:
-- +1 with chance 1 - 1/L, +2 with 1 - 5/L (L >= 5), +3 with 1 - 20/L (L >= 20).
function C.StartLuck(d, passes)
	return (passes and passes.Luck2x) and 2 or 1
end
function C.LuckTrack(start, tables, rnd) -- rnd() -> [0, 1); returns luck after each table and the lucky tables
	local track, lucky, L = {}, {}, start
	for k = 1, tables do
		L += 0.03 + rnd() * 0.09
		if rnd() < 0.06 then
			L += 0.5 + rnd() * 1.5
			lucky[k] = true
		end
		track[k] = math.floor(L * 100 + 0.5) / 100
	end
	return track, lucky
end
function C.LuckBonus(L, r1, r2, r3)
	if r1 >= 1 - 1 / L then return 0 end
	if L < 5 or r2 >= 1 - 5 / L then return 1 end
	if L < 20 or r3 >= 1 - 20 / L then return 2 end
	return 3
end

-- Cinematics: full show for Epic+ pulls that are near your best ever, the rest get the short version
C.FullCinematicRarity = 4
C.Anim = { Full = { Windup = 2.2, Slide = 0.8 }, Short = { Windup = 0.6, Slide = 0.3 } }
function C.AnimOf(full) return full and C.Anim.Full or C.Anim.Short end
function C.RollTime(dist, full) return full and 1.4 + dist / 300 or 0.8 + dist / 700 end
function C.ThrowTime(dist, full) -- until the ball is pocketed
	local a = C.AnimOf(full)
	return a.Windup + C.RollTime(dist, full) + a.Slide
end

-- The 50 tables of the long table (one per zone): name + colour (walls, runners, flight camera)
C.Tables = {}
for r, v in R do C.Tables[r] = { v[1] .. " Table", v[2] } end

-- 15 cue tiers: name, shot power multiplier, price, colours (shaft, butt, inlay, wrap, joint). Cues only add power.
C.Cues = {}
for i, c in {
	{ "Wooden", 1, 0, rgb(222, 184, 128), rgb(110, 64, 32), rgb(240, 225, 200), rgb(60, 50, 45), rgb(190, 190, 195) },
	{ "Maple", 1.2, 400, rgb(240, 214, 160), rgb(70, 40, 22), rgb(255, 245, 225), rgb(40, 40, 50), rgb(200, 200, 205) },
	{ "Ash", 1.4, 8e3, rgb(214, 196, 160), rgb(40, 40, 44), rgb(230, 60, 60), rgb(30, 30, 34), rgb(210, 210, 215) },
	{ "Carbon", 1.65, 1.5e5, rgb(55, 55, 62), rgb(25, 25, 28), rgb(0, 200, 255), rgb(20, 20, 24), rgb(150, 150, 160) },
	{ "Ebony", 1.9, 3e6, rgb(235, 215, 175), rgb(28, 18, 14), rgb(255, 215, 120), rgb(110, 20, 30), rgb(230, 190, 90) },
	{ "Golden", 2.2, 6e7, rgb(255, 210, 90), rgb(160, 110, 20), rgb(255, 245, 200), rgb(80, 50, 10), rgb(255, 225, 120) },
	{ "Ivory", 2.55, 1.2e9, rgb(250, 245, 230), rgb(200, 180, 150), rgb(60, 140, 120), rgb(140, 110, 80), rgb(225, 225, 235) },
	{ "Crystal", 2.95, 2.5e10, rgb(190, 240, 255), rgb(80, 160, 220), rgb(255, 255, 255), rgb(40, 90, 150), rgb(220, 245, 255) },
	{ "Inferno", 3.4, 5e11, rgb(255, 140, 50), rgb(90, 15, 10), rgb(255, 220, 80), rgb(40, 10, 8), rgb(255, 120, 40) },
	{ "Frost", 3.9, 1e13, rgb(200, 240, 255), rgb(40, 90, 160), rgb(150, 220, 255), rgb(20, 50, 100), rgb(230, 250, 255) },
	{ "Storm", 4.5, 2e14, rgb(220, 220, 255), rgb(50, 40, 120), rgb(255, 240, 90), rgb(30, 25, 70), rgb(200, 200, 255) },
	{ "Shadow", 5.2, 4e15, rgb(70, 50, 100), rgb(15, 10, 20), rgb(170, 90, 255), rgb(10, 8, 14), rgb(120, 80, 170) },
	{ "Celestial", 6, 8e16, rgb(255, 250, 225), rgb(240, 200, 90), rgb(120, 220, 255), rgb(255, 255, 255), rgb(255, 230, 150) },
	{ "Cosmic", 7, 2e18, rgb(120, 70, 240), rgb(20, 10, 50), rgb(255, 130, 230), rgb(40, 20, 90), rgb(200, 160, 255) },
	{ "Legend", 8, 5e19, rgb(255, 60, 160), rgb(40, 0, 30), rgb(255, 230, 120), rgb(255, 215, 90), rgb(255, 215, 90) },
} do
	C.Cues[i] = { c[1], c[2], c[3], c[4], shaft = c[4], butt = c[5], inlay = c[6], wrap = c[7], joint = c[8] }
end
C.DragonCue = { -- game pass: x3 until you own a better cue
	"Dragon", 3, 0, rgb(80, 220, 120), tier = 9,
	shaft = rgb(80, 220, 120), butt = rgb(20, 60, 30), inlay = rgb(255, 210, 60), wrap = rgb(10, 30, 15), joint = rgb(255, 210, 60),
}
C.CueParts = { Shaft = "shaft", Butt = "butt", Inlay = "inlay", Wrap = "wrap", Joint = "joint" } -- mesh palette slot -> cue field

-- Dumbbell looks better every 5 levels: plate colour + size
local PLATES = { rgb(70, 70, 78), rgb(165, 170, 180), rgb(220, 50, 50), rgb(50, 110, 230), rgb(255, 200, 50), rgb(150, 235, 255), rgb(120, 60, 220) }
function C.DumbbellLook(lvl)
	local band = math.min(#PLATES, 1 + (lvl - 1) // 5)
	return PLATES[band], 1 + math.min(lvl, 60) * 0.008, band
end
C.GymRange = 10 -- studs from the training spot

function C.LiftCost(lvl) return math.floor(100 * 3 ^ (lvl - 1)) end
C.TrainRep = 1.2 -- seconds per training rep
function C.RepStrength(lvl) return lvl * 3 end
function C.CueMult(d, passes)
	local base = C.Cues[d.cue][2]
	if passes and passes.DragonCue then base = math.max(base, C.DragonCue[2]) end
	return base
end
-- Shot power: strength has diminishing returns (cube root), the cue multiplies everything.
-- Every next table needs a bit more power than the last: table k ends at 80 * k * (1 + (k - 1) / 9) power,
-- so the first tables come fast and the last ones are a long-term goal (see tools/balance_sim.py).
local function threshold(k) return 80 * k * (1 + (k - 1) / 9) end
function C.Distance(power, d, passes) -- studs along the long table
	local raw = power * (40 + 14 * (d.strength or 0) ^ (1 / 3)) * C.CueMult(d, passes)
	local zl, prev = C.Table.Length / #C.Rarities, 0
	for k = 1, #C.Rarities do
		local t = threshold(k)
		if raw < t then return (k - 1 + (raw - prev) / (t - prev)) * zl end
		prev = t
	end
	return C.Table.Length
end
function C.ZoneOf(dist) return math.clamp(math.ceil(dist / (C.Table.Length / #C.Rarities)), 1, #C.Rarities) end

-- Replace 0 with real IDs from the Creator Dashboard (Monetization → Passes / Developer Products)
C.GamePasses = {
	{ key = "Cash2x", id = 0, badge = "2X", name = "x2 Cash", desc = "Double income from every ball" },
	{ key = "Luck2x", id = 0, badge = "2X", name = "x2 Luck", desc = "Every shot starts with double luck" },
	{ key = "DragonCue", id = 0, badge = "3X", name = "Dragon Cue", desc = "x3 shot distance until you own a better cue" },
	{ key = "GoldStick", id = 0, badge = "+50%", name = "Income Boost", desc = "+50% income from every ball" },
	{ key = "GoldenBall", id = 0, badge = "GOLD", name = "Golden Ball", desc = "Your shot ball turns gold with a sparkle trail" },
}
C.Products = {
	{ id = 0, cash = 5000 },
	{ id = 0, cash = 50000 },
	{ id = 0, cash = 500000 },
}

C.Daily = { 100, 250, 500, 1000, 2500, 5000, 15000 }
C.Playtime = { { 5, 300 }, { 15, 1000 }, { 30, 3000 }, { 60, 10000 } } -- minutes, reward

function C.Short(n)
	for _, s in { { 1e24, "Sp" }, { 1e21, "Sx" }, { 1e18, "Qi" }, { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if n >= s[1] then return string.format("%.1f%s", n / s[1], s[2]) end
	end
	return tostring(math.floor(n))
end

return C
