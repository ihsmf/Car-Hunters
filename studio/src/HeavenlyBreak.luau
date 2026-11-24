-- CUE HUNTERS grand finale of the last table (~24 s, ~10 s with "short cinematics", Skip works). Real-time scenes far
-- from the map, models from Blender (Shared/Meshes: God* (blender/god.py, textured), FinalePlanet, FinaleComputer, FinaleRobloxPlanet):
--   1 the god of billiards: clouds, his eyes ignite, wind-up, he strikes with the Legend cue 0 - 5 s (+1.5 s, later
--     stages are timed without it)
--   2 the ball flies through space into a super-planet                                     3.5 - 6 s
--   3 the planet explodes (chunks, shock wave, burning core)                               6 - 8 s
--   4 the camera plunges into the core                                                     8 - 9.2 s
--   5 inside: a computer plays the game, the screen glitches, the black silhouette with
--     white edges of the mightiest ball appears, "1 in N", the ball breaks the screen       9.2 - 15 s
--   6 the ball bursts out of the core and the debris                                       15 - 17 s
--   7 it streaks towards the home planet, atmosphere entry                                17 - 20 s
--   8 back at the long table: the ball lands in front of the player, super aura           20 - 24 s
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

local DURATION, SHORT_SPEED = 24, 2.3
local O = { -- scene origins, far away from the map and from each other
	god = V(6000, 600, 0), space = V(7200, 600, -900), room = V(6000, 600, -4600), home = V(6000, 900, -2600),
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
		local ringBase = {}
		local function grow(r, cf, k, fade) -- scale a ring() around its centre (MeshPart or block model)
			if r:IsA("BasePart") then
				ringBase[r] = ringBase[r] or r.Size
				r.Size, r.CFrame, r.Transparency = ringBase[r] * k, cf, fade
			else
				r:ScaleTo(math.max(0.01, k))
				r:PivotTo(cf)
			end
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

		-- ===== 1. the god of billiards (blender/god.py: textured GodTemple / GodBody / GodHead / GodArmR / GodArmL) =====
		local G = O.god
		mesh("GodTemple", CFrame.new(G), nil, 1, function()
			part(V(48, 3.4, 48), CFrame.new(G + V(0, 1.7, 0)), Color3.fromRGB(240, 238, 232), Enum.Material.Marble, Enum.PartType.Cylinder)
		end)
		for k = 1, 16 do -- a sea of clouds around the temple
			local a = k * math.pi / 8
			local d = rnd:NextNumber(30, 70)
			part(V(1, 0.55, 1) * rnd:NextNumber(18, 34), CFrame.new(G + V(math.cos(a) * d, rnd:NextNumber(-6, 0), math.sin(a) * d)), Color3.fromRGB(244, 246, 255), nil, Enum.PartType.Ball)
		end
		local rays = {}
		for k = 1, 7 do -- god rays falling on the temple
			local r = part(V(rnd:NextNumber(3, 6), 140, rnd:NextNumber(3, 6)), CFrame.new(G), Color3.fromRGB(255, 236, 180), Enum.Material.Neon)
			r.Transparency = 0.82
			rays[k] = { p = r, a = k * 0.9, d = rnd:NextNumber(4, 20) }
		end
		local FEET = G + V(0, 3.36, 0) -- the god stands on the top step
		local GOD = { -- studs, relative to the feet (Roblox axes), from blender/god.py (SCALE 3.2)
			shoulderR = V(0, 19.68, 3.456), shoulderL = V(0, 19.68, -3.456), neck = V(0.26, 22.4, 0),
			handR = V(1.984, 16.0, 1.024), handL = V(5.6, 17.024, -0.32), eyes = { V(1.376, 24.1, -0.544), V(1.376, 24.1, 0.544) },
		}
		local function godPiece(name, at, size, color) -- { obj, offset of obj from the piece's origin }
			local origin = CFrame.new(FEET + at)
			local m = mesh(name, origin, nil, 1, nil) or part(size, CFrame.new(FEET + at + V(0, size.Y / 2, 0)), color)
			local cf = m:IsA("BasePart") and m.CFrame or m:GetPivot()
			return { obj = m, off = origin:ToObjectSpace(cf) }
		end
		local godBody = godPiece("GodBody", V(), V(8, 22, 8), Color3.fromRGB(246, 242, 232))
		local godHead = godPiece("GodHead", V(), V(3.4, 4, 3.4), Color3.fromRGB(232, 184, 150))
		local godArmR = godPiece("GodArmR", GOD.shoulderR, V(1.5, 1.5, 6), Color3.fromRGB(232, 184, 150))
		local godArmL = godPiece("GodArmL", GOD.shoulderL, V(1.5, 1.5, 6), Color3.fromRGB(232, 184, 150))
		local godEyes = {}
		for k, e in GOD.eyes do
			godEyes[k] = part(V(0.32, 0.32, 0.32), CFrame.new(FEET + e), Color3.fromRGB(255, 214, 90), Enum.Material.Neon, Enum.PartType.Ball)
			godEyes[k].Transparency = 1
		end
		local eyeLight = light(godEyes[1], Color3.fromRGB(255, 210, 120), 0, 26)
		local CUE_DIR = (GOD.handL - GOD.handR).Unit
		local BALL0 = FEET + GOD.handL + CUE_DIR * 7
		local cueBall = part(V(1.9, 1.9, 1.9), CFrame.new(BALL0), WHITE, nil, Enum.PartType.Ball)
		local CS = 2 -- the Legend cue, twice the normal size in the god's hands
		local cue = Art.Fallback("Cue" .. #C.Cues, CFrame.new(G), CS) or part(V(0.5, 0.5, 18), CFrame.new(G), Color3.fromRGB(255, 220, 120), Enum.Material.Neon)
		cue.Parent = scene
		-- pose(lean, push, look): lean rotates the god about his feet (+ back / - forward), push slides arms + cue
		-- along the cue line, look turns the head (radians, + towards the camera side)
		local function pose(lean, push, look)
			local root = CFrame.new(FEET) * CFrame.Angles(0, 0, lean)
			local function place(piece, cf)
				local obj = piece.obj
				if obj:IsA("BasePart") then obj.CFrame = cf * piece.off else obj:PivotTo(cf * piece.off) end
			end
			place(godBody, root)
			local neck = root * CFrame.new(GOD.neck) * CFrame.Angles(0, look, 0) * CFrame.new(-GOD.neck)
			place(godHead, neck)
			local slide = CUE_DIR * push
			place(godArmR, root * CFrame.new(GOD.shoulderR + slide * 0.6))
			place(godArmL, root * CFrame.new(GOD.shoulderL + slide * 0.6))
			for k, e in godEyes do e.CFrame = neck * CFrame.new(GOD.eyes[k]) end
			local tip = root * (GOD.handL + CUE_DIR * 4 + slide)
			local aim = root:VectorToWorldSpace(CUE_DIR)
			local cf = CFrame.fromMatrix(tip - aim * 4.6 * CS, aim:Cross(Vector3.yAxis).Unit, aim)
			if cue:IsA("Model") then cue:PivotTo(cf) else cue.CFrame = CFrame.lookAt(tip - aim * 9, tip) end
			return tip, aim
		end
		pose(0, 0, 0)
		local glow = light(cueBall, Color3.fromRGB(255, 230, 160), 0, 40)
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position, a0.Parent, a1.Parent = V(0, 0.8, 0), V(0, -0.8, 0), cueBall, cueBall
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1, trail.LightEmission, trail.Lifetime = a0, a1, 1, 0.5
		trail.Color, trail.Transparency, trail.Parent = ColorSequence.new(WHITE, Color3.fromRGB(255, 200, 90)), NumberSequence.new(0, 1), cueBall

		-- ===== 2-4. the super-planet, its explosion and core =====
		local PL = O.space
		local planet
		planet = mesh("FinalePlanet", CFrame.new(PL), nil, 1, function()
			planet = part(V(120, 120, 120), CFrame.new(PL), Color3.fromRGB(120, 70, 160), nil, Enum.PartType.Ball)
		end) or planet
		local core = part(V(36, 36, 36), CFrame.new(PL), Color3.fromRGB(255, 120, 40), Enum.Material.Neon, Enum.PartType.Ball)
		light(core, Color3.fromRGB(255, 140, 60), 8, 120)
		local SPACE0 = PL + V(-700, 50, 120)
		local IMPACT = PL + V(-58, 6, 6)
		local streaks = {}
		for k = 1, 26 do -- speed lines around the camera during the flight
			streaks[k] = { p = part(V(0.12, 0.12, 14), CFrame.new(SPACE0), WHITE, Enum.Material.Neon), off = V(rnd:NextNumber(-9, 9), rnd:NextNumber(-6, 6), rnd:NextNumber(0, 60)) }
		end
		local chunks, wave = {}, nil
		local tunnel = {}
		for k = 1, 10 do -- fire rings on the dive into the core
			tunnel[k] = ring(CFrame.new(PL + V(-150 + k * 12, 0, 0)) * CFrame.Angles(0, 0, math.pi / 2), 26 - k, Color3.fromRGB(255, 120 + k * 10, 40))
		end

		-- ===== 7. the home planet =====
		local HP = O.home
		mesh("FinaleRobloxPlanet", CFrame.new(HP), nil, 1, function()
			part(V(90, 90, 90), CFrame.new(HP), Color3.fromRGB(50, 120, 220), nil, Enum.PartType.Ball)
		end)
		local comet = part(V(5, 5, 5), CFrame.new(HP + V(-400, 0, 0)), Color3.fromRGB(255, 245, 220), Enum.Material.Neon, Enum.PartType.Ball)
		light(comet, Color3.fromRGB(255, 210, 140), 6, 60)
		local fire = Instance.new("ParticleEmitter")
		fire.Color = ColorSequence.new(Color3.fromRGB(255, 240, 180), Color3.fromRGB(255, 90, 30))
		fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 10) })
		fire.Transparency, fire.LightEmission, fire.Rate = NumberSequence.new(0.1, 1), 1, 120
		fire.Lifetime, fire.Speed, fire.SpreadAngle = NumberRange.new(0.3, 0.6), NumberRange.new(2, 6), Vector2.new(25, 25)
		fire.Parent = comet

		-- ===== 6. the computer room =====
		local P = O.room
		part(V(46, 1, 34), CFrame.new(P + V(0, -0.5, 2)), Color3.fromRGB(96, 66, 46), Enum.Material.WoodPlanks)
		part(V(46, 24, 1), CFrame.new(P + V(0, 12, -6)), Color3.fromRGB(44, 46, 70))
		local window = part(V(14, 9, 0.2), CFrame.new(P + V(-12, 13, -5.4)), Color3.fromRGB(255, 110, 40), Enum.Material.Neon) -- the burning core outside
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
		bar.Text = "  CUE HUNTERS   ·   " .. string.upper(plr.DisplayName) .. " IS PLAYING"
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
		local glitch = {} -- RGB tear bars for the glitch
		for k = 1, 14 do
			local f = Instance.new("Frame")
			f.BorderSizePixel, f.Visible, f.ZIndex = 0, false, 5
			f.BackgroundColor3 = ({ Color3.fromRGB(255, 40, 80), Color3.fromRGB(40, 255, 160), Color3.fromRGB(60, 120, 255), WHITE, Color3.new() })[k % 5 + 1]
			f.Parent = bg
			glitch[k] = f
		end
		local silhouette = Instance.new("Frame") -- the mightiest ball: black disc with a white rim and glow
		silhouette.AnchorPoint, silhouette.Position, silhouette.BackgroundColor3 = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.45), Color3.new()
		silhouette.Visible, silhouette.ZIndex, silhouette.Parent = false, 4, bg
		local square = Instance.new("UIAspectRatioConstraint")
		square.AspectRatio, square.Parent = 1, silhouette
		local corner_ = Instance.new("UICorner")
		corner_.CornerRadius, corner_.Parent = UDim.new(1, 0), silhouette
		local rim = Instance.new("UIStroke")
		rim.Color, rim.Thickness, rim.Parent = WHITE, 5, silhouette
		local auraTitle = Instance.new("TextLabel") -- big caption when the ball reaches the player
		auraTitle.Size, auraTitle.Position, auraTitle.BackgroundTransparency = UDim2.fromScale(0.9, 0.09), UDim2.fromScale(0.05, 0.72), 1
		auraTitle.Text, auraTitle.TextScaled, auraTitle.FontFace, auraTitle.TextColor3 = "SUPER AURA UNLOCKED", true, C.UI.Font, WHITE
		auraTitle.Visible, auraTitle.TextTransparency, auraTitle.Parent = false, 1, gui
		local auraStroke = Instance.new("UIStroke")
		auraStroke.Thickness, auraStroke.Color, auraStroke.Parent = 4, C.UI.Ink, auraTitle
		local auraGrad = Instance.new("UIGradient")
		auraGrad.Color, auraGrad.Parent = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)), ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 80)), ColorSequenceKeypoint.new(0.66, Color3.fromRGB(90, 230, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 110, 255)) }), auraTitle

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
		local stage, glitched, landedFx, auraFx = 1, false, false, false
		local finalL = math.max(1, ctx.luck or 1)
		repeat
			if ctx.skipped() then break end
			local now = os.clock()
			local dt = math.min(now - last, 0.1)
			last = now
			local t = math.min(DURATION + 1.5, (now - t0) * speed) -- + the 1.5 s god scene
			local eye, at, fov = nil, nil, 50

			local function cut(color) -- a hard cut between shots
				flash.BackgroundColor3, flash.BackgroundTransparency = color or WHITE, 0
				trail:Clear()
			end
			if t < 5 then -- ===== 1. the god of billiards: clouds, his eyes ignite, the wind-up, the strike
				set({ ClockTime = 14, Brightness = 3, Ambient = Color3.fromRGB(200, 190, 160), OutdoorAmbient = Color3.fromRGB(220, 210, 180) })
				if atmosphere then atmosphere.Density = 0 end
				cc.TintColor, cc.Saturation, cc.Contrast, cc.Brightness = Color3.fromRGB(255, 238, 205), 0.15, 0.12, 0.02
				shade.BackgroundTransparency = math.max(shade.BackgroundTransparency, smooth(seg(t, 0, 0.6))) -- out of black
				for k, r in rays do -- slowly sweeping god rays
					local a = r.a + t * 0.15
					r.p.CFrame = CFrame.new(FEET + V(math.cos(a) * r.d, 40, math.sin(a) * r.d)) * CFrame.Angles(0.35 * math.sin(a), 0, 0.3 * math.cos(a))
				end
				local look = 0.45 * smooth(seg(t, 1.6, 2.1)) * (1 - smooth(seg(t, 2.6, 3.0))) -- turns to the camera, then to the ball
				local wind = smooth(seg(t, 2.6, 3.4)) -- lean back + draw the cue
				local strike = smooth(seg(t, 3.4, 3.55))
				local lean = 0.07 * wind * (1 - strike) - 0.1 * strike
				local tip = pose(lean, -3 * wind * (1 - strike) + 3.5 * strike, look)
				local ignite = smooth(seg(t, 1.9, 2.15))
				for _, e in godEyes do e.Transparency = 1 - ignite end
				eyeLight.Brightness = 6 * ignite
				if t >= 1.9 and not thunder.eyes then
					thunder.eyes = true
					ctx.sound("Reward")
					flash.BackgroundColor3, flash.BackgroundTransparency = Color3.fromRGB(255, 230, 160), 0.55
				end
				if t >= 2.7 and t < 3.4 and rnd:NextNumber() < 0.25 then -- lightning gathers at the cue tip
					bolt(tip + V(rnd:NextNumber(-16, 16), rnd:NextNumber(10, 30), rnd:NextNumber(-16, 16)), tip, 0.25, Color3.fromRGB(255, 240, 190), 0.12)
				end
				if t >= 3.55 and not hit then
					hit = true
					ctx.sound("Hit")
					ctx.sound("Break")
					shake = 1.8
					flash.BackgroundColor3, flash.BackgroundTransparency = WHITE, 0.05
					for _ = 1, 3 do bolt(G + V(rnd:NextNumber(-20, 20), 90, rnd:NextNumber(-20, 20)), cueBall.Position, 0.5, Color3.fromRGB(255, 240, 190), 0.25) end
				end
				local fly = smooth(seg(t, 3.55, 5)) ^ 1.6
				cueBall.CFrame = CFrame.new(BALL0 + CUE_DIR * (180 * fly) + V(0, 10 * fly, 0)) * CFrame.Angles(0, 0, -t * 12)
				glow.Brightness = hit and 6 or wind * 3
				local face = FEET + GOD.neck + V(0, 1.6, 0)
				if t < 1.6 then -- rising through the clouds towards the temple
					local u = smooth(seg(t, 0, 1.6))
					eye, at, fov = G + V(70 - 30 * u, -8 + 24 * u, 60 - 30 * u), FEET + V(0, 14 + 4 * u, 0), 55
				elseif t < 2.6 then -- push in on his face: the eyes ignite
					local u = smooth(seg(t, 1.6, 2.6))
					eye, at, fov = face + V(14 - 5 * u, 1, 7 - 2 * u), face, 40 - 8 * u
				elseif t < 3.55 then -- side view of the wind-up and the strike
					eye, at, fov = FEET + V(10, 16, 34), FEET + V(6, 15, 0), 55
				else -- chase the ball
					local b = cueBall.Position
					eye, at, fov = b - CUE_DIR * 12 + V(0, 3, 7), b + CUE_DIR * 4, 60 + 20 * fly
				end
			else
			t -= 1.5 -- the rest of the film is timed after the god scene
			if t < 6 then -- ===== 2. the ball flies through space into the super-planet
				if stage ~= 2 then stage = 2; cut() end
				set({ ClockTime = 0, Brightness = 0, Ambient = Color3.fromRGB(30, 30, 60), OutdoorAmbient = Color3.fromRGB(20, 20, 40) })
				cc.TintColor, cc.Saturation, cc.Contrast, cc.Brightness = Color3.fromRGB(220, 225, 255), 0.25, 0.15, 0
				local e = seg(t, 3.5, 6) ^ 2
				local b = SPACE0:Lerp(IMPACT, e)
				cueBall.CFrame = CFrame.new(b)
				local dir = (IMPACT - SPACE0).Unit
				eye = b - dir * 14 + V(0, 3.5, 0)
				at = b:Lerp(PL, 0.15 + 0.5 * e)
				fov = 70 + 25 * e
				for _, s in streaks do -- speed lines rush past the camera
					local z = (s.off.Z - t * 160) % 60
					local p = eye + dir * (z - 10) + V(s.off.X, s.off.Y, 0)
					s.p.CFrame = CFrame.lookAt(p, p + dir)
				end
				shake = math.max(shake, 0.2 + 0.5 * e)
			elseif t < 8 then -- ===== 3. the planet explodes
				if stage ~= 3 then
					stage = 3
					cut(Color3.fromRGB(255, 240, 220))
					ctx.sound("Break")
					ctx.sound("Pocket")
					shake = 2.2
					cueBall.Transparency = 1
					for _, s in streaks do s.p.Transparency = 1 end
					if planet then
						for _, d in (planet:IsA("BasePart") and { planet } or {}) do d.Transparency = 1 end
						for _, d in planet:GetDescendants() do if d:IsA("BasePart") then d.Transparency = 1 end end
					end
					local cols = { Color3.fromRGB(120, 70, 160), Color3.fromRGB(200, 110, 190), Color3.fromRGB(70, 40, 120), Color3.fromRGB(255, 150, 60) }
					for k = 1, 60 do
						local d = V(rnd:NextNumber(-1, 1), rnd:NextNumber(-1, 1), rnd:NextNumber(-1, 1)).Unit
						local sz = rnd:NextNumber(6, 18)
						local c = part(V(sz, sz * rnd:NextNumber(0.5, 1), sz * rnd:NextNumber(0.5, 1)), CFrame.new(PL + d * 52), cols[k % 4 + 1], k % 4 == 3 and Enum.Material.Neon or Enum.Material.Basalt)
						chunks[k] = { p = c, v = d * rnd:NextNumber(50, 150), r = V(rnd:NextNumber(-2, 2), rnd:NextNumber(-2, 2), rnd:NextNumber(-2, 2)) }
					end
					wave = ring(CFrame.new(PL), 130, Color3.fromRGB(255, 220, 170))
				end
				local u = seg(t, 6, 8)
				for _, c in chunks do
					c.p.CFrame = (c.p.CFrame + c.v * dt) * CFrame.Angles(c.r.X * dt, c.r.Y * dt, c.r.Z * dt)
				end
				if wave then grow(wave, CFrame.new(PL) * CFrame.Angles(0.3, 0, 0.2), (130 + 900 * smooth(u)) / 130, u) end
				core.Size = V(36, 36, 36) * (1 + 0.15 * math.sin(t * 20))
				set({ ClockTime = 0, Brightness = 0.5, Ambient = Color3.fromRGB(120, 70, 50) })
				cc.TintColor, cc.Contrast = Color3.fromRGB(255, 220, 200), 0.2
				eye, at, fov = PL + V(-300 - 120 * u, 70, 210 + 60 * u), PL, 62
			elseif t < 9.2 then -- ===== 4. the camera plunges into the burning core
				local u = smooth(seg(t, 8, 9.2))
				eye, at, fov = (PL + V(-160, 4, 0)):Lerp(PL + V(-6, 0, 0), u), PL, 70 + 40 * u
				for k, r in tunnel do
					local cf = CFrame.new(PL + V(-150 + k * 12, 0, 0)) * CFrame.Angles(t * (k % 2 == 0 and 2 or -2), 0, math.pi / 2)
					if r:IsA("BasePart") then r.CFrame = cf else r:PivotTo(cf) end
				end
				for _, c in chunks do c.p.CFrame += c.v * dt end
				cc.TintColor, cc.Saturation = Color3.fromRGB(255, 190, 140), 0.4
				shake = math.max(shake, 0.5)
				if t > 9.0 then flash.BackgroundColor3, flash.BackgroundTransparency = Color3.fromRGB(255, 150, 60), 0 end
			elseif t < 15 then -- ===== 5. inside the core: the computer, the glitch, the silhouette
				if stage ~= 5 then stage = 5; cut(Color3.fromRGB(255, 150, 60)) end
				local u = t - 9.2
				set({ ClockTime = 0, Brightness = 0.4, Ambient = Color3.fromRGB(110, 50, 30), OutdoorAmbient = Color3.fromRGB(80, 40, 30) })
				cc.TintColor, cc.Saturation, cc.Contrast, cc.Brightness = Color3.fromRGB(255, 225, 205), 0.15, 0.1, 0
				-- the game on the screen
				local pull = 0.8 * smooth(seg(u, 0, 0.6)) * (1 - smooth(seg(u, 0.6, 0.75)))
				miniCue.CFrame = CFrame.lookAt(prizeStart - V(3.4 + pull, -0.25, 0), prizeStart)
				local roll = smooth(seg(u, 0.75, 2.4))
				local sink = seg(u, 2.3, 2.6)
				prize:PivotTo(CFrame.new(prizeStart:Lerp(prizeGoal, roll) - V(0, 0.5 * sink, 0)) * CFrame.Angles(0, 0, -roll * 20))
				if u >= 0.75 and not mini.broke then
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
				-- glitch: the picture tears into colour bars, jumps and blinks
				local g = u >= 2.7 and u < 3.9
				for _, f in glitch do
					f.Visible = g and rnd:NextNumber() < 0.45
					if f.Visible then
						f.Position = UDim2.fromScale(rnd:NextNumber(-0.2, 0.9), rnd:NextNumber(0, 0.95))
						f.Size = UDim2.fromScale(rnd:NextNumber(0.2, 0.9), rnd:NextNumber(0.02, 0.12))
					end
				end
				vp.Position = g and UDim2.fromScale(0.02 * rnd:NextNumber(-1, 1), 0.09 + 0.02 * rnd:NextNumber(-1, 1)) or UDim2.fromScale(0, 0.09)
				vp.Visible = u < 3.6 or u >= 4.6
				if g and not glitched then
					glitched = true
					ctx.sound("Cushion")
				end
				if g then shake = math.max(shake, 0.4) end
				-- the silhouette of the mightiest ball: black with white edges, growing on the screen
				if u >= 3.5 then
					local e = smooth(seg(u, 3.5, 4.3))
					silhouette.Visible = true
					silhouette.Size = UDim2.fromScale(0.12 + 0.36 * e, (0.12 + 0.36 * e) * 1.78)
					rim.Thickness = 4 + 3 * math.sin(u * 18)
				end
				if u >= 3.8 then -- the recount runs under it: 1 in 1, 1 in 2 ... 1 in <final luck>
					local e = seg(u, 3.8, 5)
					odds.Visible = true
					odds.Text = "1 in " .. C.FullNumber(e >= 1 and finalL or finalL ^ (1 - (1 - e) ^ 3))
					odds.TextColor3 = e >= 1 and WHITE or C.UI.Title
				end
				-- camera: wide on the desk, then push into the monitor; the glass breaks and the ball flies out
				local push = smooth(seg(u, 4.4, 5.2))
				local screen = screenPart.Position
				eye = (P + V(9, 9.5, 15)):Lerp(screen + V(0, 0, 2.2), push)
				at = (P + V(0, 5.6, -1)):Lerp(screen, push)
				fov = 50 - 12 * push
				if u >= 5.2 and not shattered then
					shattered = true
					ctx.sound("Cushion")
					ctx.sound("Reward")
					shake = 1.2
					flash.BackgroundColor3, flash.BackgroundTransparency = WHITE, 0.2
					sg.Enabled = false
					for k = 1, 26 do
						local s = part(V(rnd:NextNumber(0.4, 1.2), rnd:NextNumber(0.4, 1.2), 0.05), CFrame.new(screen + V(rnd:NextNumber(-3, 3), rnd:NextNumber(-1.7, 1.7), 0.1)), Color3.fromRGB(190, 220, 255), Enum.Material.Glass)
						s.Transparency = 0.3
						shards[k] = { p = s, v = V(rnd:NextNumber(-6, 6), rnd:NextNumber(-2, 6), rnd:NextNumber(6, 16)), r = V(rnd:NextNumber(-6, 6), rnd:NextNumber(-6, 6), rnd:NextNumber(-6, 6)) }
					end
					reward.Parent = scene
				end
				for _, s in shards do
					s.v += V(0, -18, 0) * dt
					s.p.CFrame = (s.p.CFrame + s.v * dt) * CFrame.Angles(s.r.X * dt, s.r.Y * dt, s.r.Z * dt)
				end
				if shattered then
					local fly = smooth(seg(u, 5.2, 5.8))
					reward:PivotTo(CFrame.new(screen:Lerp(eye + (at - eye).Unit * 3, fly)) * CFrame.Angles(0.2, t * 2.2, 0))
				end
			elseif t < 17 then -- ===== 6. the ball bursts out of the core and the planet's debris
				if stage ~= 6 then
					stage = 6
					cut()
					reward.Parent = nil
					for _, c in chunks do c.p.CFrame = CFrame.new(PL + (c.p.Position - PL).Unit * 140) end
					ctx.sound("Hit")
				end
				local u = seg(t, 15, 17)
				for _, c in chunks do c.p.CFrame = (c.p.CFrame + c.v * dt * 0.3) * CFrame.Angles(c.r.X * dt, c.r.Y * dt, 0) end
				local p = PL:Lerp(PL + V(-600, 90, -260), smooth(u) ^ 1.4)
				comet.CFrame = CFrame.new(p)
				comet.Size = V(5, 5, 5)
				fire.Enabled = true
				eye, at, fov = PL + V(-120, 40, 150), p, 60
				set({ ClockTime = 0, Brightness = 0.3, Ambient = Color3.fromRGB(110, 60, 50) })
			elseif t < 20 then -- ===== 7. the ball streaks towards the home planet
				if stage ~= 7 then stage = 7; cut() end
				local u = seg(t, 17, 20)
				local from, to = HP + V(-420, 60, 40), HP + V(-46, 4, 0)
				local p = from:Lerp(to, smooth(u) ^ 1.3)
				comet.CFrame = CFrame.new(p)
				fire.Rate = 120 + 400 * u -- atmosphere entry
				eye, at, fov = p + V(-20, 7, 10), HP, 60 + 15 * u
				set({ ClockTime = 0, Brightness = 0.6, Ambient = Color3.fromRGB(60, 70, 110) })
				cc.TintColor = WHITE:Lerp(Color3.fromRGB(255, 200, 150), u)
				shake = math.max(shake, 0.3 * u)
				if t > 19.7 then flash.BackgroundColor3, flash.BackgroundTransparency = WHITE, 0 end
			else -- ===== 8. back at the long table: the ball lands right in front of the player
				local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
				local base = root and root.Position or V(0, 5, 0)
				if stage ~= 8 then
					stage = 8
					cut()
					for k, v in saved do Lighting[k] = v end
					if atmosphere then atmosphere.Density = atmoDensity end
					cc.TintColor, cc.Saturation, cc.Contrast, cc.Brightness = WHITE, 0.1, 0.05, 0
					comet.Transparency, fire.Enabled = 1, false
					reward = BallArt.Make(it, 3)
					reward.Parent = scene
					light(reward.PrimaryPart, Color3.fromRGB(255, 230, 170), 4, 24)
					sparks:Clone().Parent = reward.PrimaryPart
				end
				local u = t - 20
				local spot = base + V(0, 1.5, 7) -- in front of the player, along the long table (+Z)
				local drop = smooth(seg(u, 0, 0.7))
				local landed = spot + V(0, 0.6 * math.sin(u * 3), 0)
				reward:PivotTo(CFrame.new((spot + V(0, 70, 25)):Lerp(spot, drop ^ 2)):Lerp(CFrame.new(landed), seg(u, 0.7, 1.2)) * CFrame.Angles(0.2, t * 1.5, 0))
				if u >= 0.7 and not landedFx then
					landedFx = true
					ctx.sound("Pocket")
					ctx.sound("Reward")
					shake = 1.5
					flash.BackgroundTransparency = 0.3
					wave = ring(CFrame.new(spot - V(0, 3.5, 0)), 4, Color3.fromRGB(255, 230, 160))
					if ctx.odds then closeOdds = ctx.odds(finalL, 1.2) end
				end
				if wave and landedFx then grow(wave, CFrame.new(spot - V(0, 3.5, 0)), 1 + 15 * smooth(seg(u, 0.7, 1.8)), seg(u, 0.7, 1.8)) end
				if u >= 1.6 and not captioned then
					captioned = true
					ctx.caption()
					auraTitle.Visible = true
				end
				if root and u >= 1.6 and not auraFx then -- the super aura flares up on the player right away
					auraFx = true
					for _, e in { sparks:Clone(), sparks:Clone() } do
						e.Rate, e.Speed, e.Parent = 60, NumberRange.new(5, 10), root
						task.delay(6, e.Destroy, e)
					end
				end
				auraTitle.TextTransparency = math.max(0, 1 - seg(u, 1.6, 2.1))
				eye = base + V(-3, 5.5, -12)
				at = base + V(0, 3, 30)
				fov = 62
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
			if eye then camera.CFrame = CFrame.lookAt(eye, at) end
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
