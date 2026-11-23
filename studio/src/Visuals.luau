-- Swaps every part tagged with a "Mesh" StringValue for the matching Blender mesh (Shared/Meshes).
-- "MeshPivot" parts stand for a whole part-built model: the model is hidden locally and the mesh is
-- welded to the pivot. Any other tagged part (cues, rings, the gym dumbbell) is replaced 1:1.
-- Colour/scale values under a tagged part rebuild its mesh when they change (dumbbell level, cue tier).
-- Also: cue tier effects (Shared/CueFx), spinning aura rings, rainbow characters.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local C = require(RS.Shared.Config)
local BallArt=require(RS.Shared.BallArt)
local MeshBuilder = require(RS.Shared.MeshBuilder)
local CueFx = require(RS.Shared.CueFx)
local Art = require(RS.Shared.Art)
local imported = RS:WaitForChild("ImportedArt")

local function hide(p)
	p.LocalTransparencyModifier = 1
end

local function apply(tag)
	task.wait() -- let sibling override values replicate
	local p = tag.Parent
	if not (p and p:IsA("BasePart")) then return end
	local old = p:FindFirstChild("MeshVisual")
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
	local wide = p:FindFirstChild("WideScale")
	if wide then -- wider footprint (X/Z) at the same height
		local s = scale or 1
		scale = (typeof(s) == "Vector3" and s or Vector3.one * s) * Vector3.new(wide.Value, 1, wide.Value)
	end
	local mp = MeshBuilder.Create(tag.Value, p.CFrame, overrides, scale)
	if not mp or not p.Parent then
		if mp then mp:Destroy() end
		return
	end
	if old and old.Parent then old:Destroy() end
	mp.Name, mp.Anchored, mp.Massless = "MeshVisual", false, true
	if tag.Value == "Ring" then mp.Transparency = 0.15 end
	local variant = p:GetAttribute("Variant") -- prize balls: Gold / Diamond / Galaxy / Rainbow material
	for _, V in C.Variants do
		if V.name == variant and V.material then
			mp.Material = Enum.Material[V.material]
			mp.Reflectance = (V.name == "Gold" or V.name == "Diamond") and 0.3 or 0
		end
	end
	if variant == "Rainbow" then
		local h = Instance.new("Highlight")
		h.Name, h.FillTransparency, h.OutlineTransparency, h.Parent = "RainbowGlow", 0.35, 0.6, mp
		CollectionService:AddTag(h, "Rainbow")
	end
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

local pendingRoomMeshes=0
local function check(inst)
	if not (inst.Name == "Mesh" and inst:IsA("StringValue")) then return end
	local group=inst.Parent and inst.Parent.Parent
 if group and group:FindFirstChild("UseRoomGeometry") then return end
 pendingRoomMeshes+=1
 task.spawn(function()
  local ok,err=pcall(apply,inst)
  if not ok then warn("Using the built-in geometry for "..inst.Name,err) end
  pendingRoomMeshes-=1
 end)
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

local keys = {}
local function repaint(anchor)
	if not anchor.Parent then return end
	local item = keys[anchor]
	if not item then return end
	local keyValue = anchor:FindFirstChild("ArtKey")
	local key = keyValue and keyValue.Value or anchor:GetAttribute("ArtKey")
	local scale = anchor:GetAttribute("ArtScale") or 1
	local template = key and imported:FindFirstChild(key)
	local loaded = template and template:GetAttribute("LocalAssetReady") == true
	if anchor.Parent:FindFirstChild("UseRoomGeometry") then return end
 local old = anchor:FindFirstChild("NativeVisual")
	local fallback = anchor:FindFirstChild("ArtVisual") or (anchor.Name == "ArtPivot" and anchor.Parent:FindFirstChild("Appearance"))
	local hidden = anchor:GetAttribute("LocalCueHidden") or anchor:GetAttribute("LocalBellHidden")
	if old and (not loaded or old:GetAttribute("Key") ~= key) then old:Destroy(); old = nil end
	if not old and loaded then
		old = Art.Native(key, anchor.CFrame, scale)
		if old then
			old.Name = "NativeVisual"
			old:SetAttribute("Key", key)
			if not anchor.Anchored then
				old.Anchored, old.Massless = false, true
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1, weld.Parent = anchor, old, old
			end
			old.Parent = anchor
		end
	end
	if old then old.LocalTransparencyModifier = hidden and 1 or 0 end
	if anchor.Name == "MeshPivot" then
		local mesh = anchor:FindFirstChild("MeshVisual")
		if mesh then mesh.LocalTransparencyModifier = old and 1 or 0 end
		for _, part in anchor.Parent:GetDescendants() do
			if part:IsA("BasePart") and part ~= anchor and not part:IsDescendantOf(anchor) then
				part.LocalTransparencyModifier = (old or mesh) and 1 or 0
			end
		end
	elseif fallback then
		for _, part in fallback:GetDescendants() do
			if part:IsA("BasePart") then part.LocalTransparencyModifier = (hidden or old) and 1 or 0 end
		end
	end
	if anchor.Name == "Cue" and key and not item.cueFx then
		item.cueFx = true
  local conn=RunService.RenderStepped:Connect(function()
   if not anchor:GetAttribute("LocalCueHidden") then Art.PoseCue(anchor:FindFirstChild("ArtVisual"),os.clock()) end
  end)
  anchor.Destroying:Once(function()conn:Disconnect()end)
		local t = anchor:GetAttribute("Tier") or 1
		CueFx.Apply(anchor, t, CueFx.Def(t, anchor:GetAttribute("Dragon")), scale)
	end
	if anchor.Name == "Cue" then
		for _, fx in anchor:GetDescendants() do
			if fx:IsA("ParticleEmitter") or fx:IsA("PointLight") or fx:IsA("Beam") then fx.Enabled = not hidden end
		end
	end
