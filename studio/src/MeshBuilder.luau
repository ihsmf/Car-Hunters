-- Turns Blender mesh data (Shared/Meshes/<Name>) into MeshParts via EditableMesh — no asset upload needed.
-- Client-side only (EditableMesh content does not replicate). Falls back gracefully when unavailable.
local AssetService = game:GetService("AssetService")
local MeshFolder = script.Parent:WaitForChild("Meshes") -- one ModuleScript per Blender model
local Meshes = setmetatable({}, {
	__index = function(t, name)
		local m = MeshFolder:FindFirstChild(name)
		local data = m and require(m)
		rawset(t, name, data or false)
		return data or false
	end,
})

local MeshBuilder = {}
local cache = {}
local supported = true

-- overrides: { [paletteName]: Color3 } recolours a material (e.g. ball body, fence caps, cue shaft)
local function editable(name, overrides)
	local key = name
	if overrides then
		for k, c in overrides do key ..= "|" .. k .. c:ToHex() end
	end
	if cache[key] then return cache[key] end
	local data = Meshes[name]
	local em = AssetService:CreateEditableMesh()
	local colorIds = {}
	for i, entry in data.palette do
		colorIds[i] = em:AddColor((overrides and overrides[entry[1]]) or entry[2], 1)
	end
	local v = data.verts
	local front, back = {}, {}
	for i = 1, #v, 3 do
		local p = Vector3.new(v[i], v[i + 1], v[i + 2])
		local n = (i + 2) // 3
		front[n] = em:AddVertex(p)
		back[n] = em:AddVertex(p) -- separate copy for the back side, so the mesh renders with either winding
	end
	local normalsF, normalsB = {}, {}
	for n = 1, #front do
		normalsF[n] = em:AddNormal()
		normalsB[n] = em:AddNormal()
	end
	local t = data.tris
	for f = 1, #data.colors do
		local a, b, c = t[f * 3 - 2], t[f * 3 - 1], t[f * 3]
		local col = colorIds[data.colors[f]]
		local f1 = em:AddTriangle(front[a], front[b], front[c])
		em:SetFaceNormals(f1, { normalsF[a], normalsF[b], normalsF[c] })
		em:SetFaceColors(f1, { col, col, col })
		local f2 = em:AddTriangle(back[a], back[c], back[b])
		em:SetFaceNormals(f2, { normalsB[a], normalsB[c], normalsB[b] })
		em:SetFaceColors(f2, { col, col, col })
	end
	cache[key] = em
	return em
end

-- Uploaded meshes (tools/meshassets.py): ReplicatedStorage.MeshAssets.<Name> holds one MeshPart per colour slot,
-- posed around the model origin. Cloning them is instant and works everywhere (no EditableMesh needed).
local Assets = game:GetService("ReplicatedStorage"):FindFirstChild("MeshAssets")
local FOLLOW = { "Material", "Reflectance", "Transparency", "LocalTransparencyModifier", "CastShadow" }

local function fromAssets(name, cf, overrides, scale)
	local template = Assets and Assets:FindFirstChild(name)
	if not template then return nil end
	local s = scale or 1
	local pieces, root = {}, nil
	for _, t in template:GetChildren() do
		if t:IsA("MeshPart") then
			local p = t:Clone()
			local slot = p:GetAttribute("Slot")
			if overrides and overrides[slot] then p.Color = overrides[slot] end
			pieces[#pieces + 1] = { p, t:GetAttribute("Offset") * s, t.Size * s }
			if not root or t:GetAttribute("Volume") > root[1]:GetAttribute("Volume") then root = pieces[#pieces] end
		end
	end
	if not root then return nil end
	local rp = root[1]
	rp.Size, rp.CFrame = root[3], cf * CFrame.new(root[2])
	rp.Anchored, rp.CanCollide, rp.CanQuery, rp.CanTouch = true, false, false, false
	rp.Name = name
	local subs = {}
	for _, e in pieces do
		if e ~= root then
			local p = e[1]
			p.Size, p.CFrame = e[3], cf * CFrame.new(e[2])
			p.Anchored, p.Massless, p.CanCollide, p.CanQuery, p.CanTouch = false, true, false, false, false
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1, weld.Parent = rp, p, p
			p.Parent = rp
			subs[p] = rp.CFrame:ToObjectSpace(p.CFrame)
		end
	end
	-- the first piece stands for the whole model: the welds carry the others along when it moves, and a size change
	-- (e.g. Visuals' WideScale or a script) is passed on with the welds briefly released
	local base = rp.Size
	for p in subs do p:SetAttribute("BaseSize", p.Size) end
	rp:GetPropertyChangedSignal("Size"):Connect(function()
		local k = rp.Size / base
		for p, rel in subs do
			local w = p:FindFirstChildOfClass("WeldConstraint")
			if w then w.Enabled = false end
			p.Size = p:GetAttribute("BaseSize") * k
			p.CFrame = rp.CFrame * CFrame.new(rel.Position * k) * rel.Rotation
			if w then w.Enabled = true end
		end
	end)
	for _, prop in FOLLOW do
		rp:GetPropertyChangedSignal(prop):Connect(function()
			for p in subs do p[prop] = rp[prop] end
		end)
	end
	return rp
end

-- Returns a MeshPart whose model origin is `cf` (or nil if the mesh is unavailable). Extra colour pieces of an
-- uploaded mesh are children of the returned part and follow it.
function MeshBuilder.Create(name, cf, overrides, scale)
	local asset = fromAssets(name, cf, overrides, scale)
	if asset then return asset end
	if not supported or not Meshes[name] then return nil end
	local ok, part = pcall(function()
		local mp = AssetService:CreateMeshPartAsync(Content.fromObject(editable(name, overrides)))
		local s = scale or 1
		mp.Size = Meshes[name].size * s
		mp.CFrame = cf * CFrame.new(Meshes[name].center * s)
		mp.Anchored, mp.CanCollide, mp.CanQuery, mp.CanTouch = true, false, false, false
		mp.Color = Color3.new(1, 1, 1)
		mp.Material = Enum.Material.SmoothPlastic
		mp.Name = name
		return mp
	end)
	if not ok then
		supported = false
		warn("[MeshBuilder] EditableMesh unavailable, using part models:", part)
		return nil
	end
	return part
end

return MeshBuilder
