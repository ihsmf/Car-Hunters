local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.Shared.Config)
local Map = require(script.Parent.Map).Build()

local store = DataStoreService:GetDataStore("BilliardV1")
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local Request = Instance.new("RemoteFunction", remotes)
Request.Name = "Request"
local Fx = Instance.new("RemoteEvent", remotes)
Fx.Name = "Fx"
remotes.Parent = RS

local sessions = {} -- player -> {d, slot, passes, join, claimed, lastThrow, lastLift}
local taken = {} -- slot -> player
local luckShift = 0
local rng = Random.new()
local N = #C.Rarities

local function default()
	return { cash = 0, strength = 0, dumbLevel = 1, cue = 1, cues = { ["1"] = true }, cueLevel = 1, inv = {}, daily = { day = 0, streak = 0 } }
end

local function income(s)
	local sum = 0
	for _, it in s.d.inv do
		if it.eq then sum += C.Characters[it.id].income end
	end
	return sum * (s.passes.Cash2x and 2 or 1) * (s.passes.GoldStick and 1.5 or 1)
end

local function sync(plr)
	local s = sessions[plr]
	s.d.passes = s.passes
	Fx:FireClient(plr, "State", { d = s.d, slot = s.slot, income = income(s), luck = luckShift, join = s.join, claimed = s.claimed })
	plr.leaderstats.Cash.Value = math.floor(s.d.cash)
end

-- NPC персонаж с палкой и аурой
local function makeNPC(id, cf, gold)
	local info, r = C.Characters[id], C.Rarities[C.Characters[id].rarity]
	local desc = Instance.new("HumanoidDescription")
	desc.TorsoColor, desc.LeftArmColor, desc.RightArmColor = info.shirt, info.shirt, info.shirt
	desc.HeadColor, desc.LeftLegColor, desc.RightLegColor = Color3.fromRGB(255, 210, 170), Color3.fromRGB(255, 210, 170), r[2]:Lerp(Color3.new(0, 0, 0), 0.4)
	local k = 1 + info.rarity * 0.012
	desc.HeightScale, desc.WidthScale, desc.DepthScale, desc.HeadScale = k, k, k, k
	local m = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	m.Name = info.name
	m.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	m.HumanoidRootPart.Anchored = true
	m:PivotTo(cf * CFrame.new(0, 3, 0))

	local stick = Instance.new("Part")
	stick.Shape, stick.Size, stick.CanCollide, stick.Massless = Enum.PartType.Cylinder, Vector3.new(7, 0.3, 0.3), false, true
	stick.Color = gold and Color3.fromRGB(255, 200, 40) or Color3.fromRGB(160, 110, 60)
	stick.Material = gold and Enum.Material.Neon or Enum.Material.Wood
	local hand = m:FindFirstChild("RightHand")
	stick.CFrame = hand.CFrame * CFrame.Angles(0, math.rad(90), math.rad(75))
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1, w.Parent = hand, stick, stick
	stick.Parent = m

	local aura = Instance.new("ParticleEmitter")
	aura.Color = ColorSequence.new(r[2])
	aura.LightEmission, aura.Rate, aura.Lifetime = 0.8, 10 + info.rarity * 4, NumberRange.new(1, 1.6)
	aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4 + info.rarity * 0.12), NumberSequenceKeypoint.new(1, 0) })
	aura.Speed, aura.SpreadAngle = NumberRange.new(1, 3), Vector2.new(180, 180)
	aura.Transparency = NumberSequence.new(0.3, 1)
	aura.Parent = m.HumanoidRootPart
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = r[2], 8 + info.rarity, 1.5
	light.Parent = m.HumanoidRootPart

	-- корона с 8-й редкости, нимб с 15-й
	local function attach(p)
		p.Anchored, p.CanCollide, p.Massless = false, false, true
		local wc = Instance.new("WeldConstraint")
		wc.Part0, wc.Part1, wc.Parent = m.Head, p, p
		p.Parent = m
	end
	if info.rarity >= 8 then
		local crown = Instance.new("Part")
		crown.Shape, crown.Size, crown.Color, crown.Material = Enum.PartType.Cylinder, Vector3.new(0.5, 1.3, 1.3), Color3.fromRGB(255, 200, 40), Enum.Material.Metal
		crown.CFrame = m.Head.CFrame * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.pi / 2)
		attach(crown)
	end
	if info.rarity >= 15 then
		local halo = Instance.new("Part")
		halo.Shape, halo.Size, halo.Color, halo.Material = Enum.PartType.Cylinder, Vector3.new(0.15, 2, 2), r[2], Enum.Material.Neon
		halo.CFrame = m.Head.CFrame * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.pi / 2)
		attach(halo)
	end

	local bb = Instance.new("BillboardGui")
	bb.Size, bb.StudsOffset, bb.AlwaysOnTop, bb.MaxDistance = UDim2.fromOffset(180, 60), Vector3.new(0, 3.5, 0), true, 80
	for i, t in { { info.name, Color3.new(1, 1, 1) }, { r[1] .. " • 💵" .. C.Short(info.income) .. "/с", r[2] } } do
		local l = Instance.new("TextLabel")
		l.Size, l.Position, l.BackgroundTransparency = UDim2.fromScale(1, 0.5), UDim2.fromScale(0, (i - 1) * 0.5), 1
		l.FontFace, l.TextScaled, l.Text, l.TextColor3 = C.UI.Font, true, t[1], t[2]
		Instance.new("UIStroke", l).Thickness = 2
		l.Parent = bb
	end
	bb.Parent = m.Head
	return m
