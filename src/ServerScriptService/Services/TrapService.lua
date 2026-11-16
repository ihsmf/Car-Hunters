-- Throw platform upgrades (v24): Lv1..10, each level adds luck (TrapConfig.LuckMult) and a new look
-- (BaseService.applyTrapLevel). Bought at your own trap (throw menu or the "Upgrade Platform" prompt).
--   Trap.Upgrade(player)  -> remote "UpgradeTrap"
--   Trap.Level(s)         -> 1..10
--   Trap.LuckMult(s)      -> x1.00 .. x1.54, read by Shop.LuckMult
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local BaseLayout = require(Shared:WaitForChild("BaseLayout"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local TrapConfig = require(Shared:WaitForChild("TrapConfig"))

local Trap = {}
local S

function Trap.Init(hub)
	S = hub
end

function Trap.Level(s)
	return TrapConfig.Clamp(s and s.data and s.data.trapLevel or 1)
end

function Trap.LuckMult(s)
	return TrapConfig.LuckMult(Trap.Level(s))
end

-- same rule as a throw: standing near your own trap
local function nearOwnTrap(player, s)
	if not s.baseIndex then
		return false
	end
	local hrp = S.Data.GetRoot(player)
	if not hrp then
		return false
	end
	local trap = BaseLayout.ToWorld(s.baseIndex, BaseLayout.TrapLocal)
	local flat = Vector3.new(hrp.Position.X - trap.X, 0, hrp.Position.Z - trap.Z)
	return flat.Magnitude <= EconomyConfig.ThrowMaxDistance
end

function Trap.Upgrade(player)
	local s = S.Data.Get(player)
	if not s or not s.ready then
		return
	end
	if not S.Data.RateLimit(player, "trapUp", 0.4) then
		return
	end
	if not s.baseIndex then
		S.Data.Notify(player, "noBase", nil, "error")
		return
	end
	if not nearOwnTrap(player, s) then
		S.Data.Notify(player, "tooFar", nil, "warn")
		return
	end
	local d = s.data
	local cur = Trap.Level(s)
	local cost = TrapConfig.NextCost(cur)
	if not cost then
		S.Data.Notify(player, "maxLevel", nil, "warn")
		return
	end
	if d.money < cost then
		S.Data.Notify(player, "noMoney", nil, "error")
		return
	end
	d.money = d.money - cost
	d.trapLevel = cur + 1
	S.Data.Notify(player, "trapUp", { d.trapLevel, string.format("%.2f", TrapConfig.LuckMult(d.trapLevel)) }, "good")
	S.Base.RefreshAll(player)
	S.Data.Push(player)
	Net.Get("TrapUpgraded"):FireClient(player, d.trapLevel, s.baseIndex)
end

return Trap
