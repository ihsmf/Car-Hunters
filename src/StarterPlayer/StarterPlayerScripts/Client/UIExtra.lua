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
local MapConfig = require(Shared:WaitForChild("MapConfig"))
local PartConfig = require(Shared:WaitForChild("PartConfig"))
local TuningConfig = require(Shared:WaitForChild("TuningConfig"))
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
local tonyTab = "rewards"
local shopTab = "perks"
local tuneUid = nil
local TONY = C(30, 36, 58)
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
	K.new("UIGridLayout", { CellSize = UDim2.fromOffset(204, 214), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	w.shopGrid = grid
end

local function refreshSkins(st)
	for _, def in ipairs(SkinConfig.Skins) do
		local owned = (st.skins and st.skins[def.id]) or (def.pass and st.passes and st.passes[def.pass])
		local on = st.skin == def.id
		local card = K.new("Frame", { BackgroundColor3 = def.style.wall:Lerp(Color3.new(1, 1, 1), 0.75), LayoutOrder = def.order, ZIndex = 23 }, w.shopGrid)
		K.corner(card, 20)
		K.stroke(card, on and P.green or P.ink, on and 5 or 3)
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
		local card = K.new("Frame", { BackgroundColor3 = P.white, LayoutOrder = def.order, ZIndex = 23 }, w.shopGrid)
		K.corner(card, 20)
		K.stroke(card, P.ink, 3)
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
	K.new("UIGridLayout", { CellSize = UDim2.fromOffset(204, 200), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
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
		if it.tab == donateTab then
			local owned = it.isPass and st.passes and st.passes[it.id]
			local card = K.new("Frame", { BackgroundColor3 = C(255, 250, 236), LayoutOrder = it.order, ZIndex = 23 }, w.donateGrid)
			K.corner(card, 20)
			K.stroke(card, GOLD, 4)
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

---------------------------------------------------------------- Big Tony: rewards + exchange
local function costLine(r, st)
	local bits = {}
	local function add(have, need, label)
		local col = have >= need and "#1E9E40" or "#D6342C"
		table.insert(bits, string.format('<font color="%s">%s</font>', col, label))
	end
	for _, part in ipairs(PartConfig.Order or { "bolts", "tire", "engine", "turbo", "core" }) do
		local n = r.parts and r.parts[part]
		if n then
			add(st.parts[part] or 0, n, K.PART_ICON[part] .. n)
		end
	end
	for item, n in pairs(r.tune or {}) do
		local it = TuningConfig.Items[item]
		add((st.tuning or {})[item] or 0, n, it.icon .. it.name .. " x" .. n)
	end
	add(K.store.Money, r.money, "$" .. Util.FormatNumber(r.money))
	return table.concat(bits, "  ")
end

local function buildTony()
	local p = K.panelShell("tony", T("tony_title"), 920, 600, TONY)
	local tabs = K.new("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1, ZIndex = 22 }, p.content)
	K.list(tabs, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center)
	w.tonyTabs = {}
	for i, tab in ipairs({ "rewards", "exchange" }) do
		w.tonyTabs[tab] = K.toy(tabs, { Text = T("tony_" .. tab), Color = P.grey, Size = UDim2.fromOffset(200, 52), LayoutOrder = i, ZIndex = 23, TextSize = 20,
			OnClick = function()
				tonyTab = tab
				UI.Refresh()
			end })
	end
	w.tonyList = K.scroller(p.content, UDim2.fromOffset(0, 66), UDim2.new(1, 0, 1, -66))
end

local function row(parent, order, h, accent)
	local r = K.new("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = P.white, LayoutOrder = order, ZIndex = 23 }, parent)
	K.corner(r, 18)
	K.stroke(r, accent or P.ink, 3)
	return r
end

local function refreshTony(st, open)
	if open ~= "tony" then
		return
	end
	for tab, b in pairs(w.tonyTabs) do
		b.SetColor(tab == tonyTab and P.yellow or P.grey)
	end
	K.clear(w.tonyList)
	if tonyTab == "rewards" then
		K.text(w.tonyList, { Text = T("tony_hint"), Font = K.BODY, TextSize = 16, TextColor3 = P.muted, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 0, ZIndex = 23, TextXAlignment = Enum.TextXAlignment.Center })
		for i, c in ipairs(st.contracts or {}) do
			local r = row(w.tonyList, i, 84, c.ready and P.green or P.ink)
			K.text(r, { Text = contractText(c), TextSize = 20, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -260, 0, 30), ZIndex = 24 })
			local part = c.reward and K.PART_ICON[c.reward.part] or ""
			K.text(r, { Text = string.format("%d/%d   ·   +$%s  %s x%d", c.progress, c.n, Util.FormatNumber(c.reward.money), part, c.reward.n), Font = K.BODY, TextSize = 16,
				TextColor3 = P.muted, Position = UDim2.fromOffset(18, 44), Size = UDim2.new(1, -260, 0, 26), ZIndex = 24 })
			K.toy(r, { Text = c.ready and T("tony_claim") or T("tony_working"), Color = c.ready and P.green or P.grey, Size = UDim2.fromOffset(200, 60), AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0), ZIndex = 25, TextSize = c.ready and 24 or 16,
				OnClick = function()
					if c.ready then
						K.actions.Claim(c.id)
					end
				end })
		end
	else
		for i, r in ipairs(TuningConfig.Recipes) do
			local it = TuningConfig.Items[r.out]
			local fr = row(w.tonyList, i, 78)
			K.text(fr, { Text = it.icon, Font = K.BODY, TextSize = 34, Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(50, 78), ZIndex = 24, TextXAlignment = Enum.TextXAlignment.Center })
			K.text(fr, { Text = string.format("%s  <font color=\"#1E9E40\">+%d%%</font>", string.upper(it.name), math.floor(it.bonus * 100 + 0.5)), RichText = true, TextSize = 20,
				TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(70, 8), Size = UDim2.new(1, -300, 0, 28), ZIndex = 24 })
			K.text(fr, { Text = costLine(r, st), RichText = true, Font = K.BODY, TextSize = 15, TextColor3 = P.muted, Position = UDim2.fromOffset(70, 40), Size = UDim2.new(1, -300, 0, 26), ZIndex = 24 })
			K.text(fr, { Text = T("tony_have", (st.tuning or {})[r.out] or 0), Font = K.BODY, TextSize = 14, TextColor3 = P.muted, AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -184, 0.5, 0), Size = UDim2.fromOffset(70, 20), ZIndex = 24, TextXAlignment = Enum.TextXAlignment.Right })
			K.toy(fr, { Text = T("tony_build"), Color = P.orange, Size = UDim2.fromOffset(160, 58), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
				ZIndex = 25, TextSize = 22, OnClick = function() K.actions.Craft(r.id) end })
		end
	end
end

---------------------------------------------------------------- Tuning a car
local function buildTune()
	local p = K.panelShell("tune", T("tune_title"), 900, 600, P.yellow)
	w.tuneHead = K.text(p.content, { Text = "", TextSize = 22, TextColor3 = P.ink, Outline = false, Size = UDim2.new(1, 0, 0, 30), RichText = true, ZIndex = 23 })
	w.tuneList = K.scroller(p.content, UDim2.fromOffset(0, 38), UDim2.new(1, 0, 1, -38))
end

local function refreshTune(st, open)
	if open ~= "tune" then
		return
	end
	local car
	for _, c in ipairs(st.cars) do
		if c.uid == tuneUid then
			car = c
		end
	end
	K.clear(w.tuneList)
	if not car then
		w.tuneHead.Text = ""
		return
	end
	local def = CarConfig.ById[car.typeId]
	local mult = TuningConfig.CarMult(car.tune)
	w.tuneHead.Text = string.format('%s   <font color="#1E9E40">+%s/s  (x%.2f)</font>', def.name, Util.FormatNumber(CarConfig.CarIncome(car)), mult)
	for i, cat in ipairs(TuningConfig.Categories) do
		local cur = car.tune and car.tune[cat.id]
		local curIt = cur and TuningConfig.Items[cur]
		local fr = row(w.tuneList, i, 76, curIt and P.green or P.ink)
		K.text(fr, { Text = cat.icon, Font = K.BODY, TextSize = 30, Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(46, 76), ZIndex = 24, TextXAlignment = Enum.TextXAlignment.Center })
		K.text(fr, { Text = string.upper(cat.name), TextSize = 18, TextColor3 = P.muted, Outline = false, Position = UDim2.fromOffset(62, 6), Size = UDim2.fromOffset(160, 22), ZIndex = 24 })
		K.text(fr, { Text = curIt and string.format("%s +%d%%", curIt.name, math.floor(curIt.bonus * 100 + 0.5)) or T("tune_empty"), TextSize = 18,
			TextColor3 = curIt and P.ink or P.muted, Outline = false, Position = UDim2.fromOffset(62, 32), Size = UDim2.fromOffset(220, 30), ZIndex = 24 })
		local opts = K.new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(540, 60), BackgroundTransparency = 1, ZIndex = 24 }, fr)
		K.list(opts, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
		local any = false
		for _, id in ipairs(TuningConfig.Order) do
			local it = TuningConfig.Items[id]
			local have = (st.tuning or {})[id] or 0
			if it.cat == cat.id and have > 0 then
				any = true
				K.toy(opts, { Text = it.icon .. " " .. string.rep("I", it.stage), Sub = "x" .. have, SubSize = 12, TextSize = 16, Color = P.blue, Size = UDim2.fromOffset(96, 54),
					LayoutOrder = it.stage, ZIndex = 25, OnClick = function() K.actions.Tune(car.uid, cat.id, id) end })
			end
		end
		if curIt then
			K.toy(opts, { Text = T("tune_remove"), Color = P.red, Size = UDim2.fromOffset(110, 54), TextSize = 16, LayoutOrder = 9, ZIndex = 25,
				OnClick = function() K.actions.Tune(car.uid, cat.id, nil) end })
		elseif not any then
			K.text(opts, { Text = T("tune_none"), Font = K.BODY, TextSize = 14, TextColor3 = P.muted, Size = UDim2.fromOffset(260, 30), ZIndex = 25, TextXAlignment = Enum.TextXAlignment.Right })
		end
	end
end

---------------------------------------------------------------- Welcome back (offline earnings)
local function showOffline(info)
	local dim = K.new("TextButton", { Name = "WelcomeBack", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 80 }, K.gui)
	local card = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(520, 330), BackgroundColor3 = P.cream, ZIndex = 81 }, dim)
	K.corner(card, 28)
	K.stroke(card, P.ink, 5)
	local sc = K.new("UIScale", { Scale = 0.5 }, card)
	K.tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	K.text(card, { Text = "WELCOME BACK!", TextSize = 42, Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 48), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 82, Outline = 3 })
	local h = math.floor(info.seconds / 3600)
	local m = math.floor(info.seconds % 3600 / 60)
	K.text(card, { Text = string.format("Your garage worked for %dh %02dm while you were away%s", h, m, info.capped and " (max 8h)" or ""), Font = K.BODY, TextSize = 17, TextColor3 = P.muted,
		TextWrapped = true, Position = UDim2.fromOffset(30, 72), Size = UDim2.new(1, -60, 0, 44), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 82 })
	K.new("ImageLabel", { Position = UDim2.fromOffset(110, 128), Size = UDim2.fromOffset(64, 64), BackgroundTransparency = 1, Image = require(game:GetService("ReplicatedStorage").Shared.Icons).Get("coin") or "", ZIndex = 82 }, card)
	K.text(card, { Text = "+$" .. Util.FormatNumber(info.amount), TextSize = 48, TextColor3 = C(70, 220, 100), Position = UDim2.fromOffset(184, 132), Size = UDim2.fromOffset(300, 56), ZIndex = 82, Outline = 3 })
	local function closeCard()
		dim:Destroy()
	end
	local btns = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -22), Size = UDim2.fromOffset(470, 76), BackgroundTransparency = 1, ZIndex = 82 }, card)
	K.list(btns, Enum.FillDirection.Horizontal, 16, Enum.HorizontalAlignment.Center)
	K.toy(btns, { Text = "COLLECT", Color = P.green, Size = UDim2.fromOffset(210, 72), TextSize = 26, LayoutOrder = 1, ZIndex = 83, OnClick = closeCard })
	K.toy(btns, { Text = "x2", Sub = "R$ " .. ((DonateConfig.ById.offline_x2 or {}).price or "?"), Color = GOLD, Size = UDim2.fromOffset(150, 72), TextSize = 28, SubSize = 14, LayoutOrder = 2, ZIndex = 83,
		OnClick = function()
			K.actions.Donate("offline_x2")
			closeCard()
		end })
	UI.Sfx("cash")
