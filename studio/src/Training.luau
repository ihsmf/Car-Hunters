local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.Shared.Config)
local Art = require(RS.Shared.Art)
local Fx = RS:WaitForChild("Remotes"):WaitForChild("Fx")
local plr = Players.LocalPlayer
local active = {}
local kick = 0 -- camera punch on a power-up, decays every frame

local function closeup(state, char, hum, anchor, startAt)
 local root=char:FindFirstChild("HumanoidRootPart")
 local camera=workspace.CurrentCamera
 if not root or not camera then return end
 local previousType, previousSubject=camera.CameraType,camera.CameraSubject
 local previousView,previousFocus,previousFov=camera.CFrame,camera.Focus,camera.FieldOfView
 local entryTime=os.clock()
 local params=RaycastParams.new()
 params.FilterType=Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances={char}
 params.RespectCanCollide=true
 camera.CameraType=Enum.CameraType.Scriptable
 local connection=RunService.RenderStepped:Connect(function(dt)
  if workspace.CurrentCamera~=camera or camera.CameraType~=Enum.CameraType.Scriptable then return end
  local age=os.clock()-entryTime
  local elapsed=math.max(0,workspace:GetServerTimeNow()-startAt)
  local beat=(1-math.cos(2*math.pi*elapsed/C.TrainRep))*.5
  local orbit=_G.ShortOnly and 0 or math.sin(elapsed*.52)*.62
  local chest=root.Position+Vector3.new(0,.95,0)
  local target=chest:Lerp(anchor.Position,.24)
  kick*=math.exp(-6*dt)
  local offset=root.CFrame:VectorToWorldSpace(Vector3.new(3.6+orbit,1.4+.18*beat,-5.6+.6*beat-kick*1.4))
  if camera.ViewportSize.X<camera.ViewportSize.Y then offset*=1.18 end
  local hit=workspace:Raycast(target,offset,params)
  local pos=hit and hit.Position-offset.Unit*.35 or target+offset
  local view=CFrame.lookAt(pos,target)
  local alpha=math.clamp(age/.42,0,1)
  local blend=alpha*alpha*(3-2*alpha)
  if alpha<1 then camera.CFrame=previousView:Lerp(view,blend)
  else camera.CFrame=camera.CFrame:Lerp(view,1-math.exp(-12*dt)) end
  camera.FieldOfView=previousFov+(47-2*beat-6*kick-previousFov)*blend
  if kick>.02 then camera.CFrame*=CFrame.Angles(0,0,math.sin(age*60)*.012*kick) end
  camera.Focus=CFrame.new(target)
 end)
 state.releaseCamera=function()
  connection:Disconnect()
  if camera==workspace.CurrentCamera and camera.CameraType==Enum.CameraType.Scriptable and not _G.ThrowBusy then
   camera.CFrame,camera.Focus,camera.FieldOfView=previousView,previousFocus,previousFov
   if previousSubject and previousSubject.Parent then camera.CameraSubject=previousSubject
   elseif hum.Parent then camera.CameraSubject=hum end
   camera.CameraType=previousType
  end
 end
end

local function stop(uid)
	local state = active[uid]
	if not state then return end
	active[uid] = nil
	for _, conn in state.connections do conn:Disconnect() end
	for _,motor in state.posed do if motor.Parent then motor.Transform=CFrame.identity end end
	for _,joint in state.dynamic do if joint.Parent then joint.IsKinematic=false end end
 if state.restoreArm then state.restoreArm() end
 if state.floor and state.floor.Parent then state.floor:SetAttribute("LocalBellHidden", nil) end
	if state.releaseCamera then state.releaseCamera() end
end

