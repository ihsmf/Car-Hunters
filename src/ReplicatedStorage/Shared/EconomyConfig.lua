local EconomyConfig = {}

EconomyConfig.StarterParts = { bolts = 2 }
EconomyConfig.CarryCapacity = 20
EconomyConfig.DeathLossFraction = 1.0 -- one hit = whole run lost
EconomyConfig.MaxCars = 200
EconomyConfig.MaxMoney = 1e15
EconomyConfig.StartSlots = 3
EconomyConfig.MaxSlots = 24
EconomyConfig.MaxFloors = 4
EconomyConfig.MaxPlayers = 8

-- bay prices: each floor has its own base price, bays inside a floor get pricier (x1.6)
EconomyConfig.FloorCosts = { [2] = 60000, [3] = 1500000, [4] = 40000000 }
EconomyConfig.SlotCosts = {}
do
	local floorBase = { 1000, 12000, 250000, 4000000 }
	for slot = 4, 24 do
		local floor = math.floor((slot - 1) / 6) + 1
		local i = (slot - 1) % 6 - ((floor == 1) and 3 or 0)
		EconomyConfig.SlotCosts[slot] = math.floor(floorBase[floor] * 1.6 ^ i / 50 + 0.5) * 50
	end
end

-- tuned with tools/econ_sim.py (see docs/ECONOMY.md). minValue = collection value gate (keeps players from rushing)
EconomyConfig.ZoneUnlock = { -- v18 rebalance: each district ~10-60 min of income away; minValue is a soft check
	highway = { cost = 18000, minValue = 3000 },
	industrial = { cost = 200000, minValue = 30000 },
	neon = { cost = 1200000, minValue = 100000 },
	scrapyard = { cost = 3000000, minValue = 150000 },
	-- Tier 2 needs a rebirth, Tier 3 three rebirths (RebirthService); rebirths keep unlocked districts
	docks = { cost = 15000000, minValue = 250000, rebirths = 1 },
	desert = { cost = 40000000, minValue = 350000, rebirths = 1 },
	bridge = { cost = 90000000, minValue = 450000, rebirths = 1 },
	airport = { cost = 200000000, minValue = 550000, rebirths = 1 },
	canyon = { cost = 400000000, minValue = 650000, rebirths = 2 },
	circuit = { cost = 600000000, minValue = 750000, rebirths = 3 },
	drift = { cost = 1.1e+09, minValue = 900000, rebirths = 3 },
	storm = { cost = 1.8e+09, minValue = 1050000, rebirths = 3 },
	rush = { cost = 2.8e+09, minValue = 1200000, rebirths = 3 },
	colosseum = { cost = 4.2e+09, minValue = 1400000, rebirths = 3 },
}

EconomyConfig.SellFraction = 0.35
EconomyConfig.DiscoverBonusMult = 1.0
EconomyConfig.IndexTierBonus = 0.05
EconomyConfig.IndexFullBonus = 0.10
EconomyConfig.PityThreshold = 25 -- v13: counted per car caught (1 car per throw at the start)
EconomyConfig.MaxLuckShift = 0.15 -- all luck sources together

EconomyConfig.ThrowCooldown = 0.8
EconomyConfig.MaxBatch = 500 -- parts per throw (any amount: they add rarity points)
-- cars caught per throw: 1 at the start, +1 per "Multi Catch" level in the Pit Stop (ShopConfig), max 4
EconomyConfig.MaxCatch = 4
function EconomyConfig.CatchLimit(multiLevel)
	return math.clamp(1 + (tonumber(multiLevel) or 0), 1, EconomyConfig.MaxCatch)
end
EconomyConfig.MergeMaxLevel = 3 -- duplicates level a car up to this; beyond needs upgrades
EconomyConfig.ThrowAnimTime = 5.2
EconomyConfig.ThrowMaxDistance = 45
EconomyConfig.BaseActionDistance = 100
EconomyConfig.PickupRadius = 7
EconomyConfig.PickupCheckInterval = 0.15
EconomyConfig.SpawnProtection = 2.5
EconomyConfig.HitCooldown = 1.0
EconomyConfig.TrafficTickRate = 1 / 30
EconomyConfig.AutosaveInterval = 60
EconomyConfig.TeleportCooldown = 4
EconomyConfig.ActionCooldown = 0.12

return EconomyConfig
