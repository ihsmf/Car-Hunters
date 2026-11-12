local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local MapConfig = require(Shared:WaitForChild("MapConfig"))
local CarConfig = require(Shared:WaitForChild("CarConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))

Net.EnsureAll()

for _, e in ipairs(MapConfig.Validate()) do warn("[MapConfig]", e) end
for _, e in ipairs(CarConfig.Validate()) do warn("[CarConfig]", e) end

Players.CharacterAutoLoads = false
Players.RespawnTime = 3

pcall(function()
	Lighting.ClockTime = 14.3
	Lighting.Brightness = 2.3
	Lighting.Ambient = Color3.fromRGB(128, 124, 116)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 136, 124)
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.6
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GeographicLatitude = 30
	if not Lighting:FindFirstChild("CHAtmosphere") then
		local sky = Instance.new("Sky")
		sky.Name = "CHSky"
		sky.SunAngularSize = 14
		sky.MoonAngularSize = 9
		sky.StarCount = 4000
		sky.Parent = Lighting
		local a = Instance.new("Atmosphere")
		a.Name = "CHAtmosphere"
		a.Density = 0.26
		a.Offset = 0.15
		a.Color = Color3.fromRGB(200, 226, 255)
		a.Decay = Color3.fromRGB(150, 190, 230)
		a.Glare = 0.25
		a.Haze = 1.3
		a.Parent = Lighting
		local b = Instance.new("BloomEffect")
		b.Name = "CHBloom"
		b.Intensity = 0.45
		b.Size = 24
		b.Threshold = 1.15
		b.Parent = Lighting
		local r = Instance.new("SunRaysEffect")
		r.Name = "CHSunRays"
		r.Intensity = 0.05
		r.Spread = 0.6
		r.Parent = Lighting
		local c = Instance.new("ColorCorrectionEffect")
		c.Name = "CHColor"
		c.Saturation = 0.18
		c.Contrast = 0.06
		c.Brightness = 0.02
		c.Parent = Lighting
	end
end)

for _, name in ipairs({ "RuntimeTraffic", "RuntimeDrops" }) do
	if not Workspace:FindFirstChild(name) then
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = Workspace
	end
end

-- Blender models (uploaded via Open Cloud) must be in place before the map is built
pcall(function()
	require(ServerScriptService:WaitForChild("Services"):WaitForChild("ModelService")).LoadAll()
end)

if not Workspace:FindFirstChild("GeneratedMap") then
	local ok, err = pcall(function()
		local Build = require(ServerStorage:WaitForChild("Tools"):WaitForChild("BuildCityMap"))
		Build.Build({ runtime = true })
	end)
	if not ok then
		warn("[CarHunters] MAP BUILD FAILED:", err)
	end
end

local Services = ServerScriptService:WaitForChild("Services")
local S = {}
local names = { Data = "DataService", Inventory = "InventoryService", Base = "BaseService", PartSpawn = "PartSpawnService",
	Traffic = "TrafficService", Capture = "CaptureService", Cars = "CarCollectionService", Income = "IncomeService",
	Upgrade = "UpgradeService", Zone = "ZoneService", Warp = "WarpService", Shop = "ShopService", Donate = "DonateService",
	HotDrop = "HotDropService", Contracts = "ContractService", Tuning = "TuningService", Mechanic = "MechanicService", Boss = "BossService", Rebirth = "RebirthService" }
for key, moduleName in pairs(names) do
	S[key] = require(Services:WaitForChild(moduleName))
end
for _, svc in pairs(S) do
	if svc.Init then svc.Init(S) end
end
for _, svc in pairs(S) do
	if svc.Start then svc.Start() end
end

Net.Get("ThrowPart").OnServerEvent:Connect(function(p, partId) S.Capture.Throw(p, partId) end)
Net.Get("PlaceCar").OnServerEvent:Connect(function(p, uid, slot) S.Cars.Place(p, uid, slot) end)
Net.Get("RemoveCar").OnServerEvent:Connect(function(p, uid) S.Cars.Remove(p, uid) end)
Net.Get("UpgradeCar").OnServerEvent:Connect(function(p, uid, lvl) S.Upgrade.UpgradeCar(p, uid, lvl) end)
Net.Get("BuySlot").OnServerEvent:Connect(function(p, n) S.Upgrade.BuySlot(p, n) end)
Net.Get("BuyFloor").OnServerEvent:Connect(function(p, n) S.Upgrade.BuyFloor(p, n) end)
Net.Get("UnlockZone").OnServerEvent:Connect(function(p, z) S.Zone.Unlock(p, z) end)
Net.Get("SellCar").OnServerEvent:Connect(function(p, uid) S.Cars.Sell(p, uid) end)
Net.Get("AutoPark").OnServerEvent:Connect(function(p) S.Cars.AutoPark(p) end)
Net.Get("Teleport").OnServerEvent:Connect(function(p, dest) S.Warp.Go(p, dest) end)
Net.Get("BuyPerk").OnServerEvent:Connect(function(p, id) S.Shop.Buy(p, id) end)
Net.Get("Donate").OnServerEvent:Connect(function(p, id) S.Donate.Request(p, id) end)
Net.Get("ClaimContract").OnServerEvent:Connect(function(p, id) S.Mechanic.Claim(p, id) end)
Net.Get("CraftTuning").OnServerEvent:Connect(function(p, id) S.Mechanic.Craft(p, id) end)
Net.Get("Rebirth").OnServerEvent:Connect(function(p) S.Rebirth.Do(p) end)
Net.Get("SetSkin").OnServerEvent:Connect(function(p, id) S.Rebirth.Skin(p, id) end)
Net.Get("TokenPerk").OnServerEvent:Connect(function(p, id) S.Rebirth.TokenPerk(p, id) end)
Net.Get("BossThrow").OnServerEvent:Connect(function(p) S.Boss.Throw(p) end)
Net.Get("TuneCar").OnServerEvent:Connect(function(p, uid, cat, item) S.Tuning.Set(p, uid, cat, item) end)

local function hookCharacter(player, char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	local sess = S.Data.Get(player)
	hum.WalkSpeed = sess and S.Shop.WalkSpeed(sess) or MapConfig.WalkSpeed
	hum.BreakJointsOnDeath = false -- the client ragdolls the body (DeathFx)
	S.Traffic.Protect(player, sess and S.Shop.SpawnShield(sess) or EconomyConfig.SpawnProtection)
	task.defer(function() S.Inventory.EnsureNotStuck(player) end)
	hum.Died:Connect(function()
		S.Inventory.OnDeath(player)
		local sess2 = S.Data.Get(player)
		task.delay(sess2 and S.Shop.RespawnTime(sess2) or Players.RespawnTime, function()
			if player.Parent and player.Character == char then
				player:LoadCharacter()
			end
		end)
	end)
end

local function cleanup(player)
	local s = S.Data.Get(player)
	if not s then return end
	S.Base.Release(player)
	S.Data.Save(player, true)
	S.Data.Unload(player)
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(char) hookCharacter(player, char) end)
	local s = S.Data.Load(player)
	if not s then return end
	if not player.Parent then
		cleanup(player)
		return
	end
	S.Income.CreateLeaderstats(player)
	local idx = S.Base.Assign(player)
	if not idx then
		player:Kick("Server is full (max " .. EconomyConfig.MaxPlayers .. " players).")
		S.Data.Unload(player)
		return
	end
	S.Income.Recalc(player)
	S.Base.RefreshAll(player)
	s.ready = true
	S.Data.Push(player)
	player:LoadCharacter()
	if s.leftEarly then cleanup(player) end
end

Players.PlayerAdded:Connect(function(p) task.spawn(onPlayerAdded, p) end)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	local s = S.Data.Get(player)
	if not s then return end
	if s.ready then
		cleanup(player)
	else
		s.leftEarly = true
	end
end)

game:BindToClose(function()
	S.Data.SaveAll()
end)

print("[CarHunters] server ready. Spawn points:", S.PartSpawn.PointCount())
