-- Процедурная карта. Модели (стол, кий, шар, гантеля, ограждение) повторяют
-- геометрию blender/build_models.py и собираются из деталей — загрузка ассетов не нужна.
-- Если в ReplicatedStorage.Models лежат импортированные меши с теми же именами — берутся они.
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local C = require(game.ReplicatedStorage.Shared.Config)

local Models = game.ReplicatedStorage:FindFirstChild("Models")
local rgb = Color3.fromRGB
local M = Enum.Material
local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball
local Map = { Bases = {}, Zones = {} }

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored, p.TopSurface, p.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do p[k] = v end
	p.Parent = parent
	return p
end

-- цилиндр вдоль оси Y (как в Blender)
local function ycyl(d, h, cf, color, mat, parent)
	return part({ Shape = CYL, Size = Vector3.new(h, d, d), CFrame = cf * CFrame.Angles(0, 0, math.pi / 2), Color = color, Material = mat }, parent)
end

local function label(parent, face, text, color, ppS)
	local g = Instance.new("SurfaceGui")
	g.Face, g.PixelsPerStud, g.LightInfluence = face, ppS or 40, 0
	local t = Instance.new("TextLabel")
	t.Size, t.BackgroundTransparency, t.TextScaled = UDim2.fromScale(1, 1), 1, true
	t.FontFace, t.Text, t.TextColor3 = C.UI.Font, text, color or Color3.new(1, 1, 1)
	local s = Instance.new("UIStroke")
	s.Color, s.Thickness = C.UI.Stroke, 4
	s.Parent, t.Parent, g.Parent = t, g, parent
	return t
end

local function light(p, color, range, b)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Parent = color, range, b or 1.5, p
end

-- ===== Модели =====
local WOOD, DARK, GOLD = rgb(115, 56, 20), rgb(76, 36, 13), rgb(255, 190, 50)

local Build = {}
function Build.PoolTable(m, cf)
	local L, W = 16, 9
	part({ Size = Vector3.new(W + 1.6, 1.2, L + 1.6), CFrame = cf * CFrame.new(0, 3.2, 0), Color = WOOD, Material = M.Wood }, m)
	part({ Size = Vector3.new(W, 0.2, L), CFrame = cf * CFrame.new(0, 3.9, 0), Color = rgb(13, 128, 51), Material = M.Fabric }, m)
	for _, s in { -1, 1 } do
		part({ Size = Vector3.new(0.8, 0.6, L + 1.6), CFrame = cf * CFrame.new(s * (W / 2 + 0.4), 4.1, 0), Color = DARK, Material = M.Wood }, m)
		part({ Size = Vector3.new(W + 1.6, 0.6, 0.8), CFrame = cf * CFrame.new(0, 4.1, s * (L / 2 + 0.4)), Color = DARK, Material = M.Wood }, m)
		for _, t in { -1, 1 } do -- точёные ножки с золотыми кольцами
			local leg = cf * CFrame.new(s * W / 2.3, 0, t * L / 2.3)
			ycyl(0.9, 2.6, leg * CFrame.new(0, 1.3, 0), DARK, M.Wood, m)
			ycyl(1.4, 0.3, leg * CFrame.new(0, 2.5, 0), GOLD, M.Metal, m)
			ycyl(1.2, 0.3, leg * CFrame.new(0, 0.15, 0), GOLD, M.Metal, m)
		end
		for _, t in { -1, 0, 1 } do -- лузы
			local pc = cf * CFrame.new(s * W / 2, 0, t * L / 2)
			ycyl(1.1, 0.25, pc * CFrame.new(0, 4.02, 0), rgb(5, 5, 5), M.SmoothPlastic, m)
			ycyl(1.4, 0.2, pc * CFrame.new(0, 4.2, 0), GOLD, M.Metal, m).Transparency = 0.2
		end
	end
	for i = -1, 1, 2 do -- ромбы-метки на бортах
		for k = -2, 2 do
			part({ Size = Vector3.new(0.25, 0.05, 0.25), CFrame = cf * CFrame.new(i * (W / 2 + 0.4), 4.42, k * 3) * CFrame.Angles(0, math.rad(45), 0), Color = Color3.new(1, 1, 1), Material = M.Neon }, m)
		end
	end
	local lamp = part({ Size = Vector3.new(4, 0.6, 10), CFrame = cf * CFrame.new(0, 11, 0), Color = rgb(20, 90, 40), Material = M.SmoothPlastic }, m)
	part({ Size = Vector3.new(3.4, 0.2, 9.4), CFrame = cf * CFrame.new(0, 10.65, 0), Color = rgb(255, 245, 200), Material = M.Neon }, m)
	light(lamp, rgb(255, 240, 200), 18, 2)
