-- Intro cinematic for new players (before the step-by-step tutorial), with SKIP. Six scenes on the real map, a copy of
-- the player's avatar acts them out:
--   1 a tour of the hub (Pit Stop, Leaderboard, Big Tony's Gears)
--   2 crossing a city road between the cars and grabbing a glowing part
--   3 throwing it at the platform: flash, a car drives into the garage
--   4 Big Tony's GEARS: timed boosts, a geared car gets a glowing aura
--   5 upgrading the platform for more luck
--   6 a fly-over of the districts and a boss monster truck
-- Every scene checks its own models and is skipped (or played without them) when one is missing; a scene that errors
-- is skipped too, the intro goes on with the next one.
-- Played by JoinFlow when a new player answers YES: when it ends (or is skipped) the tutorial moves to step 1.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local MapConfig = require(Shared:WaitForChild("MapConfig"))
local BaseLayout = require(Shared:WaitForChild("BaseLayout"))
local CarConfig = require(Shared:WaitForChild("CarConfig"))
local TrapConfig = require(Shared:WaitForChild("TrapConfig"))
local PartVisual = require(Shared:WaitForChild("PartVisual"))
local VehicleFactory = require(Shared:WaitForChild("VehicleFactory"))

local Intro = {}
local UI, Cine, K
local RUN_ANIM = "rbxassetid://913376220" -- Roblox default R15 run
local skipped = false
local trash = {}

local function keep(x)
	table.insert(trash, x)
	return x
end

-- waits, but returns false at once when SKIP was pressed
local function wait(t)
	local t0 = os.clock()
	while os.clock() - t0 < t do
		if skipped then
			return false
		end
		RunService.RenderStepped:Wait()
	end
	return not skipped
end

-- smooth camera: every frame eases toward the target CFrame (target may be a function of time)
local cam, camTarget, camConn
local function camTo(cf, snap)
	camTarget = cf
	if snap then
		cam.CFrame = cf
	end
end

local function makeActor()
	local char = Players.LocalPlayer.Character
	if not char then
		return nil
	end
	char.Archivable = true
	local a = char:Clone()
	if not a or not a:FindFirstChild("HumanoidRootPart") then
		if a then
			a:Destroy()
		end
		return nil
	end
	for _, d in ipairs(a:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	local hum = a:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	a.HumanoidRootPart.Anchored = true
	a.Parent = Workspace
	keep(a)
	local animator = hum and (hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum))
	local track
	if animator then
		local anim = Instance.new("Animation")
		anim.AnimationId = RUN_ANIM
		track = animator:LoadAnimation(anim)
	end
	return a, track
end

-- actor runs from a to b in t seconds, facing the way it goes
local function run(actor, track, a, b, t)
	local y = actor:GetExtentsSize().Y / 2
	local face = CFrame.lookAt(a, Vector3.new(b.X, a.Y, b.Z)) - a
	if track then
		track:Play(0.1)
	end
	local t0 = os.clock()
	while true do
		local k = math.min(1, (os.clock() - t0) / t)
		actor:PivotTo(CFrame.new(a:Lerp(b, k) + Vector3.new(0, y, 0)) * face)
		if k >= 1 or skipped then
			break
		end
		RunService.RenderStepped:Wait()
	end
	if track then
		track:Stop(0.15)
	end
	return not skipped
end

-- numbered, long captions: a scene keeps its title + subtitle on screen for its whole length
local STEPS = 6
local function caption(step, title, sub, dur, titleDur)
	Cine.Title(string.format("STEP %d/%d  %s", step, STEPS, title), Color3.fromRGB(255, 210, 63), titleDur or dur, 72, 0.2)
	Cine.Sub(sub, Color3.new(1, 1, 1), dur, 0.82)
end
-- the next subtitle of the same scene (replaces the current one)
local function say(sub, dur)
	Cine.Sub(sub, Color3.new(1, 1, 1), dur, 0.82)
end
-- vehicles are posed by their Root (forward = local +X), like TrapFx / traffic; the model pivot is not aligned
local function faceCF(pos, dir)
	return CFrame.new(pos) * CFrame.Angles(0, math.atan2(-dir.Z, dir.X), 0)
end
-- runs fn(t) every frame for dur seconds (camera moves); false when SKIP was pressed
local function during(dur, fn)
	local t0 = os.clock()
	while not skipped do
		local t = os.clock() - t0
		fn(t)
		if t >= dur then
			break
		end
		RunService.RenderStepped:Wait()
	end
	return not skipped
end
local function smooth(k)
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end
-- a showcase car (nil when it can't be built); never throws
local function showCar(rarity)
	local ok, car = pcall(function()
		local pool = CarConfig.ByRarity[rarity] or CarConfig.ByRarity.Rare
		local def = pool and pool[1]
		return def and VehicleFactory.BuildCar(def)
	end)
	if ok and car and car.PrimaryPart then
		return keep(car)
	elseif ok and car then
		car:Destroy()
	end
	return nil
end
local function trapPadOf(idx)
	local map = Workspace:FindFirstChild("GeneratedMap")
	local bases = map and map:FindFirstChild("Bases")
	local base = bases and bases:FindFirstChild(string.format("Base%02d", idx), true)
	return base and base:FindFirstChild("TrapPad")
end

-- 1) the hub: a high orbit, then the camera turns from stand to stand around the fountain
local function sceneHub()
	local hub = MapConfig.Hub
	if not hub then
		return true
	end
	local centre = Vector3.new(hub.x, hub.top or 0, hub.z)
	local tour = {}
	for _, stop in ipairs({
		{ MapConfig.Shop, "PIT STOP  -  perks: run faster, carry more, catch more cars" },
		{ MapConfig.Leaderboard, "LEADERBOARD  -  the top hunters on this server" },
		{ MapConfig.Tony, "BIG TONY'S GEARS  -  huge timed boosts for your cars" },
	}) do
		if stop[1] and stop[1].angle then
			table.insert(tour, stop)
		end
	end
	local HOLD, MOVE = 2.9, 1.1
	caption(1, "WELCOME TO THE HUB", "Your home square: shops, gears and jobs - no traffic here", 3, 3 + #tour * HOLD)
	if not during(3, function(t)
		local a = 0.9 + t * 0.12
		camTo(CFrame.lookAt(centre + Vector3.new(math.cos(a) * 95, 48, math.sin(a) * 95), centre + Vector3.new(0, 4, 0)), t < 0.05)
	end) then
		return false
	end
	-- the stands are listed by rising angle, so the camera always turns the same way round (never through the fountain)
	local prev
	for _, stop in ipairs(tour) do
		local cfg = stop[1]
		local a1 = math.rad(cfg.angle)
		local a0 = prev or (a1 - 0.5)
		local r = cfg.r or 45
		say(stop[2], HOLD)
		if not during(HOLD, function(t)
			local ang = t < MOVE and a0 + (a1 - a0) * smooth(t / MOVE) or a1 + (t - MOVE) * 0.04
			local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
			camTo(CFrame.lookAt(centre + dir * 20 + Vector3.new(0, 12, 0), centre + dir * r + Vector3.new(0, 6, 0)))
		end) then
			return false
		end
		prev = a1 + (HOLD - MOVE) * 0.04
	end
	return true
end

-- 2) the city road: run across between the cars, grab a glowing part
local function sceneParts(actor, track)
	local road = MapConfig.Roads and MapConfig.Roads[1]
	if not road then
		return true
	end
	local x = -24
	local from, to = Vector3.new(x, 0.5, road.z - road.width / 2 - 8), Vector3.new(x, 0.5, road.z + road.width / 2 + 6)
	local ok, part = pcall(PartVisual.Build, "bolts")
	if ok and part then
		keep(part)
		part:PivotTo(CFrame.new(to + Vector3.new(0, 1.5, 3)))
		part.Parent = Workspace
	else
		part = nil
	end
	camTo(CFrame.lookAt(Vector3.new(x - 42, 12, road.z), Vector3.new(x, 2, road.z)), true)
	caption(2, "GRAB CAR PARTS", "Glowing parts lie around every district - run into one to pick it up", 2.6, 9)
	if not wait(2.6) then
		return false
	end
	say("Watch the traffic: one hit and you lose the parts you carry", 5.5)
	if not run(actor, track, from, to, 4.5) then
		return false
	end
	if part then
		part:Destroy()
	end
	return wait(1.2)
end

-- 3) your garage: throw the part at the platform, a car drives in
local function sceneThrow(st, actor)
	local idx = st.baseIndex
	if not idx then
		return true
	end
	local bcf = BaseLayout.GetBaseCFrame(idx)
	local trap = BaseLayout.ToWorld(idx, BaseLayout.TrapLocal)
	local stand = trap + bcf:VectorToWorldSpace(Vector3.new(12, 0, 0))
	actor:PivotTo(CFrame.lookAt(stand + Vector3.new(0, 3, 0), trap + Vector3.new(0, 3, 0)))
	camTo(CFrame.lookAt(stand + bcf:VectorToWorldSpace(Vector3.new(10, 9, 14)), trap + Vector3.new(0, 2, 0)), true)
	caption(3, "THROW PARTS AT YOUR PLATFORM", "At your platform open THROW, pick ALL and press THROW", 2.4, 6)
	if not wait(2.4) then
		return false
	end
	local ok, p2 = pcall(PartVisual.Build, "bolts")
	if ok and p2 then
		keep(p2)
		p2.Parent = Workspace
		local t0 = os.clock()
		while os.clock() - t0 < 0.7 and not skipped do
			local k = (os.clock() - t0) / 0.7
			p2:PivotTo(CFrame.new(stand:Lerp(trap, k) + Vector3.new(0, 3 + math.sin(k * math.pi) * 7, 0)))
			RunService.RenderStepped:Wait()
		end
		p2:Destroy()
	end
	Cine.Flash(Color3.new(1, 1, 1), 0.4, 0.4)
	Cine.Shake(0.8, 0.3)
	say("More parts = more rarity points = a rarer car!", 4)
	-- a car drives in from the street to bay 1, the camera follows behind it
	local car = showCar("Rare")
	if car then
		local root = car.PrimaryPart
		local y = BaseLayout.FloorY + 0.6
		local pl, sl = BaseLayout.PortalLocal, BaseLayout.SlotLocal(1)
		local pts = {}
		for _, p in ipairs({ { pl.X + 30, pl.Z }, { BaseLayout.LaneX, pl.Z }, { BaseLayout.LaneX, sl.Z }, { sl.X + 4, sl.Z } }) do
			table.insert(pts, bcf:PointToWorldSpace(Vector3.new(p[1], y, p[2])))
		end
		root.CFrame = faceCF(pts[1], pts[2] - pts[1])
		car.Parent = Workspace
		for i = 2, #pts do
			local a, b = pts[i - 1], pts[i]
			local dir = (b - a).Unit
			local seg = (b - a).Magnitude / 26
			local s0 = os.clock()
			while not skipped do
				local k = math.min(1, (os.clock() - s0) / seg)
				local pos = a:Lerp(b, k)
				root.CFrame = faceCF(pos, dir)
				camTo(CFrame.lookAt(pos - dir * 12 + Vector3.new(0, 4.5, 0), pos + dir * 6 + Vector3.new(0, 1.5, 0)))
				if k >= 1 then
					break
				end
				RunService.RenderStepped:Wait()
			end
		end
	elseif not wait(2) then
		return false
	end
	say("It parks in your garage and earns money every second", 3.5)
	return wait(3.5)
