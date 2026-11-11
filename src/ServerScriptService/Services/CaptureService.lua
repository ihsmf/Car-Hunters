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
