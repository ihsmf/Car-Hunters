local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarConfig = require(Shared:WaitForChild("CarConfig"))
local VehicleKinds = require(Shared:WaitForChild("VehicleKinds"))

local Tool = {}

local function ensure(parent, class, name)
	local o = parent:FindFirstChild(name)
	if not o then
		o = Instance.new(class)
		o.Name = name
		o.Parent = parent
	end
	return o
end

local function filled(m)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			return true
		end
	end
	return false
end

function Tool.Setup()
	local root = ensure(ReplicatedStorage, "Folder", "CarModels")
	for _, def in ipairs(CarConfig.List) do
		local m = ensure(root, "Model", def.id)
		m:SetAttribute("CarName", def.name)
		m:SetAttribute("Rarity", def.rarity)
		if m:GetAttribute("Yaw") == nil then
			m:SetAttribute("Yaw", 0)
		end
	end
	local traffic = ensure(root, "Folder", "Traffic")
	for kind in pairs(VehicleKinds) do
		local m = ensure(traffic, "Model", kind)
		if m:GetAttribute("Yaw") == nil then
			m:SetAttribute("Yaw", 0)
		end
	end
	Tool.Status()
end

function Tool.Status()
	local root = ReplicatedStorage:FindFirstChild("CarModels")
	if not root then
		print("[CarModels] folder missing - run Setup()")
		return
	end
	local done, missing = 0, {}
	for _, def in ipairs(CarConfig.List) do
		local m = root:FindFirstChild(def.id)
		if m and filled(m) then
			done = done + 1
		else
			table.insert(missing, def.id)
		end
	end
	print(string.format("[CarModels] collection: %d/%d real models", done, #CarConfig.List))
	if #missing > 0 then
		print("[CarModels] procedural fallback for: " .. table.concat(missing, ", "))
	end
end

-- Blender pipeline: import assets/cars/cars_collection.fbx and cars_traffic.fbx with File > Import 3D
-- (they land in Workspace), then run in the Command Bar:
--   require(game.ServerStorage.Tools.CarModelTool).ApplyImported()
local C = Color3.fromRGB
local LOOK = {
	Body = { Enum.Material.SmoothPlastic, nil, 0, 0.05 },
	Glass = { Enum.Material.Glass, C(18, 26, 34), 0.05, 0.25 },
	Stripe = { Enum.Material.SmoothPlastic, nil, 0, 0.05 },
	Caliper = { Enum.Material.SmoothPlastic, C(220, 40, 40), 0, 0 },
	Plate = { Enum.Material.SmoothPlastic, C(236, 236, 230), 0, 0 },
	Trim = { Enum.Material.SmoothPlastic, C(22, 22, 26), 0, 0 },
	Chrome = { Enum.Material.Metal, C(222, 224, 232), 0, 0.35 },
	Tire = { Enum.Material.SmoothPlastic, C(22, 22, 26), 0, 0 },
	Rim = { Enum.Material.Metal, C(192, 196, 204), 0, 0.2 },
	HeadLight = { Enum.Material.Neon, C(255, 246, 210), 0, 0 },
	TailLight = { Enum.Material.Neon, C(255, 40, 50), 0, 0 },
	Neon = { Enum.Material.Neon, nil, 0, 0 },
	Cargo = { Enum.Material.SmoothPlastic, C(240, 240, 244), 0, 0 },
}
local PROP_LOOK = {
	Rubber = { Enum.Material.SmoothPlastic, C(28, 28, 32) }, Orange = { Enum.Material.SmoothPlastic, C(255, 130, 30) },
	White = { Enum.Material.SmoothPlastic, C(245, 245, 245) }, Red = { Enum.Material.SmoothPlastic, C(225, 50, 50) },
	Metal = { Enum.Material.Metal, C(180, 184, 190) }, Yellow = { Enum.Material.SmoothPlastic, C(255, 210, 63) },
}
local PROPS = { TireStack = true, Cone = true, Hydrant = true }

local function installProp(m)
	local assets = ensure(game:GetService("ServerStorage"), "Folder", "BuilderAssets")
	local props = ensure(assets, "Folder", "Props")
	local old = props:FindFirstChild(m.Name)
	if old then
		old:Destroy()
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			local look = PROP_LOOK[string.match(d.Name, "^(%a+)") or ""]
			if look then
				d.Material, d.Color = look[1], look[2]
			end
			d.Anchored = true
		end
	end
	local bb, size = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(bb.Position - Vector3.new(0, size.Y / 2, 0))
	m.Parent = props
end

local function styleCar(model, def)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local key = string.match(d.Name, "^(%a+)") or d.Name
			local look = LOOK[key]
			if look then
				d.Name = key
				d.Material = look[1]
				d.Transparency = look[3]
				d.Reflectance = look[4]
				if look[2] then
					d.Color = look[2]
				elseif key == "Body" then
					d.Color = def and def.body or Color3.fromRGB(220, 60, 60)
					if def and def.chrome then
						d.Material = Enum.Material.Metal
						d.Reflectance = 0.4
					end
				elseif key == "Stripe" then
					local b = def and def.body or Color3.new(1, 0, 0)
					d.Color = (b.R + b.G + b.B < 1.9) and C(242, 242, 242) or C(14, 14, 16)
				elseif key == "Neon" then
					d.Color = def and def.neon or Color3.fromRGB(40, 230, 255)
				end
			end
			d.Anchored = false
			d.CanCollide = false
			d.CastShadow = key ~= "Glass" and key ~= "Neon"
			if d:IsA("MeshPart") then
				d.RenderFidelity = Enum.RenderFidelity.Automatic
			end
		end
	end
end

function Tool.ApplyImported(container)
	local root = ensure(ReplicatedStorage, "Folder", "CarModels")
	local traffic = ensure(root, "Folder", "Traffic")
	local sources = container and { container } or Workspace:GetChildren()
	local moved = 0
	for _, src in ipairs(sources) do
		for _, m in ipairs(src:GetDescendants()) do
			if m:IsA("Model") then
				if PROPS[m.Name] then
					installProp(m)
					moved = moved + 1
					continue
				end
				local def = CarConfig.ById[m.Name]
				local dest = def and root or (VehicleKinds[m.Name] and traffic) or nil
				if dest then
					local old = dest:FindFirstChild(m.Name)
					if old then
						old:Destroy()
					end
					styleCar(m, def)
					m:SetAttribute("Yaw", 0)
					m:SetAttribute("Recolor", def == nil)
					if def then
						m:SetAttribute("CarName", def.name)
						m:SetAttribute("Rarity", def.rarity)
					end
					m.Parent = dest
					moved = moved + 1
				end
			end
		end
	end
	print(string.format("[CarModels] ApplyImported: %d models installed", moved))
	Tool.Status()
end

function Tool.Preview()
	local VehicleFactory = require(Shared:WaitForChild("VehicleFactory"))
	local old = Workspace:FindFirstChild("CarModelPreview")
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "CarModelPreview"
	f.Parent = Workspace
	for i, def in ipairs(CarConfig.List) do
		local m = VehicleFactory.BuildCar(def)
		m.Name = def.id
		m:PivotTo(CFrame.new(-190 + ((i - 1) % 10) * 40, 0.5, 30 + math.floor((i - 1) / 10) * 30))
		m.Parent = f
	end
	print("[CarModels] preview built in Workspace.CarModelPreview (nose points +X). Fix direction with the Yaw attribute.")
end

function Tool.ClearPreview()
	local old = Workspace:FindFirstChild("CarModelPreview")
	if old then
		old:Destroy()
	end
end

return Tool
