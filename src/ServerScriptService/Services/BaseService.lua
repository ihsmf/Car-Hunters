local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("MapConfig"))
local CarConfig = require(Shared:WaitForChild("CarConfig"))
local Strings = require(Shared:WaitForChild("Strings"))
local BaseLayout = require(Shared:WaitForChild("BaseLayout"))
local VehicleFactory = require(Shared:WaitForChild("VehicleFactory"))
local ExhaustFx = require(Shared:WaitForChild("ExhaustFx"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local Util = require(Shared:WaitForChild("Util"))
local GarageKit = require(Shared:WaitForChild("GarageKit"))
local GearConfig = require(Shared:WaitForChild("GearConfig"))
local SkinConfig = require(Shared:WaitForChild("SkinConfig"))
local TrapConfig = require(Shared:WaitForChild("TrapConfig"))
local PartVisual = require(Shared:WaitForChild("PartVisual"))

local Base = {}
local S
local bases = {}

local PAD_LOCKED = Color3.fromRGB(46, 48, 54)
local PAD_FREE = Color3.fromRGB(86, 90, 98)

function Base.Init(hub)
	S = hub
end

function Base.Start()
	local map = Workspace:WaitForChild("GeneratedMap", 30)
	assert(map, "GeneratedMap not found - run BuildCityMap")
	local basesFolder = map:WaitForChild("Bases")
	for i = 1, MapConfig.BaseCount do
		local m = basesFolder:FindFirstChild(string.format("Base%02d", i), true)
		assert(m, "Base model missing: Base" .. i)
		local b = { index = i, model = m, owner = nil, sig = {}, carModels = {}, pads = {} }
		local slots = m:WaitForChild("Slots")
		for n = 1, BaseLayout.SlotsPerFloor do
			b.pads[n] = slots:WaitForChild("Slot" .. n)
		end
		b.floorModels = {}
		b.floorsFolder = m:FindFirstChild("Floors") or Instance.new("Folder", m)
		b.floorsFolder.Name = "Floors"
		b.spawn = m:WaitForChild("Spawn")
		b.sign = m:WaitForChild("OwnerSign"):FindFirstChildWhichIsA("SurfaceGui", true)
		b.screen = m:WaitForChild("IncomeScreen"):FindFirstChildWhichIsA("SurfaceGui", true)
		b.cars = m:FindFirstChild("Cars")
		if not b.cars then
			b.cars = Instance.new("Folder")
			b.cars.Name = "Cars"
			b.cars.Parent = m
		end
		bases[i] = b
		Base.SetFree(b)
	end
end

local function setPad(pad, state, rarityColor)
	if not pad then
		return
	end
	pad.Material = Enum.Material.SmoothPlastic
	pad.Transparency = 0
	if state == "locked" then
		pad.Color = PAD_LOCKED
	elseif state == "free" then
		pad.Color = PAD_FREE
	else
		pad.Color = rarityColor:Lerp(Color3.fromRGB(70, 74, 82), 0.55) -- tinted bay, the car itself carries the colour
	end
end

local function setLabel(gui, text)
	if gui then
		local label = gui:FindFirstChild("Label")
		if label then
			label.Text = text
		end
	end
end

-- builds/removes floors 2..n for the owner
local function ensureFloors(b, floors, style)
	for f = 2, BaseLayout.MaxFloors do
		if f <= floors and not b.floorModels[f] then
			local m, pads = GarageKit.BuildFloor(b.floorsFolder, BaseLayout.GetBaseCFrame(b.index), f, style)
			b.floorModels[f] = m
			for slot, pad in pairs(pads) do
				b.pads[slot] = pad
			end
		elseif f > floors and b.floorModels[f] then
			b.floorModels[f]:Destroy()
			b.floorModels[f] = nil
			for slot = (f - 1) * BaseLayout.SlotsPerFloor + 1, f * BaseLayout.SlotsPerFloor do
				b.pads[slot] = nil
			end
		end
	end
end
Base.EnsureFloors = ensureFloors

---------------------------------------------------------------- throw platform looks (v25, TrapService levels)
-- Everything lives in a "TrapUpgrades" folder of the base model, positioned from BaseLayout.TrapLocal. Solid shop
-- hardware only (no glowing neon material anywhere): levels add up:
--   2 painted steel trims + kick plates      3 diamond-plate deck with a bolted edge frame
--   4 steel corner pylons with chrome caps   5 geared turntable ring (client spin) + pinion drive
--   6 hydraulic rams + hoses, metal sparks   7 crane gantry truss + trolley + amber warning beacons
--   8 tread-plate platter + chrome rim       9 glass-and-steel canopy
--   10 gold-plated deck, crown on the magnet, trophy plaque
-- Fixed colours (the garage skin never touches "TrapUp*" names). All pieces anchored, no collide / query / touch /
-- shadow; overlays sit >= 0.08 proud of what they cover, and every piece rests on or is bolted to something.
-- Reference (local to O, y 0 = slab middle): slab top 0.5; plinth +-10.5, y 0.5..1.0; deck +-9, y 0.8..1.6;
-- posts (+-9.6, +-9.6) 1.2 wide up to 13.5; side beams x +-9.6, y 13.5..14.5; crane beam y 13.6..14.8 (x +-10.2);
-- magnet y 9.2..10.4 (r 3); "THROW PARTS HERE" sign x 10..10.4, y 12..14.4, z +-6. +X is the walk-up side.
local TRAP_ORANGE = Color3.fromRGB(255, 138, 31)
local TRAP_WHITE = Color3.fromRGB(236, 236, 230)
local TRAP_YELLOW = Color3.fromRGB(246, 196, 38)
local TRAP_GOLD = Color3.fromRGB(255, 196, 54)
local TRAP_DARK = Color3.fromRGB(32, 34, 42)
local TRAP_STEEL = Color3.fromRGB(122, 128, 138)
local TRAP_STEEL_LIGHT = Color3.fromRGB(176, 182, 190)
local TRAP_CHROME = Color3.fromRGB(222, 226, 232)
local TRAP_HOSE = Color3.fromRGB(22, 22, 24)
local TRAP_AMBER = Color3.fromRGB(255, 160, 30)
local TRAP_GLASS = Color3.fromRGB(176, 214, 232)
local TRAP_WOOD = Color3.fromRGB(92, 56, 32)
local TRAP_PAD_GOLD = Color3.fromRGB(226, 178, 64)
local TRAP_BASE_GOLD = Color3.fromRGB(122, 86, 26)

local function trapPart(parent, name, size, cf, color, mat, o)
	o = o or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Transparency = o.t or 0
	p.Reflectance = o.refl or 0
	if o.shape then
		p.Shape = o.shape
	end
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- a square-section member from p0 to p1 (never exactly vertical: CFrame.lookAt needs a tilt)
local function trapStrut(parent, name, p0, p1, w, color, mat, o)
	local len = (p1 - p0).Magnitude
	return trapPart(parent, name, Vector3.new(w, w, len), CFrame.lookAt((p0 + p1) / 2, p1), color, mat, o)
end

-- a round member (hose, rod) from p0 to p1 (cylinder axis = local X)
local function trapPipe(parent, name, p0, p1, d, color, mat, o)
	o = o or {}
	o.shape = Enum.PartType.Cylinder
	local len = (p1 - p0).Magnitude
	return trapPart(parent, name, Vector3.new(len, d, d), CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.Angles(0, math.pi / 2, 0), color, mat, o)
end

local function trapSpin(m, cf, speed)
	m.WorldPivot = cf
	m:SetAttribute("SpinCF", cf)
	m:SetAttribute("SpinSpeed", speed)
	CollectionService:AddTag(m, "TrapSpin")
end

-- short orange grinding sparks (metal on metal), falling fast
local function trapSparks(parent, rate)
	local e = Instance.new("ParticleEmitter")
	e.Name = "TrapUpSparks"
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 236, 170)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 150, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 60, 20)),
	})
	e.LightEmission = 0.8
	e.LightInfluence = 0.2
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.02) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.5) })
	e.Lifetime = NumberRange.new(0.2, 0.45)
	e.Speed = NumberRange.new(6, 12)
	e.SpreadAngle = Vector2.new(55, 55)
	e.Acceleration = Vector3.new(0, -45, 0)
	e.Drag = 2
	e.Rate = rate
	e:SetAttribute("BaseRate", rate) -- the client scales it with Perf (LOW = fewer)
	CollectionService:AddTag(e, "TrapSpark")
	e.Parent = parent
	return e
