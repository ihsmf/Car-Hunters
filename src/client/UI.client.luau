-- HUD + panels. Layout follows the Figma file "Billiard Hunters — UI" (1920x1080 frame, scaled to screen).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.Shared.Config)
local U = C.UI
local plr = Players.LocalPlayer

-- ===== Sound =====
local groups = {}
for _, n in { "Music", "SFX" } do
	local g = Instance.new("SoundGroup")
	g.Name, g.Volume, g.Parent = n, 0.5, SoundService
	groups[n] = g
end
local sounds = {}
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
local function stroke(t) return new("UIStroke", { Color = U.Ink, Thickness = t, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function grad(a, b) return new("UIGradient", { Rotation = 90, Color = ColorSequence.new(a, b) }) end

local function text(str, size, color, props)
	props = props or {}
	props.BackgroundTransparency, props.FontFace, props.Text = 1, U.Font, str
	props.TextSize, props.TextColor3 = size, color or Color3.new(1, 1, 1)
	props.Size = props.Size or UDim2.new(1, 0, 0, size * 1.2)
	return new("TextLabel", props, { new("UIStroke", { Color = U.Ink, Thickness = math.max(2, size / 11) }) })
end

-- Cartoon box with a hard ink drop-shadow (Figma: drop shadow 0/6, radius 0)
local function box(props, top, bottom, radius, strokeW)
	local holder = new("Frame", { Size = props.Size, Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, BackgroundTransparency = 1, LayoutOrder = props.LayoutOrder or 0, Name = props.Name or "Box", Parent = props.Parent })
	new("Frame", { Name = "Shadow", Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 6), BackgroundColor3 = U.Ink, Parent = holder }, { corner(radius) })
	local body = new("Frame", { Name = "Body", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = holder }, { corner(radius), stroke(strokeW or 4), grad(top, bottom) })
	return holder, body
end

local function button(props, colors, label, size, onClick)
	local holder, body = box(props, colors[1], colors[2], props.Radius or 16, 3)
	local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5, Parent = holder })
	local scale = new("UIScale", { Parent = holder })
	if label then text(label, size or 22, nil, { Size = UDim2.fromScale(1, 1), Parent = body, TextScaled = false }) end
	hit.MouseEnter:Connect(function() TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1.07 }):Play() end)
	hit.MouseLeave:Connect(function() TweenService:Create(scale, TweenInfo.new(0.15), { Scale = 1 }):Play() end)
	hit.Activated:Connect(function()
		_G.PlaySfx("Click")
		scale.Scale = 0.88
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		if onClick then onClick() end
	end)
	return holder, body, hit
end

-- ===== Root (design space 1920x1080) =====
local gui = new("ScreenGui", { Name = "Main", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = plr:WaitForChild("PlayerGui") })
local root = new("Frame", { Size = UDim2.fromOffset(1920, 1080), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = gui })
local rootScale = new("UIScale", { Parent = root })
local function rescale()
	local v = workspace.CurrentCamera.ViewportSize
	rootScale.Scale = math.max(0.42, math.min(v.X / 1920, v.Y / 1080))
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()

-- ===== Remotes (the UI is visible even while the server is starting) =====
local Remotes = RS:WaitForChild("Remotes")
local Request, Fx = Remotes:WaitForChild("Request"), Remotes:WaitForChild("Fx")
local state

-- Toast
local toastLabel = text("", 54, U.Title, { Size = UDim2.fromOffset(1400, 70), Position = UDim2.fromOffset(260, 210), Parent = root, ZIndex = 20 })
toastLabel.TextTransparency, toastLabel.UIStroke.Transparency = 1, 1
local function toast(msg, color)
	toastLabel.Text, toastLabel.TextColor3 = msg, color or U.Title
	toastLabel.TextTransparency, toastLabel.UIStroke.Transparency = 0, 0
	toastLabel.Position = UDim2.fromOffset(260, 230)
	local info = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(toastLabel, info, { Position = UDim2.fromOffset(260, 180), TextTransparency = 1 }):Play()
	TweenService:Create(toastLabel.UIStroke, info, { Transparency = 1 }):Play()
end
_G.Toast = toast

