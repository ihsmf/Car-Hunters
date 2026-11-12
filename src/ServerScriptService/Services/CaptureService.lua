local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local PartConfig = require(Shared:WaitForChild("PartConfig"))
local CarConfig = require(Shared:WaitForChild("CarConfig"))
local BaseLayout = require(Shared:WaitForChild("BaseLayout"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))

local Capture = {}
local S
local rng = Random.new()

function Capture.Init(hub)
	S = hub
end

function Capture.Roll(partId, r1, r2, pity)
	return CarConfig.Roll(partId, pity or 0, r1, r2)
end

local function firstFreeSlot(d)
	local used = {}
	for _, c in ipairs(d.cars) do
		if c.parkedSlot then
			used[c.parkedSlot] = true
		end
	end
	for i = 1, d.garageSlotCount do
		if not used[i] then
			return i
		end
	end
	return nil
end

-- one roll with pity + luck; records discovery. Returns rarity, def, isNew, bonus, pityUsed
local function rollOne(s, partId)
	local d = s.data
	local pityUsed = d.pity >= EconomyConfig.PityThreshold - 1
	local shift = S.Shop.LuckShift(s)
	local r1 = 1 - (1 - rng:NextNumber()) * (1 - shift) -- luck pushes the roll towards rarer cars
	local rarity, def = Capture.Roll(partId, r1, rng:NextNumber(), d.pity)
	if CarConfig.IsHighTier(rarity) then
		d.pity = 0
	else
		d.pity = d.pity + 1
	end
	local isNew = not d.discovered[def.id]
	local bonus = 0
	if isNew then
		d.discovered[def.id] = true
		bonus = CarConfig.DiscoverBonus(def)
		d.money = math.min(d.money + bonus, EconomyConfig.MaxMoney)
	end
	return rarity, def, isNew, bonus, pityUsed
end
Capture.RollOne = rollOne

-- checks shared by single and batch throws; returns the session or nil
local function canThrow(player)
	local s = S.Data.Get(player)
	if not s or not s.ready then
		return nil
	end
	if s.busy then
		S.Data.Notify(player, "trapBusy", nil, "warn")
		return nil
	end
	if not s.baseIndex then
		S.Data.Notify(player, "noBase", nil, "error")
		return nil
	end
	local hrp = S.Data.GetRoot(player)
	if not hrp then
		return nil
	end
	local trap = BaseLayout.ToWorld(s.baseIndex, BaseLayout.TrapLocal)
	local flat = Vector3.new(hrp.Position.X - trap.X, 0, hrp.Position.Z - trap.Z)
	if flat.Magnitude > EconomyConfig.ThrowMaxDistance then
		S.Data.Notify(player, "tooFar", nil, "warn")
		return nil
	end
	return s
end

-- the best copy of a model the player owns (highest level)
local function bestCopy(d, typeId, except)
	local best
	for _, c in ipairs(d.cars) do
		if c.typeId == typeId and c.uid ~= except and (not best or c.level > best.level) then
			best = c
		end
	end
	return best
end

