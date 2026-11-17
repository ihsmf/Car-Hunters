-- HUD + panels, laid out 1:1 from the Figma file "Billiard Hunters — UI" (frames "… v2", 1920x1080, scaled to screen).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.Shared.Config)
local U = C.UI
local plr = Players.LocalPlayer
local WHITE, INK = Color3.new(1, 1, 1), U.Ink
local rgb = Color3.fromRGB
local GREEN, ORANGE, PURPLE = { rgb(157, 245, 154), rgb(62, 193, 90) }, { rgb(255, 196, 138), rgb(255, 138, 61) }, { rgb(230, 166, 255), rgb(164, 92, 255) }
local GREY = { rgb(225, 214, 198), rgb(196, 182, 162) }

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
local function stroke(t) return new("UIStroke", { Color = INK, Thickness = t, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
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

-- cartoon box: gradient body, ink outline, hard ink shadow 6 px below
local function box(props, top, bottom, radius, strokeW)
	local holder = new("Frame", { Size = props.Size, Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, BackgroundTransparency = 1, LayoutOrder = props.LayoutOrder or 0, Name = props.Name or "Box", ZIndex = props.ZIndex or 1, Parent = props.Parent })
	new("Frame", { Name = "Shadow", Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, strokeW == 0 and 0 or 6), BackgroundColor3 = INK, BackgroundTransparency = strokeW == 0 and 1 or 0, Parent = holder }, { corner(radius) })
	local body = new("Frame", { Name = "Body", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = holder }, { corner(radius), grad(top, bottom) })
	if strokeW ~= 0 then stroke(strokeW or 4).Parent = body end
	return holder, body
end

-- button with hover/press bounce; returns holder, body, label, setEnabled(on, colors?)
local function button(props, colors, label, size, onClick)
	local holder, body = box(props, colors[1], colors[2], props.Radius or 18, 3)
	local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5, Parent = holder })
	local scale = new("UIScale", { Parent = holder })
	local lbl = text(label or "", size or 24, nil, { Size = UDim2.fromScale(1, 1), Parent = body })
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
	local f = new("Frame", { Position = pos, Size = size, BackgroundColor3 = rgb(230, 216, 194), Parent = parent }, { corner(math.floor(size.Y.Offset / 2)) })
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color or GREEN[2], Parent = f }, { corner(math.floor(size.Y.Offset / 2)) })
	return f, function(v, c)
		fill.Size = UDim2.fromScale(math.clamp(v, 0, 1), 1)
		if c then fill.BackgroundColor3 = c end
	end
end

-- ===== Root (design space 1920x1080) =====
local gui = new("ScreenGui", { Name = "Main", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = plr:WaitForChild("PlayerGui") })
local root = new("Frame", { Size = UDim2.fromOffset(1920, 1080), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = gui })
local rootScale = new("UIScale", { Parent = root })
local function rescale()
	local v = workspace.CurrentCamera.ViewportSize
	rootScale.Scale = math.max(0.33, math.min(v.X / 1920, v.Y / 1080)) -- 0.33 keeps the whole HUD on an 844x390 phone
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()

local Remotes = RS:WaitForChild("Remotes")
local Request, Fx = Remotes:WaitForChild("Request"), Remotes:WaitForChild("Fx")
local state

