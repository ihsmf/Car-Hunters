-- Бросок: кий бьёт биток -> биток разбивает пирамиду -> шары разлетаются с отскоками
-- от бортов и падают в лузы -> биток доезжает до своей зоны и падает в её лузу.
-- Для своего броска — кинематографичная камера: зум, аутзум, тряска, затемнение, вспышки, перелив цветов.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.Shared.Config)
local Fx = RS:WaitForChild("Remotes").Fx
local Models = RS:FindFirstChild("Models")
local plr = Players.LocalPlayer
local cam = workspace.CurrentCamera
local T, N = C.Table, #C.Rarities
local zoneLen = T.Length / N
local FELT_Y = 3.3
local R = 1.1 -- радиус шара
local rng = Random.new()
local mySlot

local function sfx(k) if _G.PlaySfx then _G.PlaySfx(k) end end
local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function laneX(slot) return -T.Width / 2 + (slot - 0.5) * T.Width / T.Lanes end

local function ball(color, size)
	local src = Models and Models:FindFirstChild("Ball")
	local b = src and src:Clone() or Instance.new("Part")
	if not src then b.Shape = Enum.PartType.Ball end
	b.Size, b.Color, b.Material = Vector3.one * size, color, Enum.Material.SmoothPlastic
	b.Anchored, b.CanCollide, b.CastShadow = true, false, true
	b.Parent = workspace
	return b
end

local function burst(b, color, n)
	local p = Instance.new("ParticleEmitter")
	p.Color, p.LightEmission, p.Speed = ColorSequence.new(color), 1, NumberRange.new(8, 20)
	p.Lifetime, p.SpreadAngle, p.Rate = NumberRange.new(0.4, 0.9), Vector2.new(180, 180), 0
	p.Size, p.Parent = NumberSequence.new(0.7, 0), b
	p:Emit(n)
end

