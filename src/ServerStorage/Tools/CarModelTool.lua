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
