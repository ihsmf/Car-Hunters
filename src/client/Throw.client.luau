-- The shot, start to finish:
--   1. wind-up: orbiting camera, a giant Blender cue swoops in, pulls back while energy gathers, impact frame
--   2. flight: the camera chases the ball over the long table; every new table = shake, flash, zoom punch,
--      new tint and a banner; "LUCK xN" stays on top; the ball breaks the rack, rack balls scatter into pockets
--   3. reveal: the camera cuts to the player's base, a light beam hits the podium, the new character bursts in
-- Other players' shots are shown without the camera work.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.Shared.Config)
local MeshBuilder = require(RS.Shared.MeshBuilder)
local Fx = RS:WaitForChild("Remotes"):WaitForChild("Fx")
local plr = Players.LocalPlayer
local cam = workspace.CurrentCamera
local T, N = C.Table, #C.Rarities
local zoneLen = T.Length / N
local FELT_Y = 3.3
local R = 1.1 -- ball radius
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

local function drop(b, at)
	sfx("Pocket")
	burst(b, b:GetAttribute("Tint") or WHITE, 25)
	tween(b, 0.45, { Size = Vector3.one * 0.1, CFrame = CFrame.new(at - Vector3.new(0, 1.6, 0)) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.delay(1, b.Destroy, b)
end

-- ===== Long-table pockets (same positions as the Blender table segment) =====
local pockets = {}
for i = 1, N do
	for _, sx in { -1, 1 } do
		table.insert(pockets, Vector3.new(sx * T.Width / 2, FELT_Y + R, T.StartZ + (i - 0.5) * zoneLen))
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

-- ===== A rack on every lane =====
local RACK_Z = T.StartZ + 24
local rackColors = { Color3.fromRGB(255, 220, 40), Color3.fromRGB(40, 90, 255), Color3.fromRGB(255, 50, 50), Color3.fromRGB(140, 40, 200), Color3.fromRGB(255, 130, 20), Color3.fromRGB(30, 160, 60), Color3.fromRGB(130, 30, 30), Color3.fromRGB(20, 20, 20), Color3.fromRGB(255, 120, 200), Color3.fromRGB(0, 200, 200) }
local racks = {}

local function buildRack(slot)
	local list = {}
	local x0 = laneX(slot)
	local k = 0
	for row = 0, 3 do
		for j = 0, row do
			k += 1
			local b = ball(rackColors[k], R * 2, CFrame.new(x0 + (j - row / 2) * R * 2.05, FELT_Y + R, RACK_Z + row * R * 1.8))
			b.Size = Vector3.one * 0.1
			tween(b, 0.4, { Size = Vector3.one * R * 2 }, Enum.EasingStyle.Back)
			table.insert(list, b)
		end
	end
	racks[slot] = list
end
for s = 1, T.Lanes do task.spawn(buildRack, s) end

-- Scatter physics: friction, rail and ball-ball bounces, pockets "pull" slow balls so every ball gets potted
local function breakRack(slot, power)
	local list = racks[slot]
	racks[slot] = nil
	local bodies = {}
	for _, b in list do
		local p = b.Position
		local away = Vector3.new(p.X - laneX(slot), 0, p.Z - RACK_Z + 3).Unit
		local dir = (away + Vector3.new(rng:NextNumber(-0.5, 0.5), 0, 0.4)).Unit
		table.insert(bodies, { b = b, p = p, v = dir * rng:NextNumber(30, 55) * (0.6 + power * 0.6), rot = CFrame.new() })
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
				drop(o.b, target)
				continue
			end
			o.v *= math.max(0, 1 - 0.55 * dt)
			if speed < 14 then
				o.v += (target - o.p).Unit * 40 * dt
				o.v = o.v.Unit * math.max(o.v.Magnitude, 8)
			end
			o.p += o.v * dt
			local lim = T.Width / 2 - R
			if math.abs(o.p.X) > lim then -- rail bounce
				o.p = Vector3.new(math.sign(o.p.X) * lim, o.p.Y, o.p.Z)
				o.v = Vector3.new(-o.v.X * 0.8, 0, o.v.Z)
				sfx("Hit")
			end
			if o.p.Z < T.StartZ + R then
				o.p = Vector3.new(o.p.X, o.p.Y, T.StartZ + R)
				o.v = Vector3.new(o.v.X, 0, -o.v.Z * 0.8)
			end
			for j = i + 1, #bodies do -- elastic ball-ball collision
				local q = bodies[j]
				if not q.done then
					local delta = q.p - o.p
					local dist = delta.Magnitude
					if dist < R * 2 and dist > 0 then
						local n = delta / dist
						local rel = (o.v - q.v):Dot(n)
						if rel > 0 then
							o.v -= n * rel
							q.v += n * rel
						end
						o.p -= n * (R * 2 - dist) / 2
						q.p += n * (R * 2 - dist) / 2
					end
				end
			end
			local axis = o.v.Magnitude > 0.01 and Vector3.yAxis:Cross(o.v.Unit) or Vector3.xAxis
			o.rot = CFrame.fromAxisAngle(axis, o.v.Magnitude * dt / R) * o.rot
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
skipBtn.BackgroundColor3, skipBtn.Text, skipBtn.FontFace, skipBtn.TextSize = WHITE, "SKIP ⏩", C.UI.Font, 30
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

-- ===== Reveal card: spinning rays, flowing rainbow title, pulse =====
local function revealCard(ch, bonus)
	local r = C.Rarities[ch.rarity]
	local root = frame({ BackgroundTransparency = 1, ZIndex = 3 })
	local rays = frame({ Parent = root, BackgroundTransparency = 1, Size = UDim2.fromOffset(1000, 1000), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42) })
	for k = 1, 16 do
		local pivot = frame({ Parent = rays, BackgroundTransparency = 1, Rotation = k * 22.5 })
		frame({ Parent = pivot, BackgroundColor3 = k % 2 == 0 and r[2] or WHITE, BackgroundTransparency = 0.7, Size = UDim2.new(0, 44, 0.5, 0), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5) })
	end
	local title, s1 = label(root, string.upper(r[1]) .. "!", UDim2.fromScale(0.8, 0.13), WHITE, UDim2.fromScale(0.5, 0.66))
	local name, s2 = label(root, ch.name, UDim2.fromScale(0.7, 0.08), r[2], UDim2.fromScale(0.5, 0.77))
	local _, s3 = label(root, "💵 $" .. C.Short(ch.income) .. "/s", UDim2.fromScale(0.4, 0.055), C.UI.Money, UDim2.fromScale(0.5, 0.84))
	local newTag, s4 = label(root, bonus > 0 and ("🍀 LUCK BONUS +" .. bonus) or "✨ NEW!", UDim2.fromScale(0.3, 0.05), C.UI.Title, UDim2.fromScale(0.5, 0.58))
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
		grad.Offset = Vector2.new(math.sin(t * 2.5) * 0.6, 0)
		grad.Rotation = t * 60
		if t > 0.6 then s1.Scale = 1 + math.sin(t * 7) * 0.05 end
		if ch.rarity >= 10 then
			name.TextColor3 = Color3.fromHSV((t * 0.5) % 1, 0.65, 1)
			cc.TintColor = Color3.fromHSV((t * 0.4) % 1, 0.22, 1) -- the world itself cycles through colours
		end
	end)
	return function()
		for _, sc in { s1, s2, s3, s4 } do tween(sc, 0.3, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In) end
		tween(rays, 0.3, { Size = UDim2.fromOffset(0, 0) })
		task.wait(0.35)
		conn:Disconnect()
		root:Destroy()
	end
