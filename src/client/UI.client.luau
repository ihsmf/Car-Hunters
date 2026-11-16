local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.Shared.Config)
local Remotes = RS:WaitForChild("Remotes")
local Request, Fx = Remotes.Request, Remotes.Fx
local plr = Players.LocalPlayer
local U = C.UI

local state
local panels = {}
local renderers = {}

-- Звук
local function sound(id, group)
	local s = Instance.new("Sound")
	s.SoundId, s.SoundGroup, s.Parent = id, group, SoundService
	return s
end
local groups = {}
for _, n in { "Music", "SFX" } do
	groups[n] = Instance.new("SoundGroup")
	groups[n].Name, groups[n].Volume, groups[n].Parent = n, 0.5, SoundService
end
local music = sound(C.Sounds.Music, groups.Music)
music.Looped = true
music:Play()
local sfx = {}
for k, id in C.Sounds do
	if k ~= "Music" then sfx[k] = sound(id, groups.SFX) end
end
_G.PlaySfx = function(k) if sfx[k] then sfx[k]:Play() end end

-- UI-хелперы
local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	for _, c in children or {} do c.Parent = o end
	return o
end
local function corner(r) return new("UICorner", { CornerRadius = UDim.new(r or 0.25, 0) }) end
local function stroke(t) return new("UIStroke", { Color = U.Stroke, Thickness = t or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function grad(c) return new("UIGradient", { Rotation = 90, Color = ColorSequence.new(c:Lerp(Color3.new(1, 1, 1), 0.35), c) }) end

local function text(props)
	props.BackgroundTransparency = 1
	props.FontFace, props.TextScaled = U.Font, true
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	return new("TextLabel", props, { new("UIStroke", { Color = U.Stroke, Thickness = 2.5 }) })
end

local function button(props, color, onClick)
	local b = new("TextButton", {
		Size = props.Size, Position = props.Position, AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = Color3.new(1, 1, 1), AutoButtonColor = false, Text = "", LayoutOrder = props.LayoutOrder or 0,
	}, { corner(), stroke(3), grad(color), new("UIScale", {}),
		text({ Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.05, 0.1), Text = props.Text, Name = "Label" }) })
	local scale = b.UIScale
	b.MouseEnter:Connect(function() TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1.08 }):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(scale, TweenInfo.new(0.15), { Scale = 1 }):Play() end)
	b.Activated:Connect(function()
		_G.PlaySfx("Click")
		scale.Scale = 0.9
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		if onClick then onClick() end
	end)
	return b
end

local gui = new("ScreenGui", { Name = "Main", ResetOnSpawn = false, IgnoreGuiInset = true, Parent = plr:WaitForChild("PlayerGui") })

local toastLabel = text({ Size = UDim2.fromScale(0.5, 0.06), Position = UDim2.fromScale(0.25, 0.2), Text = "", TextTransparency = 1, Parent = gui })
toastLabel.UIStroke.Transparency = 1
local function toast(msg, color)
	toastLabel.Text, toastLabel.TextColor3 = msg, color or U.Accent
	toastLabel.TextTransparency, toastLabel.UIStroke.Transparency = 0, 0
	toastLabel.Position = UDim2.fromScale(0.25, 0.22)
	TweenService:Create(toastLabel, TweenInfo.new(1.6), { Position = UDim2.fromScale(0.25, 0.16), TextTransparency = 1 }):Play()
	TweenService:Create(toastLabel.UIStroke, TweenInfo.new(1.6), { Transparency = 1 }):Play()
end
_G.Toast = toast

local function call(action, arg)
	local ok, msg = Request:InvokeServer(action, arg)
	if msg then toast(msg, ok and U.Accent or Color3.fromRGB(255, 90, 90)) end
	if ok and msg then _G.PlaySfx("Reward") end
	return ok
end

-- Деньги
local cashLabel = text({ Size = UDim2.fromScale(0.3, 0.07), Position = UDim2.fromScale(0.35, 0.02), Text = "💵 0", TextColor3 = Color3.fromRGB(140, 255, 120), Parent = gui })
local statLabel = text({ Size = UDim2.fromScale(0.4, 0.035), Position = UDim2.fromScale(0.3, 0.09), Text = "", Parent = gui })

-- Панели
local function panel(name, title)
	local f = new("Frame", {
		Name = name, Size = UDim2.fromScale(0.5, 0.62), Position = UDim2.fromScale(0.5, 0.52), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = U.Panel, Visible = false, Parent = gui,
	}, { corner(0.06), stroke(5), new("UIAspectRatioConstraint", { AspectRatio = 1.5 }),
		text({ Size = UDim2.fromScale(0.8, 0.12), Position = UDim2.fromScale(0.1, -0.05), Text = title, TextColor3 = U.Accent }) })
	button({ Size = UDim2.fromScale(0.08, 0.12), Position = UDim2.fromScale(0.95, -0.04), Text = "✖" }, Color3.fromRGB(255, 80, 80), function() f.Visible = false end).Parent = f
	local list = new("ScrollingFrame", {
		Size = UDim2.fromScale(0.92, 0.8), Position = UDim2.fromScale(0.04, 0.13), BackgroundTransparency = 1,
		ScrollBarThickness = 8, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = f,
	}, {
		new("UIGridLayout", { CellSize = UDim2.new(0.31, 0, 0, 110), CellPadding = UDim2.new(0.02, 0, 0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6) }),
	})
	panels[name] = { frame = f, list = list }
	return list
