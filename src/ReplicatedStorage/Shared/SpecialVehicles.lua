-- Hand-built shapes that are not cars: freight train, taxiing airliner, monster trucks (bosses).
-- Same contract as VehicleFactory: Model with an anchored, invisible PrimaryPart "Root" at ground level,
-- everything else welded to it, length along local +X.
local SV = {}
local C = Color3.fromRGB
local M = Enum.Material
local CYL = Enum.PartType.Cylinder

local function kit(name)
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 0.2, 1)
	root.Anchored, root.CanCollide, root.CanQuery, root.CanTouch = true, false, false, false
	root.Transparency = 1
	root.Parent = model
	model.PrimaryPart = root
	local function add(n, size, off, color, mat, shape)
		local p = Instance.new("Part")
		p.Name = n
		p.Size = size
		p.CFrame = off
		p.Color = color
		p.Material = mat or M.SmoothPlastic
		if shape then
			p.Shape = shape
		end
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, false, true
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = root, p
		w.Parent = p
		p.Parent = model
		return p
	end
	return model, add
end

local function wheelRow(add, x0, x1, step, z, y, r, color)
	for x = x0, x1, step do
		add("Wheel", Vector3.new(0.8, r * 2, r * 2), CFrame.new(x, y, z) * CFrame.Angles(0, math.pi / 2, 0), color, M.Metal, CYL)
	end
end