end

-- a quick local "gear aura" on the showcase car (the real ones are GearFx's, on parked cars only)
local function addAura(car)
	pcall(function()
		local root = car.PrimaryPart
		local gold = Color3.fromRGB(255, 205, 60)
		local hl = Instance.new("Highlight")
		hl.FillColor, hl.OutlineColor = gold, gold
		hl.FillTransparency, hl.OutlineTransparency = 0.75, 0
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = car
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = gold, 16, 2
		light.Parent = root
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(gold)
		pe.LightEmission = 1
		pe.Rate = 40
		pe.Lifetime = NumberRange.new(0.8, 1.4)
		pe.Speed = NumberRange.new(3, 6)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Size = NumberSequence.new(0.5, 0)
		pe.Parent = root
	end)
end

-- 4) Big Tony's GEARS: the shop, then a car with a gear on it lights up
local function sceneTony(actor, track)
	local map = Workspace:FindFirstChild("GeneratedMap")
	local garage = map and map:FindFirstChild("TonyGarage", true)
	local spot = garage and garage:FindFirstChild("TonySpot", true)
	local tcf -- Tony's frame: local -Z looks out of the shop at the visitors
	if spot then
		local look = spot.CFrame.LookVector * Vector3.new(1, 0, 1)
		tcf = CFrame.lookAt(spot.Position, spot.Position + (look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)))
	elseif MapConfig.Tony and MapConfig.Hub then
		-- no shop model: film the stand's place on the ring (the stand faces the hub centre)
		local cfg, hub = MapConfig.Tony, MapConfig.Hub
		local pos = Vector3.new(cfg.x, (hub.top or 0) + 0.5, cfg.z)
		tcf = CFrame.lookAt(pos, Vector3.new(hub.x, pos.Y, hub.z))
	else
		return true
	end
	local tony = tcf.Position
	local function at(x, y, z)
		return tcf:PointToWorldSpace(Vector3.new(x, y, z))
	end
	camTo(CFrame.lookAt(at(11, 8, -24), tony + Vector3.new(0, 4, 0)), true)
	caption(4, "BIG TONY'S GEARS", "Buy GEARS: huge timed boosts - x2 income, luck, speed", 5, 12)
	if not run(actor, track, at(14, 0, -16), at(2, 0, -7.5), 3) then
		return false
	end
	if not wait(2) then
		return false
	end
	-- the showcase car in front of the shop, side-on to the camera
	local car = showCar("Epic")
	if not car then
		say("Put a gear on a car and it gets a glowing aura", 4.5)
		return wait(4.5)
	end
	local root = car.PrimaryPart
	local p = at(-3, 0, -13)
	local carPos = Vector3.new(p.X, tony.Y - 0.5 + 0.6, p.Z) -- the spot is 0.5 above the paving; Root rides 0.6 above it
	root.CFrame = faceCF(carPos, tcf.RightVector)
	car.Parent = Workspace
	camTo(CFrame.lookAt(carPos + tcf:VectorToWorldSpace(Vector3.new(6, 6, -14)), carPos + Vector3.new(0, 1.5, 0)))
	say("Put a gear on a car and it gets a glowing aura", 5)
	if not wait(1.2) then
		return false
	end
	Cine.Flash(Color3.fromRGB(255, 220, 120), 0.5, 0.4)
	addAura(car)
	return during(3.8, function(t)
		local a = t * 0.35
		local off = tcf:VectorToWorldSpace(Vector3.new(math.sin(a) * 15, 6, -math.cos(a) * 15))
		camTo(CFrame.lookAt(carPos + off, carPos + Vector3.new(0, 1.5, 0)))
	end)
