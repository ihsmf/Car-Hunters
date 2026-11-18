-- HUD + panels, laid out from the Figma file "Billiard Hunters — UI" (frames "… v3", 1920x1080, scaled to screen).
-- Dark panels and cards with light text; the coloured cartoon buttons stay as they are.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.Shared.Config)
local MeshBuilder = require(RS.Shared.MeshBuilder)
local U = C.UI
local plr = Players.LocalPlayer
local WHITE, INK = Color3.new(1, 1, 1), U.Ink
local rgb = Color3.fromRGB
local GREEN, ORANGE, PURPLE = { rgb(157, 245, 154), rgb(62, 193, 90) }, { rgb(255, 196, 138), rgb(255, 138, 61) }, { rgb(230, 166, 255), rgb(164, 92, 255) }
local GREY = { rgb(205, 198, 214), rgb(170, 162, 182) }
local CREAM = { rgb(255, 251, 242), rgb(255, 236, 206) } -- panel body
local MUTED, MONEY = rgb(118, 100, 138), rgb(40, 160, 70)

-- ===== Sound =====
local groups, sounds = {}, {}
for _, n in { "Music", "SFX" } do
	local g = Instance.new("SoundGroup")
	g.Name, g.Volume, g.Parent = n, 0.5, SoundService
	groups[n] = g
end
for k, id in C.Sounds do
	local s = Instance.new("Sound")
	s.SoundId, s.SoundGroup, s.Parent = id, k == "Music" and groups.Music or groups.SFX, SoundService
	sounds[k] = s
end
sounds.Music.Looped = true
sounds.Music:Play()
_G.PlaySfx = function(k)
	if sounds[k] and k ~= "Music" then sounds[k]:Play() end
end

-- ===== Building blocks =====
local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in props do
		if k ~= "Parent" then o[k] = v end
	end
	for _, c in children or {} do c.Parent = o end
	if props.Parent then o.Parent = props.Parent end
	return o
end
local function corner(px) return new("UICorner", { CornerRadius = UDim.new(0, px) }) end
local function stroke(t, color) return new("UIStroke", { Color = color or INK, Thickness = t, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function grad(a, b) return new("UIGradient", { Rotation = 90, Color = ColorSequence.new(a, b) }) end
local function tween(o, t, props, style) TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad), props):Play() end

local function text(str, size, color, props)
	props = props or {}
	props.BackgroundTransparency, props.FontFace, props.Text = 1, U.Font, str
	props.TextSize, props.TextColor3 = size, color or WHITE
	props.Size = props.Size or UDim2.new(1, 0, 0, size * 1.25)
	local outline = props.NoStroke
	props.NoStroke = nil
	local l = new("TextLabel", props)
	if not outline then new("UIStroke", { Color = INK, Thickness = math.max(2, size / 11), Parent = l }) end
	return l
end

-- cartoon box: gradient body, outline, hard shadow 6 px below
local function box(props, top, bottom, radius, strokeW, strokeColor)
	local holder = new("Frame", { Size = props.Size, Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, BackgroundTransparency = 1, LayoutOrder = props.LayoutOrder or 0, Name = props.Name or "Box", ZIndex = props.ZIndex or 1, Parent = props.Parent })
	new("Frame", { Name = "Shadow", Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, strokeW == 0 and 0 or 6), BackgroundColor3 = INK, BackgroundTransparency = strokeW == 0 and 1 or 0, Parent = holder }, { corner(radius) })
	local body = new("Frame", { Name = "Body", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = holder }, { corner(radius), grad(top, bottom) })
	if strokeW ~= 0 then stroke(strokeW or 4, strokeColor).Parent = body end
	return holder, body
end
-- white cartoon card inside a panel: ink outline, soft cream gradient
local function card(props, radius, color)
	local f = new("Frame", { Size = props.Size, Position = props.Position or UDim2.new(), LayoutOrder = props.LayoutOrder or 0, BackgroundColor3 = WHITE, Name = props.Name or "Card", Parent = props.Parent }, {
		corner(radius or 20), stroke(3), grad(color or WHITE, (color or WHITE):Lerp(CREAM[2], 0.5)),
	})
	return f
end

-- button with hover/press bounce; returns holder, body, label, setEnabled(on, colors?)
local function button(props, colors, label, size, onClick)
	local holder, body = box(props, colors[1], colors[2], props.Radius or 18, 3)
	local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5, Parent = holder })
	local scale = new("UIScale", { Parent = holder })
	local big = math.floor((size or 24) * 1.35) -- large, readable button text; shrinks only if the label is long
	local lbl = text(label or "", big, nil, { Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), Parent = body, TextScaled = true })
	new("UITextSizeConstraint", { MaxTextSize = big, Parent = lbl })
	local enabled = true
	hit.MouseEnter:Connect(function() if enabled then tween(scale, 0.15, { Scale = 1.06 }, Enum.EasingStyle.Back) end end)
	hit.MouseLeave:Connect(function() tween(scale, 0.15, { Scale = 1 }) end)
	hit.Activated:Connect(function()
		if not enabled then return end
		_G.PlaySfx("Click")
		scale.Scale = 0.88
		tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		if onClick then onClick() end
	end)
	local function setEnabled(on, cols)
		enabled = on
		local c = on and (cols or colors) or GREY
		body.UIGradient.Color = ColorSequence.new(c[1], c[2])
	end
	return holder, body, lbl, setEnabled, hit
end

-- progress bar: returns frame, set(fraction, colour?)
local function bar(parent, pos, size, color)
	local f = new("Frame", { Position = pos, Size = size, BackgroundColor3 = rgb(230, 220, 205), Parent = parent }, { corner(math.floor(size.Y.Offset / 2)), stroke(2) })
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color or GREEN[2], Parent = f }, { corner(math.floor(size.Y.Offset / 2)) })
	return f, function(v, c)
		fill.Size = UDim2.fromScale(math.clamp(v, 0, 1), 1)
		if c then fill.BackgroundColor3 = c end
	end
end

