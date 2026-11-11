-- Hot Drop: every ~80 s a rare crate parachutes onto a dangerous spot. First player to grab it wins.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local MapConfig = require(Shared:WaitForChild("MapConfig"))

local HotDrop = {}
local S
local points = {}
local current = nil
local rng = Random.new()

HotDrop.Interval = { 70, 100 }
HotDrop.Lifetime = 45
HotDrop.FallTime = 4
HotDrop.EarlyWarning = 15

function HotDrop.Init(hub)
	S = hub
end

local function bestZone(player)
	local s = player and S.Data.Get(player)
	local best = "city"
	if s and s.data then
		for _, z in ipairs(MapConfig.ZoneOrder) do
			if s.data.unlockedZones[z] then
				best = z
			end
		end
	end
	return best
end

local function pickZone()
	local zones = {}
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(zones, bestZone(p))
	end
	if #zones == 0 then
		return nil
	end
	return zones[rng:NextInteger(1, #zones)]
end

local function pickPoint(zone)
	local list = {}
	for _, pt in ipairs(points) do
		if pt.zone == zone and pt.risk ~= "safe" then
			table.insert(list, pt)
		end
	end
	if #list == 0 then
		return nil
	end
	return list[rng:NextInteger(1, #list)]
end

local function crateModel(pos)
	local m = Instance.new("Model")
	m.Name = "HotDropCrate"
	local box = Instance.new("Part")
	box.Name = "Crate"
	box.Size = Vector3.new(4, 4, 4)
	box.Color = Color3.fromRGB(232, 178, 50)
	box.Material = Enum.Material.DiamondPlate
	box.Anchored, box.CanCollide, box.CanQuery, box.CanTouch = true, false, false, false
	box.CFrame = CFrame.new(pos + Vector3.new(0, 2.2, 0))
	box.Parent = m
	for _, a in ipairs({ 0, 90 }) do
		local band = Instance.new("Part")
		band.Name = "Band"
		band.Size = Vector3.new(4.1, 4.1, 0.6)
		band.Color = Color3.fromRGB(30, 30, 34)
		band.Material = Enum.Material.Metal
		band.Anchored, band.CanCollide, band.CanQuery, band.CanTouch = true, false, false, false
		band.CFrame = box.CFrame * CFrame.Angles(0, math.rad(a), 0)
		band.Parent = m
	end
	local smoke = Instance.new("Attachment")
	smoke.Name = "Smoke"
	smoke.Position = Vector3.new(0, 2.2, 0)
	smoke.Parent = box
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 120, 60), Color3.fromRGB(255, 60, 40))
	e.Size = NumberSequence.new(1.2, 5)
	e.Transparency = NumberSequence.new(0.2, 1)
	e.Lifetime = NumberRange.new(2.5, 3.5)
	e.Speed = NumberRange.new(5, 8)
	e.SpreadAngle = Vector2.new(10, 10)
	e.Rate = 14
	e.Acceleration = Vector3.new(0, 3, 0)
	e.Parent = smoke
	m.PrimaryPart = box
	return m
end

local function clear(reason, winner)
	if not current then
		return
	end
	if current.model then
		current.model:Destroy()
	end
	Net.Get("HotDrop"):FireAllClients({ kind = "end", id = current.id, reason = reason, winner = winner and winner.DisplayName })
	current = nil
end

local function launch(zone, byPlayer)
	if current then
		clear("replaced")
	end
	local pt = pickPoint(zone)
	if not pt then
		return
	end
	local now = Workspace:GetServerTimeNow()
	current = {
		id = tostring(math.floor(now * 1000)), pos = pt.pos, zone = zone,
		landAt = now + HotDrop.FallTime, expiresAt = now + HotDrop.FallTime + HotDrop.Lifetime,
	}
	local info = { kind = "start", id = current.id, pos = current.pos, zone = zone, landAt = current.landAt,
		expiresAt = current.expiresAt, by = byPlayer and byPlayer.DisplayName }
	Net.Get("HotDrop"):FireAllClients(info)
	task.delay(HotDrop.FallTime, function()
		if current and current.id == info.id then
			current.model = crateModel(current.pos)
			current.model.Parent = Workspace:FindFirstChild("RuntimeDrops") or Workspace
			current.landed = true
		end
	end)
end

function HotDrop.SpawnFor(player)
	launch(bestZone(player), player)
end

function HotDrop.Current()
	return current
end

function HotDrop.Start()
	local map = Workspace:WaitForChild("GeneratedMap")
	for _, inst in ipairs(map:WaitForChild("PartSpawnPoints"):GetDescendants()) do
		if inst:IsA("BasePart") and inst:GetAttribute("ZoneId") then
			table.insert(points, { pos = inst.Position, zone = inst:GetAttribute("ZoneId"), risk = inst:GetAttribute("Risk") or "safe" })
		end
	end
	-- scheduler with an early warning for scanner level 2 owners
	task.spawn(function()
		while true do
			local wait = rng:NextNumber(HotDrop.Interval[1], HotDrop.Interval[2])
			task.wait(wait - HotDrop.EarlyWarning)
			local zone = pickZone()
			if zone and not current then
				for _, p in ipairs(Players:GetPlayers()) do
					local s = S.Data.Get(p)
					if s and S.Shop.Level(s, "scanner") >= 2 then
						Net.Get("HotDrop"):FireClient(p, { kind = "warn", zone = zone, inSeconds = HotDrop.EarlyWarning })
					end
				end
				task.wait(HotDrop.EarlyWarning)
				if not current then
					launch(zone)
				end
			else
				task.wait(HotDrop.EarlyWarning)
			end
		end
	end)
	RunService.Heartbeat:Connect(function()
		if not current then
			return
		end
		local now = Workspace:GetServerTimeNow()
		if now > current.expiresAt then
			clear("expired")
			return
		end
		if not current.landed then
			return
		end
		for _, player in ipairs(Players:GetPlayers()) do
			local s = S.Data.Get(player)
			local hrp = s and s.ready and S.Data.GetRoot(player)
			if hrp then
				local d = hrp.Position - current.pos
				local r = S.Shop.PickupRadius(s) + 1
				if d.X * d.X + d.Z * d.Z <= r * r and math.abs(d.Y) < 12 then
					local partId = (rng:NextNumber() < 0.45) and "core" or "turbo"
					local n = partId == "core" and 1 or 2
					local given = S.Inventory.AddCarried(player, partId, n, current.zone, true)
					if given then
						S.Data.Notify(player, "hotDropMine", { n, partId }, "good")
						S.Contracts.Progress(player, "hotdrop", 1)
						clear("taken", player)
						return
					end
				end
			end
		end
	end)
end

return HotDrop
