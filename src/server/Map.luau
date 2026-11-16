-- Процедурная сборка карты. Если в ReplicatedStorage.Models есть меши из Blender
-- (PoolTable, Cue, Dumbbell, Fence, Ball) — используются они, иначе примитивы.
local Lighting = game:GetService("Lighting")
local C = require(game.ReplicatedStorage.Shared.Config)

local Models = game.ReplicatedStorage:FindFirstChild("Models")
local rgb = Color3.fromRGB
local Map = { Bases = {}, Zones = {} }

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored, p.TopSurface, p.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do p[k] = v end
	p.Parent = parent
	return p
end

local function mesh(name, cf, parent, fallback)
	local src = Models and Models:FindFirstChild(name)
	local m
	if src then
		m = src:Clone()
		if m:IsA("Model") then m:PivotTo(cf) else m.CFrame = cf end
		for _, d in m:GetDescendants() do if d:IsA("BasePart") then d.Anchored = true end end
		m.Parent = parent
	else
		m = Instance.new("Model")
		m.Name = name
		fallback(m, cf)
		m.Parent = parent
	end
	return m
end

local function label(parent, face, text, color, size)
	local g = Instance.new("SurfaceGui")
	g.Face, g.PixelsPerStud, g.LightInfluence = face, 40, 0
	local t = Instance.new("TextLabel")
	t.Size, t.BackgroundTransparency, t.TextScaled = UDim2.fromScale(1, 1), 1, true
	t.FontFace, t.Text, t.TextColor3 = C.UI.Font, text, color or Color3.new(1, 1, 1)
	local s = Instance.new("UIStroke")
	s.Color, s.Thickness = C.UI.Stroke, size or 4
	s.Parent, t.Parent, g.Parent = t, g, parent
	return t
end

-- Fallback-модели
local function poolTable(m, cf, scale)
	scale = scale or 1
	local L, W = 16 * scale, 9 * scale
	part({ Name = "Body", Size = Vector3.new(W + 1.6, 1.2, L + 1.6), CFrame = cf * CFrame.new(0, 3.2, 0), Color = rgb(110, 60, 30), Material = Enum.Material.Wood }, m)
	part({ Name = "Felt", Size = Vector3.new(W, 0.2, L), CFrame = cf * CFrame.new(0, 3.9, 0), Color = rgb(30, 150, 80), Material = Enum.Material.Fabric }, m)
	for _, x in { -1, 1 } do
		part({ Size = Vector3.new(0.8, 0.6, L + 1.6), CFrame = cf * CFrame.new(x * (W / 2 + 0.4), 4.1, 0), Color = rgb(90, 45, 20), Material = Enum.Material.Wood }, m)
		for _, z in { -1, 1 } do
			part({ Size = Vector3.new(1, 2.6, 1), CFrame = cf * CFrame.new(x * W / 2.3, 1.3, z * L / 2.3), Color = rgb(80, 40, 18), Material = Enum.Material.Wood }, m)
		end
	end
	for _, z in { -1, 1 } do
		part({ Size = Vector3.new(W + 1.6, 0.6, 0.8), CFrame = cf * CFrame.new(0, 4.1, z * (L / 2 + 0.4)), Color = rgb(90, 45, 20), Material = Enum.Material.Wood }, m)
	end
	for _, x in { -1, 1 } do
		for _, z in { -1, 0, 1 } do
			part({ Name = "Pocket", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.1, 1.1), CFrame = cf * CFrame.new(x * W / 2, 3.95, z * L / 2) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(15, 15, 15) }, m)
		end
	end
end

local function dumbbell(m, cf)
	part({ Name = "Bar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(5, 0.5, 0.5), CFrame = cf * CFrame.new(0, 0.9, 0), Color = rgb(180, 180, 190), Material = Enum.Material.Metal }, m)
	for _, x in { -2, 2 } do
		part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 1.8, 1.8), CFrame = cf * CFrame.new(x, 0.9, 0), Color = rgb(255, 80, 80), Material = Enum.Material.SmoothPlastic }, m)
	end
end

local function fence(m, cf, len)
	for i = 0, math.floor(len / 6) do
		part({ Size = Vector3.new(0.8, 4, 0.8), CFrame = cf * CFrame.new(-len / 2 + i * len / math.floor(len / 6), 2, 0), Color = rgb(255, 250, 240) }, m)
	end
	for _, y in { 1.5, 3.2 } do
		part({ Size = Vector3.new(len, 0.5, 0.4), CFrame = cf * CFrame.new(0, y, 0), Color = rgb(255, 210, 90) }, m)
	end
end

