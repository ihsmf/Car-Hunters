-- The shot, start to finish:
--   1. stance: the shooter bends over the head of their lane, bridge hand on the felt, their own cue
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
local BallArt=require(RS.Shared.BallArt)
local MeshBuilder = require(RS.Shared.MeshBuilder)
local CueFx = require(RS.Shared.CueFx)
local ShotPose = require(RS.Shared.ShotPose)
local Art = require(RS.Shared.Art)
local Fx = RS:WaitForChild("Remotes"):WaitForChild("Fx")
local plr = Players.LocalPlayer
local cam = workspace.CurrentCamera
local T, N = C.Table, #C.Rarities
local zoneLen = T.SegmentLength
local FELT_Y = T.FeltY
local R = ShotPose.Radius
local RR = 0.75 -- rack ball radius
local RACK_Z = T.StartZ + 6
local GOLD = Color3.fromRGB(255, 200, 50)
local rng = Random.new()
local WHITE = Color3.new(1, 1, 1)

plr.CameraMaxZoomDistance = 18 -- players can't zoom out far enough to see past the scenery

local function sfx(k) if _G.PlaySfx then _G.PlaySfx(k) end end
local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function zoneAt(z) return C.ZoneOf(z - T.StartZ) end

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
local pocketX = math.abs(workspace.World.LongTable.Table1.PocketCollider.Position.X)
for i = 1, N do
	for _, sx in { -1, 1 } do
		table.insert(pockets, Vector3.new(sx * pocketX, FELT_Y + RR, T.StartZ + (i - 0.5) * zoneLen))
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

-- ===== One shared 15-ball rack in the centre: solids, stripes, the black 8 in the middle =====
local SOLIDS = { Color3.fromRGB(250, 200, 30), Color3.fromRGB(30, 80, 200), Color3.fromRGB(220, 40, 40), Color3.fromRGB(110, 40, 170), Color3.fromRGB(255, 120, 20), Color3.fromRGB(20, 140, 70), Color3.fromRGB(130, 30, 30), Color3.fromRGB(18, 18, 20) }
local ORDER = { 1, 9, 2, 10, 8, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15 }
local rack

local function buildRack()
	local list = {}
	local k = 0
	for row = 0, 4 do
		for j = 0, row do
			k += 1
			local n = ORDER[k]
			local b = ball(SOLIDS[(n - 1) % 8 + 1], RR * 2, CFrame.new((j - row / 2) * RR * 2.04, FELT_Y + RR, RACK_Z + row * RR * 1.77) * CFrame.Angles(k, k * 2, 0))
			b.Size = Vector3.one * 0.1
			tween(b, 0.4, { Size = Vector3.one * RR * 2 }, Enum.EasingStyle.Back)
			table.insert(list, b)
		end
	end
	rack = list
end
task.spawn(buildRack)

