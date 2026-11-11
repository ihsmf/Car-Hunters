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

local T = Strings.T
local C = Color3.fromRGB
local X = {}
local K, UI
local P
local w = {}
local hot = nil -- current hot drop info
local donateTab = "boost"

local function fmtTime(sec)
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

---------------------------------------------------------------- Pit Stop
local function buildShop()
	local p = K.panelShell("shop", T("shop_title"), 900, 580, P.red)
	local grid = K.new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 22 }, p.content)
	K.new("UIGridLayout", { CellSize = UDim2.fromOffset(204, 214), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	w.shopGrid = grid
end

local function refreshShop(st, open)
	if open ~= "shop" then
		return
	end
	K.clear(w.shopGrid)
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
local GOLD = C(232, 178, 50)
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

---------------------------------------------------------------- HUD widgets
local function buildHud()
	local root = K.root
	-- gold shop button under the parts row
	w.shopBtn = K.toy(root, { Name = "MagnateBtn", Text = T("btn_magnate"), Icon = "👑", Color = GOLD, Size = UDim2.fromOffset(96, 84),
		Position = UDim2.fromOffset(18, 178), OnClick = function() UI.TogglePanel("donate") end })
	-- active boosts strip next to the money pill
	w.boosts = K.new("Frame", { Position = UDim2.fromOffset(276, 24), Size = UDim2.fromOffset(240, 50), BackgroundTransparency = 1 }, root)
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
	-- contracts widget (left, below the shop button)
	local cw = K.new("Frame", { Position = UDim2.fromOffset(18, 272), Size = UDim2.fromOffset(300, 10), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C(255, 248, 232), BackgroundTransparency = 0.05 }, root)
	K.corner(cw, 16)
	K.stroke(cw, P.ink, 3)
	K.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8) }, cw)
	K.list(cw, Enum.FillDirection.Vertical, 4)
	K.text(cw, { Text = "📜 " .. T("contracts_title"), TextSize = 18, TextColor3 = C(140, 96, 56), Outline = false, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 0 })
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

local function contractText(c)
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
	for _, b in ipairs({ { "income", "💸 x2" }, { "luck", "🍀 x2" } }) do
		local left = st.boosts and st.boosts[b[1]] or 0
		if left > 0 then
			K.pill(w.boosts, b[2] .. " " .. fmtTime(left), GOLD, { H = 34, TextSize = 18 })
		end
	end
	if st.passes and st.passes.vip then
		K.pill(w.boosts, "⭐ VIP", GOLD, { H = 34, TextSize = 18 })
	end
	-- contracts
	for _, r in ipairs(w.contractRows) do
		r:Destroy()
	end
	w.contractRows = {}
	for i, c in ipairs(st.contracts or {}) do
		local row = K.new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = i }, w.contracts)
		K.text(row, { Text = contractText(c), Font = K.BODY, TextSize = 14, TextColor3 = P.ink, TextWrapped = true, Size = UDim2.new(1, -60, 0, 22), RichText = false })
		K.text(row, { Text = string.format("%d/%d", c.progress, c.n), TextSize = 16, TextColor3 = P.ink, Outline = false, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(56, 22), TextXAlignment = Enum.TextXAlignment.Right })
		local bar = K.new("Frame", { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = C(226, 218, 200) }, row)
		K.corner(bar, 4)
		local fill = K.new("Frame", { Size = UDim2.fromScale(c.progress / c.n, 1), BackgroundColor3 = P.green }, bar)
		K.corner(fill, 4)
		table.insert(w.contractRows, row)
	end
	w.contracts.Visible = #(st.contracts or {}) > 0 and K.state.open == nil
	w.shopBtn.holder.Visible = K.state.open == nil
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
	buildHud()
	table.insert(UI.Hooks, function(st, open)
		refreshShop(st, open)
		refreshDonate(st, open)
		refreshHud(st)
	end)
	K.store.MoneyChanged.Event:Connect(function()
		local st = K.store.State
		if st and K.state.open == "shop" then
			refreshShop(st, "shop")
		end
	end)
	-- walk up to the NPCs
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local n = prompt.Parent and prompt.Parent.Name
		if n == "ShopPrompt" then
			UI.TogglePanel("shop")
		elseif n == "DonatePrompt" then
			UI.TogglePanel("donate")
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
