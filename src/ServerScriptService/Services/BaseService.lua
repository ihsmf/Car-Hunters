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
local TuningConfig = require(Shared:WaitForChild("TuningConfig"))
local SkinConfig = require(Shared:WaitForChild("SkinConfig"))
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

-- visible tuning: aero adds a wing, boost/nitro make the exhaust spit flames
local function applyTuneVisuals(model, def, tune)
	local root = model.PrimaryPart
	if not root or type(tune) ~= "table" then
		return
	end
	if tune.boost or tune.nitro then
		for _, att in ipairs(root:GetChildren()) do
			if att:IsA("Attachment") and att.Name == "Exhaust" then
				CollectionService:AddTag(att, "Backfire")
				att:SetAttribute("Color", tune.nitro and Color3.fromRGB(90, 170, 255) or Color3.fromRGB(255, 140, 40))
			end
		end
	end
	if tune.aero then
		local ext = model:GetExtentsSize()
		local stage = TuningConfig.Items[tune.aero].stage
		local back = root.CFrame * CFrame.new(-ext.X / 2 + 0.9, ext.Y / 2 + 0.3 + stage * 0.15, 0)
		local function wingPart(size, cf)
			local p = Instance.new("Part")
			p.Name = "Wing"
			p.Size = size
			p.CFrame = cf
			p.Color = stage == 3 and Color3.fromRGB(30, 30, 34) or def.body or Color3.fromRGB(30, 30, 34)
			p.Material = stage == 3 and Enum.Material.Metal or Enum.Material.SmoothPlastic -- (Material.Carbon does not exist)
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = true, false, false, false, true
			p.Parent = model
		end
		local wing = PartVisual.BuildTuning("aero", ext.Z * 0.85)
		if wing then
			-- Blender wing: its span lies along Y in Blender = along Z here, uprights point down
			wing:PivotTo(back * CFrame.new(0, -0.6, 0))
			wing.Parent = model
		else
			wingPart(Vector3.new(1.1, 0.14, ext.Z * 0.9), back)
			for _, z in ipairs({ -1, 1 }) do
				wingPart(Vector3.new(0.5, 0.8, 0.14), back * CFrame.new(0.1, -0.45, z * ext.Z * 0.3))
			end
		end
	end
end

local function buildCarModel(def, level, slotCF, car)
	local model = VehicleFactory.BuildCar(def)
	model:PivotTo(slotCF)
	ExhaustFx.Attach(model, def, CarConfig.Rarities[def.rarity].index)
	applyTuneVisuals(model, def, car and car.tune)
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
		local want = (car and not hidden) and (car.uid .. ":" .. car.level .. ":" .. TuningConfig.CarMult(car.tune)) or nil
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
