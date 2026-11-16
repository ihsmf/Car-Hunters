-- Throw platform (trap) upgrades: every level looks cooler and adds luck.
--   TrapConfig.MaxLevel           -> 10
--   TrapConfig.Costs[level]       -> price to go from level-1 to level (index 2..MaxLevel)
--   TrapConfig.LuckMult(level)    -> x(1 + 0.06 * (level - 1)): Lv1 x1.00 ... Lv10 x1.54
--   TrapConfig.Names[level]       -> what that level adds (Names[1] = the plain lift)
--   TrapConfig.NextCost(level)    -> price of the next level or nil at max
local TrapConfig = {}

TrapConfig.MaxLevel = 10
TrapConfig.LuckPerLevel = 0.06

-- economy (v24, tools/econ_sim.py): Lv2-7 in the first hour, Lv8-9 in R1, Lv10 is an R2/R3 trophy
TrapConfig.Costs = {
	[2] = 3000,
	[3] = 12000,
	[4] = 50000,
	[5] = 200000,
	[6] = 1000000,
	[7] = 6000000,
	[8] = 40000000,
	[9] = 300000000,
	[10] = 2500000000,
}

TrapConfig.Names = {
	"Steel lift",
	"Painted trims",
	"Lit edges",
	"Pylons",
	"Holo ring",
	"Sparks",
	"Sky beam",
	"Holo floor",
	"Energy dome",
	"Golden crown",
}

function TrapConfig.Clamp(level)
	return math.clamp(math.floor(tonumber(level) or 1), 1, TrapConfig.MaxLevel)
end

function TrapConfig.LuckMult(level)
	return 1 + TrapConfig.LuckPerLevel * (TrapConfig.Clamp(level) - 1)
end

function TrapConfig.NextCost(level)
	local l = TrapConfig.Clamp(level)
	if l >= TrapConfig.MaxLevel then
		return nil
	end
	return TrapConfig.Costs[l + 1]
end

return TrapConfig
