-- CAR HUNTERS UI (design: Figma "CAR HUNTERS — Game UI"). Toy buttons, cartoon fonts, no purple.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local Util = require(Shared:WaitForChild("Util"))
local MapConfig = require(Shared:WaitForChild("MapConfig"))
local PartConfig = require(Shared:WaitForChild("PartConfig"))
local CarConfig = require(Shared:WaitForChild("CarConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local VehicleFactory = require(Shared:WaitForChild("VehicleFactory"))

local T = Strings.T
local C = Color3.fromRGB
local HEAD = Enum.Font.LuckiestGuy
local BODY = Enum.Font.FredokaOne

local P = {
	yellow = C(255, 210, 63), orange = C(255, 138, 31), red = C(255, 59, 59), green = C(52, 208, 88),
	blue = C(46, 168, 255), cyan = C(34, 224, 224), ink = C(27, 31, 42), white = C(255, 255, 255),
	cream = C(255, 246, 224), grey = C(170, 176, 188), muted = C(96, 102, 116),
}
local PART_ICON = { bolts = "🔩", tire = "🛞", engine = "⚙️", turbo = "🌀", core = "⚡" }
local ZONE_ICON = { city = "🏙️", highway = "🛣️", industrial = "🏭", neon = "🌃" }
local ZONE_COLOR = { city = P.green, highway = P.blue, industrial = P.red, neon = P.cyan, plaza = P.orange }

local UI = {}
local store, actions
local gui, root
local hud, panels = {}, {}
local state = { selectedPart = nil, nearTrap = false, open = nil, sellArm = {} }
local sounds = {}

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function corner(o, r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 16) }, o)
end
local function stroke(o, color, th)
	return new("UIStroke", { Color = color or P.ink, Thickness = th or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function lift(c, k)
	return c:Lerp(k > 0 and P.white or C(0, 0, 0), math.abs(k))
end
local function gradient(o, c)
	return new("UIGradient", { Color = ColorSequence.new(lift(c, 0.35), c), Rotation = 90 }, o)
end
local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function text(parent, props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1, Font = HEAD, TextColor3 = P.white, TextScaled = false, TextSize = 22,
		Size = UDim2.new(1, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
	for k, v in pairs(props) do
		if k ~= "Outline" then
			l[k] = v
		end
	end
	if props.Outline ~= false and l.Font == HEAD then
		new("UIStroke", { Color = P.ink, Thickness = props.Outline or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, l)
	end
	return l
end
local function clear(f)
	for _, c in ipairs(f:GetChildren()) do
		if not c:IsA("UIListLayout") and not c:IsA("UIGridLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end
local function list(o, dir, gap, ha, va)
	return new("UIListLayout", { FillDirection = dir or Enum.FillDirection.Vertical, Padding = UDim.new(0, gap or 8),
		HorizontalAlignment = ha or Enum.HorizontalAlignment.Left, VerticalAlignment = va or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder }, o)
end

-- Toy button: shadow slab + face with gradient, ink outline, outlined label. Returns api.
local function toy(parent, o)
	local holder = new("Frame", { Name = o.Name or "Toy", BackgroundTransparency = 1, Size = o.Size, Position = o.Position or UDim2.new(),
		AnchorPoint = o.AnchorPoint or Vector2.zero, LayoutOrder = o.LayoutOrder or 0, ZIndex = o.ZIndex or 1 }, parent)
	local depth = o.Depth or 6
	local shadow = new("Frame", { BackgroundColor3 = lift(o.Color, -0.55), Size = UDim2.new(1, 0, 1, -depth), Position = UDim2.fromOffset(0, depth), BorderSizePixel = 0, ZIndex = holder.ZIndex }, holder)
	corner(shadow, o.Radius or 18)
	local face = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = P.white, Size = UDim2.new(1, 0, 1, -depth), BorderSizePixel = 0, ZIndex = holder.ZIndex + 1 }, holder)
	corner(face, o.Radius or 18)
	stroke(face, P.ink, 3)
	local grad = gradient(face, o.Color)
	local content = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = face.ZIndex }, face)
	list(content, Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local h = holder.Size.Y.Offset
	local icon
	if o.Icon then
		icon = text(content, { Text = o.Icon, Font = BODY, TextSize = o.IconSize or math.floor(h * 0.34), Size = UDim2.new(1, 0, 0, math.floor(h * 0.4)), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = face.ZIndex, LayoutOrder = 1 })
	end
	local label = text(content, { Text = o.Text or "", TextSize = o.TextSize or math.floor(h * (o.Icon and 0.2 or 0.36)), RichText = true,
		Size = UDim2.new(1, -8, 0, math.floor(h * (o.Icon and 0.26 or 0.5))), TextXAlignment = Enum.TextXAlignment.Center, Outline = 2.5, ZIndex = face.ZIndex, LayoutOrder = 2 })
	local sub
	if o.Sub then
		sub = text(content, { Text = o.Sub, Font = BODY, TextSize = o.SubSize or math.floor(h * 0.15), TextColor3 = P.ink, Size = UDim2.new(1, -8, 0, math.floor(h * 0.2)), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = face.ZIndex, LayoutOrder = 3, RichText = true })
	end
	local api = { holder = holder, face = face, label = label, sub = sub, icon = icon, enabled = true }
	function api.SetColor(c)
		grad.Color = ColorSequence.new(lift(c, 0.35), c)
		shadow.BackgroundColor3 = lift(c, -0.55)
	end
	function api.SetText(t, s)
		label.Text = t
		if sub and s then
			sub.Text = s
		end
	end
	face.MouseButton1Down:Connect(function()
		face.Position = UDim2.fromOffset(0, depth - 2)
	end)
	local function up()
		face.Position = UDim2.new()
	end
	face.MouseButton1Up:Connect(up)
	face.MouseLeave:Connect(up)
	face.Activated:Connect(function()
		up()
		if o.OnClick and api.enabled then
			UI.Sfx("click")
			o.OnClick()
		end
	end)
	return api
end

local function pill(parent, txt, color, props)
	local f = new("Frame", { BackgroundColor3 = color, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, props and props.H or 30), BorderSizePixel = 0, LayoutOrder = props and props.LayoutOrder or 0 }, parent)
	corner(f, 30)
	stroke(f, P.ink, 2.5)
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, f)
	local l = text(f, { Text = txt, TextSize = props and props.TextSize or 18, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), TextXAlignment = Enum.TextXAlignment.Center })
	return f, l
