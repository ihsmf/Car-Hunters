-- Extra HUD + panels: Pit Stop perks, Golden Magnate donations, combo meter, contracts, hot drop banner, boosts.
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local Util = require(Shared:WaitForChild("Util"))
local ShopConfig = require(Shared:WaitForChild("ShopConfig"))
local DonateConfig = require(Shared:WaitForChild("DonateConfig"))
local ProductIds = require(Shared:WaitForChild("ProductIds"))
local IS_STUDIO = game:GetService("RunService"):IsStudio()
local randomRestricted = false
task.spawn(function()
	local ok, info = pcall(function()
		return game:GetService("PolicyService"):GetPolicyInfoForPlayerAsync(game:GetService("Players").LocalPlayer)
	end)
	randomRestricted = ok and info and info.ArePaidRandomItemsRestricted == true or false
end)
local MapConfig = require(Shared:WaitForChild("MapConfig"))
local PartConfig = require(Shared:WaitForChild("PartConfig"))
local GearConfig = require(Shared:WaitForChild("GearConfig"))
local Icons = require(Shared:WaitForChild("Icons"))
local CarConfig = require(Shared:WaitForChild("CarConfig"))
local SkinConfig = require(Shared:WaitForChild("SkinConfig"))
local CollectionService = game:GetService("CollectionService")

