-- Throw + car reveal cinematic. Purely visual: the server already decided the result.
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
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

local function animate(duration, fn)
	local t0 = os.clock()
	while true do
		local a = math.min(1, (os.clock() - t0) / duration)
		fn(a)
		if a >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
end

local function faceCF(pos, dir)
	return CFrame.new(pos) * CFrame.Angles(0, math.atan2(-dir.Z, dir.X), 0)
end

local function findBase(idx)
	local map = Workspace:FindFirstChild("GeneratedMap")
	local bases = map and map:FindFirstChild("Bases")
	return bases and bases:FindFirstChild(string.format("Base%02d", idx), true)
end

local function fxPart(pos, size, color, shape, transparency)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.Shape = shape or Enum.PartType.Block
	p.Transparency = transparency or 0
	p.CFrame = typeof(pos) == "CFrame" and pos or CFrame.new(pos)
	p.Parent = Workspace
	return p
end

local function burst(pos, color, count, speed, texture)
	local p = fxPart(pos, Vector3.one, color, nil, 1)
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture or "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.Lifetime = NumberRange.new(0.6, 1.4)
	e.Speed = NumberRange.new(speed or 20, (speed or 20) * 1.8)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new(1.6, 0)
	e.LightEmission = 1
	e.Drag = 3
	e.Rate = 0
	e.Parent = p
	e:Emit(count)
	task.delay(2.5, function()
		p:Destroy()
	end)
end

-- expanding neon ring on the ground
local function shockwave(pos, color, size, t)
	local ring = fxPart(CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.3, 2, 2), color, Enum.PartType.Cylinder, 0.1)
	TweenService:Create(ring, TweenInfo.new(t or 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.3, size, size), Transparency = 1 }):Play()
	task.delay((t or 0.6) + 0.05, function()
		ring:Destroy()
	end)
end

local function pulse(part, color, t)
	if part then
		local orig = part.Color
		TweenService:Create(part, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), { Color = color }):Play()
		task.delay(t * 2 + 0.05, function()
			if part.Parent then
				part.Color = orig
			end
		end)
	end
end

function TrapFx.SetSfx(fn)
	sfx = fn
end

local function play(name)
	if sfx then
		sfx(name)
	end
end

