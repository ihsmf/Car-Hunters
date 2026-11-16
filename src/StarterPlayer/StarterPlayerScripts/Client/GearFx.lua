-- Gear auras (v24): every parked car with a running gear glows in that gear's own style; stronger gears look cooler.
-- The server marks the parked car model (GeneratedMap.Bases.BaseNN.Cars.Car_<slot>) with the attributes GearId and
-- GearExp (unix seconds, os.time based). Every client builds the aura locally (Workspace.GearFxLocal), never inside
-- the server's model:
--   tier 1  Nitro Can      blue speed streaks + a small blue light
--   tier 2  Lucky Clover   green sparkles + green underglow + halo ring
--           Cash Turbo     falling gold "coins" + gold underglow + halo ring
--   tier 3  Rocket Boots   cyan lightning arcs + streaks + pulsing ring + light
--   tier 4  Money Storm    gold flame jets + money beam into the sky + wide ground halo + coins
--   tier 5  Golden Engine  golden rays + spinning crown + beam + sparkles + gold outline (Highlight, near cars only)
-- A billboard above the car shows the boost and the time left ("x2 INCOME  9:42").
-- Culling: everything that moves or emits switches off beyond 220 studs from the camera; the Highlight only within
-- 60 studs and at most 10 at once (the engine renders 31); Perf LOW = a quarter of the particles and no Highlight.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GearConfig = require(Shared:WaitForChild("GearConfig"))
local Icons = require(Shared:WaitForChild("Icons"))
local Perf = require(script.Parent:WaitForChild("Perf"))

local GearFx = {}

local C = Color3.fromRGB
local WHITE = C(255, 255, 255)
local GOLD = C(255, 205, 60)
local CULL = 220
local HL_DIST, HL_MAX = 60, 10
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local TAU = math.pi * 2

local entries = {} -- [car model] = entry
local folders = {} -- [the "Cars" folder of a garage] = true
local fxRoot
local hlCount = 0

local function fmtTime(sec)
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

local function seq(a, b)
	return NumberSequence.new(a, b)
end

---------------------------------------------------------------- building blocks
local function part(e, name, size, cf, color, o)
	o = o or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = o.mat or Enum.Material.Neon
	p.Transparency = o.t or 0
	if o.shape then
		p.Shape = o.shape
	end
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	p.Massless = true
	p.Parent = e.folder
	return p
end

-- invisible carrier for attachments / emitters
local function ghost(e, name, size, cf)
	return part(e, name, size, cf, WHITE, { t = 1, mat = Enum.Material.SmoothPlastic })
end

local function att(parent, pos)
	local a = Instance.new("Attachment")
	a.Position = pos or Vector3.zero
	a.Parent = parent
	return a
end

local function emitter(e, parent, props)
	local pe = Instance.new("ParticleEmitter")
	pe.LightEmission = 1
	pe.LightInfluence = 0
	pe.Texture = SPARKLE
	for k, v in pairs(props) do
		pe[k] = v
	end
	pe:SetAttribute("BaseRate", pe.Rate)
	pe.Parent = parent
	table.insert(e.emitters, pe)
	return pe
end

