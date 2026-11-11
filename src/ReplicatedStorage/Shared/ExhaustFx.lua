-- Rarity-based exhaust for cars parked in a garage. Rarer = denser, brighter, flashier.
local CollectionService = game:GetService("CollectionService")
local Kinds = require(script.Parent:WaitForChild("VehicleKinds"))

local C = Color3.fromRGB
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local ExhaustFx = {}

-- each layer: texture, colors, rate, life, size {from,to}, speed, light emission, transparency from
local PRESETS = {
	Common = {
		{ SMOKE, { C(150, 150, 150), C(110, 110, 110) }, 3, 1.4, { 0.5, 2.2 }, 2, 0, 0.55 },
	},
	Uncommon = {
		{ SMOKE, { C(200, 255, 210), C(120, 170, 130) }, 6, 1.5, { 0.6, 2.6 }, 3, 0.1, 0.45 },
	},
	Rare = {
		{ SMOKE, { C(150, 210, 255), C(60, 120, 200) }, 9, 1.4, { 0.6, 2.8 }, 4, 0.35, 0.35 },
		{ SPARK, { C(120, 200, 255), C(46, 168, 255) }, 4, 0.5, { 0.4, 0 }, 7, 1, 0 },
	},
	Epic = {
		{ FIRE, { C(255, 230, 120), C(255, 70, 60) }, 22, 0.28, { 0.9, 0.2 }, 9, 1, 0.1 },
		{ SMOKE, { C(90, 60, 60), C(40, 40, 44) }, 10, 1.6, { 0.8, 3.4 }, 4, 0, 0.4 },
		{ SPARK, { C(255, 160, 80), C(255, 77, 109) }, 8, 0.5, { 0.45, 0 }, 10, 1, 0 },
	},
	Legendary = {
		{ FIRE, { C(255, 255, 220), C(255, 176, 32) }, 34, 0.32, { 1.2, 0.2 }, 12, 1, 0 },
		{ SMOKE, { C(255, 230, 150), C(255, 190, 60) }, 14, 1.8, { 1, 4 }, 5, 0.6, 0.3 },
		{ SPARK, { C(255, 255, 255), C(255, 210, 63) }, 16, 0.9, { 0.6, 0 }, 12, 1, 0 },
	},
}

local function emitter(att, layer)
	local e = Instance.new("ParticleEmitter")
	e.Texture = layer[1]
	e.Color = ColorSequence.new(layer[2][1], layer[2][2])
	e.Rate = layer[3]
	e.Lifetime = NumberRange.new(layer[4] * 0.8, layer[4] * 1.2)
	e.Size = NumberSequence.new(layer[5][1], layer[5][2])
	e.Speed = NumberRange.new(layer[6] * 0.7, layer[6])
	e.LightEmission = layer[7]
	e.Transparency = NumberSequence.new(layer[8], 1)
	e.SpreadAngle = Vector2.new(12, 12)
	e.Acceleration = Vector3.new(0, 2.5, 0)
	e.Drag = 1.5
	e.EmissionDirection = Enum.NormalId.Left -- -X = out of the tailpipe (cars face +X)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Rotation = NumberRange.new(0, 360)
	e.Parent = att
	return e
end

function ExhaustFx.Attach(model, def, rarityIndex)
	local root = model.PrimaryPart
	local preset = PRESETS[def.rarity]
	if not root or not preset then
		return
	end
	local k = Kinds[def.style] or Kinds.sedan
	local pipes = (rarityIndex or 1) >= 3 and { -1, 1 } or { 1 }
	for _, s in ipairs(pipes) do
		local att = Instance.new("Attachment")
		att.Name = "Exhaust"
		att.CFrame = CFrame.new(-k.L / 2 - 0.2, k.clear + 0.3, s * k.W * 0.25)
		att.Parent = root
		for _, layer in ipairs(preset) do
			emitter(att, layer)
		end
		if def.rarity == "Legendary" or def.rarity == "Epic" then
			CollectionService:AddTag(att, "Backfire")
			att:SetAttribute("Color", def.rarity == "Legendary" and C(255, 210, 63) or C(255, 77, 109))
		end
	end
	if def.rarity == "Legendary" then
		local light = Instance.new("PointLight")
		light.Color = C(255, 190, 60)
		light.Range = 10
		light.Brightness = 2
		light.Parent = root
	end
end

return ExhaustFx
