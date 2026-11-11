-- WRECKED! sequence: impact flash, heavy shake, glitch, grayscale-red grade, crane-up camera, countdown.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local PartConfig = require(Shared:WaitForChild("PartConfig"))
local Cine = require(script.Parent:WaitForChild("CineFx"))

local DeathFx = {}
local ICON = { bolts = "🔩", tire = "🛞", engine = "⚙️", turbo = "🌀", core = "⚡" }
local running = false

function DeathFx.Play(dir, lost, sfx)
	if running then
		return
	end
	running = true
	local player = Players.LocalPlayer
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if char then
		DeathFx.Ragdoll(char)
	end
	if hrp then -- the car launches the ragdoll
		hrp.AssemblyLinearVelocity = dir.Unit * 85 + Vector3.new(0, 60, 0)
		hrp.AssemblyAngularVelocity = Vector3.new(math.random(-15, 15), math.random(-15, 15), math.random(-15, 15))
		DeathFx.Shards(hrp.Position)
	end
	if sfx then
		sfx("crash")
		sfx("wrecked")
	end
	-- freeze-frame punch: hard contrast for a beat, then a cold grey grade
	Cine.Grade({ Saturation = -1, Contrast = 0.6, Brightness = 0.15, TintColor = Color3.fromRGB(255, 200, 200) }, 0)
	Cine.Shake(4, 0.7)
	task.delay(0.12, function()
		Cine.Grade({ Saturation = -0.85, Contrast = 0.25, Brightness = -0.05, TintColor = Color3.fromRGB(255, 190, 190) }, 0.4)
	end)
	Cine.Letterbox(true, 0.2)
	Cine.Title(Strings.T("wrecked"), Color3.fromRGB(255, 59, 59), 2.4, 170, 0.36)

	local parts = {}
	for _, id in ipairs(PartConfig.Order) do
		if lost and (lost[id] or 0) > 0 then
			table.insert(parts, (ICON[id] or "") .. " x" .. lost[id])
		end
	end
	task.delay(0.4, function()
		if #parts > 0 then
			Cine.Sub(Strings.T("wrecked_lost", table.concat(parts, "   ")), Color3.fromRGB(255, 210, 63), 2.2, 0.55)
		end
		Cine.Sub(Strings.T("wrecked_safe"), Color3.fromRGB(255, 255, 255), 2.2, 0.62)
	end)

	-- crane shot rising above the crash site
	task.delay(0.25, function()
		local cam = Cine.Take()
		local focus = hrp and hrp.Position or cam.CFrame.Position
		local from = cam.CFrame
		local t0 = os.clock()
		Cine.Blur(4, 1.5)
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local a = math.min(1, (os.clock() - t0) / 2.6)
			local e = 1 - (1 - a) ^ 3
			local target = CFrame.lookAt(focus + Vector3.new(math.cos(e * 1.2) * 18, 8 + e * 38, math.sin(e * 1.2) * 18), focus)
			cam.CFrame = from:Lerp(target, math.min(1, a * 3)) * CFrame.Angles(0, 0, math.rad(8 * (1 - e)))
			if a >= 1 then
				conn:Disconnect()
			end
		end)
		for n = 3, 1, -1 do
			task.wait(0.8)
			Cine.Sub(Strings.T("wrecked_back", n), Color3.fromRGB(255, 255, 255), 0.6, 0.7)
		end
	end)
end

-- joints become ball sockets so the body flops (BreakJointsOnDeath is off on the server)
function DeathFx.Ragdoll(char)
	for _, m in ipairs(char:GetDescendants()) do
		if m:IsA("Motor6D") and m.Part0 and m.Part1 and m.Name ~= "Root" then
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.CFrame, a1.CFrame = m.C0, m.C1
			a0.Parent, a1.Parent = m.Part0, m.Part1
			local bs = Instance.new("BallSocketConstraint")
			bs.Attachment0, bs.Attachment1 = a0, a1
			bs.LimitsEnabled = true
			bs.UpperAngle = 70
			bs.TwistLimitsEnabled = true
			bs.TwistLowerAngle, bs.TwistUpperAngle = -45, 45
			bs.Parent = m.Part0
			m.Enabled = false
		end
	end
	for _, p in ipairs(char:GetChildren()) do
		if p:IsA("BasePart") then
			p.CanCollide = p.Name ~= "HumanoidRootPart"
		end
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:ChangeState(Enum.HumanoidStateType.Physics)
	end
end

-- windscreen shards + dust where the car hit
function DeathFx.Shards(pos)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
	p.Size = Vector3.one
	p.Position = pos
	p.Parent = workspace
	local glass = Instance.new("ParticleEmitter")
	glass.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	glass.Color = ColorSequence.new(Color3.fromRGB(220, 240, 255), Color3.fromRGB(150, 200, 230))
	glass.Size = NumberSequence.new(0.45, 0.1)
	glass.Lifetime = NumberRange.new(0.8, 1.3)
	glass.Speed = NumberRange.new(18, 34)
	glass.SpreadAngle = Vector2.new(180, 180)
	glass.Acceleration = Vector3.new(0, -60, 0)
	glass.RotSpeed = NumberRange.new(-300, 300)
	glass.LightEmission = 0.4
	glass.Rate = 0
	glass.Parent = p
	glass:Emit(60)
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(180, 176, 170))
	dust.Size = NumberSequence.new(2, 7)
	dust.Transparency = NumberSequence.new(0.4, 1)
	dust.Lifetime = NumberRange.new(1, 1.6)
	dust.Speed = NumberRange.new(6, 12)
	dust.SpreadAngle = Vector2.new(180, 40)
	dust.Rate = 0
	dust.Parent = p
	dust:Emit(16)
	task.delay(3, function()
		p:Destroy()
	end)
end

-- called on respawn
function DeathFx.Recover()
	if not running then
		return
	end
	running = false
	Cine.Release(0.2)
	Cine.Reset(0.5)
	Cine.Flash(Color3.new(0, 0, 0), 0, 0.6)
end

return DeathFx
