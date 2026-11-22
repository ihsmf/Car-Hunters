-- Grand finale of the last table (~23 s, ~10 s with "short cinematics", Skip works). Real-time scene far from the map,
-- scenery modelled in Blender (Shared/Meshes: FinaleNature, FinaleCity, FinaleComputer), camera fully scripted:
--   1 darkness: the cue strikes in a black void, lightning rips around the ball   0 - 3.2 s
--   2 hallucination: a kaleidoscope tunnel of rings and balls, colours melt        3.2 - 6 s
--   3 nature: flight over a valley with a lake, birds                              6 - 9.5 s
--   4 city: dusk dolly between the towers, cars, then a crane over the skyline     9.5 - 13 s
--   5 the sun: straight into a burning sun, white-out                             13 - 16 s
--   6 a computer: on its screen a billiard game is played, the won ball drops, the
--     "1 in N" recount runs, the screen shatters and the ball flies out to you     16 - 23 s
-- Contract (used by Throw): return function(it, ctx) -> ok; ctx = { skipped(), sound(name), caption(), luck, odds(L, s) }
local Run = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local C = require(RS.Shared.Config)
local Art = require(RS.Shared.Art)
local BallArt = require(RS.Shared.BallArt)
local MeshBuilder = require(RS.Shared.MeshBuilder)
local V = Vector3.new
local WHITE = Color3.new(1, 1, 1)
local function smooth(x) x = math.clamp(x, 0, 1); return x * x * (3 - 2 * x) end
local function seg(t, a, b) return math.clamp((t - a) / (b - a), 0, 1) end

local DURATION, SHORT_SPEED = 23, 2.3
local O = { -- scene origins, far away from the map and from each other
	dark = V(6000, 600, 0), trip = V(6000, 600, -500), nature = V(6000, 600, -1300),
	city = V(6000, 600, -2200), sun = V(6000, 900, -3400), room = V(6000, 600, -4600),
}
local LIGHTING_KEYS = { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "ExposureCompensation", "FogEnd", "FogColor" }

