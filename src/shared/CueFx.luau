-- Visual effects of a cue tier (client side): each upgrade adds a layer on top of the previous ones.
--   3+ soft aura   5+ smoke from the tip   7+ sparkles + glow light   10+ energy ribbon along the shaft   15 flames
local C = require(script.Parent.Config)

local CueFx = {}
local WHITE = Color3.new(1, 1, 1)
local TAG = "CueFx" -- every effect instance carries this name, so Clear finds them all

local function add(cls, parent, props)
	local e = Instance.new(cls)
	if cls == "ParticleEmitter" then e.LightEmission = 0.6 end
	for k, v in props do e[k] = v end
	e.Name, e.Parent = TAG, parent
	return e
end

function CueFx.Clear(part)
	for _, d in part:GetDescendants() do
		if d.Name == TAG then d:Destroy() end
	end
end

-- part: a cue part (along local Y, 9.2 * k long); cue: a C.Cues entry or C.DragonCue
function CueFx.Apply(part, tier, cue, k)
	CueFx.Clear(part)
	if tier < 3 then return end
	k = k or 1
	local a, b = cue.inlay or cue[4], cue.shaft or cue[4]
	local tip = add("Attachment", part, { Position = Vector3.new(0, 4.4 * k, 0) })
	local grip = add("Attachment", part, { Position = Vector3.new(0, -1.5 * k, 0) })

	add("ParticleEmitter", part, { -- aura along the whole cue
		Color = ColorSequence.new(a, b), Rate = 6 + tier * 2, Lifetime = NumberRange.new(0.5, 0.9),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25 * k), NumberSequenceKeypoint.new(1, 0) }),
		Speed = NumberRange.new(0.2, 0.6), SpreadAngle = Vector2.new(180, 180), Transparency = NumberSequence.new(0.35, 1),
	})
	if tier >= 5 then -- slow smoke curling up from the tip
		add("ParticleEmitter", tip, {
			Color = ColorSequence.new(b:Lerp(WHITE, 0.6), b), LightEmission = 0.1, Rate = 5 + tier,
			Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(0.8, 1.4), Acceleration = Vector3.new(0, 1.2, 0),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3 * k), NumberSequenceKeypoint.new(1, 1.4 * k) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
			RotSpeed = NumberRange.new(-40, 40), Rotation = NumberRange.new(0, 360), Drag = 1,
		})
	end
	if tier >= 7 then -- sparkles + light
		add("ParticleEmitter", part, {
			Color = ColorSequence.new(WHITE, a), LightEmission = 1, Rate = 4 + tier, Lifetime = NumberRange.new(0.3, 0.6),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.22 * k), NumberSequenceKeypoint.new(1, 0) }),
			Speed = NumberRange.new(1, 2.5), SpreadAngle = Vector2.new(180, 180),
		})
		add("PointLight", part, { Color = a, Range = 6 + tier * 0.4, Brightness = 1.4 })
	end
	if tier >= 10 then -- energy ribbon between grip and tip
		add("Beam", part, {
			Attachment0 = grip, Attachment1 = tip, Color = ColorSequence.new(a, b), LightEmission = 1, FaceCamera = true,
			Width0 = 0.55 * k, Width1 = 0.25 * k, Texture = "rbxasset://textures/particles/sparkles_main.dds", TextureSpeed = 2, TextureLength = 2,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 0.6) }),
		})
	end
	if tier >= #C.Cues then -- top tier: flames licking the tip
		add("ParticleEmitter", tip, {
			Color = ColorSequence.new(Color3.fromRGB(255, 240, 160), a), LightEmission = 1, Rate = 40,
			Lifetime = NumberRange.new(0.25, 0.45), Speed = NumberRange.new(2, 4), Acceleration = Vector3.new(0, 6, 0),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45 * k), NumberSequenceKeypoint.new(1, 0) }),
			Texture = "rbxasset://textures/particles/fire_main.dds", SpreadAngle = Vector2.new(25, 25),
		})
	end
end

-- cue definition + tier from a cue part's attributes (set by the server)
function CueFx.Def(tier, dragon)
	return dragon and C.DragonCue or C.Cues[math.clamp(tier, 1, #C.Cues)]
end

return CueFx