-- 3D preview of a Blender model inside a ViewportFrame (cached MeshParts are re-parented, never rebuilt)
local previewCache = {}
local function viewport(parent, props, mesh, overrides, key, camCF)
	local vp = new("ViewportFrame", { Size = props.Size, Position = props.Position or UDim2.new(), BackgroundTransparency = 1, Ambient = rgb(200, 195, 215), LightColor = WHITE, LightDirection = Vector3.new(-1, -1, -0.6), Parent = parent })
	local part = previewCache[key]
	if not part then
		part = MeshBuilder.Create(mesh, CFrame.new(), overrides)
		if not part then -- no EditableMesh: a simple stand-in shape
			local size = mesh == "Cue" and Vector3.new(0.3, 9.2, 0.3) or mesh == "PrizeBall" and Vector3.one or Vector3.new(5.2, 2.3, 2.3)
			part = new("Part", { Size = size, Shape = mesh == "PrizeBall" and Enum.PartType.Ball or Enum.PartType.Block, Color = overrides and (overrides.Shaft or overrides.Plate or overrides.Body) or WHITE, Anchored = true })
		end
		previewCache[key] = part
	end
	part.Parent = vp
	local cam = new("Camera", { FieldOfView = 30, CFrame = camCF, Parent = vp })
	vp.CurrentCamera = cam
	return vp
end
local function releasePreviews()
	for _, p in previewCache do p.Parent = nil end
end

-- ===== Root (design space 1920x1080) =====
local gui = new("ScreenGui", { Name = "Main", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = plr:WaitForChild("PlayerGui") })
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets -- stay clear of notches and the Roblox top bar
local root = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
local hud = new("Frame", { Name = "HUD", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = root })
-- Every HUD block is laid out in 1920x1080 design pixels inside its own frame, anchored to a screen edge and scaled
-- by the same factor: on any aspect ratio the menu hugs the left edge, SHOOT the bottom, the stats the top.
local scales = {}
local function group(name, size, anchor, pos, parent)
	local f = new("Frame", { Name = name, Size = UDim2.fromOffset(size.X, size.Y), AnchorPoint = anchor, Position = pos, BackgroundTransparency = 1, Parent = parent or hud })
	table.insert(scales, new("UIScale", { Parent = f }))
	return f
end
local topBar = group("Top", Vector2.new(920, 110), Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 8))
local leftBar = group("Left", Vector2.new(150, 600), Vector2.new(0, 0.5), UDim2.new(0, 12, 0.5, 0))
local shotBar = group("Shot", Vector2.new(640, 280), Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -6))
local cornerBar = group("Corner", Vector2.new(460, 230), Vector2.new(1, 1), UDim2.new(1, -12, 1, -12))
local center = group("Panels", Vector2.new(980, 690), Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.52), root)
local function rescale()
	local v = workspace.CurrentCamera.ViewportSize
	local k = math.clamp(math.min(v.X / 1920, v.Y / 1080), 0.4, 1.4) -- phones get slightly bigger buttons than pure fit
	for _, sc in scales do sc.Scale = k end
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()

local Remotes = RS:WaitForChild("Remotes")
local Request, Fx = Remotes:WaitForChild("Request"), Remotes:WaitForChild("Fx")
local state

-- ===== Toast stack (under the top bar, never over it) =====
local toastStack = new("Frame", { Size = UDim2.fromOffset(700, 200), Position = UDim2.fromOffset(460, 120), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, ZIndex = 30, Parent = topBar }, {
	new("UIListLayout", { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})
local toastN = 0
local function toast(msg, color)
	toastN += 1
	local items = {}
	for _, c in toastStack:GetChildren() do
		if c:IsA("Frame") then table.insert(items, c) end
	end
	if #items >= 3 then items[1]:Destroy() end
	local holder, body = box({ Size = UDim2.fromOffset(580, 60), LayoutOrder = toastN, Parent = toastStack }, CREAM[1], CREAM[2], 30, 4)
	text(msg, 30, color or U.Title, { Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), Parent = body, TextScaled = false })
	local sc = new("UIScale", { Scale = 0.5, Parent = holder })
	tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(2.6, function()
		tween(sc, 0.25, { Scale = 0 })
		task.wait(0.27)
		holder:Destroy()
	end)
end
_G.Toast = toast

local function call(action, arg)
	local ok, msg = Request:InvokeServer(action, arg)
	if msg then
		toast(msg, ok and U.Title or U.Bad)
		_G.PlaySfx(ok and "Reward" or "Click")
	end
	return ok
end

-- ===== HUD =====
-- top bar: cash (+income) | strength | luck at the start of a shot
local function pill(x, w, colors, label)
	local holder, body = box({ Size = UDim2.fromOffset(w, 90), Position = UDim2.fromOffset(x - 500, 4), Parent = topBar }, colors[1], colors[2], 45, 4)
	text(label, 18, WHITE, { Size = UDim2.fromOffset(w, 22), Position = UDim2.fromOffset(0, 8), Parent = body, NoStroke = true, TextTransparency = 0.15 })
	return holder, body
end
local _, cashBody = pill(500, 400, GREEN, "CASH")
local cashLabel = text("$0", 40, nil, { Size = UDim2.fromOffset(230, 50), Position = UDim2.fromOffset(22, 28), Parent = cashBody, TextXAlignment = Enum.TextXAlignment.Left })
local incomeLabel = text("+$0/s", 24, nil, { Size = UDim2.fromOffset(140, 50), Position = UDim2.fromOffset(240, 28), Parent = cashBody, TextXAlignment = Enum.TextXAlignment.Right })
local strHolder, strBody = pill(920, 220, ORANGE, "STRENGTH")
local strLabel = text("0", 40, nil, { Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 28), Parent = strBody })
local strScale = new("UIScale", { Parent = strHolder })
local _, luckBody = pill(1160, 260, PURPLE, "START LUCK")
local luckLabel = text("1.00X", 40, nil, { Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 28), Parent = luckBody })

