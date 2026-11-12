local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))
local PartConfig = require(Shared:WaitForChild("PartConfig"))
local CarConfig = require(Shared:WaitForChild("CarConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local ShopConfig = require(Shared:WaitForChild("ShopConfig"))
local TuningConfig = require(Shared:WaitForChild("TuningConfig"))
local SkinConfig = require(Shared:WaitForChild("SkinConfig"))

local DataService = {}
local S

local STORE_NAME = "CarHunters_Profiles_v1"
local SCHEMA_VERSION = 4
local LOCK_TIMEOUT = 120
local SERVER_ID = (game.JobId ~= "" and game.JobId) or ("studio-" .. HttpService:GenerateGUID(false))

local store = nil
local sessions = {}

local function newProfile(isNew)
	local p = {
		schemaVersion = SCHEMA_VERSION,
		money = 0,
		parts = { bolts = 0, tire = 0, engine = 0, turbo = 0, core = 0 },
		unlockedZones = { city = true },
		garageSlotCount = EconomyConfig.StartSlots,
		floors = 1,
		cars = {},
		stats = { throws = 0, upgrades = 0, deaths = 0, sold = 0 },
		discovered = {},
		pity = 0,
		saveCount = 0,
		perks = {},
		boosts = {},
		receipts = {},
		contracts = {},
		tuning = {},
		rebirths = 0,
		tokens = 0,
		tokenPerks = {},
		skins = { classic = true },
		skin = "classic",
	}
	if isNew then
		for id, n in pairs(EconomyConfig.StarterParts) do
			p.parts[id] = n
		end
	end
	return p
end

local function toCount(v, maxV)
	if type(v) == "number" and v == v and v >= 0 and v ~= math.huge then
		return math.min(math.floor(v), maxV)
	end
	return 0
end

local function sanitize(raw)
	if type(raw) ~= "table" then
		return newProfile(true)
	end
	local p = newProfile(false)

	p.money = math.min(toCount(raw.money, EconomyConfig.MaxMoney), EconomyConfig.MaxMoney)
	if type(raw.parts) == "table" then
		for id in pairs(PartConfig.Parts) do
			p.parts[id] = toCount(raw.parts[id], 1e6)
		end
	end
	if type(raw.unlockedZones) == "table" then
		for _, id in ipairs(require(Shared.MapConfig).ZoneOrder) do
			if raw.unlockedZones[id] == true then
				p.unlockedZones[id] = true
			end
		end
	end
	p.unlockedZones.city = true
	local slots = toCount(raw.garageSlotCount, EconomyConfig.MaxSlots)
	p.garageSlotCount = Util.Clamp(slots, EconomyConfig.StartSlots, EconomyConfig.MaxSlots)
	-- v4: multi-storey garage, 6 bays per floor (old profiles get the floors their bays need)
	local floors = toCount(raw.floors, EconomyConfig.MaxFloors)
	p.floors = Util.Clamp(math.max(floors, math.ceil(p.garageSlotCount / 6)), 1, EconomyConfig.MaxFloors)

	local seenUid, seenSlot = {}, {}
	if type(raw.cars) == "table" then
		for _, c in ipairs(raw.cars) do
			if #p.cars >= EconomyConfig.MaxCars then
				break
			end
			if type(c) == "table" and CarConfig.LegacyIds[c.typeId] then
				c.typeId = CarConfig.LegacyIds[c.typeId]
			end
			if type(c) == "table" and type(c.uid) == "string" and #c.uid >= 8 and #c.uid <= 64
				and not seenUid[c.uid] and CarConfig.ById[c.typeId] then
				seenUid[c.uid] = true
				local level = Util.Clamp(toCount(c.level, CarConfig.MaxLevel), 1, CarConfig.MaxLevel)
				local slot = nil
				if Util.IsInt(c.parkedSlot) and c.parkedSlot >= 1 and c.parkedSlot <= p.garageSlotCount and not seenSlot[c.parkedSlot] then
					slot = c.parkedSlot
					seenSlot[slot] = true
				end
				local tune = {}
				if type(c.tune) == "table" then
					for cat, itemId in pairs(c.tune) do
						local it = TuningConfig.Items[itemId]
						if it and it.cat == cat then
							tune[cat] = itemId
						end
					end
				end
				table.insert(p.cars, { uid = c.uid, typeId = c.typeId, level = level, parkedSlot = slot, tune = tune })
			end
		end
	end
	if type(raw.stats) == "table" then
		p.stats.throws = toCount(raw.stats.throws, 1e9)
		p.stats.upgrades = toCount(raw.stats.upgrades, 1e9)
		p.stats.deaths = toCount(raw.stats.deaths, 1e9)
		p.stats.sold = toCount(raw.stats.sold, 1e9)
	end
	if type(raw.discovered) == "table" then
		for id, v in pairs(raw.discovered) do
			id = CarConfig.LegacyIds[id] or id
			if v == true and CarConfig.ById[id] then
				p.discovered[id] = true
			end
		end
	end
	for _, c in ipairs(p.cars) do
		p.discovered[c.typeId] = true
	end
	p.pity = math.min(toCount(raw.pity, 1e6), EconomyConfig.PityThreshold)
	p.stats.contracts = type(raw.stats) == "table" and toCount(raw.stats.contracts, 1e9) or 0
	if type(raw.perks) == "table" then
		for _, def in ipairs(ShopConfig.Perks) do
			local v = toCount(raw.perks[def.id], def.max)
			if v > 0 then
				p.perks[def.id] = v
			end
		end
	end
	if type(raw.boosts) == "table" then
		for _, id in ipairs({ "income", "luck" }) do
			local t = toCount(raw.boosts[id], 4e9)
			if t > os.time() then
				p.boosts[id] = t
			end
		end
	end
	if type(raw.receipts) == "table" then
		for _, r in ipairs(raw.receipts) do
			if type(r) == "string" and #r <= 80 and #p.receipts < 100 then
				table.insert(p.receipts, r)
			end
		end
	end
	local KINDS = { bank_part = true, combo = true, speed = true, throw = true, road = true, hotdrop = true }
	if type(raw.contracts) == "table" then
		for _, c in ipairs(raw.contracts) do
			if #p.contracts < 3 and type(c) == "table" and KINDS[c.kind] and type(c.reward) == "table"
				and PartConfig.Parts[c.reward.part] and Util.IsInt(c.n) and c.n >= 1 and c.n <= 20 then
				table.insert(p.contracts, {
					id = tostring(c.id), kind = c.kind, progress = math.min(toCount(c.progress, 20), c.n), n = c.n,
					part = PartConfig.Parts[c.part] and c.part or nil, zone = type(c.zone) == "string" and c.zone or nil,
					mult = tonumber(c.mult), seconds = tonumber(c.seconds), ready = c.ready == true or nil,
					reward = { money = toCount(c.reward.money, 1e12), part = c.reward.part, n = math.clamp(toCount(c.reward.n, 4), 1, 4) },
				})
			end
		end
	end
	if type(raw.tuning) == "table" then
		for id, n in pairs(raw.tuning) do
			if TuningConfig.Items[id] then
				local v = toCount(n, 999)
				if v > 0 then
					p.tuning[id] = v
				end
			end
		end
	end
	p.rebirths = toCount(raw.rebirths, 1000)
	p.tokens = toCount(raw.tokens, 1e6)
	if type(raw.tokenPerks) == "table" then
		for _, def in ipairs(SkinConfig.TokenPerks) do
			local v = toCount(raw.tokenPerks[def.id], def.max)
			if v > 0 then
				p.tokenPerks[def.id] = v
			end
		end
	end
	if type(raw.skins) == "table" then
		for id, v in pairs(raw.skins) do
			if v == true and SkinConfig.ById[id] then
				p.skins[id] = true
			end
		end
	end
	if type(raw.skin) == "string" and SkinConfig.ById[raw.skin] then
		p.skin = raw.skin
	end
	p.saveCount = toCount(raw.saveCount, 1e12)
	return p
end
DataService.Sanitize = sanitize

local function keyFor(userId)
	return "P_" .. tostring(userId)
end

local function acquire(userId)
	local key = keyFor(userId)
	local lastErr = "unknown"
	for attempt = 1, 5 do
		local lockedByOther = false
		local loaded = nil
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(old)
				lockedByOther = false
				loaded = nil
				if type(old) == "table" then
					local lock = old.lock
					if type(lock) == "table" and lock.id ~= SERVER_ID and os.time() - (tonumber(lock.time) or 0) < LOCK_TIMEOUT then
						lockedByOther = true
						return nil
					end
					loaded = old.data
					old.lock = { id = SERVER_ID, time = os.time() }
					return old
				end
				return { lock = { id = SERVER_ID, time = os.time() } }
			end)
		end)
		if ok then
			if lockedByOther then
				lastErr = "locked"
				task.wait(6)
			else
				return true, loaded
			end
		else
			lastErr = tostring(err)
			if RunService:IsStudio() then
				return false, "studio"
			end
			task.wait(math.min(2 ^ attempt, 8))
		end
	end
	return false, lastErr
