-- Trading UI: TRADE button (right side) -> pick a player -> request; incoming request card; two-sided trade window.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local CarConfig = require(Shared:WaitForChild("CarConfig"))
local PartConfig = require(Shared:WaitForChild("PartConfig"))
local Util = require(Shared:WaitForChild("Util"))
local Icons = require(Shared:WaitForChild("Icons"))

local TR = {}
local K, UI
local P
local C = Color3.fromRGB
local w = {}
local offer = { cars = {}, money = 0, parts = {} } -- my local draft
local last -- last state from the server

local function send()
	local cars = {}
	for uid in pairs(offer.cars) do
		table.insert(cars, uid)
	end
	Net.Get("TradeUpdate"):FireServer({ cars = cars, money = offer.money, parts = offer.parts })
end

local function rc(r)
	return CarConfig.Rarities[r].color
end

---------------------------------------------------------------- player list
local function refreshList()
	K.clear(w.list)
	local any = false
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= Players.LocalPlayer then
			any = true
			local row = K.new("Frame", { Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = P.white, ZIndex = 23 }, w.list)
			K.corner(row, 16)
			K.stroke(row, P.ink, 3)
			local ok, img = pcall(function()
				return Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
			end)
			local face = K.new("ImageLabel", { Position = UDim2.fromOffset(10, 7), Size = UDim2.fromOffset(56, 56), BackgroundColor3 = C(230, 232, 236), Image = ok and img or "", ZIndex = 24 }, row)
			K.corner(face, 28)
			K.text(row, { Text = p.DisplayName, TextSize = 22, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(78, 0), Size = UDim2.new(1, -260, 1, 0), ZIndex = 24 })
			K.toy(row, { Text = "REQUEST", Color = P.green, Size = UDim2.fromOffset(160, 54), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), TextSize = 20, ZIndex = 25,
				OnClick = function()
					Net.Get("TradeRequest"):FireServer(p.UserId)
					UI.TogglePanel(nil)
				end })
		end
	end
	if not any then
		K.text(w.list, { Text = "Nobody else is on this server yet. Invite a friend!", Font = K.BODY, TextSize = 18, TextColor3 = P.muted, Size = UDim2.new(1, 0, 0, 40), ZIndex = 23 })
	end
end

---------------------------------------------------------------- incoming request
local function requestCard(msg)
	local f = K.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -150, 0, 120), Size = UDim2.fromOffset(330, 150), BackgroundColor3 = P.cream, ZIndex = 70 }, K.gui)
	K.corner(f, 20)
	K.stroke(f, P.ink, 4)
	K.text(f, { Text = "TRADE REQUEST", TextSize = 22, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 0, 26), ZIndex = 71 })
	K.text(f, { Text = msg.name .. " wants to trade with you", Font = K.BODY, TextSize = 16, TextColor3 = P.muted, Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -32, 0, 22), ZIndex = 71 })
	local function answer(ok)
		Net.Get("TradeRespond"):FireServer(msg.from, ok)
		f:Destroy()
	end
	K.toy(f, { Text = "ACCEPT", Color = P.green, Size = UDim2.fromOffset(140, 54), Position = UDim2.fromOffset(16, 80), TextSize = 20, ZIndex = 72, OnClick = function() answer(true) end })
	K.toy(f, { Text = "DECLINE", Color = P.red, Size = UDim2.fromOffset(140, 54), Position = UDim2.fromOffset(170, 80), TextSize = 20, ZIndex = 72, OnClick = function() answer(false) end })
	UI.Sfx("ping")
	task.delay(25, function()
		if f.Parent then
			f:Destroy()
		end
	end)
end

---------------------------------------------------------------- trade window
local function carRow(parent, car, order, selected, onClick)
	local def = CarConfig.ById[car.typeId]
	if not def then
		return
	end
	local b = K.new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = selected and C(220, 250, 226) or P.white, LayoutOrder = order, ZIndex = 24 }, parent)
	K.corner(b, 12)
	K.stroke(b, selected and P.green or rc(def.rarity), selected and 4 or 2)
	K.text(b, { Text = string.format("%s  Lv%d", def.name, car.level), Font = K.BODY, TextSize = 15, TextColor3 = P.ink, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -60, 1, 0), ZIndex = 25 })
	K.text(b, { Text = string.upper(string.sub(def.rarity, 1, 4)), Font = K.BODY, TextSize = 12, TextColor3 = rc(def.rarity), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0),
		Size = UDim2.fromOffset(46, 44), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 25 })
	if onClick then
		b.Activated:Connect(onClick)
	end
end

