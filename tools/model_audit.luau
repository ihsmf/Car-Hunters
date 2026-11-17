-- Offline audit of the car models in the BUILT place (v25):
--   lune run tools/model_audit.luau [CarHunters.rbxl]
-- Runs the real ServerStorage.Tools.CarStoreTool.InstallMissingEmbedded (the same code the server runs at start)
-- against the embedded assets, then checks every CarConfig car (List + Exclusive):
--   * a model is installed (no procedural fallback body)
--   * no visible MeshPart without a mesh (the "textured cube": legacy MeshID lost when baking)
--   * the proportions pass (CarStoreTool.ProportionsOk)
-- Prints one line per car and exits 1 when any car fails.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local placePath = process.args[1] or "CarHunters.rbxl"
local CF, V3 = roblox.CFrame, roblox.Vector3

---------------------------------------------------------------- the bits of the engine lune does not have
local function parts(m)
	local t = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(t, d)
		end
	end
	return t
end
local function bbox(m)
	local mn, mx = V3.new(math.huge, math.huge, math.huge), V3.new(-math.huge, -math.huge, -math.huge)
	for _, p in parts(m) do
		local cf, h = p.CFrame, p.Size / 2
		local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
		local e = V3.new(
			math.abs(r.X) * h.X + math.abs(u.X) * h.Y + math.abs(l.X) * h.Z,
			math.abs(r.Y) * h.X + math.abs(u.Y) * h.Y + math.abs(l.Y) * h.Z,
			math.abs(r.Z) * h.X + math.abs(u.Z) * h.Y + math.abs(l.Z) * h.Z
		)
		mn = V3.new(math.min(mn.X, cf.Position.X - e.X), math.min(mn.Y, cf.Position.Y - e.Y), math.min(mn.Z, cf.Position.Z - e.Z))
		mx = V3.new(math.max(mx.X, cf.Position.X + e.X), math.max(mx.Y, cf.Position.Y + e.Y), math.max(mx.Z, cf.Position.Z + e.Z))
	end
	if mn.X == math.huge then
		return CF.new(), V3.new()
	end
	return CF.new((mn + mx) / 2), mx - mn
end
-- lune cannot assign nil to a Ref property: CarStoreTool's "car.PrimaryPart = nil" is rewritten to __clearPrimary(car)
local noPrimary = setmetatable({}, { __mode = "k" })
local function getPivot(m)
	if m:IsA("BasePart") then
		return m.CFrame
	end
	local pp = not noPrimary[m] and m:IsA("Model") and m.PrimaryPart
	if pp then
		return pp.CFrame
	end
	local okp, wp = pcall(function()
		return m.WorldPivot
	end)
	if okp and wp then
		return wp
	end
	return (bbox(m))
end
for _, cls in { "Model", "Folder", "WorldModel" } do
	pcall(roblox.implementMethod, cls, "GetBoundingBox", function(self)
		return bbox(self)
	end)
	pcall(roblox.implementMethod, cls, "GetPivot", getPivot)
	pcall(roblox.implementMethod, cls, "PivotTo", function(self, cf)
		local delta = cf * getPivot(self):Inverse()
		for _, p in parts(self) do
			p.CFrame = delta * p.CFrame
		end
		pcall(function()
			self.WorldPivot = cf
		end)
	end)
	pcall(roblox.implementMethod, cls, "GetScale", function()
		return 1
	end)
	pcall(roblox.implementMethod, cls, "ScaleTo", function() end)
end
roblox.implementMethod("Instance", "WaitForChild", function(self, n)
	return self:FindFirstChild(n)
end)

---------------------------------------------------------------- load the place and run CarStoreTool from its own sources
local game = roblox.deserializePlace(fs.readFile(placePath))
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local emb = SS:FindFirstChild("Embedded")
emb = emb and emb:FindFirstChild("Assets")
if not emb then
	print("[audit] FAIL: no ServerStorage.Embedded.Assets in " .. placePath)
	process.exit(1)
