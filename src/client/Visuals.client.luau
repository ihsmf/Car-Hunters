-- Swaps every part tagged with a "Mesh" StringValue for the matching Blender mesh (Shared/Meshes).
-- "MeshPivot" parts stand for a whole part-built model: the model is hidden locally and the mesh is
-- welded to the pivot. Any other tagged part (NPC cue sticks, decorative balls) is replaced 1:1.
-- If EditableMesh is unavailable the part-built models simply stay visible.
local RS = game:GetService("ReplicatedStorage")
local MeshBuilder = require(RS.Shared.MeshBuilder)

local function hide(p)
	p.LocalTransparencyModifier = 1
end

local function apply(tag)
	task.wait() -- let sibling override values replicate
	local p = tag.Parent
	if not (p and p:IsA("BasePart")) or p:FindFirstChild("MeshVisual") then return end
	local overrides
	for _, v in p:GetChildren() do
		if v:IsA("Color3Value") then
			overrides = overrides or {}
			overrides[v.Name] = v.Value
		end
	end
	local scaleValue = p:FindFirstChild("Scale")
	local mp = MeshBuilder.Create(tag.Value, p.CFrame, overrides, scaleValue and scaleValue.Value)
	if not mp or not p.Parent then
		if mp then mp:Destroy() end
		return
	end
	mp.Name, mp.Anchored, mp.Massless = "MeshVisual", false, true
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1, weld.Parent = p, mp, mp
	mp.Parent = p
	if p.Name == "MeshPivot" then
		for _, d in p.Parent:GetDescendants() do
			if d:IsA("BasePart") and d ~= p and not d:IsDescendantOf(p) then hide(d) end
		end
	else
		hide(p)
	end
end

local function check(inst)
	if inst.Name == "Mesh" and inst:IsA("StringValue") then task.spawn(apply, inst) end
end

local world = workspace:WaitForChild("World")
for _, d in world:GetDescendants() do check(d) end
world.DescendantAdded:Connect(check)
