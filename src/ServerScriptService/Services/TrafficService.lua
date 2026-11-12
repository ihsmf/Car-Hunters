local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("MapConfig"))
local Net = require(Shared:WaitForChild("Net"))
local TrafficMath = require(Shared:WaitForChild("TrafficMath"))
local VehicleKinds = require(Shared:WaitForChild("VehicleKinds"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))

local Traffic = {}
local S

function Traffic.Init(hub)
	S = hub
end

-- Returns the lane whose car overlaps pos at time t (margin widens the hitbox).
function Traffic.HitTest(pos, t, roadIdx, margin)
	margin = margin or 0
	local groundY = MapConfig.RoadTopY
	for _, lane in ipairs(TrafficMath.RoadLanes[roadIdx]) do
		if math.abs(pos.Z - lane.z) < 7 + (lane.weaveA or 0) + 24 + margin then
			for k = 1, lane.count do
				local kind = VehicleKinds[lane.kinds[k]]
				local dz = math.abs(pos.Z - TrafficMath.CarZ(lane, k, t))
				local x = TrafficMath.CarX(lane, k, t)
				if math.abs(pos.X - x) <= kind.L / 2 + 1.0 + margin and dz <= kind.W / 2 + 1.0 + margin and pos.Y < groundY + kind.H + 2.5 then
					return lane
				end
			end
		end
	end
	return nil
end

-- Instant death: one touch = WRECKED, carried loot of this run is lost (InventoryService.OnDeath).
local function wreck(player, s, hum, lane)
	s.lastHit = os.clock()
	if S.Shop.TryAirbag(s) then
		-- airbag pops: knocked back, shielded for a moment, loot kept
		s.protectedUntil = os.clock() + 1.5
		Net.Get("HitFx"):FireClient(player, Vector3.new(lane and lane.dir or 1, 0, 0), "airbag")
		S.Data.Push(player)
		return
	end
	Net.Get("HitFx"):FireClient(player, Vector3.new(lane and lane.dir or 1, 0, 0), "wrecked")
	hum.Health = 0
end

local function eligible(player)
	local s = S.Data.Get(player)
	local now = os.clock()
	if s and s.ready and now > s.protectedUntil and now - s.lastHit >= EconomyConfig.HitCooldown then
		local hrp, hum = S.Data.GetRoot(player)
		if hrp then
			local pos = hrp.Position
			local ri = TrafficMath.RoadAtZ(pos.Z, 3)
			if ri and math.abs(pos.X) <= MapConfig.MapHalfWidth + 6 then
				return s, hum, pos, ri
			end
		end
	end
	return nil
end

function Traffic.Start()
	-- client reports what it saw; server re-checks the recent past with a small tolerance
	Net.Get("TrafficHit").OnServerEvent:Connect(function(player)
		local s, hum, pos, ri = eligible(player)
		if not s then
			return
		end
		local t = Workspace:GetServerTimeNow()
		for back = 0, 0.5, 0.1 do
			local lane = Traffic.HitTest(pos, t - back, ri, 2.5)
			if lane then
				wreck(player, s, hum, lane)
				return
			end
		end
	end)
	-- authoritative fallback
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc < EconomyConfig.TrafficTickRate then
			return
		end
		acc = 0
		local t = Workspace:GetServerTimeNow()
		for _, player in ipairs(Players:GetPlayers()) do
			local s, hum, pos, ri = eligible(player)
			if s then
				local lane = Traffic.HitTest(pos, t, ri, 0)
				if lane then
					wreck(player, s, hum, lane)
				end
			end
		end
	end)
end

-- shared instant death for bosses, rivers, etc. (airbag still applies)
function Traffic.Wreck(player, dirX)
	local s = S.Data.Get(player)
	local _, hum = S.Data.GetRoot(player)
	local now = os.clock()
	if s and s.ready and hum and hum.Health > 0 and now > s.protectedUntil and now - s.lastHit >= EconomyConfig.HitCooldown then
		wreck(player, s, hum, { dir = dirX or 1 })
		return true
	end
	return false
end

function Traffic.Protect(player, seconds)
	local s = S.Data.Get(player)
	if s then
		s.protectedUntil = math.max(s.protectedUntil, os.clock() + seconds)
	end
end

return Traffic