-- ===== Toast stack (under the top bar, never over it) =====
local toastStack = new("Frame", { Size = UDim2.fromOffset(700, 200), Position = UDim2.fromOffset(960, 124), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, ZIndex = 30, Parent = root }, {
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
	local holder, body = box({ Size = UDim2.fromOffset(560, 54), LayoutOrder = toastN, Parent = toastStack }, U.Panel, U.Panel, 27, 3)
	text(msg, 26, color or U.Title, { Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), Parent = body, TextScaled = false })
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
local hud = new("Frame", { Name = "HUD", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = root })

-- top bar: cash (+income) | strength | luck with timer
local _, cashBody = box({ Size = UDim2.fromOffset(380, 86), Position = UDim2.fromOffset(560, 22), Parent = hud }, GREEN[1], GREEN[2], 43, 4)
local cashLabel = text("💵 0", 44, nil, { Size = UDim2.fromOffset(230, 70), Position = UDim2.fromOffset(18, 8), Parent = cashBody, TextXAlignment = Enum.TextXAlignment.Left })
local incomeLabel = text("+$0/s", 24, nil, { Size = UDim2.fromOffset(130, 40), Position = UDim2.fromOffset(236, 24), Parent = cashBody, TextXAlignment = Enum.TextXAlignment.Right })
local _, strBody = box({ Size = UDim2.fromOffset(190, 86), Position = UDim2.fromOffset(960, 22), Parent = hud }, ORANGE[1], ORANGE[2], 43, 4)
local strLabel = text("💪 0", 38, nil, { Size = UDim2.fromScale(1, 1), Parent = strBody })
local luckHolder, luckBody = box({ Size = UDim2.fromOffset(250, 86), Position = UDim2.fromOffset(1170, 22), Parent = hud }, PURPLE[1], PURPLE[2], 43, 4)
local luckLabel = text("🍀 LUCK x1", 32, nil, { Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 6), Parent = luckBody })
local _, setLuckBar = bar(luckBody, UDim2.fromOffset(30, 62), UDim2.fromOffset(190, 10), WHITE)
local luckScale = new("UIScale", { Parent = luckHolder })

-- left menu with badges
local menu = new("Frame", { Size = UDim2.fromOffset(150, 600), Position = UDim2.fromOffset(28, 300), BackgroundTransparency = 1, Parent = hud }, {
	new("UIListLayout", { Padding = UDim.new(0, 20), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local badges = {}
local open -- forward

-- shot area: live preview, power bar, SHOOT
local previewHolder, previewBody = box({ Size = UDim2.fromOffset(440, 52), Position = UDim2.fromOffset(960, 770), AnchorPoint = Vector2.new(0.5, 0), Parent = hud }, rgb(255, 227, 138), rgb(255, 184, 48), 26, 3)
local previewLabel = text("→ TABLE 1", 28, nil, { Size = UDim2.fromScale(1, 1), Parent = previewBody })
local powerFrame = new("Frame", { Size = UDim2.fromOffset(640, 44), Position = UDim2.fromOffset(640, 836), BackgroundColor3 = INK, Parent = hud }, { corner(22), stroke(4) })
local powerFill = new("Frame", { Size = UDim2.new(0, 0, 1, -12), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = WHITE, Parent = powerFrame }, {
	corner(16), new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(90, 220, 90)), ColorSequenceKeypoint.new(0.6, rgb(255, 220, 40)), ColorSequenceKeypoint.new(1, rgb(255, 60, 60)) }) }),
})
local _, _, shootLabel, setShootEnabled, shootHit = button({ Size = UDim2.fromOffset(360, 104), Position = UDim2.fromOffset(780, 900), Parent = hud, Radius = 40 }, U.Red, "🎱 SHOOT!", 56)
local hint = text("Hold to charge • release to shoot", 22, nil, { Size = UDim2.fromOffset(600, 30), Position = UDim2.fromOffset(660, 1014), Parent = hud })