end

-- 5) the platform: it levels up, more luck
local function scenePlatform(st, actor)
	local idx = st.baseIndex or 1
	local okCf, bcf = pcall(BaseLayout.GetBaseCFrame, idx)
	if not okCf or not bcf then
		return true
	end
	local pad = trapPadOf(idx)
	local trap = pad and pad.Position or BaseLayout.ToWorld(idx, BaseLayout.TrapLocal)
	local floor = pad and (pad.Position.Y + pad.Size.Y / 2) or (trap.Y + 1.6) -- pad top (the rings start here)
	local ground = BaseLayout.ToWorld(idx, BaseLayout.TrapLocal) -- the actor stands beside the pad, as in scene 3
	local stand = ground + bcf:VectorToWorldSpace(Vector3.new(12, 0, 0))
	actor:PivotTo(CFrame.lookAt(stand + Vector3.new(0, 3, 0), ground + Vector3.new(0, 3, 0)))
	local luck = math.floor((TrapConfig.LuckPerLevel or 0) * 100 + 0.5)
	caption(5, "UPGRADE YOUR PLATFORM", "Upgrade your platform for more luck", 3.2, 8)
	local function orbitAt(t)
		local a = 0.6 + t * 0.25
		camTo(CFrame.lookAt(trap + Vector3.new(math.cos(a) * 26, 14, math.sin(a) * 26), trap + Vector3.new(0, 1, 0)), t < 0.05)
	end
	if not during(2.4, orbitAt) then
		return false
	end
	say(string.format("Open THROW at your platform and press UPGRADE: Lv 1 to Lv %d, +%d%% luck per level", TrapConfig.MaxLevel or 10, luck), 5.6)
	Cine.Flash(Color3.fromRGB(120, 240, 255), 0.35, 0.4)
	-- three glowing rings rise off the pad (local fx, cleaned up with the rest)
	local rings = {}
	for i = 1, 3 do
		local ring = keep(Instance.new("Part"))
		ring.Shape = Enum.PartType.Cylinder
		ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(80, 230, 255)
		ring.Transparency = 1
		ring.Size = Vector3.new(0.3, 14, 14)
		ring.Parent = Workspace
		rings[i] = ring
	end
	return during(5.6, function(t)
		orbitAt(2.4 + t)
		for i, ring in ipairs(rings) do
			local k = ((t - (i - 1) * 0.45) % 1.4) / 1.4
			local s = 12 + k * 8
			ring.Size = Vector3.new(0.3, s, s)
			ring.CFrame = CFrame.new(trap.X, floor + 0.2 + k * 7, trap.Z) * CFrame.Angles(0, 0, math.pi / 2)
			ring.Transparency = t < (i - 1) * 0.45 and 1 or 0.35 + 0.65 * k
		end
	end)
