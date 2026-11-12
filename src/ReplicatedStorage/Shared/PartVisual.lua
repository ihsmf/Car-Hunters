local PartConfig = require(script.Parent.PartConfig)

local PartVisual = {}

local METAL = Color3.fromRGB(90, 96, 108)
local SILVER = Color3.fromRGB(205, 210, 220)
local DARK = Color3.fromRGB(30, 30, 34)

-- clone a template's parts into model, scaled so its longest side = size, centred on root, welded
function PartVisual.FromTemplate(model, root, tpl, size)
	local c = tpl:Clone()
	local _, ext = c:GetBoundingBox()
	c:ScaleTo(c:GetScale() * size / math.max(ext.X, ext.Y, ext.Z, 0.01))
	local cf2 = c:GetBoundingBox()
	local n = 0
	for _, p in ipairs(c:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CFrame = cf2:Inverse() * p.CFrame -- centre on origin
			p.Anchored = false
			local w = Instance.new("Weld")
			w.Part0, w.Part1, w.C0 = root, p, p.CFrame
			w.Parent = p
			p.Parent = model
			n = n + 1
		end
	end
	c:Destroy()
	return n > 0
end

-- tuning part showcase model (Tony's counter, reveal)
function PartVisual.BuildTuning(family, size)
	local folder = game:GetService("ReplicatedStorage"):FindFirstChild("PartModels")
	local tpl = folder and folder:FindFirstChild("Tune_" .. family)
	if not tpl then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Tune_" .. family
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one
	root.Anchored, root.CanCollide, root.CanQuery, root.CanTouch = true, false, false, false
	root.Transparency = 1
	root.Parent = model
	model.PrimaryPart = root
	PartVisual.FromTemplate(model, root, tpl, size or 3)
	return model
end

function PartVisual.Build(partId)
	local def = PartConfig.Parts[partId] or PartConfig.Parts.bolts
	local col = def.color

	local model = Instance.new("Model")
	model.Name = "Drop_" .. def.id

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.CFrame = CFrame.new(0, 0, 0)
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Transparency = 1
	root.Parent = model
	model.PrimaryPart = root

	local function add(name, size, cf, color, material, transparency, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Transparency = transparency or 0
		if shape then
			p.Shape = shape
		end
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		p.Parent = model
		local w = Instance.new("Weld")
		w.Part0 = root
		w.Part1 = p
		w.C0 = cf
		w.Parent = p
		return p
	end

	local CYL = Enum.PartType.Cylinder
	local BALL = Enum.PartType.Ball
	local upright = CFrame.Angles(0, 0, math.pi / 2)

	-- imported Blender model (blender/make_parts.py) when installed, procedural fallback otherwise
	local folder = game:GetService("ReplicatedStorage"):FindFirstChild("PartModels")
	local tpl = folder and folder:FindFirstChild("Part_" .. def.id)
	if tpl and PartVisual.FromTemplate(model, root, tpl, 3.2) then
		-- template parts added; glow/particles below still apply
	elseif def.id == "bolts" then
		add("Nut", Vector3.new(0.9, 2.0, 2.0), upright, SILVER, Enum.Material.Metal, 0, CYL)
		add("NutGlow", Vector3.new(0.95, 1.2, 1.2), upright, col, Enum.Material.Neon, 0, CYL)
		add("Shaft", Vector3.new(2.2, 0.8, 0.8), CFrame.new(0, -1.5, 0) * upright, METAL, Enum.Material.Metal, 0, CYL)
	elseif def.id == "tire" then
		add("Tire", Vector3.new(1.4, 3.4, 3.4), CFrame.new(), DARK, Enum.Material.SmoothPlastic, 0, CYL)
		add("Hub", Vector3.new(1.5, 1.7, 1.7), CFrame.new(), SILVER, Enum.Material.Metal, 0, CYL)
		add("HubGlow", Vector3.new(1.55, 0.8, 0.8), CFrame.new(), col, Enum.Material.Neon, 0, CYL)
	elseif def.id == "engine" then
		add("Block", Vector3.new(3.2, 2.0, 2.2), CFrame.new(), METAL, Enum.Material.Metal)
		for i = -1, 1 do
			add("Piston", Vector3.new(0.9, 0.9, 0.9), CFrame.new(i * 1.0, 1.4, 0) * upright, SILVER, Enum.Material.Metal, 0, CYL)
		end
		add("Strip", Vector3.new(3.25, 0.35, 2.25), CFrame.new(0, -0.2, 0), col, Enum.Material.Neon)
	elseif def.id == "turbo" then
		add("Housing", Vector3.new(2.2, 2.8, 2.8), CFrame.new(), col, Enum.Material.Metal, 0, CYL)
		add("Inlet", Vector3.new(1.2, 1.7, 1.7), CFrame.new(1.6, 0, 0), SILVER, Enum.Material.Metal, 0, CYL)
		add("InletGlow", Vector3.new(0.4, 1.2, 1.2), CFrame.new(2.2, 0, 0), col, Enum.Material.Neon, 0, CYL)
		add("Pipe", Vector3.new(1.4, 0.8, 0.8), CFrame.new(-0.2, 1.8, 0) * upright, METAL, Enum.Material.Metal, 0, CYL)
	else
		add("Core", Vector3.new(2.4, 2.4, 2.4), CFrame.new(), col, Enum.Material.Neon, 0, BALL)
		add("RingA", Vector3.new(0.18, 4.0, 4.0), CFrame.new(), SILVER, Enum.Material.Metal, 0.1, CYL)
		add("RingB", Vector3.new(0.18, 4.0, 4.0), CFrame.Angles(0, math.pi / 2, 0), SILVER, Enum.Material.Metal, 0.1, CYL)
	end

	add("Halo", Vector3.new(0.15, 5.5, 5.5), CFrame.new(0, -2.55, 0) * upright, col, Enum.Material.SmoothPlastic, 0.25, CYL)
	add("HaloCore", Vector3.new(0.17, 4.3, 4.3), CFrame.new(0, -2.55, 0) * upright, Color3.fromRGB(30, 32, 38), Enum.Material.SmoothPlastic, 0.25, CYL)

	if def.rarity == "Epic" or def.rarity == "Legendary" then
		local pe = Instance.new("ParticleEmitter")
		pe.Color = ColorSequence.new(col)
		pe.Rate = (def.rarity == "Legendary") and 10 or 5
		pe.Lifetime = NumberRange.new(1, 1.6)
		pe.Speed = NumberRange.new(2, 4)
		pe.Size = NumberSequence.new(0.5, 0)
		pe.LightEmission = 1
		pe.Parent = root
	end
	if def.rarity == "Legendary" then
		local light = Instance.new("PointLight")
		light.Color = col
		light.Range = 14
		light.Brightness = 1.5
		light.Parent = root
	end

	model:SetAttribute("PartId", def.id)
	return model
end

return PartVisual
