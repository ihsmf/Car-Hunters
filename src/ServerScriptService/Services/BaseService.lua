local Players = game:GetService("Players")
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
		for n = 1, BaseLayout.SlotCount do
			b.pads[n] = slots:WaitForChild("Slot" .. n)
		end
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

function Base.SetFree(b)
	b.owner = nil
	for slot, model in pairs(b.carModels) do
		model:Destroy()
	end
	b.carModels = {}
	b.sig = {}
	for _, pad in ipairs(b.pads) do
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

local function buildCarModel(def, level, slotCF)
	local model = VehicleFactory.BuildCar(def)
	model:PivotTo(slotCF)
	ExhaustFx.Attach(model, def, CarConfig.Rarities[def.rarity].index)
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
	label.Text = string.format("%s  Lv%d\n+%s/s", def.name, level, Util.FormatNumber(CarConfig.IncomeAt(def, level)))
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
		local want = (car and not hidden) and (car.uid .. ":" .. car.level) or nil
		if b.sig[slot] ~= want then
			if b.carModels[slot] then
				b.carModels[slot]:Destroy()
				b.carModels[slot] = nil
			end
			b.sig[slot] = want
			if want then
				local def = CarConfig.ById[car.typeId]
				local model = buildCarModel(def, car.level, BaseLayout.SlotCFrame(b.index, slot))
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
