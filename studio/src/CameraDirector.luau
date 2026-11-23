-- Owner camera mode (Shift+C, or Settings → Camera). Only for the owner account (server-checked "ownerEligible").
--   1 Free flight: WASD move, Q/E down/up, hold right mouse to look, Shift = fast, Alt = precise, wheel = speed,
--     Z/X = zoom (FOV), R/T = tilt (Dutch angle), Backspace = reset zoom/tilt. Film filters switch on with it.
--   2 Orbit: smooth circle around your character, wheel = distance, W/S = height.
--   3 Shots: an automatic director cycles beautiful preset shots of the map.
--   F = next filter (Film, Golden hour, Noir, Dream, Off), H = hide/show this toolbar, Shift+C = leave.
-- Phone: left joystick = move (orbit: height / turn), drag anywhere else = look, pinch = zoom, buttons on the right =
--   up / down / speed / zoom. Gamepad: left stick move, right stick look, L2 / R2 down / up.
-- Everything is client-side: new Lighting effects and a ScreenGui, all removed when the mode is left.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local Run = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.Shared.Config)
local plr = Players.LocalPlayer
local cam = workspace.CurrentCamera
local V = Vector3.new
local WHITE = Color3.new(1, 1, 1)
local function smooth(x) x = math.clamp(x, 0, 1); return x * x * (3 - 2 * x) end

local FILTERS = { -- soft grades: bloom only on real highlights (threshold > 1.8), never brighter than the scene
	{ name = "Film", tint = Color3.fromRGB(255, 249, 242), contrast = 0.1, saturation = 0.04, brightness = -0.02, exposure = -0.1, bloom = { 0.2, 18, 2 }, rays = 0.015, dof = { 0.25, 0.1 }, blur = 0, bars = true, vignette = 0.45 },
	{ name = "Golden hour", tint = Color3.fromRGB(255, 234, 212), contrast = 0.08, saturation = 0.1, brightness = -0.03, exposure = -0.15, bloom = { 0.25, 20, 1.9 }, rays = 0.02, dof = { 0.22, 0.08 }, blur = 0, bars = true, vignette = 0.4 },
	{ name = "Noir", tint = WHITE, contrast = 0.12, saturation = -1, brightness = -0.02, exposure = -0.05, bloom = { 0.12, 16, 2.4 }, rays = 0, dof = { 0.3, 0.12 }, blur = 0, bars = true, vignette = 0.6 },
	{ name = "Dream", tint = Color3.fromRGB(252, 244, 255), contrast = 0, saturation = 0.12, brightness = -0.02, exposure = -0.12, bloom = { 0.3, 24, 1.8 }, rays = 0.02, dof = { 0.25, 0.1 }, blur = 0, bars = false, vignette = 0.3 },
	{ name = "Off" },
}
local MODES = { "Free flight", "Orbit", "Shots" }

local active, mode, filterIdx = false, 1, 1
local baseExposure -- Lighting.ExposureCompensation before the camera mode
local fx, hiddenGuis, savedAnchor = {}, {}, nil
local pos, yaw, pitch, tYaw, tPitch, roll, fov = Vector3.zero, 0, 0, 0, 0, 0, 70
local vel, baseSpeed, looking = Vector3.zero, 40, false
local orbit = { center = Vector3.zero, angle = 0, dist = 26, height = 9 }
local shot = { idx = 0, t0 = 0, list = nil }

-- ===== overlay: letterbox, vignette, fade, toolbar =====
local gui = Instance.new("ScreenGui")
gui.Name, gui.IgnoreGuiInset, gui.ResetOnSpawn, gui.DisplayOrder, gui.Enabled = "CameraDirector", true, false, 50, false
local function frame(props, parent)
	local f = Instance.new("Frame")
	f.BorderSizePixel, f.BackgroundColor3 = 0, Color3.new()
	for k, v in props do f[k] = v end
	f.Parent = parent or gui
	return f
end
local bars = { frame({ Size = UDim2.fromScale(1, 0) }), frame({ Size = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1) }) }
local vignette = {}
for i, side in { { UDim2.fromScale(0.22, 1), UDim2.fromScale(0, 0), 0 }, { UDim2.fromScale(0.22, 1), UDim2.fromScale(0.78, 0), 180 },
	{ UDim2.fromScale(1, 0.25), UDim2.fromScale(0, 0), 90 }, { UDim2.fromScale(1, 0.25), UDim2.fromScale(0, 0.75), 270 } } do
	local f = frame({ Size = side[1], Position = side[2] })
	local g = Instance.new("UIGradient")
	g.Rotation, g.Parent = side[3], f
	vignette[i] = g
