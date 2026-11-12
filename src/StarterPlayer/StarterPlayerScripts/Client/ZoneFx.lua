-- Per-district hazards on the client: level-crossing lights/arms (docks), sandstorm (desert),
-- jet blast behind taxiing planes (airport), rain + lightning (storm).
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("MapConfig"))
local TrafficMath = require(Shared:WaitForChild("TrafficMath"))

local ZoneFx = {}
local C = Color3.fromRGB

-- seconds until the next train passes x = 0 on this road (nil if far away)
local function trainNear(roadId, t)
	for _, lane in ipairs(TrafficMath.RoadLanes[roadId] or {}) do
		for k = 1, lane.count do
			local x = TrafficMath.CarX(lane, k, t)
			local half = 75
			-- approaching from its tail side or currently over the crossing
			local ahead = -x * lane.dir
			if math.abs(x) < half + 20 or (ahead > 0 and ahead < lane.speed * 4 + half) then
				return true
			end
		end
	end
	return false
end

local function crossings(t)
	local blink = math.floor(t * 2.5) % 2
	local state = {}
	for _, l in ipairs(CollectionService:GetTagged("CrossingLight")) do
		local rid = l:GetAttribute("RoadId")
		if state[rid] == nil then
			state[rid] = trainNear(rid, t)
		end
		local on = state[rid] and (l:GetAttribute("Phase") % 2 == blink)
		l.Color = on and C(255, 40, 30) or C(90, 20, 20)
		l.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
	end
	for _, arm in ipairs(CollectionService:GetTagged("CrossingArm")) do
		local rid = arm:GetAttribute("RoadId")
		local down = state[rid]
		if down == nil then
			down = trainNear(rid, t)
			state[rid] = down
		end
		local base = arm:GetAttribute("BaseCF")
		if not base then
			arm:SetAttribute("BaseCF", arm.CFrame)
			base = arm.CFrame
		end
		local s = arm:GetAttribute("Side")
		local pivot = base * CFrame.new(s * 6, 0, 0)
		local goal = down and pivot * CFrame.new(-s * 6, 0, 0) or pivot * CFrame.Angles(0, 0, -s * math.rad(80)) * CFrame.new(-s * 6, 0, 0)
		arm.CFrame = arm.CFrame:Lerp(goal, 0.1)
	end
end

local atmo, rain, rainPart
local function ensureWeather()
	if not atmo then
		atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere", Lighting)
		atmo:SetAttribute("BaseDensity", atmo.Density)
		atmo:SetAttribute("BaseHaze", atmo.Haze)
		atmo:SetAttribute("BaseColor", atmo.Color)
	end
	if not rainPart then
		rainPart = Instance.new("Part")
		rainPart.Name = "RainEmitter"
		rainPart.Anchored, rainPart.CanCollide, rainPart.CanQuery, rainPart.CanTouch = true, false, false, false
		rainPart.Transparency = 1
		rainPart.Size = Vector3.new(120, 1, 120)
		rain = Instance.new("ParticleEmitter")
		rain.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		rain.Color = ColorSequence.new(C(190, 210, 230))
		rain.Size = NumberSequence.new(0.12)
		rain.Lifetime = NumberRange.new(0.9, 1.1)
		rain.Speed = NumberRange.new(80, 90)
		rain.EmissionDirection = Enum.NormalId.Bottom
		rain.Rate = 0
		rain.LightInfluence = 0.5
		rain.Transparency = NumberSequence.new(0.3)
		rain.Parent = rainPart
		rainPart.Parent = Workspace.CurrentCamera
	end
end

local lastBolt = 0
local function weather(zid, t, camPos)
	ensureWeather()
	local d0, h0, c0 = atmo:GetAttribute("BaseDensity"), atmo:GetAttribute("BaseHaze"), atmo:GetAttribute("BaseColor")
	local wantD, wantH, wantC = d0, h0, c0
	local rate = 0
	if zid == "desert" then
		local wave = math.max(0, math.sin(t * 2 * math.pi / 40)) -- a storm front every 40 s
		wantD, wantH, wantC = d0 + 0.45 * wave, h0 + 6 * wave, c0:Lerp(C(214, 170, 110), wave)
	elseif zid == "storm" then
		wantD, wantH, wantC = d0 + 0.4, h0 + 3, c0:Lerp(C(90, 100, 116), 0.8)
		rate = 900
		if t - lastBolt > 6 + (t % 5) then
			lastBolt = t
			local cc = Lighting:FindFirstChild("BoltFlash") or Instance.new("ColorCorrectionEffect", Lighting)
			cc.Name = "BoltFlash"
			cc.Brightness = 0.6
			task.spawn(function()
				for _ = 1, 10 do
					task.wait(0.03)
					cc.Brightness = cc.Brightness * 0.7
				end
				cc.Brightness = 0
			end)
		end
	end
	atmo.Density = atmo.Density + (wantD - atmo.Density) * 0.05
	atmo.Haze = atmo.Haze + (wantH - atmo.Haze) * 0.05
	atmo.Color = atmo.Color:Lerp(wantC, 0.05)
	rain.Rate = rate
	rainPart.CFrame = CFrame.new(camPos + Vector3.new(0, 40, 0))
end

-- planes push players standing in their exhaust
local function jetBlast(t, hrp)
	local pos = hrp.Position
	local ri = TrafficMath.RoadAtZ(pos.Z, 24)
	local road = ri and MapConfig.Roads[ri]
	if not road or road.kinds[1] ~= "plane" then
		return
	end
	for _, lane in ipairs(TrafficMath.RoadLanes[ri]) do
		for k = 1, lane.count do
			local x = TrafficMath.CarX(lane, k, t)
			local behind = (x - pos.X) * lane.dir -- >0 when the player is behind the plane
			if behind > 18 and behind < 60 and math.abs(pos.Z - lane.z) < 14 then
				local push = Vector3.new(-lane.dir * 70, 18, 0) * (1 - (behind - 18) / 42)
				hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity:Lerp(push, 0.25)
			end
		end
	end
end

function ZoneFx.Start()
	RunService.Heartbeat:Connect(function()
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		local t = Workspace:GetServerTimeNow()
		local camPos = cam.CFrame.Position
		local zid = MapConfig.ZoneAt(camPos.Z)
		if zid == "docks" then
			crossings(t)
		end
		weather(zid, t, camPos)
		local char = Players.LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and zid == "airport" then
			jetBlast(t, hrp)
		end
	end)
end

return ZoneFx
