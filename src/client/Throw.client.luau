-- The shot, start to finish:
--   1. stance: a copy of the shooter bends over the head of their lane, bridge hand on the felt, their own cue
--      (tier colours + effects) in hand; practice strokes, slow backswing, strike — the cue slides through the bridge
--   2. flight: the camera chases the ball over the long table; luck grows table by table ("LUCK 11.56X", the same
--      track the server rolled); the rack breaks quietly in the background and its balls run into the pockets
--   3. reveal: the camera cuts to the player's base, a light beam hits the podium, the new character bursts in
-- Other players' shots are shown without the camera work.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.Shared.Config)
local MeshBuilder = require(RS.Shared.MeshBuilder)
local CueFx = require(RS.Shared.CueFx)
local Rig = require(RS.Shared.Rig)
local Fx = RS:WaitForChild("Remotes"):WaitForChild("Fx")
local plr = Players.LocalPlayer
local cam = workspace.CurrentCamera
local T, N = C.Table, #C.Rarities
local zoneLen = T.Length / N
local FELT_Y = 3.3
local R = 1.1 -- main ball radius
local RR = 0.75 -- rack ball radius
local BALL_Z = T.StartZ + 13 -- where the ball is struck: room behind it for the shooter and the cue
local RACK_Z = T.StartZ + 30
local GOLD = Color3.fromRGB(255, 200, 50)
local rng = Random.new()
local WHITE = Color3.new(1, 1, 1)

plr.CameraMaxZoomDistance = 40 -- players can't zoom out far enough to see past the scenery

local function sfx(k) if _G.PlaySfx then _G.PlaySfx(k) end end
local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function laneX(slot) return -T.Width / 2 + (slot - 0.5) * T.Width / T.Lanes end
local function zoneAt(z) return math.clamp(math.floor((z - T.StartZ) / zoneLen) + 1, 1, N) end

-- Billiard ball: Blender mesh (coloured body + white number spots), plain sphere as a fallback
local function ball(color, size, cf)
	local b = MeshBuilder.Create("Ball", cf or CFrame.new(), { Body = color }, size)
	if not b then
		b = Instance.new("Part")
		b.Shape, b.Size, b.Color, b.Material = Enum.PartType.Ball, Vector3.one * size, color, Enum.Material.SmoothPlastic
		b.Anchored, b.CanCollide = true, false
		if cf then b.CFrame = cf end
	end
	b:SetAttribute("Tint", color)
	b.CastShadow = true
	b.Parent = workspace
	return b
end

local function anchorPart(cf)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.Transparency, p.Size, p.CFrame = true, false, false, 1, Vector3.one * 0.2, cf
	p.Parent = workspace
	return p
end

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.LightEmission, e.Rate = 1, 0
	for k, v in props do e[k] = v end
	e.Parent = parent
	return e
end

local function burst(at, color, n, speed)
	local p = typeof(at) == "Instance" and at or anchorPart(CFrame.new(at))
	local e = emitter(p, {
		Color = ColorSequence.new(color, WHITE), Speed = NumberRange.new((speed or 14) * 0.5, speed or 14),
		Lifetime = NumberRange.new(0.4, 0.9), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.7, 0),
		Drag = 3,
	})
	e:Emit(n)
	if p ~= at then task.delay(2, p.Destroy, p) end
end

-- flat expanding ring on the ground / table
local function shockwave(pos, color, size, t)
	local ring = Instance.new("Part")
	ring.Shape, ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CastShadow = Enum.PartType.Cylinder, true, false, false, false
	ring.Material, ring.Color, ring.Transparency = Enum.Material.ForceField, color, 0
	ring.Size = Vector3.new(0.3, 1, 1)
	ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = workspace
	tween(ring, t or 0.6, { Size = Vector3.new(0.3, size, size), Transparency = 1 }, Enum.EasingStyle.Quart)
	task.delay((t or 0.6) + 0.1, ring.Destroy, ring)
end

