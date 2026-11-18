-- Gym training (Start / Stop from the gym menu, the HUD button or the prompt at the dumbbell).
-- The character faces the gym, takes two hand-size copies of the gym dumbbell (same plates as its level) and does
-- alternating bicep curls in time with the server's reps; a "+N" pops over the head on every rep.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.Shared.Config)
local MeshBuilder = require(RS.Shared.MeshBuilder)
local Rig = require(RS.Shared.Rig)
local Fx = RS:WaitForChild("Remotes"):WaitForChild("Fx")
local plr = Players.LocalPlayer

local state

local function setFloorBell(bell, visible)
	local mv = bell and bell:FindFirstChild("MeshVisual")
	if mv then mv.LocalTransparencyModifier = visible and 0 or 1 end
end

local function handBell(source, hand)
	local plate = source:FindFirstChild("Plate")
	local sc = source:FindFirstChild("Scale")
	local k = 0.22 * (sc and sc.Value or 1)
	local b = MeshBuilder.Create("Dumbbell", hand.CFrame, { Plate = plate and plate.Value or Color3.fromRGB(70, 70, 78) }, k)
	if not b then
		b = Instance.new("Part")
		b.Size, b.Shape, b.Color, b.Material = Vector3.new(5.2, 2.3, 2.3) * k, Enum.PartType.Cylinder, plate and plate.Value or Color3.new(0.3, 0.3, 0.3), Enum.Material.Metal
	end
	b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch, b.Massless = false, false, false, false, true
	b.CFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y * 0.35, 0) -- handle across the palm
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1, w.Parent = hand, b, b
	b.Parent = hand.Parent
	return b
end

local function stop()
	if not state then return end
	local s = state
	state = nil
	s.conn:Disconnect()
	for _, b in s.bells do b:Destroy() end
	if s.sweat then s.sweat:Destroy() end
	if s.hum.Parent then
		s.hum.WalkSpeed, s.hum.JumpPower, s.hum.JumpHeight = s.speed, s.jump, s.jumpH
		s.hum.AutoRotate = true
	end
	setFloorBell(s.floor, true)
end

local function start(spotCF, floorBell)
	stop()
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local J = char and Rig.Joints(char)
	if not (hum and hrp and J) then return end
	local s = { hum = hum, speed = hum.WalkSpeed, jump = hum.JumpPower, jumpH = hum.JumpHeight, floor = floorBell, bells = {} }
	hum.WalkSpeed, hum.JumpPower, hum.JumpHeight, hum.AutoRotate = 0, 0, 0, false
	local face = floorBell and Vector3.new(floorBell.Position.X, hrp.Position.Y, floorBell.Position.Z) or hrp.Position + hrp.CFrame.LookVector
	local at = Vector3.new(spotCF.Position.X, hrp.Position.Y, spotCF.Position.Z)
	hrp.CFrame = CFrame.lookAt(at, Vector3.new(face.X, at.Y, face.Z) + (face - at).Unit * 0.01)
	setFloorBell(floorBell, false)
	if floorBell then
		s.bells = { handBell(floorBell, char.RightHand), handBell(floorBell, char.LeftHand) }
	end
	local t0 = os.clock()
	s.conn = RunService.Stepped:Connect(function()
		local t = os.clock() - t0
		local n = t / C.TrainRep
		local curl = math.sin((n % 1) * math.pi) ^ 1.4 -- up, squeeze, down
		local right = math.floor(n) % 2 == 0
		for _, side in { "Right", "Left" } do
			local c = (side == "Right") == right and curl or 0
			local out = side == "Right" and 0.1 or -0.1
			J[side .. "Shoulder"].Transform = CFrame.Angles(0.12 + 0.2 * c, 0, out)
			J[side .. "Elbow"].Transform = CFrame.Angles(0.1 + 2.25 * c, 0, 0)
			J[side .. "Wrist"].Transform = CFrame.Angles(-0.25 * c, 0, 0)
		end
		J.Waist.Transform = CFrame.Angles(-0.04 - 0.05 * curl, 0, (right and 0.03 or -0.03) * curl) -- breathing sway
		J.Neck.Transform = CFrame.Angles(0.05 * curl, 0, 0)
	end)
	task.delay(4, function() -- sweat after a few reps
		if state ~= s or not char:FindFirstChild("Head") then return end
		local e = Instance.new("ParticleEmitter")
		e.Color, e.Rate, e.Lifetime = ColorSequence.new(Color3.fromRGB(170, 220, 255)), 3, NumberRange.new(0.5, 0.8)
		e.Size, e.Speed, e.Acceleration = NumberSequence.new(0.12, 0.05), NumberRange.new(1.5, 2.5), Vector3.new(0, -14, 0)
		e.SpreadAngle, e.Transparency = Vector2.new(60, 60), NumberSequence.new(0.2, 0.6)
		e.Parent = char.Head
		s.sweat = e
	end)
	state = s
	hum.Died:Once(stop)
end

-- "+N" floating over the head on every rep
local function popRep(gain)
	local head = plr.Character and plr.Character:FindFirstChild("Head")
	if not head then return end
	local bb = Instance.new("BillboardGui")
	bb.Size, bb.StudsOffset, bb.AlwaysOnTop, bb.Adornee = UDim2.fromOffset(160, 50), Vector3.new(0, 2.5, 0), true, head
	local l = Instance.new("TextLabel")
	l.Size, l.BackgroundTransparency, l.TextScaled, l.FontFace = UDim2.fromScale(1, 1), 1, true, C.UI.Font
	l.Text, l.TextColor3 = "+" .. C.Short(gain) .. " STR", C.UI.Title
	local st = Instance.new("UIStroke")
	st.Thickness, st.Color, st.Parent = 3, C.UI.Ink, l
	l.Parent, bb.Parent = bb, plr.PlayerGui
	local tw = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(bb, tw, { StudsOffset = Vector3.new(0, 4.5, 0) }):Play()
	TweenService:Create(l, tw, { TextTransparency = 1 }):Play()
	TweenService:Create(st, tw, { Transparency = 1 }):Play()
	task.delay(1, bb.Destroy, bb)
end

Fx.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "Train" then
		if a then start(b, c) else stop() end
	elseif kind == "Rep" then
		popRep(b)
	end
end)
plr.CharacterRemoving:Connect(stop)
