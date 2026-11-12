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
local Icons = require(Shared:WaitForChild("Icons"))
local PartVisual = require(Shared:WaitForChild("PartVisual"))
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
local PART_ICON = {}
for id, p in pairs(PartConfig.Parts) do
	PART_ICON[id] = p.emoji
end
local ZONE_ICON = { city = "🏙️", highway = "🛣️", industrial = "🏭", neon = "🌃", scrapyard = "💀", docks = "🚂", desert = "🏜️", bridge = "🌉",
	airport = "✈️", canyon = "💀", circuit = "🏁", drift = "🌀", storm = "⛈️", rush = "🚦", colosseum = "👑" }
local ZONE_COLOR = { city = P.green, highway = P.blue, industrial = P.red, neon = P.cyan, plaza = P.orange, scrapyard = P.red, docks = P.blue, desert = P.orange,
	bridge = P.cyan, airport = P.blue, canyon = P.red, circuit = P.red, drift = P.cyan, storm = P.blue, rush = P.orange, colosseum = P.yellow }

local UI = {}
local store, actions
local gui, root
local overlay -- v10: pop-ups (reveal, dialogs, checkpoint, trade request, notifications) on one layer scaled like the HUD
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
		if k ~= "Outline" and k ~= "NoFit" then
			l[k] = v
		end
	end
	if props.Outline ~= false and l.Font == HEAD then
		new("UIStroke", { Color = P.ink, Thickness = props.Outline or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, l)
	end
	-- never overflow the frame: fixed-size labels shrink to fit (up to the requested size)
	if l.AutomaticSize == Enum.AutomaticSize.None and not l.TextScaled and props.NoFit ~= true then
		local want = l.TextSize
		l.TextScaled = true
		new("UITextSizeConstraint", { MaxTextSize = want, MinTextSize = math.min(9, want) }, l)
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
	local imgId = o.Image and Icons.Get(o.Image)
	if imgId then
		-- 3D sticker (Blender render): big, with a clear gap above the label
		content:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, 5)
		local sz = math.floor(h * 0.58)
		icon = new("ImageLabel", { Image = imgId, BackgroundTransparency = 1, Size = UDim2.fromOffset(sz, sz), ScaleType = Enum.ScaleType.Fit, ZIndex = face.ZIndex, LayoutOrder = 1 }, content)
	elseif o.Icon then
		icon = text(content, { Text = o.Icon, Font = BODY, TextSize = o.IconSize or math.floor(h * 0.34), Size = UDim2.new(1, 0, 0, math.floor(h * 0.4)), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = face.ZIndex, LayoutOrder = 1 })
	end
	local withIcon = icon ~= nil
	local label = text(content, { Text = o.Text or "", TextSize = o.TextSize or math.floor(h * (withIcon and 0.19 or 0.36)), RichText = true,
		Size = UDim2.new(1, -8, 0, math.floor(h * (withIcon and 0.24 or 0.5))), TextXAlignment = Enum.TextXAlignment.Center, Outline = 2.5, ZIndex = face.ZIndex, LayoutOrder = 2 })
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
	face.InputEnded:Connect(function(input) -- touch: the finger slid off the button
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			up()
		end
	end)
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
	if name == "soft" then
		name = "step" -- the quiet two-note chime (ElevenLabs) is the one calm "done" sound
	end
	local s = sounds[name]
	if s then
		s:Play()
	end
end
-- two volume groups for the Settings sliders: SFX (every UI/game sound) and Music
local function soundGroup(name, vol)
	local g = SoundService:FindFirstChild(name) or new("SoundGroup", { Name = name, Volume = vol }, SoundService)
	return g
end
UI.SfxGroup = soundGroup("SFX", 0.8)
UI.MusicGroup = soundGroup("Music", 0.5)
local function makeSound(name, id, vol, speed)
	sounds[name] = new("Sound", { Name = "UI_" .. name, SoundId = id, Volume = vol or 0.5, PlaybackSpeed = speed or 1, SoundGroup = UI.SfxGroup }, SoundService)
end

local KIND_COLOR = { good = P.green, error = P.red, warn = P.orange, info = P.blue }
-- Notifications (v10): one queue for every top message. Max 3 on screen, the same text within its lifetime merges
-- into "x2" instead of stacking, items move with their own position tweens (no list-layout snapping), and the
-- whole pill (background, text AND outline) fades before it is destroyed.
-- v13: small pills at the very top centre (the zone banner moved to the top-left), max 2 at once
local notes = { items = {}, queue = {}, top = 8 }
local NOTE_H, NOTE_GAP, NOTE_MAX, NOTE_LIFE = 28, 6, 2, 2.8

local function noteY(i)
	-- with a panel open the lane sits above the panel card, so a message never covers the button just pressed
	-- dialogs (confirm, checkpoint) also push the lane to the very top so it never covers their buttons
	local top = (state.open or state.dialog) and (hud.tutInPanel and 108 or 6) or (hud.tutInPanel and 108 or notes.top) -- below the tutorial card on garage steps
	return top + (i - 1) * (NOTE_H + NOTE_GAP)
end

local function noteLayout()
	for i, it in ipairs(notes.items) do
		tween(it.f, 0.22, { Position = UDim2.new(0.5, 0, 0, noteY(i)) })
	end
end

local noteShow
local function noteRemove(it)
	if it.dead then
		return
	end
	it.dead = true
	for i, x in ipairs(notes.items) do
		if x == it then
			table.remove(notes.items, i)
			break
		end
	end
	tween(it.f, 0.25, { BackgroundTransparency = 1 })
	tween(it.l, 0.25, { TextTransparency = 1 })
	tween(it.stroke, 0.25, { Transparency = 1 })
	for _, st in ipairs(it.l:GetChildren()) do
		if st:IsA("UIStroke") then
			tween(st, 0.25, { Transparency = 1 })
		end
	end
	task.delay(0.27, function()
		it.f:Destroy()
	end)
	noteLayout()
	local nextOne = table.remove(notes.queue, 1)
	while nextOne and (os.clock() - (nextOne.at or 0) > 4 or (state.notesOff and nextOne.kind ~= "error" and nextOne.kind ~= "warn")) do
		nextOne = table.remove(notes.queue, 1) -- stale ("Not enough money" 8 s later helps nobody)
	end
	if nextOne then
		noteShow(nextOne.msg, nextOne.kind, nextOne.n, nextOne.silent)
	end
end

local function noteLabel(it)
	return it.n > 1 and (it.msg .. "   x" .. it.n) or it.msg
end