local function call(action, arg)
	local ok, msg = Request:InvokeServer(action, arg)
	if msg then
		toast(msg, ok and U.Title or U.Bad)
		if ok then _G.PlaySfx("Reward") end
	end
	return ok
end

-- ===== HUD =====
local hud = new("Frame", { Name = "HUD", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = root })
local cashPill = new("Frame", { Size = UDim2.fromOffset(260, 78), Position = UDim2.fromOffset(960, 24), AnchorPoint = Vector2.new(0.5, 0), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = U.Ink, Parent = hud }, {
	corner(40), new("UIPadding", { PaddingLeft = UDim.new(0, 36), PaddingRight = UDim.new(0, 36) }),
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 14) }),
})
text("💵", 48, nil, { Size = UDim2.fromOffset(56, 60), Parent = cashPill })
local cashLabel = text("0", 56, U.Money, { Size = UDim2.fromOffset(0, 70), AutomaticSize = Enum.AutomaticSize.X, Parent = cashPill })
local statLabel = text("", 28, nil, { Size = UDim2.fromOffset(1000, 36), Position = UDim2.fromOffset(460, 122), Parent = hud })
local luckPill = new("Frame", { Size = UDim2.fromOffset(380, 58), Position = UDim2.fromOffset(960, 168), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), Parent = hud }, {
	corner(29), stroke(4), grad(Color3.fromRGB(150, 240, 120), Color3.fromRGB(60, 180, 70)),
})
local luckLabel = text("🍀 LUCK x1", 34, nil, { Size = UDim2.fromScale(1, 1), Parent = luckPill })
local luckScale = new("UIScale", { Parent = luckPill })

local menu = new("Frame", { Size = UDim2.fromOffset(120, 560), Position = UDim2.fromOffset(28, 300), BackgroundTransparency = 1, Parent = hud }, {
	new("UIListLayout", { Padding = UDim.new(0, 18), SortOrder = Enum.SortOrder.LayoutOrder }),
})

-- Power bar + SHOOT button
local hint = text("Hold SHOOT to charge • release to shoot", 22, nil, { Size = UDim2.fromOffset(600, 28), Position = UDim2.fromOffset(660, 806), Parent = hud })
local bar = new("Frame", { Size = UDim2.fromOffset(560, 36), Position = UDim2.fromOffset(680, 850), BackgroundColor3 = U.Ink, Parent = hud }, {
	corner(18), new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 4 }),
})
local fill = new("Frame", { Size = UDim2.new(0, 0, 1, -8), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = Color3.new(1, 1, 1), Parent = bar }, {
	corner(14), new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 220, 90)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 220, 40)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 60)) }) }),
})
local _, _, shootHit = button({ Size = UDim2.fromOffset(330, 92), Position = UDim2.fromOffset(960, 906), AnchorPoint = Vector2.new(0.5, 0), Parent = hud, Radius = 34 }, U.Red, "🎱 SHOOT!", 52)

-- ===== Panels =====
local panels, renderers = {}, {}
local function panel(key, title)
	local holder, body = box({ Size = UDim2.fromOffset(890, 640), Position = UDim2.fromOffset(960, 560), AnchorPoint = Vector2.new(0.5, 0.5), Parent = root, Name = key }, U.Panel, U.Panel, 40, 6)
	holder.Visible, holder.ZIndex = false, 10
	text(title, 52, U.Title, { Size = UDim2.new(1, -140, 0, 70), Position = UDim2.fromOffset(40, 20), Parent = body, TextXAlignment = Enum.TextXAlignment.Left })
	local sub = text("", 24, U.Ink, { Size = UDim2.new(1, -140, 0, 30), Position = UDim2.fromOffset(42, 86), Parent = body, TextXAlignment = Enum.TextXAlignment.Left })
	sub.UIStroke.Thickness = 0
	button({ Size = UDim2.fromOffset(64, 56), Position = UDim2.new(1, -96, 0, 26), Parent = body, Radius = 18 }, U.Red, "✖", 30, function() holder.Visible = false end)
	local list = new("ScrollingFrame", {
		Size = UDim2.new(1, -60, 1, -150), Position = UDim2.fromOffset(42, 128), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 10, ScrollBarImageColor3 = U.Ink, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = body,
	}, {
		new("UIGridLayout", { CellSize = UDim2.fromOffset(250, 176), CellPadding = UDim2.fromOffset(18, 18), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 2) }),
	})
	panels[key] = { holder = holder, list = list, sub = sub }