local T = Strings.T
local C = Color3.fromRGB
local X = {}
local K, UI
local P
local w = {}
local hot = nil -- current hot drop info
local donateTab = "boost"
local shopTab = "perks"
local TONY = C(72, 96, 156) -- v23: steel blue (the old near-black navy swallowed the panel's ink outline)
local GOLD = C(232, 178, 50)
local TEAL = C(40, 150, 140) -- rebirth teal (no purple in this UI)
local contractText -- defined with the HUD widgets

local function fmtTime(sec)
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

---------------------------------------------------------------- Pit Stop
local function buildShop()
	local p = K.panelShell("shop", T("shop_title"), 900, 600, P.red)
	local tabs = K.new("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1, ZIndex = 22 }, p.content)
	K.list(tabs, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center)
	w.shopTabs = {}
	for i, tab in ipairs({ "perks", "garage" }) do
		w.shopTabs[tab] = K.toy(tabs, { Text = T("shop_tab_" .. tab), Color = P.grey, Size = UDim2.fromOffset(200, 52), LayoutOrder = i, ZIndex = 23, TextSize = 20,
			OnClick = function()
				shopTab = tab
				UI.Refresh()
			end })
	end
	local grid = K.new("ScrollingFrame", { Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 1, -66), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 22 }, p.content)
	-- v23: padding so the outlines / shadows of the outer cards never clip; 4 x 198 + 3 x 12 = 828 of the 834 px inside
	K.new("UIGridLayout", { CellSize = UDim2.fromOffset(198, 214), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	K.padding(grid, 8, 14)
	w.shopGrid = grid
end

local function refreshSkins(st)
	for _, def in ipairs(SkinConfig.Skins) do
		local owned = (st.skins and st.skins[def.id]) or (def.pass and st.passes and st.passes[def.pass])
		local on = st.skin == def.id
		local card = K.card(w.shopGrid, { Color = def.style.wall:Lerp(Color3.new(1, 1, 1), 0.75), StrokeColor = on and P.green or P.ink, Stroke = on and 5 or 3,
			Radius = 20, LayoutOrder = def.order, ZIndex = 23 })
		-- mini swatch of the skin colours
		local sw = K.new("Frame", { Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(150, 40), BackgroundTransparency = 1, ZIndex = 24 }, card)
		K.list(sw, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Center)
		for _, k in ipairs({ "wall", "floor", "frame", "accent" }) do
			local c = K.new("Frame", { Size = UDim2.fromOffset(32, 40), BackgroundColor3 = def.style[k], ZIndex = 25 }, sw)
			K.corner(c, 8)
			K.stroke(c, P.ink, 2)
		end
		K.text(card, { Text = def.icon .. " " .. string.upper(def.name), TextSize = 18, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 24 })
		K.text(card, { Text = def.bonus > 0 and T("skin_bonus", math.floor(def.bonus * 100 + 0.5)) or "-", Font = K.BODY, TextSize = 18, TextColor3 = C(30, 158, 64), Position = UDim2.fromOffset(0, 86), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 24 })
		local label, color, can
		if on then
			label, color = T("skin_on"), P.green
		elseif owned then
			label, color, can = T("skin_equip"), P.blue, true
		elseif def.pass then
			local it = DonateConfig.ById[def.pass]
			label, color, can = "R$ " .. (it and it.price or "?"), GOLD, true
		elseif def.tokens then
			label, color, can = "🪙 " .. def.tokens, (st.tokens or 0) >= def.tokens and P.orange or P.grey, true
		else
			label, color, can = "$" .. Util.FormatNumber(def.money), K.store.Money >= def.money and P.green or P.grey, true
		end
		K.toy(card, { Text = label, Color = color, Size = UDim2.fromOffset(176, 62), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), ZIndex = 25, TextSize = 22,
			OnClick = function()
				if can then
					K.actions.SetSkin(def.id)
				end
			end })
	end
end

local function refreshShop(st, open)
	if open ~= "shop" then
		return
	end
	for tab, b in pairs(w.shopTabs) do
		b.SetColor(tab == shopTab and P.yellow or P.grey)
	end
	K.clear(w.shopGrid)
	if shopTab == "garage" then
		refreshSkins(st)
		return
	end
	for _, def in ipairs(ShopConfig.Perks) do
		local lvl = st.perks and st.perks[def.id] or 0
		local cost = ShopConfig.NextCost(def.id, lvl)
		local card = K.card(w.shopGrid, { Radius = 20, LayoutOrder = def.order, ZIndex = 23 })
		K.text(card, { Text = def.icon, Font = K.BODY, TextSize = 40, Size = UDim2.new(1, 0, 0, 48), Position = UDim2.fromOffset(0, 6), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 24 })
		K.text(card, { Text = string.upper(def.name), TextSize = 20, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 24 })
		K.text(card, { Text = def.desc, Font = K.BODY, TextSize = 14, TextColor3 = P.muted, TextWrapped = true, Position = UDim2.fromOffset(8, 78), Size = UDim2.new(1, -16, 0, 36), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 24 })
		local pips = K.new("Frame", { Position = UDim2.new(0.5, 0, 0, 118), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(def.max * 22, 14), BackgroundTransparency = 1, ZIndex = 24 }, card)
		K.list(pips, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center)
		for i = 1, def.max do
			local pip = K.new("Frame", { Size = UDim2.fromOffset(16, 14), BackgroundColor3 = (i <= lvl) and P.green or C(220, 222, 226), ZIndex = 25 }, pips)
			K.corner(pip, 5)
			K.stroke(pip, P.ink, 1.5)
		end
		local can = cost and K.store.Money >= cost
		K.toy(card, { Text = cost and ("$" .. Util.FormatNumber(cost)) or T("shop_max"), Sub = cost and T("shop_buy") or nil,
			Color = cost and (can and P.green or P.grey) or P.yellow, Size = UDim2.fromOffset(176, 62), AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6), ZIndex = 25, TextSize = 22, SubSize = 13,
			OnClick = function()
				if cost then
					K.actions.BuyPerk(def.id)
				end
			end })
	end
end

---------------------------------------------------------------- Golden Magnate
local function buildDonate()
	local p = K.panelShell("donate", T("donate_title"), 920, 600, GOLD)
	local tabs = K.new("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1, ZIndex = 22 }, p.content)
	K.list(tabs, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center)
	w.donateTabs = {}
	for i, tab in ipairs({ "boost", "pack", "pass" }) do
		w.donateTabs[tab] = K.toy(tabs, { Text = T("donate_" .. tab), Color = P.grey, Size = UDim2.fromOffset(170, 52), LayoutOrder = i, ZIndex = 23, TextSize = 20,
			OnClick = function()
				donateTab = tab
				UI.Refresh()
			end })
	end
	local grid = K.new("ScrollingFrame", { Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 1, -66), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 8, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 22 }, p.content)
	-- 4 x 204 + 3 x 12 = 852 of the 854 px inside the padding; +6 px height for the gold strip and the shadow slab
	K.new("UIGridLayout", { CellSize = UDim2.fromOffset(204, 206), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	K.padding(grid, 8, 14)
	w.donateGrid = grid
end

local function refreshDonate(st, open)
	if open ~= "donate" then
		return
	end
	for tab, b in pairs(w.donateTabs) do
		b.SetColor(tab == donateTab and GOLD or P.grey)
	end
	K.clear(w.donateGrid)
	local items = donateTab == "pass" and DonateConfig.Passes or DonateConfig.Products
	for _, it in ipairs(items) do
		-- live game: only products that exist on Roblox, and no paid random items where they are not allowed
		if it.tab == donateTab and DonateConfig.Available(it, ProductIds, IS_STUDIO, randomRestricted) then
			local owned = it.isPass and st.passes and st.passes[it.id]
			-- v23: white card + ink outline + shadow (the near-cream fill with a gold rim melted into the panel); gold top strip
			local card = K.card(w.donateGrid, { Accent = GOLD, AccentTop = true, AccentSize = 6, Radius = 20, LayoutOrder = it.order, ZIndex = 23 })
			K.text(card, { Text = it.icon, Font = K.BODY, TextSize = 40, Size = UDim2.new(1, 0, 0, 48), Position = UDim2.fromOffset(0, 6), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 24 })
			K.text(card, { Text = string.upper(it.name), TextSize = 19, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 24 })
			local desc = it.desc
			if it.boost and st.boosts and (st.boosts[it.boost] or 0) > 0 then
				desc = desc .. "\nActive: " .. fmtTime(st.boosts[it.boost])
			end
			K.text(card, { Text = desc, Font = K.BODY, TextSize = 14, TextColor3 = P.muted, TextWrapped = true, Position = UDim2.fromOffset(8, 78), Size = UDim2.new(1, -16, 0, 50), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 24 })
			K.toy(card, { Text = owned and T("donate_owned") or ("R$ " .. it.price), Color = owned and P.grey or GOLD, Size = UDim2.fromOffset(176, 58),
				AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), ZIndex = 25, TextSize = 24,
				OnClick = function()
					if not owned then
						K.actions.Donate(it.id)
					end
				end })
		end
	end
end

---------------------------------------------------------------- Big Tony's Gears: timed boosts, new stock every 5 minutes
local GREEN_TXT, RED_TXT = C(30, 158, 64), C(214, 52, 44)

-- v23: a list row is a white card (ink outline + shadow slab); the state colour is its left band (tan = nothing yet)
local ROW_IDLE = C(214, 204, 180)
local function row(parent, order, h, accent)
	return (K.card(parent, { Size = UDim2.new(1, 0, 0, h), Accent = accent or ROW_IDLE, Radius = 18, LayoutOrder = order, ZIndex = 23 }))
end

-- the state carries seconds-left values as of the push; count down locally from when it arrived
local pushedState, pushClock = nil, os.clock()
local function sincePush()
	local st = K.store.State
	if st ~= pushedState then
		pushedState, pushClock = st, os.clock()
	end
	return os.clock() - pushClock
end

-- server time in the server's own clock (os.time) when the state has it, else the replicated server time
local function serverNow()
	local st = K.store.State
	local el = sincePush()
	if st and tonumber(st.serverTime) then
		return st.serverTime + el
	end
	return Workspace:GetServerTimeNow()
end

-- seconds left on a car's gear right now (0 = none / run out)
local function gearLeft(car)
	local g = car and car.gear
	if type(g) ~= "table" or not GearConfig.ById[g.id] then
		return 0
	end
	if tonumber(g.left) then
		return math.max(0, g.left - sincePush())
	elseif tonumber(g.exp) then
		return math.max(0, g.exp - serverNow())
	end
	return 0
end

local function fmtMult(m)
	if m % 1 == 0 then
		return string.format("x%d", m)
	end
	return (string.format("x%.2f", m):gsub("0+$", ""))
end

-- "x2 4:12" for the garage GEAR button (nil without a running gear)
local function gearTag(car)
	local left = gearLeft(car)
	local def = left > 0 and GearConfig.ById[car.gear.id]
	if not def then
		return nil
	end
	local best = 1
	for _, m in pairs(def.effects) do
		best = math.max(best, m)
	end
	return fmtMult(best) .. " " .. fmtTime(left)
end

local function gearMinutes(def)
	return T("gears_minutes", math.floor(def.seconds / 60 + 0.5))
end

local stockCache = {}
-- this window's stock for the local player minus what they already bought in it
local function shopInfo(st)
	local now = serverNow()
	local window = GearConfig.WindowAt(now)
	if stockCache.window ~= window then
		stockCache.window = window
		stockCache.stock = GearConfig.Stock(game:GetService("Players").LocalPlayer.UserId, window)
	end
	local bought = (st.gearShop and st.gearShop.window == window and st.gearShop.bought) or {}
	local left = {}
	for id, n in pairs(stockCache.stock) do
		left[id] = math.max(0, n - (tonumber(bought[id]) or 0))
	end
	return left, (window + 1) * GearConfig.Window - now
end

local function gearPrice(def, st)
	return GearConfig.Price(def, tonumber(st.peakCarIncome) or 0) -- same formula as the server (GearService.Buy)
end

local function gearIcon(parent, def, size, pos, z)
	local img = Icons.Get("gear_" .. def.id)
	if img then
		return K.new("ImageLabel", { Image = img, BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), Position = pos, ScaleType = Enum.ScaleType.Fit, ZIndex = z }, parent)
	end
	return K.text(parent, { Text = def.icon, Font = K.BODY, TextSize = math.floor(size * 0.66), Size = UDim2.fromOffset(size, size), Position = pos,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = z })
end

local function stars(tier)
	return string.rep("★", tier) .. string.rep("☆", 5 - tier)
end

-- same test as the server (MechanicService.nearTony): 3D distance to TonyGarage.TonySpot <= 24 (MapConfig.Tony fallback)
local tonySpot
local function nearTony()
	local char = game:GetService("Players").LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end
	if not (tonySpot and tonySpot.Parent) then
		local map = Workspace:FindFirstChild("GeneratedMap")
		local garage = map and map:FindFirstChild("TonyGarage", true)
		local spot = garage and garage:FindFirstChild("TonySpot", true)
		tonySpot = spot and spot:IsA("BasePart") and spot or nil
	end
	local pos
	if tonySpot then
		pos = tonySpot.Position
	elseif MapConfig.Tony then
		pos = Vector3.new(MapConfig.Tony.x, hrp.Position.Y, MapConfig.Tony.z)
	else
		return false
	end
	return (hrp.Position - pos).Magnitude <= 24
end

local openPicker -- (opts) car picker / gear chooser, defined below

local TONY_ROW_H = 122
local function buildTony()
	local p = K.panelShell("tony", T("gears_title"), 920, 600, TONY)
	local head = K.inset(p.content, { Size = UDim2.new(1, 0, 0, 46), ZIndex = 22 })
	w.tonyTimer = K.text(head, { Text = "", TextSize = 22, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(300, 46), ZIndex = 23 })
	w.tonyHint = K.text(head, { Text = T("gears_hint"), Font = K.BODY, TextSize = 15, TextColor3 = P.muted, TextWrapped = true, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 0), Size = UDim2.new(1, -334, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 23 })
	local list = K.scroller(p.content, UDim2.fromOffset(0, 54), UDim2.new(1, 0, 1, -54))
	w.tonyRows = {}
	for i, def in ipairs(GearConfig.List) do
		local fr = row(list, i, TONY_ROW_H, def.color)
		local disc = K.new("Frame", { Position = UDim2.fromOffset(10, 13), Size = UDim2.fromOffset(96, 96), BackgroundColor3 = def.color:Lerp(P.white, 0.7), ZIndex = 24 }, fr)
		K.corner(disc, 48)
		K.stroke(disc, P.ink, 2)
		gearIcon(disc, def, 84, UDim2.fromOffset(6, 6), 25)
		K.text(fr, { Text = string.upper(def.name), TextSize = 24, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(120, 8), Size = UDim2.new(1, -470, 0, 30), ZIndex = 24 })
		K.text(fr, { Text = GearConfig.Label(def) .. "  ·  " .. gearMinutes(def), TextSize = 18, TextColor3 = K.lift(def.color, -0.4), Outline = false, Position = UDim2.fromOffset(120, 40),
			Size = UDim2.new(1, -470, 0, 24), ZIndex = 24 })
		K.text(fr, { Text = T("gears_aura") .. " " .. stars(def.tier), Font = K.BODY, TextSize = 16, TextColor3 = C(196, 140, 20), Position = UDim2.fromOffset(120, 66),
			Size = UDim2.new(1, -470, 0, 20), ZIndex = 24 })
		K.text(fr, { Text = def.desc, Font = K.BODY, TextSize = 14, TextColor3 = P.muted, Position = UDim2.fromOffset(120, 88), Size = UDim2.new(1, -470, 0, 20), ZIndex = 24 })
		local r = { def = def }
		-- right: stock + price above BUY, owned above APPLY
		r.stock = K.text(fr, { Text = "", Font = K.BODY, TextSize = 16, TextColor3 = P.ink, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -176, 0, 6), Size = UDim2.fromOffset(150, 22),
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 24 })
		r.price = K.text(fr, { Text = "", TextSize = 22, TextColor3 = GREEN_TXT, Outline = false, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -176, 0, 28), Size = UDim2.fromOffset(150, 28),
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 24 })
		r.buy = K.toy(fr, { Text = T("gears_buy"), Color = P.grey, Size = UDim2.fromOffset(150, 58), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -176, 0, 58), ZIndex = 25, TextSize = 22,
			OnClick = function()
				local st = K.store.State
				if not st then
					return
				end
				local stock = shopInfo(st)
				if ((st.gears or {})[def.id] or 0) >= GearConfig.MaxOwned then
					UI.Toast(T("n_gearMax"), "warn")
				elseif (stock[def.id] or 0) <= 0 then
					UI.Toast(T("gears_soldoutToast"), "warn")
				elseif (K.store.Money or 0) < gearPrice(def, st) then
					UI.Toast(T("gears_noMoney"), "warn")
				else
					K.actions.BuyGear(def.id)
				end
			end })
		r.own = K.text(fr, { Text = "", Font = K.BODY, TextSize = 16, TextColor3 = P.ink, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 6), Size = UDim2.fromOffset(150, 22),
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 24 })
		r.ownSub = K.text(fr, { Text = def.effects.income and T("gears_oneCar") or T("gears_whileParked"), Font = K.BODY, TextSize = 13, TextColor3 = P.muted, AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 30), Size = UDim2.fromOffset(150, 22), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 24 })
		r.apply = K.toy(fr, { Text = T("gears_apply"), Color = P.grey, Size = UDim2.fromOffset(150, 58), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 58), ZIndex = 25, TextSize = 22,
			OnClick = function()
				local st = K.store.State
				if st and ((st.gears or {})[def.id] or 0) > 0 then
					openPicker({ gear = def.id })
				else
					UI.Toast(T("gears_buyFirst"), "warn")
				end
			end })
		w.tonyRows[def.id] = r
	end