end

local function open(name)
	if not state then return end
	for n, p in panels do p.frame.Visible = n == name and not p.frame.Visible end
	local p = panels[name]
	if p.frame.Visible then
		renderers[name](p.list)
		local sc = p.frame:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = p.frame })
		sc.Scale = 0.6
		TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

local function clear(list)
	for _, c in list:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
end

local function card(list, order, color, title, sub, btnText, onClick)
	local f = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = order, Parent = list }, {
		corner(0.15), stroke(3), grad(color),
		text({ Size = UDim2.fromScale(0.92, 0.3), Position = UDim2.fromScale(0.04, 0.04), Text = title }),
		text({ Size = UDim2.fromScale(0.92, 0.22), Position = UDim2.fromScale(0.04, 0.34), Text = sub }),
	})
	if btnText then
		button({ Size = UDim2.fromScale(0.8, 0.3), Position = UDim2.fromScale(0.1, 0.62), Text = btnText }, U.Accent, onClick).Parent = f
	end
	return f
end

-- Настройки
panel("Settings", "⚙️ Настройки")
function renderers.Settings(list)
	clear(list)
	for i, n in { "Music", "SFX" } do
		local g = groups[n]
		local label = (n == "Music" and "🎵 Музыка" or "🔊 Эффекты")
		local f = card(list, i, Color3.fromRGB(120, 140, 255), label, "Громкость: " .. math.round(g.Volume * 100) .. "%")
		for j, d in { { "➖", -0.1 }, { "➕", 0.1 }, { g.Volume > 0 and "🔇" or "🔈", 0 } } do
			button({ Size = UDim2.fromScale(0.27, 0.3), Position = UDim2.fromScale(0.04 + (j - 1) * 0.32, 0.62), Text = d[1] }, U.Accent, function()
				g.Volume = d[2] == 0 and (g.Volume > 0 and 0 or 0.5) or math.clamp(g.Volume + d[2], 0, 1)
				renderers.Settings(list)
			end).Parent = f
		end
	end
end

-- Инвентарь
panel("Inventory", "🎒 Инвентарь")
function renderers.Inventory(list)
	clear(list)
	for i, it in state.d.inv do
		local ch = C.Characters[it.id]
		local r = C.Rarities[ch.rarity]
		local f = card(list, -ch.income * 1000 + i, r[2], ch.name, r[1] .. " • 💵" .. C.Short(ch.income) .. "/с")
		button({ Size = UDim2.fromScale(0.55, 0.3), Position = UDim2.fromScale(0.04, 0.62), Text = it.eq and "Убрать" or "На базу" }, it.eq and Color3.fromRGB(255, 120, 120) or Color3.fromRGB(90, 210, 120), function()
			if call("Equip", i) then renderers.Inventory(list) end
		end).Parent = f
		button({ Size = UDim2.fromScale(0.35, 0.3), Position = UDim2.fromScale(0.61, 0.62), Text = "Продать" }, U.Accent, function()
			if call("Sell", i) then renderers.Inventory(list) end
		end).Parent = f
	end
end

