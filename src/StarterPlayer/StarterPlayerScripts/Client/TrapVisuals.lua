-- Throw platform levels on the client (v24):
--   * spins the "TrapSpin" models (the geared turntable ring) that BaseService builds on every owned base nearby
--   * scales the "TrapSpark" emitters (metal grinding sparks) with Perf (LOW = fewer sparks)
--   * an "Upgrade Platform" prompt at your own trap (client-only, so only the owner sees it) that opens the throw menu
--   * the upgrade burst (dust puff, metal sparks, clank + cash sound, small shake) when the server says "TrapUpgraded"
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local BaseLayout = require(Shared:WaitForChild("BaseLayout"))
local TrapConfig = require(Shared:WaitForChild("TrapConfig"))
local Perf = require(script.Parent:WaitForChild("Perf"))

local TrapVisuals = {}
local UI, store, Cine

local SPIN_RADIUS = 180
local SPARK_SCALE = { HIGH = 1, MED = 0.6, LOW = 0.25 }
local CYAN = Color3.fromRGB(70, 225, 255)
local GOLD = Color3.fromRGB(255, 196, 54)

---------------------------------------------------------------- spin + sparks
-- [model] = { parts = {BasePart}, offsets = {CFrame}, conns }: each part's CFrame relative to the ring centre
-- (SpinCF) taken once as the server built it (unrotated); every frame they move together with one BulkMoveTo
local spinners = {}

local function dropSpin(m)
	local e = spinners[m]
	if e then
		for _, c in ipairs(e.conns) do
			c:Disconnect()
		end
		spinners[m] = nil
	end
end

local function addSpin(m)
	if not m:IsA("Model") or spinners[m] then
		return
	end
	local e = { parts = {}, offsets = {}, conns = {} }
	local function track(p)
		local cf = m:GetAttribute("SpinCF")
		if p:IsA("BasePart") and typeof(cf) == "CFrame" and not table.find(e.parts, p) then
			table.insert(e.parts, p)
			table.insert(e.offsets, cf:ToObjectSpace(p.CFrame))
		end
	end
	for _, p in ipairs(m:GetDescendants()) do
		track(p)
	end
	table.insert(e.conns, m.DescendantAdded:Connect(track)) -- streamed-in parts arrive unrotated
	table.insert(e.conns, m.DescendantRemoving:Connect(function(p)
		local i = table.find(e.parts, p)
		if i then
			table.remove(e.parts, i)
			table.remove(e.offsets, i)
		end
	end))
	spinners[m] = e
end

local function scaleSpark(e)
	if e:IsA("ParticleEmitter") then
		local base = e:GetAttribute("BaseRate") or e.Rate
		e.Rate = base * (SPARK_SCALE[Perf.Level()] or 1)
	end
end

local frame = 0
local function step()
	frame = frame + 1
	if Perf.Level() == "LOW" and frame % 2 == 1 then
		return -- half rate on weak devices
	end
	local cam = Workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position
	local now = os.clock()
	local parts, cfs, n = {}, {}, 0
	for m, e in pairs(spinners) do
		if not m.Parent then
			dropSpin(m)
		else
			local cf, speed = m:GetAttribute("SpinCF"), m:GetAttribute("SpinSpeed")
			if typeof(cf) == "CFrame" and type(speed) == "number" and (not camPos or (cf.Position - camPos).Magnitude < SPIN_RADIUS) then
				local rot = cf * CFrame.Angles(0, (now * speed) % (math.pi * 2), 0)
				for i, p in ipairs(e.parts) do
					n = n + 1
					parts[n], cfs[n] = p, rot * e.offsets[i]
				end
			end
		end
	end
	if n > 0 then
		Workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

---------------------------------------------------------------- prompt at your own trap
local promptPart, prompt, promptBase

local function trapLevel()
	local st = store.State
	return TrapConfig.Clamp(st and st.trapLevel or 1)
end

local function refreshPrompt()
	local st = store.State
	local idx = st and st.baseIndex
	if idx ~= promptBase then
		if promptPart then
			promptPart:Destroy()
			promptPart, prompt = nil, nil
		end
		promptBase = idx
		if idx then
			local t = BaseLayout.TrapLocal
			-- the deck's front edge (towards the plaza, where you walk up from), chest height
			local p = Instance.new("Part")
			p.Name = "TrapUpgradePrompt"
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
			p.Transparency = 1
			p.Size = Vector3.new(1, 1, 1)
			p.CFrame = BaseLayout.GetBaseCFrame(idx) * CFrame.new(t.X + 9.6, 3.2, t.Z)
			p.Parent = Workspace
			local pp = Instance.new("ProximityPrompt")
			pp.ActionText = "Upgrade Platform"
			pp.HoldDuration = 0
			pp.MaxActivationDistance = 14
			pp.RequiresLineOfSight = false
			pp.Parent = p
			pp.Triggered:Connect(function()
				if UI.IsCinematic and UI.IsCinematic() then
					return
				end
				local K = UI.Kit()
				if K.state.open ~= "throw" then
					UI.TogglePanel("throw") -- the PLATFORM row with the UPGRADE button is in the throw menu
				end
			end)
			promptPart, prompt = p, pp
		end
	end
	if prompt then
		local lvl = trapLevel()
		prompt.ObjectText = lvl >= TrapConfig.MaxLevel and string.format("PLATFORM Lv %d (MAX)", lvl) or string.format("PLATFORM Lv %d", lvl)
	end
