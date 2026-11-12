-- Rebirth (classic reset for a permanent income bonus + tokens) and garage skins.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkinConfig = require(Shared:WaitForChild("SkinConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))

local Rebirth = {}
local S

function Rebirth.Init(hub)
	S = hub
end

function Rebirth.IncomeMult(s)
	local d = s and s.data
	if not d then
		return 1
	end
	local skin = SkinConfig.ById[d.skin]
	return (1 + SkinConfig.Rebirth.incomePer * (d.rebirths or 0)) * (1 + (skin and skin.bonus or 0))
end

function Rebirth.PerkLevel(s, id)
	return s and s.data and s.data.tokenPerks and s.data.tokenPerks[id] or 0
end

function Rebirth.Can(s)
	local d = s.data
	local zone, money = SkinConfig.RebirthNeeds(d.rebirths or 0)
	return d.unlockedZones[zone] == true and d.money >= money, zone, money
end

function Rebirth.Do(player)
	local s = S.Data.Get(player)
	if not s or not s.ready or not S.Data.RateLimit(player, "rebirth", 2) then
		return
	end
	local ok, _, money = Rebirth.Can(s)
	if not ok then
		S.Data.Notify(player, "rebirthNotYet", nil, "warn")
		return
	end
	local d = s.data
	local tokens = math.min(5, math.floor(d.money / money)) -- 1 token, more for overshooting the target
	d.rebirths = (d.rebirths or 0) + 1
	d.tokens = (d.tokens or 0) + tokens
	-- what burns: money, cars, parts, districts, floors/bays, tuning box
	d.money = SkinConfig.Rebirth.startMoney * d.rebirths
	d.cars = {}
	for id in pairs(d.parts) do
		d.parts[id] = 0
	end
	d.parts.bolts = 3
	d.unlockedZones = { city = true }
	d.floors = 1
	d.garageSlotCount = EconomyConfig.StartSlots + Rebirth.PerkLevel(s, "startSlot")
	d.tuning = {}
	d.contracts = {}
	d.pity = 0
	s.carried = {}
	s.carriedZones = {}
	S.Data.Notify(player, "reborn", { d.rebirths, tokens }, "good")
	S.Contracts.Fill(s)
	S.Income.Recalc(player)
	S.Base.RefreshAll(player)
	S.Data.Push(player)
	local hum = select(2, S.Data.GetRoot(player))
	if hum then
		hum.Health = 0 -- respawn at the (now empty) garage
	end
end

local function ownsSkin(s, def)
	return s.data.skins[def.id] or (def.pass and S.Shop.HasPass(s, def.pass))
end

-- buy if needed, then equip
function Rebirth.Skin(player, id)
	local s = S.Data.Get(player)
	local def = type(id) == "string" and SkinConfig.ById[id]
	if not s or not s.ready or not def or not S.Data.RateLimit(player, "skin", 0.5) then
		return
	end
	local d = s.data
	if not ownsSkin(s, def) then
		if def.pass then
			S.Donate.Request(player, def.pass)
			return
		elseif def.tokens then
			if d.tokens < def.tokens then
				S.Data.Notify(player, "noTokens", nil, "error")
				return
			end
			d.tokens = d.tokens - def.tokens
		elseif def.money then
			if d.money < def.money then
				S.Data.Notify(player, "noMoney", nil, "error")
				return
			end
			d.money = d.money - def.money
		end
		d.skins[def.id] = true
	end
	d.skin = def.id
	S.Data.Notify(player, "skinOn", { def.name }, "good")
	S.Income.Recalc(player)
	S.Base.RefreshAll(player)
	S.Data.Push(player)
end

function Rebirth.TokenPerk(player, id)
	local s = S.Data.Get(player)
	local def = type(id) == "string" and SkinConfig.TokenPerkById[id]
	if not s or not s.ready or not def or not S.Data.RateLimit(player, "tperk", 0.4) then
		return
	end
	local d = s.data
	local lvl = d.tokenPerks[id] or 0
	if lvl >= def.max then
		S.Data.Notify(player, "maxLevel", nil, "warn")
		return
	end
	if d.tokens < def.cost then
		S.Data.Notify(player, "noTokens", nil, "error")
		return
	end
	d.tokens = d.tokens - def.cost
	d.tokenPerks[id] = lvl + 1
	if id == "startSlot" then
		d.garageSlotCount = math.min(d.garageSlotCount + 1, d.floors * 6)
		S.Base.RefreshAll(player)
	end
	S.Data.Notify(player, "perkBought", { def.name, lvl + 1 }, "good")
	S.Data.Push(player)
end

return Rebirth
