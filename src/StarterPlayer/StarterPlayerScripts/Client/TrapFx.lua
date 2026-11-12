-- Throw + car reveal cinematic on the garage car lift. Visual only: the server already decided the result.
-- No transparent neon geometry: light comes from PointLights/SpotLights, sparks/dust from particle emitters,
-- the rarity colour from a Highlight outline, punch from ColorCorrection/Bloom/DepthOfField.
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarConfig = require(Shared:WaitForChild("CarConfig"))
local BaseLayout = require(Shared:WaitForChild("BaseLayout"))
local VehicleFactory = require(Shared:WaitForChild("VehicleFactory"))
local PartVisual = require(Shared:WaitForChild("PartVisual"))
local Cine = require(script.Parent:WaitForChild("CineFx"))

local TrapFx = {}
local sfx
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function play(name)
	if sfx then
		sfx(name)
	end
end

-- showcase hooks set by the controller: Reveal(res, onClosed), HideReveal()
function TrapFx.SetReveal(show, hide)
	TrapFx.Reveal, TrapFx.HideReveal = show, hide
end

function TrapFx.SetSfx(fn)
	sfx = fn
end

local function tw(o, t, props, style, dir)
	local x = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	x:Play()
	return x
end

local function anchor(cf)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.one
	p.CFrame = typeof(cf) == "CFrame" and cf or CFrame.new(cf)
	p.Parent = Workspace
	return p
end

local function emitter(parent, o)
	local e = Instance.new("ParticleEmitter")
	e.Texture = o.texture or SPARK
	e.Color = ColorSequence.new(o.c1, o.c2 or o.c1)
	e.LightEmission = o.light or 0.5
	e.Size = NumberSequence.new(o.s1 or 0.6, o.s2 or 0)
	e.Transparency = NumberSequence.new(o.t1 or 0, 1)
	e.Lifetime = NumberRange.new(o.life or 0.6, (o.life or 0.6) * 1.5)
	e.Speed = NumberRange.new(o.speed or 10, (o.speed or 10) * 1.6)
	e.SpreadAngle = o.spread or Vector2.new(180, 180)
	e.Acceleration = o.acc or Vector3.zero
	e.Drag = o.drag or 3
	e.Rate = o.rate or 0
	e.ZOffset = 1
	e.Parent = parent
	return e
end

local function burst(pos, o, count)
	local a = anchor(pos)
	local e = emitter(a, o)
	e:Emit(count)
	task.delay(3, function()
		a:Destroy()
	end)
end

-- dust ring flat on the floor
local function dustRing(pos, color, count)
	local a = anchor(CFrame.new(pos))
	local e = emitter(a, { texture = SMOKE, c1 = color, s1 = 1.8, s2 = 4.5, t1 = 0.35, life = 0.9, speed = 18, spread = Vector2.new(0, 180), drag = 6, light = 0 })
	e.EmissionDirection = Enum.NormalId.Front
	e.Orientation = Enum.ParticleOrientation.FacingCamera
	a.CFrame = CFrame.new(pos) * CFrame.Angles(math.pi / 2, 0, 0)
	e:Emit(count)
	task.delay(2.5, function()
		a:Destroy()
	end)
end

local function findBase(idx)
	local map = Workspace:FindFirstChild("GeneratedMap")
	local bases = map and map:FindFirstChild("Bases")
	return bases and bases:FindFirstChild(string.format("Base%02d", idx), true)
end

local function faceCF(pos, dir)
	return CFrame.new(pos) * CFrame.Angles(0, math.atan2(-dir.Z, dir.X), 0)
end

-- smooth camera: every frame the camera eases toward camTarget
local camTarget, camConn
local function camStart(cam)
	camTarget = cam.CFrame
	local cur = cam.CFrame
	camConn = RunService.RenderStepped:Connect(function(dt)
		cur = cur:Lerp(camTarget, 1 - math.exp(-dt * 5))
		cam.CFrame = cur
	end)
end
local function camStop()
	if camConn then
		camConn:Disconnect()
		camConn = nil
	end
end

local function effect(class, props)
	local e = Instance.new(class)
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = Lighting
	return e
end

