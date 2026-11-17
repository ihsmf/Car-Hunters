-- Server: data, bases, shots, income, upgrades, bonuses, purchases
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.Shared.Config)
local Avatars = require(RS.Shared.Avatars)
local Map = require(script.Parent.Map).Build()

-- In Studio without publishing / API Services the DataStore throws: keep playing, just don't save
local okStore, store = pcall(DataStoreService.GetDataStore, DataStoreService, "BilliardHuntersV2")
if not okStore then
	warn("DataStore unavailable, progress will not be saved:", store)
	store = { GetAsync = function() return nil end, SetAsync = function() end }
end

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local Request = Instance.new("RemoteFunction")
Request.Name, Request.Parent = "Request", remotes
local Fx = Instance.new("RemoteEvent")
Fx.Name, Fx.Parent = "Fx", remotes
remotes.Parent = RS

local sessions = {} -- player -> session
local taken = {} -- base slot -> player
local luckIdx = 1 -- index into C.LuckSteps
local throwCounter = 0
local rng = Random.new()
local N = #C.Rarities
local passByKey = {}
for _, gp in C.GamePasses do passByKey[gp.key] = gp end

local ANIM = { Idle = "rbxassetid://507766666", Cheer = "rbxassetid://507770677", Wave = "rbxassetid://507770239" }

local function default()
	return {
		cash = 0, strength = 0, dumbLevel = 1, cue = 1, cues = { ["1"] = true }, cueLevel = 1,
		inv = {}, daily = { day = 0, streak = 0 }, receipts = {},
	}
end

local function luckOf(s)
	return C.LuckSteps[luckIdx] * (s.passes.Luck2x and 2 or 1)
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
	if not s then return end
	s.d.passes = s.passes
	Fx:FireClient(plr, "State", { d = s.d, slot = s.slot, income = income(s), luck = luckOf(s), luckIn = C.LuckCycle, join = s.join, claimed = s.claimed })
	plr.leaderstats.Cash.Value = math.floor(s.d.cash)
end

-- ===== Characters: Roblox avatars dressed in real catalog items (Shared/Avatars) + cue in hand + aura =====
local SKIN = { Color3.fromRGB(255, 214, 170), Color3.fromRGB(234, 184, 146), Color3.fromRGB(198, 140, 100), Color3.fromRGB(124, 84, 62) }
local ACCESSORY_TYPE = {
	[8] = Enum.AccessoryType.Hat, [41] = Enum.AccessoryType.Hair, [42] = Enum.AccessoryType.Face, [43] = Enum.AccessoryType.Neck,
	[44] = Enum.AccessoryType.Shoulder, [45] = Enum.AccessoryType.Front, [46] = Enum.AccessoryType.Back, [47] = Enum.AccessoryType.Waist,
}

local function describe(info, variant, level)
	-- level 2: full outfit, 1: clothes only, 0: plain body (fallbacks if a catalog item fails to load)
	local desc = Instance.new("HumanoidDescription")
	local skin = SKIN[variant]
	desc.HeadColor, desc.TorsoColor, desc.LeftArmColor, desc.RightArmColor, desc.LeftLegColor, desc.RightLegColor = skin, skin, skin, skin, skin, skin
	local k = 1 + info.rarity * 0.012
	desc.HeightScale, desc.WidthScale, desc.DepthScale, desc.HeadScale = k, k, k, 1
	desc.BodyTypeScale, desc.ProportionScale = 0.15, 0
	local look = Avatars[info.rarity][variant]
	if level >= 1 then
		desc.Shirt, desc.Pants = look.shirt, look.pants
	end
	if level >= 2 then
		local list = {}
		for i, a in look.accessories do
			table.insert(list, { AssetId = a[1], AccessoryType = ACCESSORY_TYPE[a[2]], Order = i, IsLayered = false })
		end
		desc:SetAccessories(list, true) -- true = include rigid (non-layered) accessories
	end
	return desc
end

local function buildAvatar(info, variant)
	for level = 2, 0, -1 do
		local ok, m = pcall(Players.CreateHumanoidModelFromDescription, Players, describe(info, variant, level), Enum.HumanoidRigType.R15)
		if ok and m then return m end
		warn("[Avatar] level", level, "failed for", info.name, m)
	end
end

local function weldTo(base, p)
	p.Anchored, p.CanCollide, p.Massless = false, false, true
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1, w.Parent = base, p, p
end