local function drop(b, at, quiet)
	if not quiet then sfx("Pocket") end
	burst(b, b:GetAttribute("Tint") or WHITE, quiet and 8 or 25)
	tween(b, 0.45, { Size = Vector3.one * 0.1, CFrame = CFrame.new(at - Vector3.new(0, 1.6, 0)) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.delay(1, b.Destroy, b)
end

-- ===== Long-table pockets (same positions as the Blender table segment) =====
local pockets = {}
for i = 1, N do
	for _, sx in { -1, 1 } do
		table.insert(pockets, Vector3.new(sx * T.Width / 2, FELT_Y + RR, T.StartZ + (i - 0.5) * zoneLen))
	end
end
local function nearestPocket(pos)
	local best, bd
	for _, p in pockets do
		local d = (p - pos).Magnitude
		if not bd or d < bd then best, bd = p, d end
	end
	return best, bd
end

-- ===== A full 15-ball rack on every lane: solids, stripes, the black 8 in the middle =====
local SOLIDS = { Color3.fromRGB(250, 200, 30), Color3.fromRGB(30, 80, 200), Color3.fromRGB(220, 40, 40), Color3.fromRGB(110, 40, 170), Color3.fromRGB(255, 120, 20), Color3.fromRGB(20, 140, 70), Color3.fromRGB(130, 30, 30), Color3.fromRGB(18, 18, 20) }
local ORDER = { 1, 9, 2, 10, 8, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15 }
local racks = {}

local function buildRack(slot)
	local list = {}
	local x0 = laneX(slot)
	local k = 0
	for row = 0, 4 do
		for j = 0, row do
			k += 1
			local n = ORDER[k]
			local b = ball(SOLIDS[(n - 1) % 8 + 1], RR * 2, CFrame.new(x0 + (j - row / 2) * RR * 2.04, FELT_Y + RR, RACK_Z + row * RR * 1.77) * CFrame.Angles(k, k * 2, 0))
			b.Size = Vector3.one * 0.1
			tween(b, 0.4, { Size = Vector3.one * RR * 2 }, Enum.EasingStyle.Back)
			table.insert(list, b)
		end
	end
	racks[slot] = list
end
for s = 1, T.Lanes do task.spawn(buildRack, s) end

-- Scatter physics: friction, rail and ball-ball bounces, pockets "pull" slow balls so every ball gets potted.
-- Runs in the background: no camera work, no sound except the soft clack of the break.
local function breakRack(slot, power)
	local list = racks[slot]
	racks[slot] = nil
	local bodies = {}
	for _, b in list do
		local p = b.Position
		local away = Vector3.new(p.X - laneX(slot), 0, p.Z - RACK_Z + 3).Unit
		local dir = (away + Vector3.new(rng:NextNumber(-0.5, 0.5), 0, 0.4)).Unit
		table.insert(bodies, { b = b, p = p, v = dir * rng:NextNumber(26, 46) * (0.6 + power * 0.6), rot = b.CFrame.Rotation })
	end
	local alive = #bodies
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		for i, o in bodies do
			if o.done then continue end
			local speed = o.v.Magnitude
			local target, d = nearestPocket(o.p)
			if d < 2.3 then
				o.done, alive = true, alive - 1
				o.b.CFrame = CFrame.new(target)
				drop(o.b, target, true)
				continue
			end
			o.v *= math.max(0, 1 - 0.55 * dt)
			if speed < 14 then
				o.v += (target - o.p).Unit * 40 * dt
				o.v = o.v.Unit * math.max(o.v.Magnitude, 8)
			end
			o.p += o.v * dt
			local lim = T.Width / 2 - RR
			if math.abs(o.p.X) > lim then -- rail bounce
				o.p = Vector3.new(math.sign(o.p.X) * lim, o.p.Y, o.p.Z)
				o.v = Vector3.new(-o.v.X * 0.8, 0, o.v.Z)
			end
			if o.p.Z < T.StartZ + RR then
				o.p = Vector3.new(o.p.X, o.p.Y, T.StartZ + RR)
				o.v = Vector3.new(o.v.X, 0, -o.v.Z * 0.8)
			end
			for j = i + 1, #bodies do -- elastic ball-ball collision
				local q = bodies[j]
				if not q.done then
					local delta = q.p - o.p
					local dist = delta.Magnitude
					if dist < RR * 2 and dist > 0 then
						local n = delta / dist
						local rel = (o.v - q.v):Dot(n)
						if rel > 0 then
							o.v -= n * rel
							q.v += n * rel
						end
						o.p -= n * (RR * 2 - dist) / 2
						q.p += n * (RR * 2 - dist) / 2
					end
				end
			end
			local axis = o.v.Magnitude > 0.01 and Vector3.yAxis:Cross(o.v.Unit) or Vector3.xAxis
			o.rot = CFrame.fromAxisAngle(axis, o.v.Magnitude * dt / RR) * o.rot
			o.b.CFrame = CFrame.new(o.p) * o.rot
		end
		if alive == 0 then
			conn:Disconnect()
			task.delay(1.5, buildRack, slot)
		end
	end)
end

-- ===== Screen effects =====
local fxGui = Instance.new("ScreenGui")
fxGui.Name, fxGui.IgnoreGuiInset, fxGui.ResetOnSpawn, fxGui.DisplayOrder = "CinemaFx", true, false, 10
fxGui.Parent = plr:WaitForChild("PlayerGui")

local function frame(props)
	local f = Instance.new("Frame")
	f.BorderSizePixel, f.Size = 0, UDim2.fromScale(1, 1)
	for k, v in props do
		if k ~= "Parent" then f[k] = v end
	end
	f.Parent = props.Parent or fxGui
	return f
end
local function label(parent, text, size, color, pos)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency, l.TextScaled, l.FontFace = 1, true, C.UI.Font
	l.Size, l.AnchorPoint, l.Position = size, Vector2.new(0.5, 0.5), pos
	l.Text, l.TextColor3, l.Parent = text, color, parent
	local st = Instance.new("UIStroke")
	st.Thickness, st.Color, st.Parent = 5, C.UI.Ink, l
	local sc = Instance.new("UIScale")
	sc.Scale, sc.Parent = 1, l
	return l, sc
end
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)), ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 230, 40)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 255, 120)), ColorSequenceKeypoint.new(0.75, Color3.fromRGB(60, 160, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 220)),
})

local flash = frame({ BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 5 })
local dim = frame({ BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1 })
local bars = {}
for i, y in { 0, 1 } do
	bars[i] = frame({ BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(0, y), Position = UDim2.fromScale(0, y), ZIndex = 4 })
end
local luckLabel, luckScale = label(fxGui, "", UDim2.fromScale(0.42, 0.075), C.UI.Title, UDim2.fromScale(0.5, 0.06))
luckLabel.Visible, luckLabel.ZIndex = false, 6
local luckGrad = Instance.new("UIGradient")
luckGrad.Color, luckGrad.Enabled, luckGrad.Parent = RAINBOW, false, luckLabel
local banner, bannerScale = label(fxGui, "", UDim2.fromScale(0.6, 0.07), WHITE, UDim2.fromScale(0.5, 0.2))
banner.Visible, banner.ZIndex = false, 6

