-- Teleport buttons: home garage or any unlocked district. Server-validated.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("MapConfig"))
local BaseLayout = require(Shared:WaitForChild("BaseLayout"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))

local Warp = {}
local S

function Warp.Init(hub)
	S = hub
end

function Warp.Go(player, dest)
	if type(dest) ~= "string" then
		return
	end
	local s = S.Data.Get(player)
	if not s or not s.ready or s.busy then
		return
	end
	local hrp = S.Data.GetRoot(player)
	if not hrp then
		return
	end
	if not S.Data.RateLimit(player, "warp", EconomyConfig.TeleportCooldown) then
		S.Data.Notify(player, "tpWait", nil, "warn")
		return
	end
	local target
	if dest == "home" then
		if not s.baseIndex then
			return
		end
		-- loot must be carried home on foot: no risk-free escape
		if S.Inventory.CarriedTotal(s) > 0 then
			S.Data.Notify(player, "carryWalk", nil, "warn")
			return
		end
		target = BaseLayout.ToWorld(s.baseIndex, BaseLayout.SpawnLocal) + Vector3.new(0, 4, 0)
	elseif MapConfig.Zones[dest] then
		if not S.Zone.IsUnlocked(s, dest) then
			S.Data.Notify(player, "zoneLocked", nil, "warn")
			return
		end
		target = MapConfig.ZoneSpawn(dest) + Vector3.new(math.random(-8, 8), 0, 0)
	else
		return
	end
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.CFrame = CFrame.new(target, target + Vector3.new(0, 0, 1))
	S.Traffic.Protect(player, 1.5)
	S.Data.Notify(player, "teleported", nil, "good")
end

return Warp