local function play(hum, id, looped)
	local a = Instance.new("Animation")
	a.AnimationId = id
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = hum
	local ok, track = pcall(function() return animator:LoadAnimation(a) end)
	if ok and track then
		track.Looped = looped
		track:Play()
	end
	return ok and track
end

local function makeNPC(id, cf, gold, fresh)
	local info = C.Characters[id]
	local r = C.Rarities[info.rarity]
	local m = buildAvatar(info, (id - 1) % 4 + 1)
	m.Name = info.name
	local hum = m.Humanoid
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	m.HumanoidRootPart.Anchored = true
	m:PivotTo(cf * CFrame.new(0, hum.HipHeight + m.HumanoidRootPart.Size.Y / 2, 0))

	-- cue held like a staff (client swaps it for the Blender cue mesh)
	local stick = Instance.new("Part")
	stick.Name, stick.Size = "Stick", Vector3.new(0.3, 9.2, 0.3)
	stick.Color = gold and Color3.fromRGB(255, 200, 40) or Color3.fromRGB(236, 196, 132)
	stick.Material = gold and Enum.Material.Metal or Enum.Material.Wood
	local hand = m.RightHand
	stick.CFrame = hand.CFrame * CFrame.Angles(math.rad(-12), 0, 0) * CFrame.new(0, 2.2, 0)
	local tag = Instance.new("StringValue")
	tag.Name, tag.Value, tag.Parent = "Mesh", "Cue", stick
	local shaft = Instance.new("Color3Value")
	shaft.Name, shaft.Value, shaft.Parent = "Shaft", stick.Color, stick
	weldTo(hand, stick)
	stick.Parent = m

	local aura = Instance.new("ParticleEmitter")
	aura.Color = ColorSequence.new(r[2], Color3.new(1, 1, 1))
	aura.LightEmission, aura.Rate, aura.Lifetime = 0.8, 10 + info.rarity * 3, NumberRange.new(1, 1.6)
	aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4 + info.rarity * 0.1), NumberSequenceKeypoint.new(1, 0) })
	aura.Speed, aura.SpreadAngle = NumberRange.new(1, 3), Vector2.new(180, 180)
	aura.Transparency = NumberSequence.new(0.3, 1)
	aura.Parent = m.HumanoidRootPart
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness, glow.Parent = r[2], 8 + info.rarity, 1.5, m.HumanoidRootPart
	local ring = Instance.new("Part") -- glowing aura disc under the feet
	ring.Shape, ring.Size, ring.Color, ring.Material = Enum.PartType.Cylinder, Vector3.new(0.1, 5.4, 5.4), r[2], Enum.Material.ForceField
	ring.CFrame = cf * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Anchored, ring.CanCollide, ring.CastShadow, ring.Parent = true, false, false, m

	local bb = Instance.new("BillboardGui")
	bb.Size, bb.StudsOffset, bb.AlwaysOnTop, bb.MaxDistance = UDim2.fromOffset(200, 64), Vector3.new(0, 3.5, 0), true, 90
	for i, t in { { info.name, Color3.new(1, 1, 1) }, { r[1] .. " • $" .. C.Short(info.income) .. "/s", r[2] } } do
		local l = Instance.new("TextLabel")
		l.Size, l.Position, l.BackgroundTransparency = UDim2.fromScale(1, 0.5), UDim2.fromScale(0, (i - 1) * 0.5), 1
		l.FontFace, l.TextScaled, l.Text, l.TextColor3 = C.UI.Font, true, t[1], t[2]
		local st = Instance.new("UIStroke")
		st.Thickness, st.Color, st.Parent = 2.5, C.UI.Ink, l
		l.Parent = bb
	end
	bb.Parent = m.Head
	m:SetAttribute("CharId", id)

	task.defer(function() -- animations need the rig parented
		if fresh then
			local t = play(hum, ANIM.Cheer, false)
			if t then t.Stopped:Wait() end
		end
		if m.Parent then play(hum, ANIM.Idle, true) end
	end)
	return m
end