end

local function rarityColor(r)
	return CarConfig.Rarities[r].color
end

local function fitCamera(vp, model, angle)
	local cam = vp.CurrentCamera or new("Camera", { FieldOfView = 38 }, vp)
	vp.CurrentCamera = cam
	local size = model:GetExtentsSize()
	local d = math.max(size.X, size.Z, size.Y * 1.6) * 1.3
	local a = angle or math.rad(35)
	local center = Vector3.new(0, size.Y * 0.45, 0)
	cam.CFrame = CFrame.lookAt(center + Vector3.new(math.cos(a) * d, d * 0.38, math.sin(a) * d), center)
end

local function carViewport(parent, def, props)
	local vp = new("ViewportFrame", { BackgroundTransparency = 1, Ambient = C(200, 200, 210), LightColor = C(255, 250, 240), LightDirection = Vector3.new(-1, -2, -1) }, parent)
	for k, v in pairs(props or {}) do
		vp[k] = v
	end
	local m = VehicleFactory.BuildCar(def, { Low = true })
	m:PivotTo(CFrame.new())
	m.Parent = vp
	fitCamera(vp, m)
	return vp, m
end

---------------------------------------------------------------- sound / toasts
function UI.Sfx(name)
	local s = sounds[name]
	if s then
		s:Play()
	end
end
local function makeSound(name, id, vol, speed)
	sounds[name] = new("Sound", { Name = "UI_" .. name, SoundId = id, Volume = vol or 0.5, PlaybackSpeed = speed or 1 }, SoundService)
end

local KIND_COLOR = { good = P.green, error = P.red, warn = P.orange, info = P.blue }
function UI.Toast(msg, kind)
	local f = new("Frame", { BackgroundColor3 = KIND_COLOR[kind] or P.blue, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 44), BorderSizePixel = 0, ZIndex = 50 }, hud.toasts)
	corner(f, 22)
	stroke(f, P.ink, 3)
	new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }, f)
	local l = text(f, { Text = msg, TextSize = 22, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), ZIndex = 51 })
	local sc = new("UIScale", { Scale = 0.4 }, f)
	tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(2.6, function()
		tween(f, 0.3, { BackgroundTransparency = 1 })
		tween(l, 0.3, { TextTransparency = 1 })
		task.wait(0.32)
		f:Destroy()
	end)
	UI.Sfx(kind == "error" and "err" or "ping")
end

function UI.Notify(payload)
	if type(payload) ~= "table" then
		return
	end
	UI.Toast(T("n_" .. tostring(payload.key), table.unpack(payload.args or {})), payload.kind)
end

