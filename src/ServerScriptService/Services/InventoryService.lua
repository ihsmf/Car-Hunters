local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("MapConfig"))
local PartConfig = require(Shared:WaitForChild("PartConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))

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

function Inv.AddCarried(player, partId, n)
	local s = S.Data.Get(player)
	if not s or not s.ready or not PartConfig.Parts[partId] then
		return false
	end
	if Inv.CarriedTotal(s) + n > EconomyConfig.CarryCapacity then
		return false
	end
	s.carried[partId] = (s.carried[partId] or 0) + n
	S.Data.Push(player)
	return true
end

function Inv.Bank(player)
	local s = S.Data.Get(player)
	if not s or not s.ready then
		return false
	end
	local moved = 0
	for id, n in pairs(s.carried) do
		if n > 0 then
			s.data.parts[id] = (s.data.parts[id] or 0) + n
			moved = moved + n
		end
	end
	s.carried = {}
	if moved > 0 then
		S.Data.Notify(player, "banked", nil, "good")
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
	local lost = 0
	for id, n in pairs(s.carried) do
		local l = math.floor(n * EconomyConfig.DeathLossFraction + 0.5)
		if l > 0 then
			s.carried[id] = n - l
			lost = lost + l
		end
	end
	if lost > 0 then
		S.Data.Notify(player, "lost", { lost }, "error")
		S.Data.Push(player)
	end
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
