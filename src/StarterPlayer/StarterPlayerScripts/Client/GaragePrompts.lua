-- Own-garage interactions created on this client only: buy the next bay right at the bay,
-- build the next floor at the lift, ride the lift between floors.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BaseLayout = require(Shared:WaitForChild("BaseLayout"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))
local CarConfig = require(Shared:WaitForChild("CarConfig"))

local GP = {}
local K, store, Cine
local folder
local sig = ""

local function anchor(name, cf)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(4, 4, 4)
	p.CFrame = cf
	p.Parent = folder
	return p
end

local function prompt(part, action, object, onTrigger)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action
	pp.ObjectText = object
	pp.HoldDuration = 0.35
	pp.MaxActivationDistance = 12
	pp.RequiresLineOfSight = false
	pp.Parent = part
	pp.Triggered:Connect(onTrigger)
	return pp
end

local function priceTag(part, text, color)
	local bb = K.new("BillboardGui", { Adornee = part, Size = UDim2.fromOffset(150, 44), StudsOffset = Vector3.new(0, 3, 0), MaxDistance = 80, LightInfluence = 0 }, part)
	local f = K.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color }, bb)
	K.corner(f, 14)
	K.stroke(f, K.P.ink, 3)
	K.text(f, { Text = text, TextSize = 22, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
end

local function ride(targetY, bcf)
	local char = Players.LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	if Cine then
		Cine.Flash(Color3.new(0, 0, 0), 0.2, 0.5)
	end
	local dest = bcf * CFrame.new(-15, targetY + 3, BaseLayout.ElevatorLocal.Z)
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.CFrame = CFrame.lookAt(dest.Position, dest.Position + bcf:VectorToWorldSpace(Vector3.new(-1, 0, 0)))
end

local function rebuild()
	local st = store.State
	if not st or not st.baseIndex then
		return
	end
	local floors = st.floors or 1
	local carKey = {}
	for _, c in ipairs(st.cars) do
		if c.slot then
			table.insert(carKey, c.uid .. "@" .. c.slot .. "L" .. c.level)
		end
	end
	table.sort(carKey)
	local key = table.concat({ st.baseIndex, st.slots, floors, table.concat(carKey, ",") }, ":")
	if key == sig then
		return
	end
	sig = key
	folder:ClearAllChildren()
	local bcf = BaseLayout.GetBaseCFrame(st.baseIndex)

	-- next bay: price tag + buy prompt right on the bay
	local nextSlot = st.slots + 1
	if nextSlot <= floors * BaseLayout.SlotsPerFloor and EconomyConfig.SlotCosts[nextSlot] then
		local cost = EconomyConfig.SlotCosts[nextSlot]
		local p = BaseLayout.SlotLocal(nextSlot)
		local a = anchor("BuyBay", bcf * CFrame.new(p.X, BaseLayout.FloorY + p.Y + 2, p.Z))
		priceTag(a, "🔒 $" .. Util.FormatNumber(cost), store.Money >= cost and K.P.green or K.P.grey)
		prompt(a, "Buy bay $" .. Util.FormatNumber(cost), "Parking bay " .. nextSlot, function()
			K.actions.BuySlot(st.slots)
		end)
	end

	-- every parked car: take it out of the garage, or sell it right there
	for _, c in ipairs(st.cars) do
		if c.slot then
			local def = CarConfig.ById[c.typeId]
			local p = BaseLayout.SlotLocal(c.slot)
			local a = anchor("Car" .. c.slot, bcf * CFrame.new(p.X, BaseLayout.FloorY + p.Y + 3, p.Z))
			local rm = prompt(a, "Remove", def and def.name or "Car", function()
				K.actions.Remove(c.uid)
			end)
			rm.KeyboardKeyCode = Enum.KeyCode.E
			rm.MaxActivationDistance = 9
			local price = def and CarConfig.SellPrice(def, c.level) or 0
			local sp = prompt(a, "Sell $" .. Util.FormatNumber(price), def and def.name or "Car", function()
				K.confirm("SELL THIS CAR?", string.format("<b>%s</b>  Lv %d\nfor <b>$%s</b>", def.name, c.level, Util.FormatNumber(price)), "SELL $" .. Util.FormatNumber(price), K.P.red, function()
					K.actions.Sell(c.uid)
				end, def)
			end)
			sp.KeyboardKeyCode = Enum.KeyCode.F
			sp.MaxActivationDistance = 9
			sp.UIOffset = Vector2.new(0, 70)
		end
	end

	-- lift: build the next floor, or ride to any built floor
	local el = BaseLayout.ElevatorLocal
	for f = 1, floors do
		local y = (f - 1) * BaseLayout.FloorHeight
		local stop = anchor("LiftStop" .. f, bcf * CFrame.new(f == 1 and el.X or -15, BaseLayout.FloorY + y + 2, el.Z))
		for g = 1, floors do
			if g ~= f then
				prompt(stop, g == 1 and "Ground floor" or ("Level " .. g), "Lift", function()
					ride((g - 1) * BaseLayout.FloorHeight + BaseLayout.FloorY, bcf)
				end)
			end
		end
		if f == 1 and floors < BaseLayout.MaxFloors then
			local cost = EconomyConfig.FloorCosts[floors + 1]
			local full = st.slots >= floors * BaseLayout.SlotsPerFloor
			priceTag(stop, (full and "🏗️ $" or "🔒 $") .. Util.FormatNumber(cost), (full and store.Money >= cost) and K.P.orange or K.P.grey)
			prompt(stop, "Build level " .. (floors + 1) .. " $" .. Util.FormatNumber(cost), "Lift", function()
				K.actions.BuyFloor(floors)
			end)
		end
	end
end

-- other players' garages are closed to you (no walking in, no stealing); yours stays open
local lastPrivacy
local function privacy(st)
	if lastPrivacy == st.baseIndex then
		return
	end
	lastPrivacy = st.baseIndex
	local map = Workspace:FindFirstChild("GeneratedMap")
	for _, d in ipairs(map and map:GetDescendants() or {}) do
		if d.Name == "PrivacyWall" and d:IsA("BasePart") then
			d.CanCollide = d:GetAttribute("BaseIndex") ~= st.baseIndex
		end
	end
end

function GP.Start(kit, cine)
	K = kit
	store = K.store
	Cine = cine
	folder = Instance.new("Folder")
	folder.Name = "GaragePrompts"
	folder.Parent = Workspace
	store.Changed.Event:Connect(function()
		rebuild()
		if store.State and store.State.baseIndex then
			privacy(store.State)
		end
	end)
	rebuild()
	Net.Get("BuyFloor") -- make sure the remote exists before the first click
end

return GP
