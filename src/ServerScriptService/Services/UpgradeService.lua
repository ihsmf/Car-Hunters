local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))
local CarConfig = require(Shared:WaitForChild("CarConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))

local Upgrade = {}
local S

function Upgrade.Init(hub)
	S = hub
end

function Upgrade.UpgradeCar(player, uid, expectedLevel)
	if type(uid) ~= "string" or #uid > 64 or not Util.IsInt(expectedLevel) then
		return
	end
	local s = S.Data.Get(player)
	if not s or not s.ready then
		return
	end
	if not S.Data.RateLimit(player, "upgrade", 0.25) then
		return
	end
	if not S.Base.IsNearOwnBase(player) then
		S.Data.Notify(player, "tooFar", nil, "warn")
		return
	end
	local d = s.data
	local car = S.Cars.Find(d, uid)
	if not car then
		return
	end
	if car.level ~= expectedLevel then
		S.Data.Notify(player, "stale", nil, "warn")
		S.Data.Push(player)
		return
	end
	local def = CarConfig.ById[car.typeId]
	if car.level >= def.maxLevel then
		S.Data.Notify(player, "maxLevel", nil, "warn")
		return
	end
	local cost = CarConfig.UpgradeCost(def, car.level)
	local partId, amount = CarConfig.UpgradeParts(def, car.level)
	if d.money < cost then
		S.Data.Notify(player, "noMoney", nil, "error")
		return
	end
	if (d.parts[partId] or 0) < amount then
		S.Data.Notify(player, "noParts", nil, "error")
		return
	end
	d.money = d.money - cost
	d.parts[partId] = d.parts[partId] - amount
	car.level = car.level + 1
	d.stats.upgrades = d.stats.upgrades + 1
	S.Data.Notify(player, "upgraded", { car.level }, "good")
	S.Base.RefreshAll(player)
	S.Income.Recalc(player)
	S.Data.Push(player)
end

function Upgrade.BuySlot(player, expectedCount)
	if not Util.IsInt(expectedCount) then
		return
	end
	local s = S.Data.Get(player)
	if not s or not s.ready then
		return
	end
	if not S.Data.RateLimit(player, "slot", 0.4) then
		return
	end
	if not S.Base.IsNearOwnBase(player) then
		S.Data.Notify(player, "tooFar", nil, "warn")
		return
	end
	local d = s.data
	if d.garageSlotCount ~= expectedCount then
		S.Data.Notify(player, "stale", nil, "warn")
		S.Data.Push(player)
		return
	end
	local nextSlot = d.garageSlotCount + 1
	local cost = EconomyConfig.SlotCosts[nextSlot]
	if not cost or nextSlot > EconomyConfig.MaxSlots then
		return
	end
	if nextSlot > d.floors * 6 then
		S.Data.Notify(player, "needFloor", nil, "warn")
		return
	end
	if d.money < cost then
		S.Data.Notify(player, "noMoney", nil, "error")
		return
	end
	d.money = d.money - cost
	d.garageSlotCount = nextSlot
	S.Data.Notify(player, "slotBought", { nextSlot }, "good")
	S.Base.RefreshAll(player)
	S.Data.Push(player)
end

function Upgrade.BuyFloor(player, expectedFloors)
	if not Util.IsInt(expectedFloors) then
		return
	end
	local s = S.Data.Get(player)
	if not s or not s.ready or not S.Data.RateLimit(player, "floor", 0.5) then
		return
	end
	if not S.Base.IsNearOwnBase(player) then
		S.Data.Notify(player, "tooFar", nil, "warn")
		return
	end
	local d = s.data
	if d.floors ~= expectedFloors then
		S.Data.Push(player)
		return
	end
	local nextFloor = d.floors + 1
	local cost = EconomyConfig.FloorCosts[nextFloor]
	if not cost then
		return
	end
	if d.garageSlotCount < d.floors * 6 then
		S.Data.Notify(player, "fillFloor", nil, "warn")
		return
	end
	if d.money < cost then
		S.Data.Notify(player, "noMoney", nil, "error")
		return
	end
	d.money = d.money - cost
	d.floors = nextFloor
	S.Data.Notify(player, "floorBuilt", { nextFloor }, "good")
	S.Base.RefreshAll(player)
	S.Data.Push(player)
end

return Upgrade