-- left menu with badges
local menu = new("Frame", { Size = UDim2.fromOffset(150, 600), BackgroundTransparency = 1, Parent = leftBar }, {
	new("UIListLayout", { Padding = UDim.new(0, 20), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local badges = {}
local open -- forward

-- shot area: live preview, power bar, SHOOT
local previewHolder, previewBody = box({ Size = UDim2.fromOffset(460, 56), Position = UDim2.fromOffset(320, 0), AnchorPoint = Vector2.new(0.5, 0), Parent = shotBar }, rgb(255, 227, 138), rgb(255, 184, 48), 28, 3)
local previewLabel = text("TABLE 1", 32, nil, { Size = UDim2.fromScale(1, 1), Parent = previewBody })
local powerFrame = new("Frame", { Size = UDim2.fromOffset(640, 44), Position = UDim2.fromOffset(0, 66), BackgroundColor3 = INK, Parent = shotBar }, { corner(22), stroke(4) })
local powerFill = new("Frame", { Size = UDim2.new(0, 0, 1, -12), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = WHITE, Parent = powerFrame }, {
	corner(16), new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(90, 220, 90)), ColorSequenceKeypoint.new(0.6, rgb(255, 220, 40)), ColorSequenceKeypoint.new(1, rgb(255, 60, 60)) }) }),
})
local _, _, shootLabel, setShootEnabled, shootHit = button({ Size = UDim2.fromOffset(380, 116), Position = UDim2.fromOffset(130, 122), Parent = shotBar, Radius = 44 }, U.Red, "SHOOT", 56)
local hint = text("Hold to charge, release to shoot", 24, nil, { Size = UDim2.fromOffset(640, 30), Position = UDim2.fromOffset(0, 248), Parent = shotBar })

-- training context button (shown at the gym and while training)
local trainHolder, _, trainLabel = button({ Size = UDim2.fromOffset(320, 96), Position = UDim2.fromOffset(140, 134), Parent = cornerBar, Radius = 32 }, GREEN, "START TRAINING", 30, function()
	if state then call(state.training and "TrainStop" or "TrainStart") end
end)
trainHolder.Visible = false