end
local fade = frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5 })
local bar = frame({ Size = UDim2.fromOffset(560, 92), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16), BackgroundTransparency = 0.25, ZIndex = 10 })
Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 16)
local status = Instance.new("TextLabel")
status.Size, status.Position, status.BackgroundTransparency = UDim2.new(1, -20, 0, 30), UDim2.fromOffset(10, 6), 1
status.FontFace, status.TextScaled, status.TextColor3, status.TextXAlignment, status.ZIndex = C.UI.Font, true, WHITE, Enum.TextXAlignment.Left, 11
status.Parent = bar
local buttons = Instance.new("Frame")
buttons.Size, buttons.Position, buttons.BackgroundTransparency, buttons.ZIndex, buttons.Parent = UDim2.new(1, -20, 0, 40), UDim2.fromOffset(10, 44), 1, 11, bar
local list = Instance.new("UIListLayout")
list.FillDirection, list.Padding, list.Parent = Enum.FillDirection.Horizontal, UDim.new(0, 6), buttons
local function addButton(text, fn)
	local b = Instance.new("TextButton")
	b.Size, b.BackgroundColor3, b.TextColor3, b.FontFace, b.TextScaled, b.Text, b.ZIndex = UDim2.fromOffset(84, 40), Color3.fromRGB(255, 190, 40), C.UI.Ink, C.UI.Font, true, text, 12
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
	b.Activated:Connect(fn)
	b.Parent = buttons
end
local corner = Instance.new("TextButton") -- tapping the top-right corner brings a hidden toolbar back (touch screens)
corner.Size, corner.AnchorPoint, corner.Position, corner.BackgroundTransparency, corner.Text = UDim2.fromOffset(90, 90), Vector2.new(1, 0), UDim2.fromScale(1, 0), 1, ""
corner.Activated:Connect(function() bar.Visible = true end)
corner.Parent = gui
-- ===== touch controls (phones / tablets) =====
local touch = { stick = Vector2.zero, input = nil, hold = {}, pad = Vector2.zero, look = Vector2.zero, trig = 0 }
local pad = Instance.new("Frame")
pad.Name, pad.Size, pad.BackgroundTransparency, pad.Visible, pad.Parent = "TouchControls", UDim2.fromScale(1, 1), 1, false, gui
local stickBase = Instance.new("Frame")
stickBase.Size, stickBase.AnchorPoint, stickBase.Position = UDim2.fromOffset(200, 200), Vector2.new(0, 1), UDim2.new(0, 36, 1, -36)
stickBase.BackgroundColor3, stickBase.BackgroundTransparency, stickBase.Active, stickBase.ZIndex = Color3.new(), 0.55, true, 20
Instance.new("UICorner", stickBase).CornerRadius = UDim.new(1, 0)
local ring = Instance.new("UIStroke")
ring.Thickness, ring.Color, ring.Transparency, ring.Parent = 3, WHITE, 0.4, stickBase
stickBase.Parent = pad
local knob = Instance.new("Frame")
knob.Size, knob.AnchorPoint, knob.Position = UDim2.fromOffset(86, 86), Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
knob.BackgroundColor3, knob.BackgroundTransparency, knob.ZIndex = WHITE, 0.15, 21
Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
knob.Parent = stickBase
local function setKnob()
	knob.Position = UDim2.new(0.5, touch.stick.X * 57, 0.5, -touch.stick.Y * 57)