-- Бонусы
panel("Daily", "🎁 Бонусы")
function renderers.Daily(list)
	clear(list)
	local day = os.time() // 86400
	local dd = state.d.daily
	local next = (dd.day == day - 1) and dd.streak % #C.Daily + 1 or (dd.day == day and dd.streak or 1)
	card(list, 0, Color3.fromRGB(255, 120, 170), "День " .. next .. "/" .. #C.Daily, "💵 " .. C.Short(C.Daily[next]),
		dd.day == day and "✅ Получено" or "Забрать!", function()
			if call("Daily") then renderers.Daily(list) end
		end)
	for i, p in C.Playtime do
		local left = p[1] * 60 - (os.time() - state.join)
		card(list, i, Color3.fromRGB(255, 170, 80), "⏱️ " .. p[1] .. " мин", "💵 " .. C.Short(p[2]),
			state.claimed[i] and "✅" or left > 0 and string.format("%d:%02d", left // 60, left % 60) or "Забрать!", function()
				if call("Playtime", i) then renderers.Daily(list) end
			end)
	end
end

-- Донат-магазин
panel("Shop", "💎 Магазин")
function renderers.Shop(list)
	clear(list)
	local i = 0
	for key, gp in C.GamePasses do
		i += 1
		card(list, i, Color3.fromRGB(255, 175, 40), gp.icon .. " " .. gp.name, "Гейм-пасс", state.d.passes[key] and "✅ Куплено" or "Купить R$", function()
			call("Pass", key)
		end)
	end
	for j, p in C.Products do
		card(list, 10 + j, Color3.fromRGB(90, 210, 120), p.icon .. " " .. C.Short(p.cash), "Пачка денег", "Купить R$", function() call("Product", j) end)
	end
end

-- Магазин киёв + прокачка (открывается у ларька на базе)
panel("Cues", "🎱 Кии и прокачка")
function renderers.Cues(list)
	clear(list)
	local d = state.d
	card(list, 0, Color3.fromRGB(255, 90, 90), "💪 Гантеля ур." .. d.dumbLevel, "+" .. d.dumbLevel .. " силы за подход", "💵 " .. C.Short(C.LiftCost(d.dumbLevel)), function()
		if call("UpDumb") then renderers.Cues(list) end
	end)
	card(list, 1, Color3.fromRGB(120, 140, 255), "🎱 Кий ур." .. d.cueLevel, "+10% к дальности", "💵 " .. C.Short(C.CueUpCost(d.cueLevel)), function()
		if call("UpCue") then renderers.Cues(list) end
	end)
	for i, cue in C.Cues do
		local owned = d.cues[tostring(i)]
		card(list, 1 + i, cue[4], cue[1], "x" .. cue[2] .. " дальность", d.cue == i and "✅ Выбран" or owned and "Выбрать" or "💵 " .. C.Short(cue[3]), function()
			if call("Cue", i) then renderers.Cues(list) end
		end)
	end
end

-- Кнопки меню слева
local menu = new("Frame", { Size = UDim2.fromScale(0.09, 0.5), Position = UDim2.fromScale(0.01, 0.25), BackgroundTransparency = 1, Parent = gui }, {
	new("UIListLayout", { Padding = UDim.new(0.03, 0), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local order = { "Settings", "Inventory", "Daily", "Shop" }
for i, key in order do
	local b = U.Buttons[key]
	local btn = button({ Size = UDim2.fromScale(1, 0.22), Text = "", LayoutOrder = i }, b[3], function() open(key) end)
	btn.Label:Destroy()
	text({ Size = UDim2.fromScale(1, 0.6), Text = b[1], Parent = btn })
	text({ Size = UDim2.fromScale(1, 0.32), Position = UDim2.fromScale(0, 0.64), Text = b[2], Parent = btn })
	new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = btn })
	btn.Parent = menu
end

-- Кнопка броска с полосой силы
local power, charging, t0 = 0, false, 0
local bar = new("Frame", { Size = UDim2.fromScale(0.3, 0.035), Position = UDim2.fromScale(0.35, 0.8), BackgroundColor3 = Color3.fromRGB(40, 30, 60), Parent = gui },
	{ corner(1), stroke(3) })
local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = bar }, {
	corner(1), new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 220, 90)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 220, 40)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 60)) }) }),
})
local throwBtn = button({ Size = UDim2.fromScale(0.16, 0.09), Position = UDim2.fromScale(0.42, 0.86), Text = "🎱 УДАР!" }, Color3.fromRGB(255, 90, 90))
throwBtn.Parent = gui
throwBtn.MouseButton1Down:Connect(function()
	if not _G.ThrowBusy then charging, power, t0 = true, 0, 0 end
end)
game:GetService("UserInputService").InputEnded:Connect(function(input)
	if not charging or (input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch) then return end
	charging = false
	local ok, msg = Request:InvokeServer("Throw", power)
	if msg then toast(msg, Color3.fromRGB(255, 90, 90)) end
	if ok then _G.PlaySfx("Hit") end
end)

game:GetService("RunService").RenderStepped:Connect(function(dt)
	if charging then t0 += dt end
	power = charging and (1 - math.abs(((t0 * 0.8) % 2) - 1)) or power
	fill.Size = UDim2.fromScale(charging and power or 0, 1)
end)

-- События сервера
Fx.OnClientEvent:Connect(function(kind, a)
	if kind == "State" then
		state = a
		cashLabel.Text = "💵 " .. C.Short(a.d.cash)
		statLabel.Text = string.format("💪 %s   📈 %s/с   🍀 +%d", C.Short(a.d.strength), C.Short(a.income), a.luck)
		for n, p in panels do if p.frame.Visible then renderers[n](p.list) end end
	elseif kind == "Cash" then
		cashLabel.Text = "💵 " .. C.Short(a)
	elseif kind == "Luck" then
		toast("🍀 Стол меняется! Удача +" .. a, Color3.fromRGB(120, 255, 140))
	elseif kind == "Open" then
		if not panels[a].frame.Visible then open(a) end
	elseif kind == "Lift" then
		if Request:InvokeServer("Lift") then
			_G.PlaySfx("Click")
			toast("+" .. state.d.dumbLevel .. " 💪", Color3.fromRGB(255, 120, 120))
		end
	end
end)
