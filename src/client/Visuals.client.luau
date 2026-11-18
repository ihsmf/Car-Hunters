-- Swaps every part tagged with a "Mesh" StringValue for the matching Blender mesh (Shared/Meshes).
-- "MeshPivot" parts stand for a whole part-built model: the model is hidden locally and the mesh is
-- welded to the pivot. Any other tagged part (cues, rings, the gym dumbbell) is replaced 1:1.
-- Colour/scale values under a tagged part rebuild its mesh when they change (dumbbell level, cue tier).
-- Also: cue tier effects (Shared/CueFx), spinning aura rings, rainbow characters.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local MeshBuilder = require(RS.Shared.MeshBuilder)
local CueFx = require(RS.Shared.CueFx)

local function hide(p)
	p.LocalTransparencyModifier = 1
end

local function apply(tag)
	task.wait() -- let sibling override values replicate
	local p = tag.Parent
	if not (p and p:IsA("BasePart")) then return end
	local old = p:FindFirstChild("MeshVisual")
	if old then old:Destroy() end
	local overrides
	for _, v in p:GetChildren() do
		if v:IsA("Color3Value") then
			overrides = overrides or {}
			overrides[v.Name] = v.Value
		end
	end
	local scaleValue = p:FindFirstChild("Scale")
	local scale = scaleValue and scaleValue.Value
	if tag.Value == "Cue" then
		local tier = p:GetAttribute("Tier") or 1
		CueFx.Apply(p, tier, CueFx.Def(tier, p:GetAttribute("Dragon")), scale or 1)
	end
	local mp = MeshBuilder.Create(tag.Value, p.CFrame, overrides, scale)
	if not mp or not p.Parent then
		if mp then mp:Destroy() end
		return
	end
	mp.Name, mp.Anchored, mp.Massless = "MeshVisual", false, true
	if tag.Value == "Ring" then mp.Transparency = 0.15 end
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
	if not (inst.Name == "Mesh" and inst:IsA("StringValue")) then return end
	task.spawn(apply, inst)
	local pending = false
	for _, v in inst.Parent:GetChildren() do
		if v:IsA("Color3Value") or (v:IsA("NumberValue") and v.Name == "Scale") then
			v.Changed:Connect(function()
				if pending then return end
				pending = true
				task.defer(function()
					pending = false
					if inst.Parent then apply(inst) end
				end)
			end)
		end
	end
end

workspace:WaitForChild("World")
for _, d in workspace:GetDescendants() do check(d) end
workspace.DescendantAdded:Connect(check) -- also catches NPC cues and the cue in each player's hand

-- aura rings turn slowly around their own axis; rainbow characters cycle their colour
local spinning = {}
local function addSpin(p) spinning[p] = p.CFrame end
for _, p in CollectionService:GetTagged("Spin") do addSpin(p) end
CollectionService:GetInstanceAddedSignal("Spin"):Connect(addSpin)
CollectionService:GetInstanceRemovedSignal("Spin"):Connect(function(p) spinning[p] = nil end)

local hueT = 0
RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	for p, base in spinning do
		if p.Parent then
			p.CFrame = base * CFrame.Angles(0, t * (p:GetAttribute("Spin") or 1), 0)
		else
			spinning[p] = nil
		end
	end
	hueT += dt
	if hueT < 0.08 then return end
	hueT = 0
	for _, m in CollectionService:GetTagged("Rainbow") do
		for i, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Name ~= "Cue" and d.Name ~= "Ring" and d.Name ~= "MeshVisual" then
				d.Color = Color3.fromHSV((t * 0.25 + i * 0.03) % 1, 0.6, 1)
			end
		end
	end
end)