end

-- text-only refresh (no rebuild): runs on state pushes, money ticks and every second while the panel is open
local function refreshTony(st, open)
	if open ~= "tony" or not w.tonyRows then
		return
	end
	local stock, restock = shopInfo(st)
	w.tonyTimer.Text = T("gears_restock", fmtTime(restock))
	w.tonyHint.Text = nearTony() and T("gears_hint") or T("gears_far")
	local money = K.store.Money or 0
	for id, r in pairs(w.tonyRows) do
		local n = stock[id] or 0
		local price = gearPrice(r.def, st)
		local own = (st.gears or {})[id] or 0
		r.stock.Text = n > 0 and T("gears_stock", n) or T("gears_soldout")
		r.stock.TextColor3 = n > 0 and P.ink or RED_TXT
		r.price.Text = "$" .. Util.FormatNumber(price)
		r.price.TextColor3 = money >= price and GREEN_TXT or RED_TXT
		r.buy.SetText(n > 0 and T("gears_buy") or T("gears_soldoutBtn"), nil)
		r.buy.SetColor((n > 0 and money >= price and own < GearConfig.MaxOwned) and P.green or P.grey)
		r.own.Text = T("gears_ownMax", own, GearConfig.MaxOwned)
		r.own.TextColor3 = own > 0 and GREEN_TXT or P.muted
		r.apply.SetColor(own > 0 and P.blue or P.grey)
	end
end

---------------------------------------------------------------- gear picker: which car gets a gear / which gear goes on a car
local picker -- { dim, mode, gear, uid, st, labels = { { label, car } }, head }

local function closePicker()
	if picker then
		local dim = picker.dim
		picker = nil
		dim:Destroy()
	end
end

local function findCar(st, uid)
	for _, c in ipairs(st.cars or {}) do
		if c.uid == uid then
			return c
		end
	end
	return nil
end

-- "💨 x1.5 SPEED · 3:12" or "No gear"
local function gearStatus(car)
	local left = gearLeft(car)
	local def = left > 0 and GearConfig.ById[car.gear.id]
	if not def then
		return T("gears_noGear"), P.muted
	end
	return string.format("%s %s  ·  %s", def.icon, GearConfig.Label(def), fmtTime(left)), K.lift(def.color, -0.4)
end

local function applyGear(car, gearId)
	local def = GearConfig.ById[gearId]
	local left = gearLeft(car)
	local cur = left > 0 and GearConfig.ById[car.gear.id]
	local function go()
		K.actions.ApplyGear(car.uid, gearId)
		UI.Sfx("cash")
		closePicker()
	end
	if cur then
		-- the confirm sits above the picker; KEEP leaves the picker open
		K.confirm(T("gears_replaceTitle"), T("gears_replaceBody", cur.name, fmtTime(left), def.name), T("gears_replaceOk"), P.orange, go)
	else
		go()
	end