end

---------------------------------------------------------------- Rebirth + token shop
local function buildRebirth()
	local p = K.panelShell("rebirth", T("rebirth_title"), 860, 600, TEAL)
	w.rbInfo = K.text(p.content, { Text = "", Font = K.BODY, TextSize = 19, TextColor3 = P.ink, RichText = true, TextWrapped = true, Size = UDim2.new(1, 0, 0, 150),
		TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 23 })
	w.rbGo = K.toy(p.content, { Text = T("rebirth_go"), Color = P.grey, Size = UDim2.fromOffset(300, 70), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 158),
		ZIndex = 24, TextSize = 28, OnClick = function()
			if w.rbArmed and os.clock() - w.rbArmed < 3 then
				w.rbArmed = nil
				K.actions.Rebirth()
				UI.TogglePanel(nil)
			else
				w.rbArmed = os.clock()
				UI.Refresh()
			end
		end })
	w.rbTokens = K.text(p.content, { Text = "", TextSize = 22, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(0, 240), Size = UDim2.new(1, 0, 0, 28), ZIndex = 23 })
	w.rbShop = K.new("Frame", { Position = UDim2.fromOffset(0, 276), Size = UDim2.new(1, 0, 0, 200), BackgroundTransparency = 1, ZIndex = 23 }, p.content)
	K.new("UIGridLayout", { CellSize = UDim2.fromOffset(256, 190), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, w.rbShop)
	-- button in the garage panel
	local gp = K.panels.garage
	if gp then
		K.toy(gp.content, { Text = T("btn_rebirth"), Icon = "♻️", Color = TEAL, Size = UDim2.fromOffset(150, 54), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -372, 0, -2),
			ZIndex = 23, TextSize = 17, OnClick = function() UI.TogglePanel("rebirth") end })
	end
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
		local card = K.new("Frame", { BackgroundColor3 = P.white, LayoutOrder = i, ZIndex = 24 }, w.rbShop)
		K.corner(card, 18)
		K.stroke(card, P.ink, 3)
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

