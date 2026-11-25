-- CUE HUNTERS ball reveal scenes (client). Every pull plays a short scene themed after the table the ball came from,
-- the rarer the ball the longer and more powerful; every scene ends the same way: the ball close-up in front of the
-- player on a darkened screen (Throw's revealCard). The very last ball plays "the birth of a star" over the long
-- table: the balls of every table rise, spin into a galaxy, collapse into a supernova and a legendary ball is born.
--   RevealScenes.Play(it, ctx)   ctx = { skipped(), sound(name), shake(a), flash(color, strength, t) }
--   RevealScenes.Finale(it, ctx) same ctx + caption(), odds(L, seconds), ballOdds
local RS = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local C = require(RS.Shared.Config)
local BallArt = require(RS.Shared.BallArt)
local MeshBuilder = require(RS.Shared.MeshBuilder)
local V = Vector3.new
local WHITE = Color3.new(1, 1, 1)
local rgb = Color3.fromRGB
local function smooth(x) x = math.clamp(x, 0, 1); return x * x * (3 - 2 * x) end
local function seg(t, a, b) return math.clamp((t - a) / (b - a), 0, 1) end

local M = {}

-- theme of a table name (same keywords as tools/hall.py)
local KITS = {
	{ { "new year" }, "NewYear" }, { { "apple", "orchard", "acorn", "maple", "grove", "blossom" }, "Orchard" },
	{ { "candy", "waffle", "macaron", "sugar" }, "Candy" },
	{ { "coral", "pearl", "seahorse", "jellyfish", "reef", "lagoon", "nautilus", "tidal" }, "Reef" },
	{ { "saguaro", "joshua", "agave", "mesa", "dunes", "sandstone", "sun arch" }, "Desert" },
	{ { "frost", "ice", "glacier", "polar", "aurora" }, "Ice" }, { { "ember", "obsidian", "magma", "firebird", "solar", "forge" }, "Fire" },
	{ { "bamboo", "koi", "tea", "bonsai", "jade", "lantern", "pagoda" }, "Zen" },
	{ { "crater", "meteor", "comet", "lunar", "orbital", "saturn", "nebula", "galaxy", "saucer", "eclipse", "astral" }, "Space" },
	{ { "brass", "pendulum", "copper", "chronometer", "clock", "windmill" }, "Clock" },
	{ { "lotus", "waterlily", "dragonfly", "bloom", "rain" }, "Garden" }, { { "pixel", "joystick", "hologram", "synthwave", "prism" }, "Pixel" },
	{ { "cloud", "storm", "thunder", "tempest", "kites", "sail" }, "Sky" },
	{ { "royal", "sapphire", "ruby", "opal", "crown", "gallery", "bastion" }, "Royal" },
	{ { "canal", "wharf", "beacon", "loft", "harbour" }, "Harbour" },
}
function M.ThemeOf(section)
	local name = string.lower((C.Tables[section] or { "" })[1])
	for _, kit in KITS do
		for _, w in kit[1] do
			if string.find(name, w, 1, true) then return kit[2] end
		end
	end
	return "Club"
end

-- ===== stage helpers =====
local LIGHT_KEYS = { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "ExposureCompensation", "FogEnd", "FogColor" }
local function stage(origin)
	local S = { O = origin, folder = Instance.new("Folder") }
	S.folder.Name = "RevealScene"
	function S.part(size, cf, color, material, shape)
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Size, p.CFrame, p.Color, p.Material = size, cf, color, material or Enum.Material.SmoothPlastic
		if shape then p.Shape = shape end
		p.Parent = S.folder
		return p
	end
	function S.ball(d, pos, color, material)
		return S.part(V(d, d, d), CFrame.new(pos), color, material or Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	function S.emit(parent, props)
		local e = Instance.new("ParticleEmitter")
		e.LightEmission, e.Rate = 1, 0
		for k, v in props do e[k] = v end
		e.Parent = parent
		return e
	end
	function S.light(parent, color, brightness, range)
		local l = Instance.new("PointLight")
		l.Color, l.Brightness, l.Range, l.Parent = color, brightness, range, parent
		return l
	end
	function S.mesh(name, cf, scale)
		local m = MeshBuilder.Create(name, cf, nil, scale or 1)
		if m then m.Parent = S.folder end
		return m
	end
	return S
end

local function withLighting(props, fn)
	local saved = {}
	for _, k in LIGHT_KEYS do saved[k] = Lighting[k] end
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	local dens = atmo and atmo.Density
	if atmo then atmo.Density = 0 end
	for k, v in props do Lighting[k] = v end
	local ok, err = pcall(fn)
	for k, v in saved do Lighting[k] = v end
	if atmo then atmo.Density = dens end
	if not ok then warn("Reveal scene:", err) end
	return ok
end

-- ===== the 16 themed scenes =====
-- Each scene: build(S, it, k, col) -> step(u, dt) returning eye, at (camera); the prize model is S.prize, which the
-- scene must bring to S.O + V(0, 3, 0) by u = 0.82 (the close-up takes over from there).
local SCENES = {}
local FOCUS = V(0, 3, 0)

local function ground(S, color, material, d)
	return S.part(V(1, d or 70, d or 70), CFrame.new(S.O + V(0, -0.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, material or Enum.Material.Sand, Enum.PartType.Cylinder)
end
local function orbitCam(S, u, dist, height, speed)
	local a = 0.6 + u * (speed or 1.2)
	return S.O + V(math.sin(a) * dist, height, math.cos(a) * dist), S.O + FOCUS + V(0, 1.5 * (1 - u), 0)
end

SCENES.Orchard = function(S, it, k, col) -- the ball ripens on an apple tree and falls through the falling leaves
	ground(S, rgb(110, 180, 80), Enum.Material.Grass)
	S.mesh("LandTree", CFrame.new(S.O + V(0, 0, -2)), 2.2)
	local leaves = S.part(V(20, 1, 20), CFrame.new(S.O + V(0, 22, -2)), WHITE)
	leaves.Transparency = 1
	S.emit(leaves, { Color = ColorSequence.new(rgb(120, 200, 80), rgb(240, 170, 60)), Rate = 30 + 60 * k, Lifetime = NumberRange.new(3, 5),
		Speed = NumberRange.new(1, 3), Acceleration = V(0, -3, 0), Size = NumberSequence.new(0.5), Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90), Shape = Enum.ParticleEmitterShape.Box, LightEmission = 0, EmissionDirection = Enum.NormalId.Bottom })
	return function(u)
		local hang = S.O + V(1.5, 17, 0)
		local fall = seg(u, 0.45, 0.72)
		local p = hang:Lerp(S.O + FOCUS, fall * fall)
		if u > 0.72 then p = S.O + FOCUS + V(0, math.abs(math.sin((u - 0.72) * 30)) * 1.5 * (1 - seg(u, 0.72, 0.82)), 0) end
		S.prize:PivotTo(CFrame.new(p) * CFrame.Angles(u * 6, u * 4, 0))
		if u > 0.72 and not S.hit then S.hit = true; S.boom(p) end
		return S.O + V(10, 6 + 8 * (1 - fall), 16), p
	end
end

SCENES.Candy = function(S, it, k, col) -- a giant wrapped candy spins, the wrapper twists open
	ground(S, rgb(255, 190, 220), Enum.Material.SmoothPlastic)
	local halves = {}
	for s = -1, 1, 2 do
		local h = S.ball(6, S.O + FOCUS, s < 0 and rgb(255, 90, 150) or rgb(120, 220, 190))
		local twist = S.part(V(3, 2.4, 2.4), CFrame.new(S.O + FOCUS), h.Color, Enum.Material.SmoothPlastic)
		halves[#halves + 1] = { h = h, t = twist, s = s }
	end
	return function(u)
		local spin = u * (12 + 10 * k)
		local open = seg(u, 0.55, 0.75)
		for _, e in halves do
			local cf = CFrame.new(S.O + FOCUS) * CFrame.Angles(0, spin, 0) * CFrame.new(e.s * (open * 9), open * 2, 0)
			e.h.CFrame = cf * CFrame.Angles(0, 0, e.s * open * 2)
			e.h.Size = V(6, 6, 6) * (1 - open * 0.3)
			e.t.CFrame = cf * CFrame.new(e.s * 4, 0, 0) * CFrame.Angles(spin * 2, 0, math.pi / 2)
			e.h.Transparency, e.t.Transparency = open, open
		end
		S.prize:PivotTo(CFrame.new(S.O + FOCUS) * CFrame.Angles(0, spin, 0))
		S.prize:ScaleTo(math.max(0.01, open))
		if open > 0.05 and not S.hit then S.hit = true; S.boom(S.O + FOCUS) end
		return orbitCam(S, u, 15, 6)
	end
end

SCENES.Reef = function(S, it, k, col) -- under the sea: a giant bubble rises out of the coral and pops
	ground(S, rgb(230, 210, 160), Enum.Material.Sand)
	for i = 1, 8 do S.mesh("LandCoral", CFrame.new(S.O + V(math.cos(i) * 12, 0, math.sin(i) * 12 - 4)) * CFrame.Angles(0, i, 0), 1.2) end
	local bub = S.ball(5, S.O + V(0, 0, 0), rgb(150, 220, 255), Enum.Material.Glass)
	bub.Transparency = 0.55
	local src = S.part(V(16, 1, 16), CFrame.new(S.O), WHITE)
	src.Transparency = 1
	S.emit(src, { Color = ColorSequence.new(rgb(200, 240, 255)), Rate = 25 + 40 * k, Lifetime = NumberRange.new(2, 4), Speed = NumberRange.new(3, 6),
		Size = NumberSequence.new(0.4, 0.1), Transparency = NumberSequence.new(0.3, 1), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top })
	return function(u)
		local rise = smooth(seg(u, 0.1, 0.7))
		local p = S.O + V(0, -1 + 4 * rise + math.sin(u * 20) * 0.2, 0)
		bub.CFrame = CFrame.new(p)
		S.prize:PivotTo(CFrame.new(p) * CFrame.Angles(0, u * 5, 0))
		if u > 0.7 and not S.hit then S.hit = true; bub.Transparency = 1; S.boom(p) end
		return orbitCam(S, u, 14, 4)
	end
end

SCENES.Desert = function(S, it, k, col) -- a sand tornado spins up and leaves the ball behind
	ground(S, rgb(235, 190, 120), Enum.Material.Sand)
	local core = S.part(V(1, 1, 1), CFrame.new(S.O), WHITE)
	core.Transparency = 1
	local swirl = S.emit(core, { Color = ColorSequence.new(rgb(240, 200, 130), rgb(190, 130, 70)), Rate = 120 + 200 * k, Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(10, 16), SpreadAngle = Vector2.new(5, 5), Size = NumberSequence.new(1.6, 0.4), Transparency = NumberSequence.new(0.2, 1),
		Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, LightEmission = 0,
		RotSpeed = NumberRange.new(-200, 200), EmissionDirection = Enum.NormalId.Top })
	return function(u)
		core.Size = V(4 + 6 * u, 1, 4 + 6 * u)
		core.CFrame = CFrame.new(S.O) * CFrame.Angles(0, u * 40, 0)
		swirl.Rate = u < 0.75 and (120 + 200 * k) or 0
		local rise = smooth(seg(u, 0.4, 0.78))
		S.prize:PivotTo(CFrame.new(S.O + V(0, 12 * (1 - rise) + 3 * rise, 0)) * CFrame.Angles(0, u * 30, 0))
		if u > 0.78 and not S.hit then S.hit = true; S.boom(S.O + FOCUS) end
		return orbitCam(S, u, 18, 6, 2)
	end
end

SCENES.Ice = function(S, it, k, col) -- the ball is frozen in a crystal that cracks and shatters
	ground(S, rgb(230, 245, 255), Enum.Material.Snow)
	local shards = {}
	for i = 1, 14 do
		local a = i * 0.45
		local p = S.part(V(1.4, 5 + (i % 4), 1.4), CFrame.new(S.O + FOCUS + V(math.cos(a) * 1.6, 0, math.sin(a) * 1.6)) * CFrame.Angles(math.sin(a) * 0.3, a, math.cos(a) * 0.3), rgb(170, 225, 255), Enum.Material.Glass)
		p.Transparency = 0.25
		shards[i] = { p = p, v = V(math.cos(a), 0.6, math.sin(a)) * (14 + 10 * k), base = p.CFrame }
	end
	local cracks = {}
	for i = 1, 8 do cracks[i] = S.part(V(0.12, 4, 0.12), CFrame.new(S.O + FOCUS), WHITE, Enum.Material.Neon) end
	return function(u, dt)
		local shake = seg(u, 0.3, 0.6)
		for i, c in cracks do
			c.Transparency = 1 - shake
			c.CFrame = CFrame.new(S.O + FOCUS + V(math.cos(i) * 2.4, 0, math.sin(i) * 2.4)) * CFrame.Angles(i, i * 2, 0)
		end
		for _, s in shards do
			if u < 0.6 then
				s.p.CFrame = s.base * CFrame.new(math.random() * 0.2 * shake, 0, math.random() * 0.2 * shake)
			else
				s.p.CFrame = (s.p.CFrame + s.v * dt) * CFrame.Angles(dt * 4, dt * 3, 0)
				s.v += V(0, -30, 0) * dt
			end
		end
		if u > 0.6 and not S.hit then S.hit = true; S.boom(S.O + FOCUS) end
		S.prize:PivotTo(CFrame.new(S.O + FOCUS) * CFrame.Angles(0, u * 4, 0))
		return orbitCam(S, u, 13, 5)
	end
end

SCENES.Fire = function(S, it, k, col) -- a volcano erupts and throws the ball out of the lava
	ground(S, rgb(60, 45, 45), Enum.Material.Basalt)
	S.part(V(14, 16, 14), CFrame.new(S.O + V(0, 4, -10)), rgb(80, 50, 45), Enum.Material.Basalt, Enum.PartType.Ball)
	local vent = S.part(V(4, 1, 4), CFrame.new(S.O + V(0, 11, -10)), rgb(255, 120, 30), Enum.Material.Neon)
	local lava = S.emit(vent, { Color = ColorSequence.new(rgb(255, 230, 120), rgb(255, 60, 20)), Rate = 0, Lifetime = NumberRange.new(1, 2),
		Speed = NumberRange.new(18, 30 + 20 * k), SpreadAngle = Vector2.new(25, 25), Acceleration = V(0, -30, 0), Size = NumberSequence.new(1.4, 0.3),
		EmissionDirection = Enum.NormalId.Top })
	S.light(vent, rgb(255, 120, 40), 6, 40)
	return function(u)
		lava.Rate = (u > 0.3 and u < 0.85) and (150 + 250 * k) or 0
		local fly = seg(u, 0.45, 0.78)
		local p = (S.O + V(0, 11, -10)):Lerp(S.O + FOCUS, fly) + V(0, math.sin(fly * math.pi) * 14, 0)
		S.prize:PivotTo(CFrame.new(p) * CFrame.Angles(u * 10, u * 6, 0))
		if u > 0.3 and not S.erupt then S.erupt = true; S.shake(1 + k); S.sound("Break") end
		if u > 0.78 and not S.hit then S.hit = true; S.boom(p) end
		return S.O + V(16, 7, 16), p:Lerp(S.O + V(0, 8, -10), 1 - fly)
	end
end

SCENES.Zen = function(S, it, k, col) -- paper lanterns rise into the night, one of them carries the ball down
	ground(S, rgb(70, 90, 70), Enum.Material.Grass)
	local lanterns = {}
	for i = 1, 10 + math.floor(10 * k) do
		local l = S.part(V(1.4, 1.8, 1.4), CFrame.new(S.O + V(math.cos(i * 2.4) * (4 + i % 5), 0, math.sin(i * 2.4) * (4 + i % 5))), rgb(255, 120, 80), Enum.Material.Neon)
		S.light(l, rgb(255, 170, 90), 1, 10)
		lanterns[i] = { p = l, s = 0.6 + (i % 4) * 0.25, d = i * 0.03 }
	end
	local petals = S.part(V(20, 1, 20), CFrame.new(S.O + V(0, 18, 0)), WHITE)
	petals.Transparency = 1
	S.emit(petals, { Color = ColorSequence.new(rgb(255, 190, 210)), Rate = 30, Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(1, 2),
		Acceleration = V(1, -2, 0), Size = NumberSequence.new(0.35), LightEmission = 0.2, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Bottom })
	return function(u)
		for _, l in lanterns do
			l.p.Position = V(l.p.Position.X, S.O.Y + math.max(0, (u - l.d)) * 30 * l.s, l.p.Position.Z)
		end
		local d = smooth(seg(u, 0.3, 0.8))
		local p = (S.O + V(0, 20, 0)):Lerp(S.O + FOCUS, d)
		S.prize:PivotTo(CFrame.new(p) * CFrame.Angles(0, u * 4, 0))
		if u > 0.8 and not S.hit then S.hit = true; S.boom(p) end
		return S.O + V(12, 4 + 8 * (1 - d), 12), p
	end
end

SCENES.Space = function(S, it, k, col) -- a meteor streaks down and leaves the ball in a glowing crater
	ground(S, rgb(140, 140, 155), Enum.Material.Slate)
	local meteor = S.ball(4, S.O + V(-60, 60, -40), rgb(255, 160, 60), Enum.Material.Neon)
	S.emit(meteor, { Color = ColorSequence.new(rgb(255, 240, 180), rgb(255, 80, 20)), Rate = 200, Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(1, 3),
		Size = NumberSequence.new(3, 0.5), SpreadAngle = Vector2.new(20, 20) })
	S.light(meteor, rgb(255, 160, 80), 8, 50)
	local crater = S.part(V(1, 1, 1), CFrame.new(S.O + V(0, -0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2), rgb(255, 120, 40), Enum.Material.Neon, Enum.PartType.Cylinder)
	return function(u)
		local f = seg(u, 0.1, 0.55)
		meteor.CFrame = CFrame.new((S.O + V(-60, 60, -40)):Lerp(S.O + FOCUS, f * f))
		if u > 0.55 and not S.hit then
			S.hit = true; meteor.Transparency = 1; S.boom(S.O + FOCUS)
			crater.Size = V(0.4, 12 + 8 * k, 12 + 8 * k)
		end
		crater.Transparency = u > 0.55 and seg(u, 0.6, 1) * 0.6 or 1
		S.prize:PivotTo(CFrame.new(u > 0.55 and (S.O + FOCUS) or meteor.Position) * CFrame.Angles(u * 8, u * 5, 0))
		return S.O + V(14, 6, 18), meteor.Position:Lerp(S.O + FOCUS, seg(u, 0.4, 0.6))
	end
end

SCENES.Clock = function(S, it, k, col) -- a vault door with spinning gears unlocks and swings open
	ground(S, rgb(90, 70, 55), Enum.Material.WoodPlanks)
	local door = S.part(V(1, 10, 10), CFrame.new(S.O + V(2, 5, 0)) * CFrame.Angles(0, 0, math.pi / 2), rgb(200, 160, 80), Enum.Material.Metal, Enum.PartType.Cylinder)
	local gears = {}
	for i = 1, 5 do
		local g = S.part(V(0.6, 2 + i * 0.6, 2 + i * 0.6), CFrame.new(S.O + V(2.7, 5, 0)), rgb(230, 190, 100), Enum.Material.Metal, Enum.PartType.Cylinder)
		gears[i] = { p = g, a = i * 1.26, r = 2.6 }
	end
	S.part(V(4, 11, 11), CFrame.new(S.O + V(-0.5, 5, 0)), rgb(60, 50, 45), Enum.Material.Metal)
	return function(u)
		local open = smooth(seg(u, 0.5, 0.72))
		local hinge = CFrame.new(S.O + V(2, 5, 5)) * CFrame.Angles(0, open * 1.9, 0) * CFrame.new(0, 0, -5)
		door.CFrame = hinge * CFrame.Angles(0, 0, math.pi / 2)
		for i, g in gears do
			g.p.CFrame = hinge * CFrame.new(0.7, math.sin(g.a) * g.r, math.cos(g.a) * g.r) * CFrame.Angles(u * 20 * (i % 2 == 0 and 1 or -1), 0, math.pi / 2)
		end
		local out = smooth(seg(u, 0.62, 0.82))
		S.prize:PivotTo(CFrame.new((S.O + V(-0.5, 5, 0)):Lerp(S.O + FOCUS + V(3, 0, 0), out)) * CFrame.Angles(0, u * 6, 0))
		if u > 0.5 and not S.click then S.click = true; S.sound("Cushion") end
		if u > 0.82 and not S.hit then S.hit = true; S.boom(S.O + FOCUS + V(3, 0, 0)) end
		return S.O + V(16, 6, 6), S.O + V(1, 5, 0)
	end
end

SCENES.Garden = function(S, it, k, col) -- a giant lotus opens its petals around the ball
	ground(S, rgb(70, 150, 190), Enum.Material.Glass)
	local petals = {}
	for i = 1, 10 do petals[i] = S.part(V(2.4, 0.3, 5), CFrame.new(S.O), rgb(255, 170, 205), Enum.Material.SmoothPlastic) end
	return function(u)
		local open = smooth(seg(u, 0.35, 0.75))
		for i, p in petals do
			local a = i * math.pi / 5
			p.CFrame = CFrame.new(S.O + V(0, 2, 0)) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -1.5) * CFrame.Angles(-1.3 + open * 1.1, 0, 0) * CFrame.new(0, 0, -2.5)
		end
		S.prize:PivotTo(CFrame.new(S.O + V(0, 1 + 2 * open, 0)) * CFrame.Angles(0, u * 4, 0))
		if u > 0.75 and not S.hit then S.hit = true; S.boom(S.O + FOCUS) end
		return orbitCam(S, u, 12, 8 - 4 * open)
	end
end

SCENES.Pixel = function(S, it, k, col) -- neon voxels fly in from everywhere and assemble the ball
	ground(S, rgb(30, 20, 60), Enum.Material.SmoothPlastic)
	local cubes = {}
	local n = 40 + math.floor(60 * k)
	for i = 1, n do
		local dir = V(math.random() - 0.5, math.random() * 0.6, math.random() - 0.5).Unit
		cubes[i] = { p = S.part(V(0.8, 0.8, 0.8), CFrame.new(S.O), Color3.fromHSV(i / n, 0.8, 1), Enum.Material.Neon), from = S.O + FOCUS + dir * (30 + math.random() * 20) }
	end
	return function(u)
		local c = smooth(seg(u, 0.1, 0.7))
		for i, q in cubes do
			local to = S.O + FOCUS + V(math.cos(i), math.sin(i * 1.7), math.sin(i)) * 1.2
			q.p.CFrame = CFrame.new(q.from:Lerp(to, c)) * CFrame.Angles(u * 6, u * 4, 0)
			q.p.Transparency = u > 0.72 and 1 or 0
		end
		S.prize:ScaleTo(math.max(0.01, seg(u, 0.7, 0.8)))
		S.prize:PivotTo(CFrame.new(S.O + FOCUS) * CFrame.Angles(0, u * 4, 0))
		if u > 0.72 and not S.hit then S.hit = true; S.boom(S.O + FOCUS) end
		return orbitCam(S, u, 16, 5, 2)
	end
end

SCENES.Sky = function(S, it, k, col) -- storm clouds, lightning, the ball drops through the clouds
	ground(S, rgb(120, 170, 220), Enum.Material.SmoothPlastic)
	for i = 1, 14 do
		local c = S.ball(8 + i % 4 * 2, S.O + V(math.cos(i) * 10, 18 + (i % 3), math.sin(i * 1.3) * 10), rgb(90, 95, 120))
		c.Transparency = 0.1
	end
	local bolts = {}
	return function(u)
		if math.random() < 0.06 + 0.1 * k and u < 0.8 then
			local x = V(math.random(-8, 8), 0, math.random(-8, 8))
			local b = S.part(V(0.4, 18, 0.4), CFrame.new(S.O + x + V(0, 9, 0)) * CFrame.Angles(0, 0, math.random() * 0.3), rgb(255, 250, 200), Enum.Material.Neon)
			table.insert(bolts, { p = b, t = 0.15 })
			S.flash(WHITE, 0.35, 0.15)
		end
		for i = #bolts, 1, -1 do
			bolts[i].t -= 1 / 60
			if bolts[i].t < 0 then bolts[i].p:Destroy(); table.remove(bolts, i) end
		end
		local f = seg(u, 0.45, 0.78)
		local p = (S.O + V(0, 22, 0)):Lerp(S.O + FOCUS, f * f)
		S.prize:PivotTo(CFrame.new(p) * CFrame.Angles(u * 9, u * 6, 0))
		if u > 0.78 and not S.hit then S.hit = true; S.boom(p) end
		return S.O + V(14, 5 + 10 * (1 - f), 14), p
	end
end

SCENES.Royal = function(S, it, k, col) -- a treasure chest opens in a beam of golden light
	ground(S, rgb(120, 20, 40), Enum.Material.Fabric)
	S.part(V(6, 3.5, 4), CFrame.new(S.O + V(0, 1.75, 0)), rgb(130, 70, 30), Enum.Material.WoodPlanks)
	local lid = S.part(V(6, 1.2, 4), CFrame.new(S.O + V(0, 4.1, 0)), rgb(150, 85, 35), Enum.Material.WoodPlanks)
	local beam = S.part(V(0.2, 40, 0.2), CFrame.new(S.O + V(0, 22, 0)), rgb(255, 220, 120), Enum.Material.Neon)
	beam.Transparency = 0.6
	return function(u)
		local open = smooth(seg(u, 0.35, 0.55))
		lid.CFrame = CFrame.new(S.O + V(0, 3.5, -2)) * CFrame.Angles(-open * 1.9, 0, 0) * CFrame.new(0, 0.6, 2)
		beam.Size = V(1 + 4 * open, 40, 1 + 4 * open)
		local rise = smooth(seg(u, 0.5, 0.8))
		S.prize:PivotTo(CFrame.new(S.O + V(0, 2 + 4 * rise, 0)) * CFrame.Angles(0, u * 5, 0))
		if u > 0.8 and not S.hit then S.hit = true; S.boom(S.O + V(0, 6, 0)) end
		return orbitCam(S, u, 14, 6)
	end
end

SCENES.Harbour = function(S, it, k, col) -- a bottle floats on the waves, the cork pops, the ball flies out
	ground(S, rgb(40, 110, 170), Enum.Material.Glass)
	local bottle = S.part(V(5, 2, 2), CFrame.new(S.O + V(0, 1, 0)), rgb(150, 220, 200), Enum.Material.Glass, Enum.PartType.Cylinder)
	bottle.Transparency = 0.4
	local cork = S.part(V(0.8, 0.9, 0.9), CFrame.new(S.O + V(2.9, 1, 0)), rgb(170, 130, 80), Enum.Material.Wood, Enum.PartType.Cylinder)
	return function(u)
		local bob = math.sin(u * 14) * 0.4
		bottle.CFrame = CFrame.new(S.O + V(0, 1 + bob, 0)) * CFrame.Angles(math.sin(u * 9) * 0.1, 0, 0.25)
		local pop = seg(u, 0.5, 0.65)
		cork.CFrame = CFrame.new(S.O + V(2.9 + pop * 6, 1.6 + bob + pop * 6, 0))
		local fly = smooth(seg(u, 0.5, 0.8))
		S.prize:PivotTo(CFrame.new((S.O + V(2.5, 1.5, 0)):Lerp(S.O + FOCUS, fly) + V(0, math.sin(fly * math.pi) * 6, 0)) * CFrame.Angles(u * 8, 0, 0))
		S.prize:ScaleTo(math.max(0.01, fly))
		if u > 0.5 and not S.pop then S.pop = true; S.sound("Pocket") end
		if u > 0.8 and not S.hit then S.hit = true; S.boom(S.O + FOCUS) end
		return S.O + V(10, 5, 14), S.O + V(1, 2, 0)
	end
end

SCENES.Club = function(S, it, k, col) -- a rack on green felt is broken, the prize rolls out to the camera
	ground(S, rgb(30, 130, 70), Enum.Material.Fabric)
	local rack = {}
	local n = 0
	for r = 0, 4 do
		for c = 0, r do
			n += 1
			rack[n] = { p = S.ball(1.4, S.O + V(-r * 1.25, 0.7, (c - r / 2) * 1.45), Color3.fromHSV(n / 15, 0.8, 0.95)), v = Vector3.zero }
		end
	end
	local cue = S.ball(1.4, S.O + V(12, 0.7, 0), WHITE)
	return function(u, dt)
		local strike = seg(u, 0.1, 0.3)
		cue.Position = (S.O + V(12, 0.7, 0)):Lerp(S.O + V(1.2, 0.7, 0), strike)
		if u > 0.3 and not S.broke then
			S.broke = true; S.sound("Break"); S.shake(0.6 + k)
			for _, b in rack do b.v = (b.p.Position - S.O).Unit * (10 + math.random() * 10) * V(1, 0, 1) end
		end
		for _, b in rack do
			b.p.Position += b.v * dt
			b.v *= math.max(0, 1 - 1.5 * dt)
		end
		local roll = smooth(seg(u, 0.35, 0.8))
		S.prize:PivotTo(CFrame.new((S.O + V(-2, 1.5, 0)):Lerp(S.O + FOCUS + V(4, 0, 0), roll)) * CFrame.Angles(0, 0, -u * 20))
		if u > 0.8 and not S.hit then S.hit = true; S.boom(S.O + FOCUS + V(4, 0, 0)) end
		return S.O + V(14, 7, 8), S.O + V(1, 1, 0)
	end
end

SCENES.NewYear = function(S, it, k, col) -- a present under the tree: the lid pops off in a burst of confetti and snow
	ground(S, rgb(240, 245, 255), Enum.Material.Snow)
	S.mesh("DecoTree", CFrame.new(S.O + V(-6, 0, -6)), 3)
	S.part(V(4, 4, 4), CFrame.new(S.O + V(0, 2, 0)), rgb(220, 40, 60), Enum.Material.SmoothPlastic)
	local lid = S.part(V(4.4, 1, 4.4), CFrame.new(S.O + V(0, 4.5, 0)), rgb(255, 210, 80), Enum.Material.SmoothPlastic)
	local snow = S.part(V(30, 1, 30), CFrame.new(S.O + V(0, 20, 0)), WHITE)
	snow.Transparency = 1
	S.emit(snow, { Color = ColorSequence.new(WHITE), Rate = 40, Lifetime = NumberRange.new(5, 7), Speed = NumberRange.new(2, 3), Size = NumberSequence.new(0.3),
		LightEmission = 0.3, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Bottom })
	return function(u)
		local pop = smooth(seg(u, 0.5, 0.7))
		lid.CFrame = CFrame.new(S.O + V(pop * 4, 4.5 + pop * 8, 0)) * CFrame.Angles(pop * 3, 0, pop * 2)
		local rise = smooth(seg(u, 0.55, 0.8))
		S.prize:PivotTo(CFrame.new(S.O + V(0, 3 + rise * 2, 0)) * CFrame.Angles(0, u * 5, 0))
		if u > 0.55 and not S.hit then S.hit = true; S.boom(S.O + FOCUS + V(0, 2, 0)) end
		return orbitCam(S, u, 14, 7)
	end
end

-- ===== playing a themed scene =====
local SKY = { -- lighting per theme
	Orchard = { ClockTime = 14, Brightness = 2.5 }, Candy = { ClockTime = 13, Brightness = 2.6 }, Reef = { ClockTime = 12, Brightness = 1.2, FogEnd = 120, FogColor = rgb(40, 120, 170) },
	Desert = { ClockTime = 16, Brightness = 2.8 }, Ice = { ClockTime = 11, Brightness = 2.6 }, Fire = { ClockTime = 0, Brightness = 1, Ambient = rgb(120, 60, 40) },
	Zen = { ClockTime = 20, Brightness = 1, Ambient = rgb(90, 80, 120) }, Space = { ClockTime = 0, Brightness = 1.2, Ambient = rgb(120, 110, 160) },
	Clock = { ClockTime = 17, Brightness = 2 }, Garden = { ClockTime = 10, Brightness = 2.6 }, Pixel = { ClockTime = 0, Brightness = 1, Ambient = rgb(120, 80, 180) },
	Sky = { ClockTime = 15, Brightness = 2.2 }, Royal = { ClockTime = 19, Brightness = 1.4, Ambient = rgb(140, 100, 80) },
	Harbour = { ClockTime = 9, Brightness = 2.4 }, Club = { ClockTime = 21, Brightness = 1.2, Ambient = rgb(120, 110, 90) },
	NewYear = { ClockTime = 22, Brightness = 1.2, Ambient = rgb(140, 150, 190) },
}

function M.Play(it, ctx)
	local section = it.section or 1
	local theme = M.ThemeOf(section)
	if section == 21 then theme = "NewYear" end
	local k = math.clamp(((it.id or 1) - 1) / (#C.Rarities - 1), 0, 1) -- rarity: longer and bigger
	local duration = (2.6 + 3.6 * k) * (_G.ShortOnly and 0.55 or 1)
	local col = C.Rarities[C.Balls[it.id].rarity][2]
	local S = stage(V(9000, 500, 0))
	S.sound, S.shake, S.flash = ctx.sound, ctx.shake, ctx.flash
	S.prize = BallArt.Make(it, 3)
	S.prize.Parent = S.folder
	local aura = Instance.new("Part")
	aura.Anchored, aura.CanCollide, aura.Transparency, aura.Size = true, false, 1, V(1, 1, 1)
	aura.Parent = S.folder
	local glow = S.emit(aura, { Color = ColorSequence.new(col, WHITE), Rate = 0, Lifetime = NumberRange.new(0.5, 1), Speed = NumberRange.new(8, 20 + 20 * k),
		SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(1, 0), Drag = 3 })
	function S.boom(p)
		aura.Position = p
		glow:Emit(60 + math.floor(120 * k))
		S.sound("Reward")
		S.shake(0.6 + 1.2 * k)
		S.flash(col:Lerp(WHITE, 0.4), 0.6 + 0.3 * k, 0.4)
	end
	local cam = workspace.CurrentCamera
	local prevType = cam.CameraType
	return withLighting(SKY[theme] or {}, function()
		local step = SCENES[theme](S, it, k, col)
		S.folder.Parent = workspace
		cam.CameraType = Enum.CameraType.Scriptable
		local t0, last = os.clock(), os.clock()
		repeat
			local now = os.clock()
			local dt = math.min(0.05, now - last)
			last = now
			local u = math.min(1, (now - t0) / duration)
			local eye, at = step(u, dt)
			cam.CFrame = CFrame.lookAt(eye, at)
			cam.FieldOfView = 55 - 10 * u
			if u >= 1 or ctx.skipped() then break end
			Run.RenderStepped:Wait()
		until false
		S.folder:Destroy()
		cam.CameraType = prevType
	end)
end

-- ===== the very last ball: the birth of a star =====
function M.Finale(it, ctx)
	local cam = workspace.CurrentCamera
	local plr = Players.LocalPlayer
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	local base = root and root.Position or V(0, 5, C.Table.StartZ - 10)
	local S = stage(V(0, 0, 0))
	local center = V(0, 70, C.Table.StartZ + 260) -- over the long table
	local balls = {}
	local n = #C.Rarities
	for i = 1, n do -- one ball rises from every table
		local col = C.Rarities[C.Balls[i].rarity][2]
		local start = V((i % 2 == 0 and 1 or -1) * 6, C.Table.FeltY + 2, C.Table.StartZ + (i - 0.5) * C.Table.SegmentLength)
		local b = S.ball(3, start, col, Enum.Material.Neon)
		balls[i] = { p = b, from = start, a = i * 2.39996, r = 30 + (i % 15) * 4, h = (i % 7 - 3) * 2 }
	end
	local star = S.ball(1, center, rgb(255, 240, 200), Enum.Material.Neon)
	S.light(star, rgb(255, 230, 180), 10, 120)
	local ring = S.part(V(1, 1, 1), CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2), rgb(255, 220, 160), Enum.Material.Neon, Enum.PartType.Cylinder)
	ring.Transparency = 1
	local sparks = S.emit(star, { Color = ColorSequence.new(rgb(255, 250, 220), rgb(255, 120, 60)), Rate = 0, Lifetime = NumberRange.new(1.5, 3),
		Speed = NumberRange.new(40, 120), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(3, 0) })
	local prize = BallArt.Make(it, 4)
	prize.Parent = S.folder
	prize:ScaleTo(0.01)
	local D = _G.ShortOnly and 7 or 13
	local prevType = cam.CameraType
	return withLighting({ ClockTime = 0, Brightness = 1.6, Ambient = rgb(140, 120, 190), OutdoorAmbient = rgb(130, 120, 180), ExposureCompensation = 0.3 }, function()
		S.folder.Parent = workspace
		cam.CameraType = Enum.CameraType.Scriptable
		local t0 = os.clock()
		local boomed, born = false, false
		repeat
			local t = (os.clock() - t0) * (13 / D)
			local u = math.min(1, t / 13)
			for i, b in balls do
				local rise = smooth(seg(t, 0.5 + i * 0.02, 3.2 + i * 0.01)) -- everything freezes, then rises
				local swirl = smooth(seg(t, 3, 6.5))
				local collapse = smooth(seg(t, 6.5, 8.6))
				local a = b.a + t * (0.6 + collapse * 3)
				local r = b.r * (1 - collapse * 0.98)
				local galaxy = center + V(math.cos(a) * r, b.h * (1 - collapse) + math.sin(a * 2) * 2 * (1 - collapse), math.sin(a) * r * 0.6)
				local up = b.from + V(0, rise * 40, 0)
				b.p.Position = up:Lerp(galaxy, swirl)
				b.p.Transparency = t > 8.6 and 1 or 0
			end
			star.Size = V(1, 1, 1) * (1 + 14 * smooth(seg(t, 6.8, 8.6)) * (1 + 0.08 * math.sin(t * 30)))
			if t > 8.6 and not boomed then -- supernova
				boomed = true
				sparks:Emit(400)
				ctx.sound("Break"); ctx.sound("Hit")
				ctx.shake(2.5)
				ctx.flash(WHITE, 1, 0.9)
				ring.Transparency = 0.2
			end
			if boomed then
				local e = seg(t, 8.6, 10.2)
				ring.Size = V(1, 20 + 500 * e, 20 + 500 * e)
				ring.Transparency = 0.2 + 0.8 * e
				star.Size = V(1, 1, 1) * math.max(0.1, 15 * (1 - smooth(seg(t, 8.8, 10))))
			end
			if t > 10 then -- the legendary ball is born from the light and flies down to the player
				if not born then born = true; ctx.sound("Reward") end
				local f = smooth(seg(t, 10, 12))
				prize:ScaleTo(math.max(0.01, smooth(seg(t, 10, 10.6))))
				local goal = base + V(0, 3, 9)
				prize:PivotTo(CFrame.new(center:Lerp(goal, f)) * CFrame.Angles(0, t * 2, 0))
			end
			local eye, at
			if t < 3.2 then
				eye, at = base + V(-6, 6, -10), center:Lerp(base + V(0, 10, 60), 0.4)
			elseif t < 8.6 then
				local o = smooth(seg(t, 3.2, 8.6))
				eye, at = base + V(-10 + 4 * o, 12 + 20 * o, -18 + 120 * o), center
			elseif t < 10 then
				eye, at = base + V(-6, 30, 102), center
			else
				local p = prize:GetPivot().Position
				eye, at = base + V(-5, 7, -6), p
			end
			cam.CFrame = CFrame.lookAt(eye, at)
			cam.FieldOfView = 70
			if t >= 13 or ctx.skipped() then break end
			Run.RenderStepped:Wait()
		until false
		S.folder:Destroy()
		cam.CameraType = prevType
	end)
end

return M