---------------------------------------------------------------- HUD
local function buildHud()
	-- money pill
	local money = new("Frame", { Position = UDim2.fromOffset(18, 16), Size = UDim2.fromOffset(250, 66), BackgroundColor3 = P.ink, BorderSizePixel = 0 }, root)
	corner(money, 40)
	stroke(money, P.white, 3)
	local coin = new("Frame", { Position = UDim2.fromOffset(10, 11), Size = UDim2.fromOffset(44, 44), BackgroundColor3 = P.white, BorderSizePixel = 0 }, money)
	corner(coin, 22)
	stroke(coin, P.ink, 3)
	new("UIGradient", { Color = ColorSequence.new(C(255, 230, 128), P.orange), Rotation = 90 }, coin)
	text(coin, { Text = "$", TextSize = 26, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	hud.money = text(money, { Position = UDim2.fromOffset(64, 6), Size = UDim2.fromOffset(180, 34), TextSize = 32, TextColor3 = P.yellow })
	hud.income = text(money, { Position = UDim2.fromOffset(64, 38), Size = UDim2.fromOffset(180, 22), TextSize = 17, Font = BODY, TextColor3 = P.green })
	hud.moneyScale = new("UIScale", {}, money)

	-- banked parts row
	local row = new("Frame", { Position = UDim2.fromOffset(18, 92), Size = UDim2.fromOffset(420, 34), BackgroundTransparency = 1 }, root)
	list(row, Enum.FillDirection.Horizontal, 6)
	hud.parts = {}
	for i, id in ipairs(PartConfig.Order) do
		local chip = new("Frame", { Size = UDim2.fromOffset(70, 34), BackgroundColor3 = P.white, BorderSizePixel = 0, LayoutOrder = i }, row)
		corner(chip, 14)
		stroke(chip, rarityColor(PartConfig.Parts[id].rarity), 3.5)
		text(chip, { Text = PART_ICON[id], Font = BODY, TextSize = 18, Position = UDim2.fromOffset(6, 0), Size = UDim2.fromOffset(26, 34) })
		hud.parts[id] = { chip = chip, n = text(chip, { Text = "0", TextSize = 20, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(34, 2), Size = UDim2.fromOffset(34, 32) }) }
	end

	-- risky loot badge
	local bag = new("Frame", { Position = UDim2.fromOffset(18, 134), Size = UDim2.fromOffset(240, 34), BackgroundColor3 = P.red, BorderSizePixel = 0, Visible = false }, root)
	corner(bag, 12)
	stroke(bag, P.ink, 3)
	hud.bag = bag
	hud.bagText = text(bag, { Text = "", TextSize = 19, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -12, 1, 0) })

	-- zone banner + hint
	local banner = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(290, 46), BackgroundColor3 = P.white, BorderSizePixel = 0 }, root)
	corner(banner, 14)
	stroke(banner, P.ink, 3.5)
	hud.bannerGrad = gradient(banner, P.orange)
	hud.zone = text(banner, { Text = "", TextSize = 28, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Outline = 3 })
	local hint = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 40), BackgroundColor3 = P.white, BorderSizePixel = 0, Visible = false }, root)
	corner(hint, 20)
	stroke(hint, P.ink, 3)
	new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }, hint)
	hud.hintFrame = hint
	hud.hint = text(hint, { Text = "", Font = BODY, TextSize = 20, TextColor3 = P.ink, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1) })

	-- side buttons (minimum: 3)
	local side = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 120), Size = UDim2.fromOffset(122, 3 * 104 + 24), BackgroundTransparency = 1 }, root)
	list(side, Enum.FillDirection.Vertical, 12)
	toy(side, { Text = T("btn_teleport"), Icon = "🚀", Color = P.blue, Size = UDim2.fromOffset(122, 104), LayoutOrder = 1, OnClick = function() UI.TogglePanel("teleport") end })
	toy(side, { Text = T("btn_garage"), Icon = "🏁", Color = P.orange, Size = UDim2.fromOffset(122, 104), LayoutOrder = 2, OnClick = function() UI.TogglePanel("garage") end })
	toy(side, { Text = T("btn_index"), Icon = "🚗", Color = P.green, Size = UDim2.fromOffset(122, 104), LayoutOrder = 3, OnClick = function() UI.TogglePanel("index") end })
	hud.newDot = new("Frame", { Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -16, 0, -6), BackgroundColor3 = P.red, Visible = false, ZIndex = 5 }, side)
	corner(hud.newDot, 11)
	stroke(hud.newDot, P.white, 3)

	-- THROW (only near own trap)
	hud.throw = toy(root, { Name = "Throw", Text = T("btn_throw"), Sub = "", Color = P.yellow, Size = UDim2.fromOffset(300, 104),
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), OnClick = function() UI.TogglePanel("throw") end })
	hud.throw.holder.Visible = false

	hud.toasts = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 170), Size = UDim2.fromOffset(600, 200), BackgroundTransparency = 1, ZIndex = 50 }, root)
	list(hud.toasts, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center)
	hud.flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = P.red, BackgroundTransparency = 1, ZIndex = 40, Active = false }, gui)
end

---------------------------------------------------------------- panels
local function panelShell(name, title, w, h, color)
	local dim = new("TextButton", { Name = name, Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(0, 0, 0), BackgroundTransparency = 0.5, Visible = false, ZIndex = 20 }, root)
	dim.Activated:Connect(function() UI.TogglePanel(nil) end)
	local card = new("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(w, h), BackgroundColor3 = P.cream, ZIndex = 21 }, dim)
	corner(card, 28)
	stroke(card, P.ink, 5)
	local head = new("Frame", { Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = P.white, ZIndex = 22 }, card)
	corner(head, 28)
	stroke(head, P.ink, 5)
	gradient(head, color)
	text(head, { Text = title, TextSize = 38, Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -110, 1, 0), ZIndex = 23, Outline = 3 })
	toy(card, { Text = "X", Color = P.red, Size = UDim2.fromOffset(60, 64), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 14, 0, -18), ZIndex = 24, OnClick = function() UI.TogglePanel(nil) end })
	local content = new("Frame", { Position = UDim2.fromOffset(22, 86), Size = UDim2.new(1, -44, 1, -104), BackgroundTransparency = 1, ZIndex = 22 }, card)
	local sc = new("UIScale", {}, card)
	panels[name] = { root = dim, card = card, content = content, scale = sc }
	return panels[name]
end

local function scroller(parent, pos, size)
	local s = new("ScrollingFrame", { Position = pos, Size = size, BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8, ScrollBarImageColor3 = P.ink,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 22 }, parent)
	list(s, Enum.FillDirection.Vertical, 10)
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 12) }, s)
	return s
end

-- THROW / bait picker
local function buildThrow()
	local p = panelShell("throw", T("throw_title"), 900, 470, P.yellow)
	local c = p.content
	local cards = new("Frame", { Size = UDim2.new(1, 0, 0, 190), BackgroundTransparency = 1, ZIndex = 22 }, c)
	list(cards, Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Center)
	panels.baitCards = {}
	for i, id in ipairs(PartConfig.Order) do
		local def = PartConfig.Parts[id]
		local b = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(150, 180), BackgroundColor3 = P.white, LayoutOrder = i, ZIndex = 23 }, cards)
		corner(b, 22)
		local st = stroke(b, rarityColor(def.rarity), 6)
		text(b, { Text = PART_ICON[id], Font = BODY, TextSize = 54, Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 70), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 24 })
		text(b, { Text = T("part_" .. id), TextSize = 22, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(0, 90), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 24 })
		local n = text(b, { Text = "x0", TextSize = 28, TextColor3 = rarityColor(def.rarity), Position = UDim2.fromOffset(0, 124), Size = UDim2.new(1, 0, 0, 34), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 24 })
		b.Activated:Connect(function()
			state.selectedPart = id
			UI.Sfx("click")
			UI.Refresh()
		end)
		panels.baitCards[id] = { btn = b, stroke = st, n = n }
	end
	local bar = new("Frame", { Position = UDim2.fromOffset(0, 204), Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = P.white, ZIndex = 22, ClipsDescendants = true }, c)
	corner(bar, 15)
	stroke(bar, P.ink, 3)
	list(bar, Enum.FillDirection.Horizontal, 0)
	panels.oddsBar = bar
	panels.oddsText = text(c, { Text = "", Font = BODY, TextSize = 17, TextColor3 = P.ink, Position = UDim2.fromOffset(0, 240), Size = UDim2.new(1, 0, 0, 24), RichText = true, ZIndex = 22 })
	panels.throwGo = toy(c, { Text = T("btn_throw"), Color = P.green, Size = UDim2.fromOffset(300, 84), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 4), ZIndex = 23,
		OnClick = function()
			if state.selectedPart and store.Banked(state.selectedPart) > 0 then
				actions.Throw(state.selectedPart)
				UI.TogglePanel(nil)
			else
				UI.Toast(T("n_noPart"), "error")
			end
		end })
