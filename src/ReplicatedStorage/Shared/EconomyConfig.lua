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
EconomyConfig.FloorCosts = { [2] = 250000, [3] = 5000000, [4] = 80000000 }
EconomyConfig.SlotCosts = {}
do
	local floorBase = { 1500, 30000, 600000, 10000000 }
	for slot = 4, 24 do
		local floor = math.floor((slot - 1) / 6) + 1
		local i = (slot - 1) % 6 - ((floor == 1) and 3 or 0)
		EconomyConfig.SlotCosts[slot] = math.floor(floorBase[floor] * 1.6 ^ i / 50 + 0.5) * 50
	end
end

-- tuned with tools/econ_sim.py (see docs/ECONOMY.md). minValue = collection value gate (keeps players from rushing)
EconomyConfig.ZoneUnlock = {
	highway = { cost = 120000, minValue = 15000 },
	industrial = { cost = 1000000, minValue = 150000 },
	neon = { cost = 14000000, minValue = 600000 },
	scrapyard = { cost = 70000000, minValue = 900000 },
	-- Tier 2 needs a rebirth, Tier 3 three rebirths (RebirthService)
	docks = { cost = 100000000, minValue = 1000000, rebirths = 1 },
	desert = { cost = 310000000, minValue = 1200000, rebirths = 1 },
	bridge = { cost = 850000000, minValue = 1500000, rebirths = 1 },
	airport = { cost = 2.6e+09, minValue = 2000000, rebirths = 1 },
	canyon = { cost = 8.5e+09, minValue = 2500000, rebirths = 2 },
	circuit = { cost = 6e+09, minValue = 2500000, rebirths = 3 },
	drift = { cost = 1.4e+10, minValue = 2500000, rebirths = 3 },
	storm = { cost = 2.7e+10, minValue = 2500000, rebirths = 3 },
	rush = { cost = 5.1e+10, minValue = 2500000, rebirths = 3 },
	colosseum = { cost = 8.5e+10, minValue = 2500000, rebirths = 3 },
}

EconomyConfig.SellFraction = 0.35
EconomyConfig.DiscoverBonusMult = 1.0
EconomyConfig.IndexTierBonus = 0.05
EconomyConfig.IndexFullBonus = 0.10
EconomyConfig.PityThreshold = 40 -- v13: counted per car caught (1 car per throw at the start)
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
