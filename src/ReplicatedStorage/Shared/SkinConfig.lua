-- Garage skins: one active at a time, each recolours the whole garage and adds an income bonus.
local C = Color3.fromRGB
local SkinConfig = {}

local function style(o)
	local base = {
		floor = C(212, 214, 218), inlay = C(60, 63, 70), line = C(242, 242, 240), wall = C(38, 40, 46),
		deck = C(238, 238, 236), frame = C(28, 30, 34), accent = C(255, 196, 40), accent2 = C(214, 52, 44),
		door = C(200, 204, 210), bay = C(80, 84, 92),
	}
	for k, v in pairs(o) do
		base[k] = v
	end
	return base
end

-- price: money | tokens (rebirth) | pass (Golden Magnate game pass)
SkinConfig.Skins = {
	{ id = "classic", name = "Classic", icon = "🏁", bonus = 0, style = style({}) },
	{ id = "street", name = "Street Garage", icon = "🧱", bonus = 0.03, money = 250000,
		style = style({ floor = C(150, 150, 154), wall = C(150, 70, 52), deck = C(196, 196, 200), accent = C(255, 140, 40), inlay = C(48, 48, 52) }) },
	{ id = "racing", name = "Racing Team", icon = "🏎️", bonus = 0.06, money = 15000000,
		style = style({ floor = C(236, 236, 240), wall = C(214, 52, 44), deck = C(250, 250, 250), accent = C(255, 255, 255), accent2 = C(30, 30, 34), inlay = C(30, 30, 34), frame = C(20, 20, 24) }) },
	{ id = "chrome", name = "Chrome Lux", icon = "💎", bonus = 0.10, money = 900000000,
		style = style({ floor = C(70, 74, 82), wall = C(196, 200, 208), deck = C(220, 224, 230), frame = C(150, 156, 166), accent = C(110, 200, 255), inlay = C(40, 44, 52), bay = C(56, 60, 68) }) },
	{ id = "midnight", name = "Midnight Club", icon = "🌙", bonus = 0.15, tokens = 15,
		style = style({ floor = C(30, 32, 44), wall = C(18, 20, 30), deck = C(40, 44, 60), frame = C(12, 12, 18), accent = C(150, 110, 255), accent2 = C(80, 200, 255), line = C(170, 150, 255), inlay = C(60, 50, 110), bay = C(44, 46, 62) }) },
	{ id = "golden", name = "Golden Magnate", icon = "👑", bonus = 0.20, pass = "golden_garage",
		style = style({ floor = C(250, 240, 214), wall = C(28, 32, 44), deck = C(250, 244, 226), frame = C(232, 178, 50), accent = C(232, 178, 50), accent2 = C(232, 178, 50), inlay = C(180, 130, 40), bay = C(60, 56, 50) }) },
}
SkinConfig.ById = {}
for i, s in ipairs(SkinConfig.Skins) do
	s.order = i
	SkinConfig.ById[s.id] = s
end

-- rebirth token shop (besides the Midnight skin)
SkinConfig.TokenPerks = {
	{ id = "startSlot", name = "+1 starting bay", icon = "🅿️", cost = 3, max = 3 },
	{ id = "luck", name = "+2% trap luck", icon = "🍀", cost = 4, max = 5, per = 0.02 },
	{ id = "magnet", name = "+25% pickup radius", icon = "🧲", cost = 5, max = 2, per = 0.25 },
}
SkinConfig.TokenPerkById = {}
for _, p in ipairs(SkinConfig.TokenPerks) do
	SkinConfig.TokenPerkById[p.id] = p
end

-- Rebirth rules
SkinConfig.Rebirth = {
	needZone = { [0] = "neon", [1] = "airport", [2] = "canyon" }, -- later rebirths need "rush"
	lateZone = "rush",
	baseMoney = 2500000, growth = 1.8,
	incomePer = 0.25, startMoney = 500,
}
function SkinConfig.RebirthNeeds(n)
	local R = SkinConfig.Rebirth
	return R.needZone[n] or R.lateZone, math.floor(R.baseMoney * R.growth ^ n)
end

return SkinConfig
