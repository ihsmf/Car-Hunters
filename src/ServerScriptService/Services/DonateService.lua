-- Golden Magnate stall: developer products + game passes, with idempotent receipt processing.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DonateConfig = require(Shared:WaitForChild("DonateConfig"))
local ProductIds = require(Shared:WaitForChild("ProductIds"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local Net = require(Shared:WaitForChild("Net"))

local Donate = {}
local S
local byProductId, byPassId = {}, {}

function Donate.Init(hub)
	S = hub
	for key, id in pairs(ProductIds.products) do
		if id and id > 0 then
			byProductId[id] = key
		end
	end
	for key, id in pairs(ProductIds.passes) do
		if id and id > 0 then
			byPassId[id] = key
		end
	end
end

local function hasReceipt(d, rid)
	for _, r in ipairs(d.receipts) do
		if r == rid then
			return true
		end
	end
	return false
end

local function remember(d, rid)
	table.insert(d.receipts, rid)
	while #d.receipts > 100 do
		table.remove(d.receipts, 1)
	end
end

local function grantGoldenCar(player, s)
	local d = s.data
	for _, c in ipairs(d.cars) do
		if c.typeId == "golden_magnat_gt" then
			return
		end
	end
	table.insert(d.cars, { uid = HttpService:GenerateGUID(false), typeId = "golden_magnat_gt", level = 1, parkedSlot = nil })
	d.discovered.golden_magnat_gt = true
	-- park it right away wherever the player is (AutoPark would demand being next to the garage)
	S.Cars.ParkBest(s)
	S.Base.RefreshAll(player)
	S.Income.Recalc(player)
	S.Data.Push(player)
end

-- applies one product; returns true when granted
function Donate.Grant(player, key)
	local s = S.Data.Get(player)
	local item = DonateConfig.ById[key]
	if not s or not s.ready or not item then
		return false
	end
	local d = s.data
	if item.boost then
		local now = os.time()
		d.boosts[item.boost] = math.max(d.boosts[item.boost] or 0, now) + item.seconds
	elseif item.cash then
		local amount = math.max(item.cash[2], math.floor(S.Income.RefIncome(s) * item.cash[1]))
		d.money = math.min(d.money + amount, EconomyConfig.MaxMoney)
	elseif item.parts then
		for id, n in pairs(item.parts) do
			d.parts[id] = (d.parts[id] or 0) + n
		end
	elseif item.slots then
		local before = d.garageSlotCount
		d.garageSlotCount = math.min(d.floors * 6, before + item.slots)
		local missing = item.slots - (d.garageSlotCount - before)
		if missing > 0 then -- already maxed: pay it out instead
			d.money = math.min(d.money + missing * math.max(50000, S.Income.RefIncome(s) * 600), EconomyConfig.MaxMoney)
		end
	elseif key == "offline_x2" then
		local off = s.offline
		if off and not off.doubled then
			off.doubled = true
			d.money = math.min(d.money + off.amount, EconomyConfig.MaxMoney)
		else
			d.money = math.min(d.money + math.max(5000, S.Income.RefIncome(s) * 600), EconomyConfig.MaxMoney)
		end
	elseif key == "pity" then
		d.pity = math.max(d.pity, EconomyConfig.PityThreshold - 1)
	elseif key == "hotdrop" then
		S.HotDrop.SpawnFor(player)
	elseif key == "revive" then
		local lost = s.lastLost
		if lost then
			for id, n in pairs(lost) do
				d.parts[id] = (d.parts[id] or 0) + n
			end
			s.lastLost = nil
		else
			d.parts.engine = (d.parts.engine or 0) + 2 -- nothing to restore: small consolation crate
		end
	end
	S.Income.Recalc(player)
	S.Base.RefreshAll(player)
	S.Data.Notify(player, "donateThanks", { item.name }, "good")
	Net.Get("DonateFx"):FireAllClients(player, key)
	S.Data.Push(player)
	return true
end

local function processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local key = byProductId[info.ProductId]
	if not player or not key then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local s = S.Data.Get(player)
	if not s or not s.ready then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local d = s.data
	if hasReceipt(d, info.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if not Donate.Grant(player, key) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	remember(d, info.PurchaseId)
	if s.ephemeral then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	-- the receipt id is in the profile: a retry after a failed save will not grant twice
	if S.Data.Save(player, false) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function refreshPasses(player)
	local s = S.Data.Get(player)
	if not s then
		return
	end
	s.passes = s.passes or {}
	for key, id in pairs(ProductIds.passes) do
		if id > 0 and not s.passes[key] then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
			if ok and owns then
				s.passes[key] = true
			end
		end
	end
	if s.passes.golden_car then
		grantGoldenCar(player, s)
	end
	player:SetAttribute("VIP", s.passes.vip == true)
	S.Income.Recalc(player)
	S.Shop.ApplyCharacter(player)
	S.Data.Push(player)
end
Donate.RefreshPasses = refreshPasses

function Donate.Request(player, key)
	local item = type(key) == "string" and DonateConfig.ById[key]
	if not item or not S.Data.RateLimit(player, "donate", 1) then
		return
	end
	if item.random then
		local ok, info = pcall(function()
			return game:GetService("PolicyService"):GetPolicyInfoForPlayerAsync(player)
		end)
		if not ok or not info or info.ArePaidRandomItemsRestricted then
			S.Data.Notify(player, "donateOff", nil, "warn")
			return
		end
	end
	local id = item.isPass and ProductIds.passes[key] or ProductIds.products[key]
	if id and id > 0 then
		if item.isPass then
			MarketplaceService:PromptGamePassPurchase(player, id)
		else
			MarketplaceService:PromptProductPurchase(player, id)
		end
	elseif RunService:IsStudio() then
		-- products are not created yet: simulate the purchase so everything can be tested in Studio
		local s = S.Data.Get(player)
		if item.isPass then
			if s then
				s.passes = s.passes or {}
				s.passes[key] = true
				refreshPasses(player)
				S.Data.Notify(player, "donateThanks", { item.name }, "good")
				Net.Get("DonateFx"):FireAllClients(player, key)
			end
		else
			Donate.Grant(player, key)
		end
	else
		S.Data.Notify(player, "donateOff", nil, "warn")
	end
end

function Donate.Start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
		local key = byPassId[passId]
		local s = S.Data.Get(player)
		if bought and key and s then
			s.passes = s.passes or {}
			s.passes[key] = true
			refreshPasses(player)
			S.Data.Notify(player, "donateThanks", { DonateConfig.ById[key].name }, "good")
			Net.Get("DonateFx"):FireAllClients(player, key)
		end
	end)
	-- boosts expire: keep income in sync
	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.time()
			for _, player in ipairs(Players:GetPlayers()) do
				local s = S.Data.Get(player)
				if s and s.ready then
					local active = {}
					for id, t in pairs(s.data.boosts) do
						if t > now then
							active[id] = true
						end
					end
					local sig = (active.income and "i" or "") .. (active.luck and "l" or "")
					if sig ~= (s.boostSig or "") then
						s.boostSig = sig
						S.Income.Recalc(player)
						S.Data.Push(player)
					end
				end
			end
		end
	end)
	task.spawn(function()
		local map = Workspace:WaitForChild("GeneratedMap", 60)
		local stall = map and map:FindFirstChild("MagnateStall", true)
		if not stall then
			return
		end
		local prompt = stall:FindFirstChild("DonatePrompt")
		if prompt then
			local pp = Instance.new("ProximityPrompt")
			pp.ActionText = "Shop"
			pp.ObjectText = "Golden Magnate"
			pp.HoldDuration = 0
			pp.MaxActivationDistance = 14
			pp.RequiresLineOfSight = false
			pp.Parent = prompt
		end
		local spot = stall:FindFirstChild("NpcSpot")
		if not spot then
			return
		end
		local GOLD = Color3.fromRGB(232, 178, 50)
		local npc, anims = S.Shop.MakeNpc("GoldenMagnate", {
			skin = Color3.fromRGB(240, 196, 160), arms = GOLD, torso = GOLD, legs = Color3.fromRGB(30, 30, 36),
		}, spot, function(n)
			local CYL = Enum.PartType.Cylinder
			local UP = CFrame.Angles(0, 0, math.pi / 2)
			S.Shop.Attach(n, "Head", Vector3.new(0.12, 1.8, 1.8), CFrame.new(0, 0.62, 0) * UP, Color3.fromRGB(20, 20, 24), Enum.Material.SmoothPlastic, CYL)
			S.Shop.Attach(n, "Head", Vector3.new(1.3, 1.15, 1.15), CFrame.new(0, 1.2, 0) * UP, Color3.fromRGB(20, 20, 24), Enum.Material.SmoothPlastic, CYL)
			S.Shop.Attach(n, "Head", Vector3.new(0.3, 1.18, 1.18), CFrame.new(0, 0.85, 0) * UP, GOLD, Enum.Material.Metal, CYL)
			S.Shop.Attach(n, "Head", Vector3.new(0.9, 0.2, 0.1), CFrame.new(0, -0.15, -0.6), Color3.fromRGB(240, 240, 240))
			S.Shop.Attach(n, "UpperTorso", Vector3.new(0.35, 0.35, 0.1), CFrame.new(0, 0.3, -0.55), Color3.fromRGB(200, 30, 40))
			local cane = S.Shop.Attach(n, "RightHand", Vector3.new(0.2, 3.4, 0.2), CFrame.new(0, -1.5, 0), Color3.fromRGB(30, 30, 34), Enum.Material.Metal)
			if cane then
				cane.Name = "Cane"
			end
			S.Shop.Attach(n, "RightHand", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 0.2, 0), GOLD, Enum.Material.Metal, Enum.PartType.Ball)
		end)
		if npc then
			npc:SetAttribute("Magnate", true)
			-- the coin toss and sparkle are animated on the clients (MagnateFx); server just cheers now and then
			task.spawn(function()
				while npc.Parent do
					task.wait(9 + math.random() * 5)
					if anims and anims.wave then
						anims.wave:Play()
					end
				end
			end)
		end
	end)
	Players.PlayerAdded:Connect(function(p)
		task.delay(3, refreshPasses, p)
	end)
end

return Donate
