local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehicleFactory = require(Shared:WaitForChild("VehicleFactory"))
local MapConfig = require(Shared:WaitForChild("MapConfig"))
local ModelSizes = require(Shared:WaitForChild("ModelSizes"))
local ServerStorage = game:GetService("ServerStorage")

local C = Color3.fromRGB
local M = Enum.Material

local Prefabs = {}
Prefabs.Count = 0

local GLASS = C(150, 205, 240)
local DARK = C(34, 36, 44)

function Prefabs.Part(parent, name, size, cf, color, mat, o)
	o = o or {}
	local p = Instance.new(o.class or "Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color
	mat = mat or M.SmoothPlastic
	if MapConfig.NoNeon and mat == M.Neon and not o.light then
		mat = M.SmoothPlastic -- only real light sources glow
	end
	if MapConfig.Cartoon and (mat == M.Concrete or mat == M.Asphalt or mat == M.Grass or mat == M.Wood) then
		mat = M.SmoothPlastic -- clean toy look
	end
	p.Material = mat
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if o.t then p.Transparency = o.t end
	if o.collide == false then
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
	if o.shape then p.Shape = o.shape end
	if o.refl then p.Reflectance = o.refl end
	if o.cast == false then p.CastShadow = false end
	p.Parent = parent
	Prefabs.Count = Prefabs.Count + 1
	return p
end
local Part = Prefabs.Part

function Prefabs.Label(part, face, text, textColor, bg)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Gui"
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	gui.Parent = part
	local l = Instance.new("TextLabel")
	l.Name = "Label"
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = bg and 0 or 1
	if bg then l.BackgroundColor3 = bg end
	l.TextColor3 = textColor or C(255, 255, 255)
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.Text = text
	l.Parent = gui
	return l
end
local Label = Prefabs.Label

-- Blender-made props: ServerStorage.BuilderAssets.Props.<name> (see docs/BLENDER.md). nil if not imported.
Prefabs.TemplateUse = { placed = 0, missing = {} }
-- opts: scale (uniform), colors = { Wall = c, Trim = c, Roof = c } recolours the Blender looks per district
function Prefabs.FromTemplate(name, parent, cf, opts)
	local assets = ServerStorage:FindFirstChild("BuilderAssets")
	local props = assets and assets:FindFirstChild("Props")
	local tpl = props and props:FindFirstChild(name)
	if not tpl then
		Prefabs.TemplateUse.missing[name] = true
		return nil
	end
	Prefabs.TemplateUse.placed = Prefabs.TemplateUse.placed + 1
	local m = tpl:Clone()
	if opts and opts.scale and math.abs(opts.scale - 1) > 0.01 then
		m:ScaleTo(m:GetScale() * opts.scale)
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			local c = opts and opts.colors and opts.colors[d.Name]
			if c then
				d.Color = c
			end
		end
	end
	m:PivotTo(cf)
	m.Parent = parent
	Prefabs.Count = Prefabs.Count + 1
	return m
end

local function pick(rng, list)
	return list[math.floor(rng() * #list) + 1]
end
local function rr(rng, a, b)
	return a + (b - a) * rng()
end
Prefabs.Pick = pick
Prefabs.RR = rr

local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

local lampLights = 0
local function addLight(part, range)
	if lampLights >= 70 then
		return -- keep the light count mobile-friendly
	end
	lampLights = lampLights + 1
	local l = Instance.new("PointLight")
	l.Range = range or 14
	l.Brightness = 1.1
	l.Color = Color3.fromRGB(255, 220, 170)
	l.Shadows = false
	l.Parent = part
end

function Prefabs.Lamp(parent, pos, variant, glow, facing)
	local cf = CFrame.new(pos) * CFrame.Angles(0, facing or 0, 0)
	local lm = Prefabs.FromTemplate(({ "LampA", "LampB", "LampC" })[variant] or "LampA", parent, CFrame.new(pos.X, pos.Y - 0.2, pos.Z) * CFrame.Angles(0, facing or 0, 0))
	if lm then
		local g = lm:FindFirstChild("Glow", true)
		if g then
			addLight(g, variant == 3 and 12 or 16)
		end
		return
	end
	local warm = Color3.fromRGB(255, 236, 200)
	local POLE = C(52, 56, 64)
	Part(parent, "LampBase", Vector3.new(1.4, 0.8, 1.4), cf * CFrame.new(0, 0.4, 0), POLE, M.Metal)
	if variant == 1 then
		Part(parent, "LampPole", Vector3.new(0.6, 12, 0.6), cf * CFrame.new(0, 6, 0), POLE, M.Metal)
		Part(parent, "LampArm", Vector3.new(4, 0.4, 0.4), cf * CFrame.new(2, 12, 0), POLE, M.Metal)
		Part(parent, "LampHousing", Vector3.new(2, 0.5, 1.2), cf * CFrame.new(4, 11.9, 0), POLE, M.Metal)
		addLight(Part(parent, "LampHead", Vector3.new(1.6, 0.15, 0.9), cf * CFrame.new(4, 11.6, 0), warm, M.Neon, { light = true }), 16)
	elseif variant == 2 then
		Part(parent, "LampPole", Vector3.new(0.7, 13, 0.7), cf * CFrame.new(0, 6.5, 0), POLE, M.Metal)
		Part(parent, "LampArmL", Vector3.new(7, 0.4, 0.4), cf * CFrame.new(0, 13, 0) * CFrame.Angles(0, math.pi / 2, 0), POLE, M.Metal)
		for _, z in ipairs({ 3.4, -3.4 }) do
			Part(parent, "LampHousing", Vector3.new(1.4, 0.5, 1.4), cf * CFrame.new(0, 12.9, z), POLE, M.Metal)
			addLight(Part(parent, "LampHead", Vector3.new(1.1, 0.15, 1.1), cf * CFrame.new(0, 12.6, z), warm, M.Neon, { light = true }), 14)
		end
	else
		Part(parent, "LampPole", Vector3.new(0.5, 8, 0.5), cf * CFrame.new(0, 4, 0), POLE, M.Metal)
		Part(parent, "LampCap", Vector3.new(2.2, 0.4, 2.2), cf * CFrame.new(0, 10.4, 0), POLE, M.Metal)
		addLight(Part(parent, "LampGlobe", Vector3.new(1.8, 2.2, 1.8), cf * CFrame.new(0, 9.1, 0), warm, M.Glass, { t = 0.2 }), 12)
	end
end

function Prefabs.Tree(parent, pos, rng, variant)
	if Prefabs.FromTemplate(variant == "palm" and "Palm" or "Tree", parent, CFrame.new(pos) * CFrame.Angles(0, rr(rng, 0, 6.28), 0), { scale = rr(rng, 0.85, 1.2) }) then
		return
	end
	local h = rr(rng, 6, 9)
	if variant == "palm" then
		Part(parent, "Trunk", Vector3.new(1.1, h + 3, 1.1), CFrame.new(pos + Vector3.new(0, (h + 3) / 2, 0)), C(150, 110, 70), M.Wood)
		for i = 0, 4 do
			local a = i * math.pi * 2 / 5
			Part(parent, "Frond", Vector3.new(6.5, 0.3, 1.6), CFrame.new(pos + Vector3.new(0, h + 3, 0)) * CFrame.Angles(0, a, 0) * CFrame.new(3, -0.4, 0) * CFrame.Angles(0, 0, -0.3), C(70, 170, 80), M.Grass, { collide = false })
		end
	else
		Part(parent, "Trunk", Vector3.new(1.3, h, 1.3), CFrame.new(pos + Vector3.new(0, h / 2, 0)), C(120, 86, 56), M.Wood)
		local g = pick(rng, { C(70, 160, 70), C(90, 180, 80), C(60, 140, 90), C(120, 190, 70) })
		local s = rr(rng, 6.5, 9)
		Part(parent, "Canopy", Vector3.new(s, s, s), CFrame.new(pos + Vector3.new(0, h + s * 0.3, 0)), g, M.Grass, { shape = BALL, collide = false })
		Part(parent, "Canopy2", Vector3.new(s * 0.7, s * 0.7, s * 0.7), CFrame.new(pos + Vector3.new(s * 0.25, h + s * 0.7, 0)), g, M.Grass, { shape = BALL, collide = false })
	end
end

function Prefabs.Bush(parent, pos, rng)
	if Prefabs.FromTemplate("Bush", parent, CFrame.new(pos) * CFrame.Angles(0, rr(rng, 0, 6.28), 0), { scale = rr(rng, 0.8, 1.3) }) then
		return
	end
	local s = rr(rng, 3, 5)
	Part(parent, "Bush", Vector3.new(s, s * 0.7, s), CFrame.new(pos + Vector3.new(0, s * 0.3, 0)), pick(rng, { C(60, 150, 70), C(80, 170, 90) }), M.Grass, { shape = BALL, collide = false })
end

function Prefabs.Bench(parent, pos, yaw)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw or 0, 0)
	Part(parent, "BenchSeat", Vector3.new(6, 0.5, 2), cf * CFrame.new(0, 1.7, 0), C(150, 100, 60), M.Wood)
	Part(parent, "BenchBack", Vector3.new(6, 1.6, 0.4), cf * CFrame.new(0, 2.8, -0.9), C(150, 100, 60), M.Wood)
	Part(parent, "BenchLegL", Vector3.new(0.5, 1.6, 1.8), cf * CFrame.new(-2.5, 0.8, 0), DARK, M.Metal)
	Part(parent, "BenchLegR", Vector3.new(0.5, 1.6, 1.8), cf * CFrame.new(2.5, 0.8, 0), DARK, M.Metal)
end

function Prefabs.Planter(parent, pos, color)
	Part(parent, "Planter", Vector3.new(5, 2, 5), CFrame.new(pos + Vector3.new(0, 1, 0)), color or C(170, 160, 150), M.Concrete)
	Part(parent, "PlanterGreen", Vector3.new(4.2, 2.4, 4.2), CFrame.new(pos + Vector3.new(0, 2.2, 0)), C(70, 160, 80), M.Grass, { shape = BALL, collide = false })
end

function Prefabs.Kiosk(parent, pos, yaw, color, text)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw or 0, 0)
	if Prefabs.FromTemplate("Kiosk", parent, cf, { colors = { Wall = color } }) then
		local sign = Part(parent, "KioskSign", Vector3.new(5, 1.3, 0.3), cf * CFrame.new(0, 8.3, -2.6), DARK)
		Label(sign, Enum.NormalId.Front, text or "SHOP", C(255, 220, 90))
		return
	end
	Part(parent, "Kiosk", Vector3.new(7, 7, 6), cf * CFrame.new(0, 3.5, 0), color, M.SmoothPlastic)
	Part(parent, "KioskRoof", Vector3.new(8.4, 0.6, 7.4), cf * CFrame.new(0, 7.3, 0), DARK)
	local win = Part(parent, "KioskWindow", Vector3.new(5, 2.6, 0.3), cf * CFrame.new(0, 4.4, -3.1), GLASS, M.Glass, { t = 0.3 })
	local sign = Part(parent, "KioskSign", Vector3.new(5, 1.3, 0.3), cf * CFrame.new(0, 6.3, -3.1), DARK)
	Label(sign, Enum.NormalId.Front, text or "SHOP", C(255, 220, 90))
end

function Prefabs.DistrictSign(parent, pos, text, color, yaw)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw or 0, 0)
	Part(parent, "SignPostL", Vector3.new(0.8, 12, 0.8), cf * CFrame.new(-7, 6, 0), DARK, M.Metal)
	Part(parent, "SignPostR", Vector3.new(0.8, 12, 0.8), cf * CFrame.new(7, 6, 0), DARK, M.Metal)
	local b = Part(parent, "SignBoard", Vector3.new(18, 5, 0.6), cf * CFrame.new(0, 11, 0), color, M.SmoothPlastic)
	Label(b, Enum.NormalId.Front, text, C(255, 255, 255))
	Label(b, Enum.NormalId.Back, text, C(255, 255, 255))