function SV.Train(color)
	local m, add = kit("Train")
	color = color or C(214, 52, 44)
	local DARK, STEEL = C(36, 38, 44), C(120, 124, 132)
	-- locomotive (front = +X)
	local LX = 75 - 11
	add("LocoBody", Vector3.new(22, 7, 7.4), CFrame.new(LX, 5.5, 0), color)
	add("LocoCab", Vector3.new(6, 3, 7.6), CFrame.new(LX + 6, 10.5, 0), color)
	add("LocoWindow", Vector3.new(0.2, 1.6, 6), CFrame.new(LX + 9.05, 10.6, 0), C(60, 90, 120), M.Glass)
	add("LocoNose", Vector3.new(1, 5, 7), CFrame.new(LX + 11.4, 4.8, 0), C(255, 210, 40))
	add("HeadLight", Vector3.new(0.3, 1, 1), CFrame.new(LX + 12, 6.4, 0), C(255, 246, 210), M.Neon)
	add("LocoStripe", Vector3.new(22.2, 0.8, 7.6), CFrame.new(LX, 4.2, 0), C(255, 210, 40))
	add("LocoFrame", Vector3.new(23, 1, 6.4), CFrame.new(LX, 1.6, 0), DARK, M.Metal)
	wheelRow(add, LX - 8, LX + 8, 4, 3.4, 1.4, 1.2, DARK)
	wheelRow(add, LX - 8, LX + 8, 4, -3.4, 1.4, 1.2, DARK)
	-- container wagons
	local wagonColors = { C(50, 110, 180), C(230, 180, 40), C(60, 140, 90), C(200, 70, 50), C(220, 220, 224) }
	local x = LX - 11 - 1.5
	local i = 0
	while x - 20 > -75 do
		i = i + 1
		local cx = x - 10
		add("WagonDeck", Vector3.new(20, 0.8, 6.6), CFrame.new(cx, 2.2, 0), DARK, M.Metal)
		add("Container", Vector3.new(19, 6.6, 7.2), CFrame.new(cx, 6, 0), wagonColors[(i - 1) % #wagonColors + 1], M.Metal)
		for k = -2, 2 do
			add("Rib", Vector3.new(0.3, 6.2, 7.4), CFrame.new(cx + k * 3.6, 6, 0), STEEL, M.Metal)
		end
		wheelRow(add, cx - 7, cx + 7, 14, 3.4, 1.2, 1, DARK)
		wheelRow(add, cx - 7, cx + 7, 14, -3.4, 1.2, 1, DARK)
		x = x - 21.5
	end
	m:SetAttribute("Height", 12)
	return m
end

function SV.Plane(color)
	local m, add = kit("Plane")
	color = color or C(240, 242, 246)
	local ACC, GREY, DARK = C(214, 52, 44), C(180, 184, 192), C(40, 42, 48)
	add("Fuselage", Vector3.new(36, 6.4, 6.4), CFrame.new(0, 7.2, 0) * CFrame.Angles(0, 0, 0), color, M.SmoothPlastic, CYL)
	add("Nose", Vector3.new(5, 5.4, 5.4), CFrame.new(19.5, 7, 0), color, M.SmoothPlastic, Enum.PartType.Ball)
	add("Cockpit", Vector3.new(1.6, 1.2, 4.4), CFrame.new(20, 8.4, 0), C(50, 70, 100), M.Glass)
	add("Tail", Vector3.new(5, 4.6, 4.6), CFrame.new(-19, 7.8, 0), color, M.SmoothPlastic, CYL)
	add("Fin", Vector3.new(6, 8, 0.6), CFrame.new(-20, 12.5, 0) * CFrame.Angles(0, 0, math.rad(-18)), ACC)
	add("Stabilizer", Vector3.new(4, 0.4, 14), CFrame.new(-20, 9, 0), color)
	add("Stripe", Vector3.new(30, 0.6, 6.5), CFrame.new(0, 7, 0), ACC)
	for _, s in ipairs({ -1, 1 }) do
		add("Wing", Vector3.new(9, 0.6, 18), CFrame.new(1, 5.6, s * 12) * CFrame.Angles(0, s * math.rad(18), 0), GREY, M.Metal)
		add("Engine", Vector3.new(6, 3, 3), CFrame.new(3, 3.9, s * 10), GREY, M.Metal, CYL)
		add("EngineIntake", Vector3.new(0.3, 2.6, 2.6), CFrame.new(6.1, 3.9, s * 10), DARK, M.Metal, CYL)
		add("Gear", Vector3.new(1, 2.4, 2.4), CFrame.new(-1, 1.2, s * 3), DARK, M.SmoothPlastic, CYL).CFrame = CFrame.new(-1, 1.2, s * 3) * CFrame.Angles(0, math.pi / 2, 0)
	end
	add("NoseGear", Vector3.new(1, 2, 2), CFrame.new(16, 1, 0) * CFrame.Angles(0, math.pi / 2, 0), DARK, M.SmoothPlastic, CYL)
	m:SetAttribute("Height", 14)
	return m
end

-- Boss monster trucks: huge wheels, lifted frame, roll cage. size = overall length.
SV.BossLooks = {
	crusher = { body = C(240, 120, 30), accent = C(30, 30, 34), L = 22 },
	juggernaut = { body = C(60, 130, 210), accent = C(255, 210, 40), L = 26 },
	titan = { body = C(200, 30, 40), accent = C(240, 190, 60), L = 30 },
}

-- Blender model (server only: ServerStorage.BuilderAssets.Props.MonsterTruck, loaded by ModelService), nose on +X.
-- Scaled to the look's length, "Body"/"Accent" pieces recoloured, every piece welded to an anchored ground Root.
local function fromBlender(lk)
	local ss = game:GetService("ServerStorage")
	local assets = ss:FindFirstChild("BuilderAssets")
	local props = assets and assets:FindFirstChild("Props")
	local tpl = props and props:FindFirstChild("MonsterTruck")
	if not tpl then
		return nil
	end
	local src = tpl:Clone()
	local _, size = src:GetBoundingBox()
	if size.X > 0.1 then
		src:ScaleTo(src:GetScale() * lk.L / size.X)
	end
	local bb
	bb, size = src:GetBoundingBox()
	-- move the model so its ground centre sits at the origin, where the Root is
	src:PivotTo(src:GetPivot() - Vector3.new(bb.Position.X, bb.Position.Y - size.Y / 2, bb.Position.Z))
	local m = kit("MonsterTruck")
	local root = m.PrimaryPart
	for _, d in ipairs(src:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Color = (d.Name == "Body" and lk.body) or (d.Name == "Accent" and lk.accent) or d.Color
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.Massless = false, false, false, false, true
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = root, d
			w.Parent = d
			d.Parent = m
		end
	end
	src:Destroy()
	m:SetAttribute("Height", size.Y)
	m:SetAttribute("HalfL", size.X / 2)
	m:SetAttribute("HalfW", size.Z / 2)
	return m
end

function SV.MonsterTruck(look)
	local lk = SV.BossLooks[look] or SV.BossLooks.crusher
	local ok, bm = pcall(fromBlender, lk)
	if ok and bm then
		return bm
	end
	local m, add = kit("MonsterTruck")
	local L = lk.L
	local s = L / 22
	local TIRE, RIM, CAGE = C(24, 24, 28), C(200, 204, 210), C(40, 42, 48)
	local r = 4.2 * s
	for _, x in ipairs({ -L * 0.32, L * 0.32 }) do
		for _, z in ipairs({ -1, 1 }) do
			add("Tire", Vector3.new(3.4 * s, r * 2, r * 2), CFrame.new(x, r, z * 5.4 * s) * CFrame.Angles(0, math.pi / 2, 0), TIRE, M.SmoothPlastic, CYL)
			add("Rim", Vector3.new(3.5 * s, r * 0.9, r * 0.9), CFrame.new(x, r, z * 5.4 * s) * CFrame.Angles(0, math.pi / 2, 0), RIM, M.Metal, CYL)
			for k = 0, 5 do
				add("Tread", Vector3.new(0.5 * s, 0.6 * s, 3.5 * s), CFrame.new(x, r, z * 5.4 * s) * CFrame.Angles(k * math.pi / 6, 0, 0) * CFrame.new(0, r, 0), TIRE)
			end
		end
	end
	add("Frame", Vector3.new(L * 0.8, 1.2 * s, 4 * s), CFrame.new(0, r + 0.6 * s, 0), CAGE, M.Metal)
	for _, x in ipairs({ -L * 0.32, L * 0.32 }) do
		add("Axle", Vector3.new(1, 1, 11 * s), CFrame.new(x, r, 0), CAGE, M.Metal)
		for _, z in ipairs({ -1, 1 }) do
			add("Shock", Vector3.new(0.6 * s, 3.2 * s, 0.6 * s), CFrame.new(x, r + 1.6 * s, z * 2.6 * s) * CFrame.Angles(math.rad(z * 20), 0, 0), C(255, 210, 40), M.Metal)
		end
	end
	local by = r + 3.2 * s
	add("Body", Vector3.new(L * 0.86, 2.8 * s, 9 * s), CFrame.new(0, by, 0), lk.body)
	add("Hood", Vector3.new(L * 0.3, 1 * s, 8.4 * s), CFrame.new(L * 0.26, by + 1.8 * s, 0), lk.body)
	add("Cab", Vector3.new(L * 0.3, 3.2 * s, 7.6 * s), CFrame.new(-L * 0.04, by + 2.9 * s, 0), lk.body)
	add("Windshield", Vector3.new(0.3, 2.4 * s, 6.8 * s), CFrame.new(L * 0.11 + 0.1, by + 3 * s, 0), C(50, 70, 100), M.Glass)
	add("Stripe", Vector3.new(L * 0.87, 0.6 * s, 9.1 * s), CFrame.new(0, by - 0.4 * s, 0), lk.accent)
	add("Bumper", Vector3.new(1.2 * s, 1.6 * s, 9.6 * s), CFrame.new(L * 0.44, by - 1 * s, 0), CAGE, M.Metal)
	for _, z in ipairs({ -1, 1 }) do
		add("Cage", Vector3.new(L * 0.36, 0.4 * s, 0.4 * s), CFrame.new(-L * 0.04, by + 4.7 * s, z * 3.6 * s), CAGE, M.Metal)
		add("Exhaust", Vector3.new(0.8 * s, 4 * s, 0.8 * s), CFrame.new(-L * 0.18, by + 4 * s, z * 4.2 * s), RIM, M.Metal)
		add("HeadLight", Vector3.new(0.3, 0.9 * s, 1.6 * s), CFrame.new(L * 0.43 + 0.2, by + 0.4 * s, z * 3 * s), C(255, 246, 210), M.Neon)
	end
	add("LightBar", Vector3.new(0.8 * s, 0.6 * s, 6 * s), CFrame.new(L * 0.08, by + 4.8 * s, 0), C(255, 196, 40), M.Neon)
	m:SetAttribute("Height", by + 5 * s)
	m:SetAttribute("HalfL", L / 2)
	m:SetAttribute("HalfW", 6.8 * s)
	return m
end

function SV.Build(kindName, color)
	if kindName == "train" then
		return SV.Train(color)
	elseif kindName == "plane" then
		return SV.Plane(color)
	end
	return nil
end

return SV