local function light(e, parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	table.insert(e.lights, l)
	return l
end

local function beam(e, a0, a1, props)
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.LightEmission = 1
	b.LightInfluence = 0
	b.FaceCamera = true
	b.Segments = 12
	for k, v in pairs(props) do
		b[k] = v
	end
	b.Parent = a0.Parent
	table.insert(e.beams, b)
	return b
end

-- a flat neon loop (ellipse rx x rz) lying y studs above the ground, built from n short segments
local function ring(e, name, rx, rz, y, width, thick, color, n, t)
	local segs = {}
	for i = 0, n - 1 do
		local a0, a1 = i / n * TAU, (i + 1) / n * TAU
		local p0 = Vector3.new(rx * math.cos(a0), 0, rz * math.sin(a0))
		local p1 = Vector3.new(rx * math.cos(a1), 0, rz * math.sin(a1))
		local mid = (p0 + p1) / 2
		local seg = part(e, name, Vector3.new(width, thick, (p1 - p0).Magnitude + 0.06), e.ground * CFrame.new(0, y, 0) * CFrame.lookAt(mid, mid + (p1 - p0)), color, { t = t })
		table.insert(segs, seg)
	end
	return segs
end

-- glow under the car: a thin neon slab (mostly hidden by the body) + a light that paints the bay floor
local function underglow(e, color, brightness)
	part(e, "Underglow", Vector3.new(e.L * 0.8, 0.06, e.W * 0.7), e.ground * CFrame.new(0, 0.24, 0), color, { t = 0.15 })
	light(e, att(e.core, Vector3.new(0, 0.6, 0)), color, math.max(e.L, e.W) * 0.9, brightness or 2)
end

-- particles filling the car's volume
local function volume(e)
	if not e.vol then
		e.vol = ghost(e, "Volume", Vector3.new(e.L, e.H, e.W), e.ground * CFrame.new(0, e.H / 2, 0))
	end
	return e.vol
end

local function streaks(e, color, rate, speed)
	emitter(e, volume(e), {
		Color = ColorSequence.new(WHITE, color), Size = seq(0.35, 0.1), Transparency = seq(0.1, 1), Squash = NumberSequence.new(2.5),
		Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = e.back, Speed = NumberRange.new(speed, speed + 8),
		Lifetime = NumberRange.new(0.25, 0.45), Rate = rate, SpreadAngle = Vector2.new(2, 2),
	})
end

local function sparkles(e, color, rate, rise)
	emitter(e, volume(e), {
		Color = ColorSequence.new(WHITE, color), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = seq(0, 0.3), EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(rise * 0.5, rise), Lifetime = NumberRange.new(0.8, 1.4),
		Rate = rate, SpreadAngle = Vector2.new(30, 30), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-120, 120),
	})
end

-- gold "coins": spinning flat sparkles raining down onto the car
local function coins(e, rate)
	local sky = ghost(e, "CoinSky", Vector3.new(e.L * 0.9, 0.2, e.W * 0.9), e.ground * CFrame.new(0, e.H + 3, 0))
	emitter(e, sky, {
		Color = ColorSequence.new(C(255, 236, 120), C(232, 168, 30)), Size = NumberSequence.new(0.45), Squash = NumberSequence.new(-1.2),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0), NumberSequenceKeypoint.new(0.85, 0), NumberSequenceKeypoint.new(1, 1) }),
		EmissionDirection = Enum.NormalId.Bottom, Speed = NumberRange.new(2, 4), Acceleration = Vector3.new(0, -6, 0), Lifetime = NumberRange.new(0.9, 1.2),
		Rate = rate, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-300, 300), LightEmission = 0.6,
	})
end

---------------------------------------------------------------- the auras
local BUILD = {}

BUILD.nitro = function(e, def)
	streaks(e, def.color, 22, 16)
	light(e, att(e.core, Vector3.new(0, e.H * 0.5, 0)), def.color, 10, 1.5)
end

BUILD.clover = function(e, def)
	sparkles(e, def.color, 14, 3)
	emitter(e, volume(e), { -- a few slow, big "leaves"
		Color = ColorSequence.new(C(120, 240, 130), C(40, 180, 70)), Size = seq(0.7, 0.2), Transparency = seq(0.2, 1), EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(1, 2), Lifetime = NumberRange.new(1.5, 2.2), Rate = 3, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40), LightEmission = 0.4,
	})
	underglow(e, def.color, 2)
	e.halo = ring(e, "Halo", e.L / 2 + 0.9, e.W / 2 + 0.9, 0.2, 0.22, 0.06, def.color, 24, 0.2)
end

