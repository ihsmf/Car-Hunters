-- CUE HUNTERS: game constants + UI tokens (mirrors the Figma UI file)
local C = {}
local rgb = Color3.fromRGB

C.UI = {
	Font = Font.fromEnum(Enum.Font.FredokaOne), -- rounded cartoon type, same family as the Figma v4 frames
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
		{ "Settings", "Settings", "Settings", rgb(169, 183, 255), rgb(111, 130, 255) },
		{ "Inventory", "Inventory", "Inventory", rgb(142, 227, 166), rgb(63, 191, 106) },
		{ "Bonus", "Bonus", "Bonus", rgb(255, 158, 200), rgb(255, 92, 158) },
		{ "Shop", "Shop", "Shop", rgb(255, 216, 107), rgb(255, 174, 31) },
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

C.Sounds.Break = C.Sounds.Hit
C.Sounds.Ball1 = C.Sounds.Hit
C.Sounds.Ball2 = C.Sounds.Hit
C.Sounds.Ball3 = C.Sounds.Hit
C.Sounds.Cushion = C.Sounds.Hit
C.Sounds.TrainingRep = C.Sounds.Click
C.Sounds.CuePurchase = C.Sounds.Reward

-- Stable rarity IDs: name, colour, character theme. Income grows x2.2 per tier.
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
	{ "Copper", rgb(93, 227, 245), "Copper Core" },
	{ "Lotus", rgb(245, 218, 93), "Lotus Bloom" },
	{ "Baroque", rgb(174, 93, 245), "Harpsichord" },
	{ "Clockwork", rgb(93, 245, 130), "Automaton" },
	{ "Obsidian", rgb(245, 93, 100), "Obsidian Knight" },
	{ "Jade", rgb(93, 145, 245), "Jade Guardian" },
	{ "Coral", rgb(189, 245, 93), "Reef Keeper" },
	{ "Pearlescent", rgb(245, 93, 233), "Pearl Diver" },
	{ "Sapphire", rgb(93, 245, 212), "Sapphire Regent" },
	{ "Aurora", rgb(245, 168, 93), "Polar Light" },
	{ "Gilded", rgb(123, 93, 245), "Gilded Sentinel" },
	{ "Cobalt", rgb(107, 245, 93), "Cobalt Marshal" },
	{ "Mirage", rgb(245, 93, 151), "Dune Mirage" },
	{ "Monolith", rgb(93, 195, 245), "Stone Colossus" },
	{ "Meteoric", rgb(240, 245, 93), "Meteor Rider" },
	{ "Boreal", rgb(206, 93, 245), "Boreal Ranger" },
	{ "Sunstone", rgb(93, 245, 161), "Sunstone Titan" },
	{ "Runic", rgb(245, 117, 93), "Rune Weaver" },
	{ "Supernova", rgb(93, 113, 245), "Star Eater" },
	{ "Empyrean", rgb(158, 245, 93), "Sky Keeper" },
	{ "Prismatic", rgb(245, 93, 202), "Prism Architect" },
	{ "Singularity", rgb(93, 245, 243), "Event Horizon" },
	{ "Paragon", rgb(245, 199, 93), "Grandmaster" },
	{ "Genesis", rgb(155, 93, 245), "World Smith" },
	{ "Apex", rgb(93, 245, 111), "Apex Champion" },
}
-- Prize balls, one per rarity: odd rarities are solid balls, even ones striped (like a real set); the white
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