end

local function refreshThrow()
	local st = store.State
	if not st then
		return
	end
	if not state.selectedPart or store.Banked(state.selectedPart) <= 0 then
		state.selectedPart = nil
		for i = #PartConfig.Order, 1, -1 do
			if store.Banked(PartConfig.Order[i]) > 0 then
				state.selectedPart = PartConfig.Order[i]
				break
			end
		end
	end
	local sel = state.selectedPart
	local n = sel and store.Banked(sel) or 0
	hud.throw.SetText(T("btn_throw"), sel and string.format("%s %s x%d", PART_ICON[sel], T("part_" .. sel), n) or T("throw_none"))
	hud.throw.SetColor(sel and P.yellow or P.grey)
	if not panels.baitCards then
		return
	end
	for id, cd in pairs(panels.baitCards) do
		local cnt = store.Banked(id)
		cd.n.Text = "x" .. cnt
		cd.btn.BackgroundTransparency = cnt > 0 and 0 or 0.45
		cd.stroke.Color = (id == sel) and P.ink or rarityColor(PartConfig.Parts[id].rarity)
		cd.stroke.Thickness = (id == sel) and 8 or 5
	end
	clear(panels.oddsBar)
	local row = CarConfig.DropChances[sel or "bolts"]
	local pity = st.pity or 0
	local pityNow = pity >= EconomyConfig.PityThreshold - 1
	if pityNow then
		row = CarConfig.PityRow(sel or "bolts")
	end
	local parts = {}
	for i, r in ipairs(CarConfig.RarityOrder) do
		local v = row[r]
		if v > 0 then
			new("Frame", { Size = UDim2.new(v / 100, 0, 1, 0), BackgroundColor3 = rarityColor(r), BorderSizePixel = 0, LayoutOrder = i, ZIndex = 23 }, panels.oddsBar)
		end
		local hexc = rarityColor(r):ToHex()
		table.insert(parts, string.format('<font color="#%s">%s %s%%</font>', hexc, T("rarity_" .. r), (v % 1 == 0) and tostring(v) or string.format("%.1f", v)))
	end
	local pityTxt = pityNow and T("throw_pity_now") or T("throw_pity", EconomyConfig.PityThreshold - pity)
	panels.oddsText.Text = table.concat(parts, "  ") .. "   |   " .. pityTxt
	panels.throwGo.SetColor((sel and n > 0) and P.green or P.grey)
end

-- TELEPORT (also unlocks districts)
local function buildTeleport()
	local p = panelShell("teleport", T("tp_title"), 820, 560, P.blue)
	panels.tpGrid = new("Frame", { Size = UDim2.new(1, 0, 1, -40), BackgroundTransparency = 1, ZIndex = 22 }, p.content)
	new("UIGridLayout", { CellSize = UDim2.fromOffset(240, 196), CellPadding = UDim2.fromOffset(16, 18), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, panels.tpGrid)
	text(p.content, { Text = "⚠ " .. T("tp_walk"), Font = BODY, TextSize = 19, TextColor3 = P.red, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), ZIndex = 22 })
end

local function refreshTeleport()
	local st = store.State
	if not st or state.open ~= "teleport" then
		return
	end
	clear(panels.tpGrid)
	local function tile(order, title, icon, color, sub, onClick)
		local f = new("Frame", { BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 22 }, panels.tpGrid)
		local t = toy(f, { Text = title, Icon = icon, Sub = sub, Color = color, Size = UDim2.fromOffset(240, 190), ZIndex = 23, SubSize = 17, OnClick = onClick })
		return t
	end
	tile(0, T("tp_home"), "🏠", P.orange, T("tp_home_desc"), function()
		actions.Teleport("home")
		UI.TogglePanel(nil)
	end)
	for i, zid in ipairs(MapConfig.ZoneOrder) do
		local zone = MapConfig.Zones[zid]
		local open = st.zones[zid] == true
		local prevOpen = i == 1 or st.zones[MapConfig.ZoneOrder[i - 1]] == true
		local req = EconomyConfig.ZoneUnlock[zid]
		local title = string.gsub(zone.name, " DISTRICT", "")
		if open then
			tile(i, title, ZONE_ICON[zid], ZONE_COLOR[zid], T("zone_desc_" .. zid), function()
				actions.Teleport(zid)
				UI.TogglePanel(nil)
			end)
		else
			local can = prevOpen and req and store.Money >= req.cost and store.CollectionValue >= req.minValue
			local sub = not prevOpen and T("zones_need_prev")
				or string.format("🔒 $%s  ·  %s $%s", Util.FormatNumber(req.cost), T("zones_value"), Util.FormatNumber(req.minValue))
			local t = tile(i, can and (T("btn_unlock") .. "!") or title, "🔒", can and P.green or P.grey, sub, function()
				if can then
					actions.Unlock(zid)
				elseif prevOpen and store.CollectionValue < req.minValue then
					UI.Toast(T("n_needValue"), "warn")
				elseif prevOpen then
					UI.Toast(T("n_noMoney"), "error")
				else
					UI.Toast(T("n_needPrev"), "warn")
				end
			end)
			if not can then
				t.holder.Size = UDim2.fromOffset(240, 190)
			end
		end
	end