local function drop(b, at)
	sfx("Pocket")
	burst(b, b.Color, 25)
	tween(b, 0.45, { Size = Vector3.one * 0.1, CFrame = CFrame.new(at - Vector3.new(0, 1.6, 0)) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.delay(1, b.Destroy, b)
end

-- ===== Лузы длинного стола (как в Map.luau) =====
local pockets = {}
for i = 1, N do
	for _, sx in { -1, 1 } do
		table.insert(pockets, Vector3.new(sx * T.Width / 2, FELT_Y + R, T.StartZ + (i - 0.5) * zoneLen))
	end
end
local function nearestPocket(pos)
	local best, bd
	for _, p in pockets do
		local d = (p - pos).Magnitude
		if not bd or d < bd then best, bd = p, d end
	end
	return best, bd
end

-- ===== Пирамиды на каждой дорожке =====
local RACK_Z = T.StartZ + 16
local rackColors = { Color3.fromRGB(255, 220, 40), Color3.fromRGB(40, 90, 255), Color3.fromRGB(255, 50, 50), Color3.fromRGB(140, 40, 200), Color3.fromRGB(255, 130, 20), Color3.fromRGB(30, 160, 60), Color3.fromRGB(130, 30, 30), Color3.fromRGB(20, 20, 20), Color3.fromRGB(255, 120, 200), Color3.fromRGB(0, 200, 200) }
local racks = {}

local function buildRack(slot)
	local list = {}
	local x0 = laneX(slot)
	local k = 0
	for row = 0, 3 do
		for j = 0, row do
			k += 1
			local pos = Vector3.new(x0 + (j - row / 2) * R * 2.05, FELT_Y + R, RACK_Z + row * R * 1.8)
			local b = ball(rackColors[k], R * 2)
			b.CFrame, b.Size = CFrame.new(pos), Vector3.one * 0.1
			tween(b, 0.4, { Size = Vector3.one * R * 2 }, Enum.EasingStyle.Back)
			table.insert(list, b)
		end
	end
	racks[slot] = list
end
for s = 1, T.Lanes do buildRack(s) end

-- Физика разлёта: трение, отскоки от бортов и друг от друга, «магнит» луз на малой скорости
local function breakRack(slot, power)
	local list = racks[slot]
	racks[slot] = nil
	local bodies = {}
	for _, b in list do
		local p = b.Position
		local away = Vector3.new(p.X - laneX(slot), 0, p.Z - RACK_Z + 3).Unit
		local dir = (away + Vector3.new(rng:NextNumber(-0.5, 0.5), 0, 0.4)).Unit
		table.insert(bodies, { b = b, p = p, v = dir * rng:NextNumber(30, 55) * (0.6 + power * 0.6), rot = CFrame.new() })
	end
	local alive = #bodies
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		for i, o in bodies do
			if o.done then continue end
			local speed = o.v.Magnitude
			local target, d = nearestPocket(o.p)
			if d < 2.3 then
				o.done, alive = true, alive - 1
				o.b.CFrame = CFrame.new(target)
				drop(o.b, target)
				continue
			end
			o.v *= math.max(0, 1 - 0.55 * dt)
			if speed < 14 then -- шар «ищет» лузу, чтобы все шары оказались забиты
				o.v += (target - o.p).Unit * 40 * dt
				o.v = o.v.Unit * math.max(o.v.Magnitude, 8)
			end
			o.p += o.v * dt
			local lim = T.Width / 2 - R
			if math.abs(o.p.X) > lim then -- отскок от борта
				o.p = Vector3.new(math.sign(o.p.X) * lim, o.p.Y, o.p.Z)
				o.v = Vector3.new(-o.v.X * 0.8, 0, o.v.Z)
				sfx("Hit")
			end
			if o.p.Z < T.StartZ + R then
				o.p = Vector3.new(o.p.X, o.p.Y, T.StartZ + R)
				o.v = Vector3.new(o.v.X, 0, -o.v.Z * 0.8)
			end
			for j = i + 1, #bodies do -- упругое столкновение шаров
				local q = bodies[j]
				if not q.done then
					local delta = q.p - o.p
					local dist = delta.Magnitude
					if dist < R * 2 and dist > 0 then
						local n = delta / dist
						local rel = (o.v - q.v):Dot(n)
						if rel > 0 then
							o.v -= n * rel
							q.v += n * rel
						end
						o.p -= n * (R * 2 - dist) / 2
						q.p += n * (R * 2 - dist) / 2
					end
				end
			end
			local axis = o.v.Magnitude > 0.01 and Vector3.yAxis:Cross(o.v.Unit) or Vector3.xAxis
			o.rot = CFrame.fromAxisAngle(axis, o.v.Magnitude * dt / R) * o.rot
			o.b.CFrame = CFrame.new(o.p) * o.rot
		end
		if alive == 0 then
			conn:Disconnect()
			task.delay(1.5, buildRack, slot)
		end
	end)
end

-- ===== Эффекты экрана =====
local fxGui = Instance.new("ScreenGui")
fxGui.Name, fxGui.IgnoreGuiInset, fxGui.ResetOnSpawn, fxGui.DisplayOrder = "CinemaFx", true, false, 10
fxGui.Parent = plr:WaitForChild("PlayerGui")

local function frame(props)
	local f = Instance.new("Frame")
	f.BorderSizePixel, f.Size = 0, UDim2.fromScale(1, 1)
	for k, v in props do f[k] = v end
	f.Parent = props.Parent or fxGui
	return f
end
local flash = frame({ BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1 })
local dim = frame({ BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1 })
local bars = {} -- кинематографичные полосы
for i, y in { 0, 1 } do
	bars[i] = frame({ BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(0, y), Position = UDim2.fromScale(0, y) })
end
local cc = Instance.new("ColorCorrectionEffect")
cc.Parent = Lighting
local blur = Instance.new("BlurEffect")
blur.Size, blur.Parent = 0, Lighting

local function doFlash(color, strength)
	flash.BackgroundColor3, flash.BackgroundTransparency = color, 1 - (strength or 0.8)
	tween(flash, 0.5, { BackgroundTransparency = 1 })
end
local function letterbox(on)
	for _, b in bars do tween(b, 0.4, { Size = UDim2.fromScale(1, on and 0.11 or 0) }) end
end

-- тряска: shake = амплитуда в стадах, затухает
local shake = 0
local function hardShake(a) shake = math.max(shake, a) end

-- окно с выпавшим персонажем: лучи, радужный градиент, пульсация
local function reveal(ch)
	local r = C.Rarities[ch.rarity]
	local root = frame({ BackgroundTransparency = 1 })
	local rays = frame({ Parent = root, BackgroundTransparency = 1, Size = UDim2.fromOffset(900, 900), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45) })
	for k = 1, 12 do -- луч внутри повёрнутого полноразмерного «шарнира» вращается вокруг центра
		local pivot = frame({ Parent = rays, BackgroundTransparency = 1, Rotation = k * 30 })
		frame({ Parent = pivot, BackgroundColor3 = r[2], BackgroundTransparency = 0.55, Size = UDim2.new(0, 40, 0.5, 0), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5) })
	end
	local function label(text, y, h, color)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency, l.TextScaled, l.FontFace = 1, true, C.UI.Font
		l.Size, l.AnchorPoint, l.Position = UDim2.fromScale(0.8, h), Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, y)
		l.Text, l.TextColor3, l.Parent = text, color, root
		local st = Instance.new("UIStroke")
		st.Thickness, st.Color, st.Parent = 5, C.UI.Stroke, l
		local sc = Instance.new("UIScale")
		sc.Scale, sc.Parent = 0, l
		return l, sc
	end
	local title, s1 = label(string.upper(r[1]) .. "!", 0.34, 0.14, Color3.new(1, 1, 1))
	local name, s2 = label(ch.name, 0.48, 0.09, r[2])
	local _, s3 = label("💵 " .. C.Short(ch.income) .. "/с", 0.58, 0.06, Color3.fromRGB(140, 255, 120))
	local grad = Instance.new("UIGradient")
	grad.Color = ch.rarity >= 10 and ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)), ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 230, 40)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 255, 120)), ColorSequenceKeypoint.new(0.75, Color3.fromRGB(60, 160, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 220)),
	}) or ColorSequence.new(Color3.new(1, 1, 1), r[2])
	grad.Parent = title
	for k, sc in { s1, s2, s3 } do
		task.delay((k - 1) * 0.15, function() tween(sc, 0.5, { Scale = 1 }, Enum.EasingStyle.Back) end)
	end
	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		rays.Rotation = t * 40
		grad.Offset = Vector2.new(math.sin(t * 3) * 0.5, 0)
		grad.Rotation = t * 90
		s1.Scale = s1.Scale > 0.95 and 1 + math.sin(t * 8) * 0.05 or s1.Scale
		name.TextColor3 = ch.rarity >= 10 and Color3.fromHSV((t * 0.6) % 1, 0.7, 1) or r[2]
		if ch.rarity >= 10 then cc.TintColor = Color3.fromHSV((t * 0.5) % 1, 0.25, 1) end -- перелив мира
	end)
	task.delay(2.8, function()
		for _, sc in { s1, s2, s3 } do tween(sc, 0.3, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In) end
		tween(rays, 0.3, { Size = UDim2.fromOffset(0, 0) })
		task.wait(0.35)
		conn:Disconnect()
		root:Destroy()
		tween(cc, 0.6, { TintColor = Color3.new(1, 1, 1), Saturation = 0, Brightness = 0, Contrast = 0 })
	end)
