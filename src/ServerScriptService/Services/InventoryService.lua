local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("MapConfig"))
local PartConfig = require(Shared:WaitForChild("PartConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local Net = require(Shared:WaitForChild("Net"))

local Inv = {}
local S

function Inv.Init(hub)
	S = hub
end

function Inv.CarriedTotal(s)
	local n = 0
	for _, v in pairs(s.carried) do
		n = n + v
	end
	return n
end

function Inv.BankedTotal(s)
	local n = 0
	for _, v in pairs(s.data.parts) do
		n = n + v
	end
	return n
end

-- combo tiers: parts picked up in one run without going home
Inv.ComboTiers = { { 7, 3 }, { 4, 2 }, { 2, 1.5 } }
Inv.SpeedBonusSeconds = 40

local function comboMult(picked)
	for _, t in ipairs(Inv.ComboTiers) do
		if picked >= t[1] then
			return t[2]
		end
	end
	return 1
end
Inv.ComboMult = comboMult

-- zone = district the part came from (contracts), force = ignore the backpack limit (hot drops)
function Inv.AddCarried(player, partId, n, zone, force)
	local s = S.Data.Get(player)
	if not s or not s.ready or not PartConfig.Parts[partId] then
		return false
	end
	if not force and Inv.CarriedTotal(s) + n > S.Shop.CarryCap(s) then
		return false
	end
	s.carried[partId] = (s.carried[partId] or 0) + n
	s.carriedZones = s.carriedZones or {}
	s.carriedZones[partId] = s.carriedZones[partId] or {}
	if zone then
		s.carriedZones[partId][zone] = (s.carriedZones[partId][zone] or 0) + n
	end
	s.run = s.run or { picked = 0, mult = 1 }
	if s.run.picked == 0 then
		s.run.firstAt = workspace:GetServerTimeNow()
		s.run.firstClock = os.clock()
	end
	s.run.picked = s.run.picked + n
	s.run.mult = comboMult(s.run.picked)
	S.Data.Push(player)
	return true
end

function Inv.Bank(player)
	local s = S.Data.Get(player)
	if not s or not s.ready then
		return false
	end
	local run = s.run or { picked = 0, mult = 1 }
	local mult = (run.mult or 1) * (run.risk or 1) -- combo x checkpoint risk multiplier
	local moved, bonus = 0, 0
	local rng = Random.new()
	local banked = {}
	for id, n in pairs(s.carried) do
		if n > 0 then
			local extra = math.floor(n * (mult - 1))
			if rng:NextNumber() < n * (mult - 1) - extra then
				extra = extra + 1
			end
			s.data.parts[id] = (s.data.parts[id] or 0) + n + extra
			banked[id] = n
			moved = moved + n
			bonus = bonus + extra
		end
	end
	local zones = s.carriedZones or {}
	s.carried = {}
	s.carriedZones = {}
	s.run = { picked = 0, mult = 1 }
	if moved > 0 then
		local secs = run.firstClock and (os.clock() - run.firstClock) or 999
		local cash = 0
		if secs <= Inv.SpeedBonusSeconds then
			cash = math.max(200, math.floor((s.income or 0) * 15))
			s.data.money = math.min(s.data.money + cash, EconomyConfig.MaxMoney)
		end
		S.Data.Notify(player, "banked2", { moved, bonus, mult, cash }, "good")
		Net.Get("BankFx"):FireClient(player, { moved = moved, bonus = bonus, mult = mult, cash = cash, parts = banked })
		S.Contracts.Progress(player, "bank_part", moved, zones)
		if mult > 1 then
			S.Contracts.Progress(player, "combo", mult)
		end
		S.Contracts.Progress(player, "speed", secs)
		S.Data.Push(player)
	end
	return moved > 0
end

function Inv.HasBanked(s, partId, n)
	return (s.data.parts[partId] or 0) >= n
end

function Inv.SpendBanked(player, partId, n)
	local s = S.Data.Get(player)
	if not s or n <= 0 or (s.data.parts[partId] or 0) < n then
		return false
	end
	s.data.parts[partId] = s.data.parts[partId] - n
	return true
end

function Inv.OnDeath(player)
	local s = S.Data.Get(player)
	if not s or not s.ready then
		return
	end
	s.data.stats.deaths = s.data.stats.deaths + 1
	local lost, lostTable = 0, {}
	for id, n in pairs(s.carried) do
		local l = math.floor(n * EconomyConfig.DeathLossFraction + 0.5)
		if l > 0 then
			s.carried[id] = n - l
			lost = lost + l
			lostTable[id] = l
		end
	end
	s.carriedZones = {}
	s.run = { picked = 0, mult = 1 }
	if lost > 0 then
		s.lastLost = lostTable -- the "Insurance" product can give it back
		S.Data.Notify(player, "lost", { lost }, "error")
	end
	S.Data.Push(player)
end

function Inv.EnsureNotStuck(player)
	local s = S.Data.Get(player)
	if not s or not s.ready then
		return
	end
	local anyCar = #s.data.cars > 0
	if Inv.BankedTotal(s) + Inv.CarriedTotal(s) == 0 and not anyCar and s.data.money < 50 then
		s.data.parts.bolts = (s.data.parts.bolts or 0) + 1
		S.Data.Notify(player, "starter", nil, "good")
		S.Data.Push(player)
	end
end

function Inv.Start()
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in ipairs(Players:GetPlayers()) do
				local s = S.Data.Get(player)
				if s and s.ready and Inv.CarriedTotal(s) > 0 then
					local hrp = S.Data.GetRoot(player)
					if hrp and hrp.Position.Z < MapConfig.PlazaEndZ then
						Inv.Bank(player)
					end
				end
			end
		end
	end)
end

return Inv
