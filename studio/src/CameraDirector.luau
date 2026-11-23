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

local FILTERS = {
	{ name = "Film", tint = Color3.fromRGB(255, 243, 230), contrast = 0.16, saturation = 0.1, brightness = 0.02, bloom = { 0.55, 28, 0.95 }, rays = 0.07, dof = { 0.35, 0.15 }, blur = 0, bars = true, vignette = 0.45 },
	{ name = "Golden hour", tint = Color3.fromRGB(255, 214, 172), contrast = 0.12, saturation = 0.2, brightness = 0.04, bloom = { 0.8, 36, 0.85 }, rays = 0.12, dof = { 0.3, 0.12 }, blur = 0, bars = true, vignette = 0.4 },
	{ name = "Noir", tint = WHITE, contrast = 0.35, saturation = -1, brightness = -0.02, bloom = { 0.2, 20, 1.2 }, rays = 0, dof = { 0.4, 0.2 }, blur = 0, bars = true, vignette = 0.65 },
	{ name = "Dream", tint = Color3.fromRGB(255, 236, 250), contrast = -0.05, saturation = 0.25, brightness = 0.06, bloom = { 1.4, 56, 0.7 }, rays = 0.1, dof = { 0.55, 0.25 }, blur = 3, bars = false, vignette = 0.3 },
	{ name = "Off" },
}
local MODES = { "Free flight", "Orbit", "Shots" }

local active, mode, filterIdx = false, 1, 1
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
	local m = workspace:FindFirstChild("World") and workspace.World:FindFirstChild(name, true)
	if not m then return nil end
	local cf = m:IsA("Model") and m:GetBoundingBox() or m.CFrame
	return cf.Position
end
local function buildShots()
	local T = C.Table
	local mine = boxOf("Base" .. (_G.MySlot or 1)) or V(0, 0, 0)
	local hall = Vector3.zero
	local n = 0
	for i = 1, 4 do
		local p = boxOf("Base" .. i)
		if p then hall += p; n += 1 end
	end
	hall = n > 0 and hall / n or mine
	local deck = V(0, C.ShotZone.LowY + 4, C.ShotZone.EndZ - 4)
	return { -- eye from, look-at from, eye to, look-at to, seconds, FOV
		{ mine + V(16, 7, 16), mine, mine + V(10, 4, -14), mine + V(0, 2, 0), 7, 40 },
		{ hall + V(0, 8, 70), hall, hall + V(0, 75, 45), hall + V(0, 0, -10), 8, 55 },
		{ V(0, 10, T.StartZ - 12), V(0, 6, T.StartZ + 60), V(0, 10, T.StartZ + 520), V(0, 6, T.StartZ + 600), 9, 55 },
		{ V(C.LaneX(2), T.FeltY + 1.3, T.StartZ + 25), V(C.LaneX(2), T.FeltY + 1, T.StartZ + 60), V(C.LaneX(3), T.FeltY + 1.3, T.StartZ + 320), V(C.LaneX(3), T.FeltY + 1, T.StartZ + 360), 7, 35 },
		{ V(-70, 150, T.StartZ + 180), V(0, 0, T.StartZ + 900), V(70, 175, T.StartZ + 520), V(0, 0, T.StartZ + 1300), 8, 50 },
		{ deck + V(0, 6, -34), deck, deck + V(0, 3, -10), deck + V(0, 1, 6), 6, 45 },
	}
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
		shot.list, shot.idx, shot.t0 = buildShots(), 1, os.clock()
	end
	refreshStatus()
end

local function leave()
	if not active then return end
	active = false
	Run:UnbindFromRenderStep("CameraDirector")
	for _, e in fx do e:Destroy() end
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
		local u = (os.clock() - shot.t0) / s[5]
		if u >= 1 then
			shot.idx, shot.t0 = shot.idx % #shot.list + 1, os.clock()
			s, u = shot.list[shot.idx], 0
		end
		local e = smooth(u)
		cam.CFrame = CFrame.lookAt(s[1]:Lerp(s[3], e), s[2]:Lerp(s[4], e)) * CFrame.Angles(0, 0, roll)
		fade.BackgroundTransparency = math.min(1, math.min(u, 1 - u) * s[5] / 0.5) -- dip to black between shots
		cam.FieldOfView = s[6] * fov / 70
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