end

-- ===== 1. Wind-up =====
local function cueCF(tip, pitch, k)
	local d = Vector3.new(0, -math.sin(pitch), math.cos(pitch)) -- butt -> tip
	return CFrame.fromMatrix(tip - d * 4.6 * k, Vector3.xAxis, d)
end

local function windup(b, start, mine, power, cueColor, full)
	local k = 1.15
	local cue = MeshBuilder.Create("Cue", CFrame.new(start), { Shaft = cueColor }, k)
	if not cue then
		cue = Instance.new("Part")
		cue.Size, cue.Color, cue.Material, cue.Anchored, cue.CanCollide = Vector3.new(0.5, 9.2 * k, 0.5), cueColor, Enum.Material.Wood, true, false
	end
	cue.Parent = workspace
	local tipAnchor = anchorPart(CFrame.new(start))
	local charge = emitter(tipAnchor, {
		Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Speed = NumberRange.new(7, 9), Lifetime = NumberRange.new(0.35, 0.45), Size = NumberSequence.new(0.35, 0.05),
		Color = ColorSequence.new(cueColor:Lerp(WHITE, 0.5), WHITE), Transparency = NumberSequence.new(0.2, 0),
	})
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness, glow.Parent = cueColor:Lerp(WHITE, 0.5), 10, 0, b
	burst(start - Vector3.new(0, 0, R + 0.4), Color3.fromRGB(90, 170, 255), 18, 5) -- chalk puff
	local W = C.AnimOf(full).Windup
	local k_ = W / C.Anim.Full.Windup -- the short version runs the same moves faster
	local t0 = os.clock()
	if mine then
		camFn = function() -- from behind-right and above to straight behind the ball, never into walls/cushion
			local t = math.clamp((os.clock() - t0) / W, 0, 1)
			local e = 1 - (1 - t) ^ 2
			local a = math.rad(35 * (1 - e))
			local rad, h = 12 - 3 * e, 6 - 2 * e
			local pos = start + Vector3.new(math.sin(a) * rad, h, -math.cos(a) * rad)
			pos = Vector3.new(math.clamp(pos.X, -40, 40), pos.Y, math.max(pos.Z, start.Z - 10))
			return CFrame.lookAt(pos, start + Vector3.new(0, 0.5, 8))
		end
		cam.FieldOfView = 62
		tween(cam, W, { FieldOfView = 38 }, Enum.EasingStyle.Sine)
		tween(dim, W, { BackgroundTransparency = 0.55 })
		tween(cc, W, { Saturation = -0.35, Contrast = 0.25 })
	end
	while true do
		local t = (os.clock() - t0) / k_
		if t >= C.Anim.Full.Windup or skip then break end
		local pitch, back
		if t < 0.35 then -- swoop in from above
			local e = TweenService:GetValue(t / 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			pitch, back = 1.25 + (0.14 - 1.25) * e, 0.4
		elseif t < 1.25 then -- slow pull back, energy gathers
			local e = math.sin((t - 0.35) / 0.9 * math.pi / 2)
			pitch, back = 0.14, 0.4 + 4.6 * e * (0.6 + power * 0.4)
			charge.Rate = 40 + 160 * e
			glow.Brightness = 4 * e
			if mine then hardShake(0.04 + 0.12 * e) end
		elseif t < 1.42 then -- hold at full tension
			pitch, back = 0.14, 5 * (0.6 + power * 0.4) + math.sin(t * 90) * 0.06
			if mine then hardShake(0.2) end
		else -- strike
			local e = math.clamp((t - 1.42) / 0.07, 0, 1)
			pitch, back = 0.14, 5 * (0.6 + power * 0.4) * (1 - e ^ 3) - 0.3 * e
			charge.Rate = 0
		end
		local tip = start - Vector3.new(0, 0, R + back) + Vector3.new(0, 0.15, 0)
		cue.CFrame = cueCF(tip, pitch, k)
		tipAnchor.CFrame = CFrame.new(tip)
		RunService.RenderStepped:Wait()
	end
	-- impact frame
	sfx("Hit")
	glow.Brightness = 0
	shockwave(start - Vector3.new(0, R - 0.1, 0), WHITE, 22, 0.5)
	burst(start, Color3.fromRGB(255, 230, 120), 50, 22)
	if mine then
		doFlash(WHITE, 0.95, 0.35)
		hardShake(3)
		local hold = cam.CFrame
		camFn = function() return hold, true end
		task.wait(full and 0.09 or 0.03) -- freeze frame
		cam.FieldOfView = 100
		tween(cam, 0.9, { FieldOfView = 80 }, Enum.EasingStyle.Quart)
		tween(dim, 0.3, { BackgroundTransparency = 1 })
		tween(cc, 0.3, { Saturation = 0.25, Contrast = 0.1 })
	end
	task.delay(0.25, cue.Destroy, cue)
	task.delay(0.6, tipAnchor.Destroy, tipAnchor)
	task.delay(0.6, glow.Destroy, glow)
end

-- ===== 3. Reveal on the base =====
local function findNpc(slot, tid)
	local base = workspace.World:FindFirstChild("Base" .. slot)
	local chars = base and base:FindFirstChild("Chars")
	if not chars or tid == 0 then return nil end
	local t0 = os.clock()
	repeat
		for _, npc in chars:GetChildren() do
			if npc:GetAttribute("ThrowId") == tid and npc:FindFirstChild("HumanoidRootPart") then return npc end
		end
		task.wait(0.05)
	until os.clock() - t0 > 5
	return nil
end

local function setHidden(model, hidden)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "Acc" and p.Name ~= "Stick" then p.LocalTransparencyModifier = hidden and 1 or 0 end
	end
end

local ANIM_CHEER, ANIM_IDLE = "rbxassetid://507770677", "rbxassetid://507766666"

local function playAnim(model, id, looped)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = hum
	local a = Instance.new("Animation")
	a.AnimationId = id
	local ok, track = pcall(animator.LoadAnimation, animator, a)
	if ok and track then
		track.Looped = looped
		track:Play()
		return track
	end
end

-- The new character is shown on the front of the stage (RevealSpot), facing the hall: a local copy is used
-- so the camera can frame it cleanly with the table behind; the real NPC appears on its spot afterwards.
local function revealOnBase(slot, tid, ch, bonus)
	local r = C.Rarities[ch.rarity]
	local npc = findNpc(slot, tid)
	local base = workspace.World:FindFirstChild("Base" .. slot)
	local spot = base and base:FindFirstChild("RevealSpot")
	local copy
	if npc and spot then
		npc.Archivable = true
		copy = npc:Clone()
	end
	if not copy then -- nothing to show on the base (inventory full / not equipped): just the card
		tween(dim, 0.3, { BackgroundTransparency = 0.35 })
		local close = revealCard(ch, bonus)
		waitOrSkip(3)
		close()
		return
	end
	local hrp = npc.HumanoidRootPart
	local stand = hrp.Size.Y / 2 + npc.Humanoid.HipHeight
	local floor = spot.Position - Vector3.new(0, spot.Size.Y / 2, 0)
	local center = floor + Vector3.new(0, stand, 0)
	local front = Vector3.zAxis -- the stage front faces the hall (+Z)
	copy:SetAttribute("ThrowId", nil)
	copy:PivotTo(CFrame.lookAt(center, center + front))
	copy.Parent = workspace
	local hideReal = RunService.RenderStepped:Connect(function() setHidden(npc, true) end)
	local hideCopy = RunService.RenderStepped:Connect(function() setHidden(copy, true) end)

	-- A: dark scene, beam slams down, energy gathers, rumble; the camera pushes in from the hall
	local camStart = os.clock()
	camFn = function()
		local t = os.clock() - camStart
		local push = math.min(t / 1.1, 1)
		local pos = center + front * (16 - 4 * push) + Vector3.new(0, 5.5 - 2 * push, 0)
		return CFrame.lookAt(pos, center + Vector3.new(0, 0.5, 0)), t < 0.05
	end
	cam.FieldOfView = 55
	tween(dim, 0.4, { BackgroundTransparency = 0.5 })
	tween(cc, 0.4, { Brightness = -0.1, Saturation = -0.2, TintColor = WHITE })
	local beam = Instance.new("Part")
	beam.Shape, beam.Anchored, beam.CanCollide, beam.CanQuery, beam.CastShadow = Enum.PartType.Cylinder, true, false, false, false
	beam.Material, beam.Color, beam.Transparency = Enum.Material.SmoothPlastic, r[2]:Lerp(WHITE, 0.6), 0.55
	beam.Size = Vector3.new(90, 0.4, 0.4)
	beam.CFrame = CFrame.new(floor + Vector3.new(0, 45, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	beam.Parent = workspace
	tween(beam, 0.35, { Size = Vector3.new(90, 7, 7) }, Enum.EasingStyle.Back)
	local beamLight = Instance.new("PointLight")
	beamLight.Color, beamLight.Range, beamLight.Brightness, beamLight.Parent = r[2], 24, 6, beam
	local core = anchorPart(CFrame.new(center))
	local gather = emitter(core, {
		Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Speed = NumberRange.new(10, 14), Lifetime = NumberRange.new(0.4, 0.5), Size = NumberSequence.new(0.6, 0.1),
		Color = ColorSequence.new(r[2], WHITE), Rate = 120,
	})
	hardShake(0.6)
	sfx("Hit")
	local t0 = os.clock()
	while os.clock() - t0 < 1.1 and not skip do
		hardShake(0.1 + (os.clock() - t0) * 0.45)
		RunService.RenderStepped:Wait()
	end

	-- B: BOOM, the character appears and cheers
	gather.Rate = 0
	hideCopy:Disconnect()
	setHidden(copy, false)
	for _, p in copy:GetDescendants() do -- keep the part-built cue hidden where the Blender cue mesh is shown
		if p.Name == "Stick" and p:FindFirstChild("MeshVisual") then p.LocalTransparencyModifier = 1 end
	end
	playAnim(copy, ANIM_CHEER, false)
	sfx("Reward")
	doFlash(r[2]:Lerp(WHITE, 0.3), 1, 0.7)
	hardShake(1.8 + ch.rarity * 0.08)
	shockwave(floor + Vector3.new(0, 0.3, 0), r[2], 40, 0.8)
	shockwave(floor + Vector3.new(0, 0.6, 0), WHITE, 24, 0.5)
	burst(core, r[2], 120, 30)
	local confetti = emitter(core, {
		Speed = NumberRange.new(20, 32), SpreadAngle = Vector2.new(50, 50), Lifetime = NumberRange.new(2, 3),
		Acceleration = Vector3.new(0, -25, 0), Drag = 1.2, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-300, 300),
		Size = NumberSequence.new(0.35), LightEmission = 0.2, EmissionDirection = Enum.NormalId.Top,
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)), ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 60)), ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 200, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 255, 120)) }),
	})
	confetti:Emit(140)
	tween(beam, 0.6, { Size = Vector3.new(90, 0.2, 0.2), Transparency = 1 })
	tween(dim, 0.3, { BackgroundTransparency = 0.8 })
	tween(cc, 0.3, { Brightness = 0.08, Saturation = 0.45, TintColor = r[2]:Lerp(WHITE, 0.7) })

	-- C: slow orbit in front of the character and zoom on the face, reveal card
	local orbit0 = os.clock()
	camFn = function()
		local t = math.min((os.clock() - orbit0) / 3.4, 1)
		local e = 1 - (1 - t) ^ 3
		local a = math.rad(-30 + 60 * e)
		local dir = CFrame.fromAxisAngle(Vector3.yAxis, a) * front
		local pos = center + dir * (12 - 5 * e) + Vector3.new(0, 3.5 - 1.7 * e, 0)
		return CFrame.lookAt(pos, center + Vector3.new(0, 1.2 * e, 0))
	end
	tween(cam, 3.4, { FieldOfView = 40 }, Enum.EasingStyle.Sine)
	local close = revealCard(ch, bonus)
	waitOrSkip(3.4)
	close()
	beam:Destroy()
	copy:Destroy()
	hideReal:Disconnect()
	setHidden(npc, false)
	task.delay(2, core.Destroy, core)