-- Variants rolled on every pull (like Big / Huge / Gold ... animals): 75 balls × 7 variants = 525 to collect
C.Variants = { -- name, income multiplier, chance (1 in N, nil = default), size
	{ name = "Normal", mult = 1, scale = 1 },
	{ name = "Big", mult = 2, oneIn = 6, scale = 1.3 },
	{ name = "Huge", mult = 5, oneIn = 30, scale = 1.7 },
	{ name = "Gold", mult = 10, oneIn = 100, scale = 1, color = rgb(255, 200, 50), material = "Foil" },
	{ name = "Diamond", mult = 25, oneIn = 400, scale = 1, color = rgb(150, 235, 255), material = "Glass" },
	{ name = "Galaxy", mult = 60, oneIn = 1500, scale = 1.1, color = rgb(90, 40, 170), material = "ForceField" },
	{ name = "Rainbow", mult = 150, oneIn = 6000, scale = 1.1, color = rgb(255, 120, 220), material = "SmoothPlastic" },
}
local maxWeights={.05,.08,.12,.15,.20,.22,.18}
C.DesignCount=24
C.MaxLuck=1e44
function C.RollVariant(roll,luck) -- roll in [0, 1); rarest first
	local acc = 0
	for v = #C.Variants, 2, -1 do
		local w=1/C.Variants[v].oneIn
  local alpha=math.clamp(math.log10(math.max(1,luck or 1))/44,0,1)
  acc += w+(maxWeights[v]-w)*alpha
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
local designNames = {
{"Apple","Leaf","Blossom","Acorn","Seed","Pear","Cherry","Butterfly"},
{"Sail","Anchor","Drop","Shell","Fish","Wheel","Lantern","Compass"},
{"Sweet","Swirl","Cherry","Star","Heart","Cone","Wafer","Bow"},
{"Fish","Shell","Coral","Jelly","Starfish","Pearl","Bubble","Ray"},
{"Cactus","Agave","Sun","Branch","Scorpion","Dune","Lizard","Bloom"},
{"Flake","Shard","Moon","Seal","Star","Icicle","Peak","Compass"},
{"Flame","Hammer","Ember","Ingot","Wing","Sun","Gear","Shard"},
{"Bamboo","Leaf","Fan","Tea","Fish","Arch","Lantern","Blossom"},
{"Moon","Star","Crater","Comet","Dish","Flag","Rocket","Orbit"},
{"Gear","Hand","Wheel","Key","Bell","Spring","Lamp","Compass"},
{"Bolt","Cloud","Drop","Kite","Swirl","Wing","Sun","Star"},
{"Lotus","Leaf","Bubble","Koi","Dragonfly","Seed","Bloom","Ripple"},
{"Pixel","Heart","Bolt","Gem","Joystick","Eye","Chip","Star"},
{"Saucer","Star","Orbit","Comet","Rocket","Dish","Moon","Satellite"},
{"Crown","Gem","Key","Shield","Rose","Wing","Torch","Star"}
}
function C.DesignName(it)
 local section = it.section or it.id
 local d=it.design or 1
 local family=(section-1)%#designNames+1
 local motif=designNames[family][(d-1)%8+1]
 if d>8 and family==4 and (d-1)%8<3 then motif=({"Nautilus","Glass Float","Coral Crown"})[(d-1)%8+1] end
 local style=d<=8 and "" or d<=16 and " Cameo" or " Reliquary"
 return C.Tables[section][1].." "..motif..style
end
function C.DiscoveryKey(it)
 return string.format("%d_%d_%d",it.section or it.id,it.design or 1,it.v or 1)
end
function C.ItemName(it)
	local v = C.Variants[it.v or 1]
	return (v.name ~= "Normal" and string.upper(v.name) .. " " or "") .. C.DesignName(it)
end

