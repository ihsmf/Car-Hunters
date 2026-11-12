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
	highway = { cost = 60000, minValue = 15000 },
	industrial = { cost = 600000, minValue = 150000 },
	neon = { cost = 5000000, minValue = 600000 },
	scrapyard = { cost = 14000000, minValue = 900000 },
	-- Tier 2 needs a rebirth, Tier 3 three rebirths (RebirthService)
	docks = { cost = 60000000, minValue = 1000000, rebirths = 1 },
	desert = { cost = 180000000, minValue = 1200000, rebirths = 1 },
	bridge = { cost = 500000000, minValue = 1500000, rebirths = 1 },
	airport = { cost = 1500000000, minValue = 2000000, rebirths = 1 },
	canyon = { cost = 5000000000, minValue = 2500000, rebirths = 2 },
	circuit = { cost = 3.5e9, minValue = 2500000, rebirths = 3 },
	drift = { cost = 8e9, minValue = 2500000, rebirths = 3 },
	storm = { cost = 1.6e10, minValue = 2500000, rebirths = 3 },
	rush = { cost = 3e10, minValue = 2500000, rebirths = 3 },
	colosseum = { cost = 5e10, minValue = 2500000, rebirths = 3 },
}

EconomyConfig.SellFraction = 0.35
EconomyConfig.DiscoverBonusMult = 1.0
EconomyConfig.IndexTierBonus = 0.05
EconomyConfig.IndexFullBonus = 0.10
EconomyConfig.PityThreshold = 120
EconomyConfig.MaxLuckShift = 0.15 -- all luck sources together

EconomyConfig.ThrowCooldown = 0.8
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