end

-- ===== Камера =====
local camTarget, camOffset, camLook -- куда смотрит кинокамера
local cinema = false
RunService:BindToRenderStep("CinemaCam", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if not cinema or not camTarget then return end
	local pos = camTarget.Position
	local goal = CFrame.lookAt(pos + camOffset, pos + (camLook or Vector3.zero))
	cam.CFrame = cam.CFrame:Lerp(goal, math.min(1, dt * 8))
	if shake > 0.01 then
		cam.CFrame *= CFrame.new(rng:NextNumber(-1, 1) * shake, rng:NextNumber(-1, 1) * shake, 0) * CFrame.Angles(0, 0, rng:NextNumber(-1, 1) * shake * 0.03)
		shake *= math.max(0, 1 - dt * 6)
	end
end)

local function setCinema(on)
	cinema = on
	_G.ThrowBusy = on
	local main = plr.PlayerGui:FindFirstChild("Main")
	if main then main.Enabled = not on end
	letterbox(on)
	if on then
		cam.CameraType = Enum.CameraType.Scriptable
	else
		cam.CameraType = Enum.CameraType.Custom
		tween(cam, 0.6, { FieldOfView = 70 })
		tween(dim, 0.4, { BackgroundTransparency = 1 })
		tween(blur, 0.4, { Size = 0 })
	end