return function(it, ctx)
	local scene = Instance.new("Folder")
	scene.Name = "GrandFinale"
	local camera = workspace.CurrentCamera
	local plr = Players.LocalPlayer
	local rnd = Random.new(4242)
	local saved = {}
	for _, k in LIGHTING_KEYS do saved[k] = Lighting[k] end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local atmoDensity = atmosphere and atmosphere.Density
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Parent = Lighting
	local blur = Instance.new("BlurEffect")
	blur.Size, blur.Parent = 0, Lighting
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.IgnoreGuiInset, gui.DisplayOrder, gui.ResetOnSpawn = "FinaleFx", true, 9, false
	local function cover(color)
		local f = Instance.new("Frame")
		f.Size, f.BorderSizePixel, f.BackgroundColor3, f.BackgroundTransparency, f.Parent = UDim2.fromScale(1, 1), 0, color, 1, gui
		return f
	end
	local shade, flash = cover(Color3.new()), cover(WHITE)
	shade.BackgroundTransparency = 0 -- black while the Blender scenery is being built
	gui.Parent = plr:WaitForChild("PlayerGui")
	local closeOdds

	local function run()
		-- ===== building blocks =====
		local function part(size, cf, color, material, shape, parent)
			local p = Instance.new("Part")
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
			p.Size, p.CFrame, p.Color, p.Material = size, cf, color, material or Enum.Material.SmoothPlastic
			if shape then p.Shape = shape end
			p.Parent = parent or scene
			return p
		end
		local function line(parent, a, b, w, color)
			return part(V(w, w, math.max(0.05, (a - b).Magnitude)), CFrame.lookAt((a + b) / 2, b), color, Enum.Material.Neon, nil, parent)
		end
		local function mesh(name, cf, overrides, scale, fallback)
			local mp = MeshBuilder.Create(name, cf, overrides, scale)
			if mp then
				mp.Parent = scene
				return mp
			end
			if fallback then fallback() end
			return nil
		end
		local function ring(cf, diameter, color) -- Blender torus, or a ring of neon blocks
			local r = mesh("Ring", cf, { Ring = color }, diameter / 4)
			if r then
				r.Material = Enum.Material.Neon
				return r
			end
			local m = Instance.new("Model")
			for k = 1, 12 do
				local a, b = k * math.pi / 6, (k + 1) * math.pi / 6
				line(m, cf * V(math.cos(a) * diameter / 2, 0, math.sin(a) * diameter / 2), cf * V(math.cos(b) * diameter / 2, 0, math.sin(b) * diameter / 2), diameter * 0.03, color)
			end
			m.Parent = scene
			return m
		end
		local function light(p, color, brightness, range)
			local l = Instance.new("PointLight")
			l.Color, l.Brightness, l.Range, l.Parent = color, brightness, range, p
			return l
		end
		local function set(props) for k, v in props do Lighting[k] = v end end

		-- lightning: jagged main channel + side branches, lives a fraction of a second
		local bolts = {}
		local function bolt(a, b, width, color, life)
			local f = Instance.new("Folder")
			f.Parent = scene
			local len = (b - a).Magnitude
			local prev = a
			for k = 1, 9 do
				local p = k == 9 and b or a:Lerp(b, k / 9) + V(rnd:NextNumber(-1, 1), rnd:NextNumber(-1, 1), rnd:NextNumber(-1, 1)) * len * 0.07
				line(f, prev, p, width, color)
				if k < 9 and rnd:NextNumber() < 0.35 then
					local dir = (V(rnd:NextNumber(-1, 1), rnd:NextNumber(-1, 0.3), rnd:NextNumber(-1, 1))).Unit
					line(f, p, p + dir * len * rnd:NextNumber(0.12, 0.3), width * 0.5, color)
				end
				prev = p
			end
			light(f:FindFirstChildWhichIsA("BasePart"), color, 6, 60)
			table.insert(bolts, { f = f, dies = os.clock() + life })
		end

		-- ===== 1. darkness =====
		local D = O.dark
		local felt = part(V(34, 1, 18), CFrame.new(D + V(0, -1.6, 0)), Color3.fromRGB(16, 92, 60), Enum.Material.Fabric)
		for _, sx in { -1, 1 } do
			part(V(1.4, 1.6, 20), CFrame.new(D + V(sx * 17.7, -1, 0)), Color3.fromRGB(70, 34, 18), Enum.Material.Wood)
			part(V(36.8, 1.6, 1.4), CFrame.new(D + V(0, -1, sx * 9.7)), Color3.fromRGB(70, 34, 18), Enum.Material.Wood)
		end
		local cueBall = part(V(1.9, 1.9, 1.9), CFrame.new(D + V(-8, -0.15, 0)), WHITE, nil, Enum.PartType.Ball)
		local cue = Art.Fallback("Cue15", CFrame.new(D), 1.35) or part(V(0.35, 0.35, 12), CFrame.new(D), Color3.fromRGB(230, 200, 140), Enum.Material.Wood)
		cue.Parent = scene
		local glow = light(cueBall, Color3.fromRGB(150, 200, 255), 0, 30)

		-- ===== 2. hallucination tunnel =====
		local T = O.trip
		local tunnel = {}
		for k = 1, 34 do
			local r = ring(CFrame.new(T + V(0, 0, -k * 9)) * CFrame.Angles(math.pi / 2, 0, 0), 26 - (k % 3) * 3, Color3.fromHSV(k / 34, 0.8, 1))
			tunnel[k] = { r = r, k = k }
		end
		local dream = {}
		for k = 1, 18 do
			local p = part(V(2.6, 2.6, 2.6), CFrame.new(T), Color3.fromHSV(k / 18, 0.7, 1), Enum.Material.Neon, Enum.PartType.Ball)
			dream[k] = p
		end
		local mirror = {}
		for k = 1, 4 do
			local m = BallArt.Make(it, 3)
			m.Parent = scene
			mirror[k] = m
		end

		-- ===== 3. nature =====
		local N = O.nature
		mesh("FinaleNature", CFrame.new(N), nil, 1, function()
			part(V(360, 2, 360), CFrame.new(N + V(0, 5, 0)), Color3.fromRGB(110, 180, 80), Enum.Material.Grass)
			part(V(100, 0.4, 90), CFrame.new(N + V(0, 6.2, 30)), Color3.fromRGB(70, 150, 210), Enum.Material.Glass)
		end)
		local birds = {}
		for k = 1, 7 do
			local body = part(V(0.6, 0.5, 1.6), CFrame.new(N), Color3.fromRGB(40, 40, 48))
			local wings = {}
			for s = 1, 2 do wings[s] = part(V(2.4, 0.12, 0.9), CFrame.new(N), Color3.fromRGB(56, 56, 64)) end
			birds[k] = { body = body, wings = wings, off = V(k * 5 - 20, (k % 3) * 3, (k % 2) * 6) }
		end

		-- ===== 4. city =====
		local Ci = O.city
		mesh("FinaleCity", CFrame.new(Ci), nil, 1, function()
			part(V(320, 1, 320), CFrame.new(Ci + V(0, -0.5, 0)), Color3.fromRGB(46, 48, 56))
			for k = 1, 30 do
				local h = rnd:NextNumber(20, 110)
				part(V(18, h, 18), CFrame.new(Ci + V(rnd:NextInteger(-6, 6) * 22, h / 2, rnd:NextInteger(-6, 6) * 22)), Color3.fromRGB(120, 130, 150))
			end
		end)
		local cars = {}
		for k = 1, 12 do
			local lane = ({ -96, -32, 32, 96 })[k % 4 + 1] + (k % 2 == 0 and 3 or -3)
			local car = part(V(3, 1.6, 6), CFrame.new(Ci), Color3.fromHSV(k / 12, 0.6, 0.9))
			local lamp = part(V(2.4, 0.4, 0.2), CFrame.new(Ci), Color3.fromRGB(255, 240, 200), Enum.Material.Neon)
			cars[k] = { car = car, lamp = lamp, x = lane, z0 = rnd:NextNumber(-150, 150), dir = k % 2 == 0 and 1 or -1, speed = rnd:NextNumber(30, 55) }
		end

		-- ===== 5. the sun =====
		local S = O.sun
		local sun = part(V(220, 220, 220), CFrame.new(S), Color3.fromRGB(255, 196, 70), Enum.Material.Neon, Enum.PartType.Ball)
		local shells = {}
		for k = 1, 2 do
			shells[k] = part(V(1, 1, 1) * (240 + k * 40), CFrame.new(S), Color3.fromRGB(255, 140 - k * 30, 40), Enum.Material.ForceField, Enum.PartType.Ball)
			shells[k].Transparency = 0.2 + k * 0.2
		end
		local corona = {}
		for k = 1, 3 do corona[k] = ring(CFrame.new(S), 300 + k * 50, Color3.fromRGB(255, 170 + k * 20, 60)) end
		local flare = Instance.new("ParticleEmitter")
		flare.Color = ColorSequence.new(Color3.fromRGB(255, 230, 140), Color3.fromRGB(255, 90, 30))
		flare.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 18), NumberSequenceKeypoint.new(1, 60) })
		flare.Transparency = NumberSequence.new(0.2, 1)
		flare.LightEmission, flare.Rate, flare.Lifetime, flare.Speed = 1, 40, NumberRange.new(1.5, 2.5), NumberRange.new(40, 90)
		flare.SpreadAngle, flare.Parent = Vector2.new(180, 180), sun

		-- ===== 6. the computer room =====
		local P = O.room
		part(V(46, 1, 34), CFrame.new(P + V(0, -0.5, 2)), Color3.fromRGB(96, 66, 46), Enum.Material.WoodPlanks)
		part(V(46, 24, 1), CFrame.new(P + V(0, 12, -6)), Color3.fromRGB(44, 46, 70))
		local window = part(V(14, 9, 0.2), CFrame.new(P + V(-12, 13, -5.4)), Color3.fromRGB(20, 30, 80), Enum.Material.Glass)
		window.Transparency = 0.1
		for k = 1, 14 do -- stars in the window
			part(V(0.18, 0.18, 0.05), CFrame.new(P + V(-12 + rnd:NextNumber(-6.5, 6.5), 13 + rnd:NextNumber(-4, 4), -5.25)), WHITE, Enum.Material.Neon)
		end
		mesh("FinaleComputer", CFrame.new(P), nil, 1, function()
			part(V(12, 0.35, 5.5), CFrame.new(P + V(0, 3.2, 0)), Color3.fromRGB(120, 78, 46), Enum.Material.Wood)
			part(V(7.2, 4.3, 0.3), CFrame.new(P + V(0, 6.2, -1.75)), Color3.fromRGB(22, 22, 26))
			part(V(1.6, 4.4, 4.2), CFrame.new(P + V(-4.9, 5.58, -0.3)), Color3.fromRGB(28, 28, 34))
		end)
		local screenPart = part(V(6.8, 3.82, 0.05), CFrame.new(P + V(0, 6.2, -1.54)), Color3.new(), nil, nil)
		screenPart.Transparency = 1
		light(screenPart, Color3.fromRGB(140, 170, 255), 2.2, 22)
		local deskLamp = part(V(0.4, 0.4, 0.4), CFrame.new(P + V(4.5, 9, 1)), Color3.fromRGB(255, 220, 170), Enum.Material.Neon)
		light(deskLamp, Color3.fromRGB(255, 200, 140), 1.2, 18)
		-- the screen: a billiard game, played inside a ViewportFrame on a SurfaceGui
		local sg = Instance.new("SurfaceGui")
		sg.Face, sg.SizingMode, sg.PixelsPerStud, sg.LightInfluence = Enum.NormalId.Back, Enum.SurfaceGuiSizingMode.PixelsPerStud, 110, 0
		sg.Adornee, sg.Parent = screenPart, screenPart
		local bg = Instance.new("Frame")
		bg.Size, bg.BackgroundColor3, bg.BorderSizePixel, bg.Parent = UDim2.fromScale(1, 1), Color3.fromRGB(12, 14, 24), 0, sg
		local bar = Instance.new("TextLabel")
		bar.Size, bar.BackgroundColor3, bar.BorderSizePixel = UDim2.fromScale(1, 0.09), Color3.fromRGB(32, 34, 48), 0
		bar.Text = "  BILLIARD HUNTERS   ·   " .. string.upper(plr.DisplayName) .. " IS PLAYING"
		bar.TextColor3, bar.TextScaled, bar.FontFace, bar.TextXAlignment, bar.Parent = Color3.fromRGB(220, 225, 240), true, C.UI.Font, Enum.TextXAlignment.Left, bg
		local vp = Instance.new("ViewportFrame")
		vp.Size, vp.Position, vp.BackgroundTransparency, vp.Parent = UDim2.fromScale(1, 0.91), UDim2.fromScale(0, 0.09), 1, bg
		vp.Ambient, vp.LightDirection = Color3.fromRGB(190, 190, 210), V(-0.4, -1, -0.3)
		local world = Instance.new("WorldModel")
		world.Parent = vp
		local vcam = Instance.new("Camera")
		vcam.FieldOfView, vcam.CFrame, vcam.Parent = 40, CFrame.lookAt(V(0, 9, 8.5), V(0, 0, 0.6)), vp
		vp.CurrentCamera = vcam
		part(V(12, 0.3, 6.4), CFrame.new(0, 0, 0), Color3.fromRGB(18, 120, 72), Enum.Material.Fabric, nil, world)
		for _, sx in { -1, 1 } do
			part(V(0.5, 0.5, 7.4), CFrame.new(sx * 6.25, 0.2, 0), Color3.fromRGB(96, 48, 22), Enum.Material.Wood, nil, world)
			part(V(13, 0.5, 0.5), CFrame.new(0, 0.2, sx * 3.45), Color3.fromRGB(96, 48, 22), Enum.Material.Wood, nil, world)
		end
		local pockets = {}
		for _, px in { -6, 0, 6 } do
			for _, pz in { -3.2, 3.2 } do
				table.insert(pockets, V(px, 0.2, pz))
				part(V(0.1, 0.7, 0.7), CFrame.new(px, 0.17, pz) * CFrame.Angles(0, 0, math.pi / 2), Color3.new(), nil, Enum.PartType.Cylinder, world)
			end
		end
		local mini = {}
		local miniColors = { Color3.fromRGB(250, 200, 30), Color3.fromRGB(30, 80, 200), Color3.fromRGB(220, 40, 40), Color3.fromRGB(110, 40, 170), Color3.fromRGB(255, 120, 20), Color3.fromRGB(20, 20, 22) }
		for k, col in miniColors do
			local row = k <= 1 and 0 or k <= 3 and 1 or 2
			local idx = k <= 1 and 0 or k <= 3 and k - 2 or k - 4
			local p0 = V(2.4 + row * 0.5, 0.35, (idx - row / 2) * 0.52)
			mini[k] = { p = part(V(0.5, 0.5, 0.5), CFrame.new(p0), col, nil, Enum.PartType.Ball, world), pos = p0, vel = Vector3.zero }
		end
		local prize = BallArt.Make(it, 0.62)
		prize.Parent = world
		local prizeStart, prizeGoal = V(-1.2, 0.36, 0), V(6, 0.36, -3.2)
		local miniCue = part(V(0.12, 0.12, 6), CFrame.new(-6, 0.6, 0), Color3.fromRGB(230, 200, 140), Enum.Material.Wood, nil, world)
		local odds = Instance.new("TextLabel")
		odds.Size, odds.Position, odds.BackgroundTransparency = UDim2.fromScale(0.96, 0.16), UDim2.fromScale(0.02, 0.8), 1
		odds.TextScaled, odds.FontFace, odds.TextColor3, odds.Text, odds.Visible = true, C.UI.Font, C.UI.Title, "", false
		local os_ = Instance.new("UIStroke")
		os_.Thickness, os_.Color, os_.Parent = 3, C.UI.Ink, odds
		odds.Parent = bg

		-- the prize that bursts out of the screen + glass shards
		local reward = BallArt.Make(it, 2.2)
		local sparks = Instance.new("ParticleEmitter")
		sparks.Color, sparks.LightEmission, sparks.Rate = ColorSequence.new(Color3.fromRGB(114, 240, 255), Color3.fromRGB(255, 198, 76)), 1, 30
		sparks.Size, sparks.Transparency = NumberSequence.new(0.25, 0), NumberSequence.new(0.05, 1)
		sparks.Speed, sparks.Lifetime, sparks.SpreadAngle = NumberRange.new(3, 7), NumberRange.new(0.3, 0.7), Vector2.new(180, 180)
		sparks.Parent = reward.PrimaryPart
		local shards = {}

		scene.Parent = workspace
		local short = _G.ShortOnly
		local speed = short and SHORT_SPEED or 1
		local t0 = os.clock()
		local shake, last = 0, 0
		local hit, thunder, shattered, captioned = false, {}, false, false
		local finalL = math.max(1, ctx.luck or 1)
		repeat
			if ctx.skipped() then break end
			local now = os.clock()
			local dt = math.min(now - last, 0.1)
			last = now
			local t = math.min(DURATION, (now - t0) * speed)
			local eye, at, fov = nil, nil, 50

			if t < 3.2 then -- ===== 1. darkness and lightning
				set({ ClockTime = 0, Brightness = 0.1, Ambient = Color3.fromRGB(10, 10, 18), OutdoorAmbient = Color3.fromRGB(8, 8, 14) })
				if atmosphere then atmosphere.Density = 0 end
				cc.Brightness, cc.Contrast, cc.Saturation = -0.15, 0.35, -0.3
				shade.BackgroundTransparency = math.max(0.15, 1 - t / 0.6) -- the world goes dark
				local pull = 1.4 * smooth(seg(t, 0.2, 0.95))
				local thrust = smooth(seg(t, 0.95, 1.12))
				local aim = Vector3.xAxis
				local tip = cueBall.Position - aim * (1.05 + (0.9 + pull) * (1 - thrust))
				local cf = CFrame.fromMatrix(tip - aim * 6.21, Vector3.zAxis, aim)
				if cue:IsA("Model") then -- Art cues are built along their local Y axis
					cue:PivotTo(cf)
					if Art.PoseCue then Art.PoseCue(cue, t, thrust) end
				else
					cue.CFrame = CFrame.lookAt(tip - aim * 6, tip)
				end
				if t >= 1.12 and not hit then
					hit = true
					ctx.sound("Hit")
					shake = 1.4
					flash.BackgroundTransparency = 0.1
				end
				if hit then cueBall.CFrame = CFrame.new(D + V(-8 + 26 * smooth(seg(t, 1.12, 3.2)), -0.15, 0)) * CFrame.Angles(0, 0, -t * 9) end
				glow.Brightness = hit and 4 + math.sin(t * 40) * 2 or pull * 2
				for _, at_ in { 1.15, 1.55, 1.9, 2.3, 2.6, 2.95 } do -- thunder strikes
					if t >= at_ and not thunder[at_] then
						thunder[at_] = true
						local target = cueBall.Position + V(rnd:NextNumber(-6, 6), 0, rnd:NextNumber(-6, 6))
						bolt(target + V(rnd:NextNumber(-10, 10), 46, rnd:NextNumber(-10, 10)), target, 0.45, Color3.fromRGB(190, 220, 255), 0.22)
						bolt(cueBall.Position, cueBall.Position + V(rnd:NextNumber(-14, 14), rnd:NextNumber(2, 10), rnd:NextNumber(-14, 14)), 0.18, Color3.fromRGB(150, 120, 255), 0.18)
						flash.BackgroundTransparency = 0.35
						shake = math.max(shake, 0.8)
						ctx.sound("Break")
					end
				end
				local b = cueBall.Position
				eye, at, fov = b + V(-9 + 4 * smooth(seg(t, 1.1, 3.2)), 4.5, 10), b + V(1, 0, 0), 48 - 8 * smooth(seg(t, 1.1, 3.2))
			elseif t < 6 then -- ===== 2. hallucination
				local u = seg(t, 3.2, 6)
				shade.BackgroundTransparency = 1
				set({ ClockTime = 0, Brightness = 1, Ambient = Color3.fromRGB(90, 60, 120) })
				cc.TintColor = Color3.fromHSV((t * 0.55) % 1, 0.55, 1)
				cc.Saturation, cc.Contrast, cc.Brightness = 0.9, 0.3 + 0.2 * math.sin(t * 9), 0.05
				blur.Size = 6 + 6 * math.sin(t * 5)
				if math.sin(t * 13) > 0.97 then cc.TintColor = Color3.new(1 - cc.TintColor.R, 1 - cc.TintColor.G, 1 - cc.TintColor.B) end -- inverted blink
				local z = -u * 280
				for _, row in tunnel do
					local cf = CFrame.new(T + V(0, 0, -row.k * 9)) * CFrame.Angles(math.pi / 2, t * (row.k % 2 == 0 and 0.8 or -0.8), 0)
					if row.r:IsA("BasePart") then row.r.CFrame = cf else row.r:PivotTo(cf) end
				end
				for k, p in dream do -- balls swirling around the camera's path
					local a = k * 2 * math.pi / #dream + t * 1.7
					p.CFrame = CFrame.new(T + V(math.cos(a) * 7, math.sin(a) * 7, z - 26 - (k % 6) * 4))
				end
				for k, m in mirror do -- the won ball, mirrored four times like a kaleidoscope
					local a = k * math.pi / 2 + t * 1.2
					m:PivotTo(CFrame.new(T + V(math.cos(a) * 3.4, math.sin(a) * 3.4, z - 18)) * CFrame.Angles(t * 2, t * 3, 0))
				end
				eye, at = T + V(0, 0, z), T + V(math.sin(t * 2) * 2, math.cos(t * 1.7) * 2, z - 30)
				fov = 62 + 26 * math.sin(t * 3.1)
				camera.CFrame = CFrame.lookAt(eye, at) * CFrame.Angles(0, 0, t * 0.9)
			elseif t < 9.5 then -- ===== 3. nature
				local u = seg(t, 6, 9.5)
				blur.Size = 0
				set({ ClockTime = 9.5, Brightness = 2.6, Ambient = Color3.fromRGB(120, 120, 130), OutdoorAmbient = Color3.fromRGB(140, 140, 150) })
				cc.TintColor, cc.Saturation, cc.Contrast, cc.Brightness = Color3.fromRGB(255, 248, 236), 0.2, 0.05, 0
				flash.BackgroundTransparency = math.min(flash.BackgroundTransparency, seg(t, 6, 6.6)) -- white cut into the valley
				local e = smooth(u)
				eye = N + V(-150 + 170 * e, 70 - 38 * e, 160 - 120 * e)
				at = N + V(20 * e, 8, 30 - 60 * e)
				for k, b in birds do
					local p = N + V(-60 + 120 * u, 40, 40 - 50 * u) + b.off
					b.body.CFrame = CFrame.lookAt(p, p + V(1, 0, -0.4))
					local flap = math.sin(t * 14 + k) * 0.6
					for s, w in b.wings do
						local side = s == 1 and 1 or -1
						w.CFrame = b.body.CFrame * CFrame.Angles(0, 0, side * flap) * CFrame.new(side * 1.3, 0, 0)
					end
				end
				fov = 55
			elseif t < 13 then -- ===== 4. city at dusk
				local u = seg(t, 9.5, 13)
				set({ ClockTime = 18.2, Brightness = 1.6, Ambient = Color3.fromRGB(110, 80, 110), OutdoorAmbient = Color3.fromRGB(130, 90, 120) })
				cc.TintColor, cc.Saturation, cc.Contrast = Color3.fromRGB(255, 205, 175), 0.3, 0.12
				flash.BackgroundTransparency = math.min(flash.BackgroundTransparency, seg(t, 9.5, 10.1))
				for _, c in cars do
					local z = (c.z0 + c.dir * c.speed * t) % 300 - 150
					local cf = CFrame.lookAt(Ci + V(c.x, 1.2, z), Ci + V(c.x, 1.2, z + c.dir))
					c.car.CFrame, c.lamp.CFrame = cf, cf * CFrame.new(0, 0.1, -3.05)
				end
				local dolly = smooth(seg(t, 9.5, 11.8))
				local crane = smooth(seg(t, 11.4, 13))
				eye = Ci + V(-32, 16 + 120 * crane, 140 - 220 * dolly + 40 * crane)
				at = Ci + V(-32 + 40 * crane, 22 + 30 * crane, 60 - 220 * dolly - 60 * crane)
				fov = 60 - 10 * crane
			elseif t < 16 then -- ===== 5. into the sun
				local u = seg(t, 13, 16)
				set({ ClockTime = 12, Brightness = 3, Ambient = Color3.fromRGB(200, 160, 120) })
				cc.TintColor, cc.Saturation, cc.Contrast, cc.Brightness = Color3.fromRGB(255, 225, 180), 0.35, 0.1, 0.25 * u
				flash.BackgroundTransparency = math.min(1, 1 - smooth(seg(t, 15.3, 16))) -- white-out
				for k, s in shells do s.CFrame = CFrame.new(S) * CFrame.Angles(0, t * 0.3 * k, 0) end
				for k, r in corona do
					local cf = CFrame.new(S) * CFrame.Angles(0.5 * k + t * 0.2, t * 0.15 * k, 0.3 * k)
					if r:IsA("BasePart") then r.CFrame = cf else r:PivotTo(cf) end
				end
				sun.Size = V(220, 220, 220) * (1 + 0.03 * math.sin(t * 6))
				eye, at = S + V(0, 40 - 30 * u, 900 - 700 * smooth(u)), S
				fov = 55 - 15 * u
				shake = math.max(shake, 0.25 * u)
			else -- ===== 6. the computer
				local u = t - 16
				set({ ClockTime = 0, Brightness = 0.4, Ambient = Color3.fromRGB(50, 50, 70), OutdoorAmbient = Color3.fromRGB(40, 40, 60) })
				cc.TintColor, cc.Saturation, cc.Contrast, cc.Brightness = WHITE, 0.15, 0.08, 0
				if u < 0.8 then flash.BackgroundTransparency = smooth(u / 0.8) end
				-- the game on the screen
				local pull = 0.8 * smooth(seg(u, 0, 0.6)) * (1 - smooth(seg(u, 0.6, 0.75)))
				miniCue.CFrame = CFrame.lookAt(prizeStart - V(3.4 + pull, -0.25, 0), prizeStart)
				local roll = smooth(seg(u, 0.75, 2.7))
				local sink = seg(u, 2.6, 2.95)
				prize:PivotTo(CFrame.new(prizeStart:Lerp(prizeGoal, roll) - V(0, 0.5 * sink, 0)) * CFrame.Angles(0, 0, -roll * 20))
				if u >= 0.75 and mini[1].vel.Magnitude == 0 and not mini.broke then -- break: rack balls fly apart
					mini.broke = true
					for k, b in mini do
						if type(k) == "number" then b.vel = V(rnd:NextNumber(1, 5), 0, rnd:NextNumber(-4, 4)) end
					end
				end
				for k, b in mini do
					if type(k) == "number" then
						b.vel *= math.max(0, 1 - 1.3 * dt)
						local p = b.pos + b.vel * dt
						if math.abs(p.X) > 5.75 then b.vel = V(-b.vel.X, 0, b.vel.Z); p = V(math.sign(p.X) * 5.75, p.Y, p.Z) end
						if math.abs(p.Z) > 2.95 then b.vel = V(b.vel.X, 0, -b.vel.Z); p = V(p.X, p.Y, math.sign(p.Z) * 2.95) end
						b.pos = p
						b.p.CFrame = CFrame.new(p)
					end
				end
				if u >= 2.95 then -- the recount runs on the screen: 1 in 1, 1 in 2 ... 1 in <final luck>
					local e = seg(u, 2.95, 4.5)
					odds.Visible = true
					odds.Text = "1 in " .. C.FullNumber(e >= 1 and finalL or finalL ^ (1 - (1 - e) ^ 3))
					odds.TextColor3 = e >= 1 and WHITE or C.UI.Title
				end
				-- camera: wide on the desk, then push into the monitor; the glass breaks and the ball flies out
				local push = smooth(seg(u, 3.9, 4.9))
				local screen = screenPart.Position
				eye = (P + V(9, 9.5, 15)):Lerp(screen + V(0, 0, 2.2), push)
				at = (P + V(0, 5.6, -1)):Lerp(screen, push)
				fov = 50 - 12 * push
				if u >= 4.9 and not shattered then
					shattered = true
					ctx.sound("Cushion")
					ctx.sound("Reward")
					shake = 1.2
					flash.BackgroundTransparency = 0.2
					sg.Enabled = false
					for k = 1, 26 do
						local s = part(V(rnd:NextNumber(0.4, 1.2), rnd:NextNumber(0.4, 1.2), 0.05), CFrame.new(screen + V(rnd:NextNumber(-3, 3), rnd:NextNumber(-1.7, 1.7), 0.1)), Color3.fromRGB(190, 220, 255), Enum.Material.Glass)
						s.Transparency = 0.3
						shards[k] = { p = s, v = V(rnd:NextNumber(-6, 6), rnd:NextNumber(-2, 6), rnd:NextNumber(6, 16)), r = V(rnd:NextNumber(-6, 6), rnd:NextNumber(-6, 6), rnd:NextNumber(-6, 6)) }
					end
					reward.Parent = scene
					if ctx.odds then closeOdds = ctx.odds(finalL, 0.9) end
				end
				for _, s in shards do
					s.v += V(0, -18, 0) * dt
					s.p.CFrame = (s.p.CFrame + s.v * dt) * CFrame.Angles(s.r.X * dt, s.r.Y * dt, s.r.Z * dt)
				end
				if shattered then
					local fly = smooth(seg(u, 4.9, 5.8))
					reward:PivotTo(CFrame.new(screen:Lerp(eye + (at - eye).Unit * 6, fly)) * CFrame.Angles(0.2, t * 2.2, 0))
					if u >= 5.6 and not captioned then
						captioned = true
						ctx.caption()
					end
				end
			end
			-- remove dead lightning, apply camera + shake
			for k = #bolts, 1, -1 do
				if os.clock() > bolts[k].dies then
					bolts[k].f:Destroy()
					table.remove(bolts, k)
				end
			end
			flash.BackgroundTransparency = math.min(1, flash.BackgroundTransparency + dt * 2.2)
			if eye and not (t >= 3.2 and t < 6) then camera.CFrame = CFrame.lookAt(eye, at) end
			camera.FieldOfView = fov
			if shake > 0.01 then
				camera.CFrame *= CFrame.new(rnd:NextNumber(-1, 1) * shake * 0.3, rnd:NextNumber(-1, 1) * shake * 0.3, 0) * CFrame.Angles(0, 0, rnd:NextNumber(-1, 1) * shake * 0.02)
				shake *= math.max(0, 1 - dt * 4)
			end
			if t >= DURATION then break end
			Run.RenderStepped:Wait()
		until false
	end

	local ok, err = xpcall(run, debug.traceback)
	if closeOdds then closeOdds() end
	scene:Destroy()
	gui:Destroy()
	cc:Destroy()
	blur:Destroy()
	for k, v in saved do Lighting[k] = v end
	if atmosphere then atmosphere.Density = atmoDensity end
	if not ok then warn("Grand finale:", err) end
	return ok
end
