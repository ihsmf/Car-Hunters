-- Throw platform levels on the client (v24):
--   * spins the "TrapSpin" models (holo ring, holo floor) that BaseService builds on every owned base nearby
--   * scales the "TrapSpark" emitters with Perf (LOW = fewer sparks)
--   * an "Upgrade Platform" prompt at your own trap (client-only, so only the owner sees it) that opens the throw menu
--   * the upgrade burst (flash ring, light column, rising sparks, sound) when the server says "TrapUpgraded"
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
local spinners = {}
local function addSpin(m)
	if m:IsA("Model") then
		spinners[m] = true
	end
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
	for m in pairs(spinners) do
		if not m.Parent then
			spinners[m] = nil
		else
			local cf, speed = m:GetAttribute("SpinCF"), m:GetAttribute("SpinSpeed")
			if typeof(cf) == "CFrame" and type(speed) == "number" and (not camPos or (cf.Position - camPos).Magnitude < SPIN_RADIUS) then
				m:PivotTo(cf * CFrame.Angles(0, (now * speed) % (math.pi * 2), 0))
			end
		end
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
local function fxPart(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = Workspace
	return p
end

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
	local pad = bcf:PointToWorldSpace(BaseLayout.TrapLocal) + Vector3.new(0, 1.7, 0)
	local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)
	-- shock ring along the deck
	local ring = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 3, 3), CFrame = CFrame.new(pad + Vector3.new(0, 0.12, 0)) * UPRIGHT, Color = color, Transparency = 0.1 })
	tw(ring, 0.7, { Size = Vector3.new(0.2, 34, 34), Transparency = 1 })
	-- light column
	local col = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(40, 6, 6), CFrame = CFrame.new(pad + Vector3.new(0, 20, 0)) * UPRIGHT, Color = Color3.new(1, 1, 1), Transparency = 0.2 })
	tw(col, 0.9, { Size = Vector3.new(60, 0.4, 0.4), Transparency = 1 })
	-- light flash + rising sparks
	local anchor = fxPart({ Size = Vector3.new(16, 0.2, 16), CFrame = CFrame.new(pad), Transparency = 1 }) -- emits from the whole deck
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = color, 34, 6, false
	light.Parent = anchor
	tw(light, 1.2, { Brightness = 0 })
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.new(1, 1, 0.9), color)
	e.LightEmission, e.LightInfluence = 1, 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(1, 1.8)
	e.Speed = NumberRange.new(14, 30)
	e.SpreadAngle = Vector2.new(35, 35)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -6, 0)
	e.Drag = 1.2
	e.Rate = 0
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Parent = anchor
	e:Emit(low and 25 or 90)
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
		UI.Sfx("revealBig")
		task.delay(0.15, function() UI.Sfx("cash") end)
	end
	if Cine then
		Cine.Flash(color, 0.55, 0.45)
		Cine.Shake(0.25, 0.3)
	end
	Debris:AddItem(ring, 1)
	Debris:AddItem(col, 1.2)
	Debris:AddItem(anchor, 2.6)
end

---------------------------------------------------------------- start
function TrapVisuals.Start(ui, storeModule, cine)
	UI, store, Cine = ui, storeModule, cine
	for _, m in ipairs(CollectionService:GetTagged("TrapSpin")) do
		addSpin(m)
	end
	CollectionService:GetInstanceAddedSignal("TrapSpin"):Connect(addSpin)
	CollectionService:GetInstanceRemovedSignal("TrapSpin"):Connect(function(m) spinners[m] = nil end)
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
