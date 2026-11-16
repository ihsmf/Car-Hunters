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

-- 25 редкостей: name, color, тема персонажей. Доход растёт x2.2 за ступень
local R = {
	{ "Обычный", rgb(200, 200, 200), "Новичок" }, { "Необычный", rgb(90, 220, 90), "Любитель" },
	{ "Редкий", rgb(70, 150, 255), "Снайпер" }, { "Эпический", rgb(170, 80, 255), "Граф" },
	{ "Легендарный", rgb(255, 170, 0), "Король" }, { "Мифический", rgb(255, 60, 90), "Дракон" },
	{ "Древний", rgb(190, 140, 90), "Фараон" }, { "Ледяной", rgb(160, 230, 255), "Йети" },
	{ "Огненный", rgb(255, 100, 30), "Феникс" }, { "Токсичный", rgb(150, 255, 40), "Мутант" },
	{ "Кибер", rgb(0, 255, 200), "Робот" }, { "Пиратский", rgb(120, 80, 40), "Капитан" },
	{ "Самурай", rgb(220, 30, 50), "Ронин" }, { "Призрачный", rgb(200, 220, 255), "Призрак" },
	{ "Божественный", rgb(255, 240, 120), "Ангел" }, { "Демонический", rgb(140, 0, 30), "Демон" },
	{ "Небесный", rgb(120, 255, 255), "Небожитель" }, { "Звёздный", rgb(255, 255, 200), "Звездочёт" },
	{ "Космический", rgb(110, 60, 230), "Астронавт" }, { "Галактический", rgb(60, 20, 140), "Император" },
	{ "Радужный", rgb(255, 120, 255), "Единорог" }, { "Квантовый", rgb(40, 200, 255), "Учёный" },
	{ "Секретный", rgb(30, 30, 30), "Аноним" }, { "Глитч", rgb(255, 0, 255), "Ошибка" },
	{ "Абсолютный", rgb(255, 0, 140), "Бог Бильярда" },
}
local titles = { "Юный", "Ловкий", "Мастер", "Великий" }

C.Rarities, C.Characters = {}, {} -- C.Rarities[i] = {name, color, income}
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

C.Table = { Length = 900, Width = 48, StartZ = 70, Lanes = 4 }
C.LuckCycle = 45 -- каждые N секунд стол сдвигает редкости вверх
C.MaxLuckShift = 4
C.ThrowCooldown = 2
C.MaxEquipped = 8
C.MaxInventory = 100

C.Cues = { -- name, distance mult, price (Cash), color
	{ "Деревянный", 1, 0, rgb(160, 110, 60) },
	{ "Клёновый", 1.3, 500, rgb(230, 190, 120) },
	{ "Карбоновый", 1.7, 5000, rgb(50, 50, 55) },
	{ "Золотой", 2.3, 50000, rgb(255, 200, 40) },
	{ "Алмазный", 3, 500000, rgb(140, 240, 255) },
	{ "Неоновый", 4, 5e6, rgb(255, 60, 220) },
	{ "Лавовый", 5.5, 5e7, rgb(255, 80, 0) },
	{ "Звёздный", 7.5, 5e8, rgb(255, 255, 180) },
	{ "Галактический", 10, 5e9, rgb(90, 40, 200) },
	{ "Абсолютный", 14, 5e10, rgb(255, 0, 140) },
}

function C.LiftCost(lvl) return math.floor(50 * 1.6 ^ (lvl - 1)) end
function C.CueUpCost(lvl) return math.floor(100 * 1.8 ^ (lvl - 1)) end
function C.Distance(power, d)
	local cueMult = math.max(d.passes.DragonCue and 6 or 0, C.Cues[d.cue][2]) * (1 + (d.cueLevel - 1) * 0.1)
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
	for _, s in { { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if n >= s[1] then return string.format("%.1f%s", n / s[1], s[2]) end
	end
	return tostring(math.floor(n))
end

return C
