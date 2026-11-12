local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Kinds = require(script.Parent.VehicleKinds)

local VehicleFactory = {}
VehicleFactory.Kinds = Kinds

local GLASS = Color3.fromRGB(70, 98, 130)
local DARK = Color3.fromRGB(30, 30, 36)
local TIRE = Color3.fromRGB(26, 26, 30)
local SILVER = Color3.fromRGB(205, 210, 220)
local HEAD = Color3.fromRGB(255, 246, 210)
local TAIL = Color3.fromRGB(255, 46, 60)
local M = Enum.Material
local CYL = Enum.PartType.Cylinder
local ACROSS = CFrame.Angles(0, math.pi / 2, 0)
local SPORTY = { sport = true, supercar = true, proto = true }
local BOXY = { van = true, truck = true, service = true, minibus = true }

local templateCache = {}

local function newRoot()
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 0.2, 1)
	root.CFrame = CFrame.new()
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Transparency = 1
	return root
end

local function modelsFolder()
	return ReplicatedStorage:FindFirstChild("CarModels")
end

local function hasGeometry(m)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			return true
		end
	end
	return false
end

local function prepareTemplate(tpl, targetL, opts)
	local m = tpl:Clone()
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("JointInstance") or d:IsA("Constraint") or d:IsA("Sound")
			or d:IsA("ProximityPrompt") or d:IsA("ClickDetector") or d:IsA("BodyMover") or d:IsA("Humanoid") then
			d:Destroy()
		end
	end
	m.PrimaryPart = nil
	m.WorldPivot = CFrame.new(m:GetPivot().Position)
	local bb, size = m:GetBoundingBox()
	local alongZ = size.Z > size.X
	local length = math.max(size.X, size.Z, 0.1)
	local scale = targetL / length
	m.WorldPivot = CFrame.new(bb.Position)
	if math.abs(scale - 1) > 1e-3 then
		m:ScaleTo(m:GetScale() * scale)
	end
	local bottom = bb.Position.Y - size.Y * scale / 2
	local yaw = (alongZ and math.pi / 2 or 0) + math.rad(tonumber(tpl:GetAttribute("Yaw")) or 0)
	local root = newRoot()
	root.CFrame = CFrame.new(bb.Position.X, bottom, bb.Position.Z) * CFrame.Angles(0, yaw, 0)
	root.Parent = m
	local recolor = tpl:GetAttribute("Recolor") == true
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			if d:IsA("Seat") or d:IsA("VehicleSeat") then
				d.Disabled = true
			end
			if recolor and opts.BodyColor then
				local n = string.lower(d.Name)
				if string.find(n, "body", 1, true) or string.find(n, "paint", 1, true) then
					d.Color = opts.BodyColor
				end
			end
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = d
			w.Parent = d
		end
	end
	m.PrimaryPart = root
	m:PivotTo(CFrame.new())
	m.Name = "Vehicle"
	m:SetAttribute("RealModel", true)
	m:SetAttribute("Height", size.Y * scale)
	return m
end

local function fromTemplate(key, tpl, targetL, opts)
	local cached = templateCache[key]
	if cached == nil then
		local ok, res = pcall(prepareTemplate, tpl, targetL, opts)
		if ok then
			cached = res
		else
			warn("[CarModels] could not prepare", tpl:GetFullName(), res)
			cached = false
		end
		templateCache[key] = cached
	end
	if cached then
		return cached:Clone()
	end
	return nil
end

local function addNeonGlow(model, k, neon)
	local root = model.PrimaryPart
	local p = Instance.new("Part")
	p.Name = "Underglow"
	p.Size = Vector3.new(k.L * 0.8, 0.15, k.W * 0.85)
	p.CFrame = root.CFrame * CFrame.new(0, 0.25, 0)
	p.Color = neon
	p.Material = M.Neon
	p.Transparency = 0.15
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = p
	w.Parent = p
	p.Parent = model
end