end

function DataService.Init(hub)
	S = hub
end

function DataService.Start()
	local ok, res = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = res
	else
		warn("[CarHunters] DataStore unavailable:", res)
	end
	task.spawn(function()
		while true do
			task.wait(EconomyConfig.AutosaveInterval)
			for player, s in pairs(sessions) do
				if s.ready and not s.ephemeral and not s.saving then
					task.spawn(DataService.Save, player, false)
				end
			end
		end
	end)
end

function DataService.Get(player)
	return sessions[player]
end

function DataService.GetRoot(player)
	local char = player.Character
	if not char then
		return nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hum and hum.Health > 0 and hrp then
		return hrp, hum
	end
	return nil
end

function DataService.Notify(player, key, args, kind)
	if player.Parent then
		Net.Get("Notify"):FireClient(player, { key = key, args = args or {}, kind = kind or "info" })
	end
end

function DataService.RateLimit(player, key, interval)
	local s = sessions[player]
	if not s then
		return false
	end
	local now = os.clock()
	if now - (s.rl[key] or 0) < interval then
		return false
	end
	s.rl[key] = now
	return true
end

function DataService.Load(player)
	local s = {
		player = player, ready = false, carried = {}, hidden = {}, rl = {}, income = 0, collectionValue = 0,
		moneyFrac = 0, busy = false, protectedUntil = 0, lastHit = 0, baseIndex = nil,
		ephemeral = false, loadFailed = false,
	}
	sessions[player] = s

	if not store then
		s.ephemeral = true
		s.data = newProfile(true)
		DataService.Notify(player, "studioNoSave", nil, "warn")
		return s
	end

	local ok, raw = acquire(player.UserId)
	if ok then
		s.data = sanitize(raw)
		s.locked = true
	elseif raw == "locked" then
		sessions[player] = nil
		player:Kick("Your data is open on another server. Please rejoin in a minute.")
		return nil
	elseif raw == "studio" then
		s.ephemeral = true
		s.data = newProfile(true)
		DataService.Notify(player, "studioNoSave", nil, "warn")
	else
		warn("[CarHunters] Profile load failed for", player.Name, raw)
		s.ephemeral = true
		s.loadFailed = true
		s.data = newProfile(true)
		DataService.Notify(player, "dataFail", nil, "error")
	end
	return s