end

local PICK_ROW_H = 84
local MAX_PICK_CARS = 60
local function fillPicker()
	local st = K.store.State
	if not picker or not st then
		return
	end
	picker.st = st
	picker.labels = {}
	K.clear(picker.list)
	if picker.mode == "gear" then
		-- every car you own, parked first (speed / luck gears only work while the car is parked)
		local cars = table.clone(st.cars or {})
		local now = serverNow()
		table.sort(cars, function(a, b)
			if (a.slot ~= nil) ~= (b.slot ~= nil) then
				return a.slot ~= nil
			end
			local ia, ib = CarConfig.CarIncome(a, now), CarConfig.CarIncome(b, now)
			if ia ~= ib then
				return ia > ib
			end
			return a.uid < b.uid
		end)
		if #cars == 0 then
			K.text(picker.list, { Text = T("garage_empty"), Font = K.BODY, TextSize = 18, TextColor3 = P.muted, Size = UDim2.new(1, 0, 0, 40), ZIndex = 74, TextXAlignment = Enum.TextXAlignment.Center })
		end
		for i, car in ipairs(cars) do
			if i > MAX_PICK_CARS then
				break
			end
			local def = CarConfig.ById[car.typeId]
			if def then
				local rc = CarConfig.Rarities[def.rarity].color
				local fr = K.card(picker.list, { Size = UDim2.new(1, 0, 0, PICK_ROW_H), Accent = rc, Radius = 16, LayoutOrder = i, ZIndex = 73 })
				K.text(fr, { Text = def.name, TextSize = 20, TextColor3 = P.ink, Outline = false, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -200, 0, 26), ZIndex = 75 })
				K.text(fr, { Text = string.format("%s · Lv %d · +%s/s", car.slot and ("Bay " .. car.slot) or "Storage", car.level or 1, Util.FormatNumber(CarConfig.CarIncome(car, now))), Font = K.BODY,
					TextSize = 14, TextColor3 = P.muted, Position = UDim2.fromOffset(14, 32), Size = UDim2.new(1, -200, 0, 20), ZIndex = 75 })
				local status = K.text(fr, { Text = "", Font = K.BODY, TextSize = 15, TextColor3 = P.muted, Position = UDim2.fromOffset(14, 54), Size = UDim2.new(1, -200, 0, 20), ZIndex = 75 })
				table.insert(picker.labels, { label = status, car = car })
				local active = gearLeft(car) > 0
				K.toy(fr, { Text = active and T("gears_replace") or T("gears_apply"), Sub = (not car.slot) and T("gears_storage") or nil, SubSize = 11, Color = active and P.orange or P.green,
					Size = UDim2.fromOffset(150, 62), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), ZIndex = 76, TextSize = 20,
					OnClick = function()
						if picker and picker.gear then
							applyGear(car, picker.gear)
						end
					end })
			end
		end
	else
		-- one car: the gears you own
		local car = findCar(st, picker.uid)
		if not car then
			closePicker()
			return
		end
		local any = false
		for i, def in ipairs(GearConfig.List) do
			local own = (st.gears or {})[def.id] or 0
			if own > 0 then
				any = true
				local fr = K.card(picker.list, { Size = UDim2.new(1, 0, 0, PICK_ROW_H), Accent = def.color, Radius = 16, LayoutOrder = i, ZIndex = 73 })
				gearIcon(fr, def, 64, UDim2.fromOffset(10, 10), 75)
				K.text(fr, { Text = string.upper(def.name) .. "  x" .. own, TextSize = 20, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(84, 10), Size = UDim2.new(1, -250, 0, 26), ZIndex = 75 })
				K.text(fr, { Text = GearConfig.Label(def) .. "  ·  " .. gearMinutes(def), Font = K.BODY, TextSize = 15, TextColor3 = K.lift(def.color, -0.4), Position = UDim2.fromOffset(84, 40),
					Size = UDim2.new(1, -250, 0, 22), ZIndex = 75 })
				K.toy(fr, { Text = T("gears_apply"), Color = P.green, Size = UDim2.fromOffset(150, 62), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), ZIndex = 76, TextSize = 20,
					OnClick = function()
						applyGear(car, def.id)
					end })
			end
		end
		if not any then
			K.text(picker.list, { Text = T("gears_noneOwned"), Font = K.BODY, TextSize = 19, TextColor3 = P.muted, TextWrapped = true, Size = UDim2.new(1, 0, 0, 56), LayoutOrder = 1, ZIndex = 74,
				TextXAlignment = Enum.TextXAlignment.Center })
			local holder = K.new("Frame", { Size = UDim2.new(1, 0, 0, 70), BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 74 }, picker.list)
			K.toy(holder, { Text = T("gears_goTony"), Color = TONY, Size = UDim2.fromOffset(280, 64), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), ZIndex = 75, TextSize = 22,
				OnClick = function()
					closePicker()
					if K.state.open ~= "tony" then
						UI.TogglePanel("tony")
					end
				end })
		end
	end
end

-- countdowns in the picker (no rebuild)
local function tickPicker()
	if not picker then
		return
	end
	local st = K.store.State
	if picker.mode == "car" then
		local car = st and findCar(st, picker.uid)
		if car then
			local txt, col = gearStatus(car)
			picker.head.Text = T("gears_now") .. " " .. txt
			picker.head.TextColor3 = col
		end
	end
	for _, e in ipairs(picker.labels) do
		local txt, col = gearStatus(e.car)
		e.label.Text = txt
		e.label.TextColor3 = col
	end
end

-- opts: { gear = id } -> pick a car for that gear; { uid = carUid } -> pick a gear for that car
openPicker = function(opts)
	closePicker()
	local st = K.store.State
	if not st or K.state.cine then
		return
	end
	local title, color, sub
	if opts.gear then
		local def = GearConfig.ById[opts.gear]
		if not def then
			return
		end
		title, color = T("gears_pickCar", string.upper(def.name)), def.color
		sub = GearConfig.Label(def) .. "  ·  " .. gearMinutes(def) .. "  ·  " .. (def.effects.income and T("gears_oneCar") or T("gears_whileParked"))
	else
		local car = findCar(st, opts.uid)
		local cdef = car and CarConfig.ById[car.typeId]
		if not cdef then
			return
		end
		title, color, sub = T("gears_pickGear", string.upper(cdef.name)), TONY, ""
	end
	local dim = K.new("TextButton", { Name = "GearPicker", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 70 },
		K.overlay)
	local box, shell = K.dialogShell(dim, { Class = "TextButton", Size = UDim2.fromOffset(660, 520), ZIndex = 71, Color = color, HeadH = 60, Title = title, TitleSize = 28 })
	local sc = K.new("UIScale", { Scale = 0.6 }, shell)
	K.tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	K.toy(box, { Text = "X", Color = P.red, Size = UDim2.fromOffset(56, 60), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 12, 0, -16), ZIndex = 76, OnClick = closePicker })
	local head = K.text(box, { Text = sub, Font = K.BODY, TextSize = 17, TextColor3 = P.ink, Position = UDim2.fromOffset(24, 68), Size = UDim2.new(1, -48, 0, 26), ZIndex = 73,
		TextXAlignment = Enum.TextXAlignment.Center })
	local list = K.scroller(box, UDim2.fromOffset(16, 100), UDim2.new(1, -32, 1, -112))
	list.ZIndex = 72
	dim.Activated:Connect(closePicker)
	picker = { dim = dim, mode = opts.gear and "gear" or "car", gear = opts.gear, uid = opts.uid, head = head, list = list, labels = {}, panel = K.state.open }
	UI.SetDialog(true)
	dim.Destroying:Connect(function()
		UI.SetDialog(false)
		if picker and picker.dim == dim then
			picker = nil
		end
	end)
	fillPicker()
	tickPicker()