BUILD.cashturbo = function(e, def)
	coins(e, 10)
	sparkles(e, GOLD, 6, 2)
	underglow(e, GOLD, 2)
	e.halo = ring(e, "Halo", e.L / 2 + 0.9, e.W / 2 + 0.9, 0.2, 0.22, 0.06, GOLD, 24, 0.2)
end

BUILD.rocket = function(e, def)
	streaks(e, def.color, 30, 22)
	underglow(e, def.color, 2.5)
	e.pulse = ring(e, "PulseRing", e.L / 2 + 1.1, e.W / 2 + 1.1, 0.21, 0.3, 0.07, def.color, 28, 0.1)
	light(e, att(e.core, Vector3.new(0, e.H + 1, 0)), def.color, 16, 2)
	-- lightning: arcs from the roof down to the ring, re-bent several times a second (see animate)
	e.arcs = {}
	for k = 0, 3 do
		local a = k / 4 * TAU + 0.4
		local top = att(e.core, Vector3.new(math.cos(a) * e.L * 0.2, e.H + 0.3, math.sin(a) * e.W * 0.2))
		local bottom = att(e.core, Vector3.new(math.cos(a) * (e.L / 2 + 1.1), 0.15, math.sin(a) * (e.W / 2 + 1.1)))
		table.insert(e.arcs, beam(e, top, bottom, { Color = ColorSequence.new(WHITE, def.color), Width0 = 0.25, Width1 = 0.12, Transparency = seq(0, 0.2), Segments = 16 }))
	end
end

local function moneyBeam(e, color, height, width)
	local a0 = att(e.core, Vector3.new(0, 0.3, 0))
	local a1 = att(e.core, Vector3.new(0, height, 0))
	beam(e, a0, a1, { Color = ColorSequence.new(color), Width0 = width, Width1 = width * 0.45, Transparency = seq(0.55, 1) })
	beam(e, a0, a1, { Color = ColorSequence.new(WHITE, color), Width0 = width * 0.9, Width1 = width * 0.4, Transparency = seq(0.1, 1), Texture = SPARKLE,
		TextureMode = Enum.TextureMode.Wrap, TextureLength = 3, TextureSpeed = 1.2 })
end

BUILD.moneystorm = function(e, def)
	-- flame jets round the car
	local n = 8
	for k = 0, n - 1 do
		local a = k / n * TAU
		local jet = att(e.core, Vector3.new(math.cos(a) * (e.L / 2 + 1.4), 0.2, math.sin(a) * (e.W / 2 + 1.4)))
		emitter(e, jet, {
			Texture = FIRE, Color = ColorSequence.new(C(255, 230, 120), C(255, 140, 20)), Size = seq(1.1, 0.2), Transparency = seq(0.2, 1),
			EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(4, 7), Lifetime = NumberRange.new(0.5, 0.8), Rate = 7, SpreadAngle = Vector2.new(10, 10),
			Acceleration = Vector3.new(0, 3, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90),
		})
	end
	coins(e, 14)
	moneyBeam(e, GOLD, 40, 2.6)
	underglow(e, GOLD, 2.5)
	e.pulse = ring(e, "Halo", e.L / 2 + 1.4, e.W / 2 + 1.4, 0.21, 0.35, 0.07, GOLD, 30, 0.1)
	ring(e, "OuterHalo", e.L / 2 + 2.3, e.W / 2 + 2.3, 0.19, 0.18, 0.06, C(255, 160, 40), 30, 0.35)
	light(e, att(e.core, Vector3.new(0, e.H + 1.5, 0)), GOLD, 18, 2)
end