end

-- ===== The shot =====
Fx.OnClientEvent:Connect(function(kind, slot, dist, id, luck, tid, fullByServer)
	if kind ~= "Throw" then return end
	local ch = C.Characters[id]
	local rcol = C.Rarities[ch.rarity][2]
	local mine = slot == _G.MySlot
	local full = fullByServer and not _G.ShortOnly -- Epic+ gets the full show unless the player chose short cinematics
	local A = C.AnimOf(full)
	if mine then _G.ShotReadyAt = os.clock() + C.ThrowTime(dist, fullByServer) + C.ThrowCooldown end
	local x = laneX(slot)
	local start = Vector3.new(x, FELT_Y + R, T.StartZ + 10) -- room behind the ball for the cue and the camera
	local b = ball(WHITE, R * 2, CFrame.new(start))
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position, a0.Parent, a1.Parent = Vector3.new(0, 0.7, 0), Vector3.new(0, -0.7, 0), b, b
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1, trail.LightEmission = a0, a1, 1
	trail.Lifetime, trail.Transparency, trail.Parent = 0.6, NumberSequence.new(0.1, 1), b
	local aura = emitter(b, {
		Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180), Lifetime = NumberRange.new(0.3, 0.6),
		Size = NumberSequence.new(0.9, 0), Transparency = NumberSequence.new(0.2, 1),
	})
	local function themeAt(z)
		local tbl = C.Tables[zoneAt(z)]
		trail.Color = ColorSequence.new(WHITE, tbl[2])
		aura.Color = ColorSequence.new(tbl[2], WHITE)
		return tbl
	end
	themeAt(start.Z)

	if mine then
		setCinema(true)
		luckLabel.Text = "🍀 LUCK x" .. luck
		luckGrad.Enabled = luck >= 5
		luckLabel.TextColor3 = luck >= 5 and WHITE or C.UI.Title
		pop(luckScale)
	end
	local power = math.clamp(dist / T.Length, 0, 1)
	windup(b, start, mine, math.clamp(dist / 400, 0.3, 1), C.Cues[mine and _G.MyCue or 1][4], full)
	aura.Rate = 40

	-- 2. Flight over the tables
	local roll = C.RollTime(dist, full)
	local zone = math.clamp(math.ceil(dist / zoneLen), 1, N)
	local endZ = math.clamp(T.StartZ + dist, start.Z + 4, T.StartZ + T.Length - R) -- same zone as the server picked
	local broke, lastZone = false, 1
	local rot, lastZ = CFrame.new(), start.Z
	if mine then
		camFn = function()
			local p = b.Position
			return CFrame.lookAt(p + Vector3.new(0, 5.5, -13), p + Vector3.new(0, 1, 12))
		end
	end
	local t0 = os.clock()
	repeat
		local t = skip and 1 or math.min((os.clock() - t0) / roll, 1)
		local z = start.Z + (endZ - start.Z) * (1 - (1 - t) ^ 3)
		rot = CFrame.Angles((z - lastZ) / R, 0, 0) * rot
		lastZ = z
		b.CFrame = CFrame.new(x, start.Y, z) * rot
		if not broke and z >= RACK_Z - R * 2 and racks[slot] then
			broke = true
			breakRack(slot, math.max(power, 0.3))
			if mine then
				hardShake(1.3)
				doFlash(WHITE, 0.35)
			end
		end
		local zn = zoneAt(z)
		if zn ~= lastZone then -- entering a new table
			lastZone = zn
			local tbl = themeAt(z)
			aura.Rate = 40 + zn * 6
			if mine and (full or zn == zone) then -- the short version only announces the final table
				hardShake(0.7 + zn * 0.06)
				doFlash(tbl[2], 0.45, 0.4)
				cam.FieldOfView = 92
				tween(cam, 0.5, { FieldOfView = 80 }, Enum.EasingStyle.Quart)
				tween(cc, 0.3, { TintColor = tbl[2]:Lerp(WHITE, 0.75) })
				showBanner("TABLE " .. zn .. " • " .. string.upper(tbl[1]), tbl[2])
				sfx("Click")
			end
		end
		RunService.RenderStepped:Wait()
	until t >= 1

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
		_G.Toast(ch.name .. " • " .. C.Rarities[ch.rarity][1], rcol)
		return
	end
	hardShake(1)
	doFlash(rcol, 0.6, 0.3)
	tween(blur, 0.3, { Size = 0 })
	local bonus = math.max(0, ch.rarity - zone)
	if full and not skip then
		tween(dim, 0.35, { BackgroundTransparency = 0 }).Completed:Wait()
		revealOnBase(slot, tid, ch, bonus)
	else -- short version / skipped: just the card, the character pops up on the base by itself
		tween(dim, 0.25, { BackgroundTransparency = 0.55 })
		local close = revealCard(ch, bonus)
		skip = false
		waitOrSkip(full and 2.2 or 1.6)
		close()
	end
	setCinema(false)
end)

-- ===== Decorative balls rolling into pockets on the base tables =====
local basePockets = {}
for _, px in { -4.6, 4.6 } do
	for _, pz in { -8.1, 0, 8.1 } do table.insert(basePockets, Vector3.new(px, 0, pz)) end
end
local world = workspace:WaitForChild("World")
while true do
	task.wait(rng:NextNumber(1, 2.5))
	local base = world:FindFirstChild("Base" .. rng:NextInteger(1, 4))
	local table_ = base and base:FindFirstChild("PoolTable")
	if table_ then
		local o = table_.MeshPivot.Position + Vector3.new(0, 4.4, 0)
		local from = o + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-6, 6))
		local goal = o + basePockets[rng:NextInteger(1, #basePockets)]
		local b = ball(rackColors[rng:NextInteger(1, #rackColors)], 0.8, CFrame.new(from))
		local spin = CFrame.fromAxisAngle((goal - from).Unit:Cross(Vector3.yAxis), -(goal - from).Magnitude / 0.4)
		tween(b, 1.2, { CFrame = CFrame.new(goal) * spin.Rotation }).Completed:Once(function() drop(b, goal) end)
	end
end
