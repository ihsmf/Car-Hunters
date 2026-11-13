-- Player trading: request -> accept -> both sides offer cars / money / parts -> both READY -> 3 s countdown ->
-- the server re-checks everything and swaps atomically. Any change resets READY.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local CarConfig = require(Shared:WaitForChild("CarConfig"))
local PartConfig = require(Shared:WaitForChild("PartConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))

local Trade = {}
local S
local pending = {} -- [target] = { [requester] = time }
local active = {} -- [player] = trade
Trade.MaxCars = 8
Trade.Countdown = 3

function Trade.Init(hub)
	S = hub
end

local function fire(player, msg)
	if player and player.Parent then
		Net.Get("TradeEvent"):FireClient(player, msg)
	end
end

local function other(t, p)
	return t.a == p and t.b or t.a
end

local function emptyOffer()
	return { cars = {}, money = 0, parts = {} }
end

-- what a side offers, as the partner should see it
local function describe(player, offer)
	local s = S.Data.Get(player)
	local cars = {}
	for uid in pairs(offer.cars) do
		for _, c in ipairs(s and s.data.cars or {}) do
			if c.uid == uid then
				table.insert(cars, { uid = uid, typeId = c.typeId, level = c.level })
			end
		end
	end
	return { cars = cars, money = offer.money, parts = offer.parts }
end

local function broadcast(t)
	for _, p in ipairs({ t.a, t.b }) do
		local o = other(t, p)
		fire(p, { type = "state", partner = o.DisplayName, partnerId = o.UserId, mine = describe(p, t.offers[p]), theirs = describe(o, t.offers[o]),
			readyMe = t.ready[p] == true, readyThem = t.ready[o] == true, countdown = t.confirmAt and math.max(0, t.confirmAt - os.clock()) or nil })
	end
end

local function close(t, reason)
	for _, p in ipairs({ t.a, t.b }) do
		if active[p] == t then
			active[p] = nil
		end
		fire(p, { type = "closed", reason = reason })
	end
end

-- offer still valid against the player's current inventory?
local function valid(player, offer)
	local s = S.Data.Get(player)
	if not s or not s.ready then
		return false
	end
	local d = s.data
	if offer.money < 0 or offer.money > d.money then
		return false
	end
	for id, n in pairs(offer.parts) do
		if (d.parts[id] or 0) < n then
			return false
		end
	end
	local n = 0
	for uid in pairs(offer.cars) do
		n = n + 1
		local found = false
		for _, c in ipairs(d.cars) do
			local def = CarConfig.ById[c.typeId]
			if c.uid == uid and not s.hidden[uid] and not (def and def.exclusive) then -- exclusive (Robux) cars stay
				found = true
			end
		end
		if not found then
			return false
		end
	end
	return n <= Trade.MaxCars
end

local function count(t)
	local n = 0
	for _ in pairs(t) do
		n = n + 1
	end
	return n
end

-- a player with fewer rebirths cannot hand anything to one with more (no feeding a main account from an alt)
local function empty(o)
	return o.money == 0 and next(o.cars) == nil and next(o.parts) == nil
end
local function rebirthsOf(p)
	local s = S.Data.Get(p)
	return s and s.data.rebirths or 0
end
local function uphill(from, to, offer)
	return not empty(offer) and rebirthsOf(from) < rebirthsOf(to)
end

local function execute(t)
	local a, b = t.a, t.b
	local oa, ob = t.offers[a], t.offers[b]
	if not valid(a, oa) or not valid(b, ob) then
		close(t, "Trade cancelled: an offer changed")
		return
	end
	if uphill(a, b, oa) or uphill(b, a, ob) then
		close(t, "Trade cancelled: you can't give items to a player with more rebirths")
		return
	end
	local sa, sb = S.Data.Get(a), S.Data.Get(b)
	local da, db = sa.data, sb.data
	if #da.cars - count(oa.cars) + count(ob.cars) > EconomyConfig.MaxCars or #db.cars - count(ob.cars) + count(oa.cars) > EconomyConfig.MaxCars then
		close(t, "Trade cancelled: car storage is full")
		return
	end
	local function moveCars(fromD, toD, set)
		for i = #fromD.cars, 1, -1 do
			local c = fromD.cars[i]
			if set[c.uid] then
				table.remove(fromD.cars, i)
				c.parkedSlot, c.benched = nil, true
				table.insert(toD.cars, c)
				toD.discovered[c.typeId] = true
			end
		end
	end
	moveCars(da, db, oa.cars)
	moveCars(db, da, ob.cars)
	da.money = da.money - oa.money + ob.money
	db.money = db.money - ob.money + oa.money
	da.money = math.min(da.money, EconomyConfig.MaxMoney)
	db.money = math.min(db.money, EconomyConfig.MaxMoney)
	for id, n in pairs(oa.parts) do
		da.parts[id] = da.parts[id] - n
		db.parts[id] = (db.parts[id] or 0) + n
	end
	for id, n in pairs(ob.parts) do
		db.parts[id] = db.parts[id] - n
		da.parts[id] = (da.parts[id] or 0) + n
	end
	for _, p in ipairs({ a, b }) do
		local s = S.Data.Get(p)
		s.data.stats.trades = (s.data.stats.trades or 0) + 1
		S.Income.Recalc(p)
		S.Base.RefreshAll(p)
		S.Data.Push(p)
		task.spawn(S.Data.Save, p) -- persist right away (no dupes if a server dies)
	end
	close(t, "done")
end

function Trade.Request(player, targetId)
	if type(targetId) ~= "number" or not S.Data.RateLimit(player, "tradeReq", 3) then
		return
	end
	local target = Players:GetPlayerByUserId(targetId)
	if not target or target == player or active[player] or active[target] then
		S.Data.Notify(player, "tradeBusy", nil, "warn")
		return
	end
	pending[target] = pending[target] or {}
	pending[target][player] = os.clock()
	fire(target, { type = "request", from = player.UserId, name = player.DisplayName })
	S.Data.Notify(player, "tradeSent", { target.DisplayName }, "info")
end

function Trade.Respond(player, fromId, accept)
	local from = type(fromId) == "number" and Players:GetPlayerByUserId(fromId)
	local list = pending[player]
	if not from or not list or not list[from] then
		return
	end
	local at = list[from]
	list[from] = nil
	if not accept then
		S.Data.Notify(from, "tradeDeclined", { player.DisplayName }, "warn")
		return
	end
	if os.clock() - at > 30 or active[player] or active[from] then
		S.Data.Notify(player, "tradeBusy", nil, "warn")
		return
	end
	local t = { a = from, b = player, offers = { [from] = emptyOffer(), [player] = emptyOffer() }, ready = {}, version = 0 }
	active[from], active[player] = t, t
	broadcast(t)
end

function Trade.Update(player, offer)
	local t = active[player]
	if not t or type(offer) ~= "table" or not S.Data.RateLimit(player, "tradeUpd", 0.15) then
		return
	end
	local clean = emptyOffer()
	if type(offer.cars) == "table" then
		for _, uid in ipairs(offer.cars) do
			if type(uid) == "string" and #uid <= 64 and count(clean.cars) < Trade.MaxCars then
				clean.cars[uid] = true
			end
		end
	end
	local m = tonumber(offer.money) or 0
	clean.money = (m == m and m >= 0) and math.floor(m) or 0
	if type(offer.parts) == "table" then
		for _, id in ipairs(PartConfig.Order) do
			local n = tonumber(offer.parts[id])
			if n and n == n and n > 0 then
				clean.parts[id] = math.floor(n)
			end
		end
	end
	if not valid(player, clean) then
		S.Data.Notify(player, "tradeInvalid", nil, "error")
		return
	end
	local other = t.a == player and t.b or t.a
	if uphill(player, other, clean) then
		S.Data.Notify(player, "tradeUphill", nil, "warn")
		return
	end
	t.offers[player] = clean
	t.ready = {}
	t.confirmAt = nil
	t.version = t.version + 1
	broadcast(t)
end

function Trade.Ready(player, on)
	local t = active[player]
	if not t then
		return
	end
	t.ready[player] = on == true
	t.confirmAt = nil
	t.version = t.version + 1
	if t.ready[t.a] and t.ready[t.b] then
		local v = t.version
		t.confirmAt = os.clock() + Trade.Countdown
		task.delay(Trade.Countdown, function()
			if active[t.a] == t and t.version == v and t.ready[t.a] and t.ready[t.b] then
				execute(t)
			end
		end)
	end
	broadcast(t)
end

function Trade.Cancel(player)
	local t = active[player]
	if t then
		close(t, player.DisplayName .. " cancelled the trade")
	end
end

function Trade.Start()
	Players.PlayerRemoving:Connect(function(p)
		pending[p] = nil
		Trade.Cancel(p)
	end)
end

Trade._active = active
Trade._execute = execute
return Trade