end

local function refreshBase(plr)
	local s = sessions[plr]
	if not s then return end
	local base = Map.Bases[s.slot]
	base.chars:ClearAllChildren()
	local i = 0
	for _, it in s.d.inv do
		if it.eq and i < C.MaxEquipped then
			i += 1
			makeNPC(it.id, base.slots[i], s.passes.GoldStick).Parent = base.chars
		end
	end
end

local function equippedCount(d)
	local n = 0
	for _, it in d.inv do if it.eq then n += 1 end end
	return n
end

-- Действия игрока
local actions = {}

function actions.Throw(plr, s, power)
	if type(power) ~= "number" or os.clock() < s.nextThrow then return end
	if #s.d.inv >= C.MaxInventory then return false, "Инвентарь полон!" end
	local dist = C.Distance(math.clamp(power, 0, 1), s.d)
	s.nextThrow = os.clock() + C.ThrowTime(dist) + C.ThrowCooldown
	local zone = math.clamp(math.ceil(dist / (C.Table.Length / N)), 1, N)
	local rarity = math.min(zone + luckShift + ((s.passes.Luck2x and rng:NextNumber() < 0.5) and 1 or 0), N)
	local pool = {}
	for id, ch in C.Characters do if ch.rarity == rarity then table.insert(pool, id) end end
	local id = pool[rng:NextInteger(1, #pool)]
	table.insert(s.d.inv, { id = id, eq = equippedCount(s.d) < C.MaxEquipped })
	Fx:FireAllClients("Throw", s.slot, dist, id)
	task.delay(C.ThrowTime(dist), refreshBase, plr)
	return true
end

function actions.Lift(plr, s)
	if os.clock() - s.lastLift < 0.35 then return end
	s.lastLift = os.clock()
	s.d.strength += s.d.dumbLevel
	return true
end

local function pay(s, cost)
	if s.d.cash < cost then return false end
	s.d.cash -= cost
	return true
end

function actions.UpDumb(_, s)
	if not pay(s, C.LiftCost(s.d.dumbLevel)) then return false, "Не хватает денег!" end
	s.d.dumbLevel += 1
	return true
end

function actions.UpCue(_, s)
	if not pay(s, C.CueUpCost(s.d.cueLevel)) then return false, "Не хватает денег!" end
	s.d.cueLevel += 1
	return true
end

function actions.Cue(_, s, i)
	local cue = C.Cues[i]
	if not cue then return end
	if not s.d.cues[tostring(i)] then
		if not pay(s, cue[3]) then return false, "Не хватает денег!" end
		s.d.cues[tostring(i)] = true
	end
	s.d.cue = i
	return true
end

function actions.Equip(plr, s, i)
	local it = s.d.inv[i]
	if not it then return end
	if not it.eq and equippedCount(s.d) >= C.MaxEquipped then return false, "Все места на базе заняты!" end
	it.eq = not it.eq
	refreshBase(plr)
	return true
end

function actions.Sell(plr, s, i)
	local it = s.d.inv[i]
	if not it then return end
	s.d.cash += C.Characters[it.id].income * 30
	table.remove(s.d.inv, i)
	if it.eq then refreshBase(plr) end
	return true
end

function actions.Daily(_, s)
	local day = os.time() // 86400
	local dd = s.d.daily
	if dd.day == day then return false, "Приходи завтра!" end
	dd.streak = (dd.day == day - 1) and dd.streak % #C.Daily + 1 or 1
	dd.day = day
	s.d.cash += C.Daily[dd.streak]
	return true, "+" .. C.Short(C.Daily[dd.streak]) .. " 💵"
end

function actions.Playtime(_, s, i)
	local p = C.Playtime[i]
	if not p or s.claimed[i] or os.time() - s.join < p[1] * 60 then return false, "Ещё рано!" end
	s.claimed[i] = true
	s.d.cash += p[2]
	return true, "+" .. C.Short(p[2]) .. " 💵"
end

function actions.Pass(plr, _, key)
	local gp = C.GamePasses[key]
	if gp and gp.id > 0 then MarketplaceService:PromptGamePassPurchase(plr, gp.id) end
end

function actions.Product(plr, _, i)
	local p = C.Products[i]
	if p and p.id > 0 then MarketplaceService:PromptProductPurchase(plr, p.id) end
end

Request.OnServerInvoke = function(plr, action, arg)
	local s, fn = sessions[plr], actions[action]
	if not (s and fn) then return false end
	local ok, msg = fn(plr, s, arg)
	sync(plr)
	return ok, msg
end

-- Игроки
Players.PlayerAdded:Connect(function(plr)
	local slot
	for i = 1, #Map.Bases do
		if not taken[i] then slot = i break end
	end
	if not slot then plr:Kick("Сервер заполнен") return end
	taken[slot] = plr

	local ok, saved = pcall(store.GetAsync, store, plr.UserId)
	local d = default()
	if ok and saved then for k, v in saved do d[k] = v end end
	local passes = {}
	for key, gp in C.GamePasses do
		if gp.id > 0 then
			local ok2, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, plr.UserId, gp.id)
			passes[key] = ok2 and owns
		end
	end
	if not plr.Parent then taken[slot] = nil return end
	sessions[plr] = { d = d, slot = slot, passes = passes, join = os.time(), claimed = {}, nextThrow = 0, lastLift = 0, loaded = ok }

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	Instance.new("NumberValue", ls).Name = "Cash"
	ls.Parent = plr
	Map.Bases[slot].sign.Text = "База " .. plr.DisplayName

	local function onChar(char)
		task.wait()
		char:PivotTo(Map.Bases[slot].spawn * CFrame.new(0, 3, 0))
	end
	plr.CharacterAdded:Connect(onChar)
	if plr.Character then onChar(plr.Character) end
	refreshBase(plr)
	sync(plr)
end)

local function save(plr)
	local s = sessions[plr]
	if s and s.loaded then
		s.d.passes = nil
		pcall(store.SetAsync, store, plr.UserId, s.d)
	end
end

Players.PlayerRemoving:Connect(function(plr)
	save(plr)
	local s = sessions[plr]
	if s then
		local base = Map.Bases[s.slot]
		base.chars:ClearAllChildren()
		base.sign.Text = "Свободная база"
		taken[s.slot] = nil
	end
	sessions[plr] = nil
end)

game:BindToClose(function()
	for plr in sessions do save(plr) end
end)

for _, base in Map.Bases do
	base.dumbPrompt.Triggered:Connect(function(plr) Fx:FireClient(plr, "Lift") end)
	base.shopPrompt.Triggered:Connect(function(plr) Fx:FireClient(plr, "Open", "Cues") end)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, id, bought)
	local s = sessions[plr]
	if not (s and bought) then return end
	for key, gp in C.GamePasses do if gp.id == id then s.passes[key] = true end end
	refreshBase(plr)
	sync(plr)