-- Rebuild the base: keep existing NPCs that are still equipped, add new ones
local function refreshBase(plr)
	local s = sessions[plr]
	if not s then return end
	local base = Map.Bases[s.slot]
	local want, items = {}, {}
	for _, it in s.d.inv do
		if it.eq and #want < C.MaxEquipped then
			table.insert(want, it.id)
			table.insert(items, it)
		end
	end
	local bySlot = {}
	for _, npc in base.chars:GetChildren() do
		bySlot[npc:GetAttribute("Slot") or 0] = npc
	end
	for _, npc in bySlot do
		local slot = npc:GetAttribute("Slot")
		if not slot or want[slot] ~= npc:GetAttribute("CharId") then
			npc:Destroy()
			bySlot[slot or 0] = nil
		end
	end
	for i, id in want do
		if not bySlot[i] then
			local npc = makeNPC(id, base.slots[i], s.passes.GoldStick, true)
			npc:SetAttribute("Slot", i)
			if items[i].tid then
				npc:SetAttribute("ThrowId", items[i].tid) -- the client plays the reveal cinematic on this NPC
				items[i].tid = nil
			end
			npc.Parent = base.chars
		end
	end
end

local function equippedCount(d)
	local n = 0
	for _, it in d.inv do
		if it.eq then n += 1 end
	end
	return n
end

local function pay(s, cost)
	if s.d.cash < cost then return false end
	s.d.cash -= cost
	return true
end

-- ===== Player actions (Request:InvokeServer(action, arg)) =====
local actions = {}

function actions.Sync() return true end