end

-- GARAGE
local function buildGarage()
	local p = panelShell("garage", T("garage_title"), 900, 580, P.orange)
	local c = p.content
	panels.garageInfo = text(c, { Text = "", Font = BODY, TextSize = 20, TextColor3 = P.ink, Size = UDim2.new(1, -380, 0, 50), ZIndex = 22, RichText = true })
	panels.autoBtn = toy(c, { Text = T("btn_autopark"), Color = P.green, Size = UDim2.fromOffset(170, 54), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -190, 0, -2), ZIndex = 23, OnClick = function() actions.AutoPark() end })
	panels.slotBtn = toy(c, { Text = T("btn_buyslot"), Sub = "", Color = P.blue, Size = UDim2.fromOffset(176, 54), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, -2), ZIndex = 23, SubSize = 14,
		OnClick = function()
			local st = store.State
			if st.slots + 1 > (st.floors or 1) * 6 then
				actions.BuyFloor(st.floors or 1)
			else
				actions.BuySlot(st.slots)
			end
		end })
	panels.carList = scroller(c, UDim2.fromOffset(0, 62), UDim2.new(1, 0, 1, -62))
end

local function sortedCars(st)
	local out = table.clone(st.cars)
	table.sort(out, function(a, b)
		local ia = CarConfig.CarIncome(a)
		local ib = CarConfig.CarIncome(b)
		if ia ~= ib then
			return ia > ib
		end
		return a.uid < b.uid
	end)
	return out
end

local function freeSlot(st)
	local used, worst, worstInc = {}, nil, nil
	for _, c in ipairs(st.cars) do
		if c.slot then
			used[c.slot] = true
			local inc = CarConfig.CarIncome(c)
			if not worstInc or inc < worstInc then
				worst, worstInc = c.slot, inc
			end
		end
	end
	for i = 1, st.slots do
		if not used[i] then
			return i
		end
	end
	return worst or 1
end

local function refreshGarage()
	local st = store.State
	if not st or state.open ~= "garage" then
		return
	end
	local parked = 0
	for _, c in ipairs(st.cars) do
		if c.slot then
			parked = parked + 1
		end
	end
	panels.garageInfo.Text = string.format('<font color="#1E9E40">+%s/s</font>   🅿 %d/%d   🚗 %d', Util.FormatNumber(store.Income), parked, st.slots, #st.cars)
	local cost = EconomyConfig.SlotCosts[st.slots + 1]
	local floors = st.floors or 1
	if cost and st.slots + 1 > floors * 6 then
		local fc = EconomyConfig.FloorCosts[floors + 1]
		panels.slotBtn.SetText("+ LEVEL " .. (floors + 1), "$" .. Util.FormatNumber(fc))
		panels.slotBtn.SetColor(store.Money >= fc and P.orange or P.grey)
	elseif cost then
		panels.slotBtn.SetText(T("btn_buyslot"), "$" .. Util.FormatNumber(cost))
		panels.slotBtn.SetColor(store.Money >= cost and P.blue or P.grey)
	else
		panels.slotBtn.SetText(T("btn_max"), "")
		panels.slotBtn.SetColor(P.grey)
	end
	clear(panels.carList)
	local cars = sortedCars(st)
	if #cars == 0 then
		text(panels.carList, { Text = T("garage_empty"), Font = BODY, TextSize = 20, TextColor3 = P.muted, TextWrapped = true, Size = UDim2.new(1, 0, 0, 60), ZIndex = 23 })
		return
	end
	local now = os.clock()
	for i, c in ipairs(cars) do
		local def = CarConfig.ById[c.typeId]
		local rc = rarityColor(def.rarity)
		local row = new("Frame", { Size = UDim2.new(1, 0, 0, 84), BackgroundColor3 = P.white, LayoutOrder = i, ZIndex = 23 }, panels.carList)
		corner(row, 18)
		stroke(row, rc, 4)
		local band = new("Frame", { Size = UDim2.new(0, 10, 1, -16), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = rc, BorderSizePixel = 0, ZIndex = 24 }, row)
		corner(band, 5)
		text(row, { Text = def.name, TextSize = 24, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(28, 8), Size = UDim2.fromOffset(300, 30), ZIndex = 24 })
		local where = c.slot and T("car_parked", c.slot) or T("car_stored")
		text(row, { Text = string.format('<font color="#%s">%s</font>  ·  %s  ·  <font color="#1E9E40">%s</font>  ·  %s', rc:ToHex(), string.upper(T("rarity_" .. def.rarity)),
			T("car_level", c.level), T("car_income", Util.FormatNumber(CarConfig.CarIncome(c))), where),
			Font = BODY, TextSize = 14, TextColor3 = P.muted, RichText = true, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(28, 44), Size = UDim2.fromOffset(350, 26), ZIndex = 24 })
		local btns = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(450, 60), BackgroundTransparency = 1, ZIndex = 24 }, row)
		list(btns, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
		if c.slot then
			toy(btns, { Text = T("btn_remove"), Color = P.orange, Size = UDim2.fromOffset(96, 54), TextSize = 16, LayoutOrder = 1, ZIndex = 25, OnClick = function() actions.Remove(c.uid) end })
		else
			toy(btns, { Text = T("btn_place"), Color = P.green, Size = UDim2.fromOffset(96, 54), TextSize = 18, LayoutOrder = 1, ZIndex = 25, OnClick = function() actions.Place(c.uid, freeSlot(st)) end })
		end
		if c.level >= def.maxLevel then
			toy(btns, { Text = T("btn_max"), Color = P.grey, Size = UDim2.fromOffset(150, 54), LayoutOrder = 2, ZIndex = 25 })
		else
			local cost = CarConfig.UpgradeCost(def, c.level)
			local partId, amount = CarConfig.UpgradeParts(def, c.level)
			local ok = store.Money >= cost and (st.parts[partId] or 0) >= amount
			toy(btns, { Text = T("btn_upgrade"), Sub = string.format("$%s + %s%d", Util.FormatNumber(cost), PART_ICON[partId], amount), SubSize = 14, TextSize = 18,
				Color = ok and P.blue or P.grey, Size = UDim2.fromOffset(150, 54), LayoutOrder = 2, ZIndex = 25, OnClick = function() actions.Upgrade(c.uid, c.level) end })
		end
		local tuned = 0
		for _ in pairs(c.tune or {}) do
			tuned = tuned + 1
		end
		toy(btns, { Text = T("btn_tune"), Sub = tuned > 0 and (tuned .. "/7") or nil, SubSize = 13, TextSize = 17, Color = P.yellow, Size = UDim2.fromOffset(84, 54),
			LayoutOrder = 3, ZIndex = 25, OnClick = function()
				if UI.OnTune then
					UI.OnTune(c.uid)
				end
			end })
		local armed = state.sellArm[c.uid] and now - state.sellArm[c.uid] < 3
		toy(btns, { Text = armed and T("btn_sure") or T("btn_sell"), Sub = "$" .. Util.FormatNumber(CarConfig.SellPrice(def, c.level)), SubSize = 13, TextSize = 16,
			Color = P.red, Size = UDim2.fromOffset(86, 54), LayoutOrder = 4, ZIndex = 25, OnClick = function()
				if armed then
					state.sellArm[c.uid] = nil
					actions.Sell(c.uid)
				else
					state.sellArm[c.uid] = os.clock()
					refreshGarage()
					task.delay(3.1, refreshGarage)
				end
			end })
	end
end

-- CARS index
local function buildIndex()
	local p = panelShell("index", T("index_title"), 900, 580, P.green)
	panels.indexInfo = text(p.content, { Text = "", Font = BODY, TextSize = 19, TextColor3 = P.ink, Size = UDim2.new(1, 0, 0, 26), ZIndex = 22 })
	local s = new("ScrollingFrame", { Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 1, -34), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 22 }, p.content)
	new("UIGridLayout", { CellSize = UDim2.fromOffset(196, 150), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }, s)
	panels.indexGrid = s
	panels.indexCards = {}