end

function Prefabs.Fountain(parent, pos, accent)
	local cf = CFrame.new(pos)
	Part(parent, "FountainRim", Vector3.new(2.4, 30, 30), cf * CFrame.new(0, 1.2, 0) * UPRIGHT, C(228, 222, 212), M.Concrete, { shape = CYL })
	Part(parent, "FountainWater", Vector3.new(0.3, 27, 27), cf * CFrame.new(0, 2.3, 0) * UPRIGHT, C(110, 196, 240), M.Glass, { shape = CYL, t = 0.25, collide = false })
	Part(parent, "FountainTier", Vector3.new(4, 10, 10), cf * CFrame.new(0, 3.5, 0) * UPRIGHT, C(240, 236, 228), M.Concrete, { shape = CYL })
	Part(parent, "FountainBowl", Vector3.new(1, 14, 14), cf * CFrame.new(0, 6, 0) * UPRIGHT, C(240, 236, 228), M.Concrete, { shape = CYL })
	Part(parent, "FountainWater2", Vector3.new(0.2, 12.5, 12.5), cf * CFrame.new(0, 6.5, 0) * UPRIGHT, C(110, 196, 240), M.Glass, { shape = CYL, t = 0.25, collide = false })
	Part(parent, "FountainSpout", Vector3.new(1.4, 6, 1.4), cf * CFrame.new(0, 9, 0), C(240, 236, 228), M.Concrete)
	local jet = Part(parent, "FountainJet", Vector3.new(1, 5, 1), cf * CFrame.new(0, 14, 0), C(190, 235, 255), M.Neon, { t = 0.45, collide = false, cast = false })
	Part(parent, "FountainGlow", Vector3.new(0.2, 28, 28), cf * CFrame.new(0, 2.45, 0) * UPRIGHT, accent, M.Neon, { shape = CYL, t = 0.85, collide = false, cast = false })
	do
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(C(210, 240, 255))
		e.Size = NumberSequence.new(0.8, 0.2)
		e.Transparency = NumberSequence.new(0.2, 1)
		e.Lifetime = NumberRange.new(1, 1.4)
		e.Speed = NumberRange.new(10, 14)
		e.SpreadAngle = Vector2.new(14, 14)
		e.Acceleration = Vector3.new(0, -24, 0)
		e.Rate = 26
		e.Parent = jet
	end