end

-- ===== Бросок =====
local function cueModel(color)
	local m = Instance.new("Model")
	for _, d in { { 0.4, 7, Color3.fromRGB(25, 12, 5), -2.5 }, { 0.3, 7, color, 4.5 }, { 0.22, 0.3, Color3.fromRGB(25, 80, 230), 8.15 } } do
		local p = Instance.new("Part")
		p.Shape, p.Anchored, p.CanCollide = Enum.PartType.Cylinder, true, false
		p.Size, p.Color, p.Material = Vector3.new(d[2], d[1], d[1]), d[3], Enum.Material.SmoothPlastic
		p:SetAttribute("off", d[4])
		p.Parent = m
	end
	m.Parent = workspace
	return m
end
local function placeCue(m, tip) -- кий лежит вдоль +Z, кончик в точке tip
	for _, p in m:GetChildren() do
		p.CFrame = CFrame.new(tip - Vector3.new(0, -0.6, 8.3 - p:GetAttribute("off"))) * CFrame.Angles(0, math.pi / 2, 0)
	end
end

Fx.OnClientEvent:Connect(function(kind, a, dist, id)
	if kind == "State" then mySlot = a.slot return end
	if kind ~= "Throw" then return end
	local slot, ch = a, C.Characters[id]
	local rcol = C.Rarities[ch.rarity][2]
	local mine = slot == mySlot
	local x = laneX(slot)
	local start = Vector3.new(x, FELT_Y + R, T.StartZ + 3)
	local b = ball(Color3.new(1, 1, 1), R * 2)
	b.CFrame = CFrame.new(start)
	local a0, a1 = Instance.new("Attachment", b), Instance.new("Attachment", b)
	a0.Position, a1.Position = Vector3.new(0, 0.7, 0), Vector3.new(0, -0.7, 0)
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1, trail.Color, trail.LightEmission = a0, a1, ColorSequence.new(Color3.new(1, 1, 1), rcol), 1
	trail.Lifetime, trail.Transparency, trail.Parent = 0.5, NumberSequence.new(0.1, 1), b

	-- 1. Замах кием: зум-ин и затемнение
	local cue = cueModel(C.Cues[2][4])
	if mine then
		setCinema(true)
		camTarget, camOffset, camLook = b, Vector3.new(6, 4, -10), Vector3.new(0, 0, 6)
		cam.FieldOfView = 70
		tween(cam, C.Anim.Windup, { FieldOfView = 38 }, Enum.EasingStyle.Sine)
		tween(dim, C.Anim.Windup, { BackgroundTransparency = 0.6 })
		tween(cc, C.Anim.Windup, { Saturation = -0.4, Contrast = 0.2 })
	end
	local t0 = os.clock()
	while os.clock() - t0 < C.Anim.Windup do
		local t = (os.clock() - t0) / C.Anim.Windup
		local back = t < 0.8 and math.sin(t / 0.8 * math.pi / 2) * 4 or 4 * (1 - (t - 0.8) / 0.2) -- оттяжка и резкий удар
		placeCue(cue, start - Vector3.new(0, 0, R + back))
		RunService.RenderStepped:Wait()
	end
	sfx("Hit")
	burst(b, Color3.new(1, 1, 1), 30)
	task.delay(0.3, cue.Destroy, cue)

	-- 2. Удар: вспышка, жёсткая тряска, аутзум-рывок
	if mine then
		doFlash(Color3.new(1, 1, 1), 0.9)
		hardShake(2.5)
		cam.FieldOfView = 105
		tween(cam, 0.8, { FieldOfView = 75 }, Enum.EasingStyle.Quart)
		tween(dim, 0.3, { BackgroundTransparency = 1 })
		tween(cc, 0.3, { Saturation = 0.3, Contrast = 0.1 })
		camOffset, camLook = Vector3.new(0, 9, -22), Vector3.new(0, 0, 20)
	end

	-- 3. Качение до своей зоны (+ разбивка пирамиды по пути)
	local roll = C.RollTime(dist)
	local zone = math.clamp(math.ceil(dist / zoneLen), 1, N)
	local endZ = math.min(T.StartZ + 3 + dist, T.StartZ + T.Length - R)
	local broke = false
	local rot, lastZ = CFrame.new(), start.Z
	t0 = os.clock()
	repeat
		local t = math.min((os.clock() - t0) / roll, 1)
		local z = start.Z + (endZ - start.Z) * (1 - (1 - t) ^ 3)
		rot = CFrame.Angles((z - lastZ) / R, 0, 0) * rot
		lastZ = z
		b.CFrame = CFrame.new(x, start.Y, z) * rot
		if not broke and z >= RACK_Z - R * 2 and racks[slot] then
			broke = true
			breakRack(slot, math.clamp(dist / T.Length, 0.3, 1))
			if mine then hardShake(1.6) doFlash(rcol, 0.4) end
		end
		RunService.RenderStepped:Wait()
	until t >= 1

	-- 4. Скат в лузу зоны: зум-ин, затемнение, замедление
	local side = x < 0 and -1 or 1
	local pocket = Vector3.new(side * T.Width / 2, start.Y, T.StartZ + (zone - 0.5) * zoneLen)
	if mine then
		camOffset, camLook = Vector3.new(-side * 10, 7, -12), Vector3.zero
		tween(cam, C.Anim.Slide, { FieldOfView = 32 }, Enum.EasingStyle.Sine)
		tween(dim, C.Anim.Slide, { BackgroundTransparency = 0.45 })
		tween(blur, C.Anim.Slide, { Size = 6 })
	end
	local from = b.Position
	t0 = os.clock()
	repeat
		local t = math.min((os.clock() - t0) / C.Anim.Slide, 1)
		local e = t * t * (3 - 2 * t)
		b.CFrame = CFrame.new(from:Lerp(pocket, e)) * rot
		RunService.RenderStepped:Wait()
	until t >= 1
	b.Color = rcol
	drop(b, pocket)

	-- 5. Финал: вспышка цвета редкости, тряска, аутзум, окно персонажа
	if mine then
		doFlash(rcol, 1)
		hardShake(1 + ch.rarity * 0.12)
		cam.FieldOfView = 90
		tween(cam, 1.2, { FieldOfView = 60 }, Enum.EasingStyle.Back)
		tween(dim, 0.3, { BackgroundTransparency = 0.25 })
		tween(blur, 0.3, { Size = 14 })
		tween(cc, 0.3, { TintColor = rcol:Lerp(Color3.new(1, 1, 1), 0.6), Brightness = 0.1, Saturation = 0.5 })
		sfx("Reward")
		reveal(ch)
		task.wait(3.2)
		setCinema(false)
	else
		_G.Toast(ch.name .. " • " .. C.Rarities[ch.rarity][1], rcol)
	end
end)

-- ===== Декоративные шары на столах баз =====
local basePockets = {}
for _, px in { -4.5, 4.5 } do for _, pz in { -8, 0, 8 } do table.insert(basePockets, Vector3.new(px, 0, pz)) end end
local world = workspace:WaitForChild("World")
while true do
	task.wait(rng:NextNumber(1, 2.5))
	local base = world:FindFirstChild("Base" .. rng:NextInteger(1, 4))
	local floor = base and base:FindFirstChild("Floor")
	if floor then
		local o = floor.Position + Vector3.new(0, 3.95, 0)
		local from = o + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-6, 6))
		local goal = o + basePockets[rng:NextInteger(1, #basePockets)]
		local b = ball(rackColors[rng:NextInteger(1, #rackColors)], 0.8)
		b.CFrame = CFrame.new(from)
		local spin = CFrame.fromAxisAngle((goal - from).Unit:Cross(Vector3.yAxis), -(goal - from).Magnitude / 0.4)
		tween(b, 1.2, { CFrame = CFrame.new(goal) * spin.Rotation }).Completed:Once(function() drop(b, goal) end)
	end
end