local cc = Instance.new("ColorCorrectionEffect")
cc.Parent = Lighting
local blur = Instance.new("BlurEffect")
blur.Size, blur.Parent = 0, Lighting

local function doFlash(color, strength, t)
	flash.BackgroundColor3, flash.BackgroundTransparency = color, 1 - (strength or 0.8)
	tween(flash, t or 0.5, { BackgroundTransparency = 1 })
end
local function letterbox(on)
	for _, b in bars do tween(b, 0.4, { Size = UDim2.fromScale(1, on and 0.1 or 0) }) end
end
local function pop(sc, from)
	sc.Scale = from or 1.8
	tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end
local function showBanner(text, color)
	banner.Text, banner.TextColor3, banner.Visible = text, color, true
	banner.TextTransparency, banner.UIStroke.Transparency = 0, 0
	pop(bannerScale, 0.3)
	task.delay(1.2, function()
		if banner.Text == text then
			tween(banner, 0.4, { TextTransparency = 1 })
			tween(banner.UIStroke, 0.4, { Transparency = 1 })
		end
	end)
end

-- Skip button (bottom-right, only during your own cinematic)
local skip = false
local skipBtn = Instance.new("TextButton")
skipBtn.Size, skipBtn.AnchorPoint, skipBtn.Position = UDim2.fromOffset(170, 60), Vector2.new(1, 1), UDim2.new(1, -30, 1, -30)
skipBtn.BackgroundColor3, skipBtn.Text, skipBtn.FontFace, skipBtn.TextSize = WHITE, "SKIP", C.UI.Font, 30
skipBtn.TextColor3, skipBtn.Visible, skipBtn.ZIndex, skipBtn.AutoButtonColor = C.UI.Ink, false, 8, true
Instance.new("UICorner", skipBtn).CornerRadius = UDim.new(0, 24)
local skipStroke = Instance.new("UIStroke")
skipStroke.Thickness, skipStroke.Color, skipStroke.ApplyStrokeMode, skipStroke.Parent = 4, C.UI.Ink, Enum.ApplyStrokeMode.Border, skipBtn
skipBtn.Parent = fxGui
skipBtn.Activated:Connect(function() skip = true end)
local function waitOrSkip(sec)
	local t0 = os.clock()
	while os.clock() - t0 < sec and not skip do RunService.RenderStepped:Wait() end
end

-- ===== Camera =====
local shake = 0
local function hardShake(a) shake = math.max(shake, a * (_G.ShakeScale or 1)) end -- Settings: camera shake on/off
local camFn -- function(dt) -> CFrame, or nil when the default camera is in control
local cinema = false
RunService:BindToRenderStep("CinemaCam", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if not cinema or not camFn then return end
	local goal, snap = camFn(dt)
	cam.CFrame = snap and goal or cam.CFrame:Lerp(goal, math.min(1, dt * 9))
	if shake > 0.01 then
		cam.CFrame *= CFrame.new(rng:NextNumber(-1, 1) * shake, rng:NextNumber(-1, 1) * shake, 0) * CFrame.Angles(0, 0, rng:NextNumber(-1, 1) * shake * 0.04)
		shake *= math.max(0, 1 - dt * 5)
	end
end)

local function setCinema(on)
	cinema = on
	_G.ThrowBusy = on
	if _G.SetHudVisible then _G.SetHudVisible(not on) end
	letterbox(on)
	luckLabel.Visible = on
	skipBtn.Visible = on
	if on then
		skip = false
		cam.CameraType = Enum.CameraType.Scriptable
	else
		camFn = nil
		cam.CameraType = Enum.CameraType.Custom
		tween(cam, 0.6, { FieldOfView = 70 })
		tween(dim, 0.4, { BackgroundTransparency = 1 })
		tween(blur, 0.4, { Size = 0 })
		tween(cc, 0.6, { TintColor = WHITE, Saturation = 0, Brightness = 0, Contrast = 0 })
	end
end

-- prize ball mesh of an item (variant colours + material), plain sphere as a fallback
local function prizeBall(it, size, cf)
	local V = C.Variants[it.v or 1]
	local p = MeshBuilder.Create("PrizeBall", cf or CFrame.new(), C.BallOverrides(it), size)
	if not p then
		p = Instance.new("Part")
		p.Shape, p.Size, p.Color = Enum.PartType.Ball, Vector3.one * size, C.BallOverrides(it).Body
		p.Anchored, p.CanCollide, p.CanQuery = true, false, false
		if cf then p.CFrame = cf end
	end
	if V.material then p.Material = Enum.Material[V.material] end
	if V.name == "Gold" or V.name == "Diamond" then p.Reflectance = 0.3 end
	return p
end