noteShow = function(msg, kind, n, silent)
	local f = new("TextButton", { Name = "Note", Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, noteY(#notes.items + 1) - 10), AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, NOTE_H), BackgroundColor3 = KIND_COLOR[kind] or P.blue, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 50 }, hud.toasts)
	corner(f, 14)
	local st = stroke(f, P.ink, 2)
	st.Transparency = 1
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, f)
	local l = text(f, { Text = msg, TextSize = 15, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), ZIndex = 51, TextTransparency = 1 })
	local it = { f = f, l = l, stroke = st, msg = msg, kind = kind, n = n or 1, expire = os.clock() + NOTE_LIFE, born = os.clock() }
	l.Text = noteLabel(it)
	table.insert(notes.items, it)
	f.Activated:Connect(function() -- tap a message to hide it right away
		noteRemove(it)
	end)
	tween(f, 0.2, { BackgroundTransparency = 0 })
	tween(l, 0.2, { TextTransparency = 0 })
	tween(st, 0.2, { Transparency = 0 })
	noteLayout()
	if not silent then
		UI.Sfx(kind == "error" and "err" or "ping")
	end
end

-- silent = no ping (e.g. a message that comes with its own sound); notifications can be switched off in Settings
-- (errors still show: the player must know why an action failed)
function UI.Toast(msg, kind, silent)
	msg = tostring(msg)
	if state.notesOff and kind ~= "error" and kind ~= "warn" then
		return
	end
	-- same message already on screen or waiting: count it instead of adding another pill
	for _, it in ipairs(notes.items) do
		if not it.dead and it.msg == msg then
			it.n = it.n + 1
			it.l.Text = noteLabel(it)
			-- refresh, but never longer than 6 s in total and not while others are waiting
			it.expire = #notes.queue > 0 and it.expire or math.min(os.clock() + NOTE_LIFE, it.born + 6)
			return
		end
	end
	for _, q in ipairs(notes.queue) do
		if q.msg == msg then
			q.n = q.n + 1
			return
		end
	end
	if #notes.items >= NOTE_MAX then
		table.insert(notes.queue, { msg = msg, kind = kind, n = 1, at = os.clock(), silent = silent })
		while #notes.queue > 5 do
			table.remove(notes.queue, 1) -- a burst: drop the oldest waiting messages
		end
		-- make room soon: the oldest one leaves early
		local oldest = notes.items[1]
		oldest.expire = math.min(oldest.expire, os.clock() + 0.6)
		return
	end
	noteShow(msg, kind, 1, silent)
end

-- a modal dialog (confirm, checkpoint) is up: the notification lane moves to the very top
-- counted: a confirm over the checkpoint card, or a confirm replacing another one, keeps the flag right
local dialogDepth = 0
function UI.SetDialog(on)
	dialogDepth = math.max(0, dialogDepth + (on and 1 or -1))
	state.dialog = dialogDepth > 0 or nil
	noteLayout()
end

function UI.SetNotificationsEnabled(on)
	if state.notesOff == not on then
		return -- unchanged (called on every settings change)
	end
	state.notesOff = not on
	if not on then
		-- drop waiting messages first (errors/warnings stay), then hide what is on screen
		local keep = {}
		for _, q in ipairs(notes.queue) do
			if q.kind == "error" or q.kind == "warn" then
				table.insert(keep, q)
			end
		end
		notes.queue = keep
		for _, it in ipairs(table.clone(notes.items)) do
			if it.kind ~= "error" and it.kind ~= "warn" then
				noteRemove(it)
			end
		end
	end
end

task.spawn(function()
	while true do
		task.wait(0.1)
		pcall(function()
			local now = os.clock()
			for _, it in ipairs(table.clone(notes.items)) do
				if state.cine then
					it.expire = math.max(it.expire, now + 0.5) -- hidden during cinematics: keep it for afterwards
				elseif now >= it.expire then
					noteRemove(it)
				end
			end
		end)
	end
end)

function UI.Notify(payload)
	if type(payload) ~= "table" then
		return
	end
	local SILENT = { banked = true, banked2 = true, contractDone = true, contractsDone = true, dailyClaimed = true, chestClaimed = true }
	UI.Toast(T("n_" .. tostring(payload.key), table.unpack(payload.args or {})), payload.kind, SILENT[payload.key])
end

---------------------------------------------------------------- HUD
local function buildHud()
	-- left column (Figma "08 — HUD Left Clean"): no cards, outlined type, real 3D icons
	-- bottom-left corner; on phones lifted above the movement thumbstick
	local UIS = game:GetService("UserInputService")
	local lift = (UIS.TouchEnabled and not UIS.KeyboardEnabled) and 210 or 0
	hud.leftLift = lift
	local colF = new("Frame", { Name = "LeftColumn", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -16 - lift), Size = UDim2.fromOffset(280, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, root)
	list(colF, Enum.FillDirection.Vertical, 12)
	hud.leftCol = colF
	local function outline(l, th)
		new("UIStroke", { Color = P.ink, Thickness = th or 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, l)
		return l
	end
	local function icon(parent, name, size, pos)
		local img = new("ImageLabel", { Size = UDim2.fromOffset(size, size), Position = pos or UDim2.new(), BackgroundTransparency = 1, Image = Icons.Get(name) or "", ScaleType = Enum.ScaleType.Fit }, parent)
		if img.Image == "" then -- not uploaded: a plain short word instead
			text(img, { Text = string.upper(string.sub(name, 1, 4)), TextSize = 14, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
		end
		return img
	end
	-- money
	local money = new("Frame", { Name = "Money", Size = UDim2.fromOffset(280, 64), BackgroundTransparency = 1, LayoutOrder = 5 }, colF)
	icon(money, "coin", 56, UDim2.fromOffset(0, 4))
	hud.money = text(money, { Position = UDim2.fromOffset(64, 0), Size = UDim2.new(1, -64, 0, 42), TextSize = 40, TextColor3 = P.white, Outline = 3 })
	hud.income = outline(text(money, { Position = UDim2.fromOffset(65, 42), Size = UDim2.new(1, -65, 0, 20), TextSize = 18, Font = BODY, TextColor3 = C(70, 220, 100) }), 2.5)
	hud.moneyScale = new("UIScale", {}, money)
	-- loot carried on this run (only while carrying)
	local bag = new("Frame", { Name = "Carrying", Size = UDim2.fromOffset(280, 28), BackgroundTransparency = 1, Visible = false, LayoutOrder = 3 }, colF)
	hud.bag = bag
	hud.bagText = text(bag, { Text = "", TextSize = 17, TextColor3 = C(255, 80, 70), Size = UDim2.new(1, 0, 0, 20), Outline = 2.5 })
	local bbar = new("Frame", { Position = UDim2.fromOffset(0, 23), Size = UDim2.fromOffset(200, 4), BackgroundColor3 = P.ink, BackgroundTransparency = 0.45, BorderSizePixel = 0 }, bag)
	corner(bbar, 2)
	hud.bagFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C(255, 80, 70), BorderSizePixel = 0 }, bbar)
	corner(hud.bagFill, 2)
	hud.icon = icon

	-- zone banner + hint
	-- zone banner: top-left corner (the top centre belongs to the notifications)
	local banner = new("Frame", { AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 16, 0, 12), Size = UDim2.fromOffset(250, 42), BackgroundColor3 = P.white, BorderSizePixel = 0 }, root)
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
	-- phones: start higher and a bit smaller so the column ends above the jump button
	local touch = (UIS.TouchEnabled and not UIS.KeyboardEnabled)
	local side = new("Frame", { Name = "SideButtons", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, touch and 64 or 100), Size = UDim2.fromOffset(122, 5 * 104 + 48), BackgroundTransparency = 1 }, root)
	if touch then
		new("UIScale", { Scale = 0.8 }, side)
	end
	hud.side = side
	list(side, Enum.FillDirection.Vertical, 12)
	local tpBtn = toy(side, { Text = T("btn_teleport"), Image = "teleport", Icon = "🚀", Color = P.blue, Size = UDim2.fromOffset(122, 104), LayoutOrder = 1, OnClick = function() UI.TogglePanel("teleport") end })
	hud.garageBtn = toy(side, { Text = T("btn_garage"), Image = "garage", Icon = "🏁", Color = P.orange, Size = UDim2.fromOffset(122, 104), LayoutOrder = 2, OnClick = function() UI.TogglePanel("garage") end })
	toy(side, { Text = T("btn_index"), Image = "index", Icon = "🚗", Color = P.green, Size = UDim2.fromOffset(122, 104), LayoutOrder = 3, OnClick = function() UI.TogglePanel("index") end })
	-- on the TELEPORT button itself (as a child of the list it used to push every button down)
	hud.teleportBtn = tpBtn
	hud.newDot = new("Frame", { Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -16, 0, -6), BackgroundColor3 = P.red, Visible = false, ZIndex = 5 }, tpBtn.holder)
	corner(hud.newDot, 11)
	stroke(hud.newDot, P.white, 3)

	-- THROW (only near own trap)
	hud.throw = toy(root, { Name = "Throw", Text = T("btn_throw"), Sub = "", Color = P.yellow, Size = UDim2.fromOffset(300, 104),
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), OnClick = function() UI.TogglePanel("throw") end })
	hud.throw.holder.Visible = false

	hud.toasts = new("Frame", { Name = "Notes", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 90 }, overlay) -- items position themselves (UI.Toast)
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