end

local function clear(list)
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then c:Destroy() end
	end
end

-- Card (Figma component "Card"): title, subtitle, up to 3 action buttons
local function card(list, order, top, bottom, title, sub, actions)
	local holder, body = box({ Size = UDim2.fromOffset(250, 170), LayoutOrder = order, Parent = list }, top, bottom, 22, 4)
	text(title, 26, nil, { Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 12), Parent = body, TextScaled = true })
	text(sub, 18, nil, { Size = UDim2.new(1, -16, 0, 24), Position = UDim2.fromOffset(8, 50), Parent = body, TextScaled = true })
	local n = #(actions or {})
	for i, a in actions or {} do
		local w = (226 - (n - 1) * 8) / n
		button({ Size = UDim2.fromOffset(w, 50), Position = UDim2.fromOffset(12 + (i - 1) * (w + 8), 96), Parent = body }, a[3] or U.Action, a[1], n > 2 and 26 or 22, a[2])
	end
	return holder
end

local function open(key)
	if not state then return end
	for k, p in panels do
		p.holder.Visible = (k == key) and not p.holder.Visible
	end
	local p = panels[key]
	if p.holder.Visible then
		renderers[key]()
		local sc = p.holder:FindFirstChild("Pop") or new("UIScale", { Name = "Pop", Parent = p.holder })
		sc.Scale = 0.6
		TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

-- Settings
panel("Settings", "⚙️ Settings")
renderers.Settings = function()
	local p = panels.Settings
	clear(p.list)
	p.sub.Text = "Music and sound effects"
	for i, key in { "Music", "SFX" } do
		local g = groups[key]
		local function set(v)
			g.Volume = math.clamp(v, 0, 1)
			renderers.Settings()
		end
		card(p.list, i, Color3.fromRGB(169, 183, 255), Color3.fromRGB(111, 130, 255), key == "Music" and "🎵 Music" or "🔊 Sound FX", "Volume " .. math.round(g.Volume * 100) .. "%", {
			{ "−", function() set(g.Volume - 0.1) end },
			{ "+", function() set(g.Volume + 0.1) end },
			{ g.Volume > 0 and "🔇" or "🔈", function() set(g.Volume > 0 and 0 or 0.5) end },
		})
	end
end

