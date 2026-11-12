local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("MapConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))

local Zone = {}
local S

function Zone.Init(hub)
	S = hub
end

function Zone.IsUnlocked(s, zoneId)
	return zoneId == "plaza" or s.data.unlockedZones[zoneId] == true
end

function Zone.Unlock(player, zoneId)
	if type(zoneId) ~= "string" or not MapConfig.Zones[zoneId] then
		return
	end
	local s = S.Data.Get(player)
	if not s or not s.ready then
		return
	end
	if not S.Data.RateLimit(player, "zone", 0.5) then
		return
	end
	local d = s.data
	if d.unlockedZones[zoneId] then
		return
	end
	local idx = MapConfig.ZoneIndex(zoneId)
	local prev = MapConfig.ZoneOrder[idx - 1]
	if not prev or not d.unlockedZones[prev] then
		S.Data.Notify(player, "needPrev", nil, "warn")
		return
	end
	local req = EconomyConfig.ZoneUnlock[zoneId]
	if not req then
		return
	end
	if (d.rebirths or 0) < (req.rebirths or 0) then
		S.Data.Notify(player, "needRebirth", { req.rebirths }, "warn")
		return
	end
	if s.collectionValue < req.minValue then
		S.Data.Notify(player, "needValue", nil, "warn")
		return
	end
	if d.money < req.cost then
		S.Data.Notify(player, "noMoney", nil, "error")
		return
	end
	d.money = d.money - req.cost
	d.unlockedZones[zoneId] = true
	S.Data.Notify(player, "zoneUnlocked", { MapConfig.Zones[zoneId].name }, "good")
	S.Data.Push(player)
end

function Zone.Start()
	-- rivers etc.: touching a kill zone = wrecked (airbag can save you, then you respawn at the bank)
	local CollectionService = game:GetService("CollectionService")
	local function hookKill(part)
		part.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player and S.Traffic.Wreck(player, 0) then
				return
			end
			local hum = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
			if player and hum and hum.Health > 0 then
				-- airbag fired: pop the player back onto the nearest bank
				local hrp = hit.Parent:FindFirstChild("HumanoidRootPart")
				if hrp then
					local z = hrp.Position.Z
					local r = MapConfig.River
					local bank = (math.abs(z - r.z1) < math.abs(z - r.z2)) and r.z1 - 6 or r.z2 + 6
					hrp.CFrame = CFrame.new(hrp.Position.X, 4, bank)
				end
			end
		end)
	end
	for _, p in ipairs(CollectionService:GetTagged("KillZone")) do
		hookKill(p)
	end
	CollectionService:GetInstanceAddedSignal("KillZone"):Connect(hookKill)
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, player in ipairs(Players:GetPlayers()) do
				local s = S.Data.Get(player)
				if s and s.ready then
					local hrp = S.Data.GetRoot(player)
					if hrp then
						local zone = MapConfig.ZoneAt(hrp.Position.Z)
						if not Zone.IsUnlocked(s, zone) then
							local gate = MapConfig.GateOfZone(zone)
							local p = hrp.Position
							hrp.CFrame = CFrame.new(p.X, p.Y + 1, gate.z - 14)
							hrp.AssemblyLinearVelocity = Vector3.zero
							S.Data.Notify(player, "zoneLocked", nil, "warn")
						end
					end
				end
			end
		end
	end)
end

return Zone