end

function Prefabs.FlowerBed(parent, pos, w, d, rng)
	if Prefabs.FromTemplate("FlowerBed", parent, CFrame.new(pos) * CFrame.Angles(0, w < d and math.pi / 2 or 0, 0), { scale = math.min(math.max(w, d) / 8, math.min(w, d) / 5) }) then
		return
	end
	Part(parent, "BedEdge", Vector3.new(w, 1, d), CFrame.new(pos + Vector3.new(0, 0.5, 0)), C(232, 224, 212), M.Concrete)
	Part(parent, "BedSoil", Vector3.new(w - 0.8, 0.2, d - 0.8), CFrame.new(pos + Vector3.new(0, 1.05, 0)), C(110, 160, 80), M.Grass, { collide = false })
	local cols = { C(255, 120, 150), C(255, 210, 90), C(120, 200, 255), C(255, 255, 255), C(255, 150, 90) }
	local n = math.floor(w * d / 14)
	for _ = 1, n do
		local x = rr(rng, -w / 2 + 1, w / 2 - 1)
		local z = rr(rng, -d / 2 + 1, d / 2 - 1)
		Part(parent, "Flower", Vector3.new(0.9, 0.9, 0.9), CFrame.new(pos + Vector3.new(x, 1.5, z)), pick(rng, cols), M.SmoothPlastic, { shape = BALL, collide = false, cast = false })
	end
end

function Prefabs.Hedge(parent, cf, len)
	Part(parent, "Hedge", Vector3.new(len, 2.6, 2.4), cf * CFrame.new(0, 1.3, 0), C(76, 156, 84), M.Grass)
	Part(parent, "HedgeTop", Vector3.new(len - 0.4, 0.6, 2.0), cf * CFrame.new(0, 2.8, 0), C(96, 178, 96), M.Grass, { collide = false })
end

function Prefabs.Cloud(parent, pos, rng)
	local s = rr(rng, 16, 30)
	local col = C(255, 255, 255)
	Part(parent, "Cloud", Vector3.new(s * 1.6, s * 0.7, s), CFrame.new(pos), col, M.SmoothPlastic, { shape = BALL, collide = false, cast = false, t = 0.08 })
	Part(parent, "Cloud", Vector3.new(s, s * 0.8, s * 0.9), CFrame.new(pos + Vector3.new(s * 0.6, s * 0.2, 0)), col, M.SmoothPlastic, { shape = BALL, collide = false, cast = false, t = 0.08 })
	Part(parent, "Cloud", Vector3.new(s * 0.9, s * 0.6, s * 0.8), CFrame.new(pos + Vector3.new(-s * 0.7, -s * 0.05, s * 0.1)), col, M.SmoothPlastic, { shape = BALL, collide = false, cast = false, t = 0.08 })
end

function Prefabs.TrafficLight(parent, pos, yaw)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw or 0, 0)
	if Prefabs.FromTemplate("TrafficLight", parent, cf) then
		return
	end
	Part(parent, "TLPole", Vector3.new(0.6, 10, 0.6), cf * CFrame.new(0, 5, 0), DARK, M.Metal)
	Part(parent, "TLBox", Vector3.new(1.4, 4, 1.2), cf * CFrame.new(0, 10.5, 0), C(40, 42, 50), M.SmoothPlastic)
	Part(parent, "TLRed", Vector3.new(0.9, 0.9, 0.3), cf * CFrame.new(0, 11.8, -0.6), C(255, 70, 70), M.Neon, { collide = false, cast = false })
	Part(parent, "TLYellow", Vector3.new(0.9, 0.9, 0.3), cf * CFrame.new(0, 10.6, -0.6), C(120, 110, 60), M.SmoothPlastic, { collide = false, cast = false })
	Part(parent, "TLGreen", Vector3.new(0.9, 0.9, 0.3), cf * CFrame.new(0, 9.4, -0.6), C(60, 110, 70), M.SmoothPlastic, { collide = false, cast = false })
end

function Prefabs.BusStop(parent, pos, yaw, color)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw or 0, 0)
	if Prefabs.FromTemplate("BusStop", parent, cf, { colors = { Trim = color } }) then
		return
	end
	Part(parent, "StopRoof", Vector3.new(10, 0.5, 3.4), cf * CFrame.new(0, 8, 0), color, M.SmoothPlastic)
	Part(parent, "StopBack", Vector3.new(10, 6, 0.3), cf * CFrame.new(0, 4.6, 1.5), GLASS, M.Glass, { t = 0.45 })
	for _, x in ipairs({ -4.8, 4.8 }) do
		Part(parent, "StopPost", Vector3.new(0.4, 7.6, 0.4), cf * CFrame.new(x, 4, 1.4), DARK, M.Metal)
	end
	Part(parent, "StopSeat", Vector3.new(7, 0.5, 1.4), cf * CFrame.new(0, 2, 0.7), C(240, 240, 240), M.SmoothPlastic)
	local sign = Part(parent, "StopSign", Vector3.new(3.6, 1.2, 0.2), cf * CFrame.new(-3, 7, -1.5), color, M.SmoothPlastic, { collide = false })
	Label(sign, Enum.NormalId.Front, "BUS", C(255, 255, 255))
end

function Prefabs.Hydrant(parent, pos)
	if Prefabs.FromTemplate("Hydrant", parent, CFrame.new(pos)) then
		return
	end
	Part(parent, "Hydrant", Vector3.new(2.2, 1.4, 1.4), CFrame.new(pos + Vector3.new(0, 1.1, 0)) * UPRIGHT, C(230, 60, 60), M.SmoothPlastic, { shape = CYL })
	Part(parent, "HydrantCap", Vector3.new(1.2, 1.2, 1.2), CFrame.new(pos + Vector3.new(0, 2.3, 0)), C(230, 60, 60), M.SmoothPlastic, { shape = BALL, collide = false })
end

function Prefabs.Bin(parent, pos, color)
	if Prefabs.FromTemplate("Bin", parent, CFrame.new(pos), { colors = { Green = color } }) then
		return
	end
	Part(parent, "Bin", Vector3.new(3, 2, 2), CFrame.new(pos + Vector3.new(0, 1.5, 0)) * UPRIGHT, color or C(70, 150, 110), M.SmoothPlastic, { shape = CYL })
	Part(parent, "BinLid", Vector3.new(0.3, 2.2, 2.2), CFrame.new(pos + Vector3.new(0, 3.1, 0)) * UPRIGHT, DARK, M.SmoothPlastic, { shape = CYL, collide = false })
end