function Map.Build()
	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace

	-- Окружение
	Instance.new("Sky").Parent = Lighting
	local atm = Instance.new("Atmosphere")
	atm.Density, atm.Color, atm.Haze = 0.25, rgb(200, 220, 255), 1
	atm.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity, bloom.Threshold = 0.6, 1.4
	bloom.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation, cc.Contrast = 0.2, 0.05
	cc.Parent = Lighting

	part({ Name = "Ground", Size = Vector3.new(700, 2, 700), CFrame = CFrame.new(0, -1, 200), Color = rgb(110, 200, 90), Material = Enum.Material.Grass }, world)
	part({ Name = "Plaza", Size = Vector3.new(460, 0.4, 40), CFrame = CFrame.new(0, 0.2, 52), Color = rgb(250, 225, 180), Material = Enum.Material.Pebble }, world)

	-- Длинный стол
	local T = C.Table
	local zoneLen = T.Length / #C.Rarities
	local long = Instance.new("Model")
	long.Name = "LongTable"
	long.Parent = world
	part({ Size = Vector3.new(T.Width + 6, 3, T.Length + 6), CFrame = CFrame.new(0, 1.5, T.StartZ + T.Length / 2), Color = rgb(100, 55, 25), Material = Enum.Material.Wood }, long)
	for _, x in { -1, 1 } do
		part({ Size = Vector3.new(2, 2, T.Length + 6), CFrame = CFrame.new(x * (T.Width / 2 + 2), 4, T.StartZ + T.Length / 2), Color = rgb(255, 200, 60), Material = Enum.Material.SmoothPlastic }, long)
	end
	for i = 1, #C.Rarities do
		local z = T.StartZ + (i - 0.5) * zoneLen
		local felt = part({ Name = "Zone" .. i, Size = Vector3.new(T.Width, 0.3, zoneLen - 0.4), CFrame = CFrame.new(0, 3.15, z), Material = Enum.Material.Fabric }, long)
		local sign = part({ Size = Vector3.new(14, 4, 0.5), CFrame = CFrame.new(T.Width / 2 + 10, 6, z) * CFrame.Angles(0, -math.pi / 2, 0), Transparency = 1, CanCollide = false }, long)
		Map.Zones[i] = { felt = felt, text = label(sign, Enum.NormalId.Front, "", nil, 3) }
	end
	for l = 1, T.Lanes - 1 do
		part({ Size = Vector3.new(0.3, 0.32, T.Length), CFrame = CFrame.new(-T.Width / 2 + l * T.Width / T.Lanes, 3.17, T.StartZ + T.Length / 2), Color = rgb(255, 255, 255), Transparency = 0.5 }, long)
	end
	local arch = part({ Size = Vector3.new(T.Width + 10, 6, 1), CFrame = CFrame.new(0, 18, T.StartZ - 2), Color = rgb(255, 120, 170) }, long)
	label(arch, Enum.NormalId.Back, "🎱 БРОСАЙ ШАР! 🎱")
	for _, x in { -1, 1 } do
		part({ Size = Vector3.new(2, 18, 2), CFrame = CFrame.new(x * (T.Width / 2 + 4), 9, T.StartZ - 2), Color = rgb(255, 120, 170) }, long)
	end

	-- 4 базы
	for i = 1, 4 do
		local x = (i - 2.5) * 110
		local origin = CFrame.new(x, 0, -10)
		local base = Instance.new("Model")
		base.Name = "Base" .. i
		base.Parent = world
		part({ Name = "Floor", Size = Vector3.new(90, 1, 90), CFrame = origin * CFrame.new(0, 0.5, 0), Color = rgb(255, 235, 200), Material = Enum.Material.WoodPlanks }, base)
		part({ Size = Vector3.new(30, 1.05, 30), CFrame = origin * CFrame.new(0, 0.5, 0), Color = rgb(170, 40, 60), Material = Enum.Material.Fabric }, base)

		mesh("PoolTable", origin, base, poolTable)
		-- ограждение из сегментов по 30: 3 сзади, по 3 с боков, 2 спереди (проход посередине)
		for _, f in { { 0, -45, 0, { -30, 0, 30 } }, { 0, 45, math.pi, { -30, 30 } }, { -45, 0, math.pi / 2, { -30, 0, 30 } }, { 45, 0, -math.pi / 2, { -30, 0, 30 } } } do
			local fcf = origin * CFrame.new(f[1], 0, f[2]) * CFrame.Angles(0, f[3], 0)
			for _, o in f[4] do mesh("Fence", fcf * CFrame.new(o, 0, 0), base, function(m, cf) fence(m, cf, 30) end) end
		end

		mesh("Dumbbell", origin * CFrame.new(-30, 1, 25), base, dumbbell)
		local dPrompt = Instance.new("ProximityPrompt")
		dPrompt.ActionText, dPrompt.ObjectText, dPrompt.HoldDuration = "Качаться", "Гантеля", 0
		dPrompt.Parent = part({ Name = "DumbbellHit", Size = Vector3.new(6, 3, 3), CFrame = origin * CFrame.new(-30, 2, 25), Transparency = 1, CanCollide = false }, base)

		local shop = part({ Name = "CueShop", Size = Vector3.new(10, 4, 4), CFrame = origin * CFrame.new(30, 2.5, 25), Color = rgb(120, 200, 255) }, base)
		part({ Size = Vector3.new(12, 0.6, 6), CFrame = origin * CFrame.new(30, 10, 25), Color = rgb(255, 90, 90) }, base)
		for _, o in { -5, 5 } do part({ Size = Vector3.new(0.6, 6, 0.6), CFrame = origin * CFrame.new(30 + o, 7, 25), Color = rgb(255, 255, 255) }, base) end
		label(shop, Enum.NormalId.Back, "🎱 КИИ")
		mesh("Cue", origin * CFrame.new(30, 6, 25) * CFrame.Angles(0, 0, math.rad(70)), base, function(m, cf)
			part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(9, 0.35, 0.35), CFrame = cf, Color = C.Cues[1][4], Material = Enum.Material.Wood }, m)
		end)
		local sPrompt = Instance.new("ProximityPrompt")
		sPrompt.ActionText, sPrompt.ObjectText, sPrompt.HoldDuration = "Открыть", "Магазин киёв", 0
		sPrompt.Parent = shop

		local signPart = part({ Size = Vector3.new(24, 5, 1), CFrame = origin * CFrame.new(0, 14, 44), Color = rgb(255, 190, 40) }, base)
		part({ Size = Vector3.new(1, 12, 1), CFrame = origin * CFrame.new(0, 6, 44), Color = rgb(255, 255, 255) }, base)

		local spawn = Instance.new("SpawnLocation")
		spawn.Anchored, spawn.Transparency, spawn.CanCollide, spawn.Size = true, 1, false, Vector3.new(6, 1, 6)
		spawn.CFrame, spawn.Neutral, spawn.Enabled = origin * CFrame.new(0, 1.1, 32), true, i == 1
		spawn.Parent = base

		local slots = {}
		for s = 1, C.MaxEquipped do
			local a = math.rad(-150 + (s - 1) * (300 / (C.MaxEquipped - 1)))
			local pos = origin.Position + Vector3.new(math.sin(a) * 18, 1, -math.cos(a) * 18)
			slots[s] = CFrame.lookAt(pos, Vector3.new(origin.X, 1, origin.Z))
			part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 5, 5), CFrame = CFrame.new(pos - Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(255, 255, 255), Material = Enum.Material.Marble }, base)
		end

		Map.Bases[i] = {
			model = base, origin = origin, slots = slots, spawn = spawn.CFrame,
			sign = label(signPart, Enum.NormalId.Back, "Свободная база"), dumbPrompt = dPrompt, shopPrompt = sPrompt,
			chars = Instance.new("Folder", base),
		}
	end

	-- Декор: деревья-«леденцы» и фонари
	local rng = Random.new(7)
	for _ = 1, 40 do
		local side = rng:NextInteger(0, 1) == 0 and -1 or 1
		local pos = Vector3.new(side * rng:NextNumber(50, 300), 0, rng:NextNumber(90, 520))
		part({ Size = Vector3.new(1.5, 10, 1.5), CFrame = CFrame.new(pos + Vector3.new(0, 5, 0)), Color = rgb(130, 80, 40), Material = Enum.Material.Wood }, world)
		part({ Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(8, 12), CFrame = CFrame.new(pos + Vector3.new(0, 12, 0)), Color = Color3.fromHSV(rng:NextNumber(0.25, 0.45), 0.6, 0.85) }, world)
	end
	for z = 80, 480, 40 do
		for _, x in { -1, 1 } do
			part({ Size = Vector3.new(1, 14, 1), CFrame = CFrame.new(x * 36, 7, z), Color = rgb(60, 60, 70), Material = Enum.Material.Metal }, world)
			local bulb = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2.5, CFrame = CFrame.new(x * 36, 15, z), Color = rgb(255, 240, 180), Material = Enum.Material.Neon }, world)
			local l = Instance.new("PointLight")
			l.Range, l.Brightness, l.Color = 30, 1.5, rgb(255, 230, 170)
			l.Parent = bulb
		end
	end
	return Map
end

return Map
