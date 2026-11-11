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
local boardLabel

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
				inc = inc + CarConfig.IncomeAt(def, c.level)
			end
		end
	end
	local _, _, _, mult = CarConfig.IndexStats(s.data.discovered or {})
	s.indexMult = mult
	s.income = math.floor(inc * mult + 0.5)
	s.collectionValue = value
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Income.Value = math.min(inc, 2e9)
		ls.Collection.Value = math.min(value, 2e9)
	end
	S.Base.SetIncomeText(player, "+" .. Util.FormatNumber(s.income) .. "/s")
end

function Income.Start()
	local map = Workspace:FindFirstChild("GeneratedMap")
	local board = map and map:FindFirstChild("Leaderboard", true)
	if board then
		local gui = board:FindFirstChildWhichIsA("SurfaceGui", true)
		boardLabel = gui and gui:FindFirstChild("Rows")
	end
	local last = os.clock()
	local boardTimer = 0
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			local dt = now - last
			last = now
			boardTimer = boardTimer + dt
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
			if boardTimer >= 4 and boardLabel then
				boardTimer = 0
				local rows = {}
				for _, player in ipairs(Players:GetPlayers()) do
					local s = S.Data.Get(player)
					if s and s.ready then
						table.insert(rows, { name = player.DisplayName, inc = s.income })
					end
				end
				table.sort(rows, function(a, b)
					return a.inc > b.inc
				end)
				local lines = {}
				for i = 1, math.min(8, #rows) do
					table.insert(lines, string.format("%d. %s  +%s/s", i, rows[i].name, Util.FormatNumber(rows[i].inc)))
				end
				boardLabel.Text = table.concat(lines, "\n")
			end
		end
	end)
end

return Income