-- THROW menu (Figma "09 — Throw Menu"): pick how many of each part, see the expected cars, throw them all at once
state.mix = {}
state.merge = true
local function mixTotal()
	local n = 0
	for _, id in ipairs(PartConfig.Order) do
		n = n + math.min(state.mix[id] or 0, store.Banked(id))
	end
	return n
end
-- how many cars one throw may catch (1..4, "Multi Catch" perk in the Pit Stop)
local function catchLimit()
	local st = store.State
	return EconomyConfig.CatchLimit(st and st.perks and st.perks.multi or 0)
end
local function setMix(id, n)
	local total = mixTotal() - math.min(state.mix[id] or 0, store.Banked(id))
	state.mix[id] = math.clamp(n, 0, math.min(store.Banked(id), EconomyConfig.MaxBatch - total))
	UI.Refresh()
end

local function buildThrow()
	local p = panelShell("throw", T("throw_title"), 940, 600, P.yellow)
	local c = p.content
	local rows = scroller(c, UDim2.new(), UDim2.fromOffset(570, 410)) -- 10 parts: scrolling list
	panels.throwRows = {}
	-- rarity points of the pick + cars per throw (1 at the start, up to 4 with "Multi Catch")
	panels.catchInfo = text(c, { Text = "", Font = BODY, TextSize = 17, TextColor3 = P.ink, RichText = true, Position = UDim2.fromOffset(0, 420), Size = UDim2.fromOffset(560, 26), ZIndex = 23 })
	for i, id in ipairs(PartConfig.Order) do
		local rc = rarityColor(PartConfig.Parts[id].rarity)
		local r = new("Frame", { Size = UDim2.fromOffset(548, 74), BackgroundColor3 = P.white, LayoutOrder = i, ZIndex = 23 }, rows)
		corner(r, 18)
		local st = stroke(r, rc, 4)
		-- the real 3D part (same model as on the map), slowly turning
		local img = new("ViewportFrame", { Position = UDim2.fromOffset(8, 5), Size = UDim2.fromOffset(64, 64), BackgroundTransparency = 1, Ambient = C(190, 190, 200),
			LightColor = C(255, 250, 240), LightDirection = Vector3.new(-1, -1.5, -1), ZIndex = 24 }, r)
		local pm = PartVisual.Build(id)
		for _, d in ipairs(pm:GetDescendants()) do
			if d:IsA("ParticleEmitter") or d:IsA("Light") then
				d:Destroy()
			end
		end
		pm:PivotTo(CFrame.new())
		pm.Parent = img
		local cam = new("Camera", { FieldOfView = 30 }, img)
		img.CurrentCamera = cam
		local _, ext = pm:GetBoundingBox()
		panels.partSpin = panels.partSpin or {}
		table.insert(panels.partSpin, { cam = cam, dist = math.max(ext.X, ext.Y, ext.Z) * 2.4, centre = pm:GetBoundingBox().Position })
		text(r, { Text = string.upper(T("part_" .. id)), TextSize = 20, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(80, 10), Size = UDim2.fromOffset(152, 26), ZIndex = 24 })
		local owned = text(r, { Text = "", Font = BODY, TextSize = 14, TextColor3 = P.muted, Position = UDim2.fromOffset(80, 40), Size = UDim2.fromOffset(150, 20), ZIndex = 24 })
		local function stepBtn(label, color, x, w, onClick)
			return toy(r, { Text = label, Color = color, Size = UDim2.fromOffset(w, 48), Position = UDim2.fromOffset(x, 12), TextSize = label == "MAX" and 18 or 26, ZIndex = 25, OnClick = onClick })
		end
		local minus = stepBtn("-", P.red, 240, 46, function() setMix(id, (state.mix[id] or 0) - 1) end)
		local cnt = new("Frame", { Position = UDim2.fromOffset(294, 15), Size = UDim2.fromOffset(72, 44), BackgroundColor3 = C(244, 240, 230), ZIndex = 24 }, r)
		corner(cnt, 12)
		local cntText = text(cnt, { Text = "0", TextSize = 26, TextColor3 = P.ink, Outline = false, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 25 })
		local plus = stepBtn("+", P.green, 374, 46, function() setMix(id, (state.mix[id] or 0) + 1) end)
		local max = stepBtn("MAX", P.blue, 428, 80, function() setMix(id, store.Banked(id)) end)
		-- hold +/- to repeat
		for _, pair in ipairs({ { plus, 1 }, { minus, -1 } }) do
			local held = false
			pair[1].face.MouseButton1Down:Connect(function()
				held = true
				task.delay(0.4, function()
					while held do
						setMix(id, (state.mix[id] or 0) + pair[2])
						task.wait(0.06)
					end
				end)
			end)
			pair[1].face.MouseButton1Up:Connect(function() held = false end)
			pair[1].face.MouseLeave:Connect(function() held = false end)
			pair[1].face.InputEnded:Connect(function() held = false end)
		end
		panels.throwRows[id] = { frame = r, stroke = st, img = img, owned = owned, cnt = cntText, minus = minus, plus = plus, max = max, rc = rc }
	end
	-- right column: quick picks, expected cars, merge toggle, throw
	local right = new("Frame", { Position = UDim2.fromOffset(582, 0), Size = UDim2.fromOffset(312, 480), BackgroundTransparency = 1, ZIndex = 22 }, c)
	toy(right, { Text = "ALL", Color = P.orange, Size = UDim2.fromOffset(98, 46), Position = UDim2.fromOffset(0, 0), TextSize = 20, ZIndex = 23, OnClick = function()
		-- every part you have (more parts = more rarity points)
		state.mix = {}
		local left = EconomyConfig.MaxBatch
		for i = #PartConfig.Order, 1, -1 do
			local id = PartConfig.Order[i]
			local n = math.min(store.Banked(id), left)
			state.mix[id] = n
			left = left - n
		end
		UI.Refresh()
	end })
	toy(right, { Text = "RARE", Color = P.blue, Size = UDim2.fromOffset(98, 46), Position = UDim2.fromOffset(107, 0), TextSize = 20, ZIndex = 23, OnClick = function()
		-- only Rare, Epic and Legendary parts
		state.mix = {}
		for _, id in ipairs(PartConfig.Order) do
			local rar = PartConfig.Parts[id].rarity
			if rar == "Rare" or rar == "Epic" or rar == "Legendary" then
				state.mix[id] = store.Banked(id)
			end
		end
		UI.Refresh()
	end })
	toy(right, { Text = "CLEAR", Color = P.grey, Size = UDim2.fromOffset(98, 46), Position = UDim2.fromOffset(214, 0), TextSize = 18, ZIndex = 23, OnClick = function()
		state.mix = {}
		UI.Refresh()
	end })
	local odds = new("Frame", { Position = UDim2.fromOffset(0, 60), Size = UDim2.fromOffset(312, 212), BackgroundColor3 = P.white, ZIndex = 23 }, right)
	corner(odds, 18)
	stroke(odds, P.ink, 3)
	text(odds, { Text = "CHANCE PER CAR", TextSize = 18, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(280, 22), ZIndex = 24 })
	local bar = new("Frame", { Position = UDim2.fromOffset(14, 38), Size = UDim2.fromOffset(284, 16), BackgroundColor3 = C(230, 232, 236), ClipsDescendants = true, ZIndex = 24 }, odds)
	corner(bar, 8)
	list(bar, Enum.FillDirection.Horizontal, 0)
	panels.oddsBar = bar
	panels.oddsLines = {}
	for i, r in ipairs(CarConfig.RarityOrder) do
		local dot = new("Frame", { Position = UDim2.fromOffset(14, 64 + (i - 1) * 22), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = rarityColor(r), ZIndex = 24 }, odds)
		corner(dot, 6)
		panels.oddsLines[r] = text(odds, { Text = "", Font = BODY, TextSize = 15, TextColor3 = P.ink, RichText = true, Position = UDim2.fromOffset(34, 58 + (i - 1) * 22), Size = UDim2.fromOffset(260, 22), ZIndex = 24 })
	end
	panels.oddsText = text(odds, { Text = "", Font = BODY, TextSize = 14, TextColor3 = P.orange, Position = UDim2.fromOffset(14, 178), Size = UDim2.fromOffset(284, 22), ZIndex = 24 })
	-- merge toggle
	local tg = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(0, 286), Size = UDim2.fromOffset(312, 44), BackgroundTransparency = 1, ZIndex = 23 }, right)
	local sw = new("Frame", { Position = UDim2.fromOffset(0, 7), Size = UDim2.fromOffset(52, 30), BackgroundColor3 = P.green, ZIndex = 24 }, tg)
	corner(sw, 15)
	stroke(sw, P.ink, 3)
	local knob = new("Frame", { Position = UDim2.fromOffset(25, 4), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = P.white, ZIndex = 25 }, sw)
	corner(knob, 11)
	text(tg, { Text = "MERGE DUPLICATES", TextSize = 16, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(62, 2), Size = UDim2.fromOffset(250, 20), ZIndex = 24 })
	text(tg, { Text = string.format("Same car = +1 level (up to Lv%d)", EconomyConfig.MergeMaxLevel), Font = BODY, TextSize = 13, TextColor3 = P.muted, Position = UDim2.fromOffset(62, 22), Size = UDim2.fromOffset(250, 18), ZIndex = 24 })
	tg.Activated:Connect(function()
		state.merge = not state.merge
		UI.Sfx("click")
		UI.Refresh()
	end)
	panels.mergeSw, panels.mergeKnob = sw, knob
	panels.throwGo = toy(right, { Text = T("btn_throw"), Color = P.green, Size = UDim2.fromOffset(312, 80), Position = UDim2.fromOffset(0, 344), TextSize = 30, ZIndex = 23,
		OnClick = function()
			local total = mixTotal()
			if total <= 0 then
				UI.Toast(T("n_noPart"), "error")
				return
			end
			local counts = {}
			for _, id in ipairs(PartConfig.Order) do
				local n = math.min(state.mix[id] or 0, store.Banked(id))
				if n > 0 then
					counts[id] = n
				end
			end
			actions.ThrowBatch(counts, state.merge)
			state.mix = {}
			UI.TogglePanel(nil)
		end })
