-- District checkpoints: at the far end of every district a player carrying loot chooses
--   SAVE & GO HOME  -> loot is banked right here and the player is teleported to the garage
--   RISK IT         -> teleported to the start of the next district (must be unlocked); loot stays at risk,
--                      the run's risk multiplier grows by +0.5 (applied when the loot is finally banked).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local MapConfig = require(Shared:WaitForChild("MapConfig"))
local BaseLayout = require(Shared:WaitForChild("BaseLayout"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))

local CP = {}
local S
local pads = {}
CP.RiskStep = 0.5
CP.MaxRisk = 4

function CP.Init(hub)
	S = hub
end

local function nextZone(zid)
	local i = MapConfig.ZoneIndex(zid)
	return MapConfig.ZoneOrder[i + 1]
end

local function offer(player, pad)
	local s = S.Data.Get(player)
	if not s or not s.ready or S.Inventory.CarriedTotal(s) <= 0 then
		return
	end
	local zid = pad:GetAttribute("ZoneId")
	local now = os.clock()
	if s.checkpoint and s.checkpoint.zone == zid and now - s.checkpoint.at < 6 then
		return
	end
	local nz = nextZone(zid)
	local open = nz ~= nil and S.Zone.IsUnlocked(s, nz)
	local req = nz and EconomyConfig.ZoneUnlock[nz]
	s.checkpoint = { zone = zid, at = now, pad = pad }
	local risk = (s.run and s.run.risk) or 1
	Net.Get("CheckpointOffer"):FireClient(player, {
		zone = zid, nextZone = nz, nextOpen = open, price = req and req.cost or nil,
		carried = S.Inventory.CarriedTotal(s), combo = (s.run and s.run.mult) or 1,
		risk = risk, nextRisk = math.min(CP.MaxRisk, risk + CP.RiskStep),
	})
end

function CP.Choose(player, choice)
	local s = S.Data.Get(player)
	local cp = s and s.checkpoint
	if not cp or not s.ready or (choice ~= "save" and choice ~= "risk") then
		return
	end
	s.checkpoint = nil
	local hrp = S.Data.GetRoot(player)
	if not hrp or (hrp.Position - cp.pad.Position).Magnitude > 60 or os.clock() - cp.at > 60 then
		return
	end
	if S.Inventory.CarriedTotal(s) <= 0 then
		return
	end
	if choice == "save" then
		S.Inventory.Bank(player)
		local target = BaseLayout.ToWorld(s.baseIndex, BaseLayout.SpawnLocal) + Vector3.new(0, 4, 0)
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.CFrame = CFrame.new(target, target + Vector3.new(0, 0, 1))
		S.Traffic.Protect(player, 1.5)
		Net.Get("CheckpointFx"):FireClient(player, { choice = "save" })
	else
		local nz = nextZone(cp.zone)
		if not nz or not S.Zone.IsUnlocked(s, nz) then
			S.Data.Notify(player, "zoneLocked", nil, "warn")
			return
		end
		s.run = s.run or { picked = 0, mult = 1 }
		s.run.risk = math.min(CP.MaxRisk, (s.run.risk or 1) + CP.RiskStep)
		local target = MapConfig.ZoneSpawn(nz) + Vector3.new(math.random(-6, 6), 0, 0)
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.CFrame = CFrame.new(target, target + Vector3.new(0, 0, 1))
		S.Traffic.Protect(player, 2.5)
		S.Data.Notify(player, "riskOn", { s.run.risk, MapConfig.Zones[nz].name }, "warn")
		Net.Get("CheckpointFx"):FireClient(player, { choice = "risk", risk = s.run.risk, zone = nz })
		S.Data.Push(player)
	end
end

function CP.Start()
	task.spawn(function()
		local map = workspace:WaitForChild("GeneratedMap", 60)
		if not map then
			return
		end
		local function hook(pad)
			if pads[pad] then
				return
			end
			pads[pad] = true
			pad.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player then
					offer(player, pad)
				end
			end)
		end
		for _, pad in ipairs(CollectionService:GetTagged("Checkpoint")) do
			hook(pad)
		end
		CollectionService:GetInstanceAddedSignal("Checkpoint"):Connect(hook)
	end)
end

return CP
