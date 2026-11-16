-- Карта лежит в Workspace.World (генерируется tools/place.py). Здесь — ссылки на её объекты и анимации.
local TweenService = game:GetService("TweenService")
local C = require(game.ReplicatedStorage.Shared.Config)

local Map = { Bases = {}, Zones = {} }

local function loop(p, t, goal, reverse)
	TweenService:Create(p, TweenInfo.new(t, reverse and Enum.EasingStyle.Sine or Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, reverse), goal):Play()
end

function Map.Build()
	local world = workspace:WaitForChild("World")
	local long = world.LongTable

	for i = 1, #C.Rarities do
		Map.Zones[i] = {
			felt = long["Zone" .. i],
			neon = long["Neon" .. i]:GetChildren(),
			text = long["Beam" .. i].Rarity.Text,
		}
	end

	for i = 1, 4 do
		local base = world["Base" .. i]
		local floor = base.Floor
		local slots = {}
		for s = 1, C.MaxEquipped do
			local p = base.Slots["Slot" .. s].Position + Vector3.new(0, 0.3, 0)
			slots[s] = CFrame.lookAt(p, Vector3.new(floor.Position.X, p.Y, floor.Position.Z))
		end
		Map.Bases[i] = {
			slots = slots,
			spawn = floor.CFrame * CFrame.new(0, 1, 32),
			sign = base.Sign.Label.Text,
			dumbPrompt = base.DumbbellHit.Prompt,
			shopPrompt = base.CueShop.Prompt,
			chars = base.Chars,
		}
	end

	-- Анимации: шар «8», кольца, летающие шары, фонтан, облака
	local eight = world.EightBall
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1, weld.Parent = eight.Ball, eight.Circle, eight.Ball
	eight.Circle.Anchored = false
	loop(eight.Ball, 5, { CFrame = eight.Ball.CFrame * CFrame.new(0, 6, 0) * CFrame.Angles(0, math.rad(30), 0) }, true)
	for k = 1, 3 do
		local ring = eight["Ring" .. k]
		loop(ring, 6 + k * 2, { CFrame = ring.CFrame * CFrame.Angles(math.pi, 0, 0) })
	end
	for _, b in world.FloatBalls:GetChildren() do
		loop(b, math.random(30, 60) / 10, { CFrame = b.CFrame * CFrame.new(0, 8, 0) * CFrame.Angles(0, math.pi, 0) }, true)
	end
	local water = Instance.new("ParticleEmitter")
	water.Color, water.Rate, water.Speed, water.SpreadAngle = ColorSequence.new(Color3.fromRGB(150, 230, 255)), 120, NumberRange.new(18, 22), Vector2.new(25, 25)
	water.Acceleration, water.Lifetime, water.Size = Vector3.new(0, -40, 0), NumberRange.new(1.2), NumberSequence.new(0.6, 0.2)
	water.LightEmission, water.Parent = 0.4, world.Fountain.Top
	local clouds = Instance.new("Clouds")
	clouds.Cover, clouds.Density, clouds.Parent = 0.55, 0.6, workspace.Terrain
	return Map
end

return Map