-- counts = { partId = n }, merge = fold duplicates into the owned copy (+1 level up to MergeMaxLevel)
function Capture.ThrowBatch(player, counts, merge)
	if type(counts) ~= "table" or not S.Data.RateLimit(player, "throw", EconomyConfig.ThrowCooldown) then
		return
	end
	local s = canThrow(player)
	if not s then
		return
	end
	local d = s.data
	local plan, total = {}, 0
	for _, id in ipairs(PartConfig.Order) do
		local n = counts[id]
		if n ~= nil then
			if type(n) ~= "number" or n ~= n or n < 0 or n % 1 ~= 0 then
				return
			end
			if n > 0 then
				if not S.Inventory.HasBanked(s, id, n) then
					S.Data.Notify(player, "noPart", nil, "error")
					return
				end
				plan[id] = n
				total = total + n
			end
		end
	end
	if total == 0 or total > EconomyConfig.MaxBatch then
		return
	end
	local limit = EconomyConfig.CatchLimit(S.Shop.Level(s, "multi"))
	if total > limit then
		S.Data.Notify(player, "catchLimit", { limit }, "warn")
		return
	end
	s.busy = true
	local results, anyPity = {}, false
	-- cheap parts first so pity tends to land on the rarer baits
	for _, id in ipairs(PartConfig.Order) do
		local n = plan[id]
		if n then
			S.Inventory.SpendBanked(player, id, n)
			for _ = 1, n do
				local rarity, def, isNew, bonus, pityUsed = rollOne(s, id)
				anyPity = anyPity or pityUsed
				local r = { partId = id, typeId = def.id, rarity = rarity, isNew = isNew, bonus = bonus }
				local copy = not isNew and merge and bestCopy(d, def.id)
				if copy and copy.level < EconomyConfig.MergeMaxLevel then
					copy.level = copy.level + 1
					r.merged = copy.level
				elseif #d.cars < EconomyConfig.MaxCars then
					local uid = HttpService:GenerateGUID(false)
					table.insert(d.cars, { uid = uid, typeId = def.id, level = 1 })
					r.uid = uid
				else
					-- storage full: pay out the car's sell value instead
					local v = CarConfig.SellPrice(def, 1)
					d.money = math.min(d.money + v, EconomyConfig.MaxMoney)
					r.sold = v
				end
				table.insert(results, r)
			end
		end
	end
	d.stats.throws = d.stats.throws + total
	S.Cars.ParkBest(s)
	-- best = rarest, then new, then highest income
	local best, bestKey
	for i, r in ipairs(results) do
		local key = CarConfig.Rarities[r.rarity].index * 1e7 + (r.isNew and 1e6 or 0) + CarConfig.ById[r.typeId].income
		if not bestKey or key > bestKey then
			best, bestKey = i, key
		end
	end
	for _, r in ipairs(results) do
		if r.uid then
			for _, c in ipairs(d.cars) do
				if c.uid == r.uid then
					r.slot = c.parkedSlot
				end
			end
		end
	end
	S.Income.Recalc(player)
	local busyFor = (2.5 + 0.05 * total) * (S.Shop.ThrowCooldown(s) / EconomyConfig.ThrowAnimTime)
	Net.Get("ThrowBatchResult"):FireClient(player, { cars = results, best = best, pityUsed = anyPity, total = total })
	S.Base.RefreshAll(player)
	S.Data.Push(player)
	S.Contracts.Progress(player, "throw", total)
	task.delay(busyFor, function()
		s.busy = false
	end)
end

function Capture.Throw(player, partId)
	if type(partId) ~= "string" or not PartConfig.Parts[partId] then
		return
	end
	local s = S.Data.Get(player)
	if not s or not s.ready then
		return
	end
	if not S.Data.RateLimit(player, "throw", EconomyConfig.ThrowCooldown) then
		return
	end
	if s.busy then
		S.Data.Notify(player, "trapBusy", nil, "warn")
		return
	end
	if not s.baseIndex then
		S.Data.Notify(player, "noBase", nil, "error")
		return
	end
	local hrp = S.Data.GetRoot(player)
	if not hrp then
		return
	end
	local trap = BaseLayout.ToWorld(s.baseIndex, BaseLayout.TrapLocal)
	local flat = Vector3.new(hrp.Position.X - trap.X, 0, hrp.Position.Z - trap.Z)
	if flat.Magnitude > EconomyConfig.ThrowMaxDistance then
		S.Data.Notify(player, "tooFar", nil, "warn")
		return
	end
	local d = s.data
	if #d.cars >= EconomyConfig.MaxCars then
		S.Data.Notify(player, "storageFull", nil, "error")
		return
	end
	if not S.Inventory.HasBanked(s, partId, 1) then
		S.Data.Notify(player, "noPart", nil, "error")
		return
	end

	s.busy = true
	S.Inventory.SpendBanked(player, partId, 1)
	local rarity, def, isNew, bonus, pityUsed = rollOne(s, partId)
	local uid = HttpService:GenerateGUID(false)
	local slot = firstFreeSlot(d)
	table.insert(d.cars, { uid = uid, typeId = def.id, level = 1, parkedSlot = slot })
	d.stats.throws = d.stats.throws + 1
	local animTime = S.Shop.ThrowCooldown(s)
	s.hidden[uid] = os.clock() + animTime + 0.1

	S.Income.Recalc(player)
	Net.Get("ThrowResult"):FireClient(player, {
		partId = partId, typeId = def.id, uid = uid, rarity = rarity, slot = slot,
		animTime = animTime, speed = EconomyConfig.ThrowAnimTime / animTime, isNew = isNew, bonus = bonus, pityUsed = pityUsed,
	})
	S.Data.Push(player)

	S.Contracts.Progress(player, "throw", 1)
	task.delay(animTime + 0.15, function()
		s.busy = false
		s.hidden[uid] = nil
		if player.Parent then
			S.Base.RefreshAll(player)
		end
	end)
end

return Capture
