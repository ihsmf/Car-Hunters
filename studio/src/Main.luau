-- Server: data, bases, shots, income, upgrades, bonuses, purchases
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local Art = require(RS.Shared.Art)
local ShotPose = require(RS.Shared.ShotPose)
local Rank = require(script.Parent.ClubRanks)
local Save = require(script.Parent.SaveSession)
local C = require(RS.Shared.Config)
local Map = require(script.Parent.Map).Build()

-- In Studio without publishing / API Services the DataStore throws: keep playing, just don't save
local storeName = RunService:IsStudio() and "BilliardHuntersV2_Studio" or "BilliardHuntersV2"
local okStore, store = pcall(DataStoreService.GetDataStore, DataStoreService, storeName)
if not okStore then
	warn("DataStore unavailable:", store)
	store = { UpdateAsync = function() error("DataStore unavailable") end }
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

local DATA_VERSION = 7
local function default()
	return {
		version = DATA_VERSION, cash = 0, totalEarned = 0, playedSeconds = 0, strength = 0, dumbLevel = 1, cue = 1,
		decks = {}, inv = {}, found = {}, best = 0, daily = { day = 0, streak = 0 }, receipts = {}, tutorial = 1,
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
	d.totalEarned = num(saved.totalEarned, 0, 1e300, d.cash)
 d.playedSeconds = math.floor(num(saved.playedSeconds, 0, 1e12, 0))
 d.strength = num(saved.strength, 0, 1e300, 0)
	d.dumbLevel = math.floor(num(saved.dumbLevel, 1, C.DumbbellMax, 1))
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
	if type(saved.decks)=="table" then
  for section=1,N do
   local key=tostring(section)
   local deck=saved.decks[key]
   if type(deck)=="table" and type(deck.order)=="table" and type(deck.used)=="number" and deck.used%1==0 and deck.used>=0 and deck.used<=C.DesignCount and #deck.order==C.DesignCount then
    local seen={}
    for _,id in ipairs(deck.order) do
     if type(id)~="number" or id%1~=0 or id<1 or id>C.DesignCount or seen[id] then break end
     seen[id]=true
    end
    local count=0
    for _ in seen do count+=1 end
    if count==C.DesignCount then d.decks[key]={order=table.clone(deck.order),used=deck.used} end
   end
  end
 end
 if type(saved.found) == "table" then
		for k in saved.found do
			if type(k)=="string" then
                local sec,design,v=k:match("^(%d+)_(%d+)_(%d+)$")
                if not sec then sec,v=k:match("^(%d+)_(%d+)$");design="1" end
                local section,style,variant=ballOf(sec),tonumber(design),tonumber(v)
                if section and style and style>=1 and style<=C.DesignCount and C.Variants[variant] then
                    d.found[C.DiscoveryKey({section=section,design=style,v=variant})]=true
                end
            end
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
				local entry={id=b,v=v,eq=eq,section=math.floor(num(it.section,1,N,b)),design=math.floor(num(it.design,1,C.DesignCount,1))}
                table.insert(d.inv,entry)
                d.found[C.DiscoveryKey(entry)]=true
			end
		end
	end
	return d
end


local function incomeFor(d, passes)
	local sum = 0
	for _, it in d.inv do
		if it.eq then sum += C.ItemIncome(it) end
	end
	return sum * (passes.Cash2x and 2 or 1) * (passes.GoldStick and 1.5 or 1)
end

local function income(s) return incomeFor(s.d, s.passes) end

local function isOwner(plr)
 local id = script:GetAttribute("OwnerUserId") or 0
 if id > 0 then return plr.UserId == id end
 return game.CreatorType == Enum.CreatorType.User and game.CreatorId > 0 and plr.UserId == game.CreatorId
end

local function playData(s)
 if s.god or not s.ownerBoost then return s.d end
 local view = table.clone(s.d)
 view.strength = math.max(view.strength,C.OwnerStrength)
 return view
end

local function sync(plr)
	local s = sessions[plr]
	if not s then return end
	Fx:FireClient(plr, "State", { d = playData(s), ownerEligible = isOwner(plr), god = s.god ~= nil, godSection=s.godSection, godVariant=s.godVariant, ownerBoost = s.ownerBoost == true or s.god ~= nil, passes = s.passes, slot = s.slot, income = income(s), luck = C.StartLuck(s.d, s.passes), training = s.training, join = s.join, claimed = s.claimed, offlineAmount = s.offlineAmount, offlineElapsed = s.offlineElapsed })
	plr.leaderstats.Cash.Value = math.floor((s.god or s).d.cash)
end

-- ===== Prize balls on the base table =====
local function weldTo(base, p)
	p.Anchored, p.CanCollide, p.Massless = false, false, true
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1, w.Parent = base, p, p
end

-- A grip anchor plus the Blender-derived cue shown throughout play.
local function cuePart(cue, tier, cf)
	local p = Instance.new("Part")
	p.Name, p.Size, p.Transparency = "Cue", Vector3.new(.2,.2,.2), 1
	p.CanCollide, p.CanQuery, p.CanTouch, p.CFrame = false, false, false, cf
	p:SetAttribute("Tier", tier)
	p:SetAttribute("Dragon", cue == C.DragonCue)
	local key = Art.CueKey(tier, cue == C.DragonCue)
	p:SetAttribute("ArtScale", C.CueScale)
	p:SetAttribute("ArtKey", key)
	Art.Attach(key, p, C.CueScale)
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
	local felt = cf * CFrame.new(0, -size / 2 + 0.03, 0)
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
	m.Name = C.DesignName(it)
	local cf = spot * CFrame.new(0, size / 2, 0)
	local p = Instance.new("Part")
	p.Name, p.Shape, p.Size, p.Color, p.Material = "Ball", Enum.PartType.Ball, Vector3.one * size, V.color or ball.body, Enum.Material.SmoothPlastic
	p.CFrame, p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = cf, true, false, false, false
	p.Transparency=1
 p:SetAttribute("Section",it.section or it.id)
 p:SetAttribute("Design",it.design or 1)
 p:SetAttribute("Edition",it.v or 1)
 p:SetAttribute("Variant", V.name)
	p:SetAttribute("Number", ball.rarity)
	CollectionService:AddTag(p, "BaseRoll")
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
	m:SetAttribute("Discovery", C.DiscoveryKey(it))
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
		if not it or C.DiscoveryKey(it) ~= npc:GetAttribute("Discovery") or it.id ~= npc:GetAttribute("BallId") or (it.v or 1) ~= npc:GetAttribute("Variant") then
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

local function earn(s,amount)
 s.d.cash += amount
 s.d.totalEarned = math.min(1e300,s.d.totalEarned+amount)
end
local function pay(s, cost)
 if s.god or s.ownerBoost then return true end
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
	local hand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
	if not (s and hand) or s.training then return end
	local old = char:FindFirstChild("Cue")
	if old then
		if upgraded then Fx:FireClient(plr, "CueSwap", old.Position) end -- the old cue vanishes in a puff
		old:Destroy()
	end
	local cue, tier = currentCue(s)
	local p = cuePart(cue, tier, hand.CFrame * CFrame.Angles(math.rad(-66), 0, math.rad(12)) * CFrame.new(0, ShotPose.CueLength * .20, 0))
	p.Massless = true
	weldTo(hand, p)
	p.Parent = char
end

local finishes = {
 {Color3.fromRGB(104,70,46),Enum.Material.Wood}, {Color3.fromRGB(80,97,110),Enum.Material.Metal},
 {Color3.fromRGB(147,87,55),Enum.Material.Metal}, {Color3.fromRGB(40,94,78),Enum.Material.Marble},
 {Color3.fromRGB(75,47,37),Enum.Material.WoodPlanks}
}
local function finishPad(slot, level)
 local pad = Map.Bases[slot].pad
 local finish = finishes[math.clamp(math.ceil(level/10),1,#finishes)]
 pad.Zone.Color,pad.Zone.Material = finish[1],finish[2]
 local lit = level > 0 and (level-1)%10+1 or 0
 for k=0,9 do
  local mark = pad[string.format("Level%02d",k)]
  mark.Color = k < lit and Color3.fromRGB(251,202,106) or Color3.fromRGB(81,78,74)
  mark.Material = k < lit and Enum.Material.Neon or Enum.Material.Metal
 end
end
local function clearDumbbell(slot)
 finishPad(slot,0)
	local db = Map.Bases[slot].dumbbell
	local old = db:FindFirstChild("ArtVisual")
	db:SetAttribute("ArtKey", nil)
	if old then old:Destroy() end
end

local function dressDumbbell(s)
	clearDumbbell(s.slot)
	local base = Map.Bases[s.slot]
	local db = base.dumbbell
	finishPad(s.slot,s.d.dumbLevel)
	local key = Art.BellKey(s.d.dumbLevel)
	local model = Art.Fallback(key, CFrame.identity)
	if model then
		local _, size = model:GetBoundingBox()
		db.Position = Vector3.new(db.Position.X, base.gym.Position.Y - .15 + size.Y / 2, db.Position.Z)
		model:Destroy()
	end
	Art.Attach(key, db)
	db:SetAttribute("ArtKey", key)
end

-- ===== Player actions (Request:InvokeServer(action, arg)) =====
local actions = {}
local COOLDOWN = { GodMode=.5, GodGear=.2, GodCatalog=.2, OwnerBoost = .4, AssetsReady = .4, Settings = 0.2, Sync = 0.5, TrainStart = 0.5, TrainStop = 0.2, Equip = 0.15, Sell = 0.15, EquipBest = 0.5, SellRarity = 0.5, Cue = 0.3, UpDumb = 0.3, Daily = 1, Playtime = 0.5, Pass = 1, Product = 1, Tutorial = 0.2 }

function actions.OwnerBoost(plr,s,enabled)
 if not isOwner(plr) or type(enabled) ~= "boolean" then return false end
 s.ownerBoost = enabled
 return true
end
local function godCatalog(s)
 local inventory={}
 for _,it in s.d.inv do
  if not it.catalog or it.eq then table.insert(inventory,it) end
 end
 for design=1,C.DesignCount do
  if #inventory>=C.MaxInventory then break end
  local item={id=s.godSection,section=s.godSection,design=design,v=s.godVariant,catalog=true}
  table.insert(inventory,item)
 end
 s.d.inv=inventory
end

function actions.GodMode(plr,s,on)
 if not isOwner(plr) or type(on)~="boolean" then return false end
 if (s.god~=nil)==on then return true end
 if s.training or s.shotRoot or os.clock()<s.nextThrow then return false,"Finish your shot or training first" end
 if on then
  s.god={d=s.d,passes=s.passes,claimed=s.claimed}
  local d=default()
  d.cash,d.strength,d.cue,d.dumbLevel,d.best,d.tutorial=1e25,math.max(s.d.strength,C.OwnerStrength*8),#C.Cues,C.DumbbellMax,N,4
  d.settings=table.clone(s.d.settings)
  s.d,s.claimed,s.passes=d,{},table.clone(s.passes)
  for _,pass in C.GamePasses do s.passes[pass.key]=true end
  s.godSection,s.godVariant=N,#C.Variants
  godCatalog(s)
 else
  s.d,s.passes,s.claimed=s.god.d,s.god.passes,s.god.claimed
  s.god,s.godSection,s.godVariant=nil,nil,nil
 end
 dressDumbbell(s)
 refreshBase(plr)
 giveCue(plr,false)
 return true
end

function actions.GodGear(plr,s,key)
 if not s.god or not isOwner(plr) or s.training or s.shotRoot or os.clock()<s.nextThrow then return false end
 if key=="cue" then
  s.d.cue=s.d.cue%#C.Cues+1
  s.passes.DragonCue=false
  giveCue(plr,false)
 elseif key=="bell" then
  s.d.dumbLevel=s.d.dumbLevel%C.DumbbellMax+1
  dressDumbbell(s)
 else return false end
 return true
end

function actions.GodCatalog(plr,s,key)
 if not s.god or not isOwner(plr) then return false end
 if key=="next" then s.godSection=s.godSection%N+1
 elseif key=="prev" then s.godSection=(s.godSection-2)%N+1
 elseif key=="edition" then s.godVariant=s.godVariant%#C.Variants+1
 else return false end
 godCatalog(s)
 return true
end
function actions.Sync() return true end
function actions.AssetsReady(plr, s)
	s.ready = true
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if root and root:GetAttribute("LoadingHold") then
		root:SetAttribute("LoadingHold", nil)
		root.Anchored = false
	end
	return true
end

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

local function drawDesign(d,section)
 local key=tostring(section)
 local deck=d.decks[key]
 if not deck or deck.used==C.DesignCount then
  local last=deck and deck.order[deck.used]
  local order=table.create(C.DesignCount)
  for n=1,C.DesignCount do order[n]=n end
  for n=#order,2,-1 do
   local k=rng:NextInteger(1,n)
   order[n],order[k]=order[k],order[n]
  end
  if order[1]==last then order[1],order[2]=order[2],order[1] end
  deck={order=order,used=0}
  d.decks[key]=deck
 end
 deck.used+=1
 return deck.order[deck.used]
end
local nextBreak=0
function actions.Throw(plr, s, power)
	if type(power) ~= "number" or power ~= power or power < 0 or power > 1
		or not s.ready or s.training or s.shotRoot or os.clock() < s.nextThrow then return false end
	local char = plr.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (root and hum and hum.Health > 0 and C.InShotZone(root.Position)) then
		return false, "Approach the shooting line"
	end
	if #s.d.inv >= C.MaxInventory then return false, "Inventory is full. Sell someone first" end
	if workspace:GetServerTimeNow()<nextBreak then return false,"The rack is resetting" end
	local dist = C.Distance(math.clamp(power, 0, 1), playData(s), s.passes)
	local zone = C.ZoneOf(dist)
	-- luck grows along the path: the client shows the same track live while the ball rolls
	local luck0 = C.StartLuck(s.d, s.passes)
	local track, lucky = C.LuckTrack(luck0, zone, function() return rng:NextNumber() end)
	local L = track[zone]
	local rarity = math.min(zone + C.LuckBonus(L, rng:NextNumber(), rng:NextNumber(), rng:NextNumber()), N)
	local full = not s.d.settings.short and rarity >= C.FullCinematicRarity and rarity >= s.d.best - 2 -- the big show only for top pulls
	s.d.best = math.max(s.d.best, rarity)
	local animation = C.AnimOf(full)
	local started = workspace:GetServerTimeNow() + .32
	local impactAt = started + animation.Windup
	nextBreak=impactAt+2.05
	local total = C.ThrowTime(dist, full)
	local stance = ShotPose.Origin(char, s.slot)
	s.nextThrow = os.clock() + .32 + total + C.ThrowCooldown
	s.shotRoot = root
	local previousAnchored = root.Anchored
	local approachOrigin = root.CFrame
	root.Anchored = true
	local approach = math.min(.35, animation.Windup * .35)
	task.delay(.32, function()
		if s.shotRoot == root and root.Parent then
			TweenService:Create(root, TweenInfo.new(approach, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = stance }):Play()
		end
	end)
	task.delay(.32 + animation.Windup + .32, function()
		if s.shotRoot == root then
			s.shotRoot = nil
			if root.Parent then root.CFrame = approachOrigin; root.Anchored = previousAnchored end
		end
	end)
	local it = { id = rarity, section=zone, design=drawDesign(s.d,zone), v = C.RollVariant(rng:NextNumber(),L) }
	throwCounter += 1
	it.eq = equippedCount(s.d) < C.MaxEquipped
	it.tid = it.eq and throwCounter or nil
	table.insert(s.d.inv, it)
	s.d.found[C.DiscoveryKey(it)] = true
	if zone == #C.Tables then s.auraAt = os.clock() + 30 end -- the super aura lights up once the grand finale has played
	local luckyList = {}
	for k in lucky do table.insert(luckyList, k) end
	Fx:FireAllClients("Throw", {
		slot = s.slot, uid = plr.UserId, dist = dist, id = it.id, section=it.section, design=it.design, v = it.v, track = track, lucky = luckyList,
		tid = it.tid or 0, full = full, gold = s.passes.GoldenBall == true, luck0 = luck0,
		cue = select(2, currentCue(s)), dragon = currentCue(s) == C.DragonCue,
		started = started, impactAt = impactAt, stance = stance, power = power,
	})
	task.delay(.32 + total, refreshBase, plr)
	if s.d.tutorial == 1 then s.d.tutorial = 2 end
	return true
end

-- Training: Start/Stop, the server adds strength every rep while the player stays at the gym
local function near(plr, s)
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	return root and hum and hum.Health > 0 and (root.Position - Map.Bases[s.slot].gym.Position).Magnitude <= C.GymRange
end

local function stopTraining(plr, s)
	if not s.training then return end
	s.training = false
	local root = s.trainRoot
	if root and root.Parent then root.Anchored = s.trainAnchored end
	s.trainRoot = nil
	if s.trainGrip then s.trainGrip:Destroy(); s.trainGrip=nil end
 local char=plr.Character
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 if root and char and root.Parent==char and hum and hum.Health>0 and not s.closing then giveCue(plr,false) end
	if plr.Parent == Players then Fx:FireClient(plr, "Train", false) end
end

function actions.TrainStart(plr, s)
	if s.training then return true end
	if not s.ready or s.shotRoot then return false end
	if not near(plr, s) then return false, "Go to the dumbbell at your base" end
	local char=plr.Character
 local hand=char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
 if not hand then return false end
 local key=Art.BellKey(s.d.dumbLevel)
 local grip=Instance.new("Part")
 grip.Name,grip.Size,grip.Transparency="TrainingGrip",Vector3.one*.12,1
 grip.CanTouch,grip.CanQuery,grip.CastShadow=false,false,false
 local socket=hand:FindFirstChild("RightGripAttachment")
 local palm=socket and socket:IsA("Attachment") and socket.CFrame or CFrame.new(0,-hand.Size.Y*.38,0)
 if hand.Name=="Right Arm" then
  local p=palm.Position
  palm=CFrame.new(p.X,math.clamp(p.Y,-hand.Size.Y*.39,hand.Size.Y*.39),p.Z)*palm.Rotation
 end
 grip.Massless,grip.CanCollide=true,false
 grip.CFrame=hand.CFrame*palm
 -- All fifty Blender handles run along local X, centred on the model origin.
 local heldScale=math.clamp(hand.Size.X/2.2,.24,1.4)
 if not Art.Attach(key,grip,heldScale) then grip:Destroy();return false,"Equipment is loading" end
 local mount=Instance.new("Motor6D")
 mount.Name,mount.Part0,mount.Part1,mount.C0="PalmMount",hand,grip,palm
 mount.Parent=grip
 local old=char:FindFirstChild("Cue")
 if old then old:Destroy() end
 s.trainGrip=grip
 s.training = true
 s.trainId = (s.trainId or 0) + 1
	local id, reps = s.trainId, 0 -- a quick Stop + Start never runs two rep loops
	local base = Map.Bases[s.slot]
	local root = plr.Character.HumanoidRootPart
	s.trainRoot, s.trainAnchored = root, root.Anchored
	root.Anchored = true
	local pos = Vector3.new(base.gym.Position.X, root.Position.Y, base.gym.Position.Z)
	root.CFrame = CFrame.lookAt(pos, Vector3.new(base.dumbbell.Position.X, pos.Y, base.dumbbell.Position.Z))
	local startAt = workspace:GetServerTimeNow() + .25
	grip:SetAttribute("StartAt",startAt)
 grip:SetAttribute("Tier",s.d.dumbLevel)
 local floor=Instance.new("ObjectValue")
 floor.Name,floor.Value,floor.Parent="Floor",base.dumbbell,grip
 grip.Parent=char
	Fx:FireClient(plr, "Train", true)
	task.spawn(function()
		task.wait(math.max(0, startAt - workspace:GetServerTimeNow()))
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
			Fx:FireClient(plr, "Rep", playData(s).strength, gain, reps)
		end
	end)
	return true
end

function actions.TrainStop(plr, s)
	stopTraining(plr, s)
	return true
end

function actions.UpDumb(plr, s)
 if not near(plr,s) then return false,"Step onto your training pad" end
	if s.training then return false, "Finish training before upgrading" end
	if s.d.dumbLevel >= C.DumbbellMax then return false, "Maximum level" end
	if not pay(s, C.LiftCost(s.d.dumbLevel)) then return false, "Not enough cash" end
	s.d.dumbLevel += 1
	dressDumbbell(s)
	return true, "Dumbbell level " .. s.d.dumbLevel
end

-- Cues are an upgrade path: you can only buy the next tier, and the new cue replaces the old one
function actions.Cue(plr, s)
 local char=plr.Character
 local root=char and char:FindFirstChild("HumanoidRootPart")
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 if not root or not hum or hum.Health<=0 or (root.Position-Map.Bases[s.slot].shopZone.Position).Magnitude>10 then return false,"Visit your cue shop" end
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
	earn(s,price)
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
	earn(s,total)
	return true, "Sold " .. n .. " for $" .. C.Short(total)
end

function actions.Daily(_, s)
	local day = os.time() // 86400
	local dd = s.d.daily
	if dd.day == day then return false, "Come back tomorrow" end
	dd.streak = (dd.day == day - 1) and dd.streak % #C.Daily + 1 or 1
	dd.day = day
	earn(s,C.Daily[dd.streak])
	return true, "+$" .. C.Short(C.Daily[dd.streak])
end

function actions.Playtime(_, s, i)
	local p = type(i) == "number" and C.Playtime[i]
	if not p or s.claimed[i] then return false end
	if os.time() - s.join < p[1] * 60 then return false, "Not yet" end
	s.claimed[i] = true
	earn(s,p[2])
	return true, "+$" .. C.Short(p[2])
end

function actions.Pass(plr, s, key)
 if s.god then return false end
	local gp = passByKey[key]
	if not gp then return false end
	if gp.id <= 0 then return false, "Set the Game Pass ID in Config" end
	MarketplaceService:PromptGamePassPurchase(plr, gp.id)
	return true
end

function actions.Product(plr, s, i)
 if s.god then return false end
	local p = type(i) == "number" and C.Products[i]
	if not p then return false end
	if p.id <= 0 then return false, "Set the Product ID in Config" end
	MarketplaceService:PromptProductPurchase(plr, p.id)
	return true
end

Request.OnServerInvoke = function(plr, action, arg)
	local s, fn = sessions[plr], actions[action]
	if not (s and fn) or s.closing or (not s.ready and action ~= "Sync" and action ~= "AssetsReady") then return false end
	local now = os.clock()
	if now - (s.last[action] or 0) < (COOLDOWN[action] or 0) then return false end
	s.last[action] = now
	local ok, msg = fn(plr, s, arg)
	sync(plr)
	return ok, msg
end

-- ===== Players =====
local function onCharacter(plr, slot, char)
	local s = sessions[plr]
	if not s then return end
	stopTraining(plr, s)
	s.shotRoot = nil
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not root or plr.Character ~= char then return end
	char:PivotTo(Map.Bases[slot].spawn * CFrame.new(0, 3, 0))
	if not s.ready then
		root:SetAttribute("LoadingHold", true)
		root.Anchored = true
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = 19.2 end
	if hum then hum.Died:Once(function()
		if sessions[plr] == s and plr.Character == char then
			stopTraining(plr, s)
			if s.shotRoot == root then s.shotRoot = nil; root.Anchored = false end
		end
	end) end
	if not char:FindFirstChild("Right Arm") then char:WaitForChild("RightHand", 8) end
	if plr.Character == char then giveCue(plr, false) end
end

local function secondsPlayed(s)
 return (s.god or s).d.playedSeconds + math.max(0,(s.leftAt or os.time())-s.join)
end
local function persist(plr, s, release)
	if not s or not s.loaded then return not release or (s and s.studio) end
	while s.saving do task.wait(.06) end
	if s.released then return release == true end
	if s.closing and not release then return false end
	s.saving = true
	local profile=s.god or s
 local copy = table.clone(profile.d)
 copy.decks={}
 for key,deck in profile.d.decks do copy.decks[key]={used=deck.used,order=table.clone(deck.order)} end
 copy.playedSeconds = secondsPlayed(s)
	copy.inv, copy.found, copy.receipts = {}, table.clone(profile.d.found), table.clone(profile.d.receipts)
	for i, it in profile.d.inv do copy.inv[i] = { id = it.id, section=it.section, design=it.design, v = it.v, eq = it.eq } end
	copy.settings, copy.daily = table.clone(profile.d.settings), table.clone(profile.d.daily)
	copy.version, copy.savedAt, copy.savedIncome = DATA_VERSION, os.time(), incomeFor(profile.d,profile.passes)
	local committed = false
	for attempt = 1, 3 do
		local ok, result = pcall(Save.Commit, store, tostring(plr.UserId), s.token, copy, release, os.time)
		if ok then
			committed = result == true
			if not committed and not release and plr.Parent then plr:Kick("Session expired. Please rejoin.") end
			break
		end
		task.wait(attempt)
	end
	if committed then Rank.queue(plr.UserId,copy) end
 if release and committed then s.released = true end
	s.saving = false
	if not committed then warn("[Billiard save]", plr.UserId, release and "release" or "checkpoint") end
	return committed
end

local function onPlayer(plr)
	local slot
	for i = 1, #Map.Bases do
		if not taken[i] then slot = i; break end
	end
	if not slot then plr:Kick("Server is full"); return end
	taken[slot] = plr

	local function holdDuringLoad(char)
		local root = char:WaitForChild("HumanoidRootPart", 8)
		if root and not sessions[plr] and plr.Character == char then
			root:SetAttribute("LoadingHold", true)
			root.Anchored = true
		end
	end
	local hold = plr.CharacterAdded:Connect(holdDuringLoad)
	if plr.Character then task.spawn(holdDuringLoad, plr.Character) end

	local passes = {}
	for _, gp in C.GamePasses do
		if gp.id > 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, plr.UserId, gp.id)
			passes[gp.key] = ok and owns
		end
	end
	local token = HttpService:GenerateGUID(false)
	local d, amount, elapsed, failure
	for attempt = 1, 3 do
		if not plr.Parent then break end
		local ok, got, cash, timeOffline = pcall(Save.Acquire, store, tostring(plr.UserId), token, sanitize, function(data)
			return incomeFor(data, passes)
		end, os.time)
		if ok and got then d, amount, elapsed = sanitize(got), cash, timeOffline; break end
		failure = not ok
		if attempt < 3 then task.wait(attempt) end
	end
	local studio = not d and RunService:IsStudio() and (not okStore or failure)
	hold:Disconnect()
	if not d and not studio then
		taken[slot] = nil
		if plr.Parent then plr:Kick(failure and "Save service unavailable. Try again." or "Previous session is saving. Please retry.") end
		return
	end
	local s = {
		d = d or default(), slot = slot, passes = passes, join = os.time(), claimed = {}, nextThrow = 0, last = {},
		token = token, loaded = d ~= nil, studio = studio, offlineAmount = amount or 0, offlineElapsed = elapsed or 0,
	}
	if not plr.Parent then
		persist(plr, s, true)
		taken[slot] = nil
		return
	end
	sessions[plr] = s
 Rank.live(plr,(s.god or s).d,secondsPlayed(s))

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local cash = Instance.new("NumberValue")
	cash.Name, cash.Parent = "Cash", ls
	ls.Parent = plr
	Map.SetOwner(slot, plr)
	plr.CharacterAdded:Connect(function(char) onCharacter(plr, slot, char) end)
	if plr.Character then task.spawn(onCharacter, plr, slot, plr.Character) end
	refreshBase(plr)
	dressDumbbell(s)
	sync(plr)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do task.spawn(onPlayer, p) end

local departing = {}
Players.PlayerRemoving:Connect(function(plr)
	local s = sessions[plr]
	if not s then return end
	s.closing = true
	s.leftAt=os.time()
 departing[plr] = s
	stopTraining(plr, s)
	sessions[plr] = nil
	Map.Bases[s.slot].chars:ClearAllChildren()
	clearDumbbell(s.slot)
	Map.SetOwner(s.slot, nil)
	taken[s.slot] = nil
	persist(plr, s, true)
	departing[plr] = nil
end)

game:BindToClose(function()
	local left = 0
	for plr, s in sessions do
		s.closing = true
		left += 1
		task.spawn(function()
			persist(plr, s, true)
			left -= 1
		end)
	end
	local t0 = os.clock()
	while (left > 0 or next(departing)) and os.clock() - t0 < 25 do task.wait(.15) end
 RS.ClubScores:SetAttribute("ProfilesClosed",true)
end)


MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, id, bought)
	local s = sessions[plr]
	if not (s and bought) then return end
	local key
	for _, gp in C.GamePasses do
		if gp.id == id then
			(s.god or s).passes[gp.key] = true
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
	local profile=s.god or s
 if not table.find(profile.d.receipts, info.PurchaseId) then
		for _, p in C.Products do
			if p.id == info.ProductId then profile.d.cash += p.cash end
		end
		table.insert(profile.d.receipts, info.PurchaseId)
		if #profile.d.receipts > 50 then table.remove(profile.d.receipts, 1) end
		sync(plr)
	end
	if not persist(plr, s, false) then return Enum.ProductPurchaseDecision.NotProcessedYet end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ===== Income every second and a checkpoint each minute =====
task.spawn(function()
	local t = 0
	while true do
		task.wait(1)
		t += 1
		for plr, s in sessions do
			local profile=s.god or s
   earn(profile,incomeFor(profile.d,profile.passes))
            Rank.live(plr,(s.god or s).d,secondsPlayed(s))
			plr.leaderstats.Cash.Value = math.floor((s.god or s).d.cash)
			Fx:FireClient(plr, "Cash", s.d.cash)
		end
		if t % 60 == 0 then
			for plr, s in sessions do task.spawn(persist, plr, s, false) end
		end
	end
end)

-- ===== Super aura: owners of a grand-finale ball (last table) glow for everyone, on every character =====
local function superAura(root)
	local f = Instance.new("Folder")
	f.Name = "SuperAura"
	local RAINBOW = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)), ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 140)), ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 90, 255)),
	})
	local feet = Instance.new("Attachment")
	feet.Name, feet.Position, feet.Parent = "AuraFeet", Vector3.new(0, -2.8, 0), root
	local core = Instance.new("Attachment")
	core.Name, core.Parent = "AuraCore", root
	local rise = Instance.new("ParticleEmitter") -- rainbow embers rising around the body
	rise.Color, rise.LightEmission, rise.Rate = RAINBOW, 1, 45
	rise.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	rise.Transparency = NumberSequence.new(0.1, 1)
	rise.Lifetime, rise.Speed = NumberRange.new(1, 1.8), NumberRange.new(4, 8)
	rise.SpreadAngle, rise.Shape, rise.ShapeInOut = Vector2.new(8, 8), Enum.ParticleEmitterShape.Cylinder, Enum.ParticleEmitterShapeInOut.Outward
	rise.EmissionDirection, rise.Parent = Enum.NormalId.Top, feet
	local spark = Instance.new("ParticleEmitter") -- white star sparkles
	spark.Color, spark.LightEmission, spark.Rate = ColorSequence.new(Color3.new(1, 1, 1)), 1, 18
	spark.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) })
	spark.Lifetime, spark.Speed, spark.SpreadAngle = NumberRange.new(0.5, 0.9), NumberRange.new(2, 5), Vector2.new(180, 180)
	spark.Parent = core
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Parent = Color3.fromRGB(255, 220, 150), 2.5, 14, core
	for k = 1, 2 do -- two curved rainbow arcs around the body
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(-2.2, -1.5 + k * 1.4, 0), Vector3.new(2.2, -1.5 + k * 1.4, 0)
		a0.Parent, a1.Parent = root, root
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1, b.Color, b.LightEmission = a0, a1, RAINBOW, 1
		b.CurveSize0, b.CurveSize1, b.Width0, b.Width1, b.FaceCamera, b.Segments = 3, -3, 0.35, 0.35, true, 16
		b.Transparency = NumberSequence.new(0.2)
		b.TextureSpeed, b.Parent = 1, f
		local mirror = b:Clone()
		mirror.CurveSize0, mirror.CurveSize1, mirror.Parent = -3, 3, f
	end
	f.Parent = root
end
task.spawn(function()
	while true do
		task.wait(1.5)
		for plr, s in sessions do
			local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			if root and not root:FindFirstChild("SuperAura") and os.clock() >= (s.auraAt or 0) then
				for _, it in s.d.inv do
					if it.section == #C.Tables then
						superAura(root)
						plr:SetAttribute("SuperAura", true)
						break
					end
				end
			end
		end
	end
end)
