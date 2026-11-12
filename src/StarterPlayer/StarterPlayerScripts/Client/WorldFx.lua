local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MapConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapConfig"))

local MOODS = {
	plaza = { clock = 14.3, bright = 2.3, tint = Color3.fromRGB(255, 250, 244), sat = 0.16, amb = Color3.fromRGB(132, 128, 118) },
	city = { clock = 14.3, bright = 2.3, tint = Color3.fromRGB(255, 250, 240), sat = 0.16, amb = Color3.fromRGB(132, 128, 118) },
	highway = { clock = 15.9, bright = 2.2, tint = Color3.fromRGB(255, 244, 226), sat = 0.14, amb = Color3.fromRGB(134, 124, 116) },
	industrial = { clock = 17.3, bright = 2.0, tint = Color3.fromRGB(255, 234, 212), sat = 0.06, amb = Color3.fromRGB(130, 110, 104) },
	neon = { clock = 20.4, bright = 1.4, tint = Color3.fromRGB(214, 236, 255), sat = 0.35, amb = Color3.fromRGB(60, 110, 150) },
	scrapyard = { clock = 17.8, bright = 1.9, tint = Color3.fromRGB(255, 226, 200), sat = 0.1, amb = Color3.fromRGB(130, 104, 96) },
	docks = { clock = 9.2, bright = 2.0, tint = Color3.fromRGB(236, 246, 255), sat = 0.1, amb = Color3.fromRGB(110, 124, 136) },
	desert = { clock = 13.0, bright = 2.6, tint = Color3.fromRGB(255, 236, 206), sat = 0.12, amb = Color3.fromRGB(150, 128, 104) },
	bridge = { clock = 11.0, bright = 2.3, tint = Color3.fromRGB(246, 252, 255), sat = 0.18, amb = Color3.fromRGB(124, 134, 140) },
	airport = { clock = 15.0, bright = 2.3, tint = Color3.fromRGB(250, 250, 255), sat = 0.12, amb = Color3.fromRGB(128, 130, 136) },
	canyon = { clock = 18.2, bright = 2.0, tint = Color3.fromRGB(255, 214, 180), sat = 0.2, amb = Color3.fromRGB(150, 100, 80) },
	circuit = { clock = 14.0, bright = 2.4, tint = Color3.fromRGB(255, 250, 244), sat = 0.2, amb = Color3.fromRGB(132, 128, 118) },
	drift = { clock = 21.0, bright = 1.3, tint = Color3.fromRGB(240, 220, 255), sat = 0.35, amb = Color3.fromRGB(90, 70, 130) },
	storm = { clock = 19.6, bright = 0.9, tint = Color3.fromRGB(190, 206, 220), sat = -0.1, amb = Color3.fromRGB(70, 80, 96) },
	rush = { clock = 16.8, bright = 2.1, tint = Color3.fromRGB(255, 236, 214), sat = 0.14, amb = Color3.fromRGB(134, 120, 110) },
	colosseum = { clock = 17.0, bright = 2.2, tint = Color3.fromRGB(255, 232, 200), sat = 0.16, amb = Color3.fromRGB(150, 126, 100) },
}
local mood = { clock = 14.3, bright = 2.3, tint = Color3.fromRGB(255, 250, 244), sat = 0.16, amb = Color3.fromRGB(132, 128, 118) }
local tintFx
local lastBackfire = 0
local spinAcc = 0

local Fx = {}
local spinning = {}
local gates = {}
local store

local function applyGate(part)
	local zone = part:GetAttribute("ZoneId")
	local unlocked = store.State and store.State.zones and store.State.zones[zone] == true
	part.CanCollide = not unlocked
	part.Transparency = unlocked and 1 or 0
	for _, g in ipairs(part:GetChildren()) do
		if g:IsA("SurfaceGui") then
			g.Enabled = not unlocked
		end
	end
end

local function addSpin(model)
	local root = model:IsA("Model") and model.PrimaryPart or model:FindFirstChild("Root")
	if not root then
		task.wait(0.2)
		root = model.PrimaryPart or model:FindFirstChild("Root")
	end
	if root then
		spinning[model] = { root = root, base = root.CFrame, phase = math.random() * 6 }
	end
end

function Fx.Start(storeModule)
	store = storeModule
	for _, m in ipairs(CollectionService:GetTagged("SpinBob")) do
		task.spawn(addSpin, m)
	end
	CollectionService:GetInstanceAddedSignal("SpinBob"):Connect(function(m)
		task.spawn(addSpin, m)
	end)
	CollectionService:GetInstanceRemovedSignal("SpinBob"):Connect(function(m)
		spinning[m] = nil
	end)
	local function regGate(p)
		gates[p] = true
		applyGate(p)
	end
	for _, p in ipairs(CollectionService:GetTagged("ZoneGate")) do
		regGate(p)
	end
	CollectionService:GetInstanceAddedSignal("ZoneGate"):Connect(regGate)
	store.Changed.Event:Connect(function()
		for p in pairs(gates) do
			if p.Parent then
				applyGate(p)
			end
		end
	end)
	tintFx = Lighting:FindFirstChild("ZoneTint") or Instance.new("ColorCorrectionEffect")
	tintFx.Name = "ZoneTint"
	tintFx.Parent = Lighting
	RunService.RenderStepped:Connect(function(dt)
		local cam = Workspace.CurrentCamera
		if cam then
			local target = MOODS[MapConfig.ZoneAt(cam.CFrame.Position.Z)] or MOODS.city
			local a = math.min(1, dt * 1.2)
			mood.clock = mood.clock + (target.clock - mood.clock) * a
			mood.bright = mood.bright + (target.bright - mood.bright) * a
			mood.sat = mood.sat + (target.sat - mood.sat) * a
			mood.tint = mood.tint:Lerp(target.tint, a)
			mood.amb = mood.amb:Lerp(target.amb, a)
			Lighting.ClockTime = mood.clock
			Lighting.Brightness = mood.bright
			Lighting.OutdoorAmbient = mood.amb
			tintFx.TintColor = mood.tint
			tintFx.Saturation = mood.sat
		end
		local t = os.clock()
		-- (v10: showcase cars stand still on static stands - no turntable spinning)
		if t - lastBackfire > 2.2 then
			lastBackfire = t
			local camPos = cam and cam.CFrame.Position or Vector3.zero
			for _, att in ipairs(CollectionService:GetTagged("Backfire")) do
				if att.Parent and (att.WorldPosition - camPos).Magnitude < 140 and math.random() < 0.45 then
					local fire = att:FindFirstChildOfClass("ParticleEmitter")
					if fire then
						fire:Emit(14)
					end
				end
			end
		end
		for m, s in pairs(spinning) do
			if s.root.Parent then
				s.root.CFrame = s.base * CFrame.Angles(0, t * 2 + s.phase, 0) + Vector3.new(0, math.sin(t * 2 + s.phase) * 0.5, 0)
			else
				spinning[m] = nil
			end
		end
	end)
end

function Fx.Hit(dir, flashFrame)
	local char = Players.LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.AssemblyLinearVelocity = dir.Unit * 70 + Vector3.new(0, 40, 0)
	end
	if flashFrame then
		flashFrame.BackgroundTransparency = 0.55
		task.spawn(function()
			for i = 1, 10 do
				flashFrame.BackgroundTransparency = 0.55 + i * 0.045
				task.wait(0.03)
			end
			flashFrame.BackgroundTransparency = 1
		end)
	end
end

return Fx