end

-- turn the part previews while the throw menu is open
RunService.RenderStepped:Connect(function()
	if state.open ~= "throw" or not panels.partSpin then
		return
	end
	local a = os.clock() * 0.9
	for _, sp in ipairs(panels.partSpin) do
		local off = Vector3.new(math.cos(a), 0.55, math.sin(a)).Unit * sp.dist
		sp.cam.CFrame = CFrame.lookAt(sp.centre + off, sp.centre)
	end
end)

local function refreshThrow()
	local st = store.State
	if not st then
		return
	end
	local ready = store.BankedTotal()
	-- first open: preselect one of the best part so a single tap still works
	if mixTotal() == 0 and ready > 0 and not state.mixTouched then
		for i = #PartConfig.Order, 1, -1 do
			local id = PartConfig.Order[i]
			if store.Banked(id) > 0 then
				state.mix[id] = 1
				break
			end
		end
	end
	hud.throw.SetText(T("btn_throw"), ready > 0 and string.format("%d parts ready", ready) or T("throw_none"))
	hud.throw.SetColor(ready > 0 and P.yellow or P.grey)
	if not panels.throwRows or state.open ~= "throw" then
		return
	end
	state.mixTouched = true
	local lim = catchLimit()
	local total, points = 0, 0
	for id, row in pairs(panels.throwRows) do
		local own = store.Banked(id)
		local n = math.min(state.mix[id] or 0, own)
		total = total + n
		row.owned.Text = own > 0 and string.format("%d owned", own) or "none owned"
		row.cnt.Text = tostring(n)
		row.cnt.TextColor3 = n > 0 and P.ink or P.grey
		row.stroke.Color = n > 0 and row.rc or C(220, 222, 226)
		row.stroke.Thickness = n > 0 and 4 or 2
		row.img.ImageTransparency = own > 0 and 0 or 0.55
		row.minus.SetColor(n > 0 and P.red or P.grey)
		row.plus.SetColor(n < own and P.green or P.grey)
		row.max.SetColor(own > 0 and P.blue or P.grey)
		points = points + n * PartConfig.Parts[id].points
	end
	-- all parts add rarity points; the throw catches `lim` cars, each rolled on those points
	panels.catchInfo.Text = string.format("<b>%d</b> rarity points  ·  catches <b>%d</b> car%s%s", points, lim, lim > 1 and "s" or "",
		lim < EconomyConfig.MaxCatch and "  ·  more with <b>Multi Catch</b> (Pit Stop)" or "")
	local chances = CarConfig.ChancesForPoints(math.max(points, 1))
	local expected = {}
	for _, r in ipairs(CarConfig.RarityOrder) do
		expected[r] = total > 0 and lim * chances[r] / 100 or 0
	end
	clear(panels.oddsBar)
	for i, r in ipairs(CarConfig.RarityOrder) do
		local share = total > 0 and chances[r] / 100 or 0
		if share > 0 then
			new("Frame", { Size = UDim2.new(math.max(share, 0.012), 0, 1, 0), BackgroundColor3 = rarityColor(r), BorderSizePixel = 0, LayoutOrder = i, ZIndex = 25 }, panels.oddsBar)
		end
		panels.oddsLines[r].Text = string.format("<b>%s</b>  <font color=\"#606674\">%s%%</font>", T("rarity_" .. r), total > 0 and (chances[r] >= 10 and string.format("%.0f", chances[r]) or string.format("%.1f", chances[r])) or "0")
	end
	local pity = st.pity or 0
	local left = EconomyConfig.PityThreshold - pity
	panels.oddsText.Text = left <= 1 and T("throw_pity_now") or T("throw_pity", left)
	panels.mergeSw.BackgroundColor3 = state.merge and P.green or P.grey
	panels.mergeKnob.Position = UDim2.fromOffset(state.merge and 25 or 3, 4)
	panels.throwGo.SetText(total > 0 and string.format("THROW %d PARTS", total) or T("btn_throw"), nil)
	panels.throwGo.SetColor(total > 0 and P.green or P.grey)
