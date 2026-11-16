-- Анимации шаров: бросок по длинному столу и декоративные шары на столах баз
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.Shared.Config)
local Fx = RS:WaitForChild("Remotes").Fx
local Models = RS:FindFirstChild("Models")
local T = C.Table

local function ball(color, size)
	local src = Models and Models:FindFirstChild("Ball")
	local b = src and src:Clone() or Instance.new("Part")
	if not src then b.Shape = Enum.PartType.Ball end
	b.Size, b.Color, b.Material = Vector3.one * size, color, Enum.Material.SmoothPlastic
	b.Anchored, b.CanCollide, b.CastShadow = true, false, true
	b.Parent = workspace
	return b
end

local function sfx(k) if _G.PlaySfx then _G.PlaySfx(k) end end

local function pocket(b, color)
	local burst = Instance.new("ParticleEmitter")
	burst.Color, burst.LightEmission, burst.Speed = ColorSequence.new(color), 1, NumberRange.new(8, 16)
	burst.Lifetime, burst.SpreadAngle, burst.Rate = NumberRange.new(0.5, 0.9), Vector2.new(180, 180), 0
	burst.Size = NumberSequence.new(0.6, 0)
	burst.Parent = b
	burst:Emit(40)
	sfx("Pocket")
	TweenService:Create(b, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Size = Vector3.one * 0.1, CFrame = b.CFrame - Vector3.new(0, 1.5, 0),
	}):Play()
	task.delay(1, b.Destroy, b)
end

Fx.OnClientEvent:Connect(function(kind, slot, dist, id)
	if kind ~= "Throw" then return end
	local ch = C.Characters[id]
	local color = C.Rarities[ch.rarity][2]
	local x = -T.Width / 2 + (slot - 0.5) * T.Width / T.Lanes
	local y = 3.3 + 1.1
	local b = ball(Color3.new(1, 1, 1), 2.2)
	local trail = Instance.new("Trail")
	local a0, a1 = Instance.new("Attachment", b), Instance.new("Attachment", b)
	a0.Position, a1.Position = Vector3.new(0, 0.6, 0), Vector3.new(0, -0.6, 0)
	trail.Attachment0, trail.Attachment1, trail.Color, trail.LightEmission = a0, a1, ColorSequence.new(color), 1
	trail.Lifetime, trail.Transparency = 0.4, NumberSequence.new(0.2, 1)
	trail.Parent = b

	local dur, t, angle = 1 + dist / 140, 0, 0
	local last = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		t = math.min(t + dt / dur, 1)
		local z = dist * (1 - (1 - t) ^ 3)
		angle += (z - last) / 1.1
		last = z
		b.CFrame = CFrame.new(x, y, T.StartZ + z) * CFrame.Angles(angle, 0, 0)
		if t >= 1 then
			conn:Disconnect()
			b.Color = color
			local bb = Instance.new("BillboardGui")
			bb.Size, bb.StudsOffset, bb.AlwaysOnTop = UDim2.fromOffset(220, 50), Vector3.new(0, 4, 0), true
			local l = Instance.new("TextLabel")
			l.Size, l.BackgroundTransparency, l.TextScaled, l.FontFace = UDim2.fromScale(1, 1), 1, true, C.UI.Font
			l.Text, l.TextColor3 = C.Rarities[ch.rarity][1] .. "!", color
			Instance.new("UIStroke", l).Thickness = 3
			l.Parent, bb.Parent = bb, b
			pocket(b, color)
			_G.Toast(ch.name .. " • " .. C.Rarities[ch.rarity][1], color)
		end
	end)
end)

-- Декоративные шары: катятся по столам баз и падают в лузы
local colors = { Color3.fromRGB(255, 220, 40), Color3.fromRGB(40, 90, 255), Color3.fromRGB(255, 50, 50), Color3.fromRGB(140, 40, 200), Color3.fromRGB(255, 130, 20), Color3.fromRGB(30, 160, 60), Color3.fromRGB(20, 20, 20) }
local pockets = {}
for _, px in { -4.5, 4.5 } do for _, pz in { -8, 0, 8 } do table.insert(pockets, Vector3.new(px, 0, pz)) end end
local world = workspace:WaitForChild("World")
local rng = Random.new()

while true do
	task.wait(rng:NextNumber(1, 2.5))
	local base = world:FindFirstChild("Base" .. rng:NextInteger(1, 4))
	local floor = base and base:FindFirstChild("Floor")
	if floor then
		local o = floor.Position + Vector3.new(0, 3.95, 0)
		local start = o + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-6, 6))
		local goal = o + pockets[rng:NextInteger(1, #pockets)]
		local b = ball(colors[rng:NextInteger(1, #colors)], 0.8)
		b.CFrame = CFrame.new(start)
		local spin = CFrame.fromAxisAngle((goal - start).Unit:Cross(Vector3.yAxis), -(goal - start).Magnitude / 0.4)
		local tw = TweenService:Create(b, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(goal) * spin.Rotation })
		tw:Play()
		tw.Completed:Once(function() pocket(b, b.Color) end)
	end
end