BUILD.goldengine = function(e, def)
	local col = def.color
	-- golden rays fanning out of the car
	local base = att(e.core, Vector3.new(0, e.H * 0.6, 0))
	for k = 0, 5 do
		local a = k / 6 * TAU
		local tip = att(e.core, Vector3.new(math.cos(a) * (e.L / 2 + 5), e.H + 7, math.sin(a) * (e.W / 2 + 5)))
		beam(e, base, tip, { Color = ColorSequence.new(C(255, 250, 200), col), Width0 = 0.6, Width1 = 3.2, Transparency = seq(0.35, 1), Segments = 4 })
	end
	moneyBeam(e, col, 48, 3)
	sparkles(e, col, 22, 4)
	coins(e, 10)
	underglow(e, col, 3)
	e.pulse = ring(e, "Halo", e.L / 2 + 1.4, e.W / 2 + 1.4, 0.21, 0.35, 0.07, col, 30, 0.1)
	ring(e, "OuterHalo", e.L / 2 + 2.4, e.W / 2 + 2.4, 0.19, 0.2, 0.06, C(255, 240, 160), 30, 0.3)
	light(e, att(e.core, Vector3.new(0, e.H + 2, 0)), col, 20, 2.5)
	-- spinning crown above the roof: band + spikes with gem tips (moved every frame, see animate)
	local r = math.min(e.L, e.W) * 0.32 + 0.6
	local centre = e.ground * CFrame.new(0, e.H + 2.4, 0)
	e.crownCF, e.crown, e.crownOff = centre, {}, {}
	local function add(p, off)
		table.insert(e.crown, p)
		table.insert(e.crownOff, off)
	end
	local n = 16
	for i = 0, n - 1 do
		local a0, a1 = i / n * TAU, (i + 1) / n * TAU
		local p0 = Vector3.new(r * math.cos(a0), 0, r * math.sin(a0))
		local p1 = Vector3.new(r * math.cos(a1), 0, r * math.sin(a1))
		local mid = (p0 + p1) / 2
		local off = CFrame.lookAt(mid, mid + (p1 - p0))
		add(part(e, "CrownBand", Vector3.new(0.18, 0.5, (p1 - p0).Magnitude + 0.05), centre * off, col, { mat = Enum.Material.Metal }), off)
	end
	for i = 0, 7 do
		local a = i / 8 * TAU
		local off = CFrame.new(r * math.cos(a), 0.65, r * math.sin(a)) * CFrame.Angles(0, -a, 0)
		add(part(e, "CrownSpike", Vector3.new(0.22, 0.85, 0.22), centre * off, col, { mat = Enum.Material.Metal }), off)
		local gem = CFrame.new(r * math.cos(a), 1.2, r * math.sin(a))
		add(part(e, "CrownGem", Vector3.new(0.34, 0.34, 0.34), centre * gem, (i % 2 == 0) and C(255, 70, 90) or C(80, 200, 255), { shape = Enum.PartType.Ball }), gem)
	end
	e.wantsHighlight = true
end

---------------------------------------------------------------- billboard
local function billboard(e, def)
	local gui = Instance.new("BillboardGui")
	gui.Name = "GearTag"
	gui.Adornee = e.core
	gui.Size = UDim2.fromOffset(196, 52)
	gui.StudsOffsetWorldSpace = Vector3.new(0, e.H + (e.crown and 6.4 or 5), 0) -- clear of the server name tag (height + 2)
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = C(20, 22, 30)
	bg.BackgroundTransparency = 0.2
	bg.Parent = gui
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 16)
	local st = Instance.new("UIStroke")
	st.Color = def.color
	st.Thickness = 2.5
	st.Parent = bg
	local img = Icons.Get("gear_" .. def.id)
	local icon
	if img then
		icon = Instance.new("ImageLabel")
		icon.Image = img
		icon.ScaleType = Enum.ScaleType.Fit
	else
		icon = Instance.new("TextLabel")
		icon.Text = def.icon
		icon.Font = Enum.Font.FredokaOne
		icon.TextScaled = true
	end
	icon.BackgroundTransparency = 1
	icon.Position = UDim2.fromOffset(5, 5)
	icon.Size = UDim2.fromOffset(42, 42)
	icon.Parent = bg
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(52, 4)
	label.Size = UDim2.new(1, -58, 0, 24)
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = def.color
	label.Text = GearConfig.Label(def)
	label.Parent = bg
	local ls = Instance.new("UIStroke")
	ls.Color = C(0, 0, 0)
	ls.Thickness = 1.5
	ls.Parent = label
	local timer = Instance.new("TextLabel")
	timer.BackgroundTransparency = 1
	timer.Position = UDim2.fromOffset(52, 28)
	timer.Size = UDim2.new(1, -58, 0, 20)
	timer.Font = Enum.Font.FredokaOne
	timer.TextScaled = true
	timer.TextXAlignment = Enum.TextXAlignment.Left
	timer.TextColor3 = WHITE
	timer.Text = ""
	timer.Parent = bg
	gui.Parent = e.core
	e.timer = timer