end)

MarketplaceService.ProcessReceipt = function(info)
	local plr = Players:GetPlayerByUserId(info.PlayerId)
	local s = plr and sessions[plr]
	if not s then return Enum.ProductPurchaseDecision.NotProcessedYet end
	for _, p in C.Products do
		if p.id == info.ProductId then s.d.cash += p.cash end
	end
	save(plr)
	sync(plr)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Смена редкостей длинного стола
local function paintZones()
	for i, z in Map.Zones do
		local r = C.Rarities[math.min(i + luckShift, N)]
		z.felt.Color = r[2]:Lerp(Color3.fromRGB(20, 120, 60), 0.35)
		z.text.Text, z.text.TextColor3 = r[1], r[2]
		for _, n in z.neon do n.Color = r[2] end
	end
end
paintZones()

task.spawn(function()
	local t = 0
	while true do
		task.wait(1)
		t += 1
		for plr, s in sessions do
			s.d.cash += income(s)
			plr.leaderstats.Cash.Value = math.floor(s.d.cash)
			Fx:FireClient(plr, "Cash", s.d.cash)
		end
		if t % C.LuckCycle == 0 then
			luckShift = (luckShift + 1) % (C.MaxLuckShift + 1)
			paintZones()
			Fx:FireAllClients("Luck", luckShift)
		end
		if t % 120 == 0 then
			for plr in sessions do task.spawn(save, plr) end
		end
	end
end)