end

function Build.Cue(m, cf, color)
	color = color or rgb(230, 170, 100)
	ycyl(0.44, 4.5, cf * CFrame.new(0, 2.25, 0), rgb(20, 10, 5), M.Wood, m)
	ycyl(0.47, 0.6, cf * CFrame.new(0, 1.2, 0), rgb(150, 15, 15), M.Fabric, m)
	ycyl(0.34, 4.3, cf * CFrame.new(0, 6.65, 0), color, M.Wood, m)
	ycyl(0.22, 0.25, cf * CFrame.new(0, 8.9, 0), rgb(245, 245, 235), M.SmoothPlastic, m)
	ycyl(0.2, 0.08, cf * CFrame.new(0, 9.06, 0), rgb(25, 80, 230), M.Fabric, m)
	part({ Shape = BALL, Size = Vector3.one * 0.46, CFrame = cf, Color = rgb(20, 10, 5) }, m)
end

function Build.Dumbbell(m, cf)
	local x = cf * CFrame.new(0, 0.9, 0)
	part({ Shape = CYL, Size = Vector3.new(5, 0.5, 0.5), CFrame = x, Color = rgb(205, 205, 215), Material = M.Metal }, m)
	for _, s in { -1, 1 } do
		part({ Shape = CYL, Size = Vector3.new(0.5, 1.8, 1.8), CFrame = x * CFrame.new(s * 2, 0, 0), Color = rgb(242, 51, 51) }, m)
		part({ Shape = CYL, Size = Vector3.new(0.4, 1.4, 1.4), CFrame = x * CFrame.new(s * 1.64, 0, 0), Color = rgb(242, 51, 51) }, m)
		part({ Shape = CYL, Size = Vector3.new(0.3, 0.7, 0.7), CFrame = x * CFrame.new(s * 2.3, 0, 0), Color = rgb(205, 205, 215), Material = M.Metal }, m)
	end
	part({ Size = Vector3.new(6, 0.4, 2.4), CFrame = cf * CFrame.new(0, -0.3, 0), Color = rgb(40, 40, 50), Material = M.Rubber }, m)
end

function Build.Fence(m, cf)
	local len, n = 30, 5
	for i = 0, n do
		local x = -len / 2 + i * len / n
		part({ Size = Vector3.new(0.8, 4, 0.8), CFrame = cf * CFrame.new(x, 2, 0), Color = rgb(255, 248, 235) }, m)
		part({ Shape = BALL, Size = Vector3.one * 1.1, CFrame = cf * CFrame.new(x, 4.2, 0), Color = rgb(255, 248, 235) }, m)
	end
	for _, y in { 1.5, 3.2 } do
		part({ Size = Vector3.new(len, 0.5, 0.4), CFrame = cf * CFrame.new(0, y, 0), Color = rgb(255, 205, 75) }, m)
	end
end

local function model(name, cf, parent, ...)
	local src = Models and Models:FindFirstChild(name)
	local m
	if src then
		m = src:Clone()
		m:PivotTo(cf)
	else
		m = Instance.new("Model")
		m.Name = name
		Build[name](m, cf, ...)
	end
	m.Parent = parent
	return m
end
Map.Model = model