-- ===== Reveal card: spinning rays, the ball turning in 3D, flowing rainbow title, pulse =====
local function revealCard(it, bonus)
	local ch = C.Balls[it.id]
	local V = C.Variants[it.v or 1]
	local r = C.Rarities[ch.rarity]
	local root = frame({ BackgroundTransparency = 1, ZIndex = 3 })
	local rays = frame({ Parent = root, BackgroundTransparency = 1, Size = UDim2.fromOffset(1000, 1000), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42) })
	for k = 1, 16 do
		local pivot = frame({ Parent = rays, BackgroundTransparency = 1, Rotation = k * 22.5 })
		frame({ Parent = pivot, BackgroundColor3 = k % 2 == 0 and r[2] or WHITE, BackgroundTransparency = 0.7, Size = UDim2.new(0, 44, 0.5, 0), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5) })
	end
	local vpHolder = frame({ Parent = root, BackgroundTransparency = 1, Size = UDim2.fromOffset(340, 340), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36) })
	local vp = Instance.new("ViewportFrame")
	vp.Size, vp.BackgroundTransparency, vp.Ambient, vp.LightDirection = UDim2.fromScale(1, 1), 1, Color3.fromRGB(200, 195, 220), Vector3.new(-1, -1, -1)
	vp.Parent = vpHolder
	local vpScale = Instance.new("UIScale")
	vpScale.Scale, vpScale.Parent = 0, vpHolder
	local shown = prizeBall(it, 4)
	shown.Parent = vp
	local vcam = Instance.new("Camera")
	vcam.FieldOfView, vcam.CFrame, vcam.Parent = 30, CFrame.lookAt(Vector3.new(0, 1.5, 8.5), Vector3.zero), vp
	vp.CurrentCamera = vcam
	tween(vpScale, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)
	local title, s1 = label(root, string.upper(r[1]) .. "!", UDim2.fromScale(0.8, 0.13), WHITE, UDim2.fromScale(0.5, 0.66))
	local name, s2 = label(root, C.ItemName(it), UDim2.fromScale(0.7, 0.08), V.color or r[2], UDim2.fromScale(0.5, 0.77))
	local _, s3 = label(root, "$" .. C.Short(C.ItemIncome(it)) .. "/s", UDim2.fromScale(0.4, 0.055), C.UI.Money, UDim2.fromScale(0.5, 0.84))
	local tagText = V.name ~= "Normal" and (string.upper(V.name) .. "  x" .. V.mult) or bonus > 0 and ("LUCK BONUS +" .. bonus) or "NEW"
	local newTag, s4 = label(root, tagText, UDim2.fromScale(0.3, 0.05), V.color or C.UI.Title, UDim2.fromScale(0.5, 0.58))
	newTag.Rotation = -4
	local grad = Instance.new("UIGradient")
	grad.Color = ch.rarity >= 10 and RAINBOW or ColorSequence.new(WHITE, r[2])
	grad.Parent = title
	for k, sc in { s4, s1, s2, s3 } do
		sc.Scale = 0
		task.delay((k - 1) * 0.12, function() tween(sc, 0.5, { Scale = 1 }, Enum.EasingStyle.Back) end)
	end
	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		rays.Rotation = t * 35
		shown.CFrame = CFrame.Angles(0.35, t * 1.6, 0) * CFrame.new(0, math.sin(t * 3) * 0.15, 0)
		grad.Offset = Vector2.new(math.sin(t * 2.5) * 0.6, 0)
		grad.Rotation = t * 60
		if t > 0.6 then s1.Scale = 1 + math.sin(t * 7) * 0.05 end
		if ch.rarity >= 10 then
			name.TextColor3 = Color3.fromHSV((t * 0.5) % 1, 0.65, 1)
			cc.TintColor = Color3.fromHSV((t * 0.4) % 1, 0.22, 1) -- the world itself cycles through colours
		end
	end)
	return function()
		for _, sc in { s1, s2, s3, s4, vpScale } do tween(sc, 0.3, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In) end
		tween(rays, 0.3, { Size = UDim2.fromOffset(0, 0) })
		task.wait(0.35)
		conn:Disconnect()
		root:Destroy()
	end
end

-- ===== 1. The shooter: a posed copy of the player's avatar with their cue =====
local SHOOT_SCALE = 1.35 -- the long table is built big; the shooter is scaled to match
local CUE_K = 0.85 * SHOOT_SCALE -- cue length 9.2 * CUE_K
local PITCH = math.rad(7) -- the butt is raised a little, like a real stroke
local DIR = Vector3.new(0, -math.sin(PITCH), math.cos(PITCH)) -- butt -> tip

local function makeCue(def, tier)
	local overrides = {}
	for slot, field in C.CueParts do overrides[slot] = def[field] end
	local cue = MeshBuilder.Create("Cue", CFrame.new(), overrides, CUE_K)
	if not cue then
		cue = Instance.new("Part")
		cue.Size, cue.Color, cue.Material = Vector3.new(0.3, 9.2, 0.3) * CUE_K, def.shaft, Enum.Material.Wood
		cue.Anchored, cue.CanCollide, cue.CanQuery = true, false, false
	end
	CueFx.Apply(cue, tier, def, CUE_K)
	cue.Parent = workspace
	return cue
end

local function cueCF(grip, back) -- the grip sits 30 % up from the butt
	local Lc = 9.2 * CUE_K
	local g = grip - DIR * back
	return CFrame.fromMatrix(g + DIR * (Lc * 0.2), Vector3.xAxis, DIR), g
end

