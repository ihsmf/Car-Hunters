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

-- cinematic mode hook (UI.SetCinematic): hides the HUD, closes panels, blocks prompts + movement
local cinema = function() end
function TrapFx.SetCinematic(fn)
	cinema = fn
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
local camTarget, camConn, camCur
local function camStart(cam)
	camTarget = cam.CFrame
	camCur = cam.CFrame
	camConn = RunService.RenderStepped:Connect(function(dt)
		camCur = camCur:Lerp(camTarget, 1 - math.exp(-dt * 5))
		cam.CFrame = camCur
	end)
end
-- jump cut (used while the screen is black)
local function camSnap(cf)
	camTarget, camCur = cf, cf
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

-- one cinematic at a time: later ones wait in a queue (e.g. "SEE BEST CAR" pressed during another reveal)
local busy, queue = false, {}
local current -- ctx of the running cinematic

local function check(ctx)
	if ctx.aborted then
		error("aborted", 0)
	end
end

local function body(res, baseIndex, ctx)
		local def = CarConfig.ById[res.typeId]
		if not def or not baseIndex then
			if def and TrapFx.Reveal then
				local shown = false
				TrapFx.Reveal(res, function()
					shown = true
				end)
				local w0 = os.clock()
				while not shown and os.clock() - w0 < 15 do
					task.wait(0.05)
				end
				if not shown and TrapFx.HideReveal then
					TrapFx.HideReveal()
				end
			end
			return
		end
		local k = 1 / math.max(1, res.speed or 1) -- fast trap pass halves every beat
		local function wait(t)
			task.wait(t * k)
			check(ctx)
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
		ctx.camTaken = true
		local cam0 = cam.CFrame
		ctx.cam0 = cam0
		camStart(cam)
		local side = bcf:VectorToWorldSpace(Vector3.new(0, 0, 1))
		local front = bcf:VectorToWorldSpace(Vector3.new(1, 0, 0)) -- out of the garage, towards the plaza
		local dof = effect("DepthOfFieldEffect", { Name = "TrapDof", FarIntensity = 0, NearIntensity = 0, FocusDistance = 30, InFocusRadius = 20 })
		local cc = effect("ColorCorrectionEffect", { Name = "TrapCC" })
		ctx.dof, ctx.cc = dof, cc

		-- 1) over the shoulder, letterbox
		Cine.Letterbox(true, 0.35)
		camTarget = CFrame.lookAt((startPos + padPos) / 2 + side * 22 + Vector3.new(0, 10, 0), padPos + Vector3.new(0, 2, 0))
		wait(0.3)

		-- 2) the part flies onto the lift
		play("throw")
		local item = PartVisual.Build(res.partId)
		ctx.item = item
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
			check(ctx)
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
		ctx.light, ctx.magnet, ctx.magnetCF = light, magnet, magnetCF
		if magnet then
			light.Parent = magnet
			tw(magnet, 0.5 * k, { CFrame = magnetCF - Vector3.new(0, 5, 0) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		end
		wait(0.45)
		item:Destroy()
		play("charge")
		local spk = anchor(CFrame.new(padPos + Vector3.new(0, 0.4, 0)))
		ctx.spk = spk
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
			check(ctx)
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

		-- 5) blackout: the screen goes fully dark, then the showcase (UI.ShowReveal) on a solid dark backdrop
		Cine.Shake(1.2 + lvl * 0.3, 0.5)
		task.wait(lvl >= 4 and 0.55 or 0.3)
		check(ctx)
		Cine.Darken(1, 0.22)
		task.wait(0.25)
		check(ctx)
		if magnet then
			magnet.CFrame = magnetCF
			light.Brightness = 0
		end
		dof.FarIntensity = 0
		local shown = false
		if TrapFx.Reveal then
			TrapFx.Reveal(res, function()
				shown = true
			end)
			local w0 = os.clock()
			while not shown and os.clock() - w0 < 15 do
				task.wait(0.05)
			end
			if not shown and TrapFx.HideReveal then
				TrapFx.HideReveal()
			end
		end
		check(ctx)

		-- 6) drive-in: the car comes through the garage gate and parks; the camera rides in front of it
		local ghost = VehicleFactory.BuildCar(def)
		ctx.ghost = ghost
		local y = BaseLayout.FloorY + 0.6
		local real = {}
		ctx.real = real
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
			ctx.door, ctx.doorCF = door, doorCF
			if door then
				ctx.doorTween = tw(door, 0.6, { CFrame = doorCF + Vector3.new(0, 10.5, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			end
			ghost:PivotTo(faceCF(pts[1], pts[2] - pts[1]))
			ghost.Parent = Workspace
			hideReal()
			-- still black: cut the camera to the gate, then fade in
			local d1 = (pts[2] - pts[1]).Unit
			camSnap(CFrame.lookAt(pts[1] + d1 * 13 + Vector3.new(0, 3.6, 0), pts[1] + Vector3.new(0, 1.6, 0)))
			task.wait(0.05)
			Cine.Darken(0, 0.45)
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
				check(ctx)
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
				ctx.doorTween = tw(door, 0.6, { CFrame = doorCF })
			end
		end
		Cine.Darken(0, 0.3) -- no slot (stored car): just fade back in
		-- 7) hand the camera back (cleanup() restores the real car and the rest)
		Cine.Letterbox(false, 0.35)
		camTarget = cam0
		task.wait(0.35)
end

-- always runs, also when the cinematic errored half-way: nothing may stay hidden, dark or scripted
local function cleanup(ctx)
	if ctx.doorTween then
		pcall(function()
			ctx.doorTween:Cancel()
		end)
	end
	if ctx.magnet and ctx.magnetCF then
		ctx.magnet.CFrame = ctx.magnetCF
	end
	for _, k in ipairs({ "item", "ghost", "spk", "dof", "cc", "light" }) do
		if ctx[k] then
			pcall(function()
				ctx[k]:Destroy()
			end)
		end
	end
	for m in pairs(ctx.real or {}) do
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 0
			elseif d:IsA("BillboardGui") then
				d.Enabled = true
			end
		end
	end
	if ctx.door and ctx.doorCF then
		ctx.door.CFrame = ctx.doorCF
	end
	if TrapFx.HideReveal then
		pcall(TrapFx.HideReveal)
	end
	camStop()
	Cine.Letterbox(false, 0.2)
	if not ctx.aborted then -- aborted = the player was wrecked: DeathFx owns the camera and the screen now
		Cine.Darken(0, 0.3)
		if ctx.camTaken then
			Cine.Release(0.3)
		end
	end
end

-- stop the running cinematic right away (the player got wrecked); queued ones are dropped
function TrapFx.Abort()
	queue = {}
	if current then
		current.aborted = true
	end
end

function TrapFx.Play(res, baseIndex, onDone)
	if busy then
		table.insert(queue, { res, baseIndex, onDone })
		return
	end
	busy = true
	pcall(cinema, true)
	task.spawn(function()
		local ctx = {}
		current = ctx
		local ok, err = pcall(body, res, baseIndex, ctx)
		if not ok and err ~= "aborted" then
			warn("TrapFx: " .. tostring(err))
		end
		local ok2, err2 = pcall(cleanup, ctx)
		if not ok2 then
			warn("TrapFx cleanup: " .. tostring(err2))
		end
		current = nil
		if onDone then
			task.spawn(onDone)
		end
		local nextOne = table.remove(queue, 1)
		busy = false
		if nextOne then
			TrapFx.Play(nextOne[1], nextOne[2], nextOne[3]) -- holds its own cinematic count before ours is released
		end
		pcall(cinema, false)
	end)
end

function TrapFx.IsBusy()
	return busy
end

return TrapFx