end

local function watch(anchor)
	if keys[anchor] or not anchor:IsA("BasePart") then return end
	keys[anchor] = {}
	for _, name in { "ArtKey", "LocalCueHidden", "LocalBellHidden" } do
		anchor:GetAttributeChangedSignal(name):Connect(function() task.defer(repaint, anchor) end)
	end
	anchor.ChildAdded:Connect(function(child)
		if child.Name == "ArtVisual" or child.Name == "ArtKey" or child.Name == "MeshVisual" then task.defer(repaint, anchor) end
	end)
	anchor.Destroying:Connect(function() keys[anchor] = nil end)
	task.defer(repaint, anchor)
end

local function inspect(inst)
	check(inst)
	if inst:IsA("BasePart") and (inst.Name == "ArtPivot" or inst.Name == "Dumbbell" or inst.Name == "Cue" and inst:GetAttribute("ArtKey")) then
		watch(inst)
	elseif inst.Name == "ArtKey" and inst.Parent and inst.Parent:IsA("BasePart") then
		watch(inst.Parent)
	end
end

local function watchImported(template)
	if not template:IsA("MeshPart") then return end
	local function update()
		for anchor in keys do
			local tag = anchor:FindFirstChild("ArtKey")
			if (tag and tag.Value or anchor:GetAttribute("ArtKey")) == template.Name then repaint(anchor) end
		end
	end
	template:GetAttributeChangedSignal("LocalAssetReady"):Connect(update)
	update()
end
for _, template in imported:GetChildren() do watchImported(template) end
imported.ChildAdded:Connect(watchImported)

if not game:IsLoaded() then game.Loaded:Wait() end
workspace:WaitForChild("World")
for _, d in workspace:GetDescendants() do inspect(d) end
workspace.DescendantAdded:Connect(inspect)
task.spawn(function()
 while pendingRoomMeshes>0 do task.wait(.08) end
 game:GetService("Players").LocalPlayer:SetAttribute("BHInitialVisuals",true)
end)

-- Decorative motion never moves server-side reward slots.
local spinning, rolling = {}, {}
local function addSpin(p) spinning[p] = p.CFrame end
local function addRoll(p)
	if rolling[p] or not p:IsDescendantOf(workspace) then return end
 if not p:GetAttribute("Section") then
    local ready
    ready=p:GetAttributeChangedSignal("Section"):Connect(function()
       ready:Disconnect()
       task.defer(addRoll,p)
    end)
    return
 end
 local model=BallArt.Make({id=p:GetAttribute("Number"),section=p:GetAttribute("Section"),design=p:GetAttribute("Design"),v=p:GetAttribute("Edition")},p.Size.X,p.CFrame)
 model.Parent=p
 rolling[p] = { model=model, base = p.CFrame, rate = .86 + (math.abs(p.Position.Z) % 3) * .11 }