end

-- TELEPORT (also unlocks districts)
local function buildTeleport()
	local p = panelShell("teleport", T("tp_title"), 820, 560, P.blue)
	panels.tpGrid = new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -40), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8, ScrollBarImageColor3 = P.ink,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 22 }, p.content)
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
		local needReb = req and (req.rebirths or 0) > (st.rebirths or 0)
		if not open and not prevOpen then
			break -- show only the next district to unlock, the rest stays a surprise
		end
		if open then
			tile(i, title, ZONE_ICON[zid], ZONE_COLOR[zid], T("zone_desc_" .. zid), function()
				actions.Teleport(zid)
				UI.TogglePanel(nil)
			end)
		else
			local can = prevOpen and req and not needReb and store.Money >= req.cost and store.CollectionValue >= req.minValue
			local sub = needReb and string.format(T("n_needRebirth"), req.rebirths)
				or string.format("🔒 $%s  ·  %s $%s", Util.FormatNumber(req.cost), T("zones_value"), Util.FormatNumber(req.minValue))
			local t = tile(i, can and (T("btn_unlock") .. "!") or title, "🔒", can and P.green or P.grey, sub, function()
				if can then
					actions.Unlock(zid)
				elseif needReb then
					UI.Toast(string.format(T("n_needRebirth"), req.rebirths), "warn")
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
-- confirmation popup (sell etc.)
local confirmDim
local function closeConfirm()
	if confirmDim then
		confirmDim:Destroy()
		confirmDim = nil
	end
end

function UI.Confirm(title, body, okText, okColor, onOk, def)
	closeConfirm() -- never two dialogs on top of each other
	if state.cine then
		return
	end
	local dim = new("TextButton", { Name = "Confirm", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 85 }, overlay)
	local card = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(480, def and 400 or 260), BackgroundColor3 = P.cream, ZIndex = 86 }, dim)
	corner(card, 26)
	stroke(card, P.ink, 5)
	local sc = new("UIScale", { Scale = 0.6 }, card)
	tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	text(card, { Text = title, TextSize = 32, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 87, Outline = 3 })
	local y = 62
	if def then
		carViewport(card, def, { Position = UDim2.fromOffset(90, 56), Size = UDim2.fromOffset(300, 140), ZIndex = 87 })
		y = 200
	end
	text(card, { Text = body, Font = BODY, TextSize = 20, TextColor3 = P.ink, RichText = true, TextWrapped = true, Position = UDim2.fromOffset(24, y), Size = UDim2.new(1, -48, 0, 70), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 87 })
	local btns = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(440, 70), BackgroundTransparency = 1, ZIndex = 87 }, card)
	list(btns, Enum.FillDirection.Horizontal, 16, Enum.HorizontalAlignment.Center)
	toy(btns, { Text = "KEEP", Color = P.grey, Size = UDim2.fromOffset(170, 66), TextSize = 24, LayoutOrder = 1, ZIndex = 88, OnClick = function() dim:Destroy() end })
	toy(btns, { Text = okText, Color = okColor or P.red, Size = UDim2.fromOffset(220, 66), TextSize = 24, LayoutOrder = 2, ZIndex = 88, OnClick = function()
		dim:Destroy()
		onOk()
	end })
	dim.Activated:Connect(function() dim:Destroy() end)
	confirmDim = dim
	UI.SetDialog(true)
	dim.Destroying:Connect(function()
		UI.SetDialog(false)
	end)
end