local function buildWindow()
	local p = K.panelShell("trade", "TRADE", 960, 620, P.blue)
	local c = p.content
	w.window = p
	-- left: my side
	local mine = K.new("Frame", { Size = UDim2.new(0.5, -8, 1, -90), BackgroundTransparency = 1, ZIndex = 22 }, c)
	K.text(mine, { Text = "YOUR OFFER", TextSize = 22, TextColor3 = P.ink, Outline = false, Size = UDim2.new(1, 0, 0, 26), ZIndex = 23 })
	K.text(mine, { Text = "Tap cars to add / remove (max 8)", Font = K.BODY, TextSize = 13, TextColor3 = P.muted, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 18), ZIndex = 23 })
	w.myCars = K.scroller(mine, UDim2.fromOffset(0, 48), UDim2.new(1, 0, 0, 230))
	-- money
	K.text(mine, { Text = "MONEY", TextSize = 18, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(0, 286), Size = UDim2.fromOffset(90, 24), ZIndex = 23 })
	w.moneyBox = K.new("TextBox", { Text = "0", PlaceholderText = "0", ClearTextOnFocus = false, Font = K.BODY, TextSize = 18, TextColor3 = P.ink, BackgroundColor3 = P.white,
		Position = UDim2.fromOffset(90, 282), Size = UDim2.fromOffset(150, 32), ZIndex = 23 }, mine)
	K.corner(w.moneyBox, 8)
	K.stroke(w.moneyBox, P.ink, 2)
	w.moneyBox.FocusLost:Connect(function()
		local v = tonumber((string.gsub(w.moneyBox.Text, "[^%d]", ""))) or 0
		offer.money = math.clamp(v, 0, K.store.Money)
		send()
	end)
	for i, add in ipairs({ 1000, 10000, 100000 }) do
		K.toy(mine, { Text = "+" .. Util.FormatNumber(add), Color = P.yellow, Size = UDim2.fromOffset(66, 34), Position = UDim2.fromOffset(248 + (i - 1) * 72, 281), TextSize = 14, ZIndex = 24,
			OnClick = function()
				offer.money = math.min(offer.money + add, K.store.Money)
				send()
			end })
	end
	-- parts steppers
	w.partRows = {}
	for i, id in ipairs(PartConfig.Order) do
		local x = (i - 1) * 88
		local img = K.new("ImageLabel", { Position = UDim2.fromOffset(x + 20, 322), Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 1, Image = Icons.Get(id) or "", ZIndex = 23 }, mine)
		local n = K.text(mine, { Text = "0", TextSize = 18, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(x, 364), Size = UDim2.fromOffset(80, 20), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 23 })
		K.toy(mine, { Text = "-", Color = P.red, Size = UDim2.fromOffset(36, 32), Position = UDim2.fromOffset(x + 2, 388), TextSize = 20, ZIndex = 24, OnClick = function()
			offer.parts[id] = math.max(0, (offer.parts[id] or 0) - 1)
			send()
		end })
		K.toy(mine, { Text = "+", Color = P.green, Size = UDim2.fromOffset(36, 32), Position = UDim2.fromOffset(x + 42, 388), TextSize = 20, ZIndex = 24, OnClick = function()
			offer.parts[id] = math.min(K.store.Banked(id), (offer.parts[id] or 0) + 1)
			send()
		end })
		w.partRows[id] = n
		img.ImageTransparency = 0
	end
	-- right: their side
	local theirs = K.new("Frame", { Position = UDim2.new(0.5, 8, 0, 0), Size = UDim2.new(0.5, -8, 1, -90), BackgroundColor3 = C(236, 242, 250), ZIndex = 22 }, c)
	K.corner(theirs, 16)
	K.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8) }, theirs)
	w.theirTitle = K.text(theirs, { Text = "THEIR OFFER", TextSize = 22, TextColor3 = P.ink, Outline = false, Size = UDim2.new(1, 0, 0, 26), ZIndex = 23 })
	w.theirCars = K.scroller(theirs, UDim2.fromOffset(0, 34), UDim2.new(1, 0, 0, 240))
	w.theirExtra = K.text(theirs, { Text = "", Font = K.BODY, TextSize = 17, TextColor3 = P.ink, RichText = true, TextWrapped = true, Position = UDim2.fromOffset(0, 284), Size = UDim2.new(1, 0, 0, 90), ZIndex = 23 })
	-- bottom bar
	w.status = K.text(c, { Text = "", Font = K.BODY, TextSize = 18, TextColor3 = P.ink, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -24), Size = UDim2.new(0.5, 0, 0, 30), ZIndex = 23 })
	w.cancel = K.toy(c, { Text = "CANCEL", Color = P.red, Size = UDim2.fromOffset(170, 64), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -250, 1, 0), TextSize = 22, ZIndex = 24, OnClick = function()
		Net.Get("TradeCancel"):FireServer()
	end })
	w.ready = K.toy(c, { Text = "READY", Color = P.green, Size = UDim2.fromOffset(230, 64), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), TextSize = 26, ZIndex = 24, OnClick = function()
		Net.Get("TradeReady"):FireServer(not (last and last.readyMe))
	end })