function actions.Throw(plr, s, power)
	if type(power) ~= "number" or power ~= power or os.clock() < s.nextThrow then return false end
	if #s.d.inv >= C.MaxInventory then return false, "Inventory is full! Sell someone first" end
	local dist = C.Distance(math.clamp(power, 0, 1), s.d)
	s.nextThrow = os.clock() + C.ThrowTime(dist) + C.ThrowCooldown
	local zone = math.clamp(math.ceil(dist / (C.Table.Length / N)), 1, N)
	local L = luckOf(s)
	local rarity = math.min(zone + C.LuckBonus(L, rng:NextNumber(), rng:NextNumber()), N)
	local pool = {}
	for id, ch in C.Characters do
		if ch.rarity == rarity then table.insert(pool, id) end
	end
	local id = pool[rng:NextInteger(1, #pool)]
	throwCounter += 1
	local eq = equippedCount(s.d) < C.MaxEquipped
	table.insert(s.d.inv, { id = id, eq = eq, tid = eq and throwCounter or nil })
	Fx:FireAllClients("Throw", s.slot, dist, id, L, eq and throwCounter or 0)
	task.delay(C.ThrowTime(dist), refreshBase, plr)
	return true
end

function actions.Lift(_, s)
	if os.clock() - s.lastLift < 0.35 then return false end
	s.lastLift = os.clock()
	s.d.strength += s.d.dumbLevel
	return true
end

function actions.UpDumb(_, s)
	if not pay(s, C.LiftCost(s.d.dumbLevel)) then return false, "Not enough cash!" end
	s.d.dumbLevel += 1
	return true, "Dumbbell upgraded!"
end

function actions.UpCue(_, s)
	if not pay(s, C.CueUpCost(s.d.cueLevel)) then return false, "Not enough cash!" end
	s.d.cueLevel += 1
	return true, "Cue upgraded!"
end

function actions.Cue(_, s, i)
	local cue = type(i) == "number" and C.Cues[i]
	if not cue then return false end
	if not s.d.cues[tostring(i)] then
		if not pay(s, cue[3]) then return false, "Not enough cash!" end
		s.d.cues[tostring(i)] = true
	end
	s.d.cue = i
	return true, cue[1] .. " cue equipped!"
end

function actions.Equip(plr, s, i)
	local it = type(i) == "number" and s.d.inv[i]
	if not it then return false end
	if not it.eq and equippedCount(s.d) >= C.MaxEquipped then return false, "All " .. C.MaxEquipped .. " spots are taken!" end
	it.eq = not it.eq
	refreshBase(plr)
	return true
end

function actions.Sell(plr, s, i)
	local it = type(i) == "number" and s.d.inv[i]
	if not it then return false end
	local price = C.Characters[it.id].income * 30
	s.d.cash += price
	table.remove(s.d.inv, i)
	if it.eq then refreshBase(plr) end
	return true, "Sold for $" .. C.Short(price)
end

function actions.Daily(_, s)
	local day = os.time() // 86400
	local dd = s.d.daily
	if dd.day == day then return false, "Come back tomorrow!" end
	dd.streak = (dd.day == day - 1) and dd.streak % #C.Daily + 1 or 1
	dd.day = day
	s.d.cash += C.Daily[dd.streak]
	return true, "+$" .. C.Short(C.Daily[dd.streak])
end

function actions.Playtime(_, s, i)
	local p = type(i) == "number" and C.Playtime[i]
	if not p or s.claimed[i] then return false end
	if os.time() - s.join < p[1] * 60 then return false, "Not yet!" end
	s.claimed[i] = true
	s.d.cash += p[2]
	return true, "+$" .. C.Short(p[2])
end

function actions.Pass(plr, _, key)
	local gp = passByKey[key]
	if not gp then return false end
	if gp.id <= 0 then return false, "Set the Game Pass ID in Config" end
	MarketplaceService:PromptGamePassPurchase(plr, gp.id)
	return true
end

function actions.Product(plr, _, i)
	local p = type(i) == "number" and C.Products[i]
	if not p then return false end
	if p.id <= 0 then return false, "Set the Product ID in Config" end
	MarketplaceService:PromptProductPurchase(plr, p.id)
	return true
end

Request.OnServerInvoke = function(plr, action, arg)
	local s, fn = sessions[plr], actions[action]
	if not (s and fn) then return false end
	local ok, msg = fn(plr, s, arg)
	sync(plr)
	return ok, msg
end

-- ===== Players =====
local function onCharacter(slot, char)
	task.wait()
	char:PivotTo(Map.Bases[slot].spawn * CFrame.new(0, 3, 0))
end

local function onPlayer(plr)
	local slot
	for i = 1, #Map.Bases do
		if not taken[i] then
			slot = i
			break
		end
	end
	if not slot then
		plr:Kick("Server is full")
		return
	end
	taken[slot] = plr

	local ok, saved = pcall(store.GetAsync, store, plr.UserId)
	local d = default()
	if ok and type(saved) == "table" then
		for k, v in saved do d[k] = v end
	end
	local passes = {}
	for _, gp in C.GamePasses do
		if gp.id > 0 then
			local ok2, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, plr.UserId, gp.id)
			passes[gp.key] = ok2 and owns
		end
	end
	if not plr.Parent then
		taken[slot] = nil
		return
	end
	sessions[plr] = { d = d, slot = slot, passes = passes, join = os.time(), claimed = {}, nextThrow = 0, lastLift = 0, loaded = ok }

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local cash = Instance.new("NumberValue")
	cash.Name, cash.Parent = "Cash", ls
	ls.Parent = plr
	Map.Bases[slot].sign.Text = plr.DisplayName .. "'s Base"

	plr.CharacterAdded:Connect(function(char) onCharacter(slot, char) end)
	if plr.Character then task.spawn(onCharacter, slot, plr.Character) end
	refreshBase(plr)
	sync(plr)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do task.spawn(onPlayer, p) end

local function save(plr)
	local s = sessions[plr]
	if not (s and s.loaded) then return end
	local copy = table.clone(s.d)
	copy.passes = nil
	pcall(store.SetAsync, store, plr.UserId, copy)
end

Players.PlayerRemoving:Connect(function(plr)
	save(plr)
	local s = sessions[plr]
	if s then
		Map.Bases[s.slot].chars:ClearAllChildren()
		Map.Bases[s.slot].sign.Text = "Free Base"
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
	for _, gp in C.GamePasses do
		if gp.id == id then s.passes[gp.key] = true end
	end
	Map.Bases[s.slot].chars:ClearAllChildren() -- rebuild sticks for Golden Stick
	refreshBase(plr)
	sync(plr)
end)

MarketplaceService.ProcessReceipt = function(info)
	local plr = Players:GetPlayerByUserId(info.PlayerId)
	local s = plr and sessions[plr]
	if not s then return Enum.ProductPurchaseDecision.NotProcessedYet end
	if not table.find(s.d.receipts, info.PurchaseId) then
		for _, p in C.Products do
			if p.id == info.ProductId then s.d.cash += p.cash end
		end
		table.insert(s.d.receipts, info.PurchaseId)
		if #s.d.receipts > 50 then table.remove(s.d.receipts, 1) end
		save(plr)
		sync(plr)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ===== Luck multiplier cycles through C.LuckSteps =====
task.spawn(function()
	local t = 0
	while true do
		task.wait(1)
		t += 1
		for plr, s in sessions do
			s.d.cash += income(s)
			plr.leaderstats.Cash.Value = math.floor(s.d.cash)
			Fx:FireClient(plr, "Cash", s.d.cash, C.LuckCycle - t % C.LuckCycle)
		end
		if t % C.LuckCycle == 0 then
			luckIdx = luckIdx % #C.LuckSteps + 1
			for plr, s in sessions do Fx:FireClient(plr, "Luck", luckOf(s)) end
		end
		if t % 120 == 0 then
			for plr in sessions do task.spawn(save, plr) end
		end
	end
end)