-- Inventory
panel("Inventory", "🎒 Inventory")
renderers.Inventory = function()
	local p = panels.Inventory
	clear(p.list)
	local on = 0
	for _, it in state.d.inv do
		if it.eq then on += 1 end
	end
	p.sub.Text = string.format("%d / %d characters  •  on base %d / %d", #state.d.inv, C.MaxInventory, on, C.MaxEquipped)
	for i, it in state.d.inv do
		local ch = C.Characters[it.id]
		local r = C.Rarities[ch.rarity]
		card(p.list, -ch.rarity * 1000 + i, r[2]:Lerp(Color3.new(1, 1, 1), 0.35), r[2], ch.name, r[1] .. " • $" .. C.Short(ch.income) .. "/s", {
			{ it.eq and "Unequip" or "Equip", function()
				if call("Equip", i) then renderers.Inventory() end
			end, it.eq and U.Red or U.Action },
			{ "Sell", function()
				if call("Sell", i) then renderers.Inventory() end
			end },
		})
	end
	if #state.d.inv == 0 then card(p.list, 0, U.Cues[1], U.Cues[2], "Empty!", "Shoot the ball to hunt pros") end
end

-- Bonus (daily streak + playtime)
panel("Bonus", "🎁 Bonuses")
renderers.Bonus = function()
	local p = panels.Bonus
	clear(p.list)
	local day = os.time() // 86400
	local dd = state.d.daily
	local claimed = dd.day == day
	local nextDay = claimed and dd.streak or ((dd.day == day - 1) and dd.streak % #C.Daily + 1 or 1)
	p.sub.Text = "Log in every day for a bigger streak • stay to earn playtime gifts"
	card(p.list, 0, Color3.fromRGB(255, 158, 200), Color3.fromRGB(255, 92, 158), "📅 Day " .. nextDay .. " / " .. #C.Daily, "$" .. C.Short(C.Daily[nextDay]), {
		{ claimed and "✅ Claimed" or "Claim!", function()
			if not claimed and call("Daily") then renderers.Bonus() end
		end },
	})
	for i, pt in C.Playtime do
		local left = pt[1] * 60 - (os.time() - state.join)
		local label = state.claimed[i] and "✅" or left > 0 and string.format("%d:%02d", left // 60, left % 60) or "Claim!"
		card(p.list, i, Color3.fromRGB(255, 200, 120), Color3.fromRGB(255, 150, 60), "⏱️ " .. pt[1] .. " min", "$" .. C.Short(pt[2]), {
			{ label, function()
				if call("Playtime", i) then renderers.Bonus() end
			end },
		})
	end
end

-- Donate shop
panel("Shop", "💎 Shop")
renderers.Shop = function()
	local p = panels.Shop
	clear(p.list)
	p.sub.Text = "Game Passes and cash packs"
	for i, gp in C.GamePasses do
		local owned = state.d.passes[gp.key]
		card(p.list, i, U.Menu[4][4], U.Menu[4][5], gp.icon .. " " .. gp.name, gp.desc, {
			{ owned and "✅ Owned" or "Buy R$", function()
				if not owned then call("Pass", gp.key) end
			end, U.Red },
		})
	end
	for i, pr in C.Products do
		card(p.list, 10 + i, Color3.fromRGB(142, 227, 166), Color3.fromRGB(63, 191, 106), pr.icon .. " $" .. C.Short(pr.cash), "Cash pack", {
			{ "Buy R$", function() call("Product", i) end, U.Red },
		})
	end
end

-- Cue shop + upgrades (opened at the stall on the base)
panel("Cues", "🎱 Cue Shop")
renderers.Cues = function()
	local p = panels.Cues
	clear(p.list)
	local d = state.d
	local cur = C.Cues[d.cue]
	p.sub.Text = string.format("Each upgrade replaces your cue  •  shot power x%s", C.CueMult(d))
	card(p.list, 0, C.UI.Money:Lerp(Color3.new(1, 1, 1), 0.3), Color3.fromRGB(63, 191, 106), "✅ " .. cur[1], "In your hands • x" .. cur[2])
	local nextCue = C.Cues[d.cue + 1]
	if nextCue then
		card(p.list, 1, nextCue[4]:Lerp(Color3.new(1, 1, 1), 0.35), nextCue[4], "⬆ " .. nextCue[1], "x" .. nextCue[2] .. " distance", {
			{ "Upgrade $" .. C.Short(nextCue[3]), function()
				if call("Cue") then renderers.Cues() end
			end },
		})
	else
		card(p.list, 1, U.Action[1], U.Action[2], "🏆 Max cue!", "You own the best cue")
	end
	for i = d.cue + 2, #C.Cues do -- locked tiers: unlock them one after another
		local cue = C.Cues[i]
		card(p.list, i, Color3.fromRGB(120, 120, 135), Color3.fromRGB(70, 70, 85), "🔒 " .. cue[1], "x" .. cue[2] .. " • $" .. C.Short(cue[3]))
	end
end

-- Menu buttons (Figma component "MenuButton": icon + label)
for i, m in U.Menu do
	local holder, body = button({ Size = UDim2.fromOffset(120, 120), LayoutOrder = i, Parent = menu, Radius = 28 }, { m[4], m[5] }, nil, nil, function() open(m[1]) end)
	text(m[2], 54, nil, { Size = UDim2.new(1, 0, 0, 66), Position = UDim2.fromOffset(0, 8), Parent = body })
	text(m[3], 22, nil, { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 80), Parent = body })
	holder.Name = m[1]
end

-- ===== Shooting =====
local power, charging, t0 = 0, false, 0
shootHit.MouseButton1Down:Connect(function()
	if not _G.ThrowBusy and state then charging, power, t0 = true, 0, 0 end
end)
UserInputService.InputEnded:Connect(function(input)
	if not charging then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	charging = false
	local ok, msg = Request:InvokeServer("Throw", power)
	if msg then toast(msg, U.Bad) end
	if not ok then fill.Size = UDim2.new(0, 0, 1, -8) end
end)
RunService.RenderStepped:Connect(function(dt)
	if not charging then return end
	t0 += dt
	power = 1 - math.abs(((t0 * 0.8) % 2) - 1)
	fill.Size = UDim2.new(power, -8, 1, -8)
end)

-- ===== Dumbbell lift: the dumbbell goes up and down, the player raises the arms, "+N" floats up =====
local lifting = false
local function liftAnimation(gain)
	if lifting or not state then return end
	local base = workspace.World:FindFirstChild("Base" .. state.slot)
	local db = base and base:FindFirstChild("Dumbbell")
	if not db then return end
	lifting = true
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if animator then
		local a = Instance.new("Animation")
		a.AnimationId = "rbxassetid://507770677"
		local ok, track = pcall(animator.LoadAnimation, animator, a)
		if ok and track then track:Play(0.1, 1, 2.2) end
	end
	local bb = new("BillboardGui", { Size = UDim2.fromOffset(140, 60), StudsOffset = Vector3.new(0, 4, 0), AlwaysOnTop = true, Parent = db.PrimaryPart or db:FindFirstChildWhichIsA("BasePart") })
	local l = text("+" .. gain .. " 💪", 40, Color3.fromRGB(255, 120, 120), { Size = UDim2.fromScale(1, 1), Parent = bb })
	TweenService:Create(bb, TweenInfo.new(0.8), { StudsOffset = Vector3.new(0, 8, 0) }):Play()
	TweenService:Create(l, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
	TweenService:Create(l.UIStroke, TweenInfo.new(0.8), { Transparency = 1 }):Play()
	task.delay(0.9, bb.Destroy, bb)
	local cf0 = db:GetPivot()
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = math.min((os.clock() - t0) / 0.4, 1)
		db:PivotTo(cf0 * CFrame.new(0, math.sin(t * math.pi) * 2.6, 0))
		if t >= 1 then
			conn:Disconnect()
			db:PivotTo(cf0)
			lifting = false
		end
	end)
end

-- ===== Server events =====
local luckIn = C.LuckCycle
local function renderStats()
	if not state then return end
	statLabel.Text = string.format("💪 %s     📈 $%s/s", C.Short(state.d.strength), C.Short(state.income))
	luckLabel.Text = string.format("🍀 LUCK x%d  •  %ds", state.luck, luckIn)
end
Fx.OnClientEvent:Connect(function(kind, a, b)
	if kind == "State" then
		state = a
		_G.MySlot = a.slot
		_G.MyCue = a.d.cue
		cashLabel.Text = C.Short(a.d.cash)
		renderStats()
		for k, p in panels do
			if p.holder.Visible then renderers[k]() end
		end
	elseif kind == "Cash" then
		cashLabel.Text, luckIn = C.Short(a), b
		renderStats()
		if panels.Bonus.holder.Visible then renderers.Bonus() end
	elseif kind == "Luck" then
		if state then state.luck = a end
		renderStats()
		luckScale.Scale = 1.5
		TweenService:Create(luckScale, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		toast("🍀 The table changed! LUCK x" .. a, Color3.fromRGB(120, 255, 140))
	elseif kind == "Open" then
		if not panels[a].holder.Visible then open(a) end
	elseif kind == "Toast" then
		toast(a, b and U.Title or U.Bad)
		if b then _G.PlaySfx("Reward") end
	elseif kind == "CueSwap" then -- the old cue disappears in a puff
		local puff = Instance.new("Part")
		puff.Anchored, puff.CanCollide, puff.Transparency, puff.Size, puff.Position = true, false, 1, Vector3.one, a
		local e = Instance.new("ParticleEmitter")
		e.Color, e.Speed, e.Lifetime = ColorSequence.new(U.Title, Color3.new(1, 1, 1)), NumberRange.new(6, 12), NumberRange.new(0.4, 0.8)
		e.SpreadAngle, e.Size, e.LightEmission, e.Rate = Vector2.new(180, 180), NumberSequence.new(0.8, 0), 1, 0
		e.Parent, puff.Parent = puff, workspace
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
end

Request:InvokeServer("Sync")