end
for _, p in CollectionService:GetTagged("BaseRoll") do addRoll(p) end
CollectionService:GetInstanceAddedSignal("BaseRoll"):Connect(addRoll)
CollectionService:GetInstanceRemovedSignal("BaseRoll"):Connect(function(p)
 local row=rolling[p]
 if row then row.model:Destroy() end
 rolling[p]=nil
end)
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
	local phase = workspace:GetServerTimeNow()
	local cam = workspace.CurrentCamera
	for p, row in rolling do
		if not p.Parent then
			rolling[p] = nil
		elseif p:GetAttribute("Revealing") then
			p.CFrame = row.base
            row.model:PivotTo(row.base)
		elseif cam and (cam.CFrame.Position - row.base.Position).Magnitude < 125 then
			local t = phase * row.rate + row.base.X
			local f = .42
			local r = p.Size.X * .5
			p.CFrame = row.base * CFrame.new(math.sin(t) * f, 0, math.sin(t * .5) * f)
				* CFrame.Angles(math.sin(t * .5) * f / r, 0, -math.sin(t) * f / r)
            row.model:PivotTo(p.CFrame)
		end
	end
	hueT += dt
	if hueT < 0.05 then return end
	hueT = 0
	for _, h in CollectionService:GetTagged("Rainbow") do
		h.FillColor = Color3.fromHSV((t * 0.3) % 1, 0.7, 1)
		h.OutlineColor = Color3.fromHSV((t * 0.3 + 0.5) % 1, 0.7, 1)
	end
end)

-- Only the soft inlay breathes; the brass border stays readable throughout the cycle.
do
 local entrance=workspace.World:WaitForChild("ShotEntrance")
 local arc=entrance:WaitForChild("BreakArc")
 local anchor=entrance:WaitForChild("Threshold")
 local hint=Instance.new("BillboardGui")
 hint.Name="ApproachHint"
 hint.Size=UDim2.fromOffset(188,28)
 hint.StudsOffsetWorldSpace=Vector3.new(0,1.35,0)
 hint.MaxDistance=38
 hint.LightInfluence=0
 hint.Adornee=anchor
 hint.Enabled=false
 hint.Parent=anchor
 local label=Instance.new("TextLabel")
 label.Size=UDim2.fromScale(1,1)
 label.BackgroundTransparency=1
 label.Font=Enum.Font.GothamBold
 label.TextSize=16
 label.Text="Step into the arc"
 label.TextColor3=Color3.fromRGB(247,243,215)
 label.TextStrokeColor3=Color3.fromRGB(33,57,49)
 label.Parent=hint
 local glows={}
 local function register(p)
  if p:IsA("BasePart") and p.Name=="Glow" then glows[p]=math.atan2(p.Position.X,79.1-p.Position.Z) end
 end
 arc.ChildAdded:Connect(register)
 for _,p in arc:GetChildren() do register(p) end
 local timer=0
 RunService.Heartbeat:Connect(function(dt)
  timer+=dt
  if timer<.08 then return end
  timer=0
  local player=game.Players.LocalPlayer
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  local distance=root and (root.Position-anchor.Position).Magnitude or math.huge
  hint.Enabled=distance<38 and root.Position.Z<79 and not C.InShotZone(root.Position) and not _G.ThrowBusy
  if distance>65 then return end
  local phase=workspace:GetServerTimeNow()*1.1
  for p,a in glows do p.LocalTransparencyModifier=.18+.10*math.sin(phase+a*2) end
  local fade=math.clamp((distance-29)/9,0,1)
  label.TextTransparency=.1+.9*fade
  label.TextStrokeTransparency=.3+.7*fade
 end)
end
-- Only the neighbouring display cases need animation while the camera follows a shot.
do
 local landscapes=workspace.World:WaitForChild("TableLandscapes")
 local active={}
 local lastSector=-1
 local timer=0
 RunService.Heartbeat:Connect(function(dt)
  timer+=dt
  if timer<1/20 then return end
  timer=0
  local cam=workspace.CurrentCamera
  if not cam then return end
  local z=cam.CFrame.Position.Z
  local sector=z<30 and 0 or C.ZoneOf(z-C.Table.StartZ)
  if sector~=lastSector then
   for _,row in active do if row.object.Parent then row.object:PivotTo(row.home) end end
   table.clear(active)
   for index=math.max(1,sector-1),math.min(#C.Tables,sector+1) do
    local stage=landscapes:FindFirstChild(string.format("ClubTable%02d",index))
    local flying=stage and stage:FindFirstChild("FloatingDisplays")
    if flying then
     for _,o in flying:GetChildren() do
      if o:FindFirstChildWhichIsA("BasePart") then
       table.insert(active,{object=o,home=o:GetPivot(),fish=o.Name:sub(1,4)=="Fish",phase=#active*.73})
      end
     end
    end
   end
   lastSector=sector
  end
  local phase=workspace:GetServerTimeNow()*.7
  for _,row in active do
   local t=phase+row.phase
   local offset=row.fish and Vector3.new(0,.16*math.sin(t*1.3),.66*math.sin(t)) or Vector3.new(0,.34*math.sin(t),0)
   if row.object.Parent then row.object:PivotTo(CFrame.new(offset)*row.home*CFrame.Angles(0,.045*math.sin(t),0)) end
  end
 end)
end