end

local function refreshPicker(st, open)
	if not picker then
		return
	end
	if open ~= picker.panel or K.state.cine then
		closePicker() -- the panel it came from closed (or another one opened)
	elseif st ~= picker.st then
		fillPicker() -- new state: owned gears / cars changed
		tickPicker()
	end
end

---------------------------------------------------------------- Jobs: active contracts, claimed anywhere in the safe zone
local JOBS = C(170, 120, 70)

-- "+$1,200   ⚙️ Engine x2" (sep: optional separator before the part)
local function rewardText(c, st, sep)
	local rw = c.reward
	if type(rw) ~= "table" then
		return ""
	end
	local mult = (st.passes and st.passes.double_contracts == true) and 2 or 1
	local def = PartConfig.Parts[rw.part]
	local part = def and string.format("%s%s %s x%d", sep or "   ", def.emoji, def.name, (rw.n or 1) * mult) or ""
	return "+$" .. Util.FormatNumber((rw.money or 0) * mult) .. part
end

local function anyReady(st)
	for _, c in ipairs(st.contracts or {}) do
		if c.ready then
			return true
		end
	end
	return false
end

local function buildJobs()
	local p = K.panelShell("jobs", T("jobs_title"), 880, 580, JOBS)
	w.jobsHint = K.text(p.content, { Text = T("jobs_hint"), Font = K.BODY, TextSize = 16, TextColor3 = P.muted, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -230, 0, 58),
		TextWrapped = true, ZIndex = 23 })
	w.jobsAll = K.toy(p.content, { Text = T("jobs_claimAll"), Color = P.green, Size = UDim2.fromOffset(210, 58), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
		ZIndex = 24, TextSize = 22, OnClick = function()
			if K.store.State and anyReady(K.store.State) then
				K.actions.Claim("all")
			end
		end })
	w.jobsList = K.scroller(p.content, UDim2.fromOffset(0, 70), UDim2.new(1, 0, 1, -70))
end

local JOB_ROW_H = 104
local function inSafeZone()
	local char = game:GetService("Players").LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return hrp ~= nil and MapConfig.ZoneAt(hrp.Position.Z) == "plaza"
end

local function refreshJobs(st, open)
	if open ~= "jobs" then
		return
	end
	local here = inSafeZone() -- claiming only works in the safe zone: outside, the buttons say where to go
	w.jobsAll.holder.Visible = anyReady(st) and here
	K.clear(w.jobsList)
	local list = st.contracts or {}
	if #list == 0 then
		K.text(w.jobsList, { Text = T("jobs_none"), Font = K.BODY, TextSize = 18, TextColor3 = P.muted, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 0, ZIndex = 23,
			TextXAlignment = Enum.TextXAlignment.Center })
	end
	for i, c in ipairs(list) do
		local n = math.max(math.floor(tonumber(c.n) or 1), 1)
		local prog = math.clamp(math.floor(tonumber(c.progress) or 0), 0, n)
		local r = row(w.jobsList, i, JOB_ROW_H, c.ready and P.green or nil)
		K.text(r, { Text = contractText(c), TextSize = 20, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -250, 0, 28), ZIndex = 24 })
		local bar = K.inset(r, { Position = UDim2.fromOffset(18, 48), Size = UDim2.new(1, -330, 0, 14), Radius = 7, ZIndex = 24 })
		local fill = K.new("Frame", { Size = UDim2.fromScale(c.ready and 1 or prog / n, 1), BackgroundColor3 = c.ready and P.yellow or C(70, 200, 100), BorderSizePixel = 0, ZIndex = 25 }, bar)
		K.corner(fill, 7)
		K.text(r, { Text = c.ready and "✅" or string.format("%d / %d", prog, n), Font = K.BODY, TextSize = 16, TextColor3 = P.ink, Position = UDim2.new(1, -306, 0, 42),
			Size = UDim2.fromOffset(60, 26), ZIndex = 24, TextXAlignment = Enum.TextXAlignment.Center })
		K.text(r, { Text = T("jobs_reward") .. "  " .. rewardText(c, st), Font = K.BODY, TextSize = 17, TextColor3 = GREEN_TXT, Position = UDim2.fromOffset(18, 72),
			Size = UDim2.new(1, -250, 0, 24), ZIndex = 24 })
		local canClaim = c.ready and here
		K.toy(r, { Text = canClaim and T("jobs_claim") or (c.ready and T("jobs_goSafe") or T("jobs_working")), Color = canClaim and P.green or P.grey,
			Size = UDim2.fromOffset(200, 60), AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0), ZIndex = 25, TextSize = canClaim and 24 or 16, OnClick = function()
				if c.ready and inSafeZone() then
					K.actions.Claim(c.id)
				end
			end })
	end
end

---------------------------------------------------------------- Welcome back (offline earnings)
local function showOffline(info)
	local dim = K.new("TextButton", { Name = "WelcomeBack", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 80 }, K.overlay)
	-- v23: shared dialog shell (shadow + green header strip); the amount sits on a white card
	local card, shell = K.dialogShell(dim, { Size = UDim2.fromOffset(520, 340), Radius = 28, ZIndex = 81, Color = P.green, HeadH = 64, Title = "WELCOME BACK!", TitleSize = 38 })
	local sc = K.new("UIScale", { Scale = 0.5 }, shell)
	K.tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	local h = math.floor(info.seconds / 3600)
	local m = math.floor(info.seconds % 3600 / 60)
	K.text(card, { Text = string.format("Your garage worked for %dh %02dm while you were away%s", h, m, info.capped and " (max 8h)" or ""), Font = K.BODY, TextSize = 17, TextColor3 = P.muted,
		TextWrapped = true, Position = UDim2.fromOffset(30, 72), Size = UDim2.new(1, -60, 0, 44), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 83 })
	local amount = K.card(card, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 122), Size = UDim2.fromOffset(400, 76), Radius = 18, ZIndex = 83 })
	K.new("ImageLabel", { Position = UDim2.fromOffset(40, 6), Size = UDim2.fromOffset(64, 64), BackgroundTransparency = 1, Image = require(game:GetService("ReplicatedStorage").Shared.Icons).Get("coin") or "", ZIndex = 85 }, amount)
	K.text(amount, { Text = "+$" .. Util.FormatNumber(info.amount), TextSize = 48, TextColor3 = C(70, 220, 100), Position = UDim2.fromOffset(114, 10), Size = UDim2.fromOffset(270, 56), ZIndex = 85, Outline = 3 })
	local function closeCard()
		dim:Destroy()
	end
	local btns = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20), Size = UDim2.fromOffset(470, 76), BackgroundTransparency = 1, ZIndex = 83 }, card)
	K.list(btns, Enum.FillDirection.Horizontal, 16, Enum.HorizontalAlignment.Center)
	K.toy(btns, { Text = "COLLECT", Color = P.green, Size = UDim2.fromOffset(210, 72), TextSize = 26, LayoutOrder = 1, ZIndex = 83, OnClick = closeCard })
	local x2 = DonateConfig.ById.offline_x2
	if x2 and DonateConfig.Available(x2, ProductIds, IS_STUDIO, randomRestricted) then
		K.toy(btns, { Text = "x2", Sub = "R$ " .. x2.price, Color = GOLD, Size = UDim2.fromOffset(150, 72), TextSize = 28, SubSize = 14, LayoutOrder = 2, ZIndex = 83,
			OnClick = function()
				K.actions.Donate("offline_x2")
				closeCard()
			end })
	end
	UI.Sfx("cash")