end

local function snapshot(s, mergeCarried)
	local d = Util.CopyTable(s.data)
	if mergeCarried then
		for id, n in pairs(s.carried) do
			d.parts[id] = (d.parts[id] or 0) + n
		end
	end
	d.schemaVersion = SCHEMA_VERSION
	d.saveCount = (d.saveCount or 0) + 1
	return d
end

function DataService.Save(player, release)
	local s = sessions[player]
	if not s or not s.data or s.ephemeral or not store or not s.locked then
		return false
	end
	local waited = 0
	while s.saving and waited < 10 do
		task.wait(0.1)
		waited = waited + 0.1
	end
	s.saving = true
	local snap = snapshot(s, release)
	local key = keyFor(player.UserId)
	local success = false
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(old)
				if type(old) == "table" and type(old.lock) == "table" and old.lock.id ~= SERVER_ID
					and os.time() - (tonumber(old.lock.time) or 0) < LOCK_TIMEOUT then
					return nil
				end
				local out = { data = snap }
				if not release then
					out.lock = { id = SERVER_ID, time = os.time() }
				end
				return out
			end)
		end)
		if ok then
			success = true
			break
		end
		warn("[CarHunters] Save failed (" .. attempt .. "):", err)
		task.wait(2 ^ attempt)
	end
	s.saving = false
	if success then
		s.data.saveCount = snap.saveCount
	end
	return success
