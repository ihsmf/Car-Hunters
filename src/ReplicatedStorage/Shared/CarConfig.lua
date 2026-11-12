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
CarConfig.IncomeMult = 1.3 -- v9: every car earns 30 % more (first rebirth came too slowly in play)
CarConfig.ValueMultiplier = 40
CarConfig.UpgradeCostBase = 0.5
CarConfig.UpgradeCostGrowth = 1.35

-- Fictional parody cars: inspired by familiar body styles, no real names, logos or badges.
local list = {
	{ id = "furd_fiasta", name = "Furd Fiasta", rarity = "Common", style = "compact", income = 2, body = C(40, 110, 220), accent = C(30, 30, 36), tag = "Small car, big dreams." },
	{ id = "dodje_caravon", name = "Dodje Caravon", rarity = "Common", style = "van", income = 3, body = C(150, 30, 40), accent = C(30, 30, 36), tag = "Seats the whole crew." },
	{ id = "furd_f150", name = "Furd F-One-Fifty", rarity = "Common", style = "pickup", income = 4, body = C(190, 196, 204), accent = C(30, 30, 36), tag = "Hauls anything, anywhere." },
	{ id = "awdi_a4", name = "Awdi A-Four", rarity = "Common", style = "sedan", income = 5, body = C(196, 200, 206), accent = C(30, 30, 36), tag = "Four doors of pure order." },
	{ id = "bmv_m3", name = "BMV M-Tree", rarity = "Uncommon", style = "sedan", income = 8, body = C(30, 90, 190), accent = C(20, 20, 24), tag = "Blinkers sold separately." },
	{ id = "mursides_e", name = "Mursides E-Klass", rarity = "Uncommon", style = "sedan", income = 10, body = C(20, 20, 24), accent = C(200, 200, 210), tag = "The boss has arrived." },
	{ id = "tezla_model3", name = "Tezla Model Tree", rarity = "Uncommon", style = "sedan", income = 12, body = C(236, 238, 242), accent = C(20, 20, 24), tag = "Silent, smooth, electric." },
	{ id = "jagwar_xe", name = "Jagwar XE", rarity = "Uncommon", style = "sedan", income = 15, body = C(16, 70, 50), accent = C(200, 200, 210), tag = "Purrs on every corner." },
	{ id = "furd_mustank", name = "Furd Mustank", rarity = "Rare", style = "muscle", income = 25, body = C(210, 40, 36), accent = C(240, 240, 240), spoiler = true, tag = "Wild horse on wheels." },
	{ id = "dodje_chalenjer", name = "Dodje Chalenjer", rarity = "Rare", style = "muscle", income = 32, body = C(255, 120, 20), accent = C(20, 20, 24), tag = "Burnouts before breakfast." },
	{ id = "ranje_rover", name = "Ranje Rover", rarity = "Rare", style = "suv", income = 40, body = C(232, 232, 228), accent = C(20, 20, 24), tag = "Royalty rides high." },
	{ id = "bmv_m4", name = "BMV M-Fore", rarity = "Rare", style = "sport", income = 50, body = C(120, 190, 60), accent = C(20, 20, 24), spoiler = true, tag = "Lives at the rev limiter." },
	{ id = "mursides_g", name = "Mursides G-Vagon", rarity = "Epic", style = "suv", income = 100, body = C(24, 26, 28), accent = C(200, 200, 210), tag = "A brick that outruns you." },
	{ id = "awdi_r8", name = "Awdi R-Ate", rarity = "Epic", style = "supercar", income = 125, body = C(200, 204, 210), accent = C(20, 20, 24), chrome = true, tag = "Engine behind, world ahead." },
	{ id = "jagwar_ftype", name = "Jagwar F-Tipe", rarity = "Epic", style = "sport", income = 150, body = C(150, 20, 30), accent = C(20, 20, 24), tag = "Long hood, loud roar." },
	{ id = "mazeratti_gt", name = "Mazeratti GranTurizmo", rarity = "Epic", style = "sport", income = 200, body = C(20, 40, 90), accent = C(200, 200, 210), tag = "Opera on four wheels." },
	{ id = "lamborgini_hurakan", name = "Lamborgini Hurakan", rarity = "Legendary", style = "supercar", income = 500, body = C(120, 220, 40), accent = C(20, 20, 24), neon = C(120, 255, 60), tag = "A storm with number plates." },
	{ id = "tezla_cybertrak", name = "Tezla Cybertrak", rarity = "Legendary", style = "pickup", income = 650, body = C(176, 180, 186), accent = C(20, 20, 24), chrome = true, tag = "Low-poly from the future." },
	{ id = "mazeratti_mc20", name = "Mazeratti MC-Twenty", rarity = "Legendary", style = "supercar", income = 800, body = C(240, 240, 236), accent = C(30, 60, 160), neon = C(110, 150, 255), tag = "Carbon, thunder, style." },
	{ id = "lamborgini_aventadoor", name = "Lamborgini Aventadoor", rarity = "Legendary", style = "proto", income = 1000, body = C(255, 150, 10), accent = C(20, 20, 24), neon = C(255, 190, 40), spoiler = true, tag = "The final hunt." },
	-- ---- wave 2
	{ id = "fiat_500", name = "Fiyat Five-Hundo", rarity = "Common", style = "compact", income = 2, body = C(150, 220, 190), accent = C(240, 240, 240), tag = "Espresso-sized." },
	{ id = "mini_kooper", name = "Mini Kooper", rarity = "Common", style = "compact", income = 3, body = C(200, 30, 40), accent = C(240, 240, 240), tag = "Go-kart with a roof." },
	{ id = "volksvagen_gulf", name = "Volksvagen Gulf GTI", rarity = "Common", style = "compact", income = 4, body = C(236, 236, 236), accent = C(200, 30, 30), tag = "The hot hatch original." },
	{ id = "hunda_civik", name = "Hunda Civik Type-Arr", rarity = "Common", style = "sedan", income = 5, body = C(250, 250, 250), accent = C(200, 30, 30), spoiler = true, tag = "VTEC just kicked in." },
	{ id = "jeap_rangler", name = "Jeap Rangler", rarity = "Uncommon", style = "suv", income = 9, body = C(250, 190, 20), accent = C(20, 20, 24), tag = "Roads are optional." },
	{ id = "mazta_miyata", name = "Mazta Miyata", rarity = "Uncommon", style = "sport", income = 11, body = C(220, 30, 30), accent = C(20, 20, 24), tag = "The answer is always Miyata." },
	{ id = "subaroo_wrx", name = "Subaroo WRX", rarity = "Uncommon", style = "sedan", income = 13, body = C(20, 70, 180), accent = C(220, 180, 60), spoiler = true, tag = "Born on gravel." },
	{ id = "chevy_kamaro", name = "Chevy Kamaro", rarity = "Uncommon", style = "muscle", income = 14, body = C(255, 200, 0), accent = C(20, 20, 24), tag = "More than meets the eye." },
	{ id = "toyoda_supera", name = "Toyoda Supera", rarity = "Rare", style = "sport", income = 28, body = C(255, 110, 20), accent = C(20, 20, 24), spoiler = true, tag = "Ten-second legend." },
	{ id = "chevy_korvette", name = "Chevy Korvette", rarity = "Rare", style = "sport", income = 36, body = C(210, 20, 30), accent = C(20, 20, 24), tag = "American thunder." },
	{ id = "nisan_gtr", name = "Nisan GT-Arr", rarity = "Rare", style = "sport", income = 45, body = C(236, 236, 240), accent = C(20, 20, 24), spoiler = true, tag = "They call it the monster." },
	{ id = "porshe_911", name = "Porshe Nine-Eleven", rarity = "Rare", style = "sport", income = 48, body = C(255, 200, 0), accent = C(20, 20, 24), tag = "Engine in the trunk. On purpose." },
	{ id = "bentli_kontinental", name = "Bentli Kontinental", rarity = "Epic", style = "sport", income = 110, body = C(110, 16, 30), accent = C(200, 200, 210), tag = "A mansion that does 200." },
	{ id = "rolz_fantom", name = "Rolz-Roice Fantom", rarity = "Epic", style = "sedan", income = 140, body = C(240, 236, 222), accent = C(200, 200, 210), chrome = false, tag = "Quiet money." },
	{ id = "maklaren_p1", name = "MakLaren P-One", rarity = "Epic", style = "supercar", income = 170, body = C(0, 150, 200), accent = C(20, 20, 24), spoiler = true, tag = "Built in a wind tunnel." },
	{ id = "ferarri_488", name = "Ferarri Four-Ate-Ate", rarity = "Epic", style = "supercar", income = 190, body = C(220, 16, 20), accent = C(20, 20, 24), tag = "Red goes faster." },
	{ id = "ferarri_laferarri", name = "Ferarri LaFerarri", rarity = "Legendary", style = "proto", income = 600, body = C(190, 0, 16), accent = C(20, 20, 24), neon = C(255, 60, 40), tag = "The The-Car." },
	{ id = "pagany_wyra", name = "Pagany Wyra", rarity = "Legendary", style = "proto", income = 750, body = C(120, 140, 165), accent = C(20, 20, 24), chrome = true, tag = "Art that breaks the wind." },
	{ id = "konigseg_agera", name = "Konigseg Agera", rarity = "Legendary", style = "proto", income = 900, body = C(244, 244, 244), accent = C(20, 20, 24), neon = C(60, 160, 255), spoiler = true, tag = "The ghost of speed." },
	{ id = "bugati_shiron", name = "Bugati Shiron", rarity = "Legendary", style = "proto", income = 1200, body = C(20, 70, 180), accent = C(20, 20, 24), neon = C(60, 140, 255), tag = "The king of top speed." },
	-- ---- wave 3 (v8): 8 more per rarity
	{ id = "hunda_jazzy", name = "Hunda Jazzy", rarity = "Common", style = "compact", income = 2, body = C(240, 120, 40), accent = C(30, 30, 36), tag = "Fits a fridge, somehow." },
	{ id = "toyoda_korolla", name = "Toyoda Korolla", rarity = "Common", style = "sedan", income = 3, body = C(170, 176, 186), accent = C(30, 30, 36), tag = "Runs forever, never complains." },
	{ id = "nisan_mikra", name = "Nisan Mikra", rarity = "Common", style = "compact", income = 2, body = C(250, 200, 210), accent = C(30, 30, 36), tag = "Parks in a shoebox." },
	{ id = "kia_soal", name = "Kia Soal", rarity = "Common", style = "compact", income = 3, body = C(110, 200, 80), accent = C(30, 30, 36), tag = "A toaster with attitude." },
	{ id = "hyunday_elantro", name = "Hyunday Elantro", rarity = "Common", style = "sedan", income = 4, body = C(30, 60, 120), accent = C(200, 200, 210), tag = "Sensible shoes on wheels." },
	{ id = "skodda_oktavia", name = "Skodda Oktavia", rarity = "Common", style = "sedan", income = 4, body = C(40, 120, 90), accent = C(200, 200, 210), tag = "Room for everything." },
	{ id = "shevy_spork", name = "Shevy Spork", rarity = "Common", style = "compact", income = 2, body = C(80, 200, 220), accent = C(30, 30, 36), tag = "Tiny, cheerful, loud horn." },
	{ id = "volvoo_240", name = "Volvoo Two-Forty", rarity = "Common", style = "sedan", income = 5, body = C(120, 30, 40), accent = C(200, 200, 210), tag = "A brick of pure safety." },
	{ id = "toyoda_takoma", name = "Toyoda Takoma", rarity = "Uncommon", style = "pickup", income = 9, body = C(200, 170, 110), accent = C(30, 30, 36), tag = "Mud is a lifestyle." },
	{ id = "furd_brongo", name = "Furd Brongo", rarity = "Uncommon", style = "suv", income = 11, body = C(60, 140, 200), accent = C(20, 20, 24), tag = "Doors off, fun on." },
	{ id = "hunda_akkord", name = "Hunda Akkord", rarity = "Uncommon", style = "sedan", income = 10, body = C(236, 236, 240), accent = C(20, 20, 24), tag = "Quietly perfect." },
	{ id = "volksvagen_bitle", name = "Volksvagen Bitle", rarity = "Uncommon", style = "compact", income = 8, body = C(250, 220, 60), accent = C(240, 240, 240), tag = "Round, happy, unstoppable." },
	{ id = "awdi_tt", name = "Awdi Tee-Tee", rarity = "Uncommon", style = "sport", income = 13, body = C(200, 204, 210), accent = C(20, 20, 24), tag = "Bauhaus on four wheels." },
	{ id = "lexxus_is", name = "Lexxus I-Ess", rarity = "Uncommon", style = "sedan", income = 12, body = C(20, 20, 24), accent = C(200, 200, 210), tag = "Silk gloves, sharp claws." },
	{ id = "dodje_ramm", name = "Dodje Ramm", rarity = "Uncommon", style = "pickup", income = 14, body = C(150, 20, 30), accent = C(200, 200, 210), tag = "Built like a battering ram." },
	{ id = "mitsubishy_evo", name = "Mitsubishy Evo", rarity = "Uncommon", style = "sedan", income = 15, body = C(30, 30, 36), accent = C(220, 180, 60), spoiler = true, tag = "Rally stage in a suit." },
	{ id = "nisan_350z", name = "Nisan Three-Fifty Zed", rarity = "Rare", style = "sport", income = 26, body = C(255, 170, 30), accent = C(20, 20, 24), tag = "Sideways is the right way." },
	{ id = "bmv_x5", name = "BMV X-Five", rarity = "Rare", style = "suv", income = 30, body = C(30, 40, 60), accent = C(200, 200, 210), tag = "School run, autobahn speed." },
	{ id = "kadillak_eskalade", name = "Kadillak Eskalade", rarity = "Rare", style = "suv", income = 38, body = C(20, 20, 24), accent = C(200, 200, 210), tag = "Arrives before it arrives." },
	{ id = "toyoda_landkruiser", name = "Toyoda Landkruiser", rarity = "Rare", style = "suv", income = 34, body = C(230, 226, 216), accent = C(20, 20, 24), tag = "Crosses deserts for fun." },
	{ id = "shelbi_kobra", name = "Shelbi Kobra", rarity = "Rare", style = "muscle", income = 44, body = C(30, 60, 160), accent = C(240, 240, 240), tag = "Two stripes, zero chill." },
	{ id = "pontiak_firebyrd", name = "Pontiak Firebyrd", rarity = "Rare", style = "muscle", income = 40, body = C(20, 20, 24), accent = C(220, 180, 60), tag = "Eagle on the hood, fire in the heart." },
	{ id = "porshe_kayen", name = "Porshe Kayen", rarity = "Rare", style = "suv", income = 46, body = C(150, 156, 166), accent = C(20, 20, 24), tag = "The sports car that does groceries." },
	{ id = "mursides_amg", name = "Mursides Ay-Em-Gee GT", rarity = "Rare", style = "sport", income = 50, body = C(110, 200, 60), accent = C(20, 20, 24), tag = "Green hell certified." },
	{ id = "astin_db11", name = "Astin Martyn Dee-Bee Eleven", rarity = "Epic", style = "sport", income = 120, body = C(30, 80, 60), accent = C(200, 200, 210), tag = "Licence to cruise." },
	{ id = "lamborgini_uroos", name = "Lamborgini Uroos", rarity = "Epic", style = "suv", income = 160, body = C(255, 200, 0), accent = C(20, 20, 24), tag = "A bull that seats five." },
	{ id = "ferarri_romma", name = "Ferarri Romma", rarity = "Epic", style = "sport", income = 150, body = C(220, 30, 30), accent = C(20, 20, 24), tag = "La dolce vita, 600 hp." },
	{ id = "porshe_taykun", name = "Porshe Taykun", rarity = "Epic", style = "sport", income = 130, body = C(40, 120, 200), accent = C(20, 20, 24), tag = "Silent rocket." },
	{ id = "maklaren_720", name = "MakLaren Seven-Twenty", rarity = "Epic", style = "supercar", income = 185, body = C(255, 120, 20), accent = C(20, 20, 24), tag = "Eyes like a predator." },
	{ id = "awdi_rs6", name = "Awdi Arr-Ess Six", rarity = "Epic", style = "sedan", income = 115, body = C(110, 116, 124), accent = C(20, 20, 24), tag = "The fastest estate in town." },
	{ id = "bentli_bentaiga", name = "Bentli Bentaiga", rarity = "Epic", style = "suv", income = 145, body = C(60, 20, 30), accent = C(200, 200, 210), tag = "A lounge on stilts." },
	{ id = "mursides_maibah", name = "Mursides Maibah", rarity = "Epic", style = "sedan", income = 175, body = C(20, 20, 24), accent = C(240, 240, 240), chrome = true, tag = "Champagne in the back." },
	{ id = "bugati_veiron", name = "Bugati Veiron", rarity = "Legendary", style = "proto", income = 700, body = C(30, 30, 90), accent = C(200, 200, 210), neon = C(80, 120, 255), tag = "The original hyper." },
	{ id = "konigseg_jesko", name = "Konigseg Yesko", rarity = "Legendary", style = "proto", income = 1100, body = C(240, 240, 240), accent = C(20, 20, 24), neon = C(255, 80, 60), spoiler = true, tag = "Wing bigger than your ego." },
	{ id = "ferarri_sf90", name = "Ferarri Ess-Eff Ninety", rarity = "Legendary", style = "supercar", income = 850, body = C(220, 16, 20), accent = C(20, 20, 24), neon = C(255, 60, 40), tag = "Hybrid fury." },
	{ id = "lamborgini_sian", name = "Lamborgini Sian", rarity = "Legendary", style = "proto", income = 950, body = C(200, 190, 60), accent = C(20, 20, 24), neon = C(255, 220, 60), tag = "Lightning in a bottle." },
	{ id = "maklaren_senna", name = "MakLaren Senna", rarity = "Legendary", style = "proto", income = 1000, body = C(255, 240, 240), accent = C(220, 30, 30), neon = C(255, 80, 80), spoiler = true, tag = "Track first, road maybe." },
	{ id = "astin_valkyry", name = "Astin Valkyry", rarity = "Legendary", style = "proto", income = 1300, body = C(30, 90, 70), accent = C(20, 20, 24), neon = C(90, 255, 180), tag = "A fighter jet with plates." },
	{ id = "pagany_huayrar", name = "Pagany Wyra Arr", rarity = "Legendary", style = "proto", income = 1150, body = C(40, 40, 44), accent = C(220, 180, 60), chrome = true, neon = C(255, 200, 80), tag = "Carbon art at 850 hp." },
	{ id = "rimak_nevara", name = "Rimak Nevara", rarity = "Legendary", style = "supercar", income = 1250, body = C(80, 90, 110), accent = C(20, 20, 24), neon = C(80, 220, 255), tag = "Electric thunder." },
}
do -- show order: rarity, then income
	local idx = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }
	table.sort(list, function(a, b)
		if idx[a.rarity] ~= idx[b.rarity] then
			return idx[a.rarity] < idx[b.rarity]
		end
		return a.income < b.income
	end)