end

---------------------------------------------------------------- Rebirth + token shop
local function buildRebirth()
	local p = K.panelShell("rebirth", T("rebirth_title"), 860, 600, TEAL)
	-- v23: the conditions sit on their own white card instead of straight on the cream
	local info = K.card(p.content, { Size = UDim2.new(1, 0, 0, 146), Accent = TEAL, Radius = 18, ZIndex = 22 })
	w.rbInfo = K.text(info, { Text = "", Font = K.BODY, TextSize = 19, TextColor3 = P.ink, RichText = true, TextWrapped = true, Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 1, -20), TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 24 })
	w.rbGo = K.toy(p.content, { Text = T("rebirth_go"), Color = P.grey, Size = UDim2.fromOffset(300, 70), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 158),
		ZIndex = 24, TextSize = 28, OnClick = function()
			if w.rbArmed and os.clock() - w.rbArmed < 3 then
				w.rbArmed = nil
				K.actions.Rebirth()
				UI.TogglePanel(nil)
			else
				w.rbArmed = os.clock()
				UI.Refresh()
				task.delay(3.05, UI.Refresh) -- back from "SURE?" when the 3 s run out
			end
		end })
	w.rbTokens = K.text(p.content, { Text = "", TextSize = 22, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(0, 240), Size = UDim2.new(1, 0, 0, 28), ZIndex = 23 })
	w.rbShop = K.new("Frame", { Position = UDim2.fromOffset(0, 276), Size = UDim2.new(1, 0, 0, 200), BackgroundTransparency = 1, ZIndex = 23 }, p.content)
	K.new("UIGridLayout", { CellSize = UDim2.fromOffset(256, 190), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, w.rbShop)
	-- v25: opened from the REBIRTH button in the HUD row (buildHud), no longer from the garage
end

local function refreshRebirth(st, open)
	if open ~= "rebirth" then
		return
	end
	local n = st.rebirths or 0
	local zone, money = SkinConfig.RebirthNeeds(n)
	local zoneOk = st.zones and st.zones[zone]
	local ok = zoneOk and K.store.Money >= money
	local mult = 1 + SkinConfig.Rebirth.incomePer * (n + 1)
	local function mark(b)
		return b and '<font color="#1E9E40">✔</font>' or '<font color="#D6342C">✘</font>'
	end
	w.rbInfo.Text = string.format("%s %s\n%s\n%s\n%s", mark(ok), T("rebirth_need", T("zone_" .. zone), Util.FormatNumber(money)),
		'<font color="#D6342C">' .. T("rebirth_lose") .. "</font>", '<font color="#1E9E40">' .. T("rebirth_keep") .. "</font>", T("rebirth_gain", string.format("%.2f", mult)))
	local armed = w.rbArmed and os.clock() - w.rbArmed < 3
	w.rbGo.SetText(armed and T("btn_sure") or T("rebirth_go"), nil)
	w.rbGo.SetColor(ok and (armed and P.red or TEAL) or P.grey)
	w.rbTokens.Text = "🪙 " .. T("rebirth_tokens", st.tokens or 0) .. "   ·   " .. T("rebirth_shop")
	K.clear(w.rbShop)
	for i, def in ipairs(SkinConfig.TokenPerks) do
		local lvl = st.tokenPerks and st.tokenPerks[def.id] or 0
		local card = K.card(w.rbShop, { Radius = 18, LayoutOrder = i, ZIndex = 24 })
		K.text(card, { Text = def.icon, Font = K.BODY, TextSize = 36, Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 6), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 25 })
		K.text(card, { Text = string.upper(def.name), TextSize = 17, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(6, 54), Size = UDim2.new(1, -12, 0, 40), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 25 })
		K.text(card, { Text = string.format("%d / %d", lvl, def.max), Font = K.BODY, TextSize = 15, TextColor3 = P.muted, Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 25 })
		local maxed = lvl >= def.max
		K.toy(card, { Text = maxed and T("shop_max") or ("🪙 " .. def.cost), Color = maxed and P.yellow or ((st.tokens or 0) >= def.cost and P.orange or P.grey), Size = UDim2.fromOffset(170, 56),
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), ZIndex = 26, TextSize = 20, OnClick = function()
				if not maxed then
					K.actions.TokenPerk(def.id)
				end
			end })
	end
end

---------------------------------------------------------------- Tony's GEARS board: this player's stock, prices and the restock timer
local function refreshGearBoard(st)
	local stock, restock = shopInfo(st)
	for _, board in ipairs(CollectionService:GetTagged("GearBoard")) do
		local gui = board:FindFirstChild("BoardGui")
		if not gui then
			gui = K.new("SurfaceGui", { Name = "BoardGui", Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 40, LightInfluence = 0.1 }, board)
			K.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(36, 44, 70), BorderSizePixel = 0 }, gui)
			local head = K.new("Frame", { Size = UDim2.new(1, 0, 0, 68), BackgroundColor3 = C(22, 26, 42), BorderSizePixel = 0, ZIndex = 2 }, gui)
			K.text(head, { Text = T("gears_board"), TextSize = 56, TextColor3 = C(255, 205, 60), Outline = 3, Position = UDim2.fromOffset(18, 4), Size = UDim2.new(0.4, 0, 1, -8), ZIndex = 3 })
			K.text(head, { Name = "Timer", Text = "", TextSize = 30, TextColor3 = P.white, Outline = 2.5, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 10),
				Size = UDim2.new(0.58, 0, 1, -20), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3 })
		end
		local timer = gui:FindFirstChild("Timer", true)
		if timer then
			timer.Text = T("gears_restock", fmtTime(restock))
		end
	end
	for _, slot in ipairs(CollectionService:GetTagged("GearSlot")) do
		local def = GearConfig.List[slot:GetAttribute("Index") or 0]
		if def then
			local gui = slot:FindFirstChild("SlotGui")
			if not gui then
				gui = K.new("SurfaceGui", { Name = "SlotGui", Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 50, LightInfluence = 0.1 }, slot)
				local bg = K.new("Frame", { Name = "Bg", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(255, 248, 228), BorderSizePixel = 0 }, gui)
				K.new("Frame", { Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = def.color, BorderSizePixel = 0, ZIndex = 2 }, bg)
				gearIcon(bg, def, 84, UDim2.fromOffset(8, 16), 2)
				K.text(bg, { Text = string.upper(def.name), TextSize = 22, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(98, 16), Size = UDim2.new(1, -104, 0, 26), ZIndex = 2 })
				K.text(bg, { Text = GearConfig.Label(def), TextSize = 17, TextColor3 = K.lift(def.color, -0.45), Outline = false, Position = UDim2.fromOffset(98, 44), Size = UDim2.new(1, -104, 0, 22), ZIndex = 2 })
				K.text(bg, { Name = "Stock", Text = "", Font = K.BODY, TextSize = 18, TextColor3 = P.ink, Position = UDim2.fromOffset(98, 70), Size = UDim2.new(1, -104, 0, 24), ZIndex = 2 })
				K.text(bg, { Name = "Price", Text = "", TextSize = 32, TextColor3 = GREEN_TXT, Outline = false, Position = UDim2.fromOffset(8, 104), Size = UDim2.new(1, -16, 0, 38),
					TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2 })
			end
			local n = stock[def.id] or 0
			local price = gearPrice(def, st)
			local bg = gui.Bg
			bg.Stock.Text = n > 0 and T("gears_stock", n) or T("gears_soldout")
			bg.Stock.TextColor3 = n > 0 and P.ink or RED_TXT
			bg.Price.Text = "$" .. Util.FormatNumber(price)
			bg.Price.TextColor3 = (K.store.Money or 0) >= price and GREEN_TXT or RED_TXT
			bg.BackgroundColor3 = n > 0 and C(255, 248, 228) or C(214, 210, 202)
		end
	end