-- A single rack breaks on contact. Staggered caroms send balls to the two real mouths.
local function breakRack(power)
 local list=rack
 if not list then return end
 rack=nil
 sfx("Break")
 local elapsed=0
 local bodies={}
 for i,ballPart in list do
  local first=ballPart.Position
  local side=first.X<0 and -1 or first.X>0 and 1 or (i%2==0 and -1 or 1)
  local target=pockets[side<0 and 1 or 2]
  local bounce=Vector3.new(side*(T.Width/2-RR),first.Y,RACK_Z+8+(i*7)%18)
  bodies[i]={ball=ballPart,start=first,turn=bounce,target=target,duration=.77+i*.032+(1-power)*.16}
 end
 local conn
 conn=RunService.RenderStepped:Connect(function(dt)
  elapsed+=dt
  local alive=false
  for i,o in bodies do
   if o.done then continue end
   local u=math.clamp((elapsed-i*.005)/o.duration,0,1)
   if u>0 and not o.launched then
    o.launched=true
    if i==3 or i==8 or i==14 then sfx("Ball"..(i==3 and 1 or i==8 and 2 or 3)) end
   end
   if u>=.5 and not o.bounced then
    o.bounced=true
    if i==2 or i==12 then sfx("Cushion") end
   end
   if u>=1 then o.done=true;drop(o.ball,o.target,i~=2 and i~=13)
   else
    alive=true
    local pos=u<.5 and o.start:Lerp(o.turn,2*u) or o.turn:Lerp(o.target,(u-.5)*2)
    o.ball.CFrame=CFrame.new(pos)*CFrame.Angles(u*11,0,u*6)
   end
  end
  if not alive then conn:Disconnect();buildRack() end
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
local luckLabel, luckScale = label(fxGui, "", UDim2.fromScale(0.94, 0.075), C.UI.Title, UDim2.fromScale(0.5, 0.06)) -- wide: luck is written in full digits
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
skipBtn.BackgroundColor3, skipBtn.Text, skipBtn.FontFace, skipBtn.TextSize = C.UI.Title, "Skip", C.UI.Font, 27
skipBtn.TextColor3, skipBtn.Visible, skipBtn.ZIndex, skipBtn.AutoButtonColor = C.UI.Ink, false, 8, true
Instance.new("UICorner", skipBtn).CornerRadius = UDim.new(0, 24)
local skipStroke = Instance.new("UIStroke")
skipStroke.Thickness, skipStroke.Color, skipStroke.ApplyStrokeMode, skipStroke.Parent = 4, C.UI.Ink, Enum.ApplyStrokeMode.Border, skipBtn
local gloss = Instance.new("Frame")
	gloss.Name, gloss.Size, gloss.Position = "EnamelHighlight", UDim2.new(.56,0,0,3), UDim2.fromOffset(11,4)
	gloss.BorderSizePixel, gloss.BackgroundColor3, gloss.BackgroundTransparency = 0, Color3.new(1,1,1), .35
	gloss.ZIndex, gloss.Parent = skipBtn.ZIndex + 1, skipBtn
	Instance.new("UICorner", gloss).CornerRadius = UDim.new(1,0)
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
	local p = cam.CFrame.Position
	local bound = p.Z >= 78 and 32 or 99
	cam.CFrame = CFrame.new(math.clamp(p.X,-bound,bound),math.clamp(p.Y,.7,p.Z>=78 and 41 or 30),math.clamp(p.Z,-22,6078)) * cam.CFrame.Rotation
end)

local function setCinema(on)
	cinema = on
	_G.ThrowBusy = on
	if _G.SetHudVisible then _G.SetHudVisible(not on) end
	letterbox(on)
	luckLabel.Visible = on
	skipBtn.Visible = false
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
	local shown = BallArt.Make(it, 4)
	shown.Parent = vp
	local vcam = Instance.new("Camera")
	vcam.FieldOfView, vcam.CFrame, vcam.Parent = 30, CFrame.lookAt(Vector3.new(0, 1.5, 8.5), Vector3.zero), vp
	vp.CurrentCamera = vcam
	tween(vpScale, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)
	local title, s1 = label(root, string.upper(r[1]) .. "!", UDim2.fromScale(0.8, 0.13), WHITE, UDim2.fromScale(0.5, 0.66))
	local name, s2 = label(root, C.ItemName(it), UDim2.fromScale(0.7, 0.08), V.color or r[2], UDim2.fromScale(0.5, 0.77))
	local _, s3 = label(root, "$" .. C.Short(C.ItemIncome(it)) .. "/s   ·   1 in " .. C.FullNumber(C.BallOdds(it)), UDim2.fromScale(0.8, 0.055), C.UI.Money, UDim2.fromScale(0.5, 0.84))
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
		shown:PivotTo(CFrame.Angles(0.35,t*1.6,0)*CFrame.new(0,math.sin(t*3)*.15,0))
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

