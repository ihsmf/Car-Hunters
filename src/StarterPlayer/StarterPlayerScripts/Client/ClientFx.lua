-- Small feedback effects: pickups, banking, donations, airbag, the Golden Magnate's coin toss.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PartConfig = require(Shared:WaitForChild("PartConfig"))
local CarConfig = require(Shared:WaitForChild("CarConfig"))
local Cine = require(script.Parent:WaitForChild("CineFx"))

local Fx = {}
local K, UI
local C = Color3.fromRGB
local GOLD = C(232, 178, 50)
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local function tw(o, t, props, style, dir)
	local x = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	x:Play()
	return x
end

local function anchor(pos)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = pos
	p.Parent = Workspace
	return p
end

function Fx.Burst(pos, color, count, speed)
	local p = anchor(pos)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARK
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.6
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(speed or 14, (speed or 14) * 1.6)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 4
	e.Rate = 0
	e.ZOffset = 1
	e.Parent = p
	e:Emit(count or 20)
	task.delay(1.6, function()
		p:Destroy()
	end)
end

-- floating world text
function Fx.Float(pos, text, color)
	local p = anchor(pos)
	local bb = K.new("BillboardGui", { Adornee = p, AlwaysOnTop = true, Size = UDim2.fromOffset(200, 50), LightInfluence = 0 }, K.gui.Parent)
	local l = K.text(bb, { Text = text, TextSize = 30, TextColor3 = color, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Outline = 3 })
	local sc = K.new("UIScale", { Scale = 0.3 }, l)
	tw(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	tw(p, 1.1, { Position = pos + Vector3.new(0, 6, 0) })
	task.delay(0.7, function()
		tw(l, 0.4, { TextTransparency = 1 })
	end)
	task.delay(1.2, function()
		bb:Destroy()
		p:Destroy()
	end)
end

function Fx.Pickup(info)
	local def = PartConfig.Parts[info.partId]
	local color = def and CarConfig.Rarities[def.rarity].color or GOLD
	Fx.Burst(info.pos + Vector3.new(0, 3, 0), color, info.risk == "road" and 40 or 22)
	Fx.Float(info.pos + Vector3.new(0, 5, 0), "+" .. info.amount .. " " .. (K.PART_ICON[info.partId] or ""), color)
	if info.risk == "road" then
		Cine.Shake(0.4, 0.2)
	end
	UI.Sfx(info.risk == "road" and "pickupBig" or "pickup")
end

-- icons fly from the middle of the screen into the parts row
function Fx.Bank(info)
	local target = UDim2.fromOffset(120, 108)
	local i = 0
	for id, n in pairs(info.parts or {}) do
		for _ = 1, math.min(n, 4) do
			i = i + 1
			local delayT = i * 0.06
			task.delay(delayT, function()
				local l = K.text(K.root, { Text = K.PART_ICON[id] or "⚙️", Font = K.BODY, TextSize = 40, AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, math.random(-60, 60), 0.55, math.random(-30, 30)), Size = UDim2.fromOffset(50, 50),
					TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 45 })
				tw(l, 0.55, { Position = target, TextSize = 22 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				task.delay(0.56, function()
					l:Destroy()
				end)
			end)
		end
	end
	local msg = "+" .. info.moved
	if info.bonus > 0 then
		msg = msg .. "  +" .. info.bonus .. " COMBO"
	end
	if Fx._bankPop and Fx._bankPop.Parent then
		Fx._bankPop:Destroy() -- one "+N" at a time: a quick second bank replaces the first
	end
	local big = K.text(K.root, { Text = msg, TextSize = 46, TextColor3 = K.P.yellow, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(700, 60), TextXAlignment = Enum.TextXAlignment.Center, Outline = 4, ZIndex = 45 })
	local sc = K.new("UIScale", { Scale = 0.2 }, big)
	tw(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	Fx._bankPop = big
	task.delay(1.3, function()
		if not big.Parent then
			return
		end
		tw(big, 0.3, { TextTransparency = 1 })
		for _, st in ipairs(big:GetChildren()) do
			if st:IsA("UIStroke") then
				tw(st, 0.3, { Transparency = 1 })
			end
		end
		task.wait(0.32)
		big:Destroy()
	end)
	if info.cash and info.cash > 0 then
		UI.Toast("⏱ SPEED BONUS +$" .. info.cash, "good")
	end
	UI.Sfx(info.bonus > 0 and "bankCombo" or "bank")
end

-- golden coin rain over the screen (buyer) / gold burst (everyone else)
function Fx.Donate(buyer, key)
	if buyer == Players.LocalPlayer then
		for k = 1, 26 do
			task.delay(k * 0.03, function()
				local l = K.text(K.gui, { Text = "🪙", Font = K.BODY, TextSize = math.random(26, 44), Position = UDim2.new(math.random(), 0, -0.1, 0),
					Size = UDim2.fromOffset(50, 50), ZIndex = 55 })
				tw(l, 1.4 + math.random() * 0.6, { Position = UDim2.new(l.Position.X.Scale, 0, 1.1, 0), Rotation = math.random(-200, 200) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				task.delay(2.1, function()
					l:Destroy()
				end)
			end)
		end
		Cine.Flash(GOLD, 0.6, 0.6)
		UI.Sfx("cash")
	end
	local c = buyer and buyer.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if hrp then
		Fx.Burst(hrp.Position + Vector3.new(0, 3, 0), GOLD, 50, 20)
	end
end

function Fx.Airbag(dir)
	local c = Players.LocalPlayer.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.AssemblyLinearVelocity = dir.Unit * 60 + Vector3.new(0, 35, 0)
		Fx.Burst(hrp.Position, C(255, 255, 255), 40, 18)
	end
	Cine.Shake(1.6, 0.4)
	Cine.Flash(C(255, 255, 255), 0.3, 0.4)
	UI.Toast("🛡️ AIRBAG SAVED YOU!", "warn")
	UI.Sfx("airbag")
end

-- the Golden Magnate flips a coin and his hat sparkles
local function magnate()
	local npc
	repeat
		task.wait(2)
		for _, m in ipairs(Workspace:GetChildren()) do
			if m:IsA("Model") and m:GetAttribute("Magnate") then
				npc = m
			end
		end
	until npc
	local hand = npc:FindFirstChild("RightHand")
	local head = npc:FindFirstChild("Head")
	if head then
		local att = Instance.new("Attachment")
		att.Position = Vector3.new(0, 1.4, 0)
		att.Parent = head
		local e = Instance.new("ParticleEmitter")
		e.Texture = SPARK
		e.Color = ColorSequence.new(GOLD)
		e.LightEmission = 0.8
		e.Size = NumberSequence.new(0.35, 0)
		e.Lifetime = NumberRange.new(0.6, 1)
		e.Speed = NumberRange.new(1, 2)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Rate = 4
		e.Parent = att
	end
	while npc.Parent and hand do
		task.wait(3 + math.random() * 2)
		local coin = Instance.new("Part")
		coin.Shape = Enum.PartType.Cylinder
		coin.Size = Vector3.new(0.12, 0.9, 0.9)
		coin.Color = GOLD
		coin.Material = Enum.Material.Metal
		coin.Reflectance = 0.3
		coin.Anchored, coin.CanCollide, coin.CanQuery, coin.CanTouch = true, false, false, false
		local p0 = hand.Position + Vector3.new(0, 0.6, 0)
		coin.CFrame = CFrame.new(p0)
		coin.Parent = Workspace
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local a = (os.clock() - t0) / 0.9
			if a >= 1 or not coin.Parent then
				conn:Disconnect()
				coin:Destroy()
				return
			end
			local h = math.sin(a * math.pi) * 5
			coin.CFrame = CFrame.new(p0 + Vector3.new(0, h, 0)) * CFrame.Angles(a * 25, 0, 0)
		end)
	end
end

function Fx.Init(ui)
	UI = ui
	K = UI.Kit()
	task.spawn(magnate)
end

return Fx