-- Resolve the anatomical chain by connected body parts. Accessories can contain
-- joints with the same names as avatar joints.
local function link(char, from, to)
 for _, joint in char:GetDescendants() do
  if joint:IsA("Motor6D") and joint.Part0==from and joint.Part1==to then
   return joint,joint.C0,joint.C1
  elseif joint:IsA("AnimationConstraint") then
   local a,b=joint.Attachment0,joint.Attachment1
   if a and b and a.Parent==from and b.Parent==to then return joint,a.CFrame,b.CFrame end
  end
 end
end

local function classicSegment(arm, length, upper)
 local part=Instance.new("Part")
 part.Name=upper and "TrainingUpperArm" or "TrainingForearm"
 part.Size=Vector3.new(arm.Size.X,length,arm.Size.Z)
 part.Color,part.Material,part.Transparency=arm.Color,arm.Material,arm.Transparency
 part.CanCollide,part.CanQuery,part.CanTouch,part.Massless=false,false,false,true
 part.CastShadow=arm.CastShadow
 return part
end

local function curlPose(char, mount, state)
 local hand=mount.Part0
 if not hand then return end
 local classic=hand.Name=="Right Arm"
 local torso=char:FindFirstChild(classic and "Torso" or "UpperTorso")
 local arm=classic and hand or char:FindFirstChild("RightUpperArm")
 local fore=classic and hand or char:FindFirstChild("RightLowerArm")
 if not (torso and arm and fore) then return end
 local shoulder,s0,s1=link(char,torso,arm)
 if not shoulder then return end
 local elbow,e0,e1,wrist,w0,w1
 if not classic then
  elbow,e0,e1=link(char,arm,fore)
  wrist,w0,w1=link(char,fore,hand)
  if not (elbow and wrist) then return end
 end
 local function own(joint)
  table.insert(state.posed,joint)
  if joint:IsA("AnimationConstraint") and not joint.IsKinematic then
   joint.IsKinematic=true
   table.insert(state.dynamic,joint)
  end
 end
 local upperRest=s0*s1:Inverse()
 local animate
 if classic then
  -- R6 has a single rigid arm. Use two local visual segments and drive the
  -- real arm endpoint so that accessories and the replicated grip follow it.
  local top=Vector3.new(0,arm.Size.Y/2,0)
  local bottom=-top
  local hinge=Vector3.zero
  local upper=classicSegment(arm,arm.Size.Y/2,true)
  local lower=classicSegment(arm,arm.Size.Y/2,false)
  local function attach(part,parent)
   local weld=Instance.new("Weld")
   weld.Part0,weld.Part1=parent,part
   weld.Parent=part
   part.Parent=state.anchor
   return weld
  end
  local front=attach(upper,torso)
  local back=attach(lower,arm)
  back.C0=CFrame.new((hinge+bottom)/2)
  local oldAlpha=arm.LocalTransparencyModifier
  state.restoreArm=function()
   if arm.Parent then arm.LocalTransparencyModifier=oldAlpha end
   upper:Destroy()
   lower:Destroy()
  end
  animate=function(upperRot,lowerRot)
   arm.LocalTransparencyModifier=1
   local upperFrame=CFrame.new(s0.Position)*upperRot*upperRest.Rotation*CFrame.new(-s1.Position)
   front.C0=upperFrame*CFrame.new((top+hinge)/2)
   local foreFrame=CFrame.new(upperFrame*hinge)*lowerRot*upperRest.Rotation*CFrame.new(-hinge)
   shoulder.Transform=s0:ToObjectSpace(foreFrame*s1)
   return foreFrame
  end
 else
  local lowerRest=upperRest*e0*e1:Inverse()
  local function boneFrame(localDown,rest)
   if localDown.Magnitude<.001 then return rest.Rotation end
   local up=-localDown.Unit
   local side=rest:VectorToObjectSpace(Vector3.xAxis)
   side-=up*up:Dot(side)
   if side.Magnitude<.001 then
    local fallback=math.abs(up.Z)<.9 and Vector3.zAxis or Vector3.yAxis
    side=fallback:Cross(up)
   end
   return CFrame.fromMatrix(Vector3.zero,side.Unit,up,side.Unit:Cross(up)):Inverse()
  end
  local upperBasis=boneFrame(e0.Position-s1.Position,upperRest)
  local foreBasis=boneFrame(w0.Position-e1.Position,lowerRest)
  animate=function(upperRot,lowerRot)
   -- Rotations are in torso space; the offsets keep each package's authored
   -- bone length, palm placement and neutral twist, even on asymmetric arms.
   local upperFrame=CFrame.new(s0.Position)*upperRot*upperBasis*CFrame.new(-s1.Position)
   local foreFrame=CFrame.new(upperFrame*e0.Position)*lowerRot*foreBasis*CFrame.new(-e1.Position)
   shoulder.Transform=s0:ToObjectSpace(upperFrame*s1)
   elbow.Transform=(upperFrame*e0):ToObjectSpace(foreFrame*e1)
   wrist.Transform=CFrame.identity
   return foreFrame*w0*w1:Inverse()
  end
  own(elbow)
  own(wrist)
 end
 own(shoulder)
 own(mount)
 return function(t)
  local outward=CFrame.Angles(0,0,math.rad(13))
  local upperRot=outward*CFrame.Angles(math.rad(6+9*t),0,0)
  local lowerRot=outward*CFrame.Angles(math.rad(16+122*t),0,0)
  local handFrame=animate(upperRot,lowerRot)
  -- Only rotate around the actual socket centre. The handle stays crosswise
  -- even on avatar packages with a rotated grip attachment.
  mount.Transform=(handFrame*mount.C0).Rotation:Inverse()*lowerRot
 end
