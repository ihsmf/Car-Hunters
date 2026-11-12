-- Contracts board: three active jobs per player. Finished jobs wait as "ready" until claimed at Big Tony.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("MapConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))

local Contracts = {}
local S
local rng = Random.new()

Contracts.Active = 3

-- part types each district is known for (bank_part contracts ask for these)
local ZONE_PARTS = {
	city = { "bolts", "tire" }, highway = { "tire", "engine" }, industrial = { "engine", "turbo" }, neon = { "turbo", "core" },
}
for _, z in ipairs(MapConfig.ZoneOrder) do
	ZONE_PARTS[z] = ZONE_PARTS[z] or { "turbo", "core" }
end

function Contracts.Init(hub)
	S = hub
end

local function bestZoneIndex(d)
	local idx = 1
	for i, z in ipairs(MapConfig.ZoneOrder) do
		if d.unlockedZones[z] then
			idx = i
		end
	end
	return idx
end

local function rewardFor(s, weight)
	local base = math.max(150, (s.income or 0) * 25) * weight
	local d = s.data
	local partPool = { "tire", "engine", "turbo", "core" }
	local tier = math.clamp(bestZoneIndex(d), 1, 4) -- core is the top reward from the Night district on
	return { money = math.floor(base / 10 + 0.5) * 10, part = partPool[tier], n = (weight >= 2) and 2 or 1 }
end

function Contracts.New(s)
	local d = s.data
	local zi = bestZoneIndex(d)
	local zone = MapConfig.ZoneOrder[rng:NextInteger(1, zi)]
	local kinds = { "bank_part", "bank_part", "combo", "speed", "throw", "road", "hotdrop" }
	local kind = kinds[rng:NextInteger(1, #kinds)]
	-- avoid duplicate kinds on the board
	for _ = 1, 6 do
		local dup = false
		for _, c in ipairs(d.contracts) do
			if c.kind == kind then
				dup = true
			end
		end
		if not dup then
			break
		end
		kind = kinds[rng:NextInteger(1, #kinds)]
	end
	local c = { id = HttpService:GenerateGUID(false), kind = kind, progress = 0 }
	if kind == "bank_part" then
		local pool = ZONE_PARTS[zone]
		c.part = pool[rng:NextInteger(1, #pool)]
		c.zone = zone
		c.n = (c.part == "core") and 1 or rng:NextInteger(2, 4)
		c.reward = rewardFor(s, 1 + c.n * 0.3)
	elseif kind == "combo" then
		c.n = 1
		c.mult = (zi >= 2) and 2 or 1.5
		c.reward = rewardFor(s, 1.6)
	elseif kind == "speed" then
		c.n = 1
		c.seconds = 40
		c.reward = rewardFor(s, 1.4)
	elseif kind == "throw" then
		c.n = rng:NextInteger(3, 6)
		c.reward = rewardFor(s, 1 + c.n * 0.15)
	elseif kind == "road" then
		c.n = rng:NextInteger(1, 3)
		c.reward = rewardFor(s, 1.3 + c.n * 0.4)
	else
		c.n = 1
		c.reward = rewardFor(s, 2.5)
	end
	return c
end

function Contracts.Fill(s)
	local d = s.data
	while #d.contracts < Contracts.Active do
		table.insert(d.contracts, Contracts.New(s))
	end
end

-- paid out by MechanicService when the player talks to Big Tony
function Contracts.Reward(player, s, c, index)
	local d = s.data
	local mult = S.Shop.HasPass(s, "double_contracts") and 2 or 1
	d.money = math.min(d.money + c.reward.money * mult, EconomyConfig.MaxMoney)
	d.parts[c.reward.part] = (d.parts[c.reward.part] or 0) + c.reward.n * mult
	d.stats.contracts = (d.stats.contracts or 0) + 1
	table.remove(d.contracts, index)
	S.Data.Notify(player, "contractDone", { c.reward.money * mult }, "good")
	S.Data.Push(player)
	task.delay(3, function()
		if player.Parent and S.Data.Get(player) == s then
			Contracts.Fill(s)
			S.Data.Push(player)
		end
	end)
end

-- event: "bank_part"(partId, n, zoneCounts) | "combo"(mult) | "speed"(seconds) | "throw" | "road" | "hotdrop"
function Contracts.Progress(player, event, amount, extra)
	local s = S.Data.Get(player)
	if not s or not s.ready then
		return
	end
	local d = s.data
	local changed = false
	for i = #d.contracts, 1, -1 do
		local c = d.contracts[i]
		local add = 0
		if c.kind == event then
			if event == "bank_part" then
				-- extra = { [partId] = { [zone] = n } }
				local byZone = extra and extra[c.part]
				add = byZone and (byZone[c.zone] or 0) or 0
			elseif event == "combo" then
				add = (amount >= c.mult) and 1 or 0
			elseif event == "speed" then
				add = (amount <= c.seconds) and 1 or 0
			else
				add = amount or 1
			end
		end
		if add > 0 and not c.ready then
			c.progress = math.min(c.n, c.progress + add)
			changed = true
			if c.progress >= c.n then
				c.ready = true
				S.Data.Notify(player, "contractReady", nil, "good")
			end
		end
	end
	if changed then
		S.Data.Push(player)
	end
end

function Contracts.Start()
	Players.PlayerAdded:Connect(function(p)
		task.delay(2, function()
			local s = S.Data.Get(p)
			if s and s.data then
				Contracts.Fill(s)
				S.Data.Push(p)
			end
		end)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		local s = S.Data.Get(p)
		if s and s.data then
			Contracts.Fill(s)
		end
	end
end

return Contracts