function Prefabs.Cone(parent, pos)
	if Prefabs.FromTemplate("Cone", parent, CFrame.new(pos)) then
		return
	end
	Part(parent, "ConeBase", Vector3.new(1.8, 0.3, 1.8), CFrame.new(pos + Vector3.new(0, 0.15, 0)), C(255, 130, 30), M.SmoothPlastic, { collide = false })
	Part(parent, "Cone", Vector3.new(1.8, 1.1, 1.1), CFrame.new(pos + Vector3.new(0, 1, 0)) * UPRIGHT, C(255, 130, 30), M.SmoothPlastic, { shape = CYL, collide = false })
	Part(parent, "ConeStripe", Vector3.new(0.4, 1.15, 1.15), CFrame.new(pos + Vector3.new(0, 1.2, 0)) * UPRIGHT, C(250, 250, 250), M.SmoothPlastic, { shape = CYL, collide = false })
end

function Prefabs.Pallet(parent, pos, yaw, rng)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw or 0, 0)
	if Prefabs.FromTemplate("Pallet", parent, cf) then
		return
	end
	Part(parent, "Pallet", Vector3.new(5, 0.6, 5), cf * CFrame.new(0, 0.3, 0), C(176, 132, 84), M.Wood)
	local h = math.floor(rr(rng, 1, 3.99))
	for i = 1, h do
		Part(parent, "Crate", Vector3.new(4.4, 2.2, 4.4), cf * CFrame.new(0, 0.6 + (i - 0.5) * 2.25, 0), pick(rng, { C(196, 150, 96), C(170, 128, 80), C(120, 140, 170) }), M.Wood)
	end
end

function Prefabs.Forklift(parent, pos, yaw)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw or 0, 0)
	if Prefabs.FromTemplate("Forklift", parent, cf) then
		return
	end
	Part(parent, "FLBody", Vector3.new(6, 2.6, 4), cf * CFrame.new(0, 2.1, 0), C(255, 196, 40), M.SmoothPlastic)
	Part(parent, "FLSeat", Vector3.new(2, 1.2, 2.4), cf * CFrame.new(-0.6, 4, 0), DARK)
	Part(parent, "FLRoof", Vector3.new(3.6, 0.3, 3.8), cf * CFrame.new(-0.4, 7.4, 0), DARK, M.Metal)
	for _, z in ipairs({ -1.7, 1.7 }) do
		Part(parent, "FLPost", Vector3.new(0.3, 4, 0.3), cf * CFrame.new(1.2, 5.4, z), DARK, M.Metal)
		Part(parent, "FLPostB", Vector3.new(0.3, 4, 0.3), cf * CFrame.new(-2, 5.4, z), DARK, M.Metal)
		Part(parent, "FLFork", Vector3.new(4, 0.25, 0.6), cf * CFrame.new(5, 0.6, z * 0.6), C(90, 90, 96), M.Metal)
	end
	Part(parent, "FLMast", Vector3.new(0.5, 7, 3.6), cf * CFrame.new(3.2, 4, 0), C(90, 90, 96), M.Metal)
	for _, x in ipairs({ -1.8, 1.8 }) do
		for _, z in ipairs({ -2, 2 }) do
			Part(parent, "FLWheel", Vector3.new(1, 2, 2), cf * CFrame.new(x, 1, z) * CFrame.Angles(0, math.pi / 2, 0), C(30, 30, 34), M.SmoothPlastic, { shape = CYL })
		end
	end
end

function Prefabs.Crane(parent, pos, yaw, accent)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw or 0, 0)
	Part(parent, "CraneMast", Vector3.new(3, 60, 3), cf * CFrame.new(0, 30, 0), accent, M.Metal)
	Part(parent, "CraneJib", Vector3.new(50, 2.4, 2.4), cf * CFrame.new(12, 60, 0), accent, M.Metal)
	Part(parent, "CraneCab", Vector3.new(5, 4, 4), cf * CFrame.new(0, 57, 0), C(240, 240, 240), M.SmoothPlastic)
	Part(parent, "CraneWeight", Vector3.new(6, 4, 4), cf * CFrame.new(-11, 58, 0), C(110, 110, 120), M.Concrete)
	Part(parent, "CraneCable", Vector3.new(0.3, 26, 0.3), cf * CFrame.new(30, 47, 0), DARK, M.Metal, { collide = false })
	Part(parent, "CraneLoad", Vector3.new(10, 4, 4), cf * CFrame.new(30, 32, 0), C(60, 110, 190), M.Metal, { collide = false })
	Part(parent, "CraneBeacon", Vector3.new(1.2, 1.2, 1.2), cf * CFrame.new(0, 62, 0), C(255, 60, 60), M.Neon, { shape = BALL, collide = false })
end

function Prefabs.HoloRing(parent, pos, color, size)
	size = size or 10
	Part(parent, "HoloRing", Vector3.new(0.4, size, size), CFrame.new(pos) * CFrame.Angles(0, math.pi / 2, 0), color, M.Neon, { shape = CYL, t = 0.5, collide = false, cast = false })
	Part(parent, "HoloRingIn", Vector3.new(0.5, size - 1.6, size - 1.6), CFrame.new(pos) * CFrame.Angles(0, math.pi / 2, 0), C(14, 12, 28), M.SmoothPlastic, { shape = CYL, t = 0.75, collide = false, cast = false })
end

function Prefabs.Gantry(parent, x, z0, width, text, accent)
	for _, s in ipairs({ -1, 1 }) do
		Part(parent, "GantryPost", Vector3.new(1.4, 20, 1.4), CFrame.new(x, 10.8, z0 + s * (width / 2 + 3)), C(150, 154, 162), M.Metal)
	end
	Part(parent, "GantryBeam", Vector3.new(1.6, 1.6, width + 8), CFrame.new(x, 20.4, z0), C(150, 154, 162), M.Metal)
	local b = Part(parent, "GantrySign", Vector3.new(0.6, 5, width * 0.6), CFrame.new(x, 17, z0), C(30, 120, 70), M.SmoothPlastic)
	Label(b, Enum.NormalId.Left, text, C(255, 255, 255))
	Label(b, Enum.NormalId.Right, text, C(255, 255, 255))
	Part(parent, "GantryTrim", Vector3.new(0.7, 0.3, width * 0.6), CFrame.new(x, 14.4, z0), accent, M.Neon, { collide = false })
end

-- concrete barrier / barrel: Blender model or a block
function Prefabs.Barrier(parent, pos, yaw, color)
	if Prefabs.FromTemplate("Barrier", parent, CFrame.new(pos) * CFrame.Angles(0, yaw or 0, 0)) then
		return
	end
	Part(parent, "Barrier", Vector3.new(7, 1.6, 1.6), CFrame.new(pos + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, yaw or 0, 0), color or C(190, 192, 200), M.Concrete)
end