end

---------------------------------------------------------------- HUD widgets
local function buildHud()
	local root = K.root
	local colF = K.hud.leftCol
	-- SHOP, JOBS, REBIRTH (+ GIFTS 3, SETTINGS 4 added by their modules): square toy buttons with the 3D icons,
	-- label underneath; 5 x 66 + 4 x 12 = 378 px
	local brow = K.new("Frame", { Name = "Buttons", Size = UDim2.fromOffset(378, 94), BackgroundTransparency = 1, LayoutOrder = 2 }, colF)
	K.list(brow, Enum.FillDirection.Horizontal, 12)
	local function iconButton(name, label, color, order, onClick)
		-- bigger 3D sticker (54 px) and a clear gap to the label below the button
		local holder = K.new("Frame", { Size = UDim2.fromOffset(66, 94), BackgroundTransparency = 1, LayoutOrder = order }, brow)
		local b = K.toy(holder, { Name = label .. "Btn", Text = "", Color = color, Size = UDim2.fromOffset(66, 66), OnClick = onClick })
		K.hud.icon(b.face, name, 54, UDim2.fromOffset(6, 3)).ZIndex = b.face.ZIndex + 1
		local l = K.text(holder, { Text = label, TextSize = 15, Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, Outline = 2.5 })
		return b, l
	end
	w.shopBtn = iconButton("shop", T("btn_magnate"), GOLD, 1, function()
		UI.TogglePanel("donate")
	end)
	local jobsBtn = iconButton("jobs", T("btn_jobs"), C(170, 120, 70), 2, function()
		UI.TogglePanel("jobs")
	end)
	K.hud.jobsBtn = jobsBtn -- (the tutorial pulses it)
	-- red dot while a finished job waits to be claimed
	w.jobsDot = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(60, 4), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = P.red, ZIndex = 30,
		Visible = false }, jobsBtn.holder.Parent)
	K.corner(w.jobsDot, 9)
	K.stroke(w.jobsDot, P.white, 2)
	-- v25: REBIRTH has its own button next to SETTINGS (it used to hide in the garage panel)
	local _, rbLabel = iconButton("rebirth", T("btn_rebirth"), TEAL, 5, function()
		UI.TogglePanel("rebirth")
	end)
	rbLabel.Position = UDim2.fromOffset(-6, 72) -- the 7-letter word gets the same overhang as SETTINGS
	rbLabel.Size = UDim2.new(1, 12, 0, 20)
	-- active boosts strip to the right of the wallet card (clear of the 378 px button row)
	w.boosts = K.new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 400, 1, -24 - (K.hud.leftLift or 0)), Size = UDim2.fromOffset(560, 40), BackgroundTransparency = 1 }, root)
	K.list(w.boosts, Enum.FillDirection.Horizontal, 6)
	-- combo: one compact text line above THROW ("COMBO x1.5" + small speed-bonus timer), no card
	local combo = K.new("Frame", { Name = "Combo", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -138), Size = UDim2.fromOffset(360, 30), BackgroundTransparency = 1, Visible = false }, root)
	K.list(combo, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	w.combo = combo
	w.comboText = K.text(combo, { Text = "", TextSize = 24, TextColor3 = P.yellow, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), LayoutOrder = 1, Outline = 2.5 })
	w.comboSub = K.text(combo, { Text = "", Font = K.BODY, TextSize = 15, TextColor3 = P.white, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), LayoutOrder = 2 })
	K.new("UIStroke", { Color = P.ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, w.comboSub)
	w.comboScale = K.new("UIScale", {}, combo)
	-- contracts: plain outlined lines with a thin progress line (no card)
	local cw = K.new("Frame", { Name = "Contracts", Size = UDim2.fromOffset(280, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1 }, colF)
	K.list(cw, Enum.FillDirection.Vertical, 7)
	w.contracts = cw
	w.contractRows = {}
	-- the active jobs are always on screen; rewards are claimed anywhere in the safe zone (JOBS button)
	K.text(cw, { Text = T("jobs_hud"), TextSize = 16, TextColor3 = P.orange, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 0, Outline = 2.5 })
	-- hot drop banner
	-- top-right corner, same row as the zone banner: the very top, never under notifications or the objective card
	local hb = K.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 12), Size = UDim2.fromOffset(380, 42),
		BackgroundColor3 = P.red, Visible = false }, root)
	K.corner(hb, 14)
	K.stroke(hb, P.ink, 3)
	w.hot = hb
	w.hotText = K.text(hb, { Text = "", TextSize = 20, Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(6, 0), TextXAlignment = Enum.TextXAlignment.Center })
end

local CONTRACT_PART = function(c)
	return PartConfig.Parts[c.part] and (K.PART_ICON[c.part] .. " " .. T("part_" .. c.part)) or ""
end

contractText = function(c)
	if c.kind == "bank_rarity" then
		return T("c_bank_rarity", c.n, T("rarity_" .. tostring(c.rarity)))
	elseif c.kind == "catch_rarity" then
		return T("c_catch_rarity", T("rarity_" .. tostring(c.rarity)))
	elseif c.kind == "bank_part" then
		return T("c_bank_part", c.n, CONTRACT_PART(c), T("zone_" .. tostring(c.zone)))
	elseif c.kind == "combo" then
		return T("c_combo", tostring(c.mult))
	elseif c.kind == "speed" then
		return T("c_speed", c.seconds or 40)
	elseif c.kind == "throw" then
		return T("c_throw", c.n)
	elseif c.kind == "road" then
		return T("c_road", c.n)
	end
	return T("c_hotdrop")
end

-- player-wide gear effect: time left = the longest running parked car giving it, colour of the strongest gear
local function gearKind(st, kind)
	local left, col, best = 0, nil, 0
	for _, c in ipairs(st.cars or {}) do
		local g = c.slot and c.gear
		local def = g and GearConfig.ById[g.id]
		local m = def and def.effects[kind]
		if m then
			local l = gearLeft(c)
			if l > 0 then
				left = math.max(left, l)
				if m > best then
					best, col = m, def.color
				end
			end
		end
	end
	return left, col
end

-- the HUD pills are made once per kind (in display order) and only change text / colour / visibility
local PILL_ORDER = { "boost_income", "boost_luck", "gear_speed", "gear_luck", "vip" }
local function pillFor(key)
	w.pills = w.pills or {}
	local p = w.pills[key]
	if not p or not p.frame.Parent then
		local order = table.find(PILL_ORDER, key) or 0
		local frame, label = K.pill(w.boosts, "", GOLD, { H = 34, TextSize = 18, LayoutOrder = order })
		p = { frame = frame, label = label }
		w.pills[key] = p
	end
	return p