C.Table = { Length = 80 * #R, SegmentLength = 80, Width = 28, StartZ = 80, Lanes = 4, FeltY = 2.8, BallOffset = 1.8 }
C.ShotZone = { HalfWidth = 17.8, StartZ = 70.32, EndZ = 79.1, LowY = 1.3, HighY = 9 }
function C.InShotZone(pos)
	local z = C.ShotZone
	local dz=z.EndZ-pos.Z
 return dz>=0 and pos.X*pos.X+dz*dz<=121 and pos.Y>=z.LowY and pos.Y<=z.HighY
end
function C.LaneX(slot) return -C.Table.Width / 2 + (slot - 0.5) * C.Table.Width / C.Table.Lanes end
-- Play area for the static map.
C.Arena = { HallHalfWidth = 100.8, HallBack = -23.68, CorridorHalfWidth = 34 }
C.ThrowCooldown = 1
C.CueScale = .66
C.MaxEquipped = 8 -- balls on the base table
C.BallSize = 1.3 -- prize ball diameter on the table (Big / Huge variants scale it)
C.MaxInventory = 150

-- Luck grows along the ball's path: every shot starts at the cue's luck (x2 with the Luck pass) and each table adds
-- its own range (C.TableGain), linearly inside the table. The final value L upgrades the rarity:
-- +1 with chance 1 - 1/L, +2 with 1 - 5/L (L >= 5), +3 with 1 - 20/L (L >= 20).
function C.CueLuck(tier)
 local u=(math.clamp(tier,1,#C.Cues)-1)/(#C.Cues-1)
 return math.min(C.MaxLuck,10^(44*u^1.6))
end
function C.FormatLuck(luck)
 if luck<10000 then return string.format("%.2f",luck) end
 local exp=math.floor(math.log10(luck)+1e-12)
 return string.format("%.2g",luck/10^exp).."e"..exp
end
-- Whole number written out in full: 10000000000, never 1e10. Above 1e15 a double holds only ~15 significant digits,
-- so those are kept and the rest is padded with zeros (no float noise such as ...8821361405306...).
function C.FullNumber(n)
 n=math.max(0,math.floor(n+.5))
 if n<1e15 then return string.format("%.0f",n) end
 local lead,frac,exp=string.format("%.14e",n):match("^(%d)%.(%d+)e%+?(%d+)$")
 local digits=lead..frac -- the 15 significant digits a double really has
 exp=tonumber(exp)
 if #digits>exp+1 then digits=digits:sub(1,exp+1) end
 return digits..string.rep("0",exp+1-#digits)
end
-- Live luck while the ball rolls: "1.01" below 1000 (so the count visibly creeps up), then whole digits
function C.LuckText(n)
 if n<1000 then return string.format("%.2f",math.floor(n*100)/100) end
 return C.FullNumber(n)
end
-- Luck a cue adds over the previous tier (what the cue shop shows)
function C.CueLuckGain(tier)
 if tier<=1 then return 1 end
 return C.CueLuck(tier)/C.CueLuck(tier-1)
end
function C.StartLuck(d, passes)
 local luck=C.CueLuck(d.cue or 1)
 if passes and passes.DragonCue then luck=math.max(luck,C.CueLuck(8)) end
 return math.min(C.MaxLuck,luck*((passes and passes.Luck2x) and 2 or 1))
end
-- Every table has its own luck range, growing along the hall: table 1 ×1.5 ... table 75 ×3. Inside a table luck grows
-- linearly with the distance covered: stopping at 80 % of a ×2 table gives ×1.8, not ×2.
function C.TableGain(k)
	local n = #C.Rarities
	return 1.5 + 1.5 * (math.clamp(k, 1, n) - 1) / math.max(1, n - 1)
end
function C.LuckAt(start, dist) -- luck at a distance along the long table (server and client use the same formula)
	local seg = C.Table.SegmentLength
	local L = start
	local d = math.max(0, dist)
	for k = 1, #C.Rarities do
		local g = C.TableGain(k)
		if d >= seg then
			L *= g
			d -= seg
		else
			L *= 1 + (g - 1) * d / seg
			break
		end
		if L >= C.MaxLuck then break end
	end
	return math.min(C.MaxLuck, L)
end
function C.LuckTrack(start, tables) -- luck at the end of every table (no randomness, no lucky tables any more)
	local track = {}
	for k = 1, tables do track[k] = C.LuckAt(start, k * C.Table.SegmentLength) end
	return track, {}
end
-- Each ball has its own fixed odds, independent of the shot's luck: rarity odds × variant odds.
function C.RarityOneIn(r) return math.floor(2 * 10 ^ ((r - 1) * 0.4) + 0.5) end
function C.BallOdds(it) return C.RarityOneIn(it.id) * ((C.Variants[it.v or 1] or C.Variants[1]).oneIn or 1) end
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
function C.RollTime(dist, full) return full and 2.5 + dist / 300 or 1.95 + dist / 700 end
function C.ThrowTime(dist, full) -- until the ball is pocketed
	local a = C.AnimOf(full)
	return a.Windup + C.RollTime(dist, full) + a.Slide
end

-- The tables of the long table (one per zone): name + colour (walls, runners, flight camera)
C.Tables = {
{ "Apple Orchard", Color3.fromHex("ffe654") },
{ "Stone Canal", Color3.fromHex("ffac50") },
{ "Candy Fair", Color3.fromHex("fff173") },
{ "Coral Nursery", Color3.fromHex("ff7462") },
{ "Saguaro Flats", Color3.fromHex("ffd059") },
{ "Frost Garden", Color3.fromHex("c1fffd") },
{ "Ember Kiln", Color3.fromHex("ffbd2f") },
{ "Bamboo Courtyard", Color3.fromHex("ffd855") },
{ "Crescent Crater", Color3.fromHex("a5fff6") },
{ "Brass Workshop", Color3.fromHex("64f5e1") },
{ "Cloud Coast", Color3.fromHex("ffe739") },
{ "Lotus Pond", Color3.fromHex("ff80bb") },
{ "Pixel Plaza", Color3.fromHex("32ffe5") },
{ "Orbital Dock", Color3.fromHex("ffcd5a") },
{ "Royal Gallery", Color3.fromHex("fff488") },
{ "Acorn Hollow", Color3.fromHex("f1ff54") },
{ "Lantern Wharf", Color3.fromHex("ffd450") },
{ "Waffle Market", Color3.fromHex("edff73") },
{ "Pearl Lagoon", Color3.fromHex("ff9862") },
{ "Joshua Dunes", Color3.fromHex("fff659") },
{ "New Year Square", Color3.fromHex("ff4f6a") },
{ "Obsidian Foundry", Color3.fromHex("ffec2f") },
{ "Koi Pavilion", Color3.fromHex("ffff55") },
{ "Meteor Camp", Color3.fromHex("a5f3ff") },
{ "Pendulum Hall", Color3.fromHex("64e8f5") },
{ "Rain Garden", Color3.fromHex("eaff39") },
{ "Waterlily Steps", Color3.fromHex("ff809e") },
{ "Joystick Alley", Color3.fromHex("32eaff") },
{ "Saucer Bay", Color3.fromHex("fff35a") },
{ "Sapphire Court", Color3.fromHex("efff88") },
{ "Maple Canopy", Color3.fromHex("caff54") },
{ "Windmill Lock", Color3.fromHex("fffc50") },
{ "Ribbon Carnival", Color3.fromHex("cdff73") },
{ "Seahorse Reef", Color3.fromHex("ffbc62") },
{ "Agave Canyon", Color3.fromHex("e2ff59") },
{ "Glacier Observatory", Color3.fromHex("c1e5ff") },
{ "Magma Pipes", Color3.fromHex("e2ff2f") },
{ "Tea Terrace", Color3.fromHex("d8ff55") },
{ "Comet Outpost", Color3.fromHex("a5dfff") },
{ "Copper Turbine", Color3.fromHex("64c7f5") },
{ "Thunder Spires", Color3.fromHex("bdff39") },
{ "Dragonfly Marsh", Color3.fromHex("ff8081") },
{ "Hologram Lab", Color3.fromHex("32bcff") },
{ "Saturn Rings", Color3.fromHex("e6ff5a") },
{ "Ruby Bastion", Color3.fromHex("d4ff88") },
{ "Blossom Ridge", Color3.fromHex("a3ff54") },
{ "Sail Loft", Color3.fromHex("daff50") },
{ "Macaron Palace", Color3.fromHex("adff73") },
{ "Jellyfish Grotto", Color3.fromHex("ffdf62") },
{ "Sandstone Mesa", Color3.fromHex("bcff59") },
{ "Aurora Needles", Color3.fromHex("c1d7ff") },
{ "Firebird Forge", Color3.fromHex("b3ff2f") },
{ "Bonsai Sanctuary", Color3.fromHex("b2ff55") },
{ "Lunar Beacons", Color3.fromHex("a5caff") },
{ "Chronometer Vault", Color3.fromHex("64a6f5") },
{ "Storm Kites", Color3.fromHex("90ff39") },
{ "Lotus Lanterns", Color3.fromHex("ff9c80") },
{ "Synthwave Towers", Color3.fromHex("328dff") },
{ "Nebula Fleet", Color3.fromHex("c0ff5a") },
{ "Opal Conservatory", Color3.fromHex("b9ff88") },
{ "Golden Grove", Color3.fromHex("7cff54") },
{ "Tidal Beacon", Color3.fromHex("b2ff50") },
{ "Sugar Comet", Color3.fromHex("8dff73") },
{ "Nautilus Crown", Color3.fromHex("fbff62") },
{ "Sun Arch", Color3.fromHex("97ff59") },
{ "Polar Crown", Color3.fromHex("c1c8ff") },
{ "Solar Furnace", Color3.fromHex("83ff2f") },
{ "Jade Pagoda", Color3.fromHex("8bff55") },
{ "Eclipse Temple", Color3.fromHex("a5b6ff") },
{ "Astral Clock", Color3.fromHex("6485f5") },
{ "Tempest Eye", Color3.fromHex("62ff39") },
{ "Bloom Sanctuary", Color3.fromHex("ffb980") },
{ "Prism Circuit", Color3.fromHex("325eff") },
{ "Galaxy Gate", Color3.fromHex("9bff5a") },
{ "Crown Zenith", Color3.fromHex("9dff88") }
}

-- 15 cue tiers: name, shot power multiplier, price, colours (shaft, butt, inlay, wrap, joint). The Legend cue is x100.
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
	{ "Legend", 100, 5e19, rgb(255, 60, 160), rgb(40, 0, 30), rgb(255, 230, 120), rgb(255, 215, 90), rgb(255, 215, 90) },
} do
	C.Cues[i] = { c[1], c[2], c[3], c[4], shaft = c[4], butt = c[5], inlay = c[6], wrap = c[7], joint = c[8] }
end
C.DragonCue = { -- game pass: x3 until you own a better cue
	"Dragon", 3, 0, rgb(80, 220, 120), tier = 9,
	shaft = rgb(80, 220, 120), butt = rgb(20, 60, 30), inlay = rgb(255, 210, 60), wrap = rgb(10, 30, 15), joint = rgb(255, 210, 60),
}
C.CueParts = { Shaft = "shaft", Butt = "butt", Inlay = "inlay", Wrap = "wrap", Joint = "joint" } -- mesh palette slot -> cue field

C.GymRange = 10
C.DumbbellMax = 50
C.TrainRep = 1.2
function C.LiftCost(lvl) return math.floor(100 * 3 ^ (lvl - 1)) end
function C.RepStrength(lvl) return 3 * 2 ^ (math.clamp(lvl, 1, C.DumbbellMax) - 1) end
function C.CueMult(d, passes)
	local base = C.Cues[d.cue][2]
	if passes and passes.DragonCue then base = math.max(base, C.DragonCue[2]) end
	return base
end
-- Shot power: strength has diminishing returns (cube root), the cue multiplies everything.
-- Every next table needs a bit more power than the last: table k ends at 80 * k * (1 + (k - 1) / 9) power,
-- so the first tables come fast and the last ones are a long-term goal (see tools/balance_sim.py).
local function threshold(k) return 80 * k * (1 + (k - 1) / 9) end
-- Full-power shot reaching the penultimate table with the starter cue.
C.OwnerStrength = math.ceil(((threshold(#C.Rarities-1) / C.Cues[1][2] - 40) / 14)^3)
function C.Distance(power, d, passes) -- studs along the long table
	local raw = power * (40 + 14 * (d.strength or 0) ^ (1 / 3)) * C.CueMult(d, passes)
	local zl, prev = C.Table.SegmentLength, 0
	for k = 1, #C.Rarities do
		local t = threshold(k)
		if raw < t then return (k - 1 + (raw - prev) / (t - prev)) * zl end
		prev = t
	end
	return C.Table.Length
end
function C.ZoneOf(dist) return math.clamp(math.ceil(dist / C.Table.SegmentLength), 1, #C.Rarities) end

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
	if n >= 1e27 then return string.format("%.2e", n) end
	for _, s in { { 1e24, "Sp" }, { 1e21, "Sx" }, { 1e18, "Qi" }, { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if n >= s[1] then return string.format("%.1f%s", n / s[1], s[2]) end
	end
	return tostring(math.floor(n))
end

return C