function Prefabs.Barrel(parent, pos, color)
	if Prefabs.FromTemplate("Barrel", parent, CFrame.new(pos), { colors = { Accent = color } }) then
		return
	end
	Part(parent, "Barrel", Vector3.new(3.6, 3, 3), CFrame.new(pos + Vector3.new(0, 1.8, 0)) * UPRIGHT, color, M.Metal, { shape = CYL })
end

local B = {}

local function mkb(parent, cf)
	return function(name, size, off, color, mat, o)
		return Part(parent, name, size, cf * CFrame.new(off), color, mat, o)
	end
end

function B.shop(parent, cf, w, d, h, pal, rng)
	local mk = mkb(parent, cf)
	local col = pick(rng, pal.buildings)
	mk("Body", Vector3.new(w, h, d), Vector3.new(0, h / 2, 0), col)
	mk("Trim", Vector3.new(w + 1, 0.8, d + 1), Vector3.new(0, h + 0.4, 0), pal.accent)
	mk("Glass", Vector3.new(w * 0.8, 3.4, 0.3), Vector3.new(0, 2.6, -d / 2 - 0.1), GLASS, M.Glass, { t = 0.3 })
	for i = 1, 3 do
		mk("Mullion", Vector3.new(0.3, 3.4, 0.4), Vector3.new(-w * 0.4 + i * w * 0.2, 2.6, -d / 2 - 0.15), C(250, 250, 250))
	end
	mk("Door", Vector3.new(3, 4.6, 0.4), Vector3.new(w * 0.3, 2.3, -d / 2 - 0.2), DARK)
	mk("Plinth", Vector3.new(w + 0.4, 0.8, d + 0.4), Vector3.new(0, 0.4, 0), C(225, 220, 212), M.Concrete)
	for fl = 1, math.floor((h - 7) / 4) do
		mk("UpperWin", Vector3.new(w * 0.7, 1.8, 0.3), Vector3.new(0, 6.5 + fl * 3.6, -d / 2 - 0.1), GLASS, M.Glass, { t = 0.25 })
	end
	mk("Awning", Vector3.new(w * 0.9, 0.5, 3.4), Vector3.new(0, 5.2, -d / 2 - 1.8), pal.accent2 or pal.accent)
	local sign = mk("Sign", Vector3.new(w * 0.6, 2.2, 0.4), Vector3.new(0, h - 1.8, -d / 2 - 0.3), DARK)
	Label(sign, Enum.NormalId.Front, pick(rng, { "PARTS", "TIRES", "AUTO", "SHOP", "MARKET", "SPEED" }), pal.accent)
	mk("AC", Vector3.new(3.4, 1.6, 3.4), Vector3.new(w / 4, h + 1.6, 0), C(170, 175, 185), M.Metal)
end

function B.house(parent, cf, w, d, h, pal, rng)
	local mk = mkb(parent, cf)
	h = math.min(h, 14)
	local col = pick(rng, pal.buildings)
	mk("Body", Vector3.new(w, h, d), Vector3.new(0, h / 2, 0), col)
	local roofH = math.min(9, d * 0.45)
	local roofCol = pick(rng, { C(200, 96, 80), C(110, 120, 150), C(90, 150, 140), C(160, 110, 170) })
	Part(parent, "RoofF", Vector3.new(w + 1.6, roofH, d / 2 + 0.8), cf * CFrame.new(0, h + roofH / 2, -d / 4 - 0.4), roofCol, M.SmoothPlastic, { class = "WedgePart" })
	Part(parent, "RoofB", Vector3.new(w + 1.6, roofH, d / 2 + 0.8), cf * CFrame.new(0, h + roofH / 2, d / 4 + 0.4) * CFrame.Angles(0, math.pi, 0), roofCol, M.SmoothPlastic, { class = "WedgePart" })
	mk("Chimney", Vector3.new(2.2, roofH, 2.2), Vector3.new(w * 0.3, h + roofH / 2 + 1, d * 0.15), C(170, 110, 90), M.Brick)
	local n = math.max(2, math.floor(w / 7))
	for i = 1, n do
		local x = -w / 2 + (i - 0.5) * (w / n)
		for fl = 0, math.floor((h - 3) / 5) - 1 do
			if not (fl == 0 and i == math.ceil(n / 2)) then
				mk("Win", Vector3.new(3, 2.8, 0.3), Vector3.new(x, 3.6 + fl * 5, -d / 2 - 0.1), GLASS, M.Glass, { t = 0.2 })
				mk("WinFrame", Vector3.new(3.6, 0.4, 0.5), Vector3.new(x, 2.1 + fl * 5, -d / 2 - 0.2), C(250, 250, 250))
			end
		end
	end
	mk("Door", Vector3.new(3.4, 5, 0.4), Vector3.new((math.ceil(n / 2) - 0.5) * (w / n) - w / 2, 2.5, -d / 2 - 0.2), pick(rng, { C(120, 80, 60), C(60, 110, 160), C(200, 80, 80) }))
	mk("Step", Vector3.new(5, 0.6, 2), Vector3.new((math.ceil(n / 2) - 0.5) * (w / n) - w / 2, 0.3, -d / 2 - 1), C(220, 214, 204), M.Concrete)
end

function B.cafe(parent, cf, w, d, h, pal, rng)
	local mk = mkb(parent, cf)
	h = math.min(h, 9)
	mk("Body", Vector3.new(w, h, d), Vector3.new(0, h / 2, 0), pick(rng, pal.buildings))
	mk("Glass", Vector3.new(w * 0.85, 3.6, 0.3), Vector3.new(0, 2.7, -d / 2 - 0.1), GLASS, M.Glass, { t = 0.3 })
	local n = 6
	for i = 1, n do
		local c = (i % 2 == 0) and C(250, 250, 250) or pal.accent
		mk("Stripe", Vector3.new(w * 0.9 / n, 0.4, 4), Vector3.new(-w * 0.45 + (i - 0.5) * (w * 0.9 / n), 5.4 - 0.1 * i, -d / 2 - 2.2), c)
	end
	local sign = mk("Sign", Vector3.new(w * 0.5, 2, 0.4), Vector3.new(0, h - 1.4, -d / 2 - 0.3), DARK)
	Label(sign, Enum.NormalId.Front, "CAFE", C(255, 200, 120))
	for i = -1, 1, 2 do
		mk("TableTop", Vector3.new(0.3, 3, 3), Vector3.new(i * w * 0.25, 2.4, -d / 2 - 6), C(240, 240, 240), M.SmoothPlastic, { shape = CYL }).CFrame = cf * CFrame.new(i * w * 0.25, 2.4, -d / 2 - 6) * UPRIGHT
		mk("TablePole", Vector3.new(2.2, 0.4, 0.4), Vector3.new(i * w * 0.25, 1.2, -d / 2 - 6), DARK).CFrame = cf * CFrame.new(i * w * 0.25, 1.2, -d / 2 - 6) * UPRIGHT
	end
end