end
local function setPill(key, txt, color)
	local p = pillFor(key)
	if txt then
		p.label.Text = txt
		p.frame.BackgroundColor3 = color
	end
	p.frame.Visible = txt ~= nil
end

local function refreshPills(st)
	for _, b in ipairs({ { "income", "2X CASH" }, { "luck", "LUCK" } }) do
		local left = st.boosts and st.boosts[b[1]] or 0
		setPill("boost_" .. b[1], left > 0 and (b[2] .. " " .. fmtTime(left)) or nil, GOLD)
	end
	-- gears: SPEED x2 4:12, LUCK x1.5 9:40
	for _, kind in ipairs({ "speed", "luck" }) do
		local m = st.gearMults and tonumber(st.gearMults[kind]) or 1
		local txt, col
		if m > 1 then
			local left, c = gearKind(st, kind)
			if left > 0 then
				txt, col = string.upper(kind) .. " " .. fmtMult(m) .. " " .. fmtTime(left), c and K.lift(c, -0.15) or P.blue
			end
		end
		setPill("gear_" .. kind, txt, col)
	end
	setPill("vip", (st.passes and st.passes.vip) and "VIP" or nil, GOLD)
end

local function refreshHud(st)
	-- boosts + gear effects
	refreshPills(st)
	-- contracts
	for _, r in ipairs(w.contractRows) do
		r:Destroy()
	end
	w.contractRows = {}
	for i, c in ipairs(st.contracts or {}) do
		local row = K.new("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = i }, w.contracts)
		local line = c.ready and T("jobs_ready") or string.format("%d/%d   %s", c.progress, c.n, contractText(c))
		local lbl = K.text(row, { Text = line, Font = K.BODY, TextSize = 14, TextColor3 = c.ready and P.yellow or P.white, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, 0, 0, 18) })
		K.new("UIStroke", { Color = P.ink, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, lbl)
		local bar = K.new("Frame", { Position = UDim2.fromOffset(0, 21), Size = UDim2.fromOffset(250, 2), BackgroundColor3 = P.ink, BackgroundTransparency = 0.5, BorderSizePixel = 0 }, row)
		K.new("Frame", { Size = UDim2.fromScale(c.progress / c.n, 1), BackgroundColor3 = c.ready and P.yellow or C(70, 220, 100), BorderSizePixel = 0 }, bar)
		table.insert(w.contractRows, row)
	end
	w.contracts.Visible = #(st.contracts or {}) > 0 and K.state.open == nil
	w.jobsDot.Visible = anyReady(st)
	K.hud.leftCol.Visible = K.state.open == nil
end

local lastMult = 1

local function tick()
	local st = K.store.State
	if not st then
		return
	end
	local run = st.run or {}
	local picked = run.picked or 0
	w.combo.Visible = picked > 0 and K.state.open == nil
	if picked > 0 then
		local mult = run.mult or 1
		w.comboText.Text = T("combo", tostring(mult))
		local elapsed = run.firstAt and (Workspace:GetServerTimeNow() - run.firstAt) or 999
		local left = 40 - elapsed
		w.comboSub.Text = left > 0 and string.format("speed bonus %ds", math.ceil(left)) or "bank it at home"
		w.comboSub.TextColor3 = left > 0 and (left <= 10 and C(255, 120, 100) or P.white) or C(200, 200, 205)
		if mult > lastMult then
			w.comboScale.Scale = 1.2
			K.tween(w.comboScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			UI.Sfx("combo")
		end
		lastMult = mult
	else
		lastMult = 1
	end
	if hot then
		local now = Workspace:GetServerTimeNow()
		if hot.kind == "warn" then
			local left = hot.at - now
			w.hot.Visible = left > 0
			w.hotText.Text = T("hot_drop_in", T("zone_" .. hot.zone), math.ceil(left))
		else
			local landing = hot.landAt - now
			local left = hot.expiresAt - now
			w.hot.Visible = left > 0
			w.hotText.Text = "📦 " .. T("hot_drop") .. ": " .. string.upper(T("zone_" .. hot.zone)) .. "  " .. (landing > 0 and ("⬇ " .. math.ceil(landing)) or ("⏱ " .. math.ceil(left)))
		end
		if not w.hot.Visible then
			hot = nil
		end
	else
		w.hot.Visible = false
	end
end

function X.OnHotDrop(info)
	if info.kind == "warn" then
		hot = { kind = "warn", zone = info.zone, at = Workspace:GetServerTimeNow() + info.inSeconds }
	elseif info.kind == "start" then
		hot = info
		if info.by then
			UI.Toast(T("hot_drop_called", info.by), "warn")
		end
		UI.Sfx("siren")
	elseif info.kind == "end" then
		if hot and hot.id == info.id then
			hot = nil
		end
		if info.reason == "taken" and info.winner then
			UI.Toast(T("hot_drop_taken", info.winner), "info")
		end
	end
end

function X.HotDrop()
	return hot
end

function X.Init(ui)
	UI = ui
	K = UI.Kit()
	P = K.P
	buildShop()
	buildDonate()
	buildTony()
	buildJobs()
	buildRebirth()
	buildHud()
	-- garage GEAR button (UI.lua): its "x2 4:12" text and the gear chooser for that car
	UI.GearTag = gearTag
	UI.OnGear = function(uid)
		openPicker({ uid = uid })
	end
	table.insert(UI.Hooks, function(st, open)
		refreshShop(st, open)
		refreshDonate(st, open)
		refreshTony(st, open)
		refreshJobs(st, open)
		refreshRebirth(st, open)
		refreshHud(st)
		refreshGearBoard(st)
		refreshPicker(st, open)
	end)
	K.store.MoneyChanged.Event:Connect(function()
		local st = K.store.State
		if st and K.state.open == "shop" then
			refreshShop(st, "shop")
		elseif st and K.state.open == "tony" then
			refreshTony(st, "tony") -- prices + BUY buttons follow the wallet (text-only update)
		end
	end)
	require(Shared:WaitForChild("Net")).Get("OfflineEarnings").OnClientEvent:Connect(showOffline)
	-- walk up to the NPCs
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local n = prompt.Parent and prompt.Parent.Name
		if n == "ShopPrompt" then
			UI.TogglePanel("shop")
		elseif n == "DonatePrompt" then
			UI.TogglePanel("donate")
		elseif n == "MagnatPrompt" then
			-- Golden Magnat GT podium on the square: buy the game pass right here
			local st = K.store.State
			if st and st.passes and st.passes.golden_car then
				UI.Toast("You already own the Golden Magnat GT!", "good")
			else
				K.actions.Donate("golden_car")
			end
		elseif n == "TonyPrompt" then
			if K.state.open ~= "tony" then
				UI.TogglePanel("tony")
			end
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc >= 0.1 then
			acc = 0
			tick()
		end
	end)
	-- boost + gear timers count down locally between state pushes (text updates only)
	task.spawn(function()
		while true do
			task.wait(1)
			local st = K.store.State
			if st then
				if st.boosts then
					for k, v in pairs(st.boosts) do
						st.boosts[k] = math.max(0, v - 1)
					end
					if K.state.open == "donate" then
						refreshDonate(st, "donate")
					end
				end
				refreshPills(st)
				refreshTony(st, K.state.open)
				refreshGearBoard(st)
				tickPicker()
				if K.state.open == "garage" and UI.TickGarageGears then
					UI.TickGarageGears()
				end
			end
		end
	end)
end

return X