function TrapFx.Play(res, baseIndex, onDone)
	task.spawn(function()
		local def = CarConfig.ById[res.typeId]
		if not def or not baseIndex then
			if def and TrapFx.Reveal then
				TrapFx.Reveal(res)
			end
			if onDone then
				onDone()
			end
			return
		end
		local k = 1 / math.max(1, res.speed or 1) -- fast trap pass halves every beat
		local function wait(t)
			task.wait(t * k)
		end
		local tStart = os.clock()
		local lvl = CarConfig.Rarities[res.rarity].index
		local rc = CarConfig.Rarities[res.rarity].color
		local bcf = BaseLayout.GetBaseCFrame(baseIndex)
		local padPos = bcf:PointToWorldSpace(BaseLayout.TrapLocal) + Vector3.new(0, 1.3, 0)
		local base = findBase(baseIndex)
		local magnet = base and base:FindFirstChild("TrapMagnet")
		local magnetCF = magnet and magnet.CFrame
		local char = Players.LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local startPos = hrp and (hrp.Position + Vector3.new(0, 2.5, 0)) or (padPos + Vector3.new(14, 8, 0))
		local cam = Cine.Take()
		local cam0 = cam.CFrame
		camStart(cam)
		local side = bcf:VectorToWorldSpace(Vector3.new(0, 0, 1))
		local front = bcf:VectorToWorldSpace(Vector3.new(1, 0, 0)) -- out of the garage, towards the plaza
		local dof = effect("DepthOfFieldEffect", { Name = "TrapDof", FarIntensity = 0, NearIntensity = 0, FocusDistance = 30, InFocusRadius = 20 })
		local cc = effect("ColorCorrectionEffect", { Name = "TrapCC" })

		-- 1) over the shoulder, letterbox
		Cine.Letterbox(true, 0.35)
		camTarget = CFrame.lookAt((startPos + padPos) / 2 + side * 22 + Vector3.new(0, 10, 0), padPos + Vector3.new(0, 2, 0))
		wait(0.3)

		-- 2) the part flies onto the lift
		play("throw")
		local item = PartVisual.Build(res.partId)
		item:PivotTo(CFrame.new(startPos))
		item.Parent = Workspace
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0, 0.7, 0), Vector3.new(0, -0.7, 0)
		a0.Parent, a1.Parent = item.PrimaryPart, item.PrimaryPart
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Color = ColorSequence.new(Color3.new(1, 1, 1), rc)
		trail.Transparency = NumberSequence.new(0.1, 1)
		trail.Lifetime = 0.3
		trail.LightEmission = 0.4
		trail.Parent = item.PrimaryPart
		local target = padPos + Vector3.new(0, 1.2, 0)
		local flight = 0.6 * k
		local t0 = os.clock()
		while true do
			local a = math.min(1, (os.clock() - t0) / flight)
			item.PrimaryPart.CFrame = CFrame.new(startPos:Lerp(target, a) + Vector3.new(0, math.sin(a * math.pi) * 10, 0)) * CFrame.Angles(a * 10, a * 7, 0)
			if a >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		Cine.Shake(0.8, 0.25)
		burst(target, { c1 = Color3.fromRGB(255, 220, 140), c2 = Color3.fromRGB(255, 140, 40), s1 = 0.5, life = 0.5, speed = 16, acc = Vector3.new(0, -40, 0) }, 30)
		dustRing(padPos, Color3.fromRGB(200, 196, 190), 18)
		play("clank")

		-- 3) the magnet comes down and charges
		camTarget = CFrame.lookAt(padPos + side * 16 + front * 10 + Vector3.new(0, 9, 0), padPos + Vector3.new(0, 3, 0))
		local light = Instance.new("PointLight")
		light.Color = rc
		light.Range = 4
		light.Brightness = 0
		if magnet then
			light.Parent = magnet
			tw(magnet, 0.5 * k, { CFrame = magnetCF - Vector3.new(0, 5, 0) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		end
		wait(0.45)
		item:Destroy()
		play("charge")
		local spk = anchor(CFrame.new(padPos + Vector3.new(0, 0.4, 0)))
		local sparks = emitter(spk, { c1 = Color3.fromRGB(255, 240, 200), c2 = rc, s1 = 0.4, life = 0.5, speed = 14, spread = Vector2.new(35, 35), acc = Vector3.new(0, -30, 0), rate = 25 + lvl * 15 })
		sparks.EmissionDirection = Enum.NormalId.Top
		local smoke = emitter(spk, { texture = SMOKE, c1 = Color3.fromRGB(150, 150, 150), s1 = 2, s2 = 6, t1 = 0.6, life = 1.4, speed = 3, acc = Vector3.new(0, 4, 0), rate = 6, light = 0 })
		tw(light, (0.9 + lvl * 0.2) * k, { Range = 18 + lvl * 4, Brightness = 2 + lvl })
		tw(dof, (0.9 + lvl * 0.2) * k, { FarIntensity = 0.6, FocusDistance = 18, InFocusRadius = 8 })
		local chargeT = (0.9 + lvl * 0.2) * k
		local c0 = os.clock()
		while os.clock() - c0 < chargeT do
			local f = (os.clock() - c0) / chargeT
			Cine.Shake(0.1 + f * 0.25 * lvl, 0.12)
			camTarget = CFrame.lookAt(padPos + side * (16 - f * 5) + front * (10 - f * 3) + Vector3.new(0, 9 - f * 2, 0), padPos + Vector3.new(0, 3, 0))
			task.wait(0.08)
		end

		-- 4) climax
		sparks.Enabled = false
		smoke.Enabled = false
		play(lvl >= 4 and "revealBig" or "reveal")
		cc.Brightness = 0.35
		cc.Contrast = 0.25
		cc.TintColor = rc:Lerp(Color3.new(1, 1, 1), 0.6)
		tw(cc, 0.7, { Brightness = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1) })
		Cine.Shake(1 + lvl * 0.45, 0.6)
		burst(padPos + Vector3.new(0, 3, 0), { c1 = rc, c2 = Color3.new(1, 1, 1), s1 = 0.8, life = 0.9, speed = 22 + lvl * 4, drag = 2 }, 30 + lvl * 20)
		if lvl >= 4 then
			Cine.Title(string.upper(res.rarity) .. "!", rc, 1.1, 150, 0.28)
		end

		-- 5) showcase: dark blurred screen, the car spins on a rarity backdrop (UI.ShowReveal) until tapped
		Cine.Darken(0.55, 0.25)
		Cine.Shake(1.2 + lvl * 0.3, 0.5)
		if magnet then
			tw(magnet, 0.6, { CFrame = magnetCF })
			tw(light, 0.8, { Brightness = 0 })
		end
		tw(dof, 0.4, { FarIntensity = 0 })
		local shown = false
		if TrapFx.Reveal then
			TrapFx.Reveal(res, function()
				shown = true
			end)
			local w0 = os.clock()
			while not shown and os.clock() - w0 < (lvl >= 4 and 6 or 4.5) do
				task.wait(0.05)
			end
			if not shown and TrapFx.HideReveal then
				TrapFx.HideReveal()
			end
		end
		Cine.Darken(0, 0.3)

		-- 6) drive-in: the car comes through the garage gate and parks; the camera rides in front of it
		local ghost = VehicleFactory.BuildCar(def)
		local y = BaseLayout.FloorY + 0.6
		local real = {}
		local function hideReal()
			local cars = base and base:FindFirstChild("Cars")
			local m = cars and res.slot and cars:FindFirstChild("Car_" .. res.slot)
			if m and not real[m] then
				real[m] = true
				for _, d in ipairs(m:GetDescendants()) do
					if d:IsA("BasePart") then
						d.LocalTransparencyModifier = 1
					elseif d:IsA("BillboardGui") then
						d.Enabled = false
					end
				end
			end
		end
		if res.slot then
			local pl = BaseLayout.PortalLocal
			local sl = BaseLayout.SlotLocal(res.slot)
			local L = function(x, yy, z)
				return bcf:PointToWorldSpace(Vector3.new(x, yy, z))
			end
			local pts = { L(pl.X + 30, y, pl.Z), L(pl.X - 6, y, pl.Z), L(BaseLayout.LaneX, y, pl.Z) }
			if sl.Y > 0 then
				local el = BaseLayout.ElevatorLocal
				local yUp = y + sl.Y
				for _, p in ipairs({ { BaseLayout.LaneX, y, el.Z }, { el.X, y, el.Z }, { el.X, yUp, el.Z }, { -15, yUp, el.Z }, { -15, yUp, sl.Z }, { sl.X, yUp, sl.Z } }) do
					table.insert(pts, L(p[1], p[2], p[3]))
				end
			else
				table.insert(pts, L(BaseLayout.LaneX, y, sl.Z))
				table.insert(pts, L(sl.X + 4, y, sl.Z))
			end
			-- open the roller door locally
			local door = base and base:FindFirstChild("PortalDoor")
			local doorCF = door and door.CFrame
			if door then
				tw(door, 0.6, { CFrame = doorCF + Vector3.new(0, 10.5, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			end
			ghost:PivotTo(faceCF(pts[1], pts[2] - pts[1]))
			ghost.Parent = Workspace
			hideReal()
			play("drive")
			local total = 0
			for i = 2, #pts do
				total = total + (pts[i] - pts[i - 1]).Magnitude
			end
			local dur = math.clamp(total / 22, 3, 6)
			local d0 = os.clock()
			local lastDir = pts[2] - pts[1]
			local camPos
			while true do
				hideReal()
				local a = math.min(1, (os.clock() - d0) / dur)
				local e = a < 0.5 and 2 * a * a or 1 - (-2 * a + 2) ^ 2 / 2 -- ease in-out
				local dist, acc = e * total, 0
				for i = 2, #pts do
					local seg = (pts[i] - pts[i - 1]).Magnitude
					if dist <= acc + seg or i == #pts then
						local pos = pts[i - 1]:Lerp(pts[i], math.clamp((dist - acc) / math.max(seg, 1e-3), 0, 1))
						local dir = pts[i] - pts[i - 1]
						dir = Vector3.new(dir.X, 0, dir.Z)
						if dir.Magnitude > 0.01 then
							lastDir = lastDir:Lerp(dir.Unit, 0.18)
						end
						local fwd = lastDir.Magnitude > 0.01 and lastDir.Unit or Vector3.new(1, 0, 0)
						ghost.PrimaryPart.CFrame = faceCF(pos, fwd) * CFrame.new(0, math.sin(os.clock() * 18) * 0.04, 0)
						-- camera in front of the car, looking back at its face
						local want = pos + fwd * 13 + fwd:Cross(Vector3.yAxis) * 2.5 + Vector3.new(0, 3.6, 0)
						camPos = camPos and camPos:Lerp(want, 0.15) or want
						camTarget = CFrame.lookAt(camPos, pos + Vector3.new(0, 1.6, 0))
						break
					end
					acc = acc + seg
				end
				if a >= 1 then
					break
				end
				RunService.RenderStepped:Wait()
			end
			-- reverse-style final: swing into the bay facing out, hero shot
			local final = pts[#pts] - bcf:VectorToWorldSpace(Vector3.new(4, 0, 0))
			local outDir = bcf:VectorToWorldSpace(Vector3.new(1, 0, 0))
			tw(ghost.PrimaryPart, 0.7, { CFrame = faceCF(final, outDir) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			camTarget = CFrame.lookAt(final + outDir * 14 + bcf:VectorToWorldSpace(Vector3.new(0, 0, 6)) + Vector3.new(0, 3, 0), final + Vector3.new(0, 1.5, 0))
			task.wait(0.8)
			Cine.Shake(0.3, 0.2)
			if lvl >= 4 then
				Cine.Title(string.upper(def.name), rc, 1.2, 90, 0.75)
			end
			task.wait(1.1)
			if door then
				tw(door, 0.6, { CFrame = doorCF })
			end
		end
		-- the real (server) car takes over
		ghost:Destroy()
		for m in pairs(real) do
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = 0
				elseif d:IsA("BillboardGui") then
					d.Enabled = true
				end
			end
		end
		spk:Destroy()

		-- 7) hand the camera back
		Cine.Letterbox(false, 0.35)
		camTarget = cam0
		task.wait(0.35)
		camStop()
		dof:Destroy()
		cc:Destroy()
		Cine.Release(0.3)
		if onDone then
			onDone()
		end
	end)
end

return TrapFx