-- copy of the shooter's character, posed by IK each frame; nil when the avatar isn't available
local function makeShooter(uid)
	local who = Players:GetPlayerByUserId(uid)
	local char = who and who.Character
	if not (char and char:FindFirstChild("HumanoidRootPart")) then return nil end
	char.Archivable = true
	local ok, m = pcall(char.Clone, char)
	if not (ok and m) then return nil end
	for _, d in m:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("ForceField") or d:IsA("Sound") or (d:IsA("BasePart") and d.Name == "Cue") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide, d.CanQuery, d.CanTouch, d.Anchored = false, false, false, false
		end
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if not hum then return nil end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.EvaluateStateMachine = false
	m.HumanoidRootPart.Anchored = true
	pcall(m.ScaleTo, m, SHOOT_SCALE)
	local J = Rig.Joints(m)
	if not J then
		m:Destroy()
		return nil
	end
	m.Name = "Shooter"
	m.Parent = workspace
	return { m = m, J = J, hum = hum }
end

-- Find a natural stance: feet on the felt, right shoulder over the grip, torso bent just enough for the
-- bridge hand to reach the felt in front. Returns the pose function (back -> Transforms) or nil.
local function stance(sh, ballPos)
	local m, J = sh.m, sh.J
	local hrpPart = m.HumanoidRootPart
	local addr = ballPos - DIR * (R + 0.35) -- cue tip at address
	local Lc = 9.2 * CUE_K
	local grip0 = addr - DIR * (Lc * 0.7)
	local bridge = addr - DIR * (2.1 * CUE_K) - Vector3.new(0, 0.18 * SHOOT_SCALE, 0)
	local foot = m:FindFirstChild("RightFoot")
	local footY = FELT_Y + (foot and foot.Size.Y / 2 or 0.2)
	local rightFoot = Vector3.new(ballPos.X - 0.5 * SHOOT_SCALE, footY, grip0.Z - 1.1 * SHOOT_SCALE)
	local leftFoot = Vector3.new(ballPos.X + 1.9 * SHOOT_SCALE, footY, grip0.Z + 1.5 * SHOOT_SCALE)
	local legReach = Rig.Reach(J.RightHip, J.RightKnee, J.RightAnkle)
	local armReach = Rig.Reach(J.LeftShoulder, J.LeftElbow, J.LeftWrist)
	local face = Vector3.new(-0.32, 0, 1).Unit -- turned a little to the right: left shoulder forward
	local stand = sh.hum.HipHeight + hrpPart.Size.Y / 2
	local best
	for bend = 0.7, 1.5, 0.05 do
		local root, waist = CFrame.Angles(-bend * 0.35, 0, 0), CFrame.Angles(-bend * 0.65, 0, 0)
		local pos = Vector3.new(ballPos.X + 1, FELT_Y + stand, grip0.Z)
		local hrp
		for _ = 1, 4 do
			hrp = CFrame.lookAt(pos, pos + face)
			local lt, ut = Rig.Torso(J, hrp, root, waist)
			local sR = Rig.JointPos(ut, J.RightShoulder)
			pos += Vector3.new(ballPos.X + 0.15 - sR.X, 0, grip0.Z + 0.5 * SHOOT_SCALE - sR.Z)
			local hipL, hipR = Rig.JointPos(lt, J.LeftHip), Rig.JointPos(lt, J.RightHip)
			local far = math.max((hipL - leftFoot).Magnitude, (hipR - rightFoot).Magnitude)
			pos -= Vector3.new(0, far - legReach * 0.96, 0) -- feet planted, knees slightly bent
		end
		hrp = CFrame.lookAt(pos, pos + face)
		local _, ut = Rig.Torso(J, hrp, root, waist)
		best = { hrp = hrp, root = root, waist = waist, neck = CFrame.Angles(bend * 0.75, 0, 0) }
		if (Rig.JointPos(ut, J.LeftShoulder) - bridge).Magnitude <= armReach * 0.97 then break end
	end
	hrpPart.CFrame = best.hrp
	return function(back)
		local _, g = cueCF(grip0, back)
		return Rig.Solve(J, best.hrp, {
			root = best.root, waist = best.waist, neck = best.neck,
			rightHand = g, leftHand = bridge, rightFoot = rightFoot, leftFoot = leftFoot,
			rightPole = Vector3.new(-0.4, 0.2, -1).Unit, leftPole = Vector3.new(1, 0.6, 0).Unit,
		})
	end, grip0
end

