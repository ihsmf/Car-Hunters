local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local CarConfig = require(Shared:WaitForChild("CarConfig"))

local Cars = {}
local S

function Cars.Init(hub)
	S = hub
end

function Cars.Find(d, uid)
	for _, c in ipairs(d.cars) do
		if c.uid == uid then
			return c
		end
	end
	return nil
end

local function ctx(player, uid)
	if type(uid) ~= "string" or #uid > 64 then
		return nil
	end
	local s = S.Data.Get(player)
	if not s or not s.ready then
		return nil
	end
	if not S.Data.RateLimit(player, "cars", EconomyConfig.ActionCooldown) then
		return nil
	end
	return s -- garage actions work from anywhere (menu or the prompt at the car)
end

local function finish(player)
	S.Base.RefreshAll(player)
	S.Income.Recalc(player)
	S.Data.Push(player)
end

function Cars.Place(player, uid, slot)
	local s = ctx(player, uid)
	if not s or not Util.IsInt(slot) then
		return
	end
	local d = s.data
	if slot < 1 or slot > d.garageSlotCount then
		return
	end
	local car = Cars.Find(d, uid)
	if not car then
		return
	end
	local occupant
	for _, c in ipairs(d.cars) do
		if c ~= car and c.parkedSlot == slot then
			occupant = c
			break
		end
	end
	local oldSlot = car.parkedSlot
	car.parkedSlot = slot
	car.benched = nil
	if occupant then
		occupant.parkedSlot = oldSlot
		occupant.benched = oldSlot == nil or nil -- swapped out to storage: keep it there
	end
	finish(player)
end

function Cars.Remove(player, uid)
	local s = ctx(player, uid)
	if not s then
		return
	end
	local car = Cars.Find(s.data, uid)
	if not car or not car.parkedSlot then
		return
	end
	car.parkedSlot = nil
	car.benched = true -- stays in storage until you park it again (auto-park after throws skips it)
	finish(player)
end

function Cars.Sell(player, uid)
	local s = ctx(player, uid)
	if not s then
		return
	end
	local d = s.data
	if s.hidden[uid] then
		S.Data.Notify(player, "busy", nil, "warn")
		return
	end
	local idx
	for i, c in ipairs(d.cars) do
		if c.uid == uid then
			idx = i
			break
		end
	end
	if not idx then
		return
	end
	local car = d.cars[idx]
	local def = CarConfig.ById[car.typeId]
	if def.exclusive then
		S.Data.Notify(player, "exclusiveKeep", nil, "warn")
		return
	end
	local price = CarConfig.SellPrice(def, car.level)
	table.remove(d.cars, idx)
	d.money = math.min(d.money + price, EconomyConfig.MaxMoney)
	d.stats.sold = (d.stats.sold or 0) + 1
	S.Data.Notify(player, "sold", { def.name, price }, "good")
	finish(player)
end

-- sell several cars at once (garage menu "sell all ..."); max 100 per call
function Cars.SellMany(player, uids)
	if type(uids) ~= "table" or #uids == 0 or #uids > 100 then
		return
	end
	local s = S.Data.Get(player)
	if not s or not s.ready or not S.Data.RateLimit(player, "sellmany", 1) then
		return
	end
	local d = s.data
	local want = {}
	for _, uid in ipairs(uids) do
		if type(uid) == "string" and #uid <= 64 then
			want[uid] = true
		end
	end
	local total, n = 0, 0
	for i = #d.cars, 1, -1 do
		local car = d.cars[i]
		local def = CarConfig.ById[car.typeId]
		if want[car.uid] and not s.hidden[car.uid] and def and not def.exclusive then
			total = total + CarConfig.SellPrice(def, car.level)
			n = n + 1
			table.remove(d.cars, i)
		end
	end
	if n == 0 then
		return
	end
	d.money = math.min(d.money + total, EconomyConfig.MaxMoney)
	d.stats.sold = (d.stats.sold or 0) + n
	S.Data.Notify(player, "soldMany", { n, total }, "good")
	finish(player)
end

-- best-earning cars take the bays (cars mid-animation keep theirs); no checks, used after throws too
function Cars.ParkBest(s, includeBenched)
	local d = s.data
	local list = {}
	for _, c in ipairs(d.cars) do
		if includeBenched then
			c.benched = nil
		end
		if not s.hidden[c.uid] and not c.benched then
			table.insert(list, c)
		end
	end
	table.sort(list, function(a, b)
		local ia = CarConfig.CarIncome(a)
		local ib = CarConfig.CarIncome(b)
		if ia ~= ib then
			return ia > ib
		end
		return a.uid < b.uid
	end)
	local reserved = {}
	for _, c in ipairs(d.cars) do
		if s.hidden[c.uid] and c.parkedSlot then
			reserved[c.parkedSlot] = true
		end
	end
	local free = {}
	for i = 1, d.garageSlotCount do
		if not reserved[i] then
			table.insert(free, i)
		end
	end
	for i, c in ipairs(list) do
		c.parkedSlot = free[i]
	end
end

function Cars.AutoPark(player)
	local s = S.Data.Get(player)
	if not s or not s.ready then
		return
	end
	if not S.Data.RateLimit(player, "autopark", 1) then
		return
	end
	if not S.Base.IsNearOwnBase(player) then
		S.Data.Notify(player, "tooFar", nil, "warn")
		return
	end
	Cars.ParkBest(s, true)
	S.Data.Notify(player, "autoParked", nil, "good")
	finish(player)
end

return Cars
