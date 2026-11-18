-- Server: data, bases, shots, income, upgrades, bonuses, purchases
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.Shared.Config)
local Map = require(script.Parent.Map).Build()

-- In Studio without publishing / API Services the DataStore throws: keep playing, just don't save
local okStore, store = pcall(DataStoreService.GetDataStore, DataStoreService, "BilliardHuntersV2")
if not okStore then
	warn("DataStore unavailable, progress will not be saved:", store)
	store = { GetAsync = function() return nil end, UpdateAsync = function() end }
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
local throwCounter = 0
local rng = Random.new()
local N = #C.Rarities
local CollectionService = game:GetService("CollectionService")
local passByKey = {}
for _, gp in C.GamePasses do passByKey[gp.key] = gp end

local DATA_VERSION = 5
local function default()
	return {
		version = DATA_VERSION, cash = 0, strength = 0, dumbLevel = 1, cue = 1,
		inv = {}, found = {}, best = 0, daily = { day = 0, streak = 0 }, receipts = {}, tutorial = 1,
		settings = { music = 0.5, sfx = 0.7, shake = true, short = false },
	}
end

-- Accept only known fields with sane values (old saves, edited saves, removed items)
local function sanitize(saved)
	local d = default()
	if type(saved) ~= "table" then return d end
	local function num(v, lo, hi, def)
		v = tonumber(v)
		if not v or v ~= v then return def end
		return math.clamp(v, lo, hi)
	end
	d.cash = num(saved.cash, 0, 1e300, 0)
	d.strength = num(saved.strength, 0, 1e300, 0)
	d.dumbLevel = math.floor(num(saved.dumbLevel, 1, 200, 1))
	d.cue = math.floor(num(saved.cue, 1, #C.Cues, 1))
	d.best = math.floor(num(saved.best, 0, N, 0))
	-- v5: prize balls (one per rarity). Older saves stored characters: 6 per rarity (v4) or 4 (v3 and older).
	local version = tonumber(saved.version) or 0
	local perRarity = version >= 5 and 1 or version == 4 and 6 or 4
	local function ballOf(id)
		id = tonumber(id)
		if not id or id < 1 then return nil end
		local b = math.ceil(id / perRarity)
		return C.Balls[b] and b or nil
	end
	if type(saved.found) == "table" then
		for k in saved.found do
			local id, v = type(k) == "string" and k:match("^(%d+)_(%d)$")
			local b = ballOf(id)
			if b and C.Variants[tonumber(v)] then d.found[b .. "_" .. v] = true end
		end
	end
	d.tutorial = math.floor(num(saved.tutorial, 1, 4, 4)) -- existing players skip the tutorial
	if type(saved.daily) == "table" then
		d.daily = { day = math.floor(num(saved.daily.day, 0, 1e7, 0)), streak = math.floor(num(saved.daily.streak, 0, #C.Daily, 0)) }
	end
	if type(saved.receipts) == "table" then
		for _, r in saved.receipts do
			if type(r) == "string" and #d.receipts < 50 then table.insert(d.receipts, r) end
		end
	end
	if type(saved.settings) == "table" then
		local st = saved.settings
		d.settings = { music = num(st.music, 0, 1, 0.5), sfx = num(st.sfx, 0, 1, 0.7), shake = st.shake ~= false, short = st.short == true }
	end
	local equipped = 0
	if type(saved.inv) == "table" then
		for _, it in saved.inv do
			local b = type(it) == "table" and ballOf(it.id)
			if b and #d.inv < C.MaxInventory then
				local eq = it.eq == true and equipped < C.MaxEquipped
				if eq then equipped += 1 end
				local v = math.floor(num(it.v, 1, #C.Variants, 1))
				table.insert(d.inv, { id = b, v = v, eq = eq })
				d.found[b .. "_" .. v] = true
			end
		end
	end
	return d
end


local function income(s)
	local sum = 0
	for _, it in s.d.inv do
		if it.eq then sum += C.ItemIncome(it) end
	end
	return sum * (s.passes.Cash2x and 2 or 1) * (s.passes.GoldStick and 1.5 or 1)
end

local function sync(plr)
	local s = sessions[plr]
	if not s then return end
	Fx:FireClient(plr, "State", { d = s.d, passes = s.passes, slot = s.slot, income = income(s), luck = C.StartLuck(s.d, s.passes), training = s.training, join = s.join, claimed = s.claimed })
	plr.leaderstats.Cash.Value = math.floor(s.d.cash)
end

-- ===== Prize balls on the base table =====
local function weldTo(base, p)
	p.Anchored, p.CanCollide, p.Massless = false, false, true
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1, w.Parent = base, p, p
end

-- a cue part the client turns into the Blender cue: tier colours + tier effects (Shared/CueFx)
local function cuePart(cue, tier, cf)
	local p = Instance.new("Part")
	p.Name, p.Size, p.Color, p.Material = "Cue", Vector3.new(0.3, 9.2, 0.3), cue.shaft, Enum.Material.Wood
	p.CanCollide, p.CanQuery, p.CanTouch, p.CFrame = false, false, false, cf
	local tag = Instance.new("StringValue")
	tag.Name, tag.Value, tag.Parent = "Mesh", "Cue", p
	for slot, field in C.CueParts do
		local v = Instance.new("Color3Value")
		v.Name, v.Value, v.Parent = slot, cue[field], p
	end
	p:SetAttribute("Tier", tier)
	p:SetAttribute("Dragon", cue == C.DragonCue)
	return p
end

local function emitter(parent, color, rate, size, speed)
	local e = Instance.new("ParticleEmitter")
	e.Color, e.LightEmission, e.Rate, e.Lifetime = ColorSequence.new(color, Color3.new(1, 1, 1)), 0.8, rate, NumberRange.new(0.8, 1.4)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.Speed, e.SpreadAngle, e.Transparency = NumberRange.new(speed * 0.5, speed), Vector2.new(180, 180), NumberSequence.new(0.2, 1)
	e.Parent = parent
	return e
end

-- glowing ring (Blender torus) lying flat or tilted around the ball
local function ring(m, cf, size, color, spin)
	local p = Instance.new("Part")
	p.Name, p.Size, p.Color, p.Material = "Ring", Vector3.new(size, 0.2, size), color, Enum.Material.Neon
	p.Transparency, p.CFrame, p.Anchored, p.CanCollide, p.CanQuery, p.CastShadow = 1, cf, true, false, false, false
	local tag = Instance.new("StringValue")
	tag.Name, tag.Value, tag.Parent = "Mesh", "Ring", p
	local col = Instance.new("Color3Value")
	col.Name, col.Value, col.Parent = "Ring", color, p
	local sc = Instance.new("NumberValue")
	sc.Name, sc.Value, sc.Parent = "Scale", size / 4, p
	if spin then
		p:SetAttribute("Spin", spin)
		CollectionService:AddTag(p, "Spin")
	end
	p.Parent = m
	return p
end

-- rarity bands: 1-10 one ring on the felt, 11-25 two rings, 26-40 + two orbiting rings, 41-50 + halo and light pillar
local function rarityFx(m, cf, rarity, color, size)
	local felt = cf * CFrame.new(0, -size / 2 - 0.25, 0)
	ring(m, felt, size * 1.5, color, 0.6)
	if rarity > 10 then ring(m, felt, size * 1.9, Color3.new(1, 1, 1):Lerp(color, 0.5), -0.4) end
	if rarity > 25 then
		for k = 1, 2 do
			ring(m, cf * CFrame.Angles(math.rad(k == 1 and 65 or -65), 0, 0), size * 1.45, color, k == 1 and 1.4 or -1.4)
		end
	end
	if rarity > 40 then
		ring(m, cf * CFrame.new(0, size * 0.85, 0), size * 0.7, Color3.fromRGB(255, 235, 140), 0.8)
		local pillar = Instance.new("Part")
		pillar.Shape, pillar.Size, pillar.Color, pillar.Material = Enum.PartType.Cylinder, Vector3.new(24, size * 1.2, size * 1.2), color, Enum.Material.ForceField
		pillar.CFrame = cf * CFrame.new(0, 12, 0) * CFrame.Angles(0, 0, math.pi / 2)
		pillar.Transparency, pillar.Anchored, pillar.CanCollide, pillar.CanQuery, pillar.CastShadow = 0.4, true, false, false, false
		pillar.Parent = m
	end
end

-- A prize ball hovering over its spot on the base table. The client swaps the part for the Blender ball mesh,
-- makes it bob and spin, and applies the variant material (Gold / Diamond / Galaxy / Rainbow).
local function makeBall(it, spot)
	local ball = C.Balls[it.id]
	local r = C.Rarities[ball.rarity]
	local V = C.Variants[it.v or 1]
	local size = C.BallSize * V.scale
	local m = Instance.new("Model")
	m.Name = ball.name
	local cf = spot * CFrame.new(0, size / 2 + 0.25, 0)
	local p = Instance.new("Part")
	p.Name, p.Shape, p.Size, p.Color, p.Material = "Ball", Enum.PartType.Ball, Vector3.one * size, V.color or ball.body, Enum.Material.SmoothPlastic
	p.CFrame, p.Anchored, p.CanCollide, p.CanQuery = cf, true, false, false
	local tag = Instance.new("StringValue")
	tag.Name, tag.Value, tag.Parent = "Mesh", "PrizeBall", p
	for k, c in C.BallOverrides(it) do
		local v = Instance.new("Color3Value")
		v.Name, v.Value, v.Parent = k, c, p
	end
	local sc = Instance.new("NumberValue")
	sc.Name, sc.Value, sc.Parent = "Scale", size, p
	p:SetAttribute("Variant", V.name)
	p:SetAttribute("Number", ball.rarity)
	CollectionService:AddTag(p, "Hover")
	p.Parent = m
	m.PrimaryPart = p
	if V.color then emitter(p, V.color, 10, 0.25, 1.5) end
	emitter(p, r[2], 4 + ball.rarity * 0.3, 0.15 + ball.rarity * 0.006, 1)
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness, glow.Parent = r[2], 5 + ball.rarity * 0.1, 0.8, p
	rarityFx(m, cf, ball.rarity, r[2], size)

	local bb = Instance.new("BillboardGui")
	bb.Size, bb.StudsOffset, bb.AlwaysOnTop, bb.MaxDistance = UDim2.fromOffset(200, 56), Vector3.new(0, size / 2 + 1.4, 0), false, 32
	for i, t in { { C.ItemName(it), V.color or Color3.new(1, 1, 1) }, { r[1] .. "  $" .. C.Short(C.ItemIncome(it)) .. "/s", r[2] } } do
		local l = Instance.new("TextLabel")
		l.Size, l.Position, l.BackgroundTransparency = UDim2.fromScale(1, 0.5), UDim2.fromScale(0, (i - 1) * 0.5), 1
		l.FontFace, l.TextScaled, l.Text, l.TextColor3 = C.UI.Font, true, t[1], t[2]
		local st = Instance.new("UIStroke")
		st.Thickness, st.Color, st.Parent = 2.5, C.UI.Ink, l
		l.Parent = bb
	end
	bb.Parent = p
	m:SetAttribute("BallId", it.id)
	m:SetAttribute("Variant", it.v or 1)
	return m
end

-- Rebuild the base: keep existing NPCs that are still equipped, add new ones
local function refreshBase(plr)
	local s = sessions[plr]
	if not s then return end
	local base = Map.Bases[s.slot]
	local items = {}
	for _, it in s.d.inv do
		if it.eq and #items < C.MaxEquipped then table.insert(items, it) end
	end
	local bySlot = {}
	for _, npc in base.chars:GetChildren() do
		bySlot[npc:GetAttribute("Slot") or 0] = npc
	end
	for _, npc in bySlot do
		local slot = npc:GetAttribute("Slot")
		local it = slot and items[slot]
		if not it or it.id ~= npc:GetAttribute("BallId") or (it.v or 1) ~= npc:GetAttribute("Variant") then
			npc:Destroy()
			bySlot[slot or 0] = nil
		end
	end
	for i, it in items do
		if not bySlot[i] then
			local npc = makeBall(it, base.slots[i])
			npc:SetAttribute("Slot", i)
			if it.tid then
				npc:SetAttribute("ThrowId", it.tid) -- the client plays the landing animation on this ball
				it.tid = nil
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

-- ===== The cue in the player's hand (no display at the shop, the shop menu shows all cues) =====
local function currentCue(s)
	local cue = C.Cues[s.d.cue]
	if s.passes.DragonCue and C.DragonCue[2] > cue[2] then return C.DragonCue, C.DragonCue.tier end
	return cue, s.d.cue
end

local function giveCue(plr, upgraded)
	local s, char = sessions[plr], plr.Character
	local hand = char and char:FindFirstChild("RightHand")
	if not (s and hand) then return end
	local old = char:FindFirstChild("Cue")
	if old then
		if upgraded then Fx:FireClient(plr, "CueSwap", old.Position) end -- the old cue vanishes in a puff
		old:Destroy()
	end
	local cue, tier = currentCue(s)
	local p = cuePart(cue, tier, hand.CFrame * CFrame.Angles(math.rad(-12), 0, 0) * CFrame.new(0, 2.2, 0))
	p.Massless = true
	weldTo(hand, p)
	p.Parent = char
end

-- dumbbell plates/size follow the level (client rebuilds the mesh when the values change)
local function dressDumbbell(s)
	local db = Map.Bases[s.slot].dumbbell
	local color, scale = C.DumbbellLook(s.d.dumbLevel)
	local plate, sc = db:FindFirstChild("Plate"), db:FindFirstChild("Scale")
	if plate then plate.Value = color end
	if sc then sc.Value = scale end
end

-- ===== Player actions (Request:InvokeServer(action, arg)) =====
local actions = {}
local COOLDOWN = { Settings = 0.2, Sync = 0.5, TrainStart = 0.5, TrainStop = 0.2, Equip = 0.15, Sell = 0.15, EquipBest = 0.5, SellRarity = 0.5, Cue = 0.3, UpDumb = 0.3, Daily = 1, Playtime = 0.5, Pass = 1, Product = 1, Tutorial = 0.2 }

function actions.Sync() return true end

function actions.Settings(_, s, st)
	if type(st) ~= "table" then return false end
	local function vol(v, def) return type(v) == "number" and v == v and math.clamp(v, 0, 1) or def end
	s.d.settings = { music = vol(st.music, 0.5), sfx = vol(st.sfx, 0.7), shake = st.shake ~= false, short = st.short == true }
	return true
end

function actions.Tutorial(_, s, step)
	if type(step) == "number" and step == s.d.tutorial + 1 and step <= 4 then s.d.tutorial = step end
	return true
end

function actions.Throw(plr, s, power)
	if type(power) ~= "number" or power ~= power or os.clock() < s.nextThrow then return false end
	if #s.d.inv >= C.MaxInventory then return false, "Inventory is full. Sell someone first" end
	local dist = C.Distance(math.clamp(power, 0, 1), s.d, s.passes)
	local zone = C.ZoneOf(dist)
	-- luck grows along the path: the client shows the same track live while the ball rolls
	local luck0 = C.StartLuck(s.d, s.passes)
	local track, lucky = C.LuckTrack(luck0, zone, function() return rng:NextNumber() end)
	local L = track[zone]
	local rarity = math.min(zone + C.LuckBonus(L, rng:NextNumber(), rng:NextNumber(), rng:NextNumber()), N)
	local full = rarity >= C.FullCinematicRarity and rarity >= s.d.best - 2 -- the big show only for top pulls
	s.d.best = math.max(s.d.best, rarity)
	s.nextThrow = os.clock() + C.ThrowTime(dist, full) + C.ThrowCooldown
	local it = { id = rarity, v = C.RollVariant(rng:NextNumber()) }
	throwCounter += 1
	it.eq = equippedCount(s.d) < C.MaxEquipped
	it.tid = it.eq and throwCounter or nil
	table.insert(s.d.inv, it)
	s.d.found[it.id .. "_" .. it.v] = true
	local luckyList = {}
	for k in lucky do table.insert(luckyList, k) end
	Fx:FireAllClients("Throw", {
		slot = s.slot, uid = plr.UserId, dist = dist, id = it.id, v = it.v, track = track, lucky = luckyList,
		tid = it.tid or 0, full = full, gold = s.passes.GoldenBall == true, luck0 = luck0,
		cue = select(2, currentCue(s)), dragon = currentCue(s) == C.DragonCue,
	})
	task.delay(C.ThrowTime(dist, full), refreshBase, plr)
	if s.d.tutorial == 1 then s.d.tutorial = 2 end
	return true
end

-- Training: Start/Stop, the server adds strength every rep while the player stays at the gym
local function near(plr, s)
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	return root and (root.Position - Map.Bases[s.slot].gym.Position).Magnitude <= C.GymRange
end

local function stopTraining(plr, s)
	if not s.training then return end
	s.training = false
	Map.Bases[s.slot].trainPrompt.ActionText = "Start training"
	Fx:FireClient(plr, "Train", false)
end

function actions.TrainStart(plr, s)
	if s.training then return true end
	if not near(plr, s) then return false, "Go to the dumbbell at your base" end
	s.training = true
	s.trainId = (s.trainId or 0) + 1
	local id, reps = s.trainId, 0 -- a quick Stop + Start never runs two rep loops
	Map.Bases[s.slot].trainPrompt.ActionText = "Stop training"
	Fx:FireClient(plr, "Train", true, Map.Bases[s.slot].gym.CFrame, Map.Bases[s.slot].dumbbell)
	task.spawn(function()
		while s.training and s.trainId == id and sessions[plr] == s do
			task.wait(C.TrainRep)
			if not (s.training and s.trainId == id and sessions[plr] == s) then break end
			if not near(plr, s) then
				stopTraining(plr, s)
				break
			end
			local gain = C.RepStrength(s.d.dumbLevel)
			s.d.strength += gain
			if s.d.tutorial == 2 and s.d.strength >= 20 then
				s.d.tutorial = 3
				sync(plr)
			end
			reps += 1
			Fx:FireClient(plr, "Rep", s.d.strength, gain, reps)
		end
	end)
	return true
end

function actions.TrainStop(plr, s)
	stopTraining(plr, s)
	return true
end

function actions.UpDumb(_, s)
	if not pay(s, C.LiftCost(s.d.dumbLevel)) then return false, "Not enough cash" end
	s.d.dumbLevel += 1
	dressDumbbell(s)
	return true, "Dumbbell level " .. s.d.dumbLevel
end

-- Cues are an upgrade path: you can only buy the next tier, and the new cue replaces the old one
function actions.Cue(plr, s)
	local nextTier = s.d.cue + 1
	local cue = C.Cues[nextTier]
	if not cue then return false, "You own the best cue" end
	if not pay(s, cue[3]) then return false, "Not enough cash" end
	s.d.cue = nextTier
	if s.d.tutorial == 3 then s.d.tutorial = 4 end
	giveCue(plr, true)
	return true, cue[1] .. " cue equipped"
end

function actions.Equip(plr, s, i)
	local it = type(i) == "number" and s.d.inv[i]
	if not it then return false end
	if not it.eq and equippedCount(s.d) >= C.MaxEquipped then return false, "All " .. C.MaxEquipped .. " spots are taken" end
	it.eq = not it.eq
	refreshBase(plr)
	return true
end

function actions.Sell(plr, s, i)
	local it = type(i) == "number" and s.d.inv[i]
	if not it then return false end
	local price = C.ItemIncome(it) * 30
	s.d.cash += price
	table.remove(s.d.inv, i)
	if it.eq then refreshBase(plr) end
	return true, "Sold for $" .. C.Short(price)
end

-- fill the base with the highest-income characters
function actions.EquipBest(plr, s)
	local order = {}
	for i, it in s.d.inv do
		it.eq = false
		table.insert(order, i)
	end
	table.sort(order, function(a, b) return C.ItemIncome(s.d.inv[a]) > C.ItemIncome(s.d.inv[b]) end)
	for k = 1, math.min(C.MaxEquipped, #order) do s.d.inv[order[k]].eq = true end
	refreshBase(plr)
	return true, "Best team placed"
end

-- sell every unequipped character of one rarity (Gold and rarer variants are kept)
function actions.SellRarity(_, s, rarity)
	if type(rarity) ~= "number" or not C.Rarities[rarity] then return false end
	local total, kept, n = 0, {}, 0
	for _, it in s.d.inv do
		if not it.eq and (it.v or 1) < 4 and it.id == rarity then
			total += C.ItemIncome(it) * 30
			n += 1
		else
			table.insert(kept, it)
		end
	end
	if n == 0 then return false, "Nothing to sell" end
	s.d.inv = kept
	s.d.cash += total
	return true, "Sold " .. n .. " for $" .. C.Short(total)
end

function actions.Daily(_, s)
	local day = os.time() // 86400
	local dd = s.d.daily
	if dd.day == day then return false, "Come back tomorrow" end
	dd.streak = (dd.day == day - 1) and dd.streak % #C.Daily + 1 or 1
	dd.day = day
	s.d.cash += C.Daily[dd.streak]
	return true, "+$" .. C.Short(C.Daily[dd.streak])
end

function actions.Playtime(_, s, i)
	local p = type(i) == "number" and C.Playtime[i]
	if not p or s.claimed[i] then return false end
	if os.time() - s.join < p[1] * 60 then return false, "Not yet" end
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
	local now = os.clock()
	if now - (s.last[action] or 0) < (COOLDOWN[action] or 0) then return false end
	s.last[action] = now
	local ok, msg = fn(plr, s, arg)
	sync(plr)
	return ok, msg
end

-- ===== Players =====
local function onCharacter(plr, slot, char)
	task.wait()
	char:PivotTo(Map.Bases[slot].spawn * CFrame.new(0, 3, 0))
	local s = sessions[plr]
	if s then stopTraining(plr, s) end
	char:WaitForChild("RightHand", 10)
	giveCue(plr, false)
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

	local ok, saved
	for attempt = 1, 3 do
		ok, saved = pcall(store.GetAsync, store, plr.UserId)
		if ok then break end
		task.wait(attempt)
	end
	local d = sanitize(saved)
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
	sessions[plr] = { d = d, slot = slot, passes = passes, join = os.time(), claimed = {}, nextThrow = 0, last = {}, loaded = ok }

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local cash = Instance.new("NumberValue")
	cash.Name, cash.Parent = "Cash", ls
	ls.Parent = plr
	Map.SetOwner(slot, plr)

	plr.CharacterAdded:Connect(function(char) onCharacter(plr, slot, char) end)
	if plr.Character then task.spawn(onCharacter, plr, slot, plr.Character) end
	refreshBase(plr)
	dressDumbbell(sessions[plr])
	sync(plr)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do task.spawn(onPlayer, p) end

local function save(plr, s)
	s = s or sessions[plr]
	if not (s and s.loaded) then return end -- never overwrite a save we failed to load
	local copy = table.clone(s.d)
	copy.version = DATA_VERSION
	for attempt = 1, 3 do
		local ok = pcall(store.UpdateAsync, store, plr.UserId, function() return copy end)
		if ok then return end
		task.wait(attempt)
	end
	warn("[Save] failed for", plr.Name)
end

Players.PlayerRemoving:Connect(function(plr)
	local s = sessions[plr]
	task.spawn(save, plr, s)
	if s then
		Map.Bases[s.slot].chars:ClearAllChildren()
		s.training = false
		Map.SetOwner(s.slot, nil)
		taken[s.slot] = nil
	end
	sessions[plr] = nil
end)

game:BindToClose(function()
	local left = 0
	for plr, s in sessions do
		left += 1
		task.spawn(function()
			save(plr, s)
			left -= 1
		end)
	end
	local t0 = os.clock()
	while left > 0 and os.clock() - t0 < 25 do task.wait(0.2) end
end)

-- gym and cue shop stand in front of each base and only serve the base owner
for idx, base in Map.Bases do
	local function owner(plr)
		local s = sessions[plr]
		if s and s.slot == idx then return s end
		if s then Fx:FireClient(plr, "Toast", "Use the gym and shop at your own base") end
	end
	base.trainPrompt.Triggered:Connect(function(plr)
		local s = owner(plr)
		if s then
			if s.training then stopTraining(plr, s) else actions.TrainStart(plr, s) end
			sync(plr)
		end
	end)
	base.shopPrompt.Triggered:Connect(function(plr)
		if owner(plr) then Fx:FireClient(plr, "Open", "Cues") end
	end)
	-- stepping into the glowing ring in front of the dumbbell opens the gym upgrade menu
	local inside = {}
	base.ring.Touched:Connect(function(hit)
		local plr = Players:GetPlayerFromCharacter(hit.Parent)
		if not plr or inside[plr] then return end
		inside[plr] = true
		if owner(plr) then Fx:FireClient(plr, "Open", "Gym") end
		task.delay(3, function() inside[plr] = nil end)
	end)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, id, bought)
	local s = sessions[plr]
	if not (s and bought) then return end
	local key
	for _, gp in C.GamePasses do
		if gp.id == id then
			s.passes[gp.key] = true
			key = gp.key
		end
	end
	if key == "DragonCue" then
		giveCue(plr, true)
	end
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

-- ===== Income every second, autosave every 2 minutes =====
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
		if t % 120 == 0 then
			for plr in sessions do task.spawn(save, plr) end
		end
	end
end)