function TrapFx.Play(res, baseIndex, onDone)
	task.spawn(function()
		local def = CarConfig.ById[res.typeId]
		if not def or not baseIndex then
			if onDone then
				onDone()
			end
			return
		end
		local tStart = os.clock()
		local lvl = CarConfig.Rarities[res.rarity].index -- 1..5 drives intensity
		local rc = CarConfig.Rarities[res.rarity].color
		local bcf = BaseLayout.GetBaseCFrame(baseIndex)
		local trapPos = bcf:PointToWorldSpace(BaseLayout.TrapLocal) + Vector3.new(0, 1, 0)
		local portalPos = bcf:PointToWorldSpace(BaseLayout.PortalLocal)
		local char = Players.LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local startPos = hrp and (hrp.Position + Vector3.new(0, 2.5, 0)) or (trapPos + Vector3.new(0, 10, 12))
		local base = findBase(baseIndex)
		local pad = base and base:FindFirstChild("TrapPad")
		local portal = base and base:FindFirstChild("PortalField")
		local cam = Cine.Take()
		local cam0 = cam.CFrame

		-- 1) over-the-shoulder shot + letterbox
		Cine.Letterbox(true, 0.35)
		local side = bcf:VectorToWorldSpace(Vector3.new(0, 0, 1))
		local shot1 = CFrame.lookAt((startPos + trapPos) / 2 + side * 26 + Vector3.new(0, 12, 0), trapPos + Vector3.new(0, 2, 0))
		Cine.Move(shot1, 0.45)
		task.wait(0.35)

		-- 2) part flies with a trail
		play("throw")
		local item = PartVisual.Build(res.partId)
		item:PivotTo(CFrame.new(startPos))
		item.Parent = Workspace
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0, 0.8, 0), Vector3.new(0, -0.8, 0)
		a0.Parent, a1.Parent = item.PrimaryPart, item.PrimaryPart
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Color = ColorSequence.new(Color3.fromRGB(255, 210, 63), rc)
		trail.LightEmission = 1
		trail.Lifetime = 0.35
		trail.Transparency = NumberSequence.new(0, 1)
		trail.Parent = item.PrimaryPart
		local target = trapPos + Vector3.new(0, 2.5, 0)
		Cine.Zoom(58, 0.7)
		animate(0.7, function(a)
			local p = startPos:Lerp(target, a) + Vector3.new(0, math.sin(a * math.pi) * 12, 0)
			item.PrimaryPart.CFrame = CFrame.new(p) * CFrame.Angles(a * 12, a * 8, 0)
		end)
		item:Destroy()

		-- 3) impact + charging
		Cine.Shake(1.2, 0.3)
		Cine.Flash(Color3.fromRGB(34, 224, 224), 0.4, 0.3)
		shockwave(trapPos, Color3.fromRGB(34, 224, 224), 30, 0.5)
		burst(trapPos, Color3.fromRGB(80, 240, 255), 40)
		pulse(pad, Color3.new(1, 1, 1), 0.2)
		Cine.Darken(0.45, 0.4)
		local closeUp = CFrame.lookAt(trapPos + side * 14 + Vector3.new(0, 7, 0) + bcf.LookVector * -8, trapPos + Vector3.new(0, 2, 0))
		local camTween = Cine.Move(closeUp, 1.2)
		Cine.Zoom(48, 1.2)
		local chargeT = 0.8 + lvl * 0.15
		local t0 = os.clock()
		while os.clock() - t0 < chargeT do
			local k = (os.clock() - t0) / chargeT
			local ring = fxPart(CFrame.new(trapPos) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.25, 12 - k * 6, 12 - k * 6), (k > 0.6) and rc or Color3.fromRGB(34, 224, 224), Enum.PartType.Cylinder, 0.2)
			TweenService:Create(ring, TweenInfo.new(0.5), { CFrame = ring.CFrame + Vector3.new(0, 10, 0), Transparency = 1 }):Play()
			task.delay(0.55, function()
				ring:Destroy()
			end)
			Cine.Shake(0.15 + k * 0.25 * lvl, 0.15)
			if lvl >= 3 and math.random() < 0.15 * k then
				Cine.Glitch(0.08, 0.4)
			end
			task.wait(0.09)
		end

		-- 4) BOOM: flash, glitch, rarity beam at the portal
		play("boom")
		Cine.Flash(Color3.new(1, 1, 1), 0, 0.5 + lvl * 0.08)
		Cine.Shake(1 + lvl * 0.5, 0.6)
		if lvl >= 2 then
			Cine.Glitch(0.15 + lvl * 0.08, 0.4 + lvl * 0.15)
		end
		Cine.Darken(0.2, 0.3)
		Cine.Zoom(80, 0.25, Enum.EasingStyle.Back)
		local beam = fxPart(CFrame.new(portalPos + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(80, 10 + lvl * 2, 10 + lvl * 2), rc, Enum.PartType.Cylinder, 0.15)
		TweenService:Create(beam, TweenInfo.new(1.6), { Size = Vector3.new(80, 0.5, 0.5), Transparency = 1 }):Play()
		task.delay(1.7, function()
			beam:Destroy()
		end)
		shockwave(portalPos + Vector3.new(0, 0.6, 0), rc, 50 + lvl * 10, 0.7)
		burst(portalPos + Vector3.new(0, 6, 0), rc, 30 + lvl * 25, 26)
		if lvl >= 5 then
			burst(portalPos + Vector3.new(0, 10, 0), Color3.fromRGB(255, 230, 120), 120, 40, "rbxasset://textures/particles/sparkles_main.dds")
		end
		if portal then
			pulse(portal, rc, 0.4)
		end
		if lvl >= 4 then
			Cine.Title(string.upper(res.rarity) .. "!", rc, 1.2, 150, 0.3)
		end

		-- 5) the car rolls out of the portal; camera tracks it
		camTween:Cancel()
		local ghost = VehicleFactory.BuildCar(def)
		local y = BaseLayout.FloorY
		local p0 = Vector3.new(portalPos.X, y, portalPos.Z)
		local laneX = BaseLayout.LaneX
		local pts = { p0, bcf:PointToWorldSpace(Vector3.new(laneX, y, BaseLayout.PortalLocal.Z)) }
		if res.slot then
			local sl = BaseLayout.SlotLocal(res.slot)
			table.insert(pts, bcf:PointToWorldSpace(Vector3.new(laneX, y, sl.Z)))
			table.insert(pts, bcf:PointToWorldSpace(Vector3.new(sl.X, y, sl.Z)))
		end
		local total = 0
		for i = 2, #pts do
			total = total + (pts[i] - pts[i - 1]).Magnitude
		end
		ghost:PivotTo(faceCF(p0, pts[2] - pts[1]))
		ghost.Parent = Workspace
		Cine.Zoom(60, 0.6)
		Cine.Darken(0, 0.6)
		local orbit0 = math.random() * math.pi * 2
		local drive = 1.7 + (lvl >= 5 and 0.5 or 0)
		animate(drive, function(a)
			local e = 1 - (1 - a) ^ 2
			local d = e * total
			local acc = 0
			local pos
			for i = 2, #pts do
				local seg = (pts[i] - pts[i - 1]).Magnitude
				if d <= acc + seg or i == #pts then
					local f = math.clamp((d - acc) / math.max(seg, 0.001), 0, 1)
					pos = pts[i - 1]:Lerp(pts[i], f)
					ghost.PrimaryPart.CFrame = faceCF(pos, pts[i] - pts[i - 1])
					break
				end
				acc = acc + seg
			end
			local ang = orbit0 + a * 1.6
			local focus = pos + Vector3.new(0, 3, 0)
			cam.CFrame = CFrame.lookAt(focus + Vector3.new(math.cos(ang) * 22, 9, math.sin(ang) * 22), focus)
		end)
		Cine.Shake(0.5, 0.2)
		if not res.slot then
			for _, d in ipairs(ghost:GetDescendants()) do
				if d:IsA("BasePart") and d.Name ~= "Root" then
					TweenService:Create(d, TweenInfo.new(0.4), { Transparency = 1 }):Play()
				end
			end
			task.wait(0.4)
		end
		-- keep the ghost until the server-side car appears in the slot
		task.delay(math.max(0.3, (res.animTime or 5.2) + 0.4 - (os.clock() - tStart)), function()
			ghost:Destroy()
		end)

		-- 6) hand the camera back
		Cine.Letterbox(false, 0.35)
		Cine.Move(cam0, 0.35)
		task.wait(0.3)
		Cine.Release(0.3)
		if onDone then
			onDone()
		end
	end)
end

return TrapFx