end

---------------------------------------------------------------- lifecycle
local function destroy(e)
	if e.highlight then
		e.highlight:Destroy()
		e.highlight = nil
		hlCount = hlCount - 1
	end
	if e.folder then
		e.folder:Destroy()
	end
end

local function build(model, def)
	local ok, cf, size = pcall(model.GetBoundingBox, model)
	if not ok or not cf or size.Magnitude < 2 then
		return nil -- still streaming in / being built: retried on the next scan
	end
	local e = { model = model, id = def.id, tier = def.tier, emitters = {}, lights = {}, beams = {}, on = nil, low = nil }
	e.folder = Instance.new("Folder")
	e.folder.Name = "Gear_" .. def.id
	-- flat frame on the bay floor under the car (parked cars stand upright; the box keeps the car's heading)
	local pos = cf.Position - Vector3.new(0, size.Y / 2, 0)
	local look = cf.LookVector
	look = Vector3.new(look.X, 0, look.Z)
	if look.Magnitude < 0.01 then
		look = Vector3.new(0, 0, -1)
	end
	e.ground = CFrame.lookAt(pos, pos + look.Unit)
	e.L, e.W, e.H = size.X, size.Z, size.Y
	e.center = cf.Position
	-- car length along local X (the rear at -X, see BaseService); streaks fly out of the back
	e.back = (size.Z > size.X) and Enum.NormalId.Back or Enum.NormalId.Left
	e.core = ghost(e, "Core", Vector3.new(0.4, 0.4, 0.4), e.ground)
	local fn = BUILD[def.id]
	if fn then
		fn(e, def)
	else
		sparkles(e, def.color, 12, 3)
	end
	billboard(e, def)
	e.folder.Parent = fxRoot
	return e
end

-- emitters / beams / lights on or off (distance cull); LOW graphics run a quarter of the particles
local function setActive(e, on, low)
	if e.on == on and e.low == low then
		return
	end
	e.on, e.low = on, low
	for _, pe in ipairs(e.emitters) do
		pe.Enabled = on
		pe.Rate = (pe:GetAttribute("BaseRate") or 10) * (low and 0.25 or 1)
	end
	for _, b in ipairs(e.beams) do
		b.Enabled = on
	end
	for _, l in ipairs(e.lights) do
		l.Enabled = on
	end
end

local function scan()
	local now = Workspace:GetServerTimeNow()
	local low = Perf.Level() == "LOW"
	local seen = {}
	for folder in pairs(folders) do
		if folder.Parent then
			for _, m in ipairs(folder:GetChildren()) do
				if m:IsA("Model") then
					local id = m:GetAttribute("GearId")
					local exp = tonumber(m:GetAttribute("GearExp"))
					local def = type(id) == "string" and GearConfig.ById[id] or nil
					if def and exp and exp > now then
						local e = entries[m]
						if e and e.id ~= id then
							destroy(e)
							entries[m] = nil
							e = nil
						end
						if not e then
							e = build(m, def)
							entries[m] = e
						end
						if e then
							seen[m] = true
							e.exp = exp
						end
					end
				end
			end
		else
			folders[folder] = nil
		end
	end
	for m, e in pairs(entries) do
		if not seen[m] or not m.Parent then
			destroy(e)
			entries[m] = nil
		end
	end
	-- distance cull, timers, and the nearest golden cars get the outline
	local cam = Workspace.CurrentCamera
	local cp = cam and cam.CFrame.Position
	local cands = {}
	for _, e in pairs(entries) do
		local d = cp and (e.center - cp).Magnitude or 0
		setActive(e, d <= CULL, low)
		e.timer.Text = fmtTime(e.exp - now)
		e.timer.TextColor3 = (e.exp - now) <= 30 and C(255, 120, 100) or WHITE
		if e.wantsHighlight and not low and d <= HL_DIST then
			table.insert(cands, { e = e, d = d })
		elseif e.highlight then
			e.highlight:Destroy()
			e.highlight = nil
			hlCount = hlCount - 1
		end
	end
	table.sort(cands, function(a, b)
		return a.d < b.d
	end)
	for i, c in ipairs(cands) do
		local e = c.e
		if i > HL_MAX and e.highlight then
			e.highlight:Destroy()
			e.highlight = nil
			hlCount = hlCount - 1
		end
	end
	for i = 1, math.min(#cands, HL_MAX) do
		local e = cands[i].e
		if not e.highlight and hlCount < HL_MAX then
			local h = Instance.new("Highlight")
			h.Adornee = e.model
			h.FillColor = GOLD
			h.FillTransparency = 0.88
			h.OutlineColor = C(255, 220, 90)
			h.OutlineTransparency = 0
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.Parent = e.folder
			e.highlight = h
			hlCount = hlCount + 1
		end
	end
end

local lastArc, lastPulse = 0, 0
local function animate()
	local t = os.clock()
	local doArc = t - lastArc >= 0.12
	local doPulse = t - lastPulse >= 0.05
	if doArc then
		lastArc = t
	end
	if doPulse then
		lastPulse = t
	end
	for _, e in pairs(entries) do
		if e.on then
			if e.crown then
				local centre = e.crownCF * CFrame.Angles(0, t * 0.9, 0) + Vector3.new(0, math.sin(t * 2) * 0.15, 0)
				local cfs = table.create(#e.crown)
				for i, off in ipairs(e.crownOff) do
					cfs[i] = centre * off
				end
				Workspace:BulkMoveTo(e.crown, cfs, Enum.BulkMoveMode.FireCFrameChanged)
			end
			if doArc and e.arcs then
				for _, b in ipairs(e.arcs) do
					b.CurveSize0 = math.random(-30, 30) / 10
					b.CurveSize1 = math.random(-30, 30) / 10
					b.Transparency = NumberSequence.new(math.random() < 0.25 and 0.7 or 0, 0.3)
				end
			end
			if doPulse and e.pulse then
				local k = 0.5 + 0.5 * math.sin(t * (e.tier >= 4 and 3 or 5))
				for _, p in ipairs(e.pulse) do
					p.Transparency = 0.05 + 0.45 * k
				end
			end
		end
	end
end

function GearFx.Start()
	fxRoot = Instance.new("Folder")
	fxRoot.Name = "GearFxLocal"
	fxRoot.Parent = Workspace
	task.spawn(function()
		local map = Workspace:WaitForChild("GeneratedMap", 120)
		local bases = map and map:WaitForChild("Bases", 60)
		if not bases then
			return
		end
		for _, d in ipairs(bases:GetDescendants()) do
			if d.Name == "Cars" and d:IsA("Folder") then
				folders[d] = true
			end
		end
		bases.DescendantAdded:Connect(function(d)
			if d.Name == "Cars" and d:IsA("Folder") then
				folders[d] = true
			end
		end)
		while true do
			local ok, err = pcall(scan)
			if not ok then
				warn("[GearFx] " .. tostring(err))
			end
			task.wait(0.5)
		end
	end)
	RunService.Heartbeat:Connect(animate)
end

return GearFx