end

-- 6) the districts: fly down the route, then the boss
local function sceneDistricts()
	local zones = MapConfig.Zones
	local z0 = zones and zones.highway and zones.highway.zMin
	local z1 = zones and zones.neon and zones.neon.zMax
	caption(6, "DISTRICTS & BOSSES", "Unlock new districts: faster traffic - and better parts", 5, 10)
	if z0 and z1 then
		if not during(5, function(t)
			local z = z0 + (z1 - z0) * t / 5
			camTo(CFrame.lookAt(Vector3.new(0, 46, z), Vector3.new(0, 0, z + 90)), t < 0.05)
		end) then
			return false
		end
	elseif not wait(5) then
		return false
	end
	local bosses = Workspace:FindFirstChild("Bosses")
	local truck = bosses and bosses:FindFirstChildWhichIsA("Model")
	if truck then
		say("Every tier ends with a boss: a monster truck guards the arena - throw parts to scare it off", 5)
		return during(5, function(t)
			if not truck.Parent then
				return
			end
			local c = truck:GetPivot().Position
			local ang = t * 0.5
			camTo(CFrame.lookAt(c + Vector3.new(math.cos(ang) * 34, 14, math.sin(ang) * 34), c + Vector3.new(0, 4, 0)), t < 0.05)
		end)
	end
	return true