end
stickBase.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch and not touch.input then touch.input = input end
end)
local side = Instance.new("Frame")
side.Size, side.AnchorPoint, side.Position, side.BackgroundTransparency = UDim2.fromOffset(176, 330), Vector2.new(1, 1), UDim2.new(1, -24, 1, -30), 1
side.Parent = pad
local grid = Instance.new("UIGridLayout")
grid.CellSize, grid.CellPadding, grid.SortOrder, grid.Parent = UDim2.fromOffset(80, 74), UDim2.fromOffset(12, 10), Enum.SortOrder.LayoutOrder, side
local function padButton(order, text, onHold, onTap)
	local b = Instance.new("TextButton")
	b.LayoutOrder, b.Text, b.FontFace, b.TextScaled, b.ZIndex = order, text, C.UI.Font, true, 20
	b.BackgroundColor3, b.BackgroundTransparency, b.TextColor3, b.AutoButtonColor = Color3.new(), 0.45, WHITE, false
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 18)
	local st = Instance.new("UIStroke")
	st.Thickness, st.Color, st.Transparency, st.ApplyStrokeMode, st.Parent = 2, WHITE, 0.5, Enum.ApplyStrokeMode.Border, b
	local tp = Instance.new("UIPadding")
	tp.PaddingTop, tp.PaddingBottom, tp.PaddingLeft, tp.PaddingRight, tp.Parent = UDim.new(0, 14), UDim.new(0, 14), UDim.new(0, 8), UDim.new(0, 8), b
	b.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		b.BackgroundTransparency = 0.15
		if onHold then touch.hold[onHold] = true end
		if onTap then onTap() end
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		b.BackgroundTransparency = 0.45
		if onHold then touch.hold[onHold] = nil end
	end)
	b.Parent = side
end
local refreshStatus -- forward (defined below)
padButton(1, "UP", "up")
padButton(2, "ZOOM +", "zoomIn")
padButton(3, "DOWN", "down")
padButton(4, "ZOOM −", "zoomOut")
padButton(5, "SPEED +", nil, function() baseSpeed = math.clamp(math.floor(baseSpeed * 1.4 + 0.5), 2, 600); refreshStatus() end)
padButton(6, "SPEED −", nil, function() baseSpeed = math.clamp(math.floor(baseSpeed / 1.4 + 0.5), 2, 600); refreshStatus() end)
padButton(7, "TILT ⟲", "rollL")
padButton(8, "TILT ⟳", "rollR")
gui.Parent = plr:WaitForChild("PlayerGui")

-- ===== filters =====
local function effect(class, name)
	local e = Instance.new(class)
	e.Name, e.Parent = "Director" .. name, Lighting
	fx[name] = e
	return e
end
local function applyFilter()
	local f = FILTERS[filterIdx]
	local on = f.name ~= "Off"
	fx.cc.Enabled, fx.bloom.Enabled, fx.rays.Enabled, fx.dof.Enabled, fx.blur.Enabled = on, on, on, on, on
	if on then
		fx.cc.TintColor, fx.cc.Contrast, fx.cc.Saturation, fx.cc.Brightness = f.tint, f.contrast, f.saturation, f.brightness
		fx.bloom.Intensity, fx.bloom.Size, fx.bloom.Threshold = f.bloom[1], f.bloom[2], f.bloom[3]
		fx.rays.Intensity, fx.rays.Spread = f.rays, 0.6
		fx.dof.FarIntensity, fx.dof.NearIntensity = f.dof[1], f.dof[2]
		fx.blur.Size = f.blur
	end
	if baseExposure == nil then baseExposure = Lighting.ExposureCompensation end
	Lighting.ExposureCompensation = baseExposure + (on and f.exposure or 0)
	local view = cam.ViewportSize
	local barH = (on and f.bars) and math.max(0, (1 - (view.X / 2.39) / view.Y) / 2) or 0 -- 2.39:1 cinema frame
	for _, b in bars do b.Size = UDim2.fromScale(1, barH) end
	local v = on and f.vignette or 0
	for _, g in vignette do
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 - v), NumberSequenceKeypoint.new(1, 1) })
		g.Parent.Visible = v > 0
	end
end

function refreshStatus()
	status.Text = string.format("CAMERA  ·  %s  ·  %s  ·  speed %d  ·  FOV %d", MODES[mode], FILTERS[filterIdx].name, baseSpeed, fov)
end

-- ===== cinematic shots (computed from the live map) =====
local function boxOf(name)
	local world = workspace:FindFirstChild("World")
	local m = world and world:FindFirstChild(name, true)
	if not m then return nil end
	if m:IsA("Model") then return m:GetBoundingBox() end
	return m.CFrame, m.Size
end

-- Safe box: shots may only move inside the hall or under the long-table ceiling (never outside the place).
local HALL = { x = C.Arena.HallHalfWidth - 9, z0 = C.Arena.HallBack + 6, z1 = C.Table.StartZ - 6, y1 = 30 }
local LANE_END = C.Table.StartZ + C.Table.Length - 6
local function safe(p)
	if p.Z < HALL.z1 then
		return V(math.clamp(p.X, -HALL.x, HALL.x), math.clamp(p.Y, 2, HALL.y1), math.clamp(p.Z, HALL.z0, HALL.z1))
	end
	return V(math.clamp(p.X, -28, 28), math.clamp(p.Y, 2, 32), math.clamp(p.Z, C.Table.StartZ - 6, LANE_END))