-- The stroke: practice strokes, slow backswing, pause, strike through the ball. Returns once the tip hits.
local function windup(b, start, mine, power, payload, full)
	local def = CueFx.Def(payload.cue or 1, payload.dragon)
	local cue = makeCue(def, payload.cue or 1)
	local sh = makeShooter(payload.uid)
	local pose, grip0
	if sh then pose, grip0 = stance(sh, start) end
	if not pose then
		grip0 = start - DIR * (R + 0.35 + 9.2 * CUE_K * 0.7)
	end
	local poseConn
	local back = 0
	if pose then
		poseConn = RunService.Stepped:Connect(function() Rig.Apply(sh.J, pose(back)) end)
	end
	local W = C.AnimOf(full).Windup
	local maxBack = (1.1 + 0.9 * power) * SHOOT_SCALE
	local side = start.X < 0 and 1 or -1 -- camera on the table-centre side of the lane
	local t0 = os.clock()
	if mine then
		local mid = start - DIR * 5
		camFn = function()
			local t = math.clamp((os.clock() - t0) / W, 0, 1)
			local e = t * t * (3 - 2 * t)
			local wide = mid + Vector3.new(side * 12, 5.5, 1)
			local behind = grip0 - DIR * 5 + Vector3.new(side * 1.2, 3.4, 0)
			return CFrame.lookAt(wide:Lerp(behind, e), (mid + Vector3.new(0, 1, 0)):Lerp(start + Vector3.new(0, 0.6, 6), e))
		end
		cam.FieldOfView = 55
		tween(cam, W, { FieldOfView = 45 }, Enum.EasingStyle.Sine)
		tween(dim, W, { BackgroundTransparency = 0.7 })
		tween(cc, W, { Saturation = -0.15, Contrast = 0.15 })
	end
	local practice = full and 0.45 or 0.1 -- share of the wind-up spent on practice strokes
	while true do
		local u = (os.clock() - t0) / W
		if u >= 1 or skip then break end
		if u < practice then -- two small practice strokes
			back = 0.45 * SHOOT_SCALE * (1 - math.cos(u / practice * 4 * math.pi)) / 2
		elseif u < 0.86 then -- slow final backswing
			local e = (u - practice) / (0.86 - practice)
			back = maxBack * math.sin(e * math.pi / 2)
			if mine then hardShake(0.03 * e) end
		elseif u < 0.92 then -- pause at the top
			back = maxBack
		else -- strike through the ball
			local e = (u - 0.92) / 0.08
			back = maxBack + (-(R + 0.35) * 0.9 - maxBack) * e ^ 2
		end
		cue.CFrame = cueCF(grip0, back)
		RunService.RenderStepped:Wait()
	end
	back = -(R + 0.35) * 0.9 -- follow-through: the tip ends just past where the ball was
	cue.CFrame = cueCF(grip0, back)
	-- impact
	sfx("Hit")
	burst(start - DIR * R, Color3.fromRGB(120, 180, 255), 14, 6) -- chalk puff
	burst(start, def.inlay:Lerp(WHITE, 0.4), 30, 18)
	shockwave(start - Vector3.new(0, R - 0.1, 0), WHITE, 16, 0.45)
	if mine then
		doFlash(WHITE, 0.7, 0.3)
		hardShake(2.2)
		tween(dim, 0.3, { BackgroundTransparency = 1 })
		tween(cc, 0.3, { Saturation = 0.2, Contrast = 0.08 })
		cam.FieldOfView = 90
		tween(cam, 0.8, { FieldOfView = 78 }, Enum.EasingStyle.Quart)
	end
	task.delay(1.4, function() -- the shooter straightens up and fades away
		if poseConn then poseConn:Disconnect() end
		for _, d in (sh and sh.m or cue):GetDescendants() do
			if d:IsA("BasePart") then tween(d, 0.4, { Transparency = 1 }) end
		end
		tween(cue, 0.4, { Transparency = 1 })
		task.wait(0.45)
		cue:Destroy()
		if sh then sh.m:Destroy() end
	end)
end

-- ===== 3. The new ball lands on your base table =====
local function findBall(slot, tid)
	local base = workspace.World:FindFirstChild("Base" .. slot)
	local chars = base and base:FindFirstChild("Chars")
	if not chars or tid == 0 then return nil end
	local t0 = os.clock()
	repeat
		for _, m in chars:GetChildren() do
			if m:GetAttribute("ThrowId") == tid and m.PrimaryPart then return m end
		end
		task.wait(0.05)
	until os.clock() - t0 > 5
	return nil
end

local function setHidden(model, hidden)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "MeshVisual" or not d:FindFirstChild("MeshVisual")) then d.LocalTransparencyModifier = hidden and 1 or 0 end
		if d:IsA("BillboardGui") then d.Enabled = not hidden end
	end
end

