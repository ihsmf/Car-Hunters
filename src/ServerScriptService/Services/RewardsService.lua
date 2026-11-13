-- Daily streak + playtime chests. Everything is decided on the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local R = require(Shared:WaitForChild("RewardConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local TuningConfig = require(Shared:WaitForChild("TuningConfig"))

local Rewards = {}
local S

function Rewards.Init(hub)
	S = hub
end

local function give(player, s, entry)
	local d = s.data
	local cash = R.Money(entry, S.Income.RefIncome(s))
	d.money = math.min(d.money + cash, EconomyConfig.MaxMoney)
	for id, n in pairs(entry.parts or {}) do
		d.parts[id] = (d.parts[id] or 0) + n
	end
	if entry.pity then
		d.pity = math.max(d.pity, EconomyConfig.PityThreshold - 1)
	end
	if entry.tuning then
		local fams = { "ecu", "exhaust", "intake", "tires", "aero" }
		local item = fams[math.random(1, #fams)] .. "1"
		d.tuning[item] = (d.tuning[item] or 0) + 1
		S.Data.Notify(player, "tuneDrop", { TuningConfig.Items[item].name }, "good")
	end
	return cash
end

function Rewards.ClaimDaily(player)
	local s = S.Data.Get(player)
	if not s or not s.ready or not S.Data.RateLimit(player, "daily", 1) then
		return
	end
	local d = s.data
	local today = R.UtcDay()
	if d.daily.last == today then
		return
	end
	local day = R.NextDay(d.daily, today)
	d.daily = { day = day, last = today }
	local cash = give(player, s, R.Daily[day])
	S.Data.Notify(player, "dailyClaimed", { day, cash }, "good")
	S.Data.Push(player)
end

function Rewards.ClaimChest(player, i)
	local s = S.Data.Get(player)
	local entry = type(i) == "number" and R.Chests[i]
	if not s or not s.ready or not entry or not S.Data.RateLimit(player, "chest", 0.5) then
		return
	end
	local played = S.Data.PlayTime(s) -- today's playtime, saved across rejoins
	local chests = s.data.play.chests
	if chests[i] or played < entry.minutes * 60 then
		return
	end
	chests[i] = true
	local cash = give(player, s, entry)
	S.Data.Notify(player, "chestClaimed", { entry.minutes, cash }, "good")
	S.Data.Push(player)
end

return Rewards