function VehicleFactory.Build(kindName, opts)
	opts = opts or {}
	local k = Kinds[kindName] or Kinds.sedan
	local body = opts.BodyColor or k.color
	local accent = opts.AccentColor or DARK
	local neon = opts.NeonColor
	local low = opts.Low == true
	local sporty = SPORTY[kindName] == true
	local boxy = BOXY[kindName] == true

	local model = Instance.new("Model")
	model.Name = "Vehicle"
	local root = newRoot()
	root.Parent = model
	model.PrimaryPart = root

	local function add(name, size, cf, color, material, transparency, shape, class)
		local p = Instance.new(class or "Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or M.SmoothPlastic
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
		p.CastShadow = not low
		p.Parent = model
		local w = Instance.new("Weld")
		w.Part0 = root
		w.Part1 = p
		w.C0 = cf
		w.Parent = p
		return p
	end
	local function wedge(name, size, cf, color, material, transparency)
		return add(name, size, cf, color, material, transparency, nil, "WedgePart")
	end

	local L, W = k.L, k.W
	local clear, bodyH = k.clear, k.bodyH
	local r = bodyH / 2
	local topY = clear + bodyH
	local midY = clear + r

	local bodyPart = add("Body", Vector3.new(L - bodyH, bodyH, W), CFrame.new(0, midY, 0), body)
	local noseF = add("BodyNose", Vector3.new(W, bodyH, bodyH), CFrame.new(L / 2 - r, midY, 0) * ACROSS, body, nil, 0, CYL)
	local noseB = add("BodyTail", Vector3.new(W, bodyH, bodyH), CFrame.new(-L / 2 + r, midY, 0) * ACROSS, body, nil, 0, CYL)
	if opts.Chrome then
		for _, p in ipairs({ bodyPart, noseF, noseB }) do
			p.Reflectance = 0.35
			p.Material = M.Metal
		end
	end
	add("Skirt", Vector3.new(L - bodyH * 0.6, 0.35, W + 0.06), CFrame.new(0, clear + 0.18, 0), accent)

	local roofTop = topY
	if k.cabinL and k.cabinL > 0 then
		local gh = k.cabinH
		local cw = W * k.cabinW
		local glassColor, glassMat, glassTr = GLASS, M.Glass, 0.15
		if k.canopyNeon and neon then
			glassColor, glassMat, glassTr = neon, M.Neon, 0.35
		end
		local wfK, wrK = 0.28, 0.2
		if sporty then
			wfK, wrK = 0.4, 0.3
		elseif boxy then
			wfK, wrK = 0.14, 0.05
		elseif kindName == "pickup" then
			wfK, wrK = 0.24, 0.06
		end
		local wf, wr = k.cabinL * wfK, k.cabinL * wrK
		local rl = k.cabinL - wf - wr
		local front = k.cabinX + k.cabinL / 2
		local cy = topY + gh / 2
		wedge("Windshield", Vector3.new(cw, gh, wf), CFrame.new(front - wf / 2, cy, 0) * CFrame.Angles(0, -math.pi / 2, 0), glassColor, glassMat, glassTr)
		add("Cabin", Vector3.new(rl, gh, cw), CFrame.new(front - wf - rl / 2, cy, 0), glassColor, glassMat, glassTr)
		if wr > 0.05 then
			wedge("RearGlass", Vector3.new(cw, gh, wr), CFrame.new(front - wf - rl - wr / 2, cy, 0) * CFrame.Angles(0, math.pi / 2, 0), glassColor, glassMat, glassTr)
		end
		add("Roof", Vector3.new(rl + 0.3, 0.3, cw + 0.12), CFrame.new(front - wf - rl / 2, topY + gh + 0.15, 0), body)
		if not low then
			add("PillarF", Vector3.new(0.35, gh, cw + 0.1), CFrame.new(front - wf - 0.17, cy, 0), body)
			add("PillarB", Vector3.new(0.35, gh, cw + 0.1), CFrame.new(front - wf - rl + 0.17, cy, 0), body)
			add("PillarM", Vector3.new(0.3, gh, cw + 0.1), CFrame.new(front - wf - rl / 2, cy, 0), body)
			for _, s in ipairs({ -1, 1 }) do
				add("Mirror", Vector3.new(0.5, 0.4, 0.5), CFrame.new(front - 0.2, topY + 0.3, s * (W / 2 + 0.15)), body)
			end
			local hoodL = L / 2 - front - r * 0.6
			if hoodL > 1.2 and not boxy then
				wedge("Hood", Vector3.new(W * 0.86, 0.35, hoodL), CFrame.new(front + hoodL / 2, topY + 0.17, 0) * CFrame.Angles(0, -math.pi / 2, 0), body)
			end
		end
		roofTop = topY + gh + 0.3
	end

	if k.box then
		add("Cargo", Vector3.new(k.box.L, k.box.H, W * 0.98), CFrame.new(k.box.x, topY + k.box.H / 2, 0), opts.CargoColor or Color3.fromRGB(236, 238, 244))
		if not low then
			add("CargoTrim", Vector3.new(k.box.L + 0.1, 0.3, W + 0.04), CFrame.new(k.box.x, topY + k.box.H - 0.15, 0), accent)
			add("CargoStripe", Vector3.new(k.box.L * 0.9, 0.6, W + 0.02), CFrame.new(k.box.x, topY + k.box.H * 0.45, 0), body)
		end
		roofTop = math.max(roofTop, topY + k.box.H)
	end

	if k.bed then
		local bw = W * 0.92
		add("BedFloor", Vector3.new(k.bed.L, 0.25, bw), CFrame.new(k.bed.x, topY + 0.12, 0), accent)
		add("BedSideL", Vector3.new(k.bed.L, 0.9, 0.3), CFrame.new(k.bed.x, topY + 0.7, bw / 2 - 0.15), body)
		add("BedSideR", Vector3.new(k.bed.L, 0.9, 0.3), CFrame.new(k.bed.x, topY + 0.7, -bw / 2 + 0.15), body)
		add("BedBack", Vector3.new(0.3, 0.9, bw), CFrame.new(k.bed.x - k.bed.L / 2 + 0.15, topY + 0.7, 0), body)
	end

	local axles = { 0.31, -0.31 }
	if k.sixWheels then
		axles = { 0.36, -0.18, -0.34 }
	end
	local rimColor = (neon and not low) and neon or SILVER
	for _, ax in ipairs(axles) do
		for _, sgn in ipairs({ -1, 1 }) do
			local z = sgn * (W / 2 - 0.4)
			local cf = CFrame.new(L * ax, k.wr, z) * ACROSS
			add("Wheel", Vector3.new(1.0, k.wr * 2, k.wr * 2), cf, TIRE, M.SmoothPlastic, 0, CYL)
			add("Rim", Vector3.new(1.06, k.wr * 1.25, k.wr * 1.25), cf, rimColor, M.Metal, 0, CYL)
			if not low then
				add("Hub", Vector3.new(1.12, k.wr * 0.45, k.wr * 0.45), cf, DARK, M.Metal, 0, CYL)
				add("Arch", Vector3.new(k.wr * 2.3, 0.35, 0.5), CFrame.new(L * ax, clear + bodyH * 0.92, sgn * (W / 2 + 0.05)), accent)
			end
		end
	end

	local function noseX(y)
		local dy = y - midY
		return L / 2 - r + math.sqrt(math.max(0, r * r - dy * dy))
	end
	local ly = midY + bodyH * 0.18
	local hx = noseX(ly)
	add("Grille", Vector3.new(0.3, bodyH * 0.38, W * 0.42), CFrame.new(noseX(midY - bodyH * 0.1) - 0.05, midY - bodyH * 0.1, 0), DARK)
	for _, s in ipairs({ -1, 1 }) do
		add("Head", Vector3.new(0.35, bodyH * 0.22, W * 0.2), CFrame.new(hx - 0.05, ly, s * W * 0.32), HEAD, M.Neon)
		add("Tail", Vector3.new(0.35, bodyH * 0.2, W * 0.24), CFrame.new(-hx + 0.05, ly, s * W * 0.3), TAIL, M.Neon)
	end

	if k.taxiSign then
		add("TaxiSign", Vector3.new(1.6, 0.7, 2.6), CFrame.new(k.cabinX, roofTop + 0.35, 0), Color3.fromRGB(255, 255, 220), M.Neon)
	end
	if not low then
		for _, s in ipairs({ -1, 1 }) do
			add("Stripe", Vector3.new(L * 0.62, 0.22, 0.08), CFrame.new(0, clear + bodyH * 0.62, s * (W / 2 + 0.03)), accent)
			add("Handle", Vector3.new(0.6, 0.15, 0.08), CFrame.new(k.cabinX or 0, topY - 0.35, s * (W / 2 + 0.04)), DARK)
		end
		if sporty then
			add("Splitter", Vector3.new(1.0, 0.18, W * 0.96), CFrame.new(L / 2 - 0.4, clear + 0.09, 0), accent)
			for _, s in ipairs({ -1, 1 }) do
				add("Exhaust", Vector3.new(0.6, 0.45, 0.45), CFrame.new(-L / 2 + 0.05, clear + 0.35, s * 1.0), SILVER, M.Metal, 0, CYL)
			end
		end
	end
	if opts.Spoiler then
		for _, s in ipairs({ -1, 1 }) do
			add("WingPost", Vector3.new(0.35, 1.0, 0.35), CFrame.new(-L * 0.42, topY + 0.5, s * W * 0.28), accent)
		end
		add("Wing", Vector3.new(1.6, 0.22, W * 0.98), CFrame.new(-L * 0.42, topY + 1.1, 0), accent)
	end
	if k.fins then
		for _, s in ipairs({ -1, 1 }) do
			wedge("Fin", Vector3.new(0.25, 1.1, 2.6), CFrame.new(-L * 0.36, topY + 0.55, s * W * 0.32) * CFrame.Angles(0, math.pi / 2, 0), accent)
		end
	end
	if neon then
		add("Underglow", Vector3.new(L * 0.8, 0.18, W * 0.9), CFrame.new(0, clear * 0.5, 0), neon, M.Neon, 0.1)
		if not low then
			for _, s in ipairs({ -1, 1 }) do
				add("Glow", Vector3.new(L * 0.66, 0.14, 0.1), CFrame.new(0, clear + bodyH * 0.25, s * (W / 2 + 0.05)), neon, M.Neon)
			end
		end
	end

	model:SetAttribute("Kind", kindName)
	model:SetAttribute("Height", roofTop)
	return model
end

function VehicleFactory.BuildCar(def, opts)
	opts = opts or {}
	local k = Kinds[def.style] or Kinds.sedan
	local folder = modelsFolder()
	local tpl = folder and folder:FindFirstChild(def.id)
	if tpl and tpl:IsA("Model") and hasGeometry(tpl) then
		local m = fromTemplate("car:" .. def.id, tpl, k.L, { BodyColor = def.body })
		if m then
			if def.neon and not opts.Low then
				addNeonGlow(m, k, def.neon)
			end
			return m
		end
	end
	return VehicleFactory.Build(def.style, {
		BodyColor = def.body, AccentColor = def.accent, NeonColor = def.neon, Spoiler = def.spoiler,
		Chrome = def.chrome, Low = opts.Low,
	})
end

function VehicleFactory.BuildTraffic(kindName, color, variant)
	local k = Kinds[kindName] or Kinds.sedan
	if k.special then
		return require(script.Parent.SpecialVehicles).Build(kindName, k.special == "train" and color or nil)
	end
	local folder = modelsFolder()
	local traffic = folder and folder:FindFirstChild("Traffic")
	if traffic then
		local options = {}
		for _, m in ipairs(traffic:GetChildren()) do
			if m:IsA("Model") and (m.Name == kindName or string.sub(m.Name, 1, #kindName + 1) == kindName .. "_") and hasGeometry(m) then
				table.insert(options, m)
			end
		end
		if #options > 0 then
			table.sort(options, function(a, b) return a.Name < b.Name end)
			local tpl = options[((variant or 1) - 1) % #options + 1]
			local m = fromTemplate("traffic:" .. tpl.Name, tpl, k.L, { BodyColor = color })
			if m then
				for _, d in ipairs(m:GetDescendants()) do
					if d:IsA("BasePart") then
						d.CastShadow = false
					end
				end
				return m
			end
		end
	end
	return VehicleFactory.Build(kindName, { BodyColor = color, Low = true })
end

function VehicleFactory.HeightOf(kindName)
	local k = Kinds[kindName] or Kinds.sedan
	return k.H
end

function VehicleFactory.HeightOfModel(model, kindName)
	local h = model and model:GetAttribute("Height")
	if type(h) == "number" then
		return h
	end
	return VehicleFactory.HeightOf(kindName)
end

return VehicleFactory
