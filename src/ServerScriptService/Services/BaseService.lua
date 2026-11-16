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

---------------------------------------------------------------- throw platform looks (v24, TrapService levels)
-- Everything lives in a "TrapUpgrades" folder of the base model, positioned from BaseLayout.TrapLocal. Levels add up:
-- 2 painted trims, 3 lit edges, 4 corner pylons, 5 holo ring (client spin), 6 sparks, 7 glowing posts + sky beam,
-- 8 holo floor (client spin), 9 energy dome, 10 golden platform + crown. Fixed colours (the garage skin never
-- touches "TrapUp*" names). All pieces: anchored, no collide / query / touch / shadow; overlays >= 0.08 off surfaces.
local TRAP_ORANGE = Color3.fromRGB(255, 138, 31)
local TRAP_WHITE = Color3.fromRGB(245, 245, 240)
local TRAP_CYAN = Color3.fromRGB(70, 225, 255)
local TRAP_GOLD = Color3.fromRGB(255, 196, 54)
local TRAP_DARK = Color3.fromRGB(32, 34, 42)
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
	if o.shape then
		p.Shape = o.shape
	end
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- a flat ring of n segments (a thin torus) around `cf` (local Y up); returns the model
local function trapRing(parent, name, cf, radius, n, thick, height, color, t)
	local m = Instance.new("Model")
	m.Name = name
	local len = 2 * radius * math.sin(math.pi / n) + 0.05
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		trapPart(m, name .. "Seg", Vector3.new(thick, height, len), cf * CFrame.Angles(0, a, 0) * CFrame.new(radius, 0, 0), color, Enum.Material.Neon, { t = t })
	end
	m.WorldPivot = cf
	m.Parent = parent
	return m
end

local function trapSpin(m, cf, speed)
	m.WorldPivot = cf
	m:SetAttribute("SpinCF", cf)
	m:SetAttribute("SpinSpeed", speed)
	CollectionService:AddTag(m, "TrapSpin")
end