end

local function refreshIndex()
	local st = store.State
	if not st or state.open ~= "index" then
		return
	end
	local found, total, _, mult = CarConfig.IndexStats(st.discovered or {})
	panels.indexInfo.Text = T("index_found", found, total) .. "   ·   " .. T("index_bonus", string.format("%.2f", mult)) .. "   ·   " .. T("index_hint")
	for i, def in ipairs(CarConfig.List) do
		local known = st.discovered and st.discovered[def.id]
		local cd = panels.indexCards[def.id]
		if not cd or cd.known ~= known then
			if cd then
				cd.frame:Destroy()
			end
			local rc = rarityColor(def.rarity)
			local f = new("Frame", { BackgroundColor3 = known and P.white or C(60, 64, 76), LayoutOrder = i, ZIndex = 23 }, panels.indexGrid)
			corner(f, 18)
			stroke(f, rc, 4)
			if known then
				carViewport(f, def, { Size = UDim2.new(1, 0, 1, -44), ZIndex = 24 })
			else
				text(f, { Text = "?", TextSize = 70, Size = UDim2.new(1, 0, 1, -44), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = rc, ZIndex = 24 })
			end
			text(f, { Text = known and def.name or T("index_unknown"), TextSize = 17, TextColor3 = known and P.ink or P.white, Outline = false, AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, -20), Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 24 })
			text(f, { Text = string.upper(T("rarity_" .. def.rarity)), Font = BODY, TextSize = 14, TextColor3 = rc, AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 24 })
			panels.indexCards[def.id] = { frame = f, known = known }
		end
	end
end