end
local gameProxy = setmetatable({
	GetService = function(_, n)
		return game:GetService(n)
	end,
	GetObjects = function()
		error("offline")
	end,
}, {
	__index = function(_, k)
		return game[k]
	end,
})
local cache = {}
local function req(m)
	if cache[m] ~= nil then
		return cache[m]
	end
	local env = setmetatable({ script = m, require = req, game = gameProxy, workspace = game:GetService("Workspace") }, { __index = _G })
	for _, k in { "Color3", "Vector3", "Vector2", "CFrame", "UDim2", "UDim", "Enum", "Instance", "ColorSequence", "ColorSequenceKeypoint", "NumberSequence", "NumberSequenceKeypoint", "NumberRange", "Rect", "BrickColor", "TweenInfo", "PhysicalProperties", "Ray", "Font", "Region3", "Faces", "Axes", "Random" } do
		env[k] = roblox[k]
	end
	env.warn = function(...)
		print("  warn:", ...)
	end
	env.print = function() end -- CarStoreTool's own progress lines
	env.task = { wait = function() end, spawn = function(f, ...)
		f(...)
	end, delay = function() end, defer = function(f, ...)
		f(...)
	end }
	env.typeof = function(v)
		return typeof(v)
	end
	env.__clearPrimary = function(model)
		noPrimary[model] = true
	end
	-- BasePart.Position has no stored value in lune: read it from the CFrame (only reads occur in these modules)
	env.__pos = function(x)
		if typeof(x) == "Instance" then
			return x.CFrame.Position
		end
		return x.Position
	end
	local src = string.gsub(m.Source, "([%w_]+)%.PrimaryPart = nil", "__clearPrimary(%1)")
	src = string.gsub(src, "([%w_]+)%.Position", "__pos(%1)")
	local fn = luau.load(src, { debugName = m.Name, environment = env })
	local res = fn()
	cache[m] = res
	return res
end
local CarConfig = req(RS.Shared.CarConfig)
local Tool = req(SS.Tools.CarStoreTool)

-- models that came with the place (Blender / hand-made) are kept as the server would keep them
local installedBefore = {}
local cm = RS:FindFirstChild("CarModels")
for _, m in (cm and cm:GetChildren() or {}) do
	installedBefore[m.Name] = true
end
local ok, err = pcall(Tool.InstallMissingEmbedded)
if not ok then
	print("[audit] FAIL: InstallMissingEmbedded errored: " .. tostring(err))
	process.exit(1)
end

---------------------------------------------------------------- checks
local function meshOf(p)
	for _, n in { "MeshContent", "MeshId" } do
		local okp, v = pcall(function()
			return p[n]
		end)
		if okp and v ~= nil then
			local s = tostring(v)
			if s == "Content(None)" or s == "" then
				return ""
			end
			return s
		end
	end
	return ""
end
local failed = 0
local cars = Tool.AllCars()
cm = RS:FindFirstChild("CarModels")
for _, def in cars do
	local m = cm and cm:FindFirstChild(def.id)
	local problems = {}
	local info = ""
	if not (m and m:FindFirstChildWhichIsA("BasePart", true)) then
		table.insert(problems, "PROCEDURAL fallback (no model installed; candidates: " .. table.concat(Tool.Candidates[def.id] or {}, ",") .. ")")
	else
		local vis, meshless = 0, {}
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 0.99 then
				vis += 1
				if d:IsA("MeshPart") and meshOf(d) == "" then
					table.insert(meshless, d.Name)
				end
			end
		end
		if #meshless > 0 then
			table.insert(problems, string.format("%d visible meshless MeshPart(s) (renders as boxes): %s", #meshless, table.concat(meshless, ", ", 1, math.min(#meshless, 5))))
		end
		local _, size = m:GetBoundingBox()
		if not installedBefore[def.id] and not Tool.ProportionsOk(size, vis) then
			table.insert(problems, string.format("bad proportions %.0fx%.0fx%.0f", size.Z, size.X, size.Y))
		end
		info = string.format("%s  %d visible, %.0fx%.0fx%.0f", installedBefore[def.id] and "place model" or ("asset " .. tostring(m:GetAttribute("StoreAssetId"))), vis, size.Z, size.X, size.Y)
	end
	if #problems > 0 then
		failed += 1
		print(string.format("[audit] FAIL %-22s %s | %s", def.id, info, table.concat(problems, "; ")))
	else
		print(string.format("[audit] ok   %-22s %s", def.id, info))
	end
end
print(string.format("[audit] %d cars, %d failing", #cars, failed))
process.exit(failed == 0 and 0 or 1)