-- ===== Карта =====
function Map.Build()
	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace
	local T = C.Table
	local N = #C.Rarities
	local zoneLen = T.Length / N
	local endZ = T.StartZ + T.Length

	-- Освещение
	Lighting.ClockTime, Lighting.Brightness, Lighting.EnvironmentDiffuseScale = 16.5, 2.5, 0.6
	local sky = Instance.new("Sky")
	sky.SunAngularSize, sky.Parent = 14, Lighting
	local atm = Instance.new("Atmosphere")
	atm.Density, atm.Color, atm.Decay, atm.Haze, atm.Glare = 0.28, rgb(255, 210, 230), rgb(140, 120, 255), 1.4, 0.6
	atm.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity, bloom.Size, bloom.Threshold, bloom.Parent = 0.8, 30, 1.3, Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation, cc.Contrast, cc.TintColor, cc.Parent = 0.25, 0.08, rgb(255, 248, 240), Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity, rays.Parent = 0.08, Lighting

	-- Остров из Terrain посреди океана
	local terrain = workspace.Terrain
	terrain.WaterColor, terrain.WaterWaveSize, terrain.WaterReflectance = rgb(40, 190, 230), 0.3, 0.6
	terrain:FillBlock(CFrame.new(0, -12, 500), Vector3.new(2400, 16, 2600), M.Water)
	terrain:FillBlock(CFrame.new(0, -4, 490), Vector3.new(720, 8, 1160), M.Grass)
	terrain:FillBlock(CFrame.new(0, -6, 490), Vector3.new(780, 6, 1220), M.Sand)
	local rng = Random.new(7)
	for _ = 1, 70 do -- горы по краю острова
		local a = rng:NextNumber(0, math.pi * 2)
		local pos = Vector3.new(math.cos(a) * 400, 0, 490 + math.sin(a) * 620)
		terrain:FillBall(pos, rng:NextNumber(25, 60), rng:NextInteger(1, 3) == 1 and M.Snow or M.Rock)
	end

	part({ Name = "Plaza", Size = Vector3.new(470, 0.4, 44), CFrame = CFrame.new(0, 0.2, 52), Color = rgb(250, 225, 180), Material = M.Pebble }, world)
	for x = -230, 230, 10 do -- шахматная дорожка
		part({ Size = Vector3.new(5, 0.42, 5), CFrame = CFrame.new(x, 0.21, 52), Color = rgb(255, 255, 255), Material = M.Marble }, world)
	end

	-- Длинный стол
	local long = Instance.new("Model")
	long.Name = "LongTable"
	long.Parent = world
	local midZ = T.StartZ + T.Length / 2
	part({ Size = Vector3.new(T.Width + 8, 3, T.Length + 8), CFrame = CFrame.new(0, 1.5, midZ), Color = WOOD, Material = M.Wood }, long)
	for _, s in { -1, 1 } do
		part({ Size = Vector3.new(2.5, 2.2, T.Length + 8), CFrame = CFrame.new(s * (T.Width / 2 + 2.75), 4.1, midZ), Color = DARK, Material = M.Wood }, long)
		part({ Size = Vector3.new(0.6, 0.4, T.Length + 8), CFrame = CFrame.new(s * (T.Width / 2 + 2.75), 5.3, midZ), Color = GOLD, Material = M.Neon }, long)
	end
	for z = T.StartZ, endZ, 60 do -- ножки
		for _, s in { -1, 1 } do ycyl(3, 1, CFrame.new(s * (T.Width / 2 + 1), 0.5, z), GOLD, M.Metal, long) end
	end
	for l = 1, T.Lanes - 1 do
		part({ Size = Vector3.new(0.3, 0.32, T.Length), CFrame = CFrame.new(-T.Width / 2 + l * T.Width / T.Lanes, 3.17, midZ), Color = Color3.new(1, 1, 1), Transparency = 0.5 }, long)
	end

	-- Зоны: сукно + неоновые ворота с названием редкости
	for i = 1, N do
		local z0 = T.StartZ + (i - 1) * zoneLen
		local felt = part({ Name = "Zone" .. i, Size = Vector3.new(T.Width, 0.3, zoneLen - 0.4), CFrame = CFrame.new(0, 3.15, z0 + zoneLen / 2), Material = M.Fabric }, long)
		local neon = {}
		for _, s in { -1, 1 } do
			table.insert(neon, part({ Size = Vector3.new(1.6, 16, 1.6), CFrame = CFrame.new(s * (T.Width / 2 + 5), 8, z0), Material = M.Neon }, long))
			table.insert(neon, part({ Shape = BALL, Size = Vector3.one * 3.5, CFrame = CFrame.new(s * (T.Width / 2 + 5), 17, z0), Material = M.Neon }, long))
		end
		local beam = part({ Size = Vector3.new(T.Width + 12, 4, 1), CFrame = CFrame.new(0, 17, z0), Color = rgb(40, 25, 60), Material = M.SmoothPlastic }, long)
		table.insert(neon, part({ Size = Vector3.new(T.Width + 12, 0.5, 1.2), CFrame = CFrame.new(0, 15, z0), Material = M.Neon }, long))
		light(beam, Color3.new(1, 1, 1), 30, 1)
		Map.Zones[i] = { felt = felt, neon = neon, text = label(beam, Enum.NormalId.Front, "", nil, 20) }
		label(beam, Enum.NormalId.Back, "Зона " .. i, nil, 20)
	end

	-- Радужная арка на старте
	local rainbow = { rgb(255, 60, 60), rgb(255, 150, 30), rgb(255, 230, 40), rgb(80, 220, 80), rgb(50, 160, 255), rgb(90, 80, 230), rgb(190, 80, 255) }
	for b, col in rainbow do
		local R = 40 - b * 1.6
		for k = 0, 24 do
			local a = math.pi * k / 24
			part({ Size = Vector3.new(1.6, 1.6, 5.4), CFrame = CFrame.new(math.cos(a) * R, math.sin(a) * R, T.StartZ - 8) * CFrame.Angles(0, 0, a) * CFrame.Angles(math.pi / 2, 0, 0), Color = col, Material = M.Neon, CanCollide = false }, world)
		end
	end
	local sign = part({ Size = Vector3.new(50, 8, 1), CFrame = CFrame.new(0, 26, T.StartZ - 8), Color = rgb(255, 110, 170) }, world)
	label(sign, Enum.NormalId.Front, "🎱 БИЛЬЯРДНЫЕ ОХОТНИКИ 🎱")

	-- Гигантский шар «8» в конце стола
	local eight = part({ Shape = BALL, Size = Vector3.one * 40, CFrame = CFrame.new(0, 32, endZ + 40), Color = rgb(15, 15, 20), Material = M.Glass, Reflectance = 0.15 }, world)
	local circle = part({ Shape = CYL, Size = Vector3.new(1, 18, 18), CFrame = eight.CFrame * CFrame.new(0, 0, -19.7) * CFrame.Angles(0, math.pi / 2, 0), Color = Color3.new(1, 1, 1), Material = M.SmoothPlastic }, world)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1, w.Parent = eight, circle, eight
	circle.Anchored = false
	label(circle, Enum.NormalId.Right, "8", Color3.new(0, 0, 0), 10)
	ycyl(30, 10, CFrame.new(0, 5, endZ + 40), GOLD, M.Metal, world)
	for k = 1, 3 do
		local ring = part({ Shape = CYL, Size = Vector3.new(1, 50 + k * 8, 50 + k * 8), CFrame = eight.CFrame * CFrame.Angles(k, k * 0.7, 0), Color = rainbow[k * 2], Material = M.ForceField, CanCollide = false }, world)
		TweenService:Create(ring, TweenInfo.new(6 + k * 2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { CFrame = ring.CFrame * CFrame.Angles(0, math.pi, 0) }):Play()
	end
	TweenService:Create(eight, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { CFrame = eight.CFrame * CFrame.new(0, 6, 0) * CFrame.Angles(0, math.rad(30), 0) }):Play()
	light(eight, rgb(200, 120, 255), 60, 3)

	-- Фонтан на площади
	local fc = CFrame.new(0, 0, 30)
	ycyl(16, 2, fc * CFrame.new(0, 1, 0), rgb(240, 240, 250), M.Marble, world)
	ycyl(14, 0.3, fc * CFrame.new(0, 2.05, 0), rgb(80, 200, 255), M.Glass, world).Transparency = 0.3
	ycyl(4, 8, fc * CFrame.new(0, 5, 0), rgb(240, 240, 250), M.Marble, world)
	local top = part({ Shape = BALL, Size = Vector3.one * 5, CFrame = fc * CFrame.new(0, 10, 0), Color = rgb(255, 230, 40), Material = M.Glass }, world)
	local water = Instance.new("ParticleEmitter")
	water.Color, water.Rate, water.Speed, water.SpreadAngle = ColorSequence.new(rgb(150, 230, 255)), 120, NumberRange.new(18, 22), Vector2.new(25, 25)
	water.Acceleration, water.Lifetime, water.Size = Vector3.new(0, -40, 0), NumberRange.new(1.2), NumberSequence.new(0.6, 0.2)
	water.LightEmission, water.Parent = 0.4, top

	-- Летающие бильярдные шары и облака
	local ballColors = { rgb(255, 220, 40), rgb(40, 90, 255), rgb(255, 50, 50), rgb(140, 40, 200), rgb(255, 130, 20), rgb(30, 160, 60), rgb(130, 30, 30) }
	for k = 1, 24 do
		local s = k % 2 == 0 and 1 or -1
		local p = part({ Shape = BALL, Size = Vector3.one * rng:NextNumber(8, 16), CFrame = CFrame.new(s * rng:NextNumber(80, 260), rng:NextNumber(40, 90), rng:NextNumber(120, endZ)), Color = ballColors[k % #ballColors + 1], Material = M.Glass, Reflectance = 0.1, CanCollide = false }, world)
		TweenService:Create(p, TweenInfo.new(rng:NextNumber(3, 6), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { CFrame = p.CFrame + Vector3.new(0, 8, 0) }):Play()
	end
	for _ = 1, 30 do
		local c = Vector3.new(rng:NextNumber(-600, 600), rng:NextNumber(140, 200), rng:NextNumber(-300, 1300))
		for _ = 1, 4 do
			part({ Shape = BALL, Size = Vector3.one * rng:NextNumber(20, 40), CFrame = CFrame.new(c + Vector3.new(rng:NextNumber(-25, 25), rng:NextNumber(-5, 5), rng:NextNumber(-15, 15))), Color = Color3.new(1, 1, 1), Material = M.SmoothPlastic, CanCollide = false, CastShadow = false }, world)
		end
	end

	-- Деревья-леденцы и фонари вдоль стола
	for _ = 1, 90 do
		local s = rng:NextInteger(0, 1) == 0 and -1 or 1
		local pos = Vector3.new(s * rng:NextNumber(60, 320), 0, rng:NextNumber(90, endZ + 60))
		local h = rng:NextNumber(8, 16)
		part({ Size = Vector3.new(1.6, h, 1.6), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)), Color = rgb(130, 80, 40), Material = M.Wood }, world)
		part({ Shape = BALL, Size = Vector3.one * rng:NextNumber(9, 14), CFrame = CFrame.new(pos + Vector3.new(0, h + 3, 0)), Color = Color3.fromHSV(rng:NextNumber(), 0.45, 1), Material = M.SmoothPlastic }, world)
	end
	for z = T.StartZ + 20, endZ, 50 do
		for _, s in { -1, 1 } do
			ycyl(1, 14, CFrame.new(s * 40, 7, z), rgb(60, 60, 70), M.Metal, world)
			light(part({ Shape = BALL, Size = Vector3.one * 2.5, CFrame = CFrame.new(s * 40, 15, z), Color = rgb(255, 240, 180), Material = M.Neon }, world), rgb(255, 230, 170), 30)
		end
	end

	-- 4 базы
	local baseColors = { rgb(255, 120, 120), rgb(120, 180, 255), rgb(120, 230, 140), rgb(255, 200, 90) }
	for i = 1, 4 do
		local x = (i - 2.5) * 110
		local origin = CFrame.new(x, 0, -10)
		local col = baseColors[i]
		local base = Instance.new("Model")
		base.Name = "Base" .. i
		base.Parent = world
		part({ Name = "Floor", Size = Vector3.new(90, 1, 90), CFrame = origin * CFrame.new(0, 0.5, 0), Color = rgb(255, 235, 200), Material = M.WoodPlanks }, base)
		part({ Size = Vector3.new(92, 0.8, 92), CFrame = origin * CFrame.new(0, 0.3, 0), Color = col }, base)
		part({ Size = Vector3.new(30, 1.05, 30), CFrame = origin * CFrame.new(0, 0.5, 0), Color = rgb(170, 40, 60), Material = M.Fabric }, base)

		model("PoolTable", origin, base)
		for _, f in { { 0, -45, 0, { -30, 0, 30 } }, { 0, 45, math.pi, { -30, 30 } }, { -45, 0, math.pi / 2, { -30, 0, 30 } }, { 45, 0, -math.pi / 2, { -30, 0, 30 } } } do
			local fcf = origin * CFrame.new(f[1], 1, f[2]) * CFrame.Angles(0, f[3], 0)
			for _, o in f[4] do model("Fence", fcf * CFrame.new(o, 0, 0), base) end
		end
		for _, s in { -1, 1 } do -- столбы входа
			ycyl(2.4, 12, origin * CFrame.new(s * 15, 6, 45), col, M.SmoothPlastic, base)
			light(part({ Shape = BALL, Size = Vector3.one * 3, CFrame = origin * CFrame.new(s * 15, 13, 45), Color = col, Material = M.Neon }, base), col, 20)
		end

		model("Dumbbell", origin * CFrame.new(-30, 1.3, 25), base)
		local dPrompt = Instance.new("ProximityPrompt")
		dPrompt.ActionText, dPrompt.ObjectText, dPrompt.HoldDuration = "Качаться", "Гантеля", 0
		dPrompt.Parent = part({ Name = "DumbbellHit", Size = Vector3.new(6, 3, 3), CFrame = origin * CFrame.new(-30, 2, 25), Transparency = 1, CanCollide = false }, base)

		local shop = part({ Name = "CueShop", Size = Vector3.new(10, 4, 4), CFrame = origin * CFrame.new(30, 3, 25), Color = rgb(120, 200, 255) }, base)
		for k = 0, 5 do -- полосатый навес
			part({ Size = Vector3.new(2, 0.6, 6), CFrame = origin * CFrame.new(25 + k * 2, 10, 25), Color = k % 2 == 0 and rgb(255, 90, 90) or Color3.new(1, 1, 1) }, base)
		end
		for _, o in { -5, 5 } do part({ Size = Vector3.new(0.6, 6, 0.6), CFrame = origin * CFrame.new(30 + o, 7, 25), Color = Color3.new(1, 1, 1) }, base) end
		label(shop, Enum.NormalId.Back, "🎱 КИИ")
		for k = 1, 3 do model("Cue", origin * CFrame.new(27 + k * 1.5, 5, 23.6) * CFrame.Angles(0, 0, math.rad(8 - k * 4)), base, C.Cues[k * 2][4]) end
		local sPrompt = Instance.new("ProximityPrompt")
		sPrompt.ActionText, sPrompt.ObjectText, sPrompt.HoldDuration = "Открыть", "Магазин киёв", 0
		sPrompt.Parent = shop

		local signPart = part({ Size = Vector3.new(24, 5, 1), CFrame = origin * CFrame.new(0, 16, 45), Color = col }, base)
		part({ Size = Vector3.new(32, 1, 1), CFrame = origin * CFrame.new(0, 12, 45), Color = col }, base)

		local slots = {}
		for s = 1, C.MaxEquipped do
			local a = math.rad(-150 + (s - 1) * (300 / (C.MaxEquipped - 1)))
			local pos = origin.Position + Vector3.new(math.sin(a) * 18, 1, -math.cos(a) * 18)
			slots[s] = CFrame.lookAt(pos, Vector3.new(origin.X, 1, origin.Z))
			ycyl(5, 0.6, CFrame.new(pos + Vector3.new(0, 0.3, 0)), Color3.new(1, 1, 1), M.Marble, base)
			ycyl(5.4, 0.2, CFrame.new(pos + Vector3.new(0, 0.1, 0)), col, M.Neon, base)
		end

		Map.Bases[i] = {
			model = base, origin = origin, slots = slots, spawn = origin * CFrame.new(0, 1.1, 32),
			sign = label(signPart, Enum.NormalId.Back, "Свободная база"), dumbPrompt = dPrompt, shopPrompt = sPrompt,
			chars = Instance.new("Folder", base),
		}
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored, spawn.Transparency, spawn.CanCollide, spawn.Size, spawn.Neutral = true, 1, false, Vector3.new(6, 1, 6), true
	spawn.CFrame, spawn.Parent = CFrame.new(0, 0.6, 52), world
	return Map
end

return Map