end

local function trapLight(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = color, range, brightness, false
	l.Parent = parent
	return l
end

local function applyTrapLevel(b, level)
	local old = b.model:FindFirstChild("TrapUpgrades")
	if old then
		old:Destroy()
	end
	local pad, plinth = b.model:FindFirstChild("TrapPad"), b.model:FindFirstChild("TrapBase")
	if not b.trapOrig then
		b.trapOrig = {
			pad = pad and { pad.Color, pad.Material } or nil,
			base = plinth and { plinth.Color, plinth.Material } or nil,
		}
	end
	local gold = level and level >= TrapConfig.MaxLevel
	for key, part in pairs({ pad = pad, base = plinth }) do
		local orig = b.trapOrig[key]
		if part and orig then
			if gold then
				part.Color = key == "pad" and TRAP_PAD_GOLD or TRAP_BASE_GOLD
				part.Material = key == "pad" and Enum.Material.DiamondPlate or Enum.Material.Metal
			else
				part.Color, part.Material = orig[1], orig[2]
			end
		end
	end
	b.trapLevel = level
	if not level then
		return
	end
	local f = Instance.new("Folder")
	f.Name = "TrapUpgrades"
	local t = BaseLayout.TrapLocal
	local O = BaseLayout.GetBaseCFrame(b.index) * CFrame.new(t.X, 0, t.Z) -- y 0 = slab middle; slab top 0.5, pad top 1.6
	local function P(x, y, z)
		return O:PointToWorldSpace(Vector3.new(x, y, z))
	end
	local METAL, PAINT, DIAMOND, GLASS = Enum.Material.Metal, Enum.Material.SmoothPlastic, Enum.Material.DiamondPlate, Enum.Material.Glass
	local CYL = Enum.PartType.Cylinder
	local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- cylinders: axis along local Y
	local corners = { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }
	local deckColor, deckMat, deckRefl = TRAP_STEEL_LIGHT, DIAMOND, 0
	if gold then
		deckColor, deckMat, deckRefl = TRAP_GOLD, METAL, 0.3
	end
	local function bolt(x, y, z)
		trapPart(f, "TrapUpBolt", Vector3.new(0.14, 0.3, 0.3), O * CFrame.new(x, y, z) * UPRIGHT, TRAP_DARK, METAL, { shape = CYL })
	end

	-- level sign under "THROW PARTS HERE", hung from it on two rods
	local sign = trapPart(f, "TrapUpSign", Vector3.new(0.4, 1.5, 7.4), O * CFrame.new(10.2, 11.1, 0), TRAP_DARK, PAINT)
	for _, z in ipairs({ -3, 3 }) do
		trapPart(f, "TrapUpHanger", Vector3.new(0.12, 0.36, 0.12), O * CFrame.new(10.2, 11.94, z), TRAP_STEEL, METAL)
	end
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Gui"
	sg.Face = Enum.NormalId.Right
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.Parent = sign
	local lbl = Instance.new("TextLabel")
	lbl.Name = "Label"
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.Font = Enum.Font.LuckiestGuy
	lbl.TextScaled = true
	lbl.RichText = true
	lbl.TextColor3 = gold and TRAP_GOLD or Color3.new(1, 1, 1)
	lbl.Text = string.format('PLATFORM Lv %d  <font color="#46E1FF">LUCK x%.2f</font>', level, TrapConfig.LuckMult(level))
	lbl.Parent = sg

	if level >= 2 then -- painted steel: an orange band round the plinth, kick plates below it, bands on posts + crane beam
		for _, s in ipairs({ -1, 1 }) do
			trapPart(f, "TrapUpTrim", Vector3.new(21.24, 0.14, 0.6), O * CFrame.new(0, 0.9, s * 10.32), TRAP_ORANGE, PAINT)
			trapPart(f, "TrapUpTrim", Vector3.new(0.6, 0.14, 20.04), O * CFrame.new(s * 10.32, 0.9, 0), TRAP_ORANGE, PAINT)
			for _, u in ipairs({ -4.6, 4.6 }) do
				trapPart(f, "TrapUpKick", Vector3.new(0.2, 0.26, 7), O * CFrame.new(s * 10.54, 0.66, u), TRAP_STEEL_LIGHT, METAL)
				trapPart(f, "TrapUpKick", Vector3.new(7, 0.26, 0.2), O * CFrame.new(u, 0.66, s * 10.54), TRAP_STEEL_LIGHT, METAL)
			end
		end
		for _, c in ipairs(corners) do
			for i, y in ipairs({ 3.2, 5.2, 10.6 }) do
				trapPart(f, "TrapUpTrim", Vector3.new(1.36, 0.55, 1.36), O * CFrame.new(c[1] * 9.6, y, c[2] * 9.6), i == 2 and TRAP_WHITE or TRAP_ORANGE, PAINT)
			end
		end
		for _, x in ipairs({ -6, 6 }) do
			trapPart(f, "TrapUpTrim", Vector3.new(0.7, 1.36, 1.36), O * CFrame.new(x, 14.2, 0), TRAP_ORANGE, PAINT)
		end
	end
	if level >= 3 then -- diamond-plate deck (0.1 proud of the pad) inside an angle-iron frame with bolt heads
		trapPart(f, "TrapUpDeck", Vector3.new(17.4, 0.2, 17.4), O * CFrame.new(0, 1.6, 0), deckColor, deckMat, { refl = deckRefl })
		local frameColor = gold and TRAP_GOLD or TRAP_STEEL
		for _, s in ipairs({ -1, 1 }) do
			trapPart(f, "TrapUpFrame", Vector3.new(17.86, 0.32, 0.48), O * CFrame.new(0, 1.66, s * 8.69), frameColor, METAL, { refl = deckRefl })
			trapPart(f, "TrapUpFrame", Vector3.new(0.48, 0.32, 16.9), O * CFrame.new(s * 8.69, 1.66, 0), frameColor, METAL, { refl = deckRefl })
			for i = -3, 3 do
				bolt(i * 2.5, 1.86, s * 8.69)
				bolt(s * 8.69, 1.86, i * 2.5)
			end
		end
	end
	if level >= 4 then -- corner pylons just outside the plinth (diagonals: the walk-in sides stay open)
		for _, c in ipairs(corners) do
			local x, z = c[1] * 12.2, c[2] * 12.2
			trapPart(f, "TrapUpPylon", Vector3.new(2, 0.35, 2), O * CFrame.new(x, 0.625, z), TRAP_DARK, METAL)
			for _, d in ipairs(corners) do
				trapPart(f, "TrapUpPylonBolt", Vector3.new(0.14, 0.26, 0.26), O * CFrame.new(x + d[1] * 0.72, 0.84, z + d[2] * 0.72) * UPRIGHT, TRAP_STEEL_LIGHT, METAL, { shape = CYL })
			end
			trapPart(f, "TrapUpPylon", Vector3.new(5.5, 0.9, 0.9), O * CFrame.new(x, 3.5, z) * UPRIGHT, TRAP_WHITE, METAL, { shape = CYL })
			trapPart(f, "TrapUpPylon", Vector3.new(0.5, 1.2, 1.2), O * CFrame.new(x, 2.2, z) * UPRIGHT, TRAP_ORANGE, PAINT, { shape = CYL })
			trapPart(f, "TrapUpPylon", Vector3.new(0.3, 1.3, 1.3), O * CFrame.new(x, 6.36, z) * UPRIGHT, TRAP_DARK, METAL, { shape = CYL })
			trapPart(f, "TrapUpCap", Vector3.new(1.2, 1.2, 1.2), O * CFrame.new(x, 6.9, z), gold and TRAP_GOLD or TRAP_CHROME, METAL, { shape = Enum.PartType.Ball, refl = 0.3 })
		end
	end
	local pinion
	if level >= 5 then -- a geared turntable ring lying on the deck (spun by the client), driven by a pinion motor
		local cf = O * CFrame.new(0, 1.7, 0)
		local ring = Instance.new("Model")
		ring.Name = "TrapUpRing"
		local n, R, w = 32, 7.4, 0.7
		local len = 2 * (R + w / 2) * math.tan(math.pi / n)
		for i = 0, n - 1 do
			local h = (i % 2 == 0) and 0.3 or 0.34 -- alternate plate heights: no shared top faces
			local a = i / n * math.pi * 2
			trapPart(ring, "TrapUpRingSeg", Vector3.new(w, h, len), cf * CFrame.Angles(0, a, 0) * CFrame.new(R, -0.08 + h / 2, 0), TRAP_DARK, METAL, { refl = 0.05 })
			local ta = (i + 0.5) / n * math.pi * 2
			trapPart(ring, "TrapUpRingTooth", Vector3.new(0.36, 0.24, 0.4), cf * CFrame.Angles(0, ta, 0) * CFrame.new(R + w / 2 + 0.12, 0.04, 0), TRAP_STEEL, METAL)
		end
		ring.Parent = f
		trapSpin(ring, cf, 0.35)
		-- pinion + motor on the +X+Z deck corner, on a bracket bolted across the edge frame
		local diag = CFrame.Angles(0, math.pi / 4, 0)
		local pc = O * diag * CFrame.new(0, 0, 8.6) -- pinion axis (the ring's teeth end at r 8.05)
		pinion = trapPart(f, "TrapUpPinion", Vector3.new(0.32, 1.2, 1.2), pc * CFrame.new(0, 1.84, 0) * UPRIGHT, TRAP_STEEL, METAL, { shape = CYL })
		for i = 0, 5 do
			trapPart(f, "TrapUpPinionTooth", Vector3.new(0.26, 0.26, 0.24), pc * CFrame.Angles(0, i / 6 * math.pi * 2, 0) * CFrame.new(0.64, 1.84, 0), TRAP_STEEL, METAL)
		end
		trapPart(f, "TrapUpMotor", Vector3.new(1.1, 1, 1), pc * CFrame.new(0, 2.5, 0) * UPRIGHT, TRAP_YELLOW, METAL, { shape = CYL })
		trapPart(f, "TrapUpMotor", Vector3.new(0.2, 1.1, 1.1), pc * CFrame.new(0, 3.08, 0) * UPRIGHT, TRAP_DARK, METAL, { shape = CYL })
		trapPart(f, "TrapUpBracket", Vector3.new(0.8, 0.3, 4), O * diag * CFrame.new(0, 1.95, 10.4), TRAP_DARK, METAL)
	end
	if level >= 6 then -- hydraulic rams on the two closed sides, bolted to the posts, with hoses down to the plinth
		for _, sz in ipairs({ -1, 1 }) do
			for _, sx in ipairs({ -1, 1 }) do
				local x, z = sx * 6, sz * 9.75
				trapPart(f, "TrapUpRam", Vector3.new(1.1, 0.2, 1.1), O * CFrame.new(x, 1.08, z), TRAP_DARK, METAL)
				trapPart(f, "TrapUpRam", Vector3.new(3, 0.84, 0.84), O * CFrame.new(x, 2.6, z) * UPRIGHT, TRAP_YELLOW, METAL, { shape = CYL })
				trapPart(f, "TrapUpRam", Vector3.new(0.25, 0.96, 0.96), O * CFrame.new(x, 4.15, z) * UPRIGHT, TRAP_DARK, METAL, { shape = CYL })
				trapPart(f, "TrapUpRamRod", Vector3.new(2.5, 0.4, 0.4), O * CFrame.new(x, 5.4, z) * UPRIGHT, TRAP_CHROME, METAL, { shape = CYL, refl = 0.35 })
				trapPart(f, "TrapUpRam", Vector3.new(0.6, 0.6, 0.6), O * CFrame.new(x, 6.75, z), TRAP_DARK, METAL)
				trapPart(f, "TrapUpRam", Vector3.new(3.2, 0.4, 0.4), O * CFrame.new(sx * 7.5, 6.75, z), TRAP_STEEL, METAL) -- clevis arm into the post
				-- two hoses from fittings on the barrel to the plinth top
				local out = sz * 0.36
				trapPipe(f, "TrapUpHose", P(x - sx * 0.25, 3.7, z + out), P(x - sx * 1.3, 1.02, sz * 10.25), 0.2, TRAP_HOSE, PAINT)
				trapPipe(f, "TrapUpHose", P(x + sx * 0.25, 1.9, z + out), P(x + sx * 1.3, 1.02, sz * 10.25), 0.2, TRAP_HOSE, PAINT)
				for _, y in ipairs({ 3.7, 1.9 }) do
					trapPart(f, "TrapUpFitting", Vector3.new(0.3, 0.26, 0.26), O * CFrame.new(x + (y > 3 and -sx or sx) * 0.25, y, z + out) * CFrame.Angles(0, math.pi / 2, 0), TRAP_STEEL_LIGHT, METAL, { shape = CYL })
				end
			end
		end
		if pinion then -- grinding sparks where the pinion bites the ring
			local att = Instance.new("Attachment")
			att.Name = "TrapUpSparkAt"
			att.CFrame = pinion.CFrame:ToObjectSpace(O * CFrame.Angles(0, math.pi / 4, 0) * CFrame.new(0, 1.95, 7.95)) -- the bite, sparks fly up
			att.Parent = pinion
			trapSparks(att, 22)
		end
	end
	if level >= 7 then -- crane gantry: a truss over the crane beam, a trolley on it, amber beacons on the top chord
		trapPart(f, "TrapUpGantry", Vector3.new(20.4, 0.6, 0.6), O * CFrame.new(0, 16.6, 0), TRAP_STEEL, METAL)
		for _, sx in ipairs({ -1, 1 }) do
			for _, x in ipairs({ 9.6, 5 }) do
				trapPart(f, "TrapUpGantry", Vector3.new(0.4, 1.7, 0.4), O * CFrame.new(sx * x, 15.55, 0), TRAP_STEEL, METAL)
			end
			trapStrut(f, "TrapUpGantry", P(sx * 9.4, 14.7, 0), P(sx * 5.2, 16.4, 0), 0.3, TRAP_STEEL, METAL)
			trapStrut(f, "TrapUpGantry", P(sx * 4.8, 14.7, 0), P(sx * 1.6, 16.4, 0), 0.3, TRAP_STEEL, METAL)
			-- beacon: dark housing + amber glass lens with a light inside
			trapPart(f, "TrapUpBeacon", Vector3.new(0.36, 0.8, 0.8), O * CFrame.new(sx * 9.6, 17.0, 0) * UPRIGHT, TRAP_DARK, METAL, { shape = CYL })
			local lens = trapPart(f, "TrapUpBeaconLens", Vector3.new(0.66, 0.66, 0.66), O * CFrame.new(sx * 9.6, 17.36, 0), TRAP_AMBER, GLASS, { shape = Enum.PartType.Ball, t = 0.25, refl = 0.1 })
			trapLight(lens, TRAP_AMBER, 12, 1.2)
		end
		trapPart(f, "TrapUpTrolley", Vector3.new(2.2, 1.6, 2), O * CFrame.new(0, 14.2, 0), TRAP_YELLOW, METAL)
		trapPart(f, "TrapUpTrolley", Vector3.new(1.4, 0.3, 1.4), O * CFrame.new(0, 15.1, 0), TRAP_DARK, METAL)
	end
	if level >= 8 then -- tread-plate platter inside the ring (chrome hub, raised lozenges) + a chrome rim on the plinth
		local platColor = gold and TRAP_GOLD or TRAP_STEEL_LIGHT
		trapPart(f, "TrapUpPlatter", Vector3.new(0.14, 13.8, 13.8), O * CFrame.new(0, 1.73, 0) * UPRIGHT, platColor, METAL, { shape = CYL, refl = gold and 0.3 or 0.08 })
		trapPart(f, "TrapUpHub", Vector3.new(0.2, 2.8, 2.8), O * CFrame.new(0, 1.9, 0) * UPRIGHT, TRAP_CHROME, METAL, { shape = CYL, refl = 0.35 })
		for i = -3, 3 do
			for j = -3, 3 do
				local x, z = i * 1.7, j * 1.7
				local r = math.sqrt(x * x + z * z)
				if r > 2.2 and r < 5.9 then
					local a = ((i + j) % 2 == 0) and math.pi / 4 or -math.pi / 4
					trapPart(f, "TrapUpTread", Vector3.new(1, 0.12, 0.24), O * CFrame.new(x, 1.84, z) * CFrame.Angles(0, a, 0), platColor, METAL, { refl = gold and 0.3 or 0.08 })
				end
			end
		end
		for _, s in ipairs({ -1, 1 }) do
			trapPart(f, "TrapUpRim", Vector3.new(21.44, 0.2, 0.44), O * CFrame.new(0, 1.02, s * 10.5), TRAP_CHROME, METAL, { refl = 0.35 })
			trapPart(f, "TrapUpRim", Vector3.new(0.44, 0.2, 20.56), O * CFrame.new(s * 10.5, 1.02, 0), TRAP_CHROME, METAL, { refl = 0.35 })
		end
	end
	if level >= 9 then -- glass-and-steel canopy: columns up from the post tops, eaves, rafters, two glass panes, ridge
		for _, c in ipairs(corners) do
			trapPart(f, "TrapUpCanopy", Vector3.new(0.9, 4.35, 0.9), O * CFrame.new(c[1] * 9.6, 16.575, c[2] * 9.6), TRAP_STEEL, METAL)
		end
		for _, s in ipairs({ -1, 1 }) do
			trapPart(f, "TrapUpCanopy", Vector3.new(20.4, 0.5, 0.6), O * CFrame.new(0, 18.95, s * 9.6), TRAP_STEEL, METAL)
			trapPart(f, "TrapUpCanopy", Vector3.new(0.5, 0.4, 19.2), O * CFrame.new(s * 9.6, 18.8, 0), TRAP_STEEL, METAL)
			for _, x in ipairs({ -9.6, -4.8, 0, 4.8, 9.6 }) do
				trapStrut(f, "TrapUpRafter", P(x, 19.2, s * 9.6), P(x, 20.38, s * 0.15), 0.35, TRAP_STEEL, METAL)
			end
			local p0, p1 = P(0, 19.2, s * 9.6), P(0, 20.4, 0)
			local cf = CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.new(0, 0.235, 0)
			trapPart(f, "TrapUpGlass", Vector3.new(s > 0 and 19.9 or 19.7, 0.12, (p1 - p0).Magnitude + 0.2), cf, TRAP_GLASS, GLASS, { t = 0.55, refl = 0.15 })
		end
		trapPart(f, "TrapUpCanopy", Vector3.new(20.2, 0.45, 0.45), O * CFrame.new(0, 20.4, 0), TRAP_STEEL, METAL)
		trapPart(f, "TrapUpCanopy", Vector3.new(20.4, 0.3, 1), O * CFrame.new(0, 20.72, 0), TRAP_CHROME, METAL, { refl = 0.3 })
	end
	if gold then -- crown on the magnet, a trophy plaque under the level sign (pad, plinth and deck turned gold above)
		local top = O * CFrame.new(0, 10.4, 0) -- magnet: height 1.2 at y 9.8
		local crown = trapPart(f, "TrapUpCrown", Vector3.new(0.8, 4, 4), top * CFrame.new(0, 0.38, 0) * UPRIGHT, TRAP_GOLD, METAL, { shape = CYL, refl = 0.3 })
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			local spike = top * CFrame.Angles(0, a, 0) * CFrame.new(1.7, 1.35, 0)
			trapPart(f, "TrapUpCrown", Vector3.new(0.45, 1.2, 0.45), spike * CFrame.Angles(0, math.pi / 4, 0), TRAP_GOLD, METAL, { refl = 0.3 })
			local gem = i % 2 == 0 and Color3.fromRGB(220, 40, 60) or Color3.fromRGB(40, 140, 230)
			trapPart(f, "TrapUpCrownGem", Vector3.new(0.5, 0.5, 0.5), spike * CFrame.new(0, 0.75, 0), gem, GLASS, { shape = Enum.PartType.Ball, t = 0.1, refl = 0.25 })
		end
		trapLight(crown, TRAP_GOLD, 16, 1.2)
		-- the throw cinematic (TrapFx) lowers the anchored magnet: the crown is welded on so it rides along
		local magnet = b.model:FindFirstChild("TrapMagnet")
		if magnet and magnet:IsA("BasePart") then
			for _, p in ipairs(f:GetChildren()) do
				if p:IsA("BasePart") and (p.Name == "TrapUpCrown" or p.Name == "TrapUpCrownGem") then
					local w = Instance.new("WeldConstraint")
					w.Part0, w.Part1 = magnet, p
					w.Parent = p
					p.Massless = true
					p.Anchored = false
				end
			end
		end
		-- trophy plaque: gold frame, walnut panel with the text, a gold cup on its left; hung from the level sign
		for _, z in ipairs({ -2, 2 }) do
			trapPart(f, "TrapUpHanger", Vector3.new(0.12, 0.3, 0.12), O * CFrame.new(10.15, 10.27, z), TRAP_STEEL, METAL)
		end
		trapPart(f, "TrapUpPlaque", Vector3.new(0.3, 1.4, 5), O * CFrame.new(10.15, 9.5, 0), TRAP_GOLD, METAL, { refl = 0.3 })
		local panel = trapPart(f, "TrapUpPlaque", Vector3.new(0.3, 1.1, 4.6), O * CFrame.new(10.25, 9.5, 0), TRAP_WOOD, Enum.Material.Wood)
		trapPart(f, "TrapUpTrophy", Vector3.new(0.3, 0.2, 0.6), O * CFrame.new(10.5, 9.12, -1.7), TRAP_GOLD, METAL, { refl = 0.3 })
		trapPart(f, "TrapUpTrophy", Vector3.new(0.4, 0.14, 0.14), O * CFrame.new(10.5, 9.38, -1.7) * UPRIGHT, TRAP_GOLD, METAL, { shape = CYL, refl = 0.3 })
		trapPart(f, "TrapUpTrophy", Vector3.new(0.5, 0.5, 0.5), O * CFrame.new(10.5, 9.74, -1.7), TRAP_GOLD, METAL, { shape = Enum.PartType.Ball, refl = 0.3 })
		trapPart(f, "TrapUpTrophy", Vector3.new(0.12, 0.6, 0.6), O * CFrame.new(10.5, 9.9, -1.7) * UPRIGHT, TRAP_GOLD, METAL, { shape = CYL, refl = 0.3 })
		local pg = Instance.new("SurfaceGui")
		pg.Name = "Gui"
		pg.Face = Enum.NormalId.Right
		pg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		pg.PixelsPerStud = 40
		pg.Parent = panel
		local pl = Instance.new("TextLabel")
		pl.BackgroundTransparency = 1
		pl.Position = UDim2.fromScale(0.04, 0.1) -- the cup is on the viewer's right (-Z)
		pl.Size = UDim2.fromScale(0.66, 0.8)
		pl.Font = Enum.Font.LuckiestGuy
		pl.TextScaled = true
		pl.TextColor3 = TRAP_GOLD
		pl.Text = "MAX PLATFORM"
		pl.Parent = pg
	end
	f.Parent = b.model
end

function Base.SetFree(b)
	b.owner = nil
	for slot, model in pairs(b.carModels) do
		model:Destroy()
	end
	b.carModels = {}
	b.sig = {}
	ensureFloors(b, 1)
	if b.skin and b.skin ~= "classic" then
		GarageKit.ApplyStyle(b.model, GarageKit.Style)
	end
	b.skin = "classic"
	b.skinFloors = nil -- the next owner's floors are painted again
	applyTrapLevel(b, nil) -- plain steel lift again
	for _, pad in pairs(b.pads) do
		setPad(pad, "locked")
	end
	setLabel(b.sign, Strings.Tables.en.free_garage)
	setLabel(b.screen, "")
end

function Base.Assign(player)
	local s = S.Data.Get(player)
	if not s then
		return nil
	end
	for i = 1, MapConfig.BaseCount do
		local b = bases[i]
		if not b.owner then
			b.owner = player
			s.baseIndex = i
			player:SetAttribute("BaseIndex", i)
			player.RespawnLocation = b.spawn
			setLabel(b.sign, string.format(Strings.Tables.en.garage_of, player.DisplayName))
			return i
		end
	end
	return nil
end

function Base.Release(player)
	local s = S.Data.Get(player)
	if s and s.baseIndex then
		local b = bases[s.baseIndex]
		if b and b.owner == player then
			Base.SetFree(b)
		end
		s.baseIndex = nil
	end
end

function Base.GetBase(index)
	return bases[index]
end

function Base.IsNearOwnBase(player)
	local s = S.Data.Get(player)
	if not s or not s.baseIndex then
		return false
	end
	local hrp = S.Data.GetRoot(player)
	if not hrp then
		return false
	end
	local center = BaseLayout.GetBaseCFrame(s.baseIndex).Position
	return (hrp.Position - center).Magnitude <= EconomyConfig.BaseActionDistance
end

local function buildCarModel(def, level, slotCF, car)
	local model = VehicleFactory.BuildCar(def)
	model:PivotTo(slotCF)
	ExhaustFx.Attach(model, def, CarConfig.Rarities[def.rarity].index)
	-- an active gear: the client's GearFx builds the aura + countdown billboard from these attributes
	local gearDef = car and GearConfig.Active(car.gear)
	if gearDef then
		model:SetAttribute("GearId", gearDef.id)
		model:SetAttribute("GearExp", car.gear.exp)
		model:SetAttribute("GearSlot", car.parkedSlot)
	end
	local rarity = CarConfig.Rarities[def.rarity]
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromOffset(150, 40)
	gui.StudsOffset = Vector3.new(0, VehicleFactory.HeightOfModel(model, def.style) + 2, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 70
	gui.Adornee = model.PrimaryPart
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextSize = 14
	label.TextColor3 = rarity.color
	label.TextStrokeTransparency = 0.3
	label.Text = string.format("%s  Lv%d\n+%s/s", def.name, level, Util.FormatNumber(car and CarConfig.CarIncome(car) or CarConfig.IncomeAt(def, level)))
	label.Parent = gui
	gui.Parent = model.PrimaryPart
	return model
end

function Base.RefreshAll(player)
	local s = S.Data.Get(player)
	if not s or not s.baseIndex then
		return
	end
	local b = bases[s.baseIndex]
	if not b or b.owner ~= player then
		return
	end
	local d = s.data
	local skin = SkinConfig.ById[d.skin] or SkinConfig.ById.classic
	ensureFloors(b, d.floors or 1, skin.style)
	if b.skin ~= skin.id or b.skinFloors ~= d.floors then
		b.skin, b.skinFloors = skin.id, d.floors
		GarageKit.ApplyStyle(b.model, skin.style)
	end
	local trapLevel = TrapConfig.Clamp(d.trapLevel or 1)
	if b.trapLevel ~= trapLevel then
		applyTrapLevel(b, trapLevel)
	end
	local now = os.clock()
	local bySlot = {}
	for _, c in ipairs(d.cars) do
		if c.parkedSlot then
			bySlot[c.parkedSlot] = c
		end
	end
	for slot = 1, BaseLayout.SlotCount do
		local pad = b.pads[slot]
		local car = bySlot[slot]
		if not pad then
			car = nil
		end
		local hidden = car and s.hidden[car.uid] and s.hidden[car.uid] > now
		if slot > d.garageSlotCount then
			setPad(pad, "locked")
			car = nil
		elseif car and not hidden then
			local def = CarConfig.ById[car.typeId]
			setPad(pad, "occupied", CarConfig.Rarities[def.rarity].color)
		else
			setPad(pad, "free")
		end
		local gear = car and GearConfig.Active(car.gear) and car.gear
		local want = (car and not hidden) and (car.uid .. ":" .. car.level .. ":" .. (gear and (gear.id .. "@" .. gear.exp) or "-")) or nil
		if b.sig[slot] ~= want then
			if b.carModels[slot] then
				b.carModels[slot]:Destroy()
				b.carModels[slot] = nil
			end
			b.sig[slot] = want
			if want then
				local def = CarConfig.ById[car.typeId]
				local model = buildCarModel(def, car.level, BaseLayout.SlotCFrame(b.index, slot), car)
				model.Name = "Car_" .. slot
				model.Parent = b.cars
				b.carModels[slot] = model
			end
		end
	end
end

function Base.SetIncomeText(player, text)
	local s = S.Data.Get(player)
	if s and s.baseIndex and bases[s.baseIndex] then
		setLabel(bases[s.baseIndex].screen, text)
	end
end

return Base
