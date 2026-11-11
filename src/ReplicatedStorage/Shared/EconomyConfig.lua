local EconomyConfig = {}

EconomyConfig.StarterParts = { bolts = 2 }
EconomyConfig.CarryCapacity = 20
EconomyConfig.DeathLossFraction = 1.0 -- one hit = whole run lost
EconomyConfig.MaxCars = 200
EconomyConfig.MaxMoney = 1e15
EconomyConfig.StartSlots = 3
EconomyConfig.MaxSlots = 12
EconomyConfig.MaxPlayers = 8

EconomyConfig.SlotCosts = {
	[4] = 1500, [5] = 4000, [6] = 10000, [7] = 25000, [8] = 60000,
	[9] = 150000, [10] = 350000, [11] = 800000, [12] = 2000000,
}

EconomyConfig.ZoneUnlock = {
	highway = { cost = 16000, minValue = 7000 },
	industrial = { cost = 180000, minValue = 70000 },
	neon = { cost = 1000000, minValue = 400000 },
}

EconomyConfig.SellFraction = 0.35
EconomyConfig.DiscoverBonusMult = 1.0
EconomyConfig.IndexTierBonus = 0.05
EconomyConfig.IndexFullBonus = 0.10
EconomyConfig.PityThreshold = 40

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