end
local function tableZ(k) return C.Table.StartZ + (k - 0.5) * C.Table.SegmentLength end

-- local props of the current shot (cue, balls), destroyed when the shot ends
local shotProps = Instance.new("Folder")
shotProps.Name = "DirectorProps"
local function localBall(color, size, at)
	local b = Instance.new("Part")
	b.Shape, b.Size, b.Color, b.Material = Enum.PartType.Ball, Vector3.one * size, color, Enum.Material.SmoothPlastic
	b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch, b.CFrame = true, false, false, false, CFrame.new(at)
	b.Parent = shotProps
	return b
end
local BALL_COLORS = { Color3.fromRGB(250, 200, 30), Color3.fromRGB(30, 80, 200), Color3.fromRGB(220, 40, 40), Color3.fromRGB(110, 40, 170),
	Color3.fromRGB(255, 120, 20), Color3.fromRGB(20, 140, 70), Color3.fromRGB(130, 30, 30), Color3.fromRGB(20, 20, 22) }

-- Each shot: seconds, FOV, optional setup(), and frame(u, dt) -> eye, look-at (u = 0..1 over the shot)
local function buildShots()
	local T = C.Table
	local rnd = Random.new()
	local baseCf = boxOf("Base" .. (_G.MySlot or 1))
	local mine = baseCf and baseCf.Position or V(0, 0, 0)
	local tableCf, tableSize
	local poolModel = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Base" .. (_G.MySlot or 1))
	poolModel = poolModel and poolModel:FindFirstChild("PoolTable")
	if poolModel then tableCf, tableSize = poolModel:GetBoundingBox() end
	local shots = {}
	local function add(sec, fovv, frame, setup) table.insert(shots, { sec = sec, fov = fovv, frame = frame, setup = setup }) end

	-- 1 your base: slow orbit around the pool table
	add(7, 42, function(u)
		local a = 0.6 + u * 1.6
		return mine + V(math.cos(a) * 15, 6.5, math.sin(a) * 15), mine + V(0, 2.5, 0)
	end)
	-- 2 balls rolling on your base table (local balls, bouncing on the felt)
	if tableCf then
		local top = tableCf.Position.Y + tableSize.Y / 2 - 0.4
		local half = V(tableSize.X * 0.36, 0, tableSize.Z * 0.36)
		local balls = {}
		add(8, 38, function(u, dt)
			for _, b in balls do
				b.pos += b.vel * dt
				if math.abs(b.pos.X - tableCf.Position.X) > half.X then b.vel = V(-b.vel.X, 0, b.vel.Z) end
				if math.abs(b.pos.Z - tableCf.Position.Z) > half.Z then b.vel = V(b.vel.X, 0, -b.vel.Z) end
				b.vel *= 1 - 0.12 * dt
				b.rot = CFrame.fromAxisAngle(Vector3.yAxis:Cross(b.vel.Magnitude > 0 and b.vel.Unit or Vector3.xAxis), b.vel.Magnitude * dt / 0.5) * b.rot
				b.part.CFrame = CFrame.new(b.pos) * b.rot
			end
			local a = u * 2.4
			local c = tableCf.Position
			return c + V(math.cos(a) * 11, 4.5, math.sin(a) * 11), c + V(0, 0.5, 0)
		end, function()
			table.clear(balls)
			for k, col in BALL_COLORS do
				local pos = tableCf.Position + V(rnd:NextNumber(-half.X, half.X), 0, rnd:NextNumber(-half.Z, half.Z))
				pos = V(pos.X, top + 0.5, pos.Z)
				local a = rnd:NextNumber(0, math.pi * 2)
				balls[k] = { part = localBall(col, 1, pos), pos = pos, vel = V(math.cos(a), 0, math.sin(a)) * rnd:NextNumber(6, 12), rot = CFrame.new() }
			end
		end)
	end
	-- 3 the strike: a cue hits the cue ball, the camera chases it down the lane
	local lane = C.LaneX(2)
	local ballY = T.FeltY + 1.1
	local start = V(lane, ballY, T.StartZ + 12)
	local cueBall, cue
	add(7, 50, function(u)
		local t = u * 7
		local pull = 1.6 * smooth(t / 1.1) * (1 - smooth((t - 1.2) / 0.12))
		local hit = t >= 1.3
		local roll = hit and (1 - (1 - math.clamp((t - 1.3) / 5.4, 0, 1)) ^ 2) * 150 or 0
		local bpos = start + V(0, 0, roll)
		cueBall.CFrame = CFrame.new(bpos) * CFrame.Angles(roll / 1.1, 0, 0)
		local centre = start + V(0, 0.3, -(6.1 + pull)) -- 10-stud cue: its tip touches the ball when pull = 0
		cue.CFrame = CFrame.lookAt(centre, centre + V(0, -0.03, 1))
		if t < 1.3 then
			return start + V(4, 3, -9), start + V(0, 0.5, 2)
		end
		return bpos + V(2.5, 5, -12), bpos + V(0, 0.5, 6)
	end, function()
		cueBall = localBall(Color3.fromRGB(250, 248, 240), 2.2, start)
		cue = Instance.new("Part")
		cue.Size, cue.Color, cue.Material = V(0.35, 0.35, 10), Color3.fromRGB(222, 184, 128), Enum.Material.Wood
		cue.Anchored, cue.CanCollide, cue.CanQuery, cue.CanTouch = true, false, false, false
		cue.Parent = shotProps
	end)
	-- 4 dolly over the long table under the lamps
	add(9, 55, function(u)
		local z = T.StartZ - 4 + u * 520
		return V(7, 21, z), V(0, 6, z + 60) -- beside the lamp rods, never through them
	end)
	-- 5 low glide along the felt
	add(7, 36, function(u)
		local z = T.StartZ + 20 + u * 300
		return V(C.LaneX(3), T.FeltY + 1.4, z), V(C.LaneX(3), T.FeltY + 1, z + 40)
	end)
	-- 6 the New Year table, then two random themed tables: slow pans past the rails and the scenery
	local picks = { 21, rnd:NextInteger(2, 20), rnd:NextInteger(22, #C.Tables) }
	for n, k in picks do
		local zc = tableZ(k)
		local sideX = n % 2 == 0 and 1 or -1
		add(7, 45, function(u)
			return V(sideX * 7, 9 - 2 * u, zc - 34 + 56 * u), V(sideX * 22, 5, zc - 10 + 40 * u)
		end)
	end
	-- 7 crane in the hall towards the long table
	add(8, 55, function(u)
		return V(0, 6 + 20 * smooth(u), HALL.z0 + 10 + 30 * u), V(0, 4, T.StartZ + 40)
	end)
	return shots
end

local function startShot(k)
	shotProps:ClearAllChildren()
	shot.idx, shot.t0 = k, os.clock()
	local s = shot.list[k]
	if s.setup then s.setup() end
end

-- ===== enter / leave =====
local function setOthers(visible)
	if visible then
		for g in hiddenGuis do if g.Parent then g.Enabled = true end end
		table.clear(hiddenGuis)
	else
		for _, g in plr.PlayerGui:GetChildren() do
			if g:IsA("ScreenGui") and g ~= gui and g.Enabled then
				hiddenGuis[g] = true
				g.Enabled = false
			end
		end
	end
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, visible)
end

local function hrp() return plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") end

local function setMode(m)
	mode = m
	vel = Vector3.zero
	if m == 1 then
		local x, y = cam.CFrame:ToOrientation()
		pos, pitch, yaw, tPitch, tYaw = cam.CFrame.Position, x, y, x, y
		if FILTERS[filterIdx].name == "Off" then filterIdx = 1 end -- free flight always starts with the film look
		applyFilter()
	elseif m == 2 then
		local root = hrp()
		orbit.center = root and root.Position or cam.CFrame.Position + cam.CFrame.LookVector * 20
	else
		shotProps.Parent = workspace
		shot.list = buildShots()
		startShot(1)
	end
	refreshStatus()
end

local function leave()
	if not active then return end
	active = false
	shotProps:ClearAllChildren()
	shotProps.Parent = nil
	Run:UnbindFromRenderStep("CameraDirector")
	for _, e in fx do e:Destroy() end
	if baseExposure ~= nil then Lighting.ExposureCompensation, baseExposure = baseExposure, nil end
	table.clear(fx)
	gui.Enabled = false
	setOthers(true)
	local root = hrp()
	if root and savedAnchor ~= nil then root.Anchored = savedAnchor end
	savedAnchor = nil
	UIS.MouseBehavior = Enum.MouseBehavior.Default
	cam.FieldOfView = 70
	cam.CameraType = Enum.CameraType.Custom
end

local update -- forward
local function enter()
	if active or not _G.OwnerEligible or _G.ThrowBusy then return end
	active = true
	effect("ColorCorrectionEffect", "cc")
	effect("BloomEffect", "bloom")
	effect("SunRaysEffect", "rays")
	effect("DepthOfFieldEffect", "dof")
	effect("BlurEffect", "blur")
	setOthers(false)
	local root = hrp()
	if root then
		savedAnchor = root.Anchored
		root.Anchored = true -- the character waits where it stands
	end
	cam.CameraType = Enum.CameraType.Scriptable
	fov, roll = cam.FieldOfView, 0
	gui.Enabled, bar.Visible = true, true
	pad.Visible = UIS.TouchEnabled
	setMode(1)
	Run:BindToRenderStep("CameraDirector", Enum.RenderPriority.Camera.Value + 2, update)
end
_G.ToggleCameraMode = function() if active then leave() else enter() end end

addButton("Fly", function() setMode(1) end)
addButton("Orbit", function() setMode(2) end)
addButton("Shots", function() setMode(3) end)
addButton("Filter", function() filterIdx = filterIdx % #FILTERS + 1; applyFilter(); refreshStatus() end)
addButton("Hide", function() bar.Visible = false end)
addButton("Exit", leave)

-- ===== input =====
UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	local k = input.KeyCode
	if k == Enum.KeyCode.C and (UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift)) then
		_G.ToggleCameraMode()
		return
	end
	if not active then return end
	if k == Enum.KeyCode.One then setMode(1)
	elseif k == Enum.KeyCode.Two then setMode(2)
	elseif k == Enum.KeyCode.Three then setMode(3)
	elseif k == Enum.KeyCode.F then filterIdx = filterIdx % #FILTERS + 1; applyFilter(); refreshStatus()
	elseif k == Enum.KeyCode.H then bar.Visible = not bar.Visible
	elseif k == Enum.KeyCode.Backspace then fov, roll = 70, 0; refreshStatus()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		looking = true
		UIS.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	end
end)
UIS.InputEnded:Connect(function(input)
	if input == touch.input then
		touch.input, touch.stick = nil, Vector2.zero
		setKnob()
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 and active then
		looking = false
		UIS.MouseBehavior = Enum.MouseBehavior.Default
	end
end)
UIS.InputChanged:Connect(function(input, processed)
	if not active then return end
	local t = input.UserInputType
	if input == touch.input then -- the joystick
		local c = stickBase.AbsolutePosition + stickBase.AbsoluteSize / 2
		local d = Vector2.new(input.Position.X, input.Position.Y) - c
		d = d.Magnitude > 57 and d.Unit * 57 or d
		touch.stick = Vector2.new(d.X, -d.Y) / 57
		setKnob()
		return
	end
	if t == Enum.UserInputType.Gamepad1 then
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then touch.pad = Vector2.new(input.Position.X, input.Position.Y)
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then touch.look = Vector2.new(input.Position.X, input.Position.Y)
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then touch.trig = input.Position.Z
		elseif input.KeyCode == Enum.KeyCode.ButtonL2 then touch.trig = -input.Position.Z end
		return
	end
	if (t == Enum.UserInputType.MouseMovement and looking) or (t == Enum.UserInputType.Touch and not processed) then
		local k = (t == Enum.UserInputType.Touch and 0.006 or 0.0035) * fov / 70
		tYaw -= input.Delta.X * k
		tPitch = math.clamp(tPitch - input.Delta.Y * k, -1.45, 1.45)
	elseif t == Enum.UserInputType.MouseWheel and not processed then
		local d = input.Position.Z
		if mode == 1 then baseSpeed = math.clamp(math.floor(baseSpeed * (d > 0 and 1.2 or 1 / 1.2) + 0.5), 2, 600)
		elseif mode == 2 then orbit.dist = math.clamp(orbit.dist * (d > 0 and 0.9 or 1.1), 6, 400) end
		refreshStatus()
	end
end)
local pinchFov
UIS.TouchPinch:Connect(function(_, scale, _, state, processed) -- two fingers: zoom
	if not active or processed then return end
	if state == Enum.UserInputState.Begin then pinchFov = fov end
	if pinchFov then fov = math.clamp(pinchFov / scale, 20, 100); refreshStatus() end
	if state == Enum.UserInputState.End then pinchFov = nil end
end)
plr.CharacterRemoving:Connect(leave)