-- Camera on the base table; a light beam hits the ball's spot, the ball drops in, bounces, bursts, the card follows.
local function revealOnBase(slot, tid, it, bonus, quick)
	local ch = C.Balls[it.id]
	local r = C.Rarities[ch.rarity]
	local real = findBall(slot, tid)
	if not real then -- not placed on the base (all spots taken): just the card
		tween(dim, 0.3, { BackgroundTransparency = 0.35 })
		local close = revealCard(it, bonus)
		waitOrSkip(3)
		close()
		return
	end
	local goal = real.PrimaryPart.CFrame.Position
	local size = real.PrimaryPart.Size.X
	local hideReal = RunService.RenderStepped:Connect(function() setHidden(real, true) end)
	local front = Vector3.new(0, 0, 1)
	local camStart = os.clock()
	camFn = function()
		local t = math.min((os.clock() - camStart) / 2.4, 1)
		local e = 1 - (1 - t) ^ 3
		return CFrame.lookAt(goal + front * (12 - 5 * e) + Vector3.new(4 - 3 * e, 6 - 2.5 * e, 0), goal + Vector3.new(0, 0.6, 0)), t < 0.02
	end
	cam.FieldOfView = 50
	tween(dim, 0.4, { BackgroundTransparency = 0.6 })
	tween(cc, 0.4, { Brightness = -0.05, Saturation = -0.1, TintColor = WHITE })
	-- light beam from the sky onto the spot
	local beam = Instance.new("Part")
	beam.Shape, beam.Anchored, beam.CanCollide, beam.CanQuery, beam.CastShadow = Enum.PartType.Cylinder, true, false, false, false
	beam.Material, beam.Color, beam.Transparency = Enum.Material.SmoothPlastic, r[2]:Lerp(WHITE, 0.6), 0.55
	beam.Size = Vector3.new(60, 0.2, 0.2)
	beam.CFrame = CFrame.new(goal + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	beam.Parent = workspace
	tween(beam, 0.35, { Size = Vector3.new(60, size * 1.8, size * 1.8) }, Enum.EasingStyle.Back)
	local beamLight = Instance.new("PointLight")
	beamLight.Color, beamLight.Range, beamLight.Brightness, beamLight.Parent = r[2], 16, 4, beam
	sfx("Hit")
	waitOrSkip(quick and 0.2 or 0.5)
	-- the ball falls in spinning, with a trail, and bounces on the felt
	local b = prizeBall(it, size, CFrame.new(goal + Vector3.new(0, 22, 0)))
	b.Parent = workspace
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position, a0.Parent, a1.Parent = Vector3.new(size * 0.4, 0, 0), Vector3.new(-size * 0.4, 0, 0), b, b
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1, trail.Color, trail.LightEmission = a0, a1, ColorSequence.new(WHITE, r[2]), 1
	trail.Lifetime, trail.Transparency, trail.Parent = 0.35, NumberSequence.new(0.2, 1), b
	local t0, fall = os.clock(), quick and 0.7 or 0.9
	repeat
		local t = skip and 1 or math.min((os.clock() - t0) / fall, 1)
		local y = 22 * (1 - TweenService:GetValue(t, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out))
		b.CFrame = CFrame.new(goal + Vector3.new(0, y, 0)) * CFrame.Angles(t * 9, t * 5, 0)
		if t > 0.36 and not b:GetAttribute("Landed") then -- first touch of the felt
			b:SetAttribute("Landed", true)
			sfx("Reward")
			hardShake(1.2 + ch.rarity * 0.05)
			doFlash(r[2]:Lerp(WHITE, 0.3), 0.9, 0.6)
			shockwave(goal - Vector3.new(0, size / 2, 0), r[2], 18, 0.7)
			shockwave(goal - Vector3.new(0, size / 2 - 0.1, 0), WHITE, 10, 0.45)
			burst(goal, r[2], 80, 22)
			local core = anchorPart(CFrame.new(goal))
			emitter(core, {
				Speed = NumberRange.new(16, 26), SpreadAngle = Vector2.new(50, 50), Lifetime = NumberRange.new(1.6, 2.4),
				Acceleration = Vector3.new(0, -25, 0), Drag = 1.2, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-300, 300),
				Size = NumberSequence.new(0.25), LightEmission = 0.2, EmissionDirection = Enum.NormalId.Top,
				Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)), ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 60)), ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 200, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 255, 120)) }),
			}):Emit(110)
			task.delay(3, core.Destroy, core)
			tween(beam, 0.6, { Size = Vector3.new(60, 0.1, 0.1), Transparency = 1 })
			tween(dim, 0.3, { BackgroundTransparency = 0.85 })
			tween(cc, 0.3, { Brightness = 0.05, Saturation = 0.3, TintColor = r[2]:Lerp(WHITE, 0.75) })
		end
		RunService.RenderStepped:Wait()
	until t >= 1
	-- the real ball takes over; the card shows what you got
	b:Destroy()
	beam:Destroy()
	hideReal:Disconnect()
	setHidden(real, false)
	tween(cam, 2.6, { FieldOfView = 40 }, Enum.EasingStyle.Sine)
	local close = revealCard(it, bonus)
	waitOrSkip(quick and 1.8 or 3)
	close()
end

-- ===== The shot =====
local luckShown = 0
local function showLuck(v, lucky)
	local from = luckShown
	luckShown = v
	local t0 = os.clock()
	task.spawn(function() -- the number counts up
		while os.clock() - t0 < 0.3 and luckShown == v do
			local e = (os.clock() - t0) / 0.3
			luckLabel.Text = string.format("LUCK %.2fX", from + (v - from) * e)
			RunService.RenderStepped:Wait()
		end
		if luckShown == v then luckLabel.Text = string.format("LUCK %.2fX", v) end
	end)
	luckGrad.Enabled = v >= 5
	luckLabel.TextColor3 = v >= 5 and WHITE or C.UI.Title
	pop(luckScale, lucky and 1.8 or 1.25)
end