local function trapSparks(parent, color, rate)
	local e = Instance.new("ParticleEmitter")
	e.Name = "TrapUpSparks"
	e.Color = ColorSequence.new(Color3.new(1, 1, 0.85), color)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.4) })
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(5, 9)
	e.SpreadAngle = Vector2.new(28, 28)
	e.Acceleration = Vector3.new(0, -18, 0)
	e.Drag = 1
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
	local glow = gold and TRAP_GOLD or TRAP_CYAN
	local NEON, METAL, FOIL = Enum.Material.Neon, Enum.Material.Metal, Enum.Material.Foil
	local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- cylinders: axis along local Y
	local corners = { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }

	-- level sign under "THROW PARTS HERE" (TrapSign: x +10.2, y 12..14.4)
	local sign = trapPart(f, "TrapUpSign", Vector3.new(0.4, 1.5, 7.4), O * CFrame.new(10.2, 11.1, 0), TRAP_DARK, Enum.Material.SmoothPlastic)
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

	if level >= 2 then -- painted trims: an orange band round the plinth, racing bands on the posts and the crane beam
		trapPart(f, "TrapUpTrim", Vector3.new(21.16, 0.2, 21.16), O * CFrame.new(0, 0.8, 0), TRAP_ORANGE, Enum.Material.SmoothPlastic)
		for _, c in ipairs(corners) do
			for i, y in ipairs({ 3.2, 5.2, 10.6 }) do
				trapPart(f, "TrapUpTrim", Vector3.new(1.36, 0.55, 1.36), O * CFrame.new(c[1] * 9.6, y, c[2] * 9.6), i == 2 and TRAP_WHITE or TRAP_ORANGE, Enum.Material.SmoothPlastic)
			end
		end
		for _, x in ipairs({ -6, 6 }) do
			trapPart(f, "TrapUpTrim", Vector3.new(0.7, 1.36, 1.36), O * CFrame.new(x, 14.2, 0), TRAP_ORANGE, Enum.Material.SmoothPlastic)
		end
	end
	if level >= 3 then -- lit edges: a neon frame on the deck rim and one on the plinth rim
		for _, s in ipairs({ -1, 1 }) do
			trapPart(f, "TrapUpEdge", Vector3.new(17.4, 0.12, 0.3), O * CFrame.new(0, 1.74, s * 8.55), glow, NEON)
			trapPart(f, "TrapUpEdge", Vector3.new(0.3, 0.12, 16.7), O * CFrame.new(s * 8.55, 1.74, 0), glow, NEON)
			trapPart(f, "TrapUpEdge", Vector3.new(17.6, 0.12, 0.3), O * CFrame.new(0, 1.14, s * 9.85), glow, NEON)
			trapPart(f, "TrapUpEdge", Vector3.new(0.3, 0.12, 17.6), O * CFrame.new(s * 9.85, 1.14, 0), glow, NEON)
		end
	end
	local caps = {}
	if level >= 4 then -- corner pylons just outside the plinth (diagonals: the walk-in sides stay open)
		for i, c in ipairs(corners) do
			local x, z = c[1] * 12.2, c[2] * 12.2
			trapPart(f, "TrapUpPylon", Vector3.new(2, 0.3, 2), O * CFrame.new(x, 0.67, z), TRAP_DARK, METAL)
			trapPart(f, "TrapUpPylon", Vector3.new(5.4, 0.9, 0.9), O * CFrame.new(x, 3.52, z) * UPRIGHT, TRAP_WHITE, METAL, { shape = Enum.PartType.Cylinder })
			trapPart(f, "TrapUpPylon", Vector3.new(0.5, 1.2, 1.2), O * CFrame.new(x, 2.2, z) * UPRIGHT, TRAP_ORANGE, Enum.Material.SmoothPlastic, { shape = Enum.PartType.Cylinder })
			trapPart(f, "TrapUpPylon", Vector3.new(0.3, 1.3, 1.3), O * CFrame.new(x, 6.36, z) * UPRIGHT, TRAP_DARK, METAL, { shape = Enum.PartType.Cylinder })
			caps[i] = trapPart(f, "TrapUpCap", Vector3.new(1.3, 1.3, 1.3), O * CFrame.new(x, 7.15, z), glow, NEON, { shape = Enum.PartType.Ball })
		end
	end
	if level >= 5 then -- hologram ring floating round the deck (spun by the client)
		local cf = O * CFrame.new(0, 4.4, 0)
		local ring = trapRing(f, "TrapUpRing", cf, 11.2, 28, 0.5, 0.3, glow, 0.3)
		for i = 0, 3 do
			trapPart(ring, "TrapUpRingGem", Vector3.new(0.7, 0.7, 0.7), cf * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(11.2, 0, 0) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), TRAP_WHITE, NEON, { t = 0.1 })
		end
		trapSpin(ring, cf, 0.6)
	end
	if level >= 6 then -- sparks fountain off the pylon caps
		for _, cap in ipairs(caps) do
			local att = Instance.new("Attachment")
			att.Name = "TrapUpSparkAt"
			att.Position = Vector3.new(0, 0.6, 0)
			att.Parent = cap
			trapSparks(att, gold and TRAP_GOLD or TRAP_ORANGE, 14)
			trapLight(cap, glow, 10, 1.2)
		end
	end
	if level >= 7 then -- glowing posts (neon strips on the outer faces) + a sky beam from the crane
		for _, c in ipairs(corners) do
			trapPart(f, "TrapUpPillar", Vector3.new(0.2, 9.6, 0.4), O * CFrame.new(c[1] * 10.4, 7.4, c[2] * 9.6), glow, NEON)
			trapPart(f, "TrapUpPillar", Vector3.new(0.4, 9.6, 0.2), O * CFrame.new(c[1] * 9.6, 7.4, c[2] * 10.4), glow, NEON)
		end
		trapPart(f, "TrapUpEmitter", Vector3.new(0.4, 2.6, 2.6), O * CFrame.new(0, 15.08, 0) * UPRIGHT, TRAP_DARK, METAL, { shape = Enum.PartType.Cylinder })
		trapPart(f, "TrapUpEmitter", Vector3.new(0.2, 1.6, 1.6), O * CFrame.new(0, 15.38, 0) * UPRIGHT, glow, NEON, { shape = Enum.PartType.Cylinder })
		trapPart(f, "TrapUpBeam", Vector3.new(70, 1.3, 1.3), O * CFrame.new(0, 15.5 + 35, 0) * UPRIGHT, glow, NEON, { shape = Enum.PartType.Cylinder, t = 0.55 })
		trapPart(f, "TrapUpBeam", Vector3.new(69.6, 2.6, 2.6), O * CFrame.new(0, 15.5 + 35, 0) * UPRIGHT, glow, NEON, { shape = Enum.PartType.Cylinder, t = 0.85 }) -- caps off the inner beam's planes
	end
	if level >= 8 then -- holo floor: two neon rings + a cross-hair, flat on the deck (pad top 1.6), slowly turning
		local cf = O * CFrame.new(0, 1.71, 0)
		local floor = Instance.new("Model")
		floor.Name = "TrapUpFloor"
		trapRing(floor, "TrapUpFloorRing", cf * CFrame.new(0, 0.08, 0), 7.4, 28, 0.28, 0.06, glow, 0.3)
		trapRing(floor, "TrapUpFloorRing", cf * CFrame.new(0, 0.08, 0), 4.4, 20, 0.22, 0.06, glow, 0.3)
		for i = 0, 3 do
			trapPart(floor, "TrapUpFloorTick", Vector3.new(2.2, 0.06, 0.16), cf * CFrame.Angles(0, i * math.pi / 2 + math.pi / 4, 0) * CFrame.new(5.9, 0, 0), TRAP_WHITE, NEON, { t = 0.3 })
		end
		floor.Parent = f
		trapSpin(floor, cf, -0.25)
	end
	if level >= 9 then -- energy dome over the whole lift (no collision, no raycasts: walk and throw straight through)
		local dome = trapPart(f, "TrapUpDome", Vector3.new(34, 38, 34), O * CFrame.new(0, 0.5, 0), gold and TRAP_GOLD or Color3.fromRGB(90, 200, 255), Enum.Material.ForceField, { t = 0.6 })
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = dome
	end
	if gold then -- crown on the magnet + a golden light (the pad and plinth turned gold above)
		local top = O * CFrame.new(0, 10.4, 0) -- magnet: height 1.2 at y 9.8
		local crown = trapPart(f, "TrapUpCrown", Vector3.new(0.8, 4, 4), top * CFrame.new(0, 0.48, 0) * UPRIGHT, TRAP_GOLD, FOIL, { shape = Enum.PartType.Cylinder })
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			local spike = top * CFrame.Angles(0, a, 0) * CFrame.new(1.7, 1.45, 0)
			trapPart(f, "TrapUpCrown", Vector3.new(0.45, 1.2, 0.45), spike * CFrame.Angles(0, math.pi / 4, 0), TRAP_GOLD, FOIL)
			trapPart(f, "TrapUpCrownGem", Vector3.new(0.5, 0.5, 0.5), spike * CFrame.new(0, 0.85, 0), i % 2 == 0 and Color3.fromRGB(255, 70, 90) or Color3.fromRGB(80, 200, 255), NEON, { shape = Enum.PartType.Ball })
		end
		trapLight(crown, TRAP_GOLD, 22, 2)
		local att = Instance.new("Attachment")
		att.Name = "TrapUpSparkAt"
		att.Parent = crown
		trapSparks(att, TRAP_GOLD, 10)
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
