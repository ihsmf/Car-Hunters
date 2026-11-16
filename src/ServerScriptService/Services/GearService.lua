-- Gears (v24): timed boosts bought for money at Big Tony (stock per player, new every GearConfig.Window seconds)
-- and applied to one owned car. Income gears boost that car (CarConfig.CarIncome); speed / luck gears boost the
-- player while the geared car is parked (the best one counts, they do not stack).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GearConfig = require(Shared:WaitForChild("GearConfig"))
local Util = require(Shared:WaitForChild("Util"))

local Gears = {}
local S

function Gears.Init(hub)
	S = hub
end

local function findCar(d, uid)
	for _, c in ipairs(d.cars) do
		if c.uid == uid then
			return c
		end
	end
	return nil
end

-- the shop window record for now (a new window starts with nothing bought)
local function shopWindow(d)
	local w = GearConfig.WindowAt(os.time())
	if type(d.gearShop) ~= "table" or d.gearShop.window ~= w then
		d.gearShop = { window = w, bought = {} }
	end
	return d.gearShop
end
Gears.ShopWindow = shopWindow

-- how many of a gear the player can still buy in the current window
function Gears.StockLeft(player, s, id)
	local shop = shopWindow(s.data)
	local stock = GearConfig.Stock(player.UserId, shop.window)[id] or 0
	return math.max(0, stock - (shop.bought[id] or 0))
end

-- player-wide effect ("speed" / "luck"): the best active gear on a PARKED car, 1 without one
function Gears.PlayerMult(s, kind)
	local d = s and s.data
	if not d or type(d.cars) ~= "table" then
		return 1
	end
	local now = os.time()
	local best = 1
	for _, c in ipairs(d.cars) do
		if c.parkedSlot and c.gear then
			local def = GearConfig.Active(c.gear, now)
			local m = def and def.effects[kind]
			if m and m > best then
				best = m
			end
		end
	end
	return best
end

-- income multiplier of one car (1 without an active income gear)
function Gears.CarMult(car)
	return GearConfig.CarMult(car, os.time())
end

-- after anything that changes gear effects: income, walk speed, garage models, client state
local function refresh(player)
	S.Income.Recalc(player)
	S.Shop.ApplyCharacter(player)
	S.Base.RefreshAll(player)
	S.Data.Push(player)
end

function Gears.Buy(player, id)
	local s = S.Data.Get(player)
	local def = type(id) == "string" and GearConfig.ById[id]
	if not s or not s.ready or not def or not S.Data.RateLimit(player, "gearBuy", 0.3) then
		return
	end
	if not S.Mechanic.NearTony(player) then
		S.Data.Notify(player, "gearNearTony", nil, "warn")
		return
	end
	local d = s.data
	if Gears.StockLeft(player, s, id) < 1 then
		S.Data.Notify(player, "noStock", { def.name }, "warn")
		return
	end
	local price = GearConfig.Price(def, d.peakIncome)
	if d.money < price then
		S.Data.Notify(player, "noMoney", nil, "error")
		return
	end
	d.money = d.money - price
	local shop = d.gearShop
	shop.bought[id] = (shop.bought[id] or 0) + 1
	d.gears[id] = math.min((d.gears[id] or 0) + 1, 999)
	S.Data.Notify(player, "gearBought", { def.name }, "good")
	if S.Mechanic.Gesture then
		S.Mechanic.Gesture()
	end
	S.Data.Push(player)
end

-- put a gear from the inventory on an owned car (parked or stored). An active gear is replaced (the client confirms).
function Gears.Apply(player, carUid, id)
	local s = S.Data.Get(player)
	local def = type(id) == "string" and GearConfig.ById[id]
	if not s or not s.ready or not def or type(carUid) ~= "string" or not S.Data.RateLimit(player, "gearApply", 0.3) then
		return
	end
	local d = s.data
	local car = findCar(d, carUid)
	if not car or (d.gears[id] or 0) < 1 then
		return
	end
	d.gears[id] = d.gears[id] - 1
	if d.gears[id] <= 0 then
		d.gears[id] = nil
	end
	car.gear = { id = id, exp = os.time() + def.seconds }
	S.Data.Notify(player, "gearApplied", { def.name, GearConfig.Label(def) }, "good")
	refresh(player)
end

-- grant gears (road drops, boss reward, playtime chest)
function Gears.Give(player, id, n)
	local s = S.Data.Get(player)
	if s and s.data and GearConfig.ById[id] then
		s.data.gears[id] = math.min((s.data.gears[id] or 0) + (n or 1), 999)
		S.Data.Push(player)
		return true
	end
	return false
end

-- a random gear from a list of ids; returns its def (or nil)
function Gears.GiveRandom(player, ids)
	local id = ids[math.random(1, #ids)]
	if Gears.Give(player, id, 1) then
		return GearConfig.ById[id]
	end
	return nil
end

-- every gear id up to a tier (playtime chest)
function Gears.IdsUpToTier(maxTier)
	local out = {}
	for _, def in ipairs(GearConfig.List) do
		if def.tier <= maxTier then
			table.insert(out, def.id)
		end
	end
	return out
end

local function tick(player, s)
	local d = s.data
	local now = os.time()
	local expired
	for _, c in ipairs(d.cars) do
		if c.gear and not GearConfig.Active(c.gear, now) then
			expired = expired or GearConfig.ById[c.gear.id]
			c.gear = nil
		end
	end
	-- speed / luck follow parked cars: park, unpark, trade or expiry all land here
	local sig = Gears.PlayerMult(s, "speed") .. ":" .. Gears.PlayerMult(s, "luck")
	if expired then
		s.gearSig = sig
		S.Data.Notify(player, "gearExpired", { expired.name }, "info")
		refresh(player)
	elseif sig ~= s.gearSig then
		s.gearSig = sig
		S.Shop.ApplyCharacter(player)
		S.Data.Push(player)
	end
	-- one-time notice saved by the data migration (tuning refund)
	local pn = d.pendingNotice
	if pn and os.clock() - (s.joinedAt or 0) > 4 then
		d.pendingNotice = nil
		if pn.key == "tuneRefund" then
			S.Data.Notify(player, "tuneRefund", { Util.FormatNumber(pn.amount or 0) }, "good")
		elseif pn.key == "gearWelcome" then
			S.Data.Notify(player, "gearWelcome", nil, "good")
		end
	end
end

function Gears.Start()
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in ipairs(Players:GetPlayers()) do
				local s = S.Data.Get(player)
				if s and s.ready and s.data then
					local ok, err = pcall(tick, player, s)
					if not ok then
						warn("[Gears] tick failed:", err)
					end
				end
			end
		end
	end)
end

return Gears