function UI.TogglePanel(name)
	if name ~= nil and state.open == name then
		name = nil
	end
	for n, p in pairs(panels) do
		if type(p) == "table" and p.root and p.scale then
			if n == name then
				p.root.Visible = true
				p.scale.Scale = 0.6
				tween(p.scale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
			else
				p.root.Visible = false
			end
		end
	end
	state.open = name
	if name then
		UI.Sfx("open")
	end
	UI.Refresh()
end

---------------------------------------------------------------- reveal
local function buildReveal()
	local r = new("TextButton", { Name = "Reveal", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(0, 0, 0), BackgroundTransparency = 0.25, Visible = false, ZIndex = 60 }, gui)
	local rays = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, ZIndex = 60 }, r)
	for k = 0, 11 do
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(1600, 46), Rotation = k * 15, BackgroundColor3 = P.yellow, BackgroundTransparency = 0.82, BorderSizePixel = 0, ZIndex = 60 }, rays)
	end
	local box = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(640, 600), BackgroundTransparency = 1, ZIndex = 61 }, r)
	local sc = new("UIScale", {}, box)
	local top = text(box, { Text = T("reveal_new"), TextSize = 34, Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 62 })
	local badge = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46), Size = UDim2.fromOffset(330, 54), BackgroundColor3 = P.white, ZIndex = 62 }, box)
	corner(badge, 27)
	stroke(badge, P.ink, 4)
	local badgeGrad = gradient(badge, P.yellow)
	local rarity = text(badge, { Text = "", TextSize = 36, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 63, Outline = 3 })
	local vpHolder = new("Frame", { Position = UDim2.fromOffset(60, 110), Size = UDim2.fromOffset(520, 270), BackgroundTransparency = 1, ZIndex = 62 }, box)
	local name = text(box, { Text = "", TextSize = 64, Position = UDim2.fromOffset(0, 380), Size = UDim2.new(1, 0, 0, 70), TextXAlignment = Enum.TextXAlignment.Center, Outline = 4, ZIndex = 62 })
	local info = text(box, { Text = "", Font = BODY, TextSize = 24, Position = UDim2.fromOffset(0, 452), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center, RichText = true, ZIndex = 62 })
	local ok = toy(box, { Text = T("btn_awesome"), Color = P.green, Size = UDim2.fromOffset(300, 86), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), ZIndex = 63,
		OnClick = function() UI.HideReveal() end })
	panels.reveal = { root = r, rays = rays, box = box, sc = sc, top = top, badgeGrad = badgeGrad, rarity = rarity, vpHolder = vpHolder, name = name, info = info, ok = ok }
	r.Activated:Connect(function() UI.HideReveal() end)
end

function UI.HideReveal()
	local rv = panels.reveal
	if rv.root.Visible then
		rv.root.Visible = false
		if rv.conn then
			rv.conn:Disconnect()
			rv.conn = nil
		end
	end
end

function UI.ShowReveal(res)
	local rv = panels.reveal
	local def = CarConfig.ById[res.typeId]
	if not def then
		return
	end
	local rc = rarityColor(res.rarity)
	rv.top.Text = res.isNew and T("reveal_new") or T("reveal_got")
	rv.badgeGrad.Color = ColorSequence.new(lift(rc, 0.35), rc)
	rv.rarity.Text = "★ " .. string.upper(T("rarity_" .. res.rarity)) .. " ★"
	rv.name.Text = string.upper(def.name)
	rv.name.TextColor3 = rc
	local lines = { string.format('<font color="#34D058">+%s/s</font>', Util.FormatNumber(CarConfig.IncomeAt(def, 1))) }
	table.insert(lines, res.slot and T("reveal_placed", res.slot) or T("reveal_stored"))
	if res.isNew and res.bonus and res.bonus > 0 then
		table.insert(lines, T("reveal_first", Util.FormatNumber(res.bonus)))
	end
	if res.pityUsed then
		table.insert(lines, T("reveal_pity"))
	end
	rv.info.Text = table.concat(lines, "  ·  ")
	for _, ray in ipairs(rv.rays:GetChildren()) do
		ray.BackgroundColor3 = rc
	end
	clear(rv.vpHolder)
	local vp, model = carViewport(rv.vpHolder, def, { Size = UDim2.fromScale(1, 1), ZIndex = 62 })
	rv.root.Visible = true
	rv.sc.Scale = 0.2
	tween(rv.sc, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	UI.Sfx("fanfare")
	local t0 = os.clock()
	if rv.conn then
		rv.conn:Disconnect()
	end
	rv.conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		rv.rays.Rotation = t * 25
		if model.Parent then
			fitCamera(vp, model, math.rad(35) + t * 0.8)
		end
	end)
end

---------------------------------------------------------------- refresh
local function refreshHud()
	local st = store.State
	hud.money.Text = "$" .. Util.FormatNumber(store.Money)
	hud.income.Text = "+" .. Util.FormatNumber(store.Income) .. " / sec"
	for id, p in pairs(hud.parts) do
		local n = store.Banked(id)
		p.n.Text = tostring(n)
		p.chip.BackgroundTransparency = n > 0 and 0 or 0.4
	end
	local carried = store.CarriedTotal()
	hud.bag.Visible = carried > 0
	if carried > 0 then
		local icons = {}
		for _, id in ipairs(PartConfig.Order) do
			local n = store.Carried(id)
			if n > 0 then
				table.insert(icons, PART_ICON[id] .. n)
			end
		end
		hud.bagText.Text = "🎒 " .. T("hud_risky", carried, st.carryCap or EconomyConfig.CarryCapacity) .. "  " .. table.concat(icons, " ")
		hud.bag.Size = UDim2.fromOffset(math.max(240, hud.bagText.TextBounds.X + 24), 34)
	end
	hud.throw.holder.Visible = state.nearTrap and state.open == nil
	-- "can unlock" dot on TELEPORT
	local dot = false
	for i, zid in ipairs(MapConfig.ZoneOrder) do
		local req = EconomyConfig.ZoneUnlock[zid]
		if req and not st.zones[zid] and st.zones[MapConfig.ZoneOrder[i - 1]] and store.Money >= req.cost and store.CollectionValue >= req.minValue then
			dot = true
		end
	end
	hud.newDot.Visible = dot
	hud.canUnlock = dot
end

local function refreshHint()
	local st = store.State
	local msg
	local throws = st.stats and st.stats.throws or 0
	if store.CarriedTotal() > 0 then
		msg = T("tut_return")
	elseif throws == 0 then
		msg = store.BankedTotal() == 0 and T("tut_find") or T("tut_throw")
	elseif (st.stats.upgrades or 0) == 0 and #st.cars > 0 then
		msg = T("tut_upgrade")
	elseif hud.canUnlock then
		msg = T("tut_zone")
	end
	hud.hintFrame.Visible = msg ~= nil and state.open == nil
	if msg then
		hud.hint.Text = "👉  " .. msg
	end