---------------------------------------------------------------- contract cards on the board (local player's jobs)
local function refreshBoard(st)
	for _, card in ipairs(CollectionService:GetTagged("ContractCard")) do
		local idx = card:GetAttribute("Index")
		local c = st.contracts and st.contracts[idx]
		local gui = card:FindFirstChild("CardGui")
		if not gui then
			gui = K.new("SurfaceGui", { Name = "CardGui", Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 40, LightInfluence = 0.2 }, card)
			K.new("Frame", { Name = "Bg", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(255, 248, 228) }, gui)
			K.text(gui, { Name = "Title", Text = "", TextSize = 30, TextColor3 = P.ink, Outline = false, Position = UDim2.new(0, 14, 0, 20), Size = UDim2.new(1, -28, 0.45, 0),
				TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2 })
			K.text(gui, { Name = "Prog", Text = "", TextSize = 40, TextColor3 = P.ink, Outline = false, Position = UDim2.new(0, 0, 0.55, 0), Size = UDim2.new(1, 0, 0, 48),
				TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2 })
			K.text(gui, { Name = "Reward", Text = "", Font = K.BODY, TextSize = 26, TextColor3 = C(30, 158, 64), Outline = false, Position = UDim2.new(0, 0, 0.75, 0), Size = UDim2.new(1, 0, 0, 34),
				TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2 })
		end
		if c then
			gui.Title.Text = contractText(c)
			gui.Prog.Text = c.ready and "✅ CLAIM AT TONY" or string.format("%d / %d", c.progress, c.n)
			gui.Prog.TextColor3 = c.ready and C(30, 158, 64) or P.ink
			gui.Reward.Text = "+$" .. Util.FormatNumber(c.reward.money) .. "  " .. (K.PART_ICON[c.reward.part] or "") .. "x" .. c.reward.n
			gui.Bg.BackgroundColor3 = c.ready and C(220, 250, 226) or C(255, 248, 228)
		else
			gui.Title.Text, gui.Prog.Text, gui.Reward.Text = "NEW JOB SOON", "...", ""
			gui.Bg.BackgroundColor3 = C(235, 230, 218)
		end
	end
end

---------------------------------------------------------------- HUD widgets
local function buildHud()
	local root = K.root
	local colF = K.hud.leftCol
	-- SHOP + JOBS: square toy buttons with the 3D icons, label underneath
	local brow = K.new("Frame", { Name = "Buttons", Size = UDim2.fromOffset(280, 88), BackgroundTransparency = 1, LayoutOrder = 4 }, colF)
	K.list(brow, Enum.FillDirection.Horizontal, 12)
	local function iconButton(name, label, color, order, onClick)
		local holder = K.new("Frame", { Size = UDim2.fromOffset(66, 88), BackgroundTransparency = 1, LayoutOrder = order }, brow)
		local b = K.toy(holder, { Name = label .. "Btn", Text = "", Color = color, Size = UDim2.fromOffset(66, 66), OnClick = onClick })
		K.hud.icon(b.face, name, 46, UDim2.fromOffset(10, 8)).ZIndex = b.face.ZIndex + 1
		local l = K.text(holder, { Text = label, TextSize = 15, Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, Outline = 2.5 })
		return b, l
	end
	w.shopBtn = iconButton("shop", T("btn_magnate"), GOLD, 1, function()
		UI.TogglePanel("donate")
	end)
	w.jobsOpen = true
	w.jobsBtn, w.jobsLabel = iconButton("jobs", "JOBS", P.orange, 2, function()
		w.jobsOpen = not w.jobsOpen
		UI.Refresh()
	end)
	-- active boosts strip to the right of the wallet card
	w.boosts = K.new("Frame", { Position = UDim2.fromOffset(310, 18), Size = UDim2.fromOffset(240, 40), BackgroundTransparency = 1 }, root)
	K.list(w.boosts, Enum.FillDirection.Horizontal, 6)
	-- combo meter (bottom left, above the jump area of mobile thumbstick? left of THROW)
	local combo = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -140), Size = UDim2.fromOffset(300, 74), BackgroundColor3 = P.ink, Visible = false }, root)
	K.corner(combo, 20)
	K.stroke(combo, P.white, 3)
	w.combo = combo
	w.comboText = K.text(combo, { Text = "", TextSize = 34, TextColor3 = P.yellow, Position = UDim2.fromOffset(14, 4), Size = UDim2.new(1, -28, 0, 38), TextXAlignment = Enum.TextXAlignment.Center })
	local bar = K.new("Frame", { Position = UDim2.fromOffset(14, 46), Size = UDim2.new(1, -28, 0, 12), BackgroundColor3 = C(70, 74, 84) }, combo)
	K.corner(bar, 6)
	w.comboFill = K.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = P.orange }, bar)
	K.corner(w.comboFill, 6)
	w.comboSub = K.text(combo, { Text = "", Font = K.BODY, TextSize = 13, TextColor3 = P.white, Position = UDim2.fromOffset(14, 58), Size = UDim2.new(1, -28, 0, 14), TextXAlignment = Enum.TextXAlignment.Center })
	w.comboScale = K.new("UIScale", {}, combo)
	-- contracts: plain outlined lines with a thin progress line (no card)
	local cw = K.new("Frame", { Name = "Contracts", Size = UDim2.fromOffset(280, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 5 }, colF)
	K.list(cw, Enum.FillDirection.Vertical, 7)
	w.contracts = cw
	w.contractRows = {}
	-- hot drop banner
	local hb = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 118), Size = UDim2.fromOffset(420, 44), BackgroundColor3 = P.red, Visible = false }, root)
	K.corner(hb, 14)
	K.stroke(hb, P.ink, 3)
	w.hot = hb
	w.hotText = K.text(hb, { Text = "", TextSize = 22, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
end

local CONTRACT_PART = function(c)
	return PartConfig.Parts[c.part] and (K.PART_ICON[c.part] .. " " .. T("part_" .. c.part)) or ""
end

contractText = function(c)
	if c.kind == "bank_part" then
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

local function refreshHud(st)
	-- boosts
	K.clear(w.boosts)
	for _, b in ipairs({ { "income", "2X CASH" }, { "luck", "LUCK" } }) do
		local left = st.boosts and st.boosts[b[1]] or 0
		if left > 0 then
			K.pill(w.boosts, b[2] .. " " .. fmtTime(left), GOLD, { H = 34, TextSize = 18 })
		end
	end
	if st.passes and st.passes.vip then
		K.pill(w.boosts, "VIP", GOLD, { H = 34, TextSize = 18 })
	end
	-- contracts
	for _, r in ipairs(w.contractRows) do
		r:Destroy()
	end
	w.contractRows = {}
	for i, c in ipairs(st.contracts or {}) do
		local row = K.new("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = i }, w.contracts)
		local line = c.ready and "READY  -  see Big Tony" or string.format("%d/%d   %s", c.progress, c.n, contractText(c))
		local lbl = K.text(row, { Text = line, Font = K.BODY, TextSize = 14, TextColor3 = c.ready and P.yellow or P.white, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, 0, 0, 18) })
		K.new("UIStroke", { Color = P.ink, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, lbl)
		local bar = K.new("Frame", { Position = UDim2.fromOffset(0, 21), Size = UDim2.fromOffset(250, 2), BackgroundColor3 = P.ink, BackgroundTransparency = 0.5, BorderSizePixel = 0 }, row)
		K.new("Frame", { Size = UDim2.fromScale(c.progress / c.n, 1), BackgroundColor3 = c.ready and P.yellow or C(70, 220, 100), BorderSizePixel = 0 }, bar)
		table.insert(w.contractRows, row)
	end
	w.contracts.Visible = w.jobsOpen and #(st.contracts or {}) > 0 and K.state.open == nil
	K.hud.leftCol.Visible = K.state.open == nil
	local ready = 0
	for _, c in ipairs(st.contracts or {}) do
		if c.ready then
			ready = ready + 1
		end
	end
	w.jobsLabel.Text = ready > 0 and ("JOBS " .. ready .. "!") or "JOBS"
end

local NEXT_TIER = { { 2, 1.5 }, { 4, 2 }, { 7, 3 } }
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
		local nextAt, prevAt = nil, 0
		for _, t in ipairs(NEXT_TIER) do
			if picked < t[1] then
				nextAt = t[1]
				break
			end
			prevAt = t[1]
		end
		w.comboText.Text = T("combo", tostring(mult))
		w.comboFill.Size = UDim2.fromScale(nextAt and (picked - prevAt) / (nextAt - prevAt) or 1, 1)
		local elapsed = run.firstAt and (Workspace:GetServerTimeNow() - run.firstAt) or 999
		local left = 40 - elapsed
		w.comboSub.Text = left > 0 and (T("combo_hint") .. "  ⏱ " .. T("speed_bonus", math.ceil(left))) or T("combo_hint")
		if mult > lastMult then
			w.comboScale.Scale = 1.35
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
	buildTune()
	buildRebirth()
	buildHud()
	UI.OnTune = function(uid)
		tuneUid = uid
		UI.TogglePanel("tune")
	end
	table.insert(UI.Hooks, function(st, open)
		refreshShop(st, open)
		refreshDonate(st, open)
		refreshTony(st, open)
		refreshTune(st, open)
		refreshRebirth(st, open)
		refreshHud(st)
		refreshBoard(st)
	end)
	K.store.MoneyChanged.Event:Connect(function()
		local st = K.store.State
		if st and K.state.open == "shop" then
			refreshShop(st, "shop")
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
		elseif n == "TonyPrompt" then
			tonyTab = "rewards"
			for _, c in ipairs(K.store.State and K.store.State.contracts or {}) do
				if c.ready then
					K.actions.Claim("all") -- walking up pays out everything that's done
					break
				end
			end
			UI.TogglePanel("tony")
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
	-- boost timers count down locally between state pushes
	task.spawn(function()
		while true do
			task.wait(1)
			local st = K.store.State
			if st and st.boosts then
				for k, v in pairs(st.boosts) do
					st.boosts[k] = math.max(0, v - 1)
				end
				refreshHud(st)
				if K.state.open == "donate" then
					refreshDonate(st, "donate")
				end
			end
		end
	end)
end

return X