function B.apartment(parent, cf, w, d, h, pal, rng)
	local mk = mkb(parent, cf)
	mk("Body", Vector3.new(w, h, d), Vector3.new(0, h / 2, 0), pick(rng, pal.buildings))
	local floors = math.floor((h - 4) / 4)
	for i = 0, floors - 1 do
		mk("Windows", Vector3.new(w - 4, 2.2, 0.3), Vector3.new(0, 5 + i * 4, -d / 2 - 0.1), GLASS, M.Glass, { t = 0.25 })
	end
	mk("Entrance", Vector3.new(5, 4, 0.5), Vector3.new(0, 2, -d / 2 - 0.2), DARK)
	mk("Ledge", Vector3.new(w + 1.2, 1, d + 1.2), Vector3.new(0, h + 0.5, 0), pal.accent)
	mk("Tank", Vector3.new(4, 4, 4), Vector3.new(-w / 4, h + 3, 0), C(140, 140, 150), M.Metal, { shape = CYL }).CFrame = cf * CFrame.new(-w / 4, h + 3, 0) * UPRIGHT
	for i = 0, floors - 1 do
		if i % 2 == 1 then
			for _, sx in ipairs({ -1, 1 }) do
				mk("Balcony", Vector3.new(6, 0.5, 2.2), Vector3.new(sx * w * 0.25, 3.8 + i * 4, -d / 2 - 1.1), C(240, 240, 244))
				mk("Rail", Vector3.new(6, 1.2, 0.2), Vector3.new(sx * w * 0.25, 4.6 + i * 4, -d / 2 - 2.1), pal.accent)
			end
		end
	end
	mk("RoofGarden", Vector3.new(w * 0.35, 0.8, d * 0.4), Vector3.new(w / 5, h + 1.4, 0), C(100, 170, 90), M.Grass)
end

function B.tower(parent, cf, w, d, h, pal, rng)
	local mk = mkb(parent, cf)
	local col = pick(rng, pal.buildings)
	local h1 = h * 0.62
	mk("Base", Vector3.new(w, h1, d), Vector3.new(0, h1 / 2, 0), col)
	mk("Top", Vector3.new(w * 0.72, h - h1, d * 0.72), Vector3.new(0, h1 + (h - h1) / 2, 0), col)
	for i = 0, math.floor(h1 / 5) - 1 do
		mk("WinBand", Vector3.new(w - 3, 2.4, 0.3), Vector3.new(0, 4 + i * 5, -d / 2 - 0.1), GLASS, M.Glass, { t = 0.2 })
	end
	mk("Spire", Vector3.new(0.6, 8, 0.6), Vector3.new(0, h + 4, 0), DARK, M.Metal)
	mk("Beacon", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, h + 8.4, 0), C(255, 60, 60), M.Neon, { shape = BALL })
end

function B.dealership(parent, cf, w, d, h, pal, rng)
	local mk = mkb(parent, cf)
	h = math.min(h, 10)
	mk("Back", Vector3.new(w, h, 3), Vector3.new(0, h / 2, d / 2 - 1.5), C(230, 232, 238))
	mk("SideL", Vector3.new(3, h, d), Vector3.new(-w / 2 + 1.5, h / 2, 0), C(230, 232, 238))
	mk("SideR", Vector3.new(3, h, d), Vector3.new(w / 2 - 1.5, h / 2, 0), C(230, 232, 238))
	mk("Roof", Vector3.new(w + 2, 1, d + 4), Vector3.new(0, h + 0.5, -1), pal.accent)
	mk("Glass", Vector3.new(w - 6, h - 2, 0.3), Vector3.new(0, h / 2, -d / 2), GLASS, M.Glass, { t = 0.5 })
	mk("Floor", Vector3.new(w - 6, 0.3, d - 3), Vector3.new(0, 0.3, 0), C(60, 62, 70))
	local sign = mk("Sign", Vector3.new(w * 0.5, 2.6, 0.4), Vector3.new(0, h + 2.2, -d / 2 - 1), DARK)
	Label(sign, Enum.NormalId.Front, "MOTORS", pal.accent)
	local car = VehicleFactory.Build(pick(rng, { "sport", "supercar", "sedan" }), { BodyColor = pick(rng, { C(220, 50, 50), C(240, 200, 40), C(60, 120, 230) }), Spoiler = true })
	car:PivotTo(cf * CFrame.new(0, 0.5, -d / 2 + 9) * CFrame.Angles(0, math.pi / 2 + 0.4, 0))
	car.Parent = parent
end

function B.garage(parent, cf, w, d, h, pal, rng)
	local mk = mkb(parent, cf)
	h = math.min(h, 10)
	mk("Body", Vector3.new(w, h, d), Vector3.new(0, h / 2, 0), C(160, 165, 175))
	for i = 0, 3 do
		mk("Roller", Vector3.new(w * 0.55, 1.4, 0.4), Vector3.new(0, 1 + i * 1.5, -d / 2 - 0.2), (i % 2 == 0) and C(235, 235, 240) or C(205, 208, 215))
	end
	mk("Hazard", Vector3.new(w * 0.6, 0.6, 0.5), Vector3.new(0, 7.4, -d / 2 - 0.2), C(255, 200, 30))
	mk("Roof", Vector3.new(w + 1, 0.8, d + 1), Vector3.new(0, h + 0.4, 0), pal.accent)
end

function B.billboard(parent, cf, w, d, h, pal, rng)
	local mk = mkb(parent, cf)
	mk("PostL", Vector3.new(1.4, 20, 1.4), Vector3.new(-w / 3, 10, 0), DARK, M.Metal)
	mk("PostR", Vector3.new(1.4, 20, 1.4), Vector3.new(w / 3, 10, 0), DARK, M.Metal)
	local b = mk("Board", Vector3.new(w, 12, 1), Vector3.new(0, 24, 0), C(20, 22, 30))
	local msgs = { "TURBO FUEL", "FAST LANE", "HUNT THE CARS", "NITRO DRINK", "ROAD KING" }
	local t = pick(rng, msgs)
	Label(b, Enum.NormalId.Front, t, pal.accent)
	Label(b, Enum.NormalId.Back, t, pal.accent)
end

function B.gasstation(parent, cf, w, d, h, pal, rng)
	local mk = mkb(parent, cf)
	mk("Shop", Vector3.new(w * 0.45, 8, d * 0.5), Vector3.new(w * 0.27, 4, d * 0.2), C(235, 235, 240))
	mk("ShopGlass", Vector3.new(w * 0.35, 3, 0.3), Vector3.new(w * 0.27, 3, d * 0.2 - d * 0.25 - 0.1), GLASS, M.Glass, { t = 0.3 })
	mk("Canopy", Vector3.new(w * 0.7, 1, d * 0.45), Vector3.new(-w * 0.12, 10, -d * 0.18), pal.accent2 or pal.accent)
	for _, sx in ipairs({ -1, 1 }) do
		mk("Pillar", Vector3.new(1.2, 10, 1.2), Vector3.new(-w * 0.12 + sx * w * 0.3, 5, -d * 0.18 - d * 0.18), DARK, M.Metal)
	end
	for i = -1, 1, 2 do
		mk("Pump", Vector3.new(1.6, 4, 2.4), Vector3.new(-w * 0.12 + i * w * 0.12, 2, -d * 0.18), pal.accent)
	end
	local s = mk("Sign", Vector3.new(w * 0.5, 2, 0.4), Vector3.new(-w * 0.12, 11.3, -d * 0.4), DARK)
	Label(s, Enum.NormalId.Front, "FUEL", C(255, 240, 120))