state.garageTab = "parked"
local function buildGarage()
	local p = panelShell("garage", T("garage_title"), 940, 600, P.orange)
	local c = p.content
	panels.garageInfo = text(c, { Text = "", Font = BODY, TextSize = 18, TextColor3 = P.ink, Size = UDim2.new(1, -540, 0, 50), ZIndex = 22, RichText = true, TextWrapped = true })
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
	-- tabs + bulk sell
	local tabs = new("Frame", { Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, ZIndex = 22 }, c)
	list(tabs, Enum.FillDirection.Horizontal, 10)
	panels.garageTabs = {}
	for i, tab in ipairs({ "parked", "storage" }) do
		panels.garageTabs[tab] = toy(tabs, { Text = string.upper(tab), Color = P.grey, Size = UDim2.fromOffset(170, 48), TextSize = 20, LayoutOrder = i, ZIndex = 23, OnClick = function()
			state.garageTab = tab
			UI.Refresh()
		end })
	end
	panels.bulk = {}
	for i, r in ipairs({ "Common", "Uncommon" }) do
		panels.bulk[r] = toy(tabs, { Text = "SELL ALL " .. string.upper(r), Color = P.red, Size = UDim2.fromOffset(250, 48), TextSize = 16, LayoutOrder = 10 + i, ZIndex = 23, OnClick = function()
			local st = store.State
			local uids, total = {}, 0
			for _, car in ipairs(st.cars) do
				local def = CarConfig.ById[car.typeId]
				if not car.slot and def.rarity == r and #uids < 100 then
					table.insert(uids, car.uid)
					total = total + CarConfig.SellPrice(def, car.level)
				end
			end
			if #uids == 0 then
				UI.Toast("No " .. r .. " cars in storage", "warn")
				return
			end
			UI.Confirm("SELL " .. #uids .. " CARS?", string.format("All %s cars in storage for <b>$%s</b>.\nParked cars are never sold.", r, Util.FormatNumber(total)), "SELL ALL", P.red, function()
				actions.SellMany(uids)
			end)
		end })
	end
	panels.carList = scroller(c, UDim2.fromOffset(0, 120), UDim2.new(1, 0, 1, -120))
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
	local parked, stored = 0, 0
	for _, c in ipairs(st.cars) do
		if c.slot then
			parked = parked + 1
		else
			stored = stored + 1
		end
	end
	panels.garageInfo.Text = string.format('<font color="#1E9E40">+%s/s</font>   Bays %d/%d   Cars %d', Util.FormatNumber(store.Income), parked, st.slots, #st.cars)
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
	local tab = state.garageTab
	panels.garageTabs.parked.SetText(string.format("PARKED %d", parked), nil)
	panels.garageTabs.storage.SetText(string.format("STORAGE %d", stored), nil)
	panels.garageTabs.parked.SetColor(tab == "parked" and P.orange or P.grey)
	panels.garageTabs.storage.SetColor(tab == "storage" and P.orange or P.grey)
	for _, b in pairs(panels.bulk) do
		b.holder.Visible = tab == "storage"
	end
	clear(panels.carList)
	local cars = {}
	for _, car in ipairs(sortedCars(st)) do
		if (tab == "parked") == (car.slot ~= nil) then
			table.insert(cars, car)
		end
	end
	if #cars == 0 then
		local msg = #st.cars == 0 and T("garage_empty") or (tab == "parked" and "No cars parked. Open STORAGE and press PARK." or "Storage is empty. Cars you REMOVE from the garage wait here.")
		text(panels.carList, { Text = msg, Font = BODY, TextSize = 20, TextColor3 = P.muted, TextWrapped = true, Size = UDim2.new(1, 0, 0, 60), ZIndex = 23 })
		return
	end
	for i, c in ipairs(cars) do
		local def = CarConfig.ById[c.typeId]
		local rc = rarityColor(def.rarity)
		local row = new("Frame", { Size = UDim2.new(1, 0, 0, 88), BackgroundColor3 = P.white, LayoutOrder = i, ZIndex = 23 }, panels.carList)
		corner(row, 18)
		stroke(row, rc, 4)
		if i <= 24 then
			carViewport(row, def, { Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(120, 76), ZIndex = 24 })
		end
		text(row, { Text = def.name, TextSize = 22, TextColor3 = P.ink, Outline = false, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(136, 10), Size = UDim2.fromOffset(260, 28), ZIndex = 24 })
		local where = c.slot and ("Bay " .. c.slot) or "Storage"
		text(row, { Text = string.format('<font color="#%s">%s</font> · Lv %d · <font color="#1E9E40">+%s/s</font> · %s', rc:ToHex(), string.upper(T("rarity_" .. def.rarity)),
			c.level, Util.FormatNumber(CarConfig.CarIncome(c)), where),
			Font = BODY, TextSize = 14, TextColor3 = P.muted, RichText = true, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(136, 46), Size = UDim2.fromOffset(260, 24), ZIndex = 24 })
		local btns = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(470, 60), BackgroundTransparency = 1, ZIndex = 24 }, row)
		list(btns, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
		if c.slot then
			toy(btns, { Text = T("btn_remove"), Sub = "to storage", SubSize = 12, Color = P.orange, Size = UDim2.fromOffset(104, 56), TextSize = 17, LayoutOrder = 1, ZIndex = 25, OnClick = function() actions.Remove(c.uid) end })
		else
			toy(btns, { Text = T("btn_place"), Sub = "in a bay", SubSize = 12, Color = P.green, Size = UDim2.fromOffset(104, 56), TextSize = 18, LayoutOrder = 1, ZIndex = 25, OnClick = function() actions.Place(c.uid, freeSlot(st)) end })
		end
		if c.level >= def.maxLevel then
			toy(btns, { Text = T("btn_max"), Color = P.grey, Size = UDim2.fromOffset(140, 56), LayoutOrder = 2, ZIndex = 25 })
		else
			local ucost = CarConfig.UpgradeCost(def, c.level)
			local partId, amount = CarConfig.UpgradeParts(def, c.level)
			local ok = store.Money >= ucost and (st.parts[partId] or 0) >= amount
			toy(btns, { Text = T("btn_upgrade"), Sub = string.format("$%s + %d %s", Util.FormatNumber(ucost), amount, T("part_" .. partId)), SubSize = 12, TextSize = 17,
				Color = ok and P.blue or P.grey, Size = UDim2.fromOffset(140, 56), LayoutOrder = 2, ZIndex = 25, OnClick = function() actions.Upgrade(c.uid, c.level) end })
		end
		local tuned = 0
		for _ in pairs(c.tune or {}) do
			tuned = tuned + 1
		end
		toy(btns, { Text = T("btn_tune"), Sub = tuned > 0 and (tuned .. "/7") or nil, SubSize = 12, TextSize = 17, Color = P.yellow, Size = UDim2.fromOffset(84, 56),
			LayoutOrder = 3, ZIndex = 25, OnClick = function()
				if UI.OnTune then
					UI.OnTune(c.uid)
				end
			end })
		local price = CarConfig.SellPrice(def, c.level)
		toy(btns, { Text = T("btn_sell"), Sub = "$" .. Util.FormatNumber(price), SubSize = 12, TextSize = 17, Color = P.red, Size = UDim2.fromOffset(96, 56), LayoutOrder = 4, ZIndex = 25,
			OnClick = function()
				UI.Confirm("SELL THIS CAR?", string.format("<b>%s</b>  Lv %d\nfor <b>$%s</b>", def.name, c.level, Util.FormatNumber(price)), "SELL $" .. Util.FormatNumber(price), P.red, function()
					actions.Sell(c.uid)
				end, def)
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
	if name ~= nil and state.cine then
		return -- no menus over a cinematic
	end
	if name ~= nil and state.open == name then
		name = nil
	end
	closeConfirm()
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
	noteLayout()
	pcall(function() -- world prompts (E/F at the garage, NPCs) only when no panel is open
		game:GetService("ProximityPromptService").Enabled = name == nil and not state.cine
	end)
	UI.Refresh()
end

-- Cinematic mode (car drop, batch reveal): the whole HUD hides, open panels close and cannot open,
-- proximity prompts and movement are off. Calls are counted, every SetCinematic(true) has one SetCinematic(false).
local cineDepth = 0
function UI.SetCinematic(on)
	cineDepth = math.max(0, cineDepth + (on and 1 or -1))
	local active = cineDepth > 0
	if (state.cine == true) == active then
		return
	end
	state.cine = active
	root.Visible = not active
	hud.toasts.Visible = not active
	Players.LocalPlayer:SetAttribute("Cinematic", active) -- world helpers (guide beam) hide too
	pcall(function()
		game:GetService("ProximityPromptService").Enabled = not active and state.open == nil
	end)
	if active then
		-- a failing hook must never leave the game half in cinematic mode
		pcall(UI.CloseOverlays)
		pcall(UI.TogglePanel, nil) -- closing is allowed in cinematic mode, opening is not
	end
	pcall(function()
		local pm = require(Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
		local controls = pm:GetControls()
		if active then
			controls:Disable()
		else
			controls:Enable()
		end
	end)
	if not active then
		pcall(UI.Refresh)
	end
end

function UI.IsCinematic()
	return state.cine == true
end

-- other modules register closers for their own pop-ups (trade request card, confirm dialogs, ...)
UI.Overlays = { closeConfirm }
function UI.CloseOverlays()
	for _, fn in ipairs(UI.Overlays) do
		pcall(fn)
	end
end

---------------------------------------------------------------- reveal
local function buildReveal()
	-- showcase: blurred world, rarity backdrop with turning rays + light streaks, car spinning on a glowing turntable
	local r = new("TextButton", { Name = "Reveal", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(6, 7, 12), BackgroundTransparency = 0, Visible = false, ZIndex = 60 }, overlay)
	local glow = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromScale(1.4, 1.4), BackgroundColor3 = P.yellow, BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 60 }, r)
	new("UIAspectRatioConstraint", {}, glow)
	corner(glow, 2000)
	local glowGrad = new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.5, 0.85), NumberSequenceKeypoint.new(1, 1) }), Rotation = 90 }, glow)
	local rays = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, ZIndex = 60 }, r)
	for k = 0, 11 do
		local ray = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(2000, 60), Rotation = k * 15, BackgroundColor3 = P.yellow, BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 60 }, rays)
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }) }, ray)
	end
	-- light streaks sweeping across + floating sparkles
	local streaks, sparks = {}, {}
	for k = 1, 3 do
		local st = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0.5, 0, 0, 6 + k * 3), Rotation = -18, BackgroundColor3 = C(255, 255, 255), BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = 61 }, r)
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }, st)
		streaks[k] = st
	end
	for k = 1, 26 do
		local sp = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = C(255, 255, 255), BorderSizePixel = 0, ZIndex = 61 }, r)
		corner(sp, 3)
		sparks[k] = { f = sp, x = math.random(), y = math.random(), v = 0.03 + math.random() * 0.06, s = 3 + math.random() * 7 }
	end
	local box = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(700, 640), BackgroundTransparency = 1, ZIndex = 61 }, r)
	local sc = new("UIScale", {}, box)
	local top = text(box, { Text = T("reveal_new"), TextSize = 34, Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 62 })
	local badge = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46), Size = UDim2.fromOffset(330, 54), BackgroundColor3 = P.white, ZIndex = 62 }, box)
	corner(badge, 27)
	stroke(badge, P.ink, 4)
	local badgeGrad = gradient(badge, P.yellow)
	local rarity = text(badge, { Text = "", TextSize = 36, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 63, Outline = 3 })
	-- turntable: glowing ellipse under the car
	local disc = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(350, 352), Size = UDim2.fromOffset(470, 90), BackgroundColor3 = P.yellow, BorderSizePixel = 0, ZIndex = 61 }, box)
	corner(disc, 200)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.5, 0.25), NumberSequenceKeypoint.new(1, 0.9) }) }, disc)
	local ring = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(350, 352), Size = UDim2.fromOffset(420, 70), BackgroundTransparency = 1, ZIndex = 61 }, box)
	corner(ring, 200)
	local ringStroke = stroke(ring, P.white, 4)
	local vpHolder = new("Frame", { Position = UDim2.fromOffset(40, 106), Size = UDim2.fromOffset(620, 300), BackgroundTransparency = 1, ZIndex = 62 }, box)
	local name = text(box, { Text = "", TextSize = 64, Position = UDim2.fromOffset(0, 410), Size = UDim2.new(1, 0, 0, 70), TextXAlignment = Enum.TextXAlignment.Center, Outline = 4, ZIndex = 62 })
	local info = text(box, { Text = "", Font = BODY, TextSize = 24, Position = UDim2.fromOffset(0, 482), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center, RichText = true, ZIndex = 62 })
	local stamp = text(box, { Text = "NEW!", TextSize = 46, TextColor3 = P.yellow, Rotation = -14, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(600, 120), Size = UDim2.fromOffset(160, 60), TextXAlignment = Enum.TextXAlignment.Center, Outline = 4, ZIndex = 64, Visible = false })
	local ok = toy(box, { Text = T("btn_awesome"), Color = P.green, Size = UDim2.fromOffset(300, 86), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), ZIndex = 63,
		OnClick = function() UI.HideReveal() end })
	panels.reveal = { root = r, rays = rays, box = box, sc = sc, top = top, badgeGrad = badgeGrad, rarity = rarity, vpHolder = vpHolder, name = name, info = info, ok = ok,
		glow = glow, glowGrad = glowGrad, disc = disc, ringStroke = ringStroke, streaks = streaks, sparks = sparks, stamp = stamp }
	r.Activated:Connect(function()
		if os.clock() - (panels.reveal.shownAt or 0) > 0.8 then -- ignore the tap that was still meant for the throw
			UI.HideReveal()
		end
	end)
