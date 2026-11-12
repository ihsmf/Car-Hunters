local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local CarConfig = require(Shared:WaitForChild("CarConfig"))
local Util = require(Shared:WaitForChild("Util"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))

local Income = {}
local S

function Income.Init(hub)
	S = hub
end

function Income.CreateLeaderstats(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local inc = Instance.new("IntValue")
	inc.Name = "Income"
	inc.Parent = ls
	local col = Instance.new("IntValue")
	col.Name = "Collection"
	col.Parent = ls
	ls.Parent = player
end

function Income.Recalc(player)
	local s = S.Data.Get(player)
	if not s or not s.data then
		return
	end
	local inc, value = 0, 0
	for _, c in ipairs(s.data.cars) do
		local def = CarConfig.ById[c.typeId]
		if def then
			value = value + CarConfig.ValueAt(def, c.level)
			if c.parkedSlot then
				inc = inc + CarConfig.CarIncome(c)
			end
		end
	end
	local _, _, _, mult = CarConfig.IndexStats(s.data.discovered or {})
	s.indexMult = mult
	s.income = math.floor(inc * mult * S.Shop.IncomeMult(s) * S.Rebirth.IncomeMult(s) + 0.5)
	s.collectionValue = value
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Income.Value = math.min(inc, 2e9)
		ls.Collection.Value = math.min(value, 2e9)
	end
	S.Base.SetIncomeText(player, "+" .. Util.FormatNumber(s.income) .. "/s")
end

-- offline earnings: a share of income for the time away (capped), paid once on join
Income.OfflineShare = 0.15
Income.OfflineCap = 8 * 3600
function Income.PayOffline(player)
	local s = S.Data.Get(player)
	local d = s and s.data
	if not d or (d.lastSeen or 0) <= 0 then
		return
	end
	local away = os.time() - d.lastSeen
	if away < 120 then
		return
	end
	local secs = math.min(away, Income.OfflineCap)
	local amount = math.floor(secs * (s.income or 0) * Income.OfflineShare)
	if amount <= 0 then
		return
	end
	d.money = math.min(d.money + amount, EconomyConfig.MaxMoney)
	s.offline = { amount = amount, seconds = secs, doubled = false }
	Net.Get("OfflineEarnings"):FireClient(player, { amount = amount, seconds = away, capped = away > Income.OfflineCap })
end

function Income.Start()
	local last = os.clock()
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			local dt = now - last
			last = now
			for _, player in ipairs(Players:GetPlayers()) do
				local s = S.Data.Get(player)
				if s and s.ready then
					s.moneyFrac = s.moneyFrac + s.income * dt
					local whole = math.floor(s.moneyFrac)
					if whole > 0 then
						s.moneyFrac = s.moneyFrac - whole
						s.data.money = math.min(s.data.money + whole, EconomyConfig.MaxMoney)
					end
					Net.Get("MoneySync"):FireClient(player, s.data.money, s.income, s.collectionValue)
				end
			end
		end
	end)
end

return Income