end

-- old save ids -> new ids (same rarity and income slot)
CarConfig.LegacyIds = {
	rusty_compact = "furd_fiasta", pocket_hatch = "dodje_caravon", dusty_sedan = "furd_f150", mule_pickup = "awdi_a4",
	street_runner = "bmv_m3", city_taxi = "mursides_e", cargo_hopper = "tezla_model3", boulevard_gt = "jagwar_xe",
	night_phantom = "furd_mustank", iron_hauler = "dodje_chalenjer", redline_coupe = "ranje_rover", volt_cruiser = "bmv_m4",
	turbo_vortex = "mursides_g", chrome_viper = "awdi_r8", apex_predator = "jagwar_ftype", solar_flare = "mazeratti_gt",
	neon_specter = "lamborgini_hurakan", hyper_nova = "tezla_cybertrak", quantum_drift = "mazeratti_mc20", eclipse_titan = "lamborgini_aventadoor",
}

-- exclusive cars: never drop from the trap, granted by a game pass
CarConfig.Exclusive = {
	{ id = "golden_magnat_gt", name = "Golden Magnat GT", rarity = "Legendary", style = "supercar", income = 2000, body = C(232, 178, 50), accent = C(20, 20, 24), chrome = true, neon = C(255, 210, 90), exclusive = true, tag = "Only for true magnates." },
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

for _, def in ipairs(CarConfig.Exclusive) do
	def.value = def.income * CarConfig.ValueMultiplier
	def.maxLevel = CarConfig.MaxLevel
	def.order = 1000
	CarConfig.ById[def.id] = def
end

-- v13 catch by RARITY POINTS: a throw adds up the points of every part thrown (PartConfig.Parts[id].points);
-- the car rarity odds come from this curve (log-interpolated between the rows). Top cars stay rare on purpose.
CarConfig.PointRows = {
	{ 1, { Common = 72, Uncommon = 22, Rare = 5.5, Epic = 0.48, Legendary = 0.02 } },
	{ 4, { Common = 58, Uncommon = 30, Rare = 10, Epic = 1.9, Legendary = 0.1 } },
	{ 10, { Common = 42, Uncommon = 34, Rare = 19.75, Epic = 4, Legendary = 0.25 } },
	{ 22, { Common = 28, Uncommon = 36, Rare = 27.4, Epic = 8, Legendary = 0.6 } },
	{ 50, { Common = 15, Uncommon = 32, Rare = 37.5, Epic = 14, Legendary = 1.5 } },
	{ 200, { Common = 4, Uncommon = 18, Rare = 42, Epic = 30, Legendary = 6 } },
}
function CarConfig.ChancesForPoints(points)
	local rows = CarConfig.PointRows
	points = math.max(points or 1, rows[1][1])
	if points >= rows[#rows][1] then
		return table.clone(rows[#rows][2])
	end
	for i = 1, #rows - 1 do
		local a, b = rows[i], rows[i + 1]
		if points <= b[1] then
			local t = (math.log(points) - math.log(a[1])) / (math.log(b[1]) - math.log(a[1]))
			local out = {}
			for _, r in ipairs(CarConfig.RarityOrder) do
				out[r] = a[2][r] + (b[2][r] - a[2][r]) * t
			end
			return out
		end
	end
	return table.clone(rows[#rows][2])
end
-- odds of a single part (throw menu, simulator)
CarConfig.DropChances = {}
for id, part in pairs(PartConfig.Parts) do
	CarConfig.DropChances[id] = CarConfig.ChancesForPoints(part.points)
end

function CarConfig.IncomeAt(def, level)
	return math.floor(def.income * CarConfig.IncomeMult * (1 + CarConfig.IncomeGrowth * (level - 1)) + 0.5)
end

-- income of one owned car incl. its tuning parts
function CarConfig.CarIncome(car)
	local def = CarConfig.ById[car.typeId]
	if not def then
		return 0
	end
	return math.floor(CarConfig.IncomeAt(def, car.level) * require(script.Parent.TuningConfig).CarMult(car.tune) + 0.5)
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

function CarConfig.PityRow(row)
	-- pity guarantees an Epic; a Legendary keeps its own (small) chance on top
	local l = math.min(row.Legendary * 3, 20)
	return { Common = 0, Uncommon = 0, Rare = 0, Epic = 100 - l, Legendary = l }
end

-- one car from a throw worth `points` rarity points
function CarConfig.RollPoints(points, pity, r1, r2)
	local row = CarConfig.ChancesForPoints(points)
	if pity and pity >= EconomyConfig.PityThreshold - 1 then
		row = CarConfig.PityRow(row)
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
		if #CarConfig.ByRarity[r] ~= #CarConfig.ByRarity.Common or #CarConfig.ByRarity[r] < 4 then
			table.insert(errors, r .. ": uneven car count " .. #CarConfig.ByRarity[r])
		end
		count = count + #CarConfig.ByRarity[r]
	end
	if count ~= #list then
		table.insert(errors, "car count mismatch " .. count)
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
