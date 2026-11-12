-- Loads the Blender models that tools/roblox_open_cloud.py uploaded (ids in Shared/ModelIds.lua), styles their meshes
-- by look name and installs them where the game looks for them:
--   spawn models + street props -> ServerStorage.BuilderAssets.Props   (map builder, Prefabs.FromTemplate)
--   pickup / tuning parts       -> ReplicatedStorage.PartModels        (PartVisual, WheelKit)
-- Must run before the map is built. Anything that fails to load keeps the procedural fallback.
local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Looks = require(Shared:WaitForChild("ModelLooks"))

local ModelService = {}

local function ensure(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

local function style(model, anchored)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local key = string.match(d.Name, "^(%a+)") or ""
			local look = Looks[key]
			if look then
				d.Name = key
				d.Material, d.Color, d.Reflectance, d.Transparency = look[1], look[2], look[3], look[4]
				d.CanCollide = look[5] ~= false
			end
			d.Anchored = anchored
			d.CastShadow = key ~= "Glow" and key ~= "Glass" and key ~= "Water"
			d.TopSurface, d.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		end
	end
end

-- pivot at the bottom centre, or (spawn models) back on the Blender origin; info = { size, c = bbox centre offset }
local function normalize(model, info)
	local bb, ext = model:GetBoundingBox()
	if info and info.size then
		local cur = math.max(ext.X, ext.Y, ext.Z)
		if cur > 0.01 and math.abs(cur / info.size - 1) > 0.02 then
			model.WorldPivot = bb
			model:ScaleTo(model:GetScale() * info.size / cur)
			bb, ext = model:GetBoundingBox()
		end
	end
	if info and info.c then
		model.WorldPivot = CFrame.new(bb.Position - Vector3.new(info.c[1], info.c[2], info.c[3]))
	else
		model.WorldPivot = CFrame.new(bb.Position - Vector3.new(0, ext.Y / 2, 0))
	end
end

-- the imported FBX root: the first Model under the inserted container (or a Model wrapping its parts)
local function rootOf(container, name)
	local m = container:FindFirstChildWhichIsA("Model")
	if not m then
		m = Instance.new("Model")
		for _, c in ipairs(container:GetChildren()) do
			c.Parent = m
		end
	end
	m.Name = name
	return m
end

local function install(dest, m)
	local old = dest:FindFirstChild(m.Name)
	if old then
		old:Destroy()
	end
	m.Parent = dest
end

function ModelService.LoadAll()
	local okIds, ids = pcall(require, Shared:WaitForChild("ModelIds"))
	if not okIds or type(ids) ~= "table" then
		return 0
	end
	local okSizes, sizes = pcall(require, Shared:WaitForChild("ModelSizes"))
	sizes = okSizes and sizes or {}
	local props = ensure(ensure(ServerStorage, "BuilderAssets"), "Props")
	local partModels = ensure(ReplicatedStorage, "PartModels")
	local n = 0
	local stats = { embedded = 0, downloaded = 0, missing = {} }
	for name, id in pairs(ids) do
		if id and id > 0 then
			-- 1) embedded in the place file (tools/bake_models.luau)  2) LoadAsset (needs the game owner to own the asset)
			local emb = ServerStorage:FindFirstChild("Embedded")
			emb = emb and emb:FindFirstChild("Assets") and emb.Assets:FindFirstChild("A" .. tostring(id))
			local ok, res
			if emb then
				ok, res = true, emb:Clone()
				stats.embedded = stats.embedded + 1
			else
				ok, res = pcall(function()
					return InsertService:LoadAsset(id)
				end)
				if ok and res then
					stats.downloaded = stats.downloaded + 1
				end
			end
			if ok and res then
				if name == "PartsKit" or name == "PropsKit" then
					for _, m in ipairs(res:GetDescendants()) do
						if m:IsA("Model") and (string.match(m.Name, "^Part_") or string.match(m.Name, "^Tune_") or m.Name == "TireStack" or m.Name == "Cone" or m.Name == "Hydrant") then
							local part = name == "PartsKit"
							style(m, not part)
							if part then
								for _, d in ipairs(m:GetDescendants()) do
									if d:IsA("BasePart") then
										d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = false, false, false, false
									end
								end
							end
							normalize(m)
							install(part and partModels or props, m)
							n = n + 1
						end
					end
				else
					local m = rootOf(res, name)
					style(m, true)
					normalize(m, sizes[name])
					install(props, m)
					n = n + 1
				end
				res:Destroy()
			else
				table.insert(stats.missing, name)
				warn(string.format("[Models] %s (%s) did not load: %s", name, tostring(id), tostring(res)))
			end
		end
	end
	print(string.format("[Models] %d Blender models installed (embedded %d, downloaded %d)%s", n, stats.embedded, stats.downloaded,
		#stats.missing > 0 and ("  MISSING: " .. table.concat(stats.missing, ", ")) or ""))
	return n
end

return ModelService