end

UI.Hooks = {}

function UI.Refresh()
	if not store.State then
		return
	end
	for _, fn in ipairs(UI.Hooks) do
		fn(store.State, state.open)
	end
	refreshHud()
	refreshThrow()
	refreshHint()
	refreshGarage()
	refreshIndex()
	refreshTeleport()
end

function UI.SetZoneName(zoneId)
	if hud.lastZone == zoneId then
		return
	end
	hud.lastZone = zoneId
	hud.zone.Text = string.upper(T("zone_" .. zoneId))
	local c = ZONE_COLOR[zoneId] or P.orange
	hud.bannerGrad.Color = ColorSequence.new(lift(c, 0.35), c)
end

function UI.SetNearTrap(v)
	if state.nearTrap ~= v then
		state.nearTrap = v
		if not v and state.open == "throw" then
			UI.TogglePanel(nil)
		end
		refreshHud()
	end
end

function UI.FlashFrame()
	return hud.flash
end

function UI.Gui()
	return gui
end

function UI.Init(storeModule, actionTable)
	store, actions = storeModule, actionTable
	local player = Players.LocalPlayer
	gui = new("ScreenGui", { Name = "MainUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 10 })
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafe
	end)
	root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
	local uiScale = new("UIScale", {}, root)
	local function rescale()
		local vp = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		local s = math.clamp(math.min(vp.Y / 760, vp.X / 1240), 0.5, 1.2)
		uiScale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	rescale()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
	-- ElevenLabs SFX when uploaded (SoundIds), otherwise Roblox built-in sounds
	local SoundIds = require(Shared:WaitForChild("SoundIds"))
	local FALLBACK = {
		click = { "rbxasset://sounds/button.wav", 0.35 }, open = { "rbxasset://sounds/swoosh.wav", 0.25, 1.3 },
		err = { "rbxasset://sounds/uuhhh.mp3", 0.3, 1.2 }, ping = { "rbxasset://sounds/electronicpingshort.wav", 0.45, 1.2 },
		throw = { "rbxasset://sounds/swoosh.wav", 0.6, 1.4 }, clank = { "rbxasset://sounds/clickfast.wav", 0.6, 0.6 },
		charge = { "rbxasset://sounds/electronicpingshort.wav", 0.3, 0.5 }, reveal = { "rbxasset://sounds/Rocket shot.wav", 0.6, 0.8 },
		revealBig = { "rbxasset://sounds/Rocket shot.wav", 0.8, 0.6 }, land = { "rbxasset://sounds/collide.wav", 0.8, 0.6 },
		drive = { "rbxasset://sounds/swoosh.wav", 0.4, 0.6 }, pickup = { "rbxasset://sounds/electronicpingshort.wav", 0.5, 1.5 },
		pickupBig = { "rbxasset://sounds/electronicpingshort.wav", 0.6, 1.1 }, bank = { "rbxasset://sounds/victory.wav", 0.35, 1.3 },
		bankCombo = { "rbxasset://sounds/victory.wav", 0.5 }, combo = { "rbxasset://sounds/electronicpingshort.wav", 0.5, 1.8 },
		cash = { "rbxasset://sounds/victory.wav", 0.5, 1.2 }, siren = { "rbxasset://sounds/electronicpingshort.wav", 0.2, 0.9 },
		crash = { "rbxasset://sounds/collide.wav", 0.9, 0.8 }, wrecked = { "rbxasset://sounds/uuhhh.mp3", 0.5 },
		airbag = { "rbxasset://sounds/Rocket shot.wav", 0.5, 1.6 }, whoosh = { "rbxasset://sounds/swoosh.wav", 0.6, 0.8 },
		fanfare = { "rbxasset://sounds/victory.wav", 0.5 }, hit = { "rbxasset://sounds/collide.wav", 0.9, 0.8 },
		boom = { "rbxasset://sounds/Rocket shot.wav", 0.7, 0.7 },
	}
	for name, fb in pairs(FALLBACK) do
		local id = SoundIds[name]
		if id and id > 0 then
			makeSound(name, "rbxassetid://" .. id, fb[2] + 0.15, 1)
		else
			makeSound(name, fb[1], fb[2], fb[3])
		end
	end
	if SoundIds.ambience and SoundIds.ambience > 0 then
		local amb = new("Sound", { Name = "Ambience", SoundId = "rbxassetid://" .. SoundIds.ambience, Volume = 0.25, Looped = true }, SoundService)
		amb:Play()
	end
	buildHud()
	buildThrow()
	buildTeleport()
	buildGarage()
	buildIndex()
	buildReveal()
	gui.Parent = player:WaitForChild("PlayerGui")
	UI.SetZoneName("plaza")

	local lastMoney = 0
	store.Changed.Event:Connect(UI.Refresh)
	store.MoneyChanged.Event:Connect(function()
		if store.Money > lastMoney then
			hud.moneyScale.Scale = 1.08
			tween(hud.moneyScale, 0.2, { Scale = 1 })
		end
		lastMoney = store.Money
		refreshHud()
	end)
	UI.Refresh()
end

-- toolkit for the other UI modules (UIExtra, Markers, Minimap)
function UI.Kit()
	return {
		new = new, toy = toy, text = text, corner = corner, stroke = stroke, gradient = gradient, list = list, clear = clear,
		tween = tween, pill = pill, lift = lift, panelShell = panelShell, scroller = scroller, carViewport = carViewport,
		P = P, HEAD = HEAD, BODY = BODY, root = root, gui = gui, hud = hud, panels = panels, state = state, store = store,
		actions = actions, PART_ICON = PART_ICON,
	}
end

return UI