end

---------------------------------------------------------------- upgrade burst
-- solid-world feel (v25): no glowing parts, just a dust puff off the deck, a shower of short metal sparks, the clank
-- of new hardware bolting on and a small camera shake
local function tw(o, t, props, style)
	local tween = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

function TrapVisuals.Burst(level, baseIndex)
	baseIndex = baseIndex or (store.State and store.State.baseIndex)
	if not baseIndex then
		return
	end
	level = TrapConfig.Clamp(level)
	local low = Perf.Level() == "LOW"
	local color = level >= TrapConfig.MaxLevel and GOLD or CYAN
	local bcf = BaseLayout.GetBaseCFrame(baseIndex)
	local pad = bcf:PointToWorldSpace(BaseLayout.TrapLocal) + Vector3.new(0, 1.9, 0)
	-- an invisible emitter box over the whole deck
	local anchor = Instance.new("Part")
	anchor.Name = "TrapUpgradeBurst"
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch, anchor.CastShadow = true, false, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(17, 0.2, 17)
	anchor.CFrame = CFrame.new(pad)
	anchor.Parent = Workspace
	-- dust: grey-beige puffs rolling out low over the deck
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(196, 186, 168), Color3.fromRGB(150, 144, 134))
	dust.LightEmission, dust.LightInfluence = 0, 1
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 5) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(0.9, 1.6)
	dust.Speed = NumberRange.new(4, 9)
	dust.SpreadAngle = Vector2.new(80, 80)
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Acceleration = Vector3.new(0, 1.5, 0)
	dust.Drag = 3
	dust.RotSpeed = NumberRange.new(-40, 40)
	dust.Rate = 0
	dust.Shape = Enum.ParticleEmitterShape.Box
	dust.Parent = anchor
	dust:Emit(low and 8 or 22)
	-- metal sparks: short, orange, falling fast
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 236, 170)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 150, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 60, 20)),
	})
	e.LightEmission, e.LightInfluence = 0.8, 0.2
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0.03) })
	e.Lifetime = NumberRange.new(0.3, 0.6)
	e.Speed = NumberRange.new(12, 24)
	e.SpreadAngle = Vector2.new(60, 60)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -50, 0)
	e.Drag = 1.5
	e.Rate = 0
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Parent = anchor
	e:Emit(low and 20 or 70)
	-- floating "Lv N" over the deck
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(260, 90)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 160
	bb.Adornee = anchor
	bb.Parent = anchor
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.TextColor3 = color
	l.TextStrokeTransparency = 0
	l.TextStrokeColor3 = Color3.fromRGB(27, 31, 42)
	l.Text = string.format("PLATFORM Lv %d!", level)
	l.Parent = bb
	tw(bb, 2.2, { StudsOffsetWorldSpace = Vector3.new(0, 16, 0) })
	task.delay(1.4, function()
		tw(l, 0.8, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	if UI then
		UI.Sfx("clank")
		task.delay(0.18, function()
			UI.Sfx("clank")
		end)
		task.delay(0.35, function()
			UI.Sfx("cash")
		end)
	end
	if Cine then
		Cine.Shake(0.3, 0.35)
	end
	Debris:AddItem(anchor, 2.6)
end

---------------------------------------------------------------- start
function TrapVisuals.Start(ui, storeModule, cine)
	UI, store, Cine = ui, storeModule, cine
	for _, m in ipairs(CollectionService:GetTagged("TrapSpin")) do
		addSpin(m)
	end
	CollectionService:GetInstanceAddedSignal("TrapSpin"):Connect(addSpin)
	CollectionService:GetInstanceRemovedSignal("TrapSpin"):Connect(dropSpin)
	for _, e in ipairs(CollectionService:GetTagged("TrapSpark")) do
		scaleSpark(e)
	end
	CollectionService:GetInstanceAddedSignal("TrapSpark"):Connect(scaleSpark)
	Perf.Changed.Event:Connect(function()
		for _, e in ipairs(CollectionService:GetTagged("TrapSpark")) do
			scaleSpark(e)
		end
	end)
	RunService.RenderStepped:Connect(step)
	store.Changed.Event:Connect(refreshPrompt)
	refreshPrompt()
	-- money ticks only refresh the HUD: keep the throw menu's UPGRADE button colour live too
	store.MoneyChanged.Event:Connect(function()
		local K = UI.Kit()
		if K.state.open == "throw" and K.panels.trapRefresh then
			K.panels.trapRefresh()
		end
	end)
	Net.Get("TrapUpgraded").OnClientEvent:Connect(function(level, baseIndex)
		TrapVisuals.Burst(level, baseIndex)
	end)
	Players.LocalPlayer:GetAttributeChangedSignal("BaseIndex"):Connect(refreshPrompt)
end

return TrapVisuals