end

local function partsLine(parts)
	local out = {}
	for _, id in ipairs(PartConfig.Order) do
		if parts and (parts[id] or 0) > 0 then
			table.insert(out, parts[id] .. " " .. id)
		end
	end
	return #out > 0 and table.concat(out, ", ") or "no parts"
end

local function renderState(msg)
	last = msg
	if K.state.open ~= "trade" then
		UI.TogglePanel("trade")
	end
	-- my cars: every car I own, offered ones highlighted
	offer.cars = {}
	for _, c in ipairs(msg.mine.cars) do
		offer.cars[c.uid] = true
	end
	offer.money = msg.mine.money or 0
	offer.parts = msg.mine.parts or {}
	K.clear(w.myCars)
	local st = K.store.State
	for i, car in ipairs(st and st.cars or {}) do
		local sel = offer.cars[car.uid]
		carRow(w.myCars, car, sel and i or i + 1000, sel, function()
			if offer.cars[car.uid] then
				offer.cars[car.uid] = nil
			else
				local n = 0
				for _ in pairs(offer.cars) do
					n = n + 1
				end
				if n >= 8 then
					UI.Toast("Max 8 cars per trade", "warn")
					return
				end
				offer.cars[car.uid] = true
			end
			send()
		end)
	end
	w.moneyBox.Text = tostring(offer.money)
	for id, n in pairs(w.partRows) do
		n.Text = tostring(offer.parts[id] or 0) .. " / " .. K.store.Banked(id)
	end
	w.theirTitle.Text = string.upper(msg.partner) .. " OFFERS"
	K.clear(w.theirCars)
	for i, car in ipairs(msg.theirs.cars) do
		carRow(w.theirCars, car, i, false)
	end
	if #msg.theirs.cars == 0 then
		K.text(w.theirCars, { Text = "No cars", Font = K.BODY, TextSize = 15, TextColor3 = P.muted, Size = UDim2.new(1, 0, 0, 30), ZIndex = 24 })
	end
	w.theirExtra.Text = string.format("<b>$%s</b>\n%s", Util.FormatNumber(msg.theirs.money or 0), partsLine(msg.theirs.parts))
	if msg.countdown then
		w.status.Text = string.format("Both ready - trading in %d...", math.ceil(msg.countdown))
		task.delay(1, function()
			if last == msg and msg.countdown and msg.countdown > 1 then
				msg.countdown = msg.countdown - 1
				renderState(msg)
			end
		end)
	elseif msg.readyMe and not msg.readyThem then
		w.status.Text = "Waiting for " .. msg.partner .. "..."
	elseif msg.readyThem then
		w.status.Text = msg.partner .. " is READY"
	else
		w.status.Text = "Make your offer, then press READY"
	end
	w.ready.SetText(msg.readyMe and "UNREADY" or "READY", nil)
	w.ready.SetColor(msg.readyMe and P.orange or P.green)
end

function TR.Start(ui)
	UI = ui
	K = UI.Kit()
	P = K.P
	-- right-side button under CARS
	local holder = K.new("Frame", { Size = UDim2.fromOffset(122, 104), BackgroundTransparency = 1, LayoutOrder = 4 }, K.hud.side)
	local b = K.toy(holder, { Text = "TRADE", Icon = " ", Color = P.blue, Size = UDim2.fromOffset(122, 104), OnClick = function() UI.TogglePanel("tradeList") end })
	local img = K.new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(52, 52), BackgroundTransparency = 1,
		Image = Icons.Get("trade") or "", ZIndex = b.face.ZIndex + 1 }, b.face)
	img.ImageTransparency = 0
	local lp = K.panelShell("tradeList", "TRADE WITH", 640, 520, P.blue)
	w.list = K.scroller(lp.content, UDim2.new(), UDim2.fromScale(1, 1))
	buildWindow()
	table.insert(UI.Hooks, function(_, open)
		if open == "tradeList" then
			refreshList()
		end
	end)
	Net.Get("TradeEvent").OnClientEvent:Connect(function(msg)
		if msg.type == "request" then
			requestCard(msg)
		elseif msg.type == "state" then
			renderState(msg)
		elseif msg.type == "closed" then
			last = nil
			if K.state.open == "trade" then
				UI.TogglePanel(nil)
			end
			if msg.reason == "done" then
				UI.Sfx("fanfare")
				UI.Toast("Trade complete!", "good")
			else
				UI.Toast(msg.reason or "Trade cancelled", "warn")
			end
		end
	end)
end

return TR
