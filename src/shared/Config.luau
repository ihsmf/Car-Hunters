-- Все игровые константы и UI-токены (соответствуют макету Figma)
local C = {}

local rgb = Color3.fromRGB

C.UI = {
	Font = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold),
	Stroke = rgb(40, 20, 60),
	Panel = rgb(255, 244, 222),
	Accent = rgb(255, 190, 40),
	Buttons = {
		Settings = { "⚙️", "Настройки", rgb(120, 140, 255) },
		Inventory = { "🎒", "Инвентарь", rgb(90, 210, 120) },
		Daily = { "🎁", "Бонус", rgb(255, 120, 170) },
		Shop = { "💎", "Магазин", rgb(255, 175, 40) },
	},
}

C.Sounds = {
	Music = "rbxassetid://1837849285",
	Hit = "rbxassetid://9119720940",
	Pocket = "rbxassetid://9118823101",
	Click = "rbxassetid://6895079853",
	Reward = "rbxassetid://9125402735",
}

-- name, color, income/sec
C.Rarities = {
	{ "Обычный", rgb(200, 200, 200), 1 },
	{ "Необычный", rgb(90, 220, 90), 3 },
	{ "Редкий", rgb(70, 150, 255), 8 },
	{ "Эпический", rgb(170, 80, 255), 20 },
	{ "Легендарный", rgb(255, 170, 0), 50 },
	{ "Мифический", rgb(255, 60, 90), 120 },
	{ "Божественный", rgb(255, 240, 120), 300 },
	{ "Небесный", rgb(120, 255, 255), 750 },
	{ "Космический", rgb(110, 60, 230), 2000 },
	{ "Радужный", rgb(255, 120, 255), 5000 },
	{ "Секретный", rgb(30, 30, 30), 12000 },
	{ "Абсолютный", rgb(255, 0, 140), 30000 },
}

local names = {
	{ "Новичок Вася", "Студент Петя", "Дядя Коля" },
	{ "Ловкий Миша", "Тётя Света", "Кий-Бой" },
	{ "Снайпер Лёха", "Профи Гена", "Мисс Шар" },
	{ "Граф Карамболь", "Двойной Удар", "Леди Луза" },
	{ "Король Пула", "Барон Борт", "Мастер Отыгрыш" },
	{ "Дракон Шара", "Тень Лузы", "Вихрь" },
	{ "Ангел Кия", "Оракул", "Святой Шар" },
	{ "Небожитель", "Облачный Кий", "Звёздочка" },
	{ "Астро-Профи", "Чёрная Дыра", "Комета" },
	{ "Радуга", "Единорог", "Призма" },
	{ "???", "Аноним", "Глитч" },
	{ "Абсолют", "Создатель Столов", "Бильярдный Бог" },
}

C.Characters = {} -- id -> {name, rarity, income, skin, shirt}
for r, list in names do
	for i, n in list do
		table.insert(C.Characters, {
			name = n,
			rarity = r,
			income = math.floor(C.Rarities[r][3] * (1 + (i - 1) * 0.25)),
			shirt = C.Rarities[r][2]:Lerp(rgb(255, 255, 255), (i - 1) * 0.2),
		})
	end
end

C.Table = { Length = 420, Width = 48, StartZ = 70, Lanes = 4 }
C.LuckCycle = 45 -- каждые N секунд стол сдвигает редкости вверх
C.MaxLuckShift = 3
C.ThrowCooldown = 2
C.MaxEquipped = 8
C.MaxInventory = 100

C.Cues = { -- name, distance mult, price (Cash), color
	{ "Деревянный", 1, 0, rgb(160, 110, 60) },
	{ "Клёновый", 1.3, 500, rgb(230, 190, 120) },
	{ "Карбоновый", 1.7, 5000, rgb(50, 50, 55) },
	{ "Золотой", 2.3, 50000, rgb(255, 200, 40) },
	{ "Алмазный", 3, 500000, rgb(140, 240, 255) },
	{ "Неоновый", 4, 5000000, rgb(255, 60, 220) },
}

function C.LiftCost(lvl) return math.floor(50 * 1.6 ^ (lvl - 1)) end
function C.CueUpCost(lvl) return math.floor(100 * 1.8 ^ (lvl - 1)) end
function C.Distance(power, d)
	local cueMult = (d.passes.DragonCue and 6 or C.Cues[d.cue][2]) * (1 + (d.cueLevel - 1) * 0.1)
	return math.min(C.Table.Length, power * (30 + d.strength * 0.4) * cueMult)
end

-- Заменить 0 на реальные ID из Creator Dashboard
C.GamePasses = {
	Cash2x = { id = 0, icon = "💰", name = "x2 Деньги" },
	Luck2x = { id = 0, icon = "🍀", name = "x2 Удача" },
	DragonCue = { id = 0, icon = "🐉", name = "Кий Дракона" },
	GoldStick = { id = 0, icon = "🪄", name = "Золотая Палка" },
}
C.Products = { -- id -> cash
	{ id = 0, cash = 5000, icon = "💵" },
	{ id = 0, cash = 50000, icon = "💰" },
}

C.Daily = { 100, 250, 500, 1000, 2500, 5000, 15000 }
C.Playtime = { { 5, 300 }, { 15, 1000 }, { 30, 3000 }, { 60, 10000 } } -- минуты, награда

function C.Short(n)
	for _, s in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if n >= s[1] then return string.format("%.1f%s", n / s[1], s[2]) end
	end
	return tostring(math.floor(n))
end

return C