end

function UI.HideReveal()
	local rv = panels.reveal
	if rv.root.Visible then
		rv.root.Visible = false
		if rv.conn then
			rv.conn:Disconnect()
			rv.conn = nil
		end
		if rv.blur then
			rv.blur:Destroy()
			rv.blur = nil
		end
		local cb = rv.onClosed
		rv.onClosed = nil
		if cb then
			cb()
		end
	end
end

function UI.ShowReveal(res, onClosed)
	local rv = panels.reveal
	rv.onClosed = onClosed
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
	rv.glow.BackgroundColor3 = rc
	rv.disc.BackgroundColor3 = rc
	rv.ringStroke.Color = lift(rc, 0.4)
	rv.stamp.Visible = res.isNew == true
	for _, sp in ipairs(rv.sparks) do
		sp.f.BackgroundColor3 = math.random() < 0.5 and rc or C(255, 255, 255)
	end
	clear(rv.vpHolder)
	local vp, model = carViewport(rv.vpHolder, def, { Size = UDim2.fromScale(1, 1), ZIndex = 62 })
	if not rv.blur then
		rv.blur = new("BlurEffect", { Name = "RevealBlur", Size = 0 }, game:GetService("Lighting"))
		tween(rv.blur, 0.35, { Size = 22 })
	end
	rv.root.Visible = true
	rv.shownAt = os.clock()
	rv.sc.Scale = 0.2
	tween(rv.sc, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	UI.Sfx("fanfare")
	local lvl = CarConfig.Rarities[res.rarity].index
	local t0 = os.clock()
	if rv.conn then
		rv.conn:Disconnect()
	end
	rv.conn = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - t0
		rv.rays.Rotation = t * (18 + lvl * 4)
		rv.glow.Size = UDim2.fromScale(1.3 + math.sin(t * 2) * 0.05, 1.3 + math.sin(t * 2) * 0.05)
		for k, st in ipairs(rv.streaks) do
			local ph = ((t * (0.35 + k * 0.12)) + k * 0.33) % 1.6 - 0.3
			st.Position = UDim2.fromScale(ph, 0.25 + k * 0.18)
		end
		for _, sp in ipairs(rv.sparks) do
			sp.y = sp.y - sp.v * dt * (1 + lvl * 0.3)
			if sp.y < -0.05 then
				sp.y, sp.x = 1.05, math.random()
			end
			sp.f.Position = UDim2.fromScale(sp.x + math.sin(t + sp.s) * 0.01, sp.y)
			sp.f.Size = UDim2.fromOffset(sp.s, sp.s)
			sp.f.BackgroundTransparency = 0.2 + 0.6 * math.abs(math.sin(t * 3 + sp.s))
		end
		rv.stamp.Rotation = -14 + math.sin(t * 4) * 4
		if model.Parent then
			fitCamera(vp, model, math.rad(35) + t * 0.9)
		end
	end)