-- onboarding bubble
local tipHolder, tipBody = box({ Size = UDim2.fromOffset(460, 110), Position = UDim2.fromOffset(0, 0), Parent = cornerBar }, CREAM[1], CREAM[2], 26, 4)
local tipText = text("", 26, INK, { Size = UDim2.new(1, -40, 0, 56), Position = UDim2.fromOffset(20, 10), Parent = tipBody, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
local tipStep = text("", 22, PURPLE[2], { Size = UDim2.new(1, -40, 0, 24), Position = UDim2.fromOffset(20, 66), Parent = tipBody, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
tipHolder.Visible = false

-- ===== Panels =====
local panels, renderers = {}, {}
local function panel(key, title, colors)
	local holder, body = box({ Size = UDim2.fromOffset(980, 680), Position = UDim2.fromOffset(490, 345), AnchorPoint = Vector2.new(0.5, 0.5), Parent = center, Name = key, ZIndex = 10 }, CREAM[1], CREAM[2], 40, 6)
	holder.Visible = false
	-- title ribbon in the colour of the menu button, a light stripe of polka dots for a playful touch
	local _, ribbon = box({ Size = UDim2.new(1, 24, 0, 92), Position = UDim2.fromOffset(-12, -28), Parent = body }, colors[1], colors[2], 30, 5)
	for k = 0, 9 do
		new("Frame", { Size = UDim2.fromOffset(14, 14), Position = UDim2.new(0, 330 + k * 46, 0, k % 2 == 0 and 16 or 58), BackgroundColor3 = WHITE, BackgroundTransparency = 0.7, Parent = ribbon }, { corner(7) })
	end
	text(title, 56, WHITE, { Size = UDim2.new(1, -160, 1, 0), Position = UDim2.fromOffset(34, 0), Parent = ribbon, TextXAlignment = Enum.TextXAlignment.Left })
	local sub = text("", 26, MUTED, { Size = UDim2.new(1, -80, 0, 30), Position = UDim2.fromOffset(40, 80), Parent = body, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
	button({ Size = UDim2.fromOffset(74, 68), Position = UDim2.fromOffset(900, -16), Parent = body, Radius = 24 }, U.Red, "X", 34, function() holder.Visible = false end)
	local content = new("Frame", { Size = UDim2.fromOffset(900, 530), Position = UDim2.fromOffset(40, 130), BackgroundTransparency = 1, Parent = body })
	panels[key] = { holder = holder, content = content, sub = sub }
end
local function clear(f)
	releasePreviews()
	for _, c in f:GetChildren() do c:Destroy() end
end
local function scroller(parent, pos, size, cell, pad)
	return new("ScrollingFrame", {
		Position = pos, Size = size, BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8, ScrollBarImageColor3 = INK,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = parent,
	}, {
		new("UIGridLayout", { CellSize = cell, CellPadding = UDim2.fromOffset(pad, pad), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }),
	})
end

function open(key, force)
	if not state then return end
	local p = panels[key]
	local show = force or not p.holder.Visible
	for _, q in panels do q.holder.Visible = false end
	if not show then return end
	p.holder.Visible = true
	renderers[key]()
	local sc = p.holder:FindFirstChild("Pop") or new("UIScale", { Name = "Pop", Parent = p.holder })
	sc.Scale = 0.6
	tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end
local function rerender() -- Settings is not rebuilt from server updates (it would interrupt a slider drag)
	for k, p in panels do
		if p.holder.Visible and k ~= "Settings" then renderers[k]() end
	end
end

-- --- Inventory ---
local BALL_CAM = CFrame.lookAt(Vector3.new(0, 0.6, 3.4), Vector3.zero)
panel("Inventory", "Inventory", { U.Menu[2][4], U.Menu[2][5] })
local sortMode = "best"
local TOTAL = #C.Balls * #C.Variants
local function sellDialog()
	local p = panels.Inventory
	local counts = {}
	for _, it in state.d.inv do
		if not it.eq and (it.v or 1) < 4 then
			local r = it.id
			counts[r] = counts[r] or { n = 0, cash = 0 }
			counts[r].n += 1
			counts[r].cash += C.ItemIncome(it) * 30
		end
	end
	local holder, body = box({ Size = UDim2.fromOffset(580, 500), Position = UDim2.fromOffset(450, 260), AnchorPoint = Vector2.new(0.5, 0.5), Parent = p.content, ZIndex = 20 }, CREAM[1], CREAM[2], 30, 5)
	text("Sell unequipped", 36, INK, { Size = UDim2.new(1, -100, 0, 50), Position = UDim2.fromOffset(24, 12), Parent = body, TextXAlignment = Enum.TextXAlignment.Left })
	text("Gold, Diamond, Galaxy and Rainbow are kept", 20, MUTED, { Size = UDim2.new(1, -100, 0, 24), Position = UDim2.fromOffset(26, 60), Parent = body, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
	button({ Size = UDim2.fromOffset(56, 50), Position = UDim2.fromOffset(504, 16), Parent = body, Radius = 18 }, U.Red, "X", 26, function() holder:Destroy() end)
	local list = new("ScrollingFrame", { Size = UDim2.fromOffset(540, 390), Position = UDim2.fromOffset(20, 96), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8, ScrollBarImageColor3 = INK, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = body }, {
		new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingRight = UDim.new(0, 10) }),
	})
	local any = false
	for r = 1, #C.Rarities do
		local c = counts[r]
		if c then
			any = true
			local rar = C.Rarities[r]
			local row = card({ Size = UDim2.new(1, 0, 0, 60), LayoutOrder = r, Parent = list }, 16)
			new("Frame", { Size = UDim2.fromOffset(10, 40), Position = UDim2.fromOffset(12, 10), BackgroundColor3 = rar[2], Parent = row }, { corner(5) })
			text(rar[1] .. "  x" .. c.n, 26, INK, { Size = UDim2.fromOffset(260, 60), Position = UDim2.fromOffset(34, 0), Parent = row, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
			button({ Size = UDim2.fromOffset(200, 46), Position = UDim2.fromOffset(310, 7), Parent = row, Radius = 16 }, U.Action, "Sell $" .. C.Short(c.cash), 22, function()
				if call("SellRarity", r) then
					holder:Destroy()
					renderers.Inventory()
				end
			end)
		end
	end
	if not any then text("Nothing to sell: every ball is on your table.", 24, MUTED, { Size = UDim2.new(1, 0, 0, 80), Parent = list, TextWrapped = true, NoStroke = true }) end
end
renderers.Inventory = function()
	local p = panels.Inventory
	clear(p.content)
	local d = state.d
	local on, found = 0, 0
	for _, it in d.inv do
		if it.eq then on += 1 end
	end
	for _ in d.found or {} do found += 1 end
	p.sub.Text = string.format("%d / %d balls   %d / %d on the table   %d / %d found", #d.inv, C.MaxInventory, on, C.MaxEquipped, found, TOTAL)
	local _, setCap = bar(p.content, UDim2.fromOffset(0, 4), UDim2.fromOffset(470, 14))
	setCap(#d.inv / C.MaxInventory, #d.inv >= C.MaxInventory * 0.9 and U.Bad or GREEN[2])
	button({ Size = UDim2.fromOffset(160, 46), Position = UDim2.fromOffset(500, -12), Parent = p.content }, GREEN, "Equip best", 22, function()
		if call("EquipBest") then renderers.Inventory() end
	end)
	button({ Size = UDim2.fromOffset(110, 46), Position = UDim2.fromOffset(672, -12), Parent = p.content }, U.Action, "Sell", 22, sellDialog)
	button({ Size = UDim2.fromOffset(106, 46), Position = UDim2.fromOffset(794, -12), Parent = p.content }, U.Cues, sortMode == "best" and "Best" or "New", 22, function()
		sortMode = sortMode == "best" and "new" or "best"
		renderers.Inventory()
	end)
	local list = scroller(p.content, UDim2.fromOffset(0, 46), UDim2.fromOffset(900, 484), UDim2.fromOffset(285, 250), 16)
	if #d.inv == 0 then
		text("No balls yet.\nHold SHOOT to win your first ball.", 30, MUTED, { Size = UDim2.fromOffset(880, 160), Parent = list, TextWrapped = true, NoStroke = true })
		list.UIGridLayout.CellSize = UDim2.fromOffset(880, 160)
		return
	end
	local rank = {}
	for i in d.inv do table.insert(rank, i) end
	table.sort(rank, function(x, y)
		if sortMode == "new" then return x > y end
		return C.ItemIncome(d.inv[x]) > C.ItemIncome(d.inv[y])
	end)
	for order, i in rank do
		local it = d.inv[i]
		local ch = C.Balls[it.id]
		local rar = C.Rarities[ch.rarity]
		local V = C.Variants[it.v or 1]
		local inc = C.ItemIncome(it)
		local c = card({ Size = UDim2.fromOffset(285, 250), LayoutOrder = order, Parent = list }, 22)
		local ribbon = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = rar[2], Parent = c }, { corner(20) })
		new("Frame", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 20), BackgroundColor3 = rar[2], BorderSizePixel = 0, Parent = ribbon })
		text(string.upper(rar[1]), 24, nil, { Size = UDim2.fromScale(1, 1), Parent = ribbon })
		viewport(c, { Size = UDim2.fromOffset(96, 96), Position = UDim2.fromOffset(10, 46) }, "PrizeBall", C.BallOverrides(it), "ball" .. it.id .. "_" .. (it.v or 1), BALL_CAM)
		if V.mult > 1 then -- variant badge
			local vb = new("Frame", { Size = UDim2.fromOffset(150, 30), Position = UDim2.fromOffset(118, 50), BackgroundColor3 = V.color or ORANGE[2], Parent = c }, { corner(15), stroke(2) })
			text(string.upper(V.name) .. " x" .. V.mult, 20, nil, { Size = UDim2.fromScale(1, 1), Parent = vb })
		end
		text(ch.name, 28, INK, { Size = UDim2.fromOffset(160, 30), Position = UDim2.fromOffset(114, 84), Parent = c, TextScaled = true, NoStroke = true, TextXAlignment = Enum.TextXAlignment.Left })
		text("$" .. C.Short(inc) .. "/s", 26, MONEY, { Size = UDim2.fromOffset(160, 30), Position = UDim2.fromOffset(114, 114), Parent = c, NoStroke = true, TextXAlignment = Enum.TextXAlignment.Left })
		button({ Size = UDim2.fromOffset(150, 52), Position = UDim2.fromOffset(14, 180), Parent = c, Radius = 18 }, it.eq and U.Red or GREEN, it.eq and "Remove" or "Place", 22, function()
			if call("Equip", i) then renderers.Inventory() end
		end)
		button({ Size = UDim2.fromOffset(98, 52), Position = UDim2.fromOffset(174, 180), Parent = c, Radius = 18 }, U.Action, "Sell", 22, function()
			if call("Sell", i) then renderers.Inventory() end
		end)
		if it.eq then text("ON TABLE", 18, MONEY, { Size = UDim2.fromOffset(160, 24), Position = UDim2.fromOffset(114, 146), Parent = c, NoStroke = true, TextXAlignment = Enum.TextXAlignment.Left }) end
	end
end

-- --- Bonuses ---
panel("Bonus", "Bonuses", { U.Menu[3][4], U.Menu[3][5] })
local bonusTick
renderers.Bonus = function()
	local p = panels.Bonus
	clear(p.content)
	p.sub.Text = "Log in every day for a bigger streak, stay to earn playtime gifts"
	local day = os.time() // 86400
	local dd = state.d.daily
	local claimedToday = dd.day == day
	local streak = (dd.day == day or dd.day == day - 1) and dd.streak or 0
	local today = claimedToday and streak or streak % #C.Daily + 1
	for k = 1, #C.Daily do
		local done = k < today or (claimedToday and k == today)
		local isToday = k == today and not claimedToday
		local tile = card({ Size = UDim2.fromOffset(118, 150), Position = UDim2.fromOffset((k - 1) * 130, 0), Parent = p.content }, 20, isToday and rgb(255, 236, 170) or done and rgb(220, 248, 214) or WHITE)
		if isToday then tile.UIStroke.Thickness = 5 end
		text("Day " .. k, 24, done and MUTED or INK, { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 14), Parent = tile, NoStroke = true })
		text("$" .. C.Short(C.Daily[k]), 32, done and MUTED or MONEY, { Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 56), Parent = tile, NoStroke = true })
		text(done and "Claimed" or isToday and "Today" or "", 22, done and MONEY or ORANGE[2], { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 106), Parent = tile, NoStroke = true })
	end
	local _, _, _, setDailyBtn = button({ Size = UDim2.fromOffset(320, 64), Position = UDim2.fromOffset(290, 172), Parent = p.content, Radius = 24 }, { rgb(255, 158, 200), rgb(255, 92, 158) },
		claimedToday and "Come back tomorrow" or "Claim day " .. today, 28, function()
			if not claimedToday and call("Daily") then renderers.Bonus() end
		end)
	setDailyBtn(not claimedToday)
	local rows = {}
	for i, pt in C.Playtime do
		local y = 266 + (i - 1) * 64
		local row = card({ Size = UDim2.fromOffset(900, 54), Position = UDim2.fromOffset(0, y), Parent = p.content }, 16)
		text(pt[1] .. " min", 24, INK, { Size = UDim2.fromOffset(160, 54), Position = UDim2.fromOffset(20, 0), Parent = row, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
		local _, setBar = bar(row, UDim2.fromOffset(180, 19), UDim2.fromOffset(460, 16))
		text("$" .. C.Short(pt[2]), 24, MONEY, { Size = UDim2.fromOffset(110, 54), Position = UDim2.fromOffset(652, 0), Parent = row, NoStroke = true })
		local _, _, lbl, setBtn = button({ Size = UDim2.fromOffset(120, 42), Position = UDim2.fromOffset(770, 6), Parent = row, Radius = 16 }, GREEN, "Claim", 22, function()
			if call("Playtime", i) then renderers.Bonus() end
		end)
		rows[i] = { setBar = setBar, lbl = lbl, setBtn = setBtn }
	end
	bonusTick = function()
		for i, pt in C.Playtime do
			local left = pt[1] * 60 - (os.time() - state.join)
			local r = rows[i]
			r.setBar(1 - math.max(left, 0) / (pt[1] * 60), left <= 0 and GREEN[2] or ORANGE[2])
			if state.claimed[i] then
				r.lbl.Text = "Done"
				r.setBtn(false)
			elseif left > 0 then
				r.lbl.Text = string.format("%d:%02d", left // 60, left % 60)
				r.setBtn(false)
			else
				r.lbl.Text = "Claim"
				r.setBtn(true)
			end
		end
	end
	bonusTick()
end

-- --- Donate shop ---
panel("Shop", "Shop", { U.Menu[4][4], U.Menu[4][5] })
renderers.Shop = function()
	local p = panels.Shop
	clear(p.content)
	p.sub.Text = "Game Passes and cash packs"
	local list = new("ScrollingFrame", { Size = UDim2.fromOffset(900, 530), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8, ScrollBarImageColor3 = INK, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = p.content })
	local y = 0
	for i, gp in C.GamePasses do
		local owned = state.passes[gp.key]
		local x = ((i - 1) % 2) * 450
		y = ((i - 1) // 2) * 150
		local c = card({ Size = UDim2.fromOffset(436, 136), Position = UDim2.fromOffset(x, y), Parent = list }, 22)
		local disc = new("Frame", { Size = UDim2.fromOffset(96, 96), Position = UDim2.fromOffset(18, 20), BackgroundColor3 = WHITE, Parent = c }, { corner(48), grad(rgb(255, 227, 138), rgb(255, 174, 31)), stroke(3) })
		text(gp.badge, 32, nil, { Size = UDim2.fromScale(1, 1), Parent = disc })
		text(gp.name, 30, INK, { Size = UDim2.fromOffset(300, 40), Position = UDim2.fromOffset(130, 12), Parent = c, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
		text(gp.desc, 19, MUTED, { Size = UDim2.fromOffset(290, 40), Position = UDim2.fromOffset(130, 48), Parent = c, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, NoStroke = true })
		local _, _, _, setBtn = button({ Size = UDim2.fromOffset(160, 40), Position = UDim2.fromOffset(130, 88), Parent = c, Radius = 14 }, U.Red, owned and "Owned" or "Buy", 22, function()
			if not owned then call("Pass", gp.key) end
		end)
		setBtn(not owned)
	end
	y += 160
	text("Cash packs", 30, INK, { Size = UDim2.fromOffset(400, 40), Position = UDim2.fromOffset(0, y), Parent = list, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
	for i, pr in C.Products do
		local c = card({ Size = UDim2.fromOffset(286, 130), Position = UDim2.fromOffset((i - 1) * 302, y + 48), Parent = list }, 22)
		text("$" .. C.Short(pr.cash), 40, MONEY, { Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 8), Parent = c })
		button({ Size = UDim2.fromOffset(170, 42), Position = UDim2.fromOffset(58, 74), Parent = c, Radius = 14 }, U.Red, "Buy", 22, function() call("Product", i) end)
	end
end

-- --- Cue shop (opened at the kiosk): every cue in one horizontal list ---
panel("Cues", "Cue Shop", U.Cues)
local function cueOverrides(def)
	local o = {}
	for slot, field in C.CueParts do o[slot] = def[field] end
	return o
end
local CUE_CAM = CFrame.lookAt(Vector3.new(11, 0, 13), Vector3.new(0, 0, 0)) * CFrame.Angles(0, 0, math.rad(-38))
renderers.Cues = function()
	local p = panels.Cues
	clear(p.content)
	local d = state.d
	local nextTier = d.cue + 1
	p.sub.Text = string.format("Shot power x%s   Every upgrade makes your shots go further", C.CueMult(d, state.passes))
	local list = new("ScrollingFrame", {
		Size = UDim2.fromOffset(900, 440), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8, ScrollBarImageColor3 = INK,
		ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), Parent = p.content,
	}, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2), PaddingBottom = UDim.new(0, 14) }),
	})
	for k, cue in C.Cues do
		local owned, isNow, isNext = k < d.cue, k == d.cue, k == nextTier
		local c = card({ Size = UDim2.fromOffset(210, 410), LayoutOrder = k, Parent = list }, 22, isNow and rgb(214, 250, 210) or isNext and rgb(255, 240, 190) or WHITE)
		if isNow or isNext then c.UIStroke.Thickness = 5 end
		text("TIER " .. k, 18, MUTED, { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 12), Parent = c, NoStroke = true })
		text(cue[1], 30, INK, { Size = UDim2.new(1, -16, 0, 36), Position = UDim2.fromOffset(8, 34), Parent = c, TextScaled = true, NoStroke = true })
		local vp = viewport(c, { Size = UDim2.fromOffset(190, 180), Position = UDim2.fromOffset(10, 74) }, "Cue", cueOverrides(cue), "cue" .. k, CUE_CAM)
		if k > nextTier then vp.ImageTransparency, vp.ImageColor3 = 0.2, rgb(150, 140, 160) end
		text("x" .. cue[2], 40, ORANGE[2], { Size = UDim2.new(1, 0, 0, 46), Position = UDim2.fromOffset(0, 258), Parent = c })
		text("shot power", 20, MUTED, { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 304), Parent = c, NoStroke = true })
		if isNow then
			text("EQUIPPED", 26, MONEY, { Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 340), Parent = c, NoStroke = true })
		elseif owned then
			text("OWNED", 22, MUTED, { Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 340), Parent = c, NoStroke = true })
		elseif isNext then
			local can = d.cash >= cue[3]
			local _, _, _, setBtn = button({ Size = UDim2.fromOffset(178, 50), Position = UDim2.fromOffset(16, 342), Parent = c, Radius = 18 }, GREEN, "$" .. C.Short(cue[3]), 26, function()
				if can and call("Cue") then renderers.Cues() end
			end)
			setBtn(can)
		else
			text("$" .. C.Short(cue[3]), 24, MUTED, { Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 340), Parent = c, NoStroke = true })
		end
	end
	task.defer(function() -- show the current cue and the next one
		list.CanvasPosition = Vector2.new(math.max(0, (d.cue - 2) * 224), 0)
	end)
	local nxt = C.Cues[nextTier]
	local msg = nxt and (d.cash >= nxt[3] and ("Next: " .. nxt[1] .. "  x" .. nxt[2] .. " power") or ("Need $" .. C.Short(nxt[3] - d.cash) .. " more for the " .. nxt[1] .. " cue")) or "You own the best cue"
	text(msg, 28, INK, { Size = UDim2.fromOffset(900, 40), Position = UDim2.fromOffset(0, 470), Parent = p.content, NoStroke = true })