-- ===== per frame =====
local function key(k) return UIS:IsKeyDown(k) and 1 or 0 end
update = function(dt)
	if _G.ThrowBusy then leave(); return end -- a shot cinematic takes the camera
	local K = Enum.KeyCode
	-- zoom and tilt (all modes)
	local h = touch.hold
	local z = key(K.X) - key(K.Z) + (h.zoomOut and 1 or 0) - (h.zoomIn and 1 or 0)
	if z ~= 0 then fov = math.clamp(fov + z * 40 * dt, 20, 100); refreshStatus() end
	roll = roll + (key(K.T) - key(K.R) + (h.rollR and 1 or 0) - (h.rollL and 1 or 0)) * 0.6 * dt
	local stick = touch.stick + (touch.pad.Magnitude > 0.15 and touch.pad or Vector2.zero) -- joystick + gamepad
	if touch.look.Magnitude > 0.15 then -- gamepad right stick looks around
		tYaw -= touch.look.X * 2.2 * dt
		tPitch = math.clamp(tPitch + touch.look.Y * 1.6 * dt, -1.45, 1.45)
	end
	local lift = (h.up and 1 or 0) - (h.down and 1 or 0) + (math.abs(touch.trig) > 0.1 and touch.trig or 0)
	if mode == 1 then
		yaw += (tYaw - yaw) * math.min(1, dt * 14) -- damped look: no jitter
		pitch += (tPitch - pitch) * math.min(1, dt * 14)
		local rot = CFrame.fromOrientation(pitch, yaw, 0)
		local move = rot:VectorToWorldSpace(V(key(K.D) - key(K.A) + stick.X, 0, key(K.S) - key(K.W) - stick.Y)) + V(0, key(K.E) - key(K.Q) + lift, 0)
		local speed = baseSpeed * (UIS:IsKeyDown(K.LeftShift) and 4 or 1) * (UIS:IsKeyDown(K.LeftAlt) and 0.25 or 1)
		local amount = math.min(1, move.Magnitude) -- a half-pushed joystick flies at half speed
		vel = vel:Lerp(move.Magnitude > 0.01 and move.Unit * speed * amount or Vector3.zero, math.min(1, dt * 6)) -- smooth start/stop
		pos += vel * dt
		cam.CFrame = CFrame.new(pos) * rot * CFrame.Angles(0, 0, roll)
	elseif mode == 2 then
		orbit.angle += dt * (0.22 + stick.X * 0.8)
		orbit.height = math.clamp(orbit.height + (key(K.W) - key(K.S) + stick.Y + lift) * 20 * dt, -10, 200)
		local c = orbit.center
		local eye = c + V(math.cos(orbit.angle) * orbit.dist, orbit.height, math.sin(orbit.angle) * orbit.dist)
		cam.CFrame = CFrame.lookAt(eye, c + V(0, 2, 0)) * CFrame.Angles(0, 0, roll)
	else
		local s = shot.list[shot.idx]
		local u = (os.clock() - shot.t0) / s.sec
		if u >= 1 then
			if shot.idx == #shot.list then shot.list = buildShots() end -- new random tables every round
			startShot(shot.idx % #shot.list + 1)
			s, u = shot.list[shot.idx], 0
		end
		local eye, at = s.frame(u, dt)
		cam.CFrame = CFrame.lookAt(safe(eye), at) * CFrame.Angles(0, 0, roll)
		fade.BackgroundTransparency = math.min(1, math.min(u, 1 - u) * s.sec / 0.5) -- dip to black between shots
		cam.FieldOfView = s.fov * fov / 70
	end
	if mode ~= 3 then
		fade.BackgroundTransparency = 1
		cam.FieldOfView = fov
	end
	-- depth of field follows whatever is in the middle of the frame
	if fx.dof and fx.dof.Enabled then
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = { plr.Character }
		local hit = workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 800, params)
		local d = hit and (hit.Position - cam.CFrame.Position).Magnitude or 300
		fx.dof.FocusDistance += (d - fx.dof.FocusDistance) * math.min(1, dt * 4)
		fx.dof.InFocusRadius = math.clamp(fx.dof.FocusDistance * 0.35, 4, 80)
	end
end
