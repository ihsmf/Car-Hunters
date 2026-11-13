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

function Capture.Roll(points, r1, r2, pity)
	return CarConfig.RollPoints(points, pity or 0, r1, r2)
end

-- one car from a throw worth `points`, with pity + luck; records discovery. Returns rarity, def, isNew, bonus, pityUsed
local function rollOne(s, points)
	local d = s.data
	local pityUsed = d.pity >= EconomyConfig.PityThreshold - 1
	local shift = S.Shop.LuckShift(s)
	local r1 = 1 - (1 - rng:NextNumber()) * (1 - shift) -- luck pushes the roll towards rarer cars
	local rarity, def = Capture.Roll(points, r1, rng:NextNumber(), d.pity)
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
	if total == 0 then
		return
	end
	if total > EconomyConfig.MaxBatch then
		S.Data.Notify(player, "noPart", nil, "error")
		return
	end
	-- every part adds its rarity points; the throw catches `cars` cars (Multi Catch), each rolled on those points
	local points, bestPart = 0, nil
	for _, id in ipairs(PartConfig.Order) do
		if plan[id] then
			points = points + plan[id] * PartConfig.Parts[id].points
			bestPart = id
		end
	end
	local cars = EconomyConfig.CatchLimit(S.Shop.Level(s, "multi"))
	s.busy = true
	local results, anyPity = {}, false
	for id, n in pairs(plan) do
		S.Inventory.SpendBanked(player, id, n)
	end
	for _ = 1, cars do
		local rarity, def, isNew, bonus, pityUsed = rollOne(s, points)
		anyPity = anyPity or pityUsed
		local r = { partId = bestPart, typeId = def.id, rarity = rarity, isNew = isNew, bonus = bonus }
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
	local animTime = S.Shop.ThrowCooldown(s)
	local single = #results == 1 and results[1].uid ~= nil
	local busyFor = single and animTime + 0.15 or (2.5 + 0.3 * #results) * (animTime / EconomyConfig.ThrowAnimTime)
	if single then
		-- one new car: the full cinematic (merged / sold results go to the batch reveal, which shows them) (part flies in, blackout reveal, drive-in); the real car stays hidden meanwhile
		local r = results[1]
		if r.uid then
			s.hidden[r.uid] = os.clock() + animTime + 0.1
			task.delay(animTime + 0.15, function()
				s.hidden[r.uid] = nil
				if player.Parent then
					S.Base.RefreshAll(player)
				end
			end)
		end
		Net.Get("ThrowResult"):FireClient(player, {
			partId = r.partId, typeId = r.typeId, uid = r.uid, rarity = r.rarity, slot = r.slot, isNew = r.isNew, bonus = r.bonus,
			merged = r.merged, sold = r.sold, pityUsed = anyPity, points = points, parts = total,
			animTime = animTime, speed = EconomyConfig.ThrowAnimTime / animTime,
		})
	else
		Net.Get("ThrowBatchResult"):FireClient(player, { cars = results, best = best, pityUsed = anyPity, total = total, points = points })
	end
	S.Base.RefreshAll(player)
	S.Data.Push(player)
	S.Contracts.Progress(player, "throw", total)
	local caught = {}
	for _, r in ipairs(results) do
		table.insert(caught, r.rarity)
	end
	S.Contracts.Progress(player, "catch", #caught, caught)
	task.delay(busyFor, function()
		s.busy = false
	end)
end

-- legacy single-part remote: the same as a one-part batch
function Capture.Throw(player, partId)
	if type(partId) == "string" and PartConfig.Parts[partId] then
		Capture.ThrowBatch(player, { [partId] = 1 }, true)
	end
end

return Capture