end

-- --- Gym (opened by stepping into the ring in front of the dumbbell) ---
panel("Gym", "Gym", GREEN)
local PLATE_NAMES = { "Iron", "Steel", "Red", "Blue", "Gold", "Diamond", "Galaxy" }
local BELL_CAM = CFrame.lookAt(Vector3.new(6, 4, 10), Vector3.new(0, 0, 0))
renderers.Gym = function()
	local p = panels.Gym
	clear(p.content)
	local d = state.d
	p.sub.Text = state.training and string.format("Training: %d reps, +%s strength per second", state.reps or 0, C.Short(C.RepStrength(d.dumbLevel) / C.TrainRep))
		or "Strength makes every shot longer. Train at your dumbbell."
	local info = card({ Size = UDim2.fromOffset(900, 230), Position = UDim2.fromOffset(0, 0), Parent = p.content }, 26)
	local color, _, band = C.DumbbellLook(d.dumbLevel)
	viewport(info, { Size = UDim2.fromOffset(300, 210), Position = UDim2.fromOffset(10, 10) }, "Dumbbell", { Plate = color }, "bell" .. band, BELL_CAM)
	text("Dumbbell  Lv." .. d.dumbLevel, 40, INK, { Size = UDim2.fromOffset(560, 54), Position = UDim2.fromOffset(320, 24), Parent = info, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
	text(PLATE_NAMES[band] .. " plates   new look every 5 levels", 22, MUTED, { Size = UDim2.fromOffset(560, 30), Position = UDim2.fromOffset(322, 80), Parent = info, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
	text("Strength " .. C.Short(d.strength), 32, ORANGE[2], { Size = UDim2.fromOffset(560, 40), Position = UDim2.fromOffset(322, 124), Parent = info, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
	text(string.format("+%s per rep, one rep every %.1f s", C.Short(C.RepStrength(d.dumbLevel)), C.TrainRep), 24, INK, { Size = UDim2.fromOffset(560, 32), Position = UDim2.fromOffset(322, 168), Parent = info, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
	local cost = C.LiftCost(d.dumbLevel)
	local can = d.cash >= cost
	local _, _, _, setBtn = button({ Size = UDim2.fromOffset(430, 84), Position = UDim2.fromOffset(0, 266), Parent = p.content, Radius = 28 }, ORANGE,
		can and ("UPGRADE  $" .. C.Short(cost)) or ("Need $" .. C.Short(cost - d.cash)), 30, function()
			if can and call("UpDumb") then renderers.Gym() end
		end)
	setBtn(can)
	button({ Size = UDim2.fromOffset(430, 84), Position = UDim2.fromOffset(470, 266), Parent = p.content, Radius = 28 }, state.training and U.Red or GREEN,
		state.training and "STOP TRAINING" or "START TRAINING", 30, function()
			local starting = not state.training
			if call(starting and "TrainStart" or "TrainStop") and starting then
				p.holder.Visible = false -- close the menu to watch the reps
			end
		end)
	text(string.format("Next level: +%s per rep", C.Short(C.RepStrength(d.dumbLevel + 1))), 24, MUTED, { Size = UDim2.fromOffset(430, 36), Position = UDim2.fromOffset(0, 370), Parent = p.content, NoStroke = true })
	text("Stand on the TRAIN spot", 24, MUTED, { Size = UDim2.fromOffset(430, 36), Position = UDim2.fromOffset(470, 370), Parent = p.content, NoStroke = true })
end

-- --- Settings (saved to the account) ---
panel("Settings", "Settings", { U.Menu[1][4], U.Menu[1][5] })
local settings = { music = 0.5, sfx = 0.7, shake = true, short = false }
local saveQueued = false
local function applySettings()
	groups.Music.Volume, groups.SFX.Volume = settings.music, settings.sfx
	_G.ShakeScale = settings.shake and 1 or 0
	_G.ShortOnly = settings.short
end
local function saveSettings()
	applySettings()
	if saveQueued then return end
	saveQueued = true
	task.delay(0.6, function()
		saveQueued = false
		Request:InvokeServer("Settings", settings)
	end)
end
local sliderConns = {}
renderers.Settings = function()
	local p = panels.Settings
	clear(p.content)
	for _, c in sliderConns do c:Disconnect() end
	table.clear(sliderConns)
	p.sub.Text = "Saved to your account"
	local rowsDef = { { "Music", "music", "slider" }, { "Sound effects", "sfx", "slider" }, { "Camera shake", "shake", "toggle" }, { "Short cinematics only", "short", "toggle" } }
	for i, def in rowsDef do
		local row = card({ Size = UDim2.fromOffset(900, 90), Position = UDim2.fromOffset(0, 10 + (i - 1) * 110), Parent = p.content }, 22)
		text(def[1], 32, INK, { Size = UDim2.fromOffset(420, 90), Position = UDim2.fromOffset(30, 0), Parent = row, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
		local key = def[2]
		if def[3] == "slider" then
			local track = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(380, 16), Position = UDim2.fromOffset(470, 37), BackgroundColor3 = GREY[1], Parent = row }, { corner(8), stroke(2) })
			local fill = new("Frame", { Size = UDim2.fromScale(settings[key], 1), BackgroundColor3 = rgb(111, 130, 255), Parent = track }, { corner(8) })
			local knob = new("Frame", { Size = UDim2.fromOffset(36, 40), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(settings[key], 0, 0.5, 0), BackgroundColor3 = WHITE, ZIndex = 3, Parent = track }, { corner(18), stroke(4) })
			local dragging = false
			local function setFromX(x)
				local v = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
				settings[key] = math.floor(v * 20 + 0.5) / 20
				fill.Size = UDim2.fromScale(settings[key], 1)
				knob.Position = UDim2.new(settings[key], 0, 0.5, 0)
				saveSettings()
			end
			track.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = true
					setFromX(input.Position.X)
				end
			end)
			table.insert(sliderConns, UserInputService.InputChanged:Connect(function(input)
				if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then setFromX(input.Position.X) end
			end))
			table.insert(sliderConns, UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
			end))
		else
			local on = settings[key]
			local sw = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(110, 50), Position = UDim2.fromOffset(760, 20), BackgroundColor3 = on and GREEN[2] or GREY[1], Parent = row }, { corner(25), stroke(3) })
			new("Frame", { Size = UDim2.fromOffset(42, 42), Position = UDim2.fromOffset(on and 64 or 4, 4), BackgroundColor3 = WHITE, Parent = sw }, { corner(21) })
			sw.Activated:Connect(function()
				settings[key] = not settings[key]
				_G.PlaySfx("Click")
				saveSettings()
				renderers.Settings()
			end)
		end
	end
end

-- menu buttons (Figma component "MenuButton": icon + label) with badges
for i, m in U.Menu do
	local holder, body = button({ Size = UDim2.fromOffset(120, 120), LayoutOrder = i, Parent = menu, Radius = 30 }, { m[4], m[5] }, "", 1, function() open(m[1]) end)
	text(m[2], 54, nil, { Size = UDim2.new(1, 0, 0, 66), Position = UDim2.fromOffset(0, 8), Parent = body, NoStroke = true })
	text(m[3], 21, nil, { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 82), Parent = body })
	holder.Name = m[1]
	local bHolder, bBody = box({ Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(96, -12), Parent = holder, ZIndex = 6 }, rgb(255, 59, 59), rgb(255, 59, 59), 20, 4)
	badges[m[1]] = { holder = bHolder, label = text("!", 24, nil, { Size = UDim2.fromScale(1, 1), Parent = bBody }) }
	bHolder.Visible = false
end
local function setBadge(key, value)
	local b = badges[key]
	b.holder.Visible = value ~= nil
	if value then b.label.Text = tostring(value) end
end
local function updateBadges()
	if not state then return end
	local d = state.d
	local day = os.time() // 86400
	local ready = d.daily.day ~= day and 1 or 0
	for i, pt in C.Playtime do
		if not state.claimed[i] and os.time() - state.join >= pt[1] * 60 then ready += 1 end
	end
	setBadge("Bonus", ready > 0 and ready or nil)
	local on, free = 0, 0
	for _, it in d.inv do
		if it.eq then on += 1 else free += 1 end
	end
	setBadge("Inventory", (#d.inv >= C.MaxInventory * 0.9 or (on < C.MaxEquipped and free > 0)) and "!" or nil)
end

-- ===== Onboarding: 3 steps, with an arrow above the gym / kiosk =====
local TIPS = {
	{ "Hold SHOOT, release when the bar is high", "Step 1 of 3" },
	{ "Go to the gym in front of your base and start training", "Step 2 of 3" },
	{ "Open the cue shop in front of your base and upgrade your cue", "Step 3 of 3" },
}
local arrow, arrowStep
local function baseObj(...)
	local o = workspace.World:FindFirstChild("Base" .. state.slot)
	for _, n in { ... } do o = o and o:FindFirstChild(n) end
	return o
end
local function updateTutorial()
	local step = state and state.d.tutorial or 4
	tipHolder.Visible = step <= 3 and hud.Visible
	if step == arrowStep then return end
	arrowStep = step
	if arrow then
		arrow:Destroy()
		arrow = nil
	end
	if step > 3 then return end
	tipText.Text, tipStep.Text = TIPS[step][1], TIPS[step][2]
	if step >= 2 then
		local target = step == 2 and baseObj("Gym", "TrainSpot") or baseObj("CueShop")
		if target then
			arrow = new("BillboardGui", { Size = UDim2.fromOffset(90, 90), StudsOffset = Vector3.new(0, 9, 0), AlwaysOnTop = true, Adornee = target, Parent = gui })
			local a = text("▼", 80, U.Title, { Size = UDim2.fromScale(1, 1), Parent = arrow })
			TweenService:Create(a, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.fromOffset(0, 16) }):Play()
		end
	end
end

-- ===== Kiosk hint when the next cue is affordable =====
local kioskTag
local function updateKioskTag()
	if not state then return end
	local nxt = C.Cues[state.d.cue + 1]
	local can = nxt and state.d.cash >= nxt[3]
	if can and not kioskTag then
		local shop = baseObj("CueShop")
		if shop then
			kioskTag = new("BillboardGui", { Size = UDim2.fromOffset(230, 46), StudsOffset = Vector3.new(0, 13.5, 0), MaxDistance = 90, Adornee = shop, Parent = gui })
			local _, b = box({ Size = UDim2.fromScale(1, 1), Parent = kioskTag }, GREEN[1], GREEN[2], 23, 3)
			text("UPGRADE READY", 24, nil, { Size = UDim2.fromScale(1, 1), Parent = b })
		end
	elseif not can and kioskTag then
		kioskTag:Destroy()
		kioskTag = nil
	end
end

-- ===== Training context button: near your gym or while training =====
local function updateTrainButton()
	if not state then return end
	local spot = baseObj("Gym", "TrainSpot")
	local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	local near = spot and hrp and (hrp.Position - spot.Position).Magnitude <= C.GymRange + 4
	trainHolder.Visible = (state.training or near) and hud.Visible or false
	trainLabel.Text = state.training and ("STOP   " .. (state.reps or 0) .. " REPS") or "START TRAINING"
end

-- ===== Shooting: charge, live preview of where the ball will land =====
local power, charging, t0 = 0, false, 0
local function shotReady() return state and not _G.ThrowBusy and os.clock() >= (_G.ShotReadyAt or 0) end
local function preview(p)
	if not state then return end
	local zone = C.ZoneOf(C.Distance(p, state.d, state.passes))
	local rar = C.Rarities[zone]
	previewLabel.Text = string.format("TABLE %d   %s", zone, string.upper(rar[1]))
	previewBody.UIGradient.Color = ColorSequence.new(rar[2]:Lerp(WHITE, 0.35), rar[2])
end
shootHit.MouseButton1Down:Connect(function()
	if shotReady() then charging, power, t0 = true, 0, 0 end
end)
UserInputService.InputEnded:Connect(function(input)
	if not charging then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	charging = false
	local ok, msg = Request:InvokeServer("Throw", power)
	if msg then toast(msg, U.Bad) end
	if not ok then powerFill.Size = UDim2.new(0, 0, 1, -12) end
end)
local trainCheck = 0
RunService.RenderStepped:Connect(function(dt)
	if charging then
		t0 += dt
		power = 1 - math.abs(((t0 * 0.8) % 2) - 1)
		powerFill.Size = UDim2.new(power, -12, 1, -12)
		preview(power)
	end
	local ready = shotReady()
	setShootEnabled(ready, U.Red)
	if not charging then
		shootLabel.Text = ready and "SHOOT" or "..."
		if ready then preview(1) end
	end
	hint.Text = ready and "Hold to charge, release to shoot" or "Wait for the ball"
	trainCheck += dt
	if trainCheck > 0.25 then
		trainCheck = 0
		updateTrainButton()
	end
end)

-- ===== Server events =====
local shownCash, targetCash = 0, 0
local function renderStats()
	if not state then return end
	incomeLabel.Text = "+$" .. C.Short(state.income) .. "/s"
	strLabel.Text = C.Short(state.d.strength)
	luckLabel.Text = string.format("%.2fX", state.luck)
end
RunService.Heartbeat:Connect(function(dt) -- smooth cash count-up
	shownCash += (targetCash - shownCash) * math.min(1, dt * 8)
	if math.abs(targetCash - shownCash) < 1 then shownCash = targetCash end
	cashLabel.Text = "$" .. C.Short(shownCash)
end)

local firstState = true
Fx.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "State" then
		state = a
		_G.MySlot, _G.MyCue = a.slot, a.d.cue
		targetCash = a.d.cash
		if firstState then
			firstState = false
			shownCash = a.d.cash
			for k, v in a.d.settings or {} do settings[k] = v end
			applySettings()
		end
		renderStats()
		updateBadges()
		updateTutorial()
		updateKioskTag()
		updateTrainButton()
		rerender()
	elseif kind == "Cash" then
		targetCash = a
		if state then state.d.cash = a end
		renderStats()
		updateBadges()
		updateKioskTag()
		if panels.Bonus.holder.Visible and bonusTick then bonusTick() end
	elseif kind == "Train" then
		if state then state.training, state.reps = a == true, 0 end
		updateTrainButton()
		if panels.Gym.holder.Visible then renderers.Gym() end
	elseif kind == "Rep" then
		if state then state.d.strength, state.reps = a, c end
		renderStats()
		strScale.Scale = 1.12
		tween(strScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		if panels.Gym.holder.Visible then renderers.Gym() end
	elseif kind == "Open" then
		if panels[a] then open(a, true) end
	elseif kind == "Toast" then
		toast(a, b and U.Title or U.Bad)
		if b then _G.PlaySfx("Reward") end
	elseif kind == "CueSwap" then -- the old cue disappears in a puff
		local puff = new("Part", { Anchored = true, CanCollide = false, Transparency = 1, Size = Vector3.one, Position = a, Parent = workspace })
		local e = new("ParticleEmitter", {
			Color = ColorSequence.new(U.Title, WHITE), Speed = NumberRange.new(6, 12), Lifetime = NumberRange.new(0.4, 0.8),
			SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.8, 0), LightEmission = 1, Rate = 0, Parent = puff,
		})
		e:Emit(40)
		task.delay(2, puff.Destroy, puff)
		_G.PlaySfx("Reward")
	end
end)

_G.SetHudVisible = function(on)
	hud.Visible = on
	if not on then
		for _, p in panels do p.holder.Visible = false end
	end
	updateTutorial()
end

Request:InvokeServer("Sync")