end

function B.motel(parent, cf, w, d, h, pal, rng)
	local mk = mkb(parent, cf)
	h = math.min(h, 9)
	mk("Body", Vector3.new(w, h, d), Vector3.new(0, h / 2, 0), pick(rng, pal.buildings))
	local n = math.floor(w / 8)
	for i = 1, n do
		local x = -w / 2 + (i - 0.5) * (w / n)
		mk("Door", Vector3.new(2.6, 4.6, 0.4), Vector3.new(x, 2.3, -d / 2 - 0.2), DARK)
		mk("Window", Vector3.new(3, 2.4, 0.3), Vector3.new(x, 6.4, -d / 2 - 0.1), GLASS, M.Glass, { t = 0.25 })
	end
	mk("Roof", Vector3.new(w + 1.5, 0.8, d + 1.5), Vector3.new(0, h + 0.4, 0), pal.accent)
end

function B.warehouse(parent, cf, w, d, h, pal, rng)
	local mk = mkb(parent, cf)
	h = math.max(h, 12)
	mk("Body", Vector3.new(w, h, d), Vector3.new(0, h / 2, 0), pick(rng, pal.buildings), M.Metal)
	local ribs = math.floor(w / 6)
	for i = 1, ribs do
		mk("Rib", Vector3.new(1, 1.2, d + 1), Vector3.new(-w / 2 + (i - 0.5) * (w / ribs), h + 0.6, 0), C(120, 126, 136), M.Metal)
	end
	mk("Door", Vector3.new(w * 0.4, h * 0.6, 0.4), Vector3.new(0, h * 0.3, -d / 2 - 0.2), C(90, 96, 108), M.Metal)
	mk("DoorStripe", Vector3.new(w * 0.4, 0.8, 0.5), Vector3.new(0, h * 0.62, -d / 2 - 0.2), pal.accent)
	mk("Vent", Vector3.new(3, 2, 3), Vector3.new(w * 0.3, h + 2, 0), C(170, 175, 185), M.Metal)
end

function B.containers(parent, cf, w, d, h, pal, rng)
	local mk = mkb(parent, cf)
	local cols = { C(200, 70, 50), C(60, 110, 190), C(230, 180, 40), C(70, 150, 90), C(180, 180, 190) }
	local nx = math.max(1, math.floor(w / 13))
	for ix = 1, nx do
		local stack = math.floor(rr(rng, 1, 4))
		for iy = 1, stack do
			local off = Vector3.new(-w / 2 + (ix - 0.5) * (w / nx), (iy - 1) * 4.3, -d / 2 + 4)
			if not Prefabs.FromTemplate("Container", parent, cf * CFrame.new(off), { colors = { Trim = pick(rng, cols) } }) then
				mk("Container", Vector3.new(12, 4.2, 5), off + Vector3.new(0, 2.1, 0), pick(rng, cols), M.Metal)
			end
		end
		local stack2 = math.floor(rr(rng, 1, 3))
		for iy = 1, stack2 do
			local off = Vector3.new(-w / 2 + (ix - 0.5) * (w / nx), (iy - 1) * 4.3, -d / 2 + 10)
			if not Prefabs.FromTemplate("Container", parent, cf * CFrame.new(off), { colors = { Trim = pick(rng, cols) } }) then
				mk("Container", Vector3.new(12, 4.2, 5), off + Vector3.new(0, 2.1, 0), pick(rng, cols), M.Metal)
			end
		end
	end
end

function B.silo(parent, cf, w, d, h, pal, rng)
	local mk = mkb(parent, cf)
	local r = math.min(w, d) * 0.4
	for i = -1, 1, 2 do
		local x = i * r * 1.1
		mk("Silo", Vector3.new(h, r * 2, r * 2), Vector3.new(x, h / 2, 0), C(200, 204, 212), M.Metal, { shape = CYL }).CFrame = cf * CFrame.new(x, h / 2, 0) * UPRIGHT
		mk("Dome", Vector3.new(r * 2, r * 1.2, r * 2), Vector3.new(x, h + 0.2, 0), C(170, 90, 70), M.Metal, { shape = BALL })
	end
	mk("Pipe", Vector3.new(r * 2.4, 1, 1), Vector3.new(0, h * 0.7, 0), C(90, 96, 108), M.Metal)
end

function B.factory(parent, cf, w, d, h, pal, rng)
	local mk = mkb(parent, cf)
	h = math.max(h, 14)
	mk("Body", Vector3.new(w, h, d), Vector3.new(0, h / 2, 0), pick(rng, pal.buildings), M.Brick)
	for i = 1, 3 do
		mk("Window", Vector3.new(w * 0.18, 3, 0.3), Vector3.new(-w * 0.3 + (i - 1) * w * 0.3, h * 0.6, -d / 2 - 0.1), C(255, 210, 120), M.Neon, { t = 0.2 })
	end
	mk("Chimney", Vector3.new(h * 1.2, 3.2, 3.2), Vector3.new(w * 0.3, h + h * 0.55, d * 0.2), C(120, 90, 80), M.Brick, { shape = CYL }).CFrame = cf * CFrame.new(w * 0.3, h + h * 0.55, d * 0.2) * UPRIGHT
	mk("ChimneyTop", Vector3.new(3.8, 1.2, 3.8), Vector3.new(w * 0.3, h + h * 1.1, d * 0.2), pal.accent, M.SmoothPlastic)
	mk("Roof", Vector3.new(w + 1, 1, d + 1), Vector3.new(0, h + 0.5, 0), C(100, 104, 114), M.Metal)
end

function B.pipes(parent, cf, w, d, h, pal, rng)
	local mk = mkb(parent, cf)
	for i = 0, 2 do
		mk("Pipe", Vector3.new(w, 2.2, 2.2), Vector3.new(0, 4 + i * 2.8, 0), (i % 2 == 0) and C(190, 90, 60) or C(120, 130, 145), M.Metal, { shape = CYL })
	end
	for i = 0, 3 do
		mk("Support", Vector3.new(1.2, 10, 3), Vector3.new(-w / 2 + 3 + i * (w - 6) / 3, 5, 0), DARK, M.Metal)
	end
end

