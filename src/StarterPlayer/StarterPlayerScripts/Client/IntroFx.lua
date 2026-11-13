-- Intro cinematic for new players (before the step-by-step tutorial), with SKIP.
-- A copy of the player's avatar acts it out on the real map: crosses a city road and grabs a part, throws it into the
-- garage trap and a car drives in, walks up to Big Tony, then a fly-over of the districts and a boss monster truck.
-- Plays once: when it ends (or is skipped) the tutorial moves to step 1.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local MapConfig = require(Shared:WaitForChild("MapConfig"))
local BaseLayout = require(Shared:WaitForChild("BaseLayout"))
local CarConfig = require(Shared:WaitForChild("CarConfig"))
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
local STEPS = 5
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

local function scenes(st, actor, track)
	-- 1) the city road: run across between the cars, grab a glowing part
	local road = MapConfig.Roads[1]
	local x = -24
	local from, to = Vector3.new(x, 0.5, road.z - road.width / 2 - 8), Vector3.new(x, 0.5, road.z + road.width / 2 + 6)
	local part = keep(PartVisual.Build("bolts"))
	part:PivotTo(CFrame.new(to + Vector3.new(0, 1.5, 3)))
	part.Parent = Workspace
	camTo(CFrame.lookAt(Vector3.new(x - 42, 12, road.z), Vector3.new(x, 2, road.z)), true)
	caption(1, "GRAB CAR PARTS", "Glowing parts lie around every district - run into one to pick it up", 2.6, 9)
	if not wait(2.6) then
		return
	end
	say("Watch the traffic: one hit and you lose the parts you carry", 5.5)
	if not run(actor, track, from, to, 4.5) then
		return
	end
	part:Destroy()
	if not wait(1.2) then
		return
	end
	-- 2) your garage: throw the part into the trap, a car drives in
	local idx = st.baseIndex
	if idx then
		local bcf = BaseLayout.GetBaseCFrame(idx)
		local trap = BaseLayout.ToWorld(idx, BaseLayout.TrapLocal)
		local stand = trap + bcf:VectorToWorldSpace(Vector3.new(12, 0, 0))
		actor:PivotTo(CFrame.lookAt(stand + Vector3.new(0, 3, 0), trap + Vector3.new(0, 3, 0)))
		camTo(CFrame.lookAt(stand + bcf:VectorToWorldSpace(Vector3.new(10, 9, 14)), trap + Vector3.new(0, 2, 0)), true)
		caption(2, "THROW PARTS INTO YOUR TRAP", "Stand next to the trap in your garage and press THROW", 2.4, 6)
		if not wait(2.4) then
			return
		end
		local p2 = keep(PartVisual.Build("bolts"))
		p2.Parent = Workspace
		local t0 = os.clock()
		while os.clock() - t0 < 0.7 and not skipped do
			local k = (os.clock() - t0) / 0.7
			p2:PivotTo(CFrame.new(stand:Lerp(trap, k) + Vector3.new(0, 3 + math.sin(k * math.pi) * 7, 0)))
			RunService.RenderStepped:Wait()
		end
		p2:Destroy()
		Cine.Flash(Color3.new(1, 1, 1), 0.4, 0.4)
		Cine.Shake(0.8, 0.3)
		-- a car drives in from the street to bay 1, the camera follows behind it
		local def = CarConfig.ByRarity.Rare[1]
		local car = keep(VehicleFactory.BuildCar(def))
		local root = car.PrimaryPart
		local y = BaseLayout.FloorY + 0.6
		local pl, sl = BaseLayout.PortalLocal, BaseLayout.SlotLocal(1)
		local pts = {}
		for _, p in ipairs({ { pl.X + 30, pl.Z }, { BaseLayout.LaneX, pl.Z }, { BaseLayout.LaneX, sl.Z }, { sl.X + 4, sl.Z } }) do
			table.insert(pts, bcf:PointToWorldSpace(Vector3.new(p[1], y, p[2])))
		end
		root.CFrame = faceCF(pts[1], pts[2] - pts[1])
		car.Parent = Workspace
		say("More parts = more rarity points = a rarer car!", 4)
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
		say("It parks in your garage and earns money every second", 3.5)
		if not wait(3.5) then
			return
		end
	end
	-- 3) Big Tony: parts for tuning
	local stand = Workspace:FindFirstChild("GeneratedMap") and Workspace.GeneratedMap:FindFirstChild("ContractStand", true)
	local spot = stand and stand:FindFirstChild("TonySpot")
	if spot then
		local tony = spot.Position
		local a = tony + Vector3.new(14, 0, -12)
		camTo(CFrame.lookAt(tony + Vector3.new(16, 8, -26), tony + Vector3.new(0, 3, 0)), true)
		caption(3, "MEET BIG TONY", "Bring him parts and he tunes your cars - tuned cars earn more", 6)
		if not run(actor, track, a, tony + Vector3.new(3, 0, -4), 3.2) then
			return
		end
		if not wait(2.6) then
			return
		end
	end
	-- 4) the districts: fly down the route
	local z0, z1 = MapConfig.Zones.highway.zMin, MapConfig.Zones.neon.zMax
	caption(4, "UNLOCK NEW DISTRICTS", "The deeper you go, the faster the traffic - and the better the parts", 5)
	local f0 = os.clock()
	while os.clock() - f0 < 5 and not skipped do
		local z = z0 + (z1 - z0) * (os.clock() - f0) / 5
		camTo(CFrame.lookAt(Vector3.new(0, 46, z), Vector3.new(0, 0, z + 90)), os.clock() - f0 < 0.05)
		RunService.RenderStepped:Wait()
	end
	-- 5) the boss
	local bosses = Workspace:FindFirstChild("Bosses")
	local truck = bosses and bosses:FindFirstChildWhichIsA("Model")
	if truck and not skipped then
		caption(5, "EVERY TIER ENDS WITH A BOSS", "A monster truck guards the arena - throw parts to scare it off", 5)
		local b0 = os.clock()
		while os.clock() - b0 < 5 and not skipped do
			local c = truck:GetPivot().Position
			local ang = (os.clock() - b0) * 0.5
			camTo(CFrame.lookAt(c + Vector3.new(math.cos(ang) * 34, 14, math.sin(ang) * 34), c + Vector3.new(0, 4, 0)), os.clock() - b0 < 0.05)
			RunService.RenderStepped:Wait()
		end
	end
	if not skipped then
		Cine.Title("NOW IT'S YOUR TURN!", Color3.fromRGB(110, 230, 140), 2.4, 84, 0.42)
		wait(2.2)
	end
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

function Intro.Start(ui, cine)
	UI, Cine = ui, cine
	K = UI.Kit()
	task.spawn(function()
		-- new players only (tutorial 0), once their avatar is in the world
		local st
		repeat
			task.wait(0.5)
			st = K.store.State
		until st and Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if (st.tutorial or 0) == 0 then
			task.wait(1)
			Intro.Play(st)
		end
	end)
end

return Intro