-- The same timeline poses the real avatar on every client. Contact releases the cue ball.
local function windup(start, mine, payload)
	local def = CueFx.Def(payload.cue, payload.dragon)
	local W = payload.impactAt - payload.started
	local approach = math.min(.35, W * .35)
	local who = Players:GetPlayerByUserId(payload.uid)
	local char = who and who.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local real = char and char:FindFirstChild("Cue")
	local animate, resetPose
	if root and hum and hum.Health > 0 then animate, resetPose = ShotPose.Animator(char, payload.slot, payload.stance) end
	local key = Art.CueKey(payload.cue, payload.dragon)
	local prop = anchorPart(CFrame.new(start))
	local appearance = Art.Native(key, prop.CFrame, C.CueScale)
	local native = appearance ~= nil
	if not appearance then appearance = Art.Fallback(key, prop.CFrame, C.CueScale) end
	local side = start.X < 0 and 1 or -1
	local _, grip = ShotPose.Cue(start, 0)
	local maximum = .65 + (payload.power or 0) * .65
	local back, blend = 0, 0
	local hidden = false
	local started = false
	local conn

	local function revealReal()
		if real and real.Parent then real:SetAttribute("LocalCueHidden", nil) end
	end
	local function cleanup()
		if conn then conn:Disconnect(); conn = nil end
		if resetPose and char and char.Parent then resetPose() end
		revealReal()
		if appearance and not appearance.Parent then appearance:Destroy() end
		prop:Destroy()
	end
	if animate then
		conn = RunService.PreSimulation:Connect(function()
			if char.Parent and hum.Health > 0 and started then animate(back, blend) end
		end)
	end
	if mine then
		camFn = function()
			local t = math.clamp((workspace:GetServerTimeNow() - payload.started) / W,0,1)
			local mid = start - ShotPose.Dir * 5
			local wide = mid + Vector3.new(side * 11,5,0)
			local close = grip - ShotPose.Dir * 5 + Vector3.new(side*1.7,3.2,0)
			return CFrame.lookAt(wide:Lerp(close,t),mid:Lerp(start + Vector3.new(0,.6,4),t))
		end
		cam.FieldOfView = 58
		tween(cam, W, { FieldOfView = 45 }, Enum.EasingStyle.Sine)
	end
	local function place()
		if not appearance then return end
		local cf = ShotPose.Cue(start, back)
  prop.CFrame=cf
		if native then
			local template = RS.ImportedArt:FindFirstChild(key)
			appearance.CFrame = cf * CFrame.new((template:GetAttribute("Center") or Vector3.zero) * C.CueScale)
		else
			appearance:PivotTo(cf)
   Art.PoseCue(appearance,os.clock(),math.clamp(back/maximum,0,1))
		end
	end
	if appearance then appearance.Parent = nil end
	while workspace:GetServerTimeNow() < payload.impactAt do
		local t = workspace:GetServerTimeNow() - payload.started
		blend = math.clamp(t / approach,0,1)
		started = t >= 0
		if t >= approach then
			local u = math.clamp((t-approach)/(W-approach),0,1)
			if u < .72 then
				back = maximum * math.sin(u/.72*math.pi/2)
			elseif u < .79 then
				back = maximum
			else
				back = maximum + (-.30-maximum)*((u-.79)/.21)^2
			end
			if not hidden then
				hidden = true
				if real and real.Parent then real:SetAttribute("LocalCueHidden", true) end
				if appearance then appearance.Parent = prop; CueFx.Apply(prop,payload.cue,def,C.CueScale) end
			end
			place()
		end
		if hum and (not char.Parent or hum.Health <= 0) then
			cleanup()
			while workspace:GetServerTimeNow() < payload.impactAt do RunService.RenderStepped:Wait() end
			return
		end
		RunService.RenderStepped:Wait()
	end
	back, blend = -.30, 1
	if not hidden and appearance then
		if real and real.Parent then real:SetAttribute("LocalCueHidden", true) end
		appearance.Parent = prop
	end
	place()
	local tip = start - ShotPose.Dir * R
	sfx("Hit")
	burst(tip, Color3.fromRGB(140,200,255), 14, 6)
	burst(start,def.inlay:Lerp(WHITE,.4),30,18)
	shockwave(start - Vector3.new(0,R-.1,0),WHITE,13,.4)
	if mine then
		doFlash(WHITE,.6,.24)
		hardShake(1.8)
		cam.FieldOfView = 88
		tween(cam,.7,{FieldOfView = 78},Enum.EasingStyle.Quart)
		skipBtn.Visible = true
	end
	task.spawn(function()
		local t0 = os.clock()
		repeat
			blend = math.clamp(1-(os.clock()-t0)/.26,0,1)
			RunService.RenderStepped:Wait()
		until blend <= 0 or not root or not root.Parent
		cleanup()
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
-- The table reached selects the ceremony, independently of the luck roll.
local function milestoneReveal(it, section)
 local rank=math.floor(section/3)
 local finale=section==#C.Tables
 local duration=finale and 15 or 4.4+rank*.28
 if _G.ShortOnly then duration=math.min(duration,3) end
 local tint=C.Tables[section][2]
 local gold=Color3.fromRGB(255,211,114)
 local ice=Color3.fromRGB(126,229,255)
 local root=frame({Name="SectionReveal",ZIndex=3,BackgroundColor3=Color3.fromRGB(7,5,20)})
 local vp=Instance.new("ViewportFrame")
 vp.BackgroundTransparency=1
 vp.Size=UDim2.fromScale(1,.84)
 vp.Ambient=Color3.fromRGB(182,173,208)
 vp.LightColor=Color3.fromRGB(255,241,216)
 vp.LightDirection=Vector3.new(-1,-.4,-.7)
 vp.Parent=root
 local camera=Instance.new("Camera")
 camera.FieldOfView=42
 camera.Parent=vp
 vp.CurrentCamera=camera
 local world=Instance.new("WorldModel")
 world.Parent=vp
 local prize=BallArt.Make(it,3)
 prize.Parent=world
 local function gem(parent,color,shape,size,cf)
  local p=Instance.new("Part")
  p.Anchored,p.CanCollide,p.CanQuery,p.CanTouch=true,false,false,false
  p.Material,p.Color,p.Shape=Enum.Material.Neon,color,shape
  p.Size,p.CFrame,p.Parent=size,cf,parent
  return p
 end
 local function line(parent,a,b,width,color)
  return gem(parent,color,Enum.PartType.Block,Vector3.new(width,width,(b-a).Magnitude),CFrame.lookAt((a+b)*.5,b))
 end
 local orbitCount=math.min(5,1+math.floor(rank/6))
 local tracks={}
 for i=1,orbitCount do
  local ring=Instance.new("Model")
  ring.WorldPivot=CFrame.identity
  ring.Parent=world
  local radius=2.1+i*.35
  local function point(angle) return Vector3.new(radius*math.cos(angle),radius*math.sin(angle),0) end
  for k=0,23 do
   line(ring,point(k*math.pi/12),point((k+1)*math.pi/12),.035+.004*i,i%2==0 and ice or tint)
  end
  local bead=gem(world,gold,Enum.PartType.Ball,Vector3.one*(.20+i*.035),CFrame.identity)
  tracks[i]={ring=ring,bead=bead,radius=radius}
 end
 local shards={}
 for i=1,5+rank do
  shards[i]=gem(world,i%3==0 and gold or tint,Enum.PartType.Block,Vector3.new(.08,.25+i%4*.12,.08),CFrame.identity)
 end
 local bolts={}
 if rank>=6 then
  for i=1,math.min(6,math.floor(rank/4)) do
   local chain=Instance.new("Model")
   chain.WorldPivot=CFrame.identity
   chain.Parent=world
   local p=Vector3.new(1.45,0,0)
   for k=1,6 do
    local q=Vector3.new(1.45+k*.65,((k+i)%2-.5)*.66,math.sin(k+i)*.38)
    line(chain,p,q,.07,i%2==0 and ice or gold)
    p=q
   end
   bolts[i]=chain
  end
 end
 local glyphs={}
 local symbols={"H","He","C","N","O","Ne","Si","Ar","Xe","Au","Ω","Δ"}
 if rank>=10 then
  for i=1,math.min(#symbols,math.floor(rank/2)) do
   local glyph=label(root,symbols[i],UDim2.fromScale(.058,.045),i%2==0 and ice or gold,UDim2.fromScale(.5,.4))
   glyphs[i]=glyph
  end
 end
 local title=label(root,C.ItemName(it),UDim2.fromScale(.8,.10),WHITE,UDim2.fromScale(.5,.77))
 local detail=label(root,C.Rarities[C.Balls[it.id].rarity][1].."   ·   $"..C.Short(C.ItemIncome(it)).."/s",UDim2.fromScale(.72,.055),gold,UDim2.fromScale(.5,.87))
 local curtain=frame({Parent=root,BackgroundColor3=Color3.new(),ZIndex=4})
 skipBtn.Visible=true
 luckLabel.Visible=false
 local start=os.clock()
 local struck=false
 repeat
  local elapsed=os.clock()-start
  local u=math.min(1,elapsed/duration)
  local orbit=elapsed*(.61+rank*.018)
  local charge=math.clamp(u/.55,0,1)
  local fall=math.clamp((u-.51)/.18,0,1)
  local y=(1-fall*fall)*1.15+math.sin(math.pi*math.clamp((u-.69)/.15,0,1))*.28
  local focus=Vector3.new(0,y,0)
  prize:PivotTo(CFrame.new(focus)*CFrame.Angles(.2,orbit*1.3,0))
  for i,row in tracks do
   local spin=CFrame.new(focus)*CFrame.Angles(.55+i*.68,orbit*.32+i,.3+i*.92+orbit*.16)
   row.ring:PivotTo(spin)
   local a=orbit*(1+i*.35)+i
   row.bead.Position=spin*Vector3.new(row.radius*math.cos(a),row.radius*math.sin(a),0)
  end
  for i,p in shards do
   local a=orbit*.48+i*2.39996
   local rad=2.8+(1-charge)*4+(i%5)*.24+1.8*math.sin(fall*math.pi)
   p.CFrame=CFrame.new(math.cos(a)*rad,y+math.sin(a*1.7+i)*2,math.sin(a)*rad)*CFrame.Angles(a,i,a*.4)
  end
  for i,chain in bolts do
   local opening=math.clamp((u-.25-i*.018)*8,0,1)
   chain:PivotTo(CFrame.new(0,y,opening>0 and 0 or -1000)*CFrame.Angles(0,orbit*.45+i*.9,i*2.4+math.sin(orbit*.6)*.18))
  end
  for i,glyph in glyphs do
   local a=i*2*math.pi/#glyphs+orbit*.17
   glyph.Visible=u>.23 and u<.84
   glyph.Position=UDim2.fromScale(.5+.36*math.cos(a),.41+.25*math.sin(a))
   glyph.Rotation=math.sin(a)*12
  end
  local distance=13-charge*3+math.sin(fall*math.pi)*2
  camera.CFrame=CFrame.lookAt(Vector3.new(math.sin(orbit*.25)*distance,2+.6*math.cos(orbit),math.cos(orbit*.25)*distance),focus)
  -- Two broad eclipse cuts, followed by the impact and the identifying card.
  local eclipse=.25*math.max(0,1-u/.085)
  if finale then
   eclipse=math.max(eclipse,.94*math.max(0,1-math.abs(u-.31)/.045),.98*math.max(0,1-math.abs(u-.53)/.055))
  end
  curtain.BackgroundTransparency=1-eclipse
  title.Visible,detail.Visible=u>=.69,u>=.73
  if u>=.69 and not struck then struck=true;sfx("Reward");hardShake(.35+rank*.035) end
  if u>=1 or skip then break end
  RunService.RenderStepped:Wait()
 until false
 root:Destroy()
end


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
	local primary = real.PrimaryPart
	primary:SetAttribute("Revealing", true)
	RunService.RenderStepped:Wait()
	local goal = primary.Position
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
	local b = BallArt.Make(it, size, CFrame.new(goal + Vector3.new(0, 22, 0)))
	b.Parent = workspace
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position, a0.Parent, a1.Parent = Vector3.new(size * 0.4, 0, 0), Vector3.new(-size * 0.4, 0, 0), b.PrimaryPart, b.PrimaryPart
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1, trail.Color, trail.LightEmission = a0, a1, ColorSequence.new(WHITE, r[2]), 1
	trail.Lifetime, trail.Transparency, trail.Parent = 0.35, NumberSequence.new(0.2, 1), b.PrimaryPart
	local t0, fall = os.clock(), quick and 0.7 or 0.9
	repeat
		local t = skip and 1 or math.min((os.clock() - t0) / fall, 1)
		local y = 22 * (1 - TweenService:GetValue(t, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out))
		b:PivotTo(CFrame.new(goal+Vector3.new(0,y,0))*CFrame.Angles(t*9,t*5,0))
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
	if primary.Parent then primary:SetAttribute("Revealing", nil) end
	tween(cam, 2.6, { FieldOfView = 40 }, Enum.EasingStyle.Sine)
	local close = revealCard(it, bonus)
	waitOrSkip(quick and 1.8 or 3)
	close()
end

-- ===== The shot =====
local function setLuck(v) -- the number is written every frame while the ball rolls
	luckLabel.Text = "LUCK ×" .. C.LuckText(v)
	luckGrad.Enabled = v >= 5
	luckLabel.TextColor3 = v >= 5 and WHITE or C.UI.Title
end
-- The shown luck never jumps: it counts up ×1.00, ×1.01, ×1.02 ... towards the target. The further behind and the
-- bigger the luck, the faster it climbs (multiplicative speed), so huge values still arrive in a couple of seconds.
local luckShown, luckTarget, luckClock = 1, 1, os.clock()
local function luckStep(dt)
	local now = os.clock()
	dt, luckClock = dt or math.min(0.1, now - luckClock), now
	if luckShown >= luckTarget then return true end
	local gap = math.log10(luckTarget / luckShown)
	local rate = 0.35 + 1.6 * gap + 0.25 * math.log10(luckShown + 1)
	luckShown = math.min(luckTarget, math.max(luckShown + 0.01, luckShown * (1 + rate * dt)))
	setLuck(luckShown)
	return luckShown >= luckTarget
end
local function showLuck(v, lucky) -- a new target (a table was crossed): pop, the number keeps counting up
	luckTarget = math.max(luckTarget, v)
	pop(luckScale, lucky and 1.8 or 1.25)
end

-- "1 in N" recount on a reveal: climbs 1, 2, 3 ... 100 ... on a log curve and stops exactly on the shot's final luck
local function oddsCounter(finalL, seconds)
	finalL = math.max(1, finalL or 1)
	local l, sc = label(fxGui, "1 in 1", UDim2.fromScale(0.94, 0.085), WHITE, UDim2.fromScale(0.5, 0.16))
	l.ZIndex = 9
	local grad = Instance.new("UIGradient")
	grad.Color, grad.Parent = ColorSequence.new(WHITE, C.UI.Title), l
	local t0, last, lastTick = os.clock(), "", 0
	task.spawn(function()
		repeat
			local u = math.clamp((os.clock() - t0) / seconds, 0, 1)
			local v = u >= 1 and finalL or finalL ^ (1 - (1 - u) ^ 3)
			local text = "1 in " .. C.FullNumber(v)
			if text ~= last then
				last, l.Text = text, text
				if os.clock() - lastTick > 0.06 then
					lastTick = os.clock()
					sfx("Click")
				end
			end
			RunService.RenderStepped:Wait()
		until u >= 1 or not l.Parent
		if l.Parent then
			grad.Color = RAINBOW
			pop(sc, 1.7)
			sfx("Reward")
		end
	end)
	return function()
		if not l.Parent then return end
		tween(l, 0.3, { TextTransparency = 1 })
		tween(l.UIStroke, 0.3, { Transparency = 1 })
		task.delay(0.35, l.Destroy, l)
	end
end

Fx.OnClientEvent:Connect(function(kind, p)
	if kind ~= "Throw" then return end
	local slot, dist, tid = p.slot, p.dist, p.tid
	local it = { id = p.id, section=p.section,design=p.design,v=p.v }
	local ch = C.Balls[it.id]
	local rcol = C.Rarities[ch.rarity][2]
	local mine = p.uid == plr.UserId
	local full = p.full
	local A = C.AnimOf(full)
	if mine then _G.ShotReadyAt = p.started + C.ThrowTime(dist, p.full) + C.ThrowCooldown end
	local x = 0
	local start = ShotPose.Ball(slot)
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
		luckShown, luckTarget, luckClock = 1, 1, os.clock() -- table luck: x1.00 at the start of the long table
		setLuck(1)
		pop(luckScale, 1.25)
	end
	local power = math.clamp(dist / T.Length, 0, 1)
	windup(start, mine, p)
	aura.Rate = 40

	-- 2. Flight over the tables
	local roll = C.RollTime(dist, full)
	local zone = math.clamp(math.ceil(dist / zoneLen), 1, N)
	local endZ = math.clamp(T.StartZ + dist, start.Z + 4, T.StartZ + T.Length - R) -- same zone as the server picked
	local impactZ = RACK_Z - R - RR
	local aimAtRack = rack ~= nil and endZ >= impactZ
	local broke, lastZone = false, 1
	local rot, lastX, lastZ = CFrame.new(), x, start.Z
	if mine then
		camFn = function()
			local bp = b.Position
			local mix=math.clamp((workspace:GetServerTimeNow()-p.impactAt-.42)/.65,0,1)
            local offset=Vector3.new(0,13,-14):Lerp(Vector3.new(0,6,-13),mix)
            return CFrame.lookAt(bp+offset,bp+Vector3.new(0,0,11))
		end
	end
	repeat
		local t = mine and skip and 1 or math.clamp((workspace:GetServerTimeNow() - p.impactAt) / roll, 0, 1)
		local seconds=t*roll
        local approachEnd=math.min(endZ,impactZ+1)
        local z
        if seconds<.24 then
            z=start.Z+(impactZ-start.Z)*seconds/.24
        elseif seconds<.72 then
            z=impactZ+(approachEnd-impactZ)*(seconds-.24)/.48
        else
            local exit=math.clamp((seconds-.72)/(roll-.72),0,1)
            z=approachEnd+(endZ-approachEnd)*(1-(1-exit)^2)
        end
        local ballX=0
        local step = Vector3.new(ballX - lastX, 0, z - lastZ)
		if step.Magnitude > 0 then
			rot = CFrame.fromAxisAngle(Vector3.yAxis:Cross(step.Unit), step.Magnitude / R) * rot
		end
		lastX, lastZ = ballX, z
		b.CFrame = CFrame.new(ballX, start.Y, z) * rot
		if aimAtRack and not broke and z >= impactZ then
			broke = true
			breakRack(math.max(power, 0.3))
		end
		if mine then -- live luck: grows smoothly between the server's per-table values as the ball moves
			luckTarget = math.max(luckTarget, C.LuckAt(1, math.min(z - T.StartZ, dist))) -- the tables' fixed ranges
			luckStep(skip and 99 or nil)
		end
		local zn = zoneAt(z)
		if zn ~= lastZone then -- entering a new table: the luck of the table just crossed is added
			local crossed = zn - 1
			lastZone = zn
			local tbl = themeAt(z)
			aura.Rate = 40 + zn
            aura.SpreadAngle=Vector2.new(38+(zn%5)*22,45+(zn%4)*26)
            aura.Acceleration=Vector3.new(0,2+(zn%7)*1.5,0)
            trail.Lifetime=.28+zn*.006
			if mine and p.track[crossed] then pop(luckScale, 1.25) end
			if mine and (full or zn == zone) then -- the short version only announces the final table
				hardShake(0.5 + zn * 0.03)
				doFlash(tbl[2], 0.35, 0.35)
				cam.FieldOfView = 90
				tween(cam, 0.5, { FieldOfView = 80 }, Enum.EasingStyle.Quart)
				tween(cc, 0.3, { TintColor = tbl[2]:Lerp(WHITE, 0.75) })
				showBanner("TABLE " .. zn .. "  " .. string.upper(tbl[1]) .. "  LUCK ×" .. string.format("%.2g", C.TableGain(zn)), tbl[2])
				sfx("Click")
			end
		end
		RunService.RenderStepped:Wait()
	until t >= 1
	local tableL = C.LuckAt(1, dist)
	local finalL = math.min(C.MaxLuck, tableL * (p.luck0 or 1)) -- the cue multiplies the table luck when the ball drops
	if mine then -- finish the table count, then the cue multiplier kicks in
		showLuck(tableL, luckyAt[zone])
		local t0 = os.clock()
		while not luckStep(skip and 99 or nil) and os.clock() - t0 < 3 do RunService.RenderStepped:Wait() end
		luckShown = tableL
		setLuck(tableL)
		if (p.luck0 or 1) > 1 then
			showBanner("CUE BONUS  ×" .. C.LuckText(p.luck0), C.UI.Title)
			sfx("Reward")
			luckTarget = finalL
			t0 = os.clock()
			while not luckStep(skip and 99 or nil) and os.clock() - t0 < 2.5 do RunService.RenderStepped:Wait() end
		end
		luckShown = finalL
		setLuck(finalL)
		pop(luckScale, 1.6)
	end

	-- slide into the zone pocket: zoom in, dim, blur, then fade to black
	local side = slot%2==0 and 1 or -1
	local pocket = Vector3.new(side * pocketX, start.Y, T.StartZ + (zone - 0.5) * zoneLen)
	if mine then
		camFn = function()
			return CFrame.lookAt(pocket + Vector3.new(-side * 8, 7, -9), pocket)
		end
		tween(cam, A.Slide, { FieldOfView = 34 }, Enum.EasingStyle.Sine)
		tween(dim, A.Slide, { BackgroundTransparency = full and 0.45 or 0.75 })
		tween(blur, A.Slide, { Size = full and 6 or 2 })
	end
	local from = b.Position
	repeat
		local t = mine and skip and 1 or math.clamp((workspace:GetServerTimeNow() - p.impactAt - roll) / A.Slide, 0, 1)
		b.CFrame = CFrame.new(from:Lerp(pocket, t * t * (3 - 2 * t))) * rot
		RunService.RenderStepped:Wait()
	until t >= 1
	b:SetAttribute("Tint", rcol)
	drop(b, pocket)
	shockwave(pocket - Vector3.new(0, 0.9, 0), rcol, 12, 0.5)

	if not mine then
		if _G.Toast then _G.Toast(C.ItemName(it) .. "  " .. C.Rarities[ch.rarity][1], rcol) end
		return
	end
	hardShake(1)
	doFlash(rcol, 0.6, 0.3)
	tween(blur, 0.3, { Size = 0 })
	local bonus = math.max(0, ch.rarity - zone)
	local ballOdds = C.BallOdds(it) -- the ball's own "1 in N", independent of the shot's luck
	local closeOdds = it.section ~= #C.Tables and oddsCounter(ballOdds, full and 2.4 or 1.5) -- the finale counts on its own screen
	if it.section==#C.Tables then
  camFn=nil
  dim.BackgroundTransparency=1
  flash.BackgroundTransparency=1
  blur.Size=0
  cc.Brightness,cc.Contrast,cc.TintColor=0,0,WHITE
  luckLabel.Visible,banner.Visible=false,false
  local caption
  local function showPrize()
   if caption then return end
   caption=label(fxGui,C.ItemName(it).."   ·   $"..C.Short(C.ItemIncome(it)).."/s",UDim2.fromScale(.84,.085),WHITE,UDim2.fromScale(.5,.82))
   caption.ZIndex=7
  end
  local ok,shown=pcall(function()
   if skip then return false end
   return require(RS.Shared.HeavenlyBreak)(it,{skipped=function()return skip end,sound=sfx,caption=showPrize,luck=finalL,ballOdds=ballOdds,odds=oddsCounter})
  end)
  if not ok or not shown or not caption then
   showPrize()
   if _G.Toast then _G.Toast(C.ItemName(it),rcol) end
   local okCard,close=pcall(revealCard,it,bonus)
   task.wait(1.25)
   if okCard then pcall(close) end
  end
  caption:Destroy()
 elseif not skip and (it.section or 1)>=3 then
  milestoneReveal(it,it.section)
 elseif not skip then -- every pull lands on your table; the short version is just quicker
		tween(dim, full and 0.35 or 0.2, { BackgroundTransparency = 0 }).Completed:Wait()
		revealOnBase(slot, tid, it, bonus, not full)
	else -- skipped: just the card, the ball appears on the base by itself
		tween(dim, 0.25, { BackgroundTransparency = 0.55 })
		local close = revealCard(it, bonus)
		skip = false
		waitOrSkip(full and 2.2 or 1.6)
		close()
	end
	if closeOdds then closeOdds() end
	setCinema(false)
end)