-- onboarding bubble
local tipHolder, tipBody = box({ Size = UDim2.fromOffset(460, 100), Position = UDim2.fromOffset(1190, 880), Parent = hud }, WHITE, WHITE, 24, 4)
local tipText = text("", 24, INK, { Size = UDim2.new(1, -40, 0, 56), Position = UDim2.fromOffset(20, 10), Parent = tipBody, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
local tipStep = text("", 20, rgb(164, 92, 255), { Size = UDim2.new(1, -40, 0, 24), Position = UDim2.fromOffset(20, 66), Parent = tipBody, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
tipHolder.Visible = false

-- ===== Panels =====
local panels, renderers = {}, {}
local function panel(key, title)
	local holder, body = box({ Size = UDim2.fromOffset(980, 680), Position = UDim2.fromOffset(960, 560), AnchorPoint = Vector2.new(0.5, 0.5), Parent = root, Name = key, ZIndex = 10 }, U.Panel, U.Panel, 40, 6)
	holder.Visible = false
	text(title, 52, U.Title, { Size = UDim2.new(1, -160, 0, 70), Position = UDim2.fromOffset(40, 16), Parent = body, TextXAlignment = Enum.TextXAlignment.Left })
	local sub = text("", 24, rgb(122, 106, 136), { Size = UDim2.new(1, -160, 0, 30), Position = UDim2.fromOffset(44, 88), Parent = body, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
	button({ Size = UDim2.fromOffset(70, 60), Position = UDim2.fromOffset(880, 24), Parent = body, Radius = 20 }, U.Red, "✖", 30, function() holder.Visible = false end)
	local content = new("Frame", { Size = UDim2.fromOffset(900, 530), Position = UDim2.fromOffset(40, 130), BackgroundTransparency = 1, Parent = body })
	panels[key] = { holder = holder, content = content, sub = sub }
end
local function clear(f)
	for _, c in f:GetChildren() do c:Destroy() end
end
local function scroller(parent, pos, size, cell, pad)
	return new("ScrollingFrame", {
		Position = pos, Size = size, BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 10, ScrollBarImageColor3 = INK,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = parent,
	}, {
		new("UIGridLayout", { CellSize = cell, CellPadding = UDim2.fromOffset(pad, pad + 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingTop = UDim.new(0, 14), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }),
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
panel("Inventory", "🎒 Inventory")
local sortMode = "best"
local function sellDialog()
	local p = panels.Inventory
	local counts = {}
	for _, it in state.d.inv do
		if not it.eq then
			local r = C.Characters[it.id].rarity
			counts[r] = counts[r] or { n = 0, cash = 0 }
			counts[r].n += 1
			counts[r].cash += C.Characters[it.id].income * 30
		end
	end
	local holder, body = box({ Size = UDim2.fromOffset(560, 500), Position = UDim2.fromOffset(450, 260), AnchorPoint = Vector2.new(0.5, 0.5), Parent = p.content, ZIndex = 20 }, U.Panel, U.Panel, 30, 5)
	text("💰 Sell unequipped", 36, U.Title, { Size = UDim2.new(1, -100, 0, 50), Position = UDim2.fromOffset(24, 16), Parent = body, TextXAlignment = Enum.TextXAlignment.Left })
	button({ Size = UDim2.fromOffset(56, 50), Position = UDim2.fromOffset(484, 16), Parent = body, Radius = 18 }, U.Red, "✖", 26, function() holder:Destroy() end)
	local list = new("ScrollingFrame", { Size = UDim2.fromOffset(520, 410), Position = UDim2.fromOffset(20, 76), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = body }, {
		new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingRight = UDim.new(0, 10) }),
	})
	local any = false
	for r = 1, #C.Rarities do
		local c = counts[r]
		if c then
			any = true
			local rar = C.Rarities[r]
			local _, row = box({ Size = UDim2.new(1, 0, 0, 60), LayoutOrder = r, Parent = list }, WHITE, WHITE, 18, 3)
			new("Frame", { Size = UDim2.fromOffset(14, 44), Position = UDim2.fromOffset(10, 8), BackgroundColor3 = rar[2], Parent = row }, { corner(7) })
			text(rar[1] .. "  ×" .. c.n, 26, INK, { Size = UDim2.fromOffset(250, 60), Position = UDim2.fromOffset(34, 0), Parent = row, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
			button({ Size = UDim2.fromOffset(200, 46), Position = UDim2.fromOffset(290, 7), Parent = row, Radius = 16 }, U.Action, "Sell $" .. C.Short(c.cash), 22, function()
				if call("SellRarity", r) then
					holder:Destroy()
					renderers.Inventory()
				end
			end)
		end
	end
	if not any then text("Nothing to sell — all your characters are on the base.", 24, INK, { Size = UDim2.new(1, 0, 0, 80), Parent = list, TextWrapped = true, NoStroke = true }) end
end
renderers.Inventory = function()
	local p = panels.Inventory
	clear(p.content)
	local d = state.d
	local on = 0
	for _, it in d.inv do
		if it.eq then on += 1 end
	end
	p.sub.Text = string.format("%d / %d characters  •  %d / %d on the base", #d.inv, C.MaxInventory, on, C.MaxEquipped)
	local _, setCap = bar(p.content, UDim2.fromOffset(0, 0), UDim2.fromOffset(500, 18))
	setCap(#d.inv / C.MaxInventory, #d.inv >= C.MaxInventory * 0.9 and U.Bad or GREEN[2])
	button({ Size = UDim2.fromOffset(150, 46), Position = UDim2.fromOffset(520, -12), Parent = p.content }, GREEN, "⭐ Equip best", 22, function()
		if call("EquipBest") then renderers.Inventory() end
	end)
	button({ Size = UDim2.fromOffset(110, 46), Position = UDim2.fromOffset(680, -12), Parent = p.content }, U.Action, "💰 Sell…", 22, sellDialog)
	button({ Size = UDim2.fromOffset(100, 46), Position = UDim2.fromOffset(800, -12), Parent = p.content }, U.Cues, sortMode == "best" and "↓ Best" or "↓ New", 22, function()
		sortMode = sortMode == "best" and "new" or "best"
		renderers.Inventory()
	end)
	local list = scroller(p.content, UDim2.fromOffset(0, 46), UDim2.fromOffset(900, 484), UDim2.fromOffset(285, 210), 20)
	if #d.inv == 0 then
		text("No characters yet!\nHold 🎱 SHOOT to hunt billiard pros.", 30, INK, { Size = UDim2.fromOffset(880, 160), Parent = list, TextWrapped = true, NoStroke = true })
		list.UIGridLayout.CellSize = UDim2.fromOffset(880, 160)
		return
	end
	for i, it in d.inv do
		local ch = C.Characters[it.id]
		local rar = C.Rarities[ch.rarity]
		local order = sortMode == "best" and -(ch.rarity * 10000 + ch.income % 10000) or -i
		local cardHolder, card = box({ Size = UDim2.fromOffset(285, 210), LayoutOrder = order, Parent = list }, WHITE, WHITE, 24, 4)
		local ribbon = new("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = rar[2], Parent = card }, { corner(24) })
		new("Frame", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 26), BackgroundColor3 = rar[2], BorderSizePixel = 0, Parent = ribbon })
		text(string.upper(rar[1]), 22, nil, { Size = UDim2.fromScale(1, 1), Parent = ribbon })
		text(ch.name, 28, INK, { Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(10, 56), Parent = card, TextScaled = true, NoStroke = true })
		text("💵 $" .. C.Short(ch.income) .. "/s", 24, GREEN[2], { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 98), Parent = card, NoStroke = true })
		button({ Size = UDim2.fromOffset(150, 46), Position = UDim2.fromOffset(16, 146), Parent = card, Radius = 16 }, it.eq and U.Red or GREEN, it.eq and "Unequip" or "Equip", 22, function()
			if call("Equip", i) then renderers.Inventory() end
		end)
		button({ Size = UDim2.fromOffset(92, 46), Position = UDim2.fromOffset(178, 146), Parent = card, Radius = 16 }, U.Action, "Sell", 22, function()
			if call("Sell", i) then renderers.Inventory() end
		end)
		if it.eq then
			local _, check = box({ Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(255, -12), Parent = cardHolder, ZIndex = 3 }, GREEN[2], GREEN[2], 20, 3)
			text("✓", 26, nil, { Size = UDim2.fromScale(1, 1), Parent = check })
		end
	end
end

-- --- Bonuses ---
panel("Bonus", "🎁 Bonuses")
local bonusTick
renderers.Bonus = function()
	local p = panels.Bonus
	clear(p.content)
	p.sub.Text = "Log in every day for a bigger streak  •  stay to earn playtime gifts"
	local day = os.time() // 86400
	local dd = state.d.daily
	local claimedToday = dd.day == day
	local streak = (dd.day == day or dd.day == day - 1) and dd.streak or 0
	local today = claimedToday and streak or streak % #C.Daily + 1
	for k = 1, #C.Daily do
		local done = k < today or (claimedToday and k == today)
		local isToday = k == today and not claimedToday
		local top = isToday and rgb(255, 227, 138) or done and rgb(201, 242, 194) or WHITE
		local bottom = isToday and rgb(255, 184, 48) or top
		local _, tile = box({ Size = UDim2.fromOffset(118, 150), Position = UDim2.fromOffset((k - 1) * 130, 0), Parent = p.content }, top, bottom, 22, 4)
		text("Day " .. k, 24, INK, { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 10), Parent = tile, NoStroke = true })
		text(done and "✅" or "💵", 40, nil, { Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 46), Parent = tile, NoStroke = true })
		text("$" .. C.Short(C.Daily[k]), 24, GREEN[2], { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 104), Parent = tile, NoStroke = true })
	end
	local _, _, _, setDailyBtn = button({ Size = UDim2.fromOffset(300, 64), Position = UDim2.fromOffset(300, 170), Parent = p.content, Radius = 24 }, { rgb(255, 158, 200), rgb(255, 92, 158) },
		claimedToday and "✅ Come back tomorrow" or "Claim Day " .. today .. "!", 28, function()
			if not claimedToday and call("Daily") then renderers.Bonus() end
		end)
	setDailyBtn(not claimedToday)
	local rows = {}
	for i, pt in C.Playtime do
		local y = 260 + (i - 1) * 64
		local _, row = box({ Size = UDim2.fromOffset(900, 54), Position = UDim2.fromOffset(0, y), Parent = p.content }, WHITE, WHITE, 18, 3)
		text("⏱️ " .. pt[1] .. " min", 24, INK, { Size = UDim2.fromOffset(180, 54), Position = UDim2.fromOffset(18, 0), Parent = row, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
		local _, setBar = bar(row, UDim2.fromOffset(210, 18), UDim2.fromOffset(440, 18))
		text("$" .. C.Short(pt[2]), 24, GREEN[2], { Size = UDim2.fromOffset(100, 54), Position = UDim2.fromOffset(670, 0), Parent = row, NoStroke = true })
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
				r.lbl.Text = "✅"
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
panel("Shop", "💎 Shop")
renderers.Shop = function()
	local p = panels.Shop
	clear(p.content)
	p.sub.Text = "Game Passes and cash packs"
	for i, gp in C.GamePasses do
		local owned = state.passes[gp.key]
		local x, y = ((i - 1) % 2) * 455, ((i - 1) // 2) * 170
		local _, card = box({ Size = UDim2.fromOffset(440, 154), Position = UDim2.fromOffset(x, y), Parent = p.content }, rgb(255, 241, 184), rgb(255, 216, 107), 26, 4)
		text(gp.icon, 64, nil, { Size = UDim2.fromOffset(110, 154), Parent = card, NoStroke = true })
		text(gp.name, 32, INK, { Size = UDim2.fromOffset(310, 44), Position = UDim2.fromOffset(110, 14), Parent = card, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
		text(gp.desc, 22, rgb(122, 106, 136), { Size = UDim2.fromOffset(310, 30), Position = UDim2.fromOffset(110, 56), Parent = card, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
		local _, _, _, setBtn = button({ Size = UDim2.fromOffset(180, 46), Position = UDim2.fromOffset(110, 94), Parent = card, Radius = 16 }, U.Red, owned and "✅ OWNED" or "Buy", 24, function()
			if not owned then call("Pass", gp.key) end
		end)
		setBtn(not owned)
	end
	for i, pr in C.Products do
		local _, card = box({ Size = UDim2.fromOffset(290, 150), Position = UDim2.fromOffset((i - 1) * 305, 360), Parent = p.content }, rgb(201, 242, 194), rgb(62, 193, 90), 26, 4)
		text(pr.icon .. " $" .. C.Short(pr.cash), 36, nil, { Size = UDim2.new(1, 0, 0, 70), Position = UDim2.fromOffset(0, 10), Parent = card })
		button({ Size = UDim2.fromOffset(180, 46), Position = UDim2.fromOffset(55, 90), Parent = card, Radius = 16 }, U.Red, "Buy", 24, function() call("Product", i) end)
	end
end

-- --- Cue shop (opened at the kiosk) ---
panel("Cues", "🎱 Cue Shop")
local function cueCard(parent, x, title, titleColor, cue, top, bottom, sub)
	local _, c = box({ Size = UDim2.fromOffset(380, 330), Position = UDim2.fromOffset(x, 10), Parent = parent }, top, bottom, 30, 4)
	text(title, 26, titleColor, { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 14), Parent = c, NoStroke = true })
	new("Frame", { Size = UDim2.fromOffset(120, 120), Position = UDim2.fromOffset(130, 56), BackgroundColor3 = cue[4], Parent = c }, { corner(60), stroke(4) })
	text("🎱", 80, nil, { Size = UDim2.fromOffset(120, 120), Position = UDim2.fromOffset(130, 56), Parent = c, NoStroke = true })
	text(cue[1], 36, INK, { Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 196), Parent = c, NoStroke = true })
	text(sub, 24, rgb(122, 106, 136), { Size = UDim2.new(1, 0, 0, 32), Position = UDim2.fromOffset(0, 246), Parent = c, NoStroke = true })
end
renderers.Cues = function()
	local p = panels.Cues
	clear(p.content)
	local d = state.d
	local cur, nxt = C.Cues[d.cue], C.Cues[d.cue + 1]
	p.sub.Text = "Each upgrade replaces your cue  •  shot power x" .. C.CueMult(d, state.passes)
	cueCard(p.content, 0, "NOW", GREEN[2], cur, WHITE, WHITE, "x" .. cur[2] .. " distance")
	if nxt then
		text("➜", 80, U.Title, { Size = UDim2.fromOffset(140, 100), Position = UDim2.fromOffset(380, 120), Parent = p.content })
		cueCard(p.content, 520, "NEXT", ORANGE[2], nxt, rgb(255, 241, 184), rgb(255, 216, 107), string.format("x%s distance  (+%d%%)", nxt[2], math.floor((nxt[2] / cur[2] - 1) * 100 + 0.5)))
		local can = d.cash >= nxt[3]
		local _, _, _, setBtn = button({ Size = UDim2.fromOffset(380, 80), Position = UDim2.fromOffset(520, 360), Parent = p.content, Radius = 26 }, GREEN,
			can and ("UPGRADE  $" .. C.Short(nxt[3])) or ("Need $" .. C.Short(nxt[3] - d.cash) .. " more"), 30, function()
				if can and call("Cue") then renderers.Cues() end
			end)
		setBtn(can)
	else
		text("🏆 You own the best cue!", 40, U.Title, { Size = UDim2.fromOffset(500, 330), Position = UDim2.fromOffset(400, 10), Parent = p.content })
	end
	for k = 1, #C.Cues do -- tier track
		local col = k < d.cue and GREEN[2] or k == d.cue and U.Title or GREY[1]
		new("Frame", { Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset((k - 1) * 62, 470), BackgroundColor3 = col, Parent = p.content }, { corner(23), stroke(3) })
	end
	text("Tier " .. d.cue .. " / " .. #C.Cues, 26, INK, { Size = UDim2.fromOffset(200, 46), Position = UDim2.fromOffset(640, 470), Parent = p.content, NoStroke = true })
end

-- --- Gym (opened with R at the dumbbell) ---
panel("Gym", "💪 Gym")
renderers.Gym = function()
	local p = panels.Gym
	clear(p.content)
	local d = state.d
	p.sub.Text = "Press E at your dumbbell to lift  •  strength makes your shots longer"
	local _, info = box({ Size = UDim2.fromOffset(900, 200), Position = UDim2.fromOffset(0, 10), Parent = p.content }, WHITE, WHITE, 30, 4)
	text("🏋️", 110, nil, { Size = UDim2.fromOffset(200, 200), Parent = info, NoStroke = true })
	text("Dumbbell Lv." .. d.dumbLevel, 40, INK, { Size = UDim2.fromOffset(600, 60), Position = UDim2.fromOffset(200, 26), Parent = info, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
	text("💪 Strength " .. C.Short(d.strength) .. "   •   +" .. d.dumbLevel .. " per lift", 28, rgb(122, 106, 136), { Size = UDim2.fromOffset(660, 40), Position = UDim2.fromOffset(200, 90), Parent = info, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
	local cost = C.LiftCost(d.dumbLevel)
	local can = d.cash >= cost
	local _, _, _, setBtn = button({ Size = UDim2.fromOffset(460, 84), Position = UDim2.fromOffset(220, 250), Parent = p.content, Radius = 28 }, ORANGE,
		can and ("UPGRADE  $" .. C.Short(cost)) or ("Need $" .. C.Short(cost - d.cash) .. " more"), 32, function()
			if can and call("UpDumb") then renderers.Gym() end
		end)
	setBtn(can)
	text("Next level: +" .. (d.dumbLevel + 1) .. " strength per lift", 26, INK, { Size = UDim2.fromOffset(900, 40), Position = UDim2.fromOffset(0, 350), Parent = p.content, NoStroke = true })
end

-- --- Settings (saved to the account) ---
panel("Settings", "⚙️ Settings")
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
	local rowsDef = { { "🎵 Music", "music", "slider" }, { "🔊 Sound FX", "sfx", "slider" }, { "📳 Camera shake", "shake", "toggle" }, { "🎬 Short cinematics only", "short", "toggle" } }
	for i, def in rowsDef do
		local _, row = box({ Size = UDim2.fromOffset(900, 90), Position = UDim2.fromOffset(0, 10 + (i - 1) * 110), Parent = p.content }, WHITE, WHITE, 24, 3)
		text(def[1], 32, INK, { Size = UDim2.fromOffset(420, 90), Position = UDim2.fromOffset(30, 0), Parent = row, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
		local key = def[2]
		if def[3] == "slider" then
			local track = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(380, 16), Position = UDim2.fromOffset(470, 37), BackgroundColor3 = GREY[1], Parent = row }, { corner(8) })
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
			local sw = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(110, 50), Position = UDim2.fromOffset(760, 20), BackgroundColor3 = on and GREEN[2] or GREY[1], Parent = row }, { corner(25), stroke(4) })
			new("Frame", { Size = UDim2.fromOffset(42, 42), Position = UDim2.fromOffset(on and 64 or 4, 4), BackgroundColor3 = WHITE, Parent = sw }, { corner(21), stroke(3) })
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
	{ "👉 Hold SHOOT, release when the bar is high!", "Step 1 of 3" },
	{ "💪 Go to the GYM in front of your base and press E to lift!", "Step 2 of 3" },
	{ "🎱 Open the CUE SHOP in front of your base and upgrade your cue!", "Step 3 of 3" },
}
local arrow, arrowStep
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
		local base = workspace.World:FindFirstChild("Base" .. state.slot)
		local target = base and (step == 2 and base:FindFirstChild("DumbbellHit") or base:FindFirstChild("CueShop"))
		if target then
			arrow = new("BillboardGui", { Size = UDim2.fromOffset(120, 120), StudsOffset = Vector3.new(0, 9, 0), AlwaysOnTop = true, Adornee = target, Parent = gui })
			local a = text("⬇️", 90, nil, { Size = UDim2.fromScale(1, 1), Parent = arrow, NoStroke = true })
			tween(a, 0.5, { Position = UDim2.fromOffset(0, 20) })
			TweenService:Create(a, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.fromOffset(0, 20) }):Play()
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
		local base = workspace.World:FindFirstChild("Base" .. state.slot)
		local shop = base and base:FindFirstChild("CueShop")
		if shop then
			kioskTag = new("BillboardGui", { Size = UDim2.fromOffset(260, 60), StudsOffset = Vector3.new(0, 13, 0), MaxDistance = 120, Adornee = shop, Parent = gui })
			local l = text("⬆ NEW CUE READY!", 30, U.Title, { Size = UDim2.fromScale(1, 1), Parent = kioskTag })
			TweenService:Create(l, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.fromOffset(0, -10) }):Play()
		end
	elseif not can and kioskTag then
		kioskTag:Destroy()
		kioskTag = nil
	end
end

-- ===== Shooting: charge, live preview of where the ball will land =====
local power, charging, t0 = 0, false, 0
local function shotReady() return state and not _G.ThrowBusy and os.clock() >= (_G.ShotReadyAt or 0) end
local function preview(p)
	if not state then return end
	local zone = C.ZoneOf(C.Distance(p, state.d, state.passes))
	local rar = C.Rarities[zone]
	previewLabel.Text = string.format("→ TABLE %d • %s", zone, string.upper(rar[1]))
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
		shootLabel.Text = ready and "🎱 SHOOT!" or "⏳ …"
		if ready then preview(1) end
	end
	hint.Text = ready and "Hold to charge • release to shoot" or "Wait for the ball…"
end)

-- ===== Dumbbell lift: the dumbbell goes up and down, the player raises the arms, "+N" floats up =====
local lifting = false
local function liftAnimation(gain)
	if lifting or not state then return end
	local base = workspace.World:FindFirstChild("Base" .. state.slot)
	local db = base and base:FindFirstChild("Dumbbell")
	if not db then return end
	lifting = true
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if animator then
		local a = Instance.new("Animation")
		a.AnimationId = "rbxassetid://507770677"
		local ok, track = pcall(animator.LoadAnimation, animator, a)
		if ok and track then track:Play(0.1, 1, 2.2) end
	end
	local bb = new("BillboardGui", { Size = UDim2.fromOffset(140, 60), StudsOffset = Vector3.new(0, 4, 0), AlwaysOnTop = true, Adornee = db:FindFirstChildWhichIsA("BasePart"), Parent = gui })
	local l = text("+" .. gain .. " 💪", 40, rgb(255, 120, 120), { Size = UDim2.fromScale(1, 1), Parent = bb })
	tween(bb, 0.8, { StudsOffset = Vector3.new(0, 8, 0) })
	tween(l, 0.8, { TextTransparency = 1 })
	tween(l.UIStroke, 0.8, { Transparency = 1 })
	task.delay(0.9, bb.Destroy, bb)
	local cf0 = db:GetPivot()
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = math.min((os.clock() - start) / 0.4, 1)
		db:PivotTo(cf0 * CFrame.new(0, math.sin(t * math.pi) * 2.6, 0))
		if t >= 1 then
			conn:Disconnect()
			db:PivotTo(cf0)
			lifting = false
		end
	end)
end

-- ===== Server events =====
local shownCash, targetCash = 0, 0
local luckIn = C.LuckCycle
local function renderStats()
	if not state then return end
	incomeLabel.Text = "+$" .. C.Short(state.income) .. "/s"
	strLabel.Text = "💪 " .. C.Short(state.d.strength)
	luckLabel.Text = "🍀 LUCK x" .. state.luck
	setLuckBar(luckIn / C.LuckCycle)
end
RunService.Heartbeat:Connect(function(dt) -- smooth cash count-up
	shownCash += (targetCash - shownCash) * math.min(1, dt * 8)
	if math.abs(targetCash - shownCash) < 1 then shownCash = targetCash end
	cashLabel.Text = "💵 " .. C.Short(shownCash)
end)

local firstState = true
Fx.OnClientEvent:Connect(function(kind, a, b)
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
		rerender()
	elseif kind == "Cash" then
		targetCash, luckIn = a, b
		if state then state.d.cash = a end
		renderStats()
		updateBadges()
		updateKioskTag()
		if panels.Bonus.holder.Visible and bonusTick then bonusTick() end
	elseif kind == "Luck" then
		if state then state.luck = a end
		renderStats()
		luckScale.Scale = 1.4
		tween(luckScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
		toast("🍀 The table changed! LUCK x" .. a, rgb(120, 220, 140))
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
	elseif kind == "Lift" then
		if Request:InvokeServer("Lift") and state then
			_G.PlaySfx("Click")
			liftAnimation(state.d.dumbLevel)
		end
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