function B.neontower(parent, cf, w, d, h, pal, rng)
	local mk = mkb(parent, cf)
	local col = pick(rng, pal.buildings)
	mk("Body", Vector3.new(w, h, d), Vector3.new(0, h / 2, 0), col)
	local nc = pick(rng, { pal.accent, pal.accent2 })
	for i = -1, 1 do
		mk("NeonStrip", Vector3.new(0.8, h * 0.9, 0.5), Vector3.new(i * w * 0.3, h / 2, -d / 2 - 0.2), nc, M.Neon)
	end
	for i = 0, math.floor(h / 8) - 1 do
		mk("WinBand", Vector3.new(w - 4, 1.2, 0.3), Vector3.new(0, 5 + i * 8, -d / 2 - 0.15), C(120, 180, 255), M.Neon, { t = 0.5 })
	end
	mk("TopRing", Vector3.new(w + 2, 1, d + 2), Vector3.new(0, h + 0.5, 0), nc, M.Neon)
end

function B.club(parent, cf, w, d, h, pal, rng)
	local mk = mkb(parent, cf)
	h = math.min(h, 12)
	mk("Body", Vector3.new(w, h, d), Vector3.new(0, h / 2, 0), C(18, 18, 28))
	local sign = mk("Sign", Vector3.new(w * 0.8, 5, 0.6), Vector3.new(0, h - 2, -d / 2 - 0.4), C(8, 8, 14))
	Label(sign, Enum.NormalId.Front, pick(rng, { "NEON CLUB", "TURBO BAR", "HOLO LOUNGE", "DRIFT" }), pal.accent)
	mk("DoorGlow", Vector3.new(5, 6, 0.4), Vector3.new(0, 3, -d / 2 - 0.3), pal.accent2, M.Neon)
	mk("EdgeL", Vector3.new(0.6, h, 0.6), Vector3.new(-w / 2, h / 2, -d / 2), pal.accent, M.Neon)
	mk("EdgeR", Vector3.new(0.6, h, 0.6), Vector3.new(w / 2, h / 2, -d / 2), pal.accent, M.Neon)
end

function B.holosign(parent, cf, w, d, h, pal, rng)
	local mk = mkb(parent, cf)
	mk("Pole", Vector3.new(1.2, 12, 1.2), Vector3.new(0, 6, 0), DARK, M.Metal)
	local s = mk("Holo", Vector3.new(w, 10, 0.5), Vector3.new(0, 17, 0), pal.accent2, M.Neon, { t = 0.55, collide = false })
	Label(s, Enum.NormalId.Front, pick(rng, { "HUNT", "SPEED", "NEON", "WIN" }), C(255, 255, 255))
	Label(s, Enum.NormalId.Back, "HUNT", C(255, 255, 255))
	mk("Frame", Vector3.new(w + 1, 0.6, 0.8), Vector3.new(0, 22.2, 0), pal.accent, M.Neon)
	mk("FrameB", Vector3.new(w + 1, 0.6, 0.8), Vector3.new(0, 11.8, 0), pal.accent, M.Neon)
end

Prefabs.Buildings = B

function Prefabs.TireStack(parent, pos, rng)
	if Prefabs.FromTemplate("TireStack", parent, CFrame.new(pos) * CFrame.Angles(0, rr(rng, 0, 6), 0)) then
		return
	end
	local n = math.floor(rr(rng, 2, 4.99))
	for i = 1, n do
		local cf = CFrame.new(pos + Vector3.new(rr(rng, -0.3, 0.3), 0.75 + (i - 1) * 1.45, rr(rng, -0.3, 0.3))) * UPRIGHT
		Part(parent, "Tire", Vector3.new(1.4, 4, 4), cf, C(30, 30, 34), M.SmoothPlastic, { shape = CYL })
		Part(parent, "TireRim", Vector3.new(1.46, 2, 2), cf, pick(rng, { C(255, 210, 63), C(255, 59, 59), C(46, 168, 255), C(52, 208, 88) }), M.SmoothPlastic, { shape = CYL, collide = false })
	end
end

-- checkered strip (finish-line flag look)
function Prefabs.Checker(parent, cf, len, h, d)
	local n = math.floor(len / 2)
	for i = 0, n - 1 do
		for row = 0, 1 do
			if (i + row) % 2 == 0 then
				Part(parent, "Checker", Vector3.new(len / n, h / 2, d), cf * CFrame.new(-len / 2 + (i + 0.5) * len / n, (row - 0.5) * h / 2, 0), C(250, 250, 250), M.SmoothPlastic, { collide = false, cast = false })
			end
		end
	end
	Part(parent, "CheckerBack", Vector3.new(len, h, d - 0.1), cf, C(20, 20, 24), M.SmoothPlastic, { collide = false })
end

local PARKED = { "compact", "sedan", "taxi", "van", "pickup", "sport" }
function Prefabs.ParkedCar(parent, cf, rng, kinds)
	local kind = pick(rng, kinds or PARKED)
	local m = VehicleFactory.BuildTraffic(kind, pick(rng, MapConfig.TrafficColors), math.floor(rr(rng, 1, 9)))
	m:PivotTo(cf)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = d.Name == "Root" and false or true
		end
	end
	m.Parent = parent
	Prefabs.Count = Prefabs.Count + 1
	return m
end

Prefabs.Archetypes = {
	city = {
		{ "shop", 24, 36, 10, 14 }, { "cafe", 22, 30, 8, 9 }, { "apartment", 26, 36, 18, 28 }, { "house", 22, 30, 10, 13 },
		{ "tower", 26, 32, 28, 40 }, { "dealership", 38, 46, 9, 10 }, { "garage", 24, 32, 9, 10 },
	},
	highway = {
		{ "gasstation", 40, 48, 8, 8 }, { "motel", 40, 58, 8, 9 }, { "billboard", 34, 40, 20, 20 },
		{ "shop", 26, 34, 10, 12 }, { "tower", 26, 32, 24, 34 },
	},
	industrial = {
		{ "warehouse", 36, 56, 12, 16 }, { "containers", 28, 40, 8, 8 }, { "silo", 24, 30, 22, 28 },
		{ "factory", 34, 44, 14, 20 }, { "pipes", 30, 44, 10, 10 },
	},
	neon = {
		{ "neontower", 26, 34, 30, 52 }, { "club", 30, 40, 10, 12 }, { "holosign", 20, 24, 20, 22 },
		{ "neontower", 24, 30, 26, 44 }, { "club", 28, 36, 9, 11 },
	},
}

-- Blender building scaled to fit the lot (footprint from ModelSizes), recoloured with the district palette
local ROOFS = { C(200, 96, 80), C(110, 120, 150), C(90, 150, 140), C(160, 110, 170), C(230, 170, 70) }
function Prefabs.Building(kind, parent, cf, w, d, h, pal, rng)
	local info = ModelSizes["B_" .. kind]
	if info and info.w and kind ~= "containers" and kind ~= "billboard" and kind ~= "holosign" and kind ~= "pipes" then
		local s = math.min(w / info.w, d / info.d)
		local m = Prefabs.FromTemplate("B_" .. kind, parent, cf, { scale = s, colors = { Wall = pick(rng, pal.buildings), Trim = pal.accent, Roof = pick(rng, ROOFS) } })
		if m then
			return
		end
	end
	local fn = B[kind]
	if fn then
		fn(parent, cf, w, d, h, pal, rng)
	end
end

return Prefabs