end


local function start(who, char, anchor)
 local uid=who.UserId
 local ref=anchor:WaitForChild("Floor",10)
 if not ref or who.Character~=char or anchor.Parent~=char then return end
 local floor,startAt=ref.Value,anchor:GetAttribute("StartAt")
 if not startAt or (active[uid] and active[uid].anchor==anchor) then return end
 stop(uid)
	
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local mount=anchor:WaitForChild("PalmMount",10)
 if not (hum and hum.Health>0 and mount and who.Character==char and anchor.Parent==char) then return end
 local state={posed={},dynamic={},anchor=anchor,floor=floor,connections={}}
 local pose=curlPose(char,mount,state)
 active[uid] = state

	if floor then floor:SetAttribute("LocalBellHidden",true) end
 if who==plr then closeup(state,char,hum,anchor,startAt) end
 table.insert(state.connections,anchor.Destroying:Connect(function() if active[uid]==state then stop(uid) end end))

 local a, b = Instance.new("Attachment"), Instance.new("Attachment")
	a.Position, b.Position, a.Parent, b.Parent = Vector3.new(-.45,0,0), Vector3.new(.45,0,0), anchor, anchor
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1, trail.Color = a, b, ColorSequence.new(C.UI.Title, Color3.fromRGB(255,126,111))
	trail.Lifetime, trail.LightEmission, trail.Transparency, trail.Parent = .16, .8, NumberSequence.new(.12,1), anchor
	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(C.UI.Title, Color3.fromRGB(255,126,111))
	particles.Rate, particles.Speed, particles.Lifetime = 0, NumberRange.new(3,7), NumberRange.new(.25,.48)
	particles.SpreadAngle, particles.Size, particles.LightEmission, particles.Parent = Vector2.new(80,80), NumberSequence.new(.20,0), .8, anchor

	-- power aura on the lifting arm: grows with every rep of this set
	local aura = Instance.new("ParticleEmitter")
	aura.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 90, 60))
	aura.LightEmission, aura.Rate, aura.Speed, aura.Lifetime = 1, 6, NumberRange.new(.5, 1.5), NumberRange.new(.4, .8)
	aura.Size, aura.Transparency = NumberSequence.new(.5, 0), NumberSequence.new(.2, 1)
	aura.SpreadAngle, aura.Acceleration, aura.Parent = Vector2.new(180, 180), Vector3.new(0, 4, 0), anchor
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness, glow.Parent = Color3.fromRGB(255, 190, 80), 8, .4, anchor
	local root = char:FindFirstChild("HumanoidRootPart")
	local head = char:FindFirstChild("Head")
	local steam = Instance.new("ParticleEmitter") -- puffs of steam from the head on the hardest part of the rep
	steam.Color, steam.LightEmission, steam.Rate = ColorSequence.new(Color3.new(1, 1, 1)), .1, 0
	steam.Speed, steam.Lifetime, steam.SpreadAngle = NumberRange.new(2, 4), NumberRange.new(.6, 1), Vector2.new(25, 25)
	steam.Size, steam.Transparency = NumberSequence.new(.6, 1.6), NumberSequence.new(.45, 1)
	steam.EmissionDirection, steam.Parent = Enum.NormalId.Top, head or anchor
	table.insert(state.connections, { Disconnect = function() aura:Destroy(); glow:Destroy(); steam:Destroy() end })
	local function ring(color, size, t) -- a flat shockwave on the floor around the feet
		if not root then return end
		local r = Instance.new("Part")
		r.Shape, r.Anchored, r.CanCollide, r.CanQuery, r.CanTouch, r.CastShadow = Enum.PartType.Cylinder, true, false, false, false, false
		r.Material, r.Color, r.Transparency = Enum.Material.Neon, color, .15
		r.Size = Vector3.new(.12, 2, 2)
		local rp = RaycastParams.new()
		rp.FilterType, rp.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, { char }
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -8, 0), rp)
		r.CFrame = CFrame.new((hit and hit.Position or root.Position - Vector3.new(0, 3, 0)) + Vector3.new(0, .08, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		r.Parent = workspace
		local tw = TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(r, tw, { Size = Vector3.new(.12, size, size), Transparency = 1 }):Play()
		task.delay(t + .05, r.Destroy, r)
	end

	local peak = -1
	table.insert(state.connections, RunService.PreSimulation:Connect(function()
		if anchor.Parent~=char or not char.Parent or hum.Health <= 0 then stop(uid); return end
		local elapsed = workspace:GetServerTimeNow() - startAt
		local rep = math.max(0,elapsed / C.TrainRep)
		local n, u = math.floor(rep), rep % 1
		local curl
		if u<.37 then local x=u/.37; curl=x*x*(3-2*x)
        elseif u<.50 then curl=1
        else local x=(u-.50)/.50; curl=1-x*x*(3-2*x) end
        trail.Enabled = elapsed > 0 and u > .13 and u < .6
		if u >= .48 and n ~= peak then
			peak = n
			particles:Emit(8 + math.min(16, (anchor:GetAttribute("Tier") or 1) // 2))
			local set = n + 1
			aura.Rate = math.min(60, 6 + set * 2.5)
			glow.Brightness = math.min(3, .4 + set * .12)
			steam:Emit(2 + math.min(6, set // 3))
			if set % 10 == 0 then -- POWER UP every 10th rep
				ring(Color3.fromRGB(255, 215, 80), 26, .7)
				ring(Color3.fromRGB(255, 120, 60), 16, .5)
				particles:Emit(60)
				glow.Brightness = 8
				TweenService:Create(glow, TweenInfo.new(.6), { Brightness = math.min(3, .4 + set * .12) }):Play()
				if who == plr then kick = 1; _G.PowerUp = set end
			else
				ring(Color3.fromRGB(255, 230, 140), 9 + math.min(6, set * .3), .45)
				if who == plr then kick = math.max(kick, .25) end
			end
		end
        if not pose then
            pose = curlPose(char,mount,state)
        end
        if pose then pose(curl) end
	end))
	table.insert(state.connections, hum.Died:Once(function() stop(uid) end))
	table.insert(state.connections, who.CharacterRemoving:Connect(function() stop(uid) end))
end

local comboGui, comboLabel, comboScale
local function popRep(gain, reps)
	local head = plr.Character and plr.Character:FindFirstChild("Head")
	if not head then return end
	local power = reps and reps % 10 == 0
	local bb = Instance.new("BillboardGui")
	bb.Size, bb.AlwaysOnTop, bb.Adornee = UDim2.fromOffset(power and 300 or 210, power and 70 or 52), true, head
	bb.StudsOffset = Vector3.new((math.random() - .5) * 2.4, 2.4, 0)
	local l = Instance.new("TextLabel")
	l.Size, l.BackgroundTransparency, l.TextScaled, l.FontFace = UDim2.fromScale(1, 1), 1, true, C.UI.Font
	l.Text = power and "POWER UP!" or "+" .. C.Short(gain) .. " STRENGTH"
	l.TextColor3 = power and Color3.fromRGB(255, 120, 60) or C.UI.Title
	local st = Instance.new("UIStroke")
	st.Thickness, st.Color, st.Parent = 3, C.UI.Ink, l
	local sc = Instance.new("UIScale")
	sc.Scale, sc.Parent = .3, l
	l.Parent, bb.Parent = bb, plr.PlayerGui
	TweenService:Create(sc, TweenInfo.new(.25, Enum.EasingStyle.Back), { Scale = power and 1.3 or 1 }):Play()
	local tw = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(bb, tw, { StudsOffset = bb.StudsOffset + Vector3.new(0, 2.6, 0) }):Play()
	task.delay(.45, function()
		local fade = TweenInfo.new(.55)
		TweenService:Create(l, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(st, fade, { Transparency = 1 }):Play()
	end)
	task.delay(1.1, bb.Destroy, bb)
	if not reps then return end
	if not comboGui or not comboGui.Parent then -- the rep combo counter next to the head
		comboGui = Instance.new("BillboardGui")
		comboGui.Size, comboGui.AlwaysOnTop, comboGui.StudsOffset = UDim2.fromOffset(120, 64), true, Vector3.new(2.6, 1, 0)
		comboLabel = Instance.new("TextLabel")
		comboLabel.Size, comboLabel.BackgroundTransparency, comboLabel.TextScaled, comboLabel.FontFace = UDim2.fromScale(1, 1), 1, true, C.UI.Font
		comboLabel.TextColor3 = Color3.new(1, 1, 1)
		local cs = Instance.new("UIStroke")
		cs.Thickness, cs.Color, cs.Parent = 4, C.UI.Ink, comboLabel
		local g = Instance.new("UIGradient")
		g.Rotation, g.Color, g.Parent = 90, ColorSequence.new(Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 120, 40)), comboLabel
		comboScale = Instance.new("UIScale")
		comboScale.Parent = comboLabel
		comboLabel.Parent, comboGui.Parent = comboGui, plr.PlayerGui
	end
	comboGui.Adornee = head
	comboLabel.Text = "x" .. reps
	comboScale.Scale = power and 2 or 1.45
	TweenService:Create(comboScale, TweenInfo.new(.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

local function watch(player)
 local function character(char)
  local function inspect(child)
   if child.Name=="TrainingGrip" and child:IsA("BasePart") then task.spawn(start,player,char,child) end
  end
  char.ChildAdded:Connect(inspect)
  for _,child in char:GetChildren() do inspect(child) end
 end
 player.CharacterAdded:Connect(character)
 if player.Character then character(player.Character) end
end
Players.PlayerAdded:Connect(watch)
for _,player in Players:GetPlayers() do watch(player) end
Players.PlayerRemoving:Connect(function(player) stop(player.UserId) end)
Fx.OnClientEvent:Connect(function(kind,a,gain,reps)
 if kind=="Rep" then popRep(gain,reps)
 elseif kind=="Train" and a~=true and comboGui then comboGui:Destroy();comboGui=nil end
end)