Fx.OnClientEvent:Connect(function(kind, p)
	if kind ~= "Throw" then return end
	local slot, dist, tid = p.slot, p.dist, p.tid
	local it = { id = p.id, v = p.v }
	local ch = C.Balls[it.id]
	local rcol = C.Rarities[ch.rarity][2]
	local mine = slot == _G.MySlot
	local full = p.full and not _G.ShortOnly -- the big show only for top pulls, unless the player chose short cinematics
	local A = C.AnimOf(full)
	if mine then _G.ShotReadyAt = os.clock() + C.ThrowTime(dist, p.full) + C.ThrowCooldown end
	local x = laneX(slot)
	local start = Vector3.new(x, FELT_Y + R, BALL_Z)
	local b = ball(p.gold and GOLD or WHITE, R * 2, CFrame.new(start))
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position, a0.Parent, a1.Parent = Vector3.new(0, 0.7, 0), Vector3.new(0, -0.7, 0), b, b
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1, trail.LightEmission = a0, a1, 1
	trail.Lifetime, trail.Transparency, trail.Parent = 0.6, NumberSequence.new(0.1, 1), b
	local aura = emitter(b, {
		Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180), Lifetime = NumberRange.new(0.3, 0.6),
		Size = NumberSequence.new(0.9, 0), Transparency = NumberSequence.new(0.2, 1),
	})
	if p.gold then -- Golden Ball pass: gold sparkles
		emitter(b, {
			Color = ColorSequence.new(GOLD, WHITE), Rate = 25, Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180),
			Lifetime = NumberRange.new(0.4, 0.8), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) }),
		})
	end
	local function themeAt(z)
		local tbl = C.Tables[zoneAt(z)]
		trail.Color = ColorSequence.new(p.gold and GOLD or WHITE, tbl[2])
		aura.Color = ColorSequence.new(tbl[2], WHITE)
		return tbl
	end
	themeAt(start.Z)
	local luckyAt = {}
	for _, k in p.lucky do luckyAt[k] = true end

	if mine then
		setCinema(true)
		luckShown = p.luck0
		luckLabel.Text = string.format("LUCK %.2fX", p.luck0)
		showLuck(p.luck0)
	end
	local power = math.clamp(dist / T.Length, 0, 1)
	windup(b, start, mine, math.clamp(dist / 600, 0.3, 1), p, full)
	aura.Rate = 40

	-- 2. Flight over the tables
	local roll = C.RollTime(dist, full)
	local zone = math.clamp(math.ceil(dist / zoneLen), 1, N)
	local endZ = math.clamp(T.StartZ + dist, start.Z + 4, T.StartZ + T.Length - R) -- same zone as the server picked
	local broke, lastZone = false, 1
	local rot, lastZ = CFrame.new(), start.Z
	if mine then
		camFn = function()
			local bp = b.Position
			return CFrame.lookAt(bp + Vector3.new(0, 5.5, -13), bp + Vector3.new(0, 1, 12))
		end
	end
	local t0 = os.clock()
	repeat
		local t = skip and 1 or math.min((os.clock() - t0) / roll, 1)
		local z = start.Z + (endZ - start.Z) * (1 - (1 - t) ^ 3)
		rot = CFrame.Angles((z - lastZ) / R, 0, 0) * rot
		lastZ = z
		b.CFrame = CFrame.new(x, start.Y, z) * rot
		if not broke and z >= RACK_Z - RR * 2 and racks[slot] then
			broke = true
			breakRack(slot, math.max(power, 0.3))
		end
		local zn = zoneAt(z)
		if zn ~= lastZone then -- entering a new table: the luck of the table just crossed is added
			local crossed = zn - 1
			lastZone = zn
			local tbl = themeAt(z)
			aura.Rate = 40 + zn
			if mine and p.track[crossed] then
				showLuck(p.track[crossed], luckyAt[crossed])
				if luckyAt[crossed] then
					showBanner("LUCKY TABLE", C.UI.Title)
					doFlash(C.UI.Title, 0.35, 0.35)
					sfx("Reward")
				end
			end
			if mine and (full or zn == zone) then -- the short version only announces the final table
				hardShake(0.5 + zn * 0.03)
				doFlash(tbl[2], 0.35, 0.35)
				cam.FieldOfView = 90
				tween(cam, 0.5, { FieldOfView = 80 }, Enum.EasingStyle.Quart)
				tween(cc, 0.3, { TintColor = tbl[2]:Lerp(WHITE, 0.75) })
				if not luckyAt[crossed] then showBanner("TABLE " .. zn .. "  " .. string.upper(tbl[1]), tbl[2]) end
				sfx("Click")
			end
		end
		RunService.RenderStepped:Wait()
	until t >= 1
	if mine and p.track[zone] then showLuck(p.track[zone], luckyAt[zone]) end

	-- slide into the zone pocket: zoom in, dim, blur, then fade to black
	local side = x < 0 and -1 or 1
	local pocket = Vector3.new(side * T.Width / 2, start.Y, T.StartZ + (zone - 0.5) * zoneLen)
	if mine then
		camFn = function()
			return CFrame.lookAt(pocket + Vector3.new(-side * 8, 7, -9), pocket)
		end
		tween(cam, A.Slide, { FieldOfView = 34 }, Enum.EasingStyle.Sine)
		tween(dim, A.Slide, { BackgroundTransparency = full and 0.45 or 0.75 })
		tween(blur, A.Slide, { Size = full and 6 or 2 })
	end
	local from = b.Position
	t0 = os.clock()
	repeat
		local t = skip and 1 or math.min((os.clock() - t0) / A.Slide, 1)
		b.CFrame = CFrame.new(from:Lerp(pocket, t * t * (3 - 2 * t))) * rot
		RunService.RenderStepped:Wait()
	until t >= 1
	b:SetAttribute("Tint", rcol)
	drop(b, pocket)
	shockwave(pocket - Vector3.new(0, 0.9, 0), rcol, 12, 0.5)

	if not mine then
		_G.Toast(C.ItemName(it) .. "  " .. C.Rarities[ch.rarity][1], rcol)
		return
	end
	hardShake(1)
	doFlash(rcol, 0.6, 0.3)
	tween(blur, 0.3, { Size = 0 })
	local bonus = math.max(0, ch.rarity - zone)
	if not skip then -- every pull lands on your table; the short version is just quicker
		tween(dim, full and 0.35 or 0.2, { BackgroundTransparency = 0 }).Completed:Wait()
		revealOnBase(slot, tid, it, bonus, not full)
	else -- skipped: just the card, the ball appears on the base by itself
		tween(dim, 0.25, { BackgroundTransparency = 0.55 })
		local close = revealCard(it, bonus)
		skip = false
		waitOrSkip(full and 2.2 or 1.6)
		close()
	end
	setCinema(false)
end)