end

function DataService.SaveAll()
	local pending = 0
	for player, s in pairs(sessions) do
		if s.ready and not s.ephemeral then
			pending = pending + 1
			task.spawn(function()
				DataService.Save(player, true)
				pending = pending - 1
			end)
		end
	end
	local t = 0
	while pending > 0 and t < 25 do
		task.wait(0.2)
		t = t + 0.2
	end
end

function DataService.Unload(player)
	sessions[player] = nil
end

function DataService.BuildState(s)
	local d = s.data
	local cars = {}
	for _, c in ipairs(d.cars) do
		table.insert(cars, { uid = c.uid, typeId = c.typeId, level = c.level, slot = c.parkedSlot, tune = Util.CopyTable(c.tune or {}) })
	end
	return {
		money = d.money,
		parts = Util.CopyTable(d.parts),
		carried = Util.CopyTable(s.carried),
		carryCap = S.Shop.CarryCap(s),
		zones = Util.CopyTable(d.unlockedZones),
		slots = d.garageSlotCount,
		floors = d.floors,
		cars = cars,
		stats = Util.CopyTable(d.stats),
		baseIndex = s.baseIndex,
		income = s.income,
		collectionValue = s.collectionValue,
		ephemeral = s.ephemeral,
		discovered = Util.CopyTable(d.discovered),
		pity = d.pity,
		indexMult = s.indexMult or 1,
		perks = Util.CopyTable(d.perks),
		boosts = { income = math.max(0, (d.boosts.income or 0) - os.time()), luck = math.max(0, (d.boosts.luck or 0) - os.time()) },
		passes = Util.CopyTable(s.passes or {}),
		contracts = Util.CopyTable(d.contracts),
		tuning = Util.CopyTable(d.tuning),
		rebirths = d.rebirths,
		tokens = d.tokens,
		tokenPerks = Util.CopyTable(d.tokenPerks),
		skins = Util.CopyTable(d.skins),
		skin = d.skin,
		walkSpeed = S.Shop.WalkSpeed(s),
		pickupRadius = S.Shop.PickupRadius(s),
		airbagIn = S.Shop.AirbagReadyIn(s),
		run = { picked = s.run and s.run.picked or 0, mult = s.run and s.run.mult or 1, firstAt = s.run and s.run.firstAt },
	}
end

function DataService.Push(player)
	local s = sessions[player]
	if not s or s.pushQueued then
		return
	end
	s.pushQueued = true
	task.defer(function()
		s.pushQueued = false
		if player.Parent and s.data then
			Net.Get("StateUpdate"):FireClient(player, DataService.BuildState(s))
		end
	end)
end

return DataService