end

---------------------------------------------------------------- refresh
local function refreshHud()
	local st = store.State
	hud.money.Text = "$" .. Util.FormatNumber(store.Money)
	hud.income.Text = "+" .. Util.FormatNumber(store.Income) .. " / sec"
	local carried = store.CarriedTotal()
	hud.bag.Visible = carried > 0
	if carried > 0 then
		local cap = st.carryCap or EconomyConfig.CarryCapacity
		local risk = st.run and st.run.risk or 1
		hud.bagText.Text = string.format("CARRYING  %d / %d", carried, cap) .. (risk > 1 and string.format("   RISK x%s", risk) or "")
		hud.bagFill.Size = UDim2.fromScale(math.clamp(carried / cap, 0, 1), 1)
	end
	hud.throw.holder.Visible = state.nearTrap and state.open == nil
	-- "can unlock" dot on TELEPORT
	local dot = false
	for i, zid in ipairs(MapConfig.ZoneOrder) do
		local req = EconomyConfig.ZoneUnlock[zid]
		if req and (req.rebirths or 0) <= (st.rebirths or 0) and not st.zones[zid] and st.zones[MapConfig.ZoneOrder[i - 1]] and store.Money >= req.cost and store.CollectionValue >= req.minValue then
			dot = true
		end
	end
	hud.newDot.Visible = dot
	hud.canUnlock = dot
end

-- the single next goal after the tutorial: { title, body } (shown by Tutorial's objective card)
local function refreshHint()
	local st = store.State
	local goal
	if store.CarriedTotal() > 0 then
		goal = { "BANK YOUR LOOT", "Run home to the plaza, or reach the district CHECKPOINT to save it" }
	elseif store.BankedTotal() > 0 and state.nearTrap then
		goal = { "THROW YOUR PARTS", "Press THROW and pick how many of each part" }
	end
	-- (v13: no "unlock the next district" card after the tutorial - the tutorial asks for the Highway once)
	hud.nextGoal = goal
	hud.hintFrame.Visible = false
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
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	end)
	root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
	local uiScale = new("UIScale", {}, root)
	-- above the Cine layer (45), same scale as the HUD: nothing of a pop-up can fall off a phone screen
	overlay = new("Frame", { Name = "Overlay", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 60 }, gui)
	local ovScale = new("UIScale", {}, overlay)
	local function rescale()
		local vp = gui.AbsoluteSize.Magnitude > 0 and gui.AbsoluteSize or (Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize) or Vector2.new(1280, 720)
		local s = math.clamp(math.min(vp.Y / 760, vp.X / 1240), 0.5, 1.2)
		uiScale.Scale, ovScale.Scale = s, s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
		overlay.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	rescale()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
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
		step = { "rbxasset://sounds/electronicpingshort.wav", 0.18, 1.6 }, -- tutorial step: soft and short
	}
	for name, fb in pairs(FALLBACK) do
		local id = SoundIds[name]
		if id and id > 0 then
			makeSound(name, "rbxassetid://" .. id, name == "step" and 0.35 or fb[2] + 0.15, 1)
		else
			makeSound(name, fb[1], fb[2], fb[3])
		end
	end
	if SoundIds.ambience and SoundIds.ambience > 0 then
		local amb = new("Sound", { Name = "Ambience", SoundId = "rbxassetid://" .. SoundIds.ambience, Volume = 0.25, Looped = true, SoundGroup = UI.MusicGroup }, SoundService)
		amb:Play()
	end
	-- relaxing background music (ElevenLabs), looped; its volume is the Music slider (Settings)
	if SoundIds.music and SoundIds.music > 0 then
		local music = new("Sound", { Name = "Music", SoundId = "rbxassetid://" .. SoundIds.music, Volume = 0.6, Looped = true, SoundGroup = UI.MusicGroup }, SoundService)
		music:Play()
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
		P = P, HEAD = HEAD, BODY = BODY, root = root, gui = gui, overlay = overlay, hud = hud, panels = panels, state = state, store = store,
		actions = actions, PART_ICON = PART_ICON, confirm = UI.Confirm,
	}
end

return UI