end

local function scenes(st, actor, track)
	-- each scene runs protected: a broken one is skipped, the intro goes on with the next
	local list = {
		sceneHub,
		function() return sceneParts(actor, track) end,
		function() return sceneThrow(st, actor) end,
		function() return sceneTony(actor, track) end,
		function() return scenePlatform(st, actor) end,
		sceneDistricts,
	}
	for i, fn in ipairs(list) do
		local ok, goOn = pcall(fn)
		if not ok then
			warn("[IntroFx] scene " .. i .. ": " .. tostring(goOn))
		end
		if skipped then
			return
		end
	end
	Cine.Title("NOW IT'S YOUR TURN!", Color3.fromRGB(110, 230, 140), 2.4, 84, 0.42)
	wait(2.2)
end

function Intro.Play(st)
	skipped = false
	UI.SetCinematic(true)
	cam = Cine.Take()
	local cam0 = cam.CFrame
	camTarget = cam.CFrame
	camConn = RunService.RenderStepped:Connect(function(dt)
		cam.CFrame = cam.CFrame:Lerp(camTarget, 1 - math.exp(-dt * 6))
	end)
	Cine.Letterbox(true, 0.4)
	-- everything that can fail runs protected, so the cleanup below always gives the player back the controls
	local skip
	pcall(function()
		skip = K.toy(K.overlay, { Text = "SKIP  >", Color = K.P.grey, Size = UDim2.fromOffset(150, 56), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -24),
			TextSize = 22, ZIndex = 95, OnClick = function() skipped = true end })
		local actor, track = makeActor()
		if actor then
			scenes(st, actor, track)
		end
	end)
	Cine.ClearText()
	Cine.Darken(1, 0.3)
	task.wait(0.35)
	for _, x in ipairs(trash) do
		pcall(function()
			x:Destroy()
		end)
	end
	trash = {}
	if skip then
		skip.holder:Destroy()
	end
	if camConn then
		camConn:Disconnect()
		camConn = nil
	end
	cam.CFrame = cam0
	Cine.Letterbox(false, 0.2)
	Cine.Release(0.2)
	Cine.Darken(0, 0.5)
	UI.SetCinematic(false)
	Net.Get("TutorialStep"):FireServer(1) -- the intro is done: the tutorial starts at step 1
end

-- JoinFlow asks "NEED A TUTORIAL?" and calls Intro.Play on YES
function Intro.Start(ui, cine)
	UI, Cine = ui, cine
	K = UI.Kit()
end

return Intro
