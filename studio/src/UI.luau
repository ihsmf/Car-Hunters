-- CUE HUNTERS interface, using the Figma button and icon components.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.Shared.Config)
local BallArt=require(RS.Shared.BallArt)
local MeshBuilder = require(RS.Shared.MeshBuilder)
local Art = require(RS.Shared.Art)
local U = C.UI
local plr = Players.LocalPlayer
local WHITE, INK = Color3.new(1, 1, 1), U.Ink
local rgb = Color3.fromRGB
local GREEN, ORANGE, PURPLE = { rgb(157, 245, 154), rgb(62, 193, 90) }, { rgb(255, 196, 138), rgb(255, 138, 61) }, { rgb(230, 166, 255), rgb(164, 92, 255) }
local GREY = { rgb(205, 198, 214), rgb(170, 162, 182) }
local CREAM = { rgb(255, 251, 242), rgb(255, 236, 206) } -- panel body
local MUTED, MONEY = rgb(118, 100, 138), rgb(40, 160, 70)

-- ===== Sound =====
local groups, sounds = {}, {}
for _, n in { "Music", "SFX" } do
	local g = Instance.new("SoundGroup")
	g.Name, g.Volume, g.Parent = n, 0.5, SoundService
	groups[n] = g
end
for k, id in C.Sounds do
	local s = Instance.new("Sound")
	s.SoundId, s.SoundGroup, s.Parent = id, k == "Music" and groups.Music or groups.SFX, SoundService
	sounds[k] = s
end
sounds.Music.Looped = true
sounds.Music:Play()
local levels={Hit=.40,Break=.32,Ball1=.20,Ball2=.18,Ball3=.17,Cushion=.13,Pocket=.28,TrainingRep=.13,CuePurchase=.32,Click=.22,Reward=.32}
local pitches={Break=.89,Ball1=1.10,Ball2=1.02,Ball3=1.17,Cushion=.72,TrainingRep=.82}
for key,volume in levels do
 sounds[key].Volume=volume
 sounds[key].PlaybackSpeed=pitches[key] or 1
end
task.spawn(function()
 local library=SoundService:WaitForChild("ClubAudio")
 local function bind(recording)
  local key=recording.Name
  if not recording:IsA("Sound") or not sounds[key] then return end
  local function apply()
   local id=recording.SoundId
   sounds[key].SoundId=id~="" and id or C.Sounds[key]
   sounds[key].PlaybackSpeed=id~="" and 1 or pitches[key] or 1
  end
  recording:GetPropertyChangedSignal("SoundId"):Connect(apply)
  apply()
 end
 library.ChildAdded:Connect(bind)
 for _,recording in library:GetChildren() do bind(recording) end
end)
sounds.Music.Volume=.30
local playedAt={}
_G.PlaySfx=function(k)
 local sound=sounds[k]
 if not sound or k=="Music" then return end
 local now=os.clock()
 if now-(playedAt[k] or -1)<.085 then return end
 playedAt[k]=now
 sound:Play()
end

-- ===== Building blocks =====
local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in props do
		if k ~= "Parent" then o[k] = v end
	end
	for _, c in children or {} do c.Parent = o end
	if props.Parent then o.Parent = props.Parent end
	return o
end
local function corner(px) return new("UICorner", { CornerRadius = UDim.new(0, px) }) end
local function stroke(t, color) return new("UIStroke", { Color = color or INK, Thickness = t, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function grad(a, b) return new("UIGradient", { Rotation = 90, Color = ColorSequence.new(a, b) }) end
local function tween(o, t, props, style) TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad), props):Play() end

local function text(str, size, color, props)
	props = props or {}
	props.BackgroundTransparency, props.FontFace, props.Text = 1, U.Font, str
	props.TextSize, props.TextColor3 = size, color or WHITE
	props.Size = props.Size or UDim2.new(1, 0, 0, size * 1.25)
	local outline = props.NoStroke
	props.NoStroke = nil
	local l = new("TextLabel", props)
	if not outline then new("UIStroke", { Color = INK, Thickness = math.max(2, size / 11), Parent = l }) end
	return l
end

-- cartoon box: gradient body, outline, hard shadow 6 px below
local function box(props, top, bottom, radius, strokeW, strokeColor)
	local holder = new("Frame", { Size = props.Size, Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, BackgroundTransparency = 1, LayoutOrder = props.LayoutOrder or 0, Name = props.Name or "Box", ZIndex = props.ZIndex or 1, Parent = props.Parent })
	new("Frame", { Name = "Shadow", Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, strokeW == 0 and 0 or 7), BackgroundColor3 = INK, BackgroundTransparency = strokeW == 0 and 1 or 0, Parent = holder }, { corner(radius) })
	local body = new("Frame", { Name = "Body", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = holder }, { corner(radius), grad(top, bottom) })
	if strokeW ~= 0 then stroke(strokeW or 4, strokeColor).Parent = body end
	return holder, body
end
-- UI v5: a light sweep travels across buttons, pills and ribbons; one Heartbeat drives them all
local shimmers = {}
local function shimmer(body, radius, period)
	local o = new("Frame", { Name = "Shimmer", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 4, Parent = body }, { corner(radius) })
	local g = new("UIGradient", { Rotation = 18, Offset = Vector2.new(-1.2, 0), Parent = o,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.25), NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1) }) })
	table.insert(shimmers, { g = g, period = period or 3.2, phase = math.random() * 3 })
	-- depth: darker lower third and a crisp top highlight line
	new("Frame", { Name = "Depth", Size = UDim2.new(1, 0, 0.34, 0), Position = UDim2.fromScale(0, 0.66), BackgroundColor3 = INK, BackgroundTransparency = 0.86, BorderSizePixel = 0, ZIndex = 0, Parent = body }, { corner(radius) })
	return o
end
RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for i = #shimmers, 1, -1 do
		local s = shimmers[i]
		if not s.g.Parent or not s.g.Parent.Parent then
			table.remove(shimmers, i)
		else
			local u = ((t + s.phase) % s.period) / 0.9 -- sweep takes 0.9 s, then rests
			s.g.Offset = Vector2.new(u <= 1 and -1.2 + u * 2.4 or 1.2, 0)
		end
	end
end)

-- white cartoon card inside a panel: ink outline, soft cream gradient
local function card(props, radius, color)
	local f = new("Frame", { Size = props.Size, Position = props.Position or UDim2.new(), LayoutOrder = props.LayoutOrder or 0, BackgroundColor3 = WHITE, Name = props.Name or "Card", Parent = props.Parent }, {
		corner(radius or 20), stroke(4), grad(color or WHITE, (color or WHITE):Lerp(CREAM[2], 0.55)),
	})
	new("Frame", { Name = "Gloss", Size = UDim2.new(1, -20, 0, 10), Position = UDim2.fromOffset(10, 5), BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 0, Parent = f }, { corner(5) })
	local lift = new("UIScale", { Parent = f })
	local edge = f:FindFirstChildOfClass("UIStroke")
	f.MouseEnter:Connect(function()
		tween(lift, 0.15, { Scale = 1.03 })
		if edge then tween(edge, 0.15, { Color = rgb(255, 170, 40) }) end
	end)
	f.MouseLeave:Connect(function()
		tween(lift, 0.15, { Scale = 1 })
		if edge then tween(edge, 0.15, { Color = INK }) end
	end)
	return f
end

-- Vector strokes match the editable icon components in Figma.
local ICONS = {
	Coin = { {5,7,8,4,16,4,19,7,19,17,16,20,8,20,5,17,5,7}, {12,8,12,16} },
	Settings = { {3,8,21,8}, {3,16,21,16}, {8,5,8,11}, {16,13,16,19} },
	Inventory = { {5,8,12,4,19,8,19,20,5,20,5,8}, {5,8,12,12,19,8}, {12,12,12,19} },
	Bonus = { {4,10,20,10,20,20,4,20,4,10}, {12,10,12,20}, {12,10,6,7,6,4,9,4,12,10,15,4,18,4,18,7,12,10} },
	Shop = { {3,9,7,4,17,4,21,9,12,21,3,9}, {3,9,21,9}, {8,9,12,21,16,9} },
	Shot = { {4,19,16,7}, {12,10,14,6,18,4,21,7,19,11,15,13}, {5,8,5,3}, {3,5,8,5} },
	Train = { {3,8,3,16}, {6,6,6,18}, {6,12,18,12}, {18,6,18,18}, {21,8,21,16} },
	Close = { {6,6,18,18}, {18,6,6,18} },
}

local function icon(parent, name, size, at, color)
	local f = new("Frame", { Size = UDim2.fromOffset(size,size), Position = at, BackgroundTransparency = 1, Parent = parent })
	for _, path in ICONS[name] do
		for i = 1, #path-3, 2 do
			local x1, y1, x2, y2 = path[i], path[i+1], path[i+2], path[i+3]
			local dx, dy = x2-x1, y2-y1
			local part = new("Frame", {
				AnchorPoint = Vector2.new(.5,.5), Size = UDim2.fromOffset(math.sqrt(dx*dx+dy*dy)*size/24+size*.06, size*.095),
				Position = UDim2.fromScale((x1+x2)/48,(y1+y2)/48), Rotation = math.deg(math.atan2(dy,dx)),
				BorderSizePixel = 0, BackgroundColor3 = color, Parent = f,
			})
			new("UICorner", { CornerRadius = UDim.new(1,0), Parent = part })
		end
	end
	return f
end

local hudArtwork = {
Cash = {colors={Color3.fromHex("402040"),Color3.fromHex("202040"),Color3.fromHex("204040"),Color3.fromHex("206040"),Color3.fromHex("208060"),Color3.fromHex("20c060"),Color3.fromHex("20a060"),Color3.fromHex("404040"),Color3.fromHex("606040"),Color3.fromHex("608060"),Color3.fromHex("80a060"),Color3.fromHex("a0e060"),Color3.fromHex("a0ff80"),Color3.fromHex("80c060"),Color3.fromHex("60a060"),Color3.fromHex("a0e080"),Color3.fromHex("608040"),Color3.fromHex("406040"),Color3.fromHex("80e060"),Color3.fromHex("206060")}, rects={26,5,1,1,1,27,5,1,1,2,28,5,5,1,1,19,6,14,1,1,11,7,1,1,1,12,7,1,1,2,13,7,13,1,1,26,7,1,2,2,27,7,2,1,3,29,7,1,1,4,30,7,1,1,5,31,7,2,1,1,4,8,14,1,1,18,8,2,1,2,20,8,6,1,3,27,8,2,1,1,29,8,1,1,2,30,8,1,1,6,31,8,3,1,1,1,9,10,1,1,11,9,1,1,2,12,9,6,1,3,18,9,1,1,2,19,9,11,1,1,30,9,1,1,7,31,9,1,2,3,32,9,2,9,1,1,10,2,8,1,3,10,2,1,2,5,10,5,1,3,10,10,1,1,2,11,10,13,1,1,24,10,1,1,8,25,10,1,1,9,26,10,1,1,10,27,10,1,1,11,28,10,2,1,1,30,10,1,1,5,3,11,1,5,5,4,11,1,1,2,5,11,11,1,1,16,11,3,1,8,19,11,1,1,9,20,11,1,1,11,21,11,1,1,12,22,11,6,2,13,28,11,1,1,8,29,11,1,3,1,30,11,2,1,4,4,12,4,1,1,8,12,1,1,8,9,12,1,1,9,10,12,1,1,10,11,12,1,1,11,12,12,1,1,14,13,12,1,1,12,14,12,1,1,10,15,12,6,1,1,21,12,1,1,15,28,12,1,1,9,30,12,1,2,3,31,12,1,1,4,4,13,2,3,1,6,13,1,1,14,7,13,6,1,13,13,13,1,1,15,14,13,3,1,1,17,13,2,1,3,19,13,3,1,1,22,13,1,1,15,23,13,5,1,13,28,13,1,1,10,31,13,1,5,5,6,14,1,1,11,7,14,5,6,13,12,14,1,1,16,13,14,2,2,1,15,14,1,1,3,16,14,4,1,7,20,14,1,1,3,21,14,2,2,1,23,14,1,1,16,24,14,4,3,13,28,14,1,1,11,29,14,2,4,1,6,15,1,1,15,12,15,1,1,15,15,15,6,4,7,23,15,1,1,15,28,15,1,1,14,3,16,1,3,4,4,16,1,1,2,5,16,1,6,1,6,16,1,1,10,12,16,1,2,9,13,16,1,2,1,14,16,1,2,3,21,16,1,2,3,22,16,1,2,1,23,16,1,2,9,28,16,1,1,12,4,17,1,2,3,6,17,1,1,17,24,17,5,3,13,1,18,1,1,2,2,18,1,1,1,6,18,1,1,9,12,18,1,1,15,13,18,2,2,1,21,18,2,2,1,23,18,1,1,15,29,18,1,1,8,30,18,1,3,1,31,18,1,1,4,32,18,3,1,1,1,19,2,4,1,3,19,2,1,4,6,19,1,1,18,12,19,1,1,16,15,19,1,1,3,16,19,4,1,7,20,19,1,1,3,23,19,1,1,16,29,19,1,1,9,31,19,2,2,3,33,19,2,6,1,3,20,1,3,3,4,20,1,2,4,6,20,1,2,8,7,20,6,1,13,13,20,1,1,15,14,20,3,1,1,17,20,2,1,3,19,20,3,1,1,22,20,1,1,15,23,20,6,1,13,29,20,1,1,10,7,21,7,1,13,14,21,1,1,15,15,21,6,1,1,21,21,1,1,15,22,21,7,1,13,29,21,1,1,11,30,21,2,1,1,32,21,1,2,4,4,22,1,3,5,5,22,2,3,1,7,22,8,1,13,15,22,1,1,16,16,22,1,2,15,17,22,2,1,9,19,22,1,1,15,20,22,2,1,16,22,22,1,1,19,23,22,1,1,14,24,22,1,1,11,25,22,1,1,10,26,22,1,1,9,27,22,1,1,8,28,22,4,1,1,1,23,1,1,2,2,23,1,1,1,3,23,1,2,2,7,23,6,1,13,13,23,1,1,16,14,23,1,1,14,15,23,1,1,11,17,23,1,1,10,18,23,1,1,9,19,23,1,1,8,20,23,11,1,1,31,23,1,1,2,32,23,1,2,5,1,24,2,1,1,7,24,1,1,11,8,24,1,1,10,9,24,1,1,9,10,24,1,1,18,11,24,1,1,8,12,24,13,1,1,25,24,1,1,2,26,24,1,1,3,27,24,1,1,4,28,24,1,2,20,29,24,1,1,5,30,24,1,1,7,31,24,1,1,6,2,25,2,4,1,4,25,1,1,7,5,25,12,1,1,17,25,2,1,3,19,25,1,1,4,20,25,2,1,5,22,25,1,1,7,23,25,3,1,6,26,25,1,1,7,27,25,1,1,5,29,25,1,1,4,30,25,1,1,3,31,25,1,1,2,32,25,3,1,1,4,26,1,1,6,5,26,1,1,2,6,26,2,1,1,8,26,1,1,2,9,26,1,1,3,10,26,2,1,4,12,26,1,2,5,13,26,2,1,7,15,26,3,1,6,18,26,1,1,7,19,26,2,1,5,21,26,1,1,4,22,26,2,1,3,24,26,11,1,1,4,27,2,1,6,6,27,1,1,7,7,27,3,1,6,10,27,2,1,7,13,27,1,1,4,14,27,2,1,3,16,27,16,1,1,4,28,1,1,5,5,28,2,1,4,7,28,1,1,3,8,28,1,1,2,9,28,15,1,1,2,29,15,1,1,2,30,7,1,1}},
Strength = {colors={Color3.fromHex("402040"),Color3.fromHex("c08040"),Color3.fromHex("a08040"),Color3.fromHex("a06040"),Color3.fromHex("804040"),Color3.fromHex("604040"),Color3.fromHex("c08020"),Color3.fromHex("ffc020"),Color3.fromHex("202040"),Color3.fromHex("e0a020"),Color3.fromHex("806040"),Color3.fromHex("ffa020")}, rects={12,2,7,1,1,11,3,11,1,1,10,4,3,1,1,13,4,1,1,2,14,4,1,1,3,15,4,1,1,4,16,4,1,1,5,17,4,1,1,6,18,4,4,1,1,9,5,3,1,1,12,5,1,1,7,13,5,7,1,8,20,5,3,1,1,8,6,3,1,1,11,6,1,1,2,12,6,8,1,8,20,6,1,1,6,21,6,2,2,1,7,7,3,1,1,10,7,1,1,7,11,7,9,1,8,20,7,1,1,4,7,8,2,2,1,9,8,1,1,7,10,8,8,1,8,18,8,1,1,7,19,8,1,1,4,20,8,3,1,1,6,9,1,1,9,9,9,5,1,8,14,9,1,1,10,15,9,1,1,3,16,9,1,1,5,17,9,6,1,1,6,10,2,4,1,8,10,1,1,11,9,10,4,3,8,13,10,1,1,10,14,10,6,1,1,20,10,1,1,9,8,11,1,1,2,13,11,1,1,7,14,11,4,1,1,8,12,1,1,10,13,12,1,1,3,14,12,2,3,1,5,13,1,1,9,8,13,5,4,8,13,13,1,1,4,19,13,2,1,1,21,13,1,1,9,5,14,2,4,1,7,14,1,1,11,13,14,1,1,5,17,14,1,1,9,18,14,9,1,1,27,14,1,1,9,7,15,1,1,2,13,15,1,1,6,14,15,6,1,1,20,15,2,1,6,22,15,8,1,1,7,16,1,1,10,13,16,4,1,1,17,16,1,1,6,18,16,1,1,7,19,16,1,1,10,20,16,1,1,6,21,16,4,1,1,25,16,1,1,6,26,16,1,1,5,27,16,3,1,1,30,16,1,1,9,4,17,1,1,9,7,17,6,1,8,13,17,3,1,1,16,17,1,1,6,17,17,1,1,12,18,17,1,1,4,19,17,8,1,1,27,17,1,1,7,28,17,1,1,4,29,17,2,1,1,31,17,1,1,9,4,18,2,4,1,6,18,1,1,11,7,18,5,2,8,12,18,1,2,10,13,18,2,2,1,15,18,1,1,6,16,18,1,1,12,17,18,1,1,4,18,18,3,1,1,21,18,1,1,3,22,18,2,1,10,24,18,1,1,11,25,18,3,1,1,28,18,1,2,10,29,18,1,1,7,30,18,3,1,1,6,19,1,1,2,15,19,1,1,10,16,19,1,1,2,17,19,2,1,1,19,19,1,1,6,20,19,1,1,10,21,19,4,1,8,25,19,1,1,7,26,19,2,1,1,29,19,1,1,8,30,19,1,1,4,31,19,2,1,1,6,20,1,1,10,7,20,6,1,8,13,20,3,1,10,16,20,3,1,1,19,20,1,1,12,20,20,6,1,8,26,20,2,1,10,28,20,2,1,8,30,20,1,1,12,31,20,3,1,1,3,21,1,1,9,6,21,9,1,8,15,21,1,1,10,16,21,2,1,1,18,21,1,1,10,19,21,12,1,8,31,21,1,1,5,32,21,2,5,1,3,22,2,4,1,5,22,1,1,11,6,22,10,1,8,16,22,2,1,10,18,22,13,1,8,31,22,1,1,3,5,23,1,1,2,6,23,25,2,8,31,23,1,2,7,5,24,1,1,10,2,25,1,1,9,5,25,26,1,8,31,25,1,1,4,2,26,2,2,1,4,26,1,1,11,5,26,25,1,8,30,26,1,1,10,31,26,3,1,1,4,27,1,1,5,5,27,1,1,12,6,27,23,1,8,29,27,1,1,12,30,27,1,1,6,31,27,2,1,1,2,28,4,1,1,6,28,1,1,4,7,28,1,1,10,8,28,20,1,8,28,28,1,1,10,29,28,1,1,6,30,28,2,1,1,32,28,1,1,9,3,29,5,1,1,8,29,1,1,6,9,29,1,1,3,10,29,1,1,10,11,29,15,1,8,26,29,1,1,7,27,29,1,1,5,28,29,3,1,1,31,29,1,1,9,5,30,7,1,1,12,30,1,1,6,13,30,1,1,11,14,30,1,1,4,15,30,1,1,3,16,30,2,1,2,18,30,2,1,10,20,30,1,1,7,21,30,1,1,2,22,30,1,1,3,23,30,1,1,11,24,30,1,1,6,25,30,5,1,1,7,31,21,1,1,28,31,1,1,9,11,32,1,1,1,12,32,1,1,9,13,32,12,1,1,25,32,1,1,9}},
Settings = {colors={Color3.fromHex("202040"),Color3.fromHex("402040"),Color3.fromHex("404080"),Color3.fromHex("4060a0"),Color3.fromHex("40c0ff"),Color3.fromHex("404060"),Color3.fromHex("40a0e0"),Color3.fromHex("4080c0"),Color3.fromHex("406080"),Color3.fromHex("40a0ff"),Color3.fromHex("404040"),Color3.fromHex("606080"),Color3.fromHex("a0c0e0"),Color3.fromHex("a0e0ff"),Color3.fromHex("80a0c0"),Color3.fromHex("6080a0"),Color3.fromHex("402060"),Color3.fromHex("4040a0"),Color3.fromHex("4060c0")}, rects={14,1,1,1,1,15,1,6,1,2,21,1,1,1,1,14,2,8,1,2,14,3,2,3,2,16,3,1,1,3,17,3,2,1,4,19,3,1,1,3,20,3,2,3,2,7,4,3,1,2,16,4,1,3,4,17,4,2,3,5,19,4,1,3,4,26,4,3,1,2,6,5,5,1,2,25,5,5,1,2,5,6,11,1,2,20,6,11,1,2,4,7,3,3,2,7,7,1,1,6,8,7,1,1,7,9,7,1,1,8,10,7,4,1,2,14,7,1,1,6,15,7,1,1,4,16,7,4,1,5,20,7,1,1,4,21,7,1,1,6,22,7,4,1,2,26,7,1,1,8,27,7,1,1,7,28,7,1,1,6,29,7,3,3,2,7,8,1,1,7,8,8,2,1,5,10,8,1,1,4,11,8,1,1,2,12,8,1,1,6,13,8,1,1,7,14,8,1,1,5,15,8,1,1,8,16,8,4,1,9,20,8,1,1,8,21,8,1,1,5,22,8,1,1,7,23,8,1,1,6,24,8,1,1,2,25,8,1,1,4,26,8,2,1,5,28,8,1,1,7,7,9,1,1,8,8,9,4,1,5,12,9,1,1,10,13,9,1,1,9,14,9,8,1,2,22,9,1,1,4,23,9,1,1,10,24,9,4,1,5,28,9,1,1,8,5,10,3,1,2,8,10,1,1,4,9,10,2,1,5,11,10,1,1,7,12,10,4,1,2,16,10,1,1,11,17,10,2,1,6,19,10,1,1,11,20,10,4,1,2,24,10,1,1,7,25,10,2,1,5,27,10,1,1,4,28,10,3,1,2,6,11,3,1,2,9,11,1,1,5,10,11,1,1,7,11,11,3,1,2,14,11,1,1,12,15,11,1,1,13,16,11,4,1,14,20,11,1,1,13,21,11,1,1,12,22,11,3,1,2,25,11,1,1,7,26,11,1,2,5,27,11,3,1,2,6,12,2,2,2,8,12,1,1,6,9,12,1,1,10,10,12,3,1,2,13,12,1,1,15,14,12,3,1,14,17,12,2,1,13,19,12,3,1,14,22,12,1,1,15,23,12,3,1,2,27,12,1,1,6,28,12,2,2,2,8,13,1,1,7,9,13,1,1,9,10,13,2,1,2,12,13,1,1,15,13,13,2,1,14,15,13,1,1,16,16,13,4,1,2,20,13,1,1,16,21,13,2,1,14,23,13,1,1,15,24,13,2,1,2,26,13,1,1,4,27,13,1,1,7,1,14,1,1,1,2,14,5,1,2,7,14,1,1,6,8,14,1,1,5,9,14,2,2,2,11,14,1,1,12,12,14,2,1,14,14,14,1,1,6,15,14,6,1,2,21,14,1,1,6,22,14,2,1,14,24,14,1,1,12,25,14,2,2,2,27,14,1,1,5,28,14,1,1,6,29,14,5,1,2,34,14,1,1,1,1,15,6,1,2,7,15,1,1,4,8,15,1,1,8,11,15,1,1,13,12,15,1,1,14,13,15,1,1,16,14,15,2,1,2,16,15,1,1,17,17,15,2,1,18,19,15,1,1,17,20,15,2,1,2,22,15,1,1,16,23,15,1,1,14,24,15,1,1,13,27,15,1,1,8,28,15,1,1,4,29,15,6,1,2,1,16,2,4,2,3,16,1,1,3,4,16,3,1,4,7,16,1,1,5,8,16,1,1,9,9,16,1,4,2,10,16,1,1,11,11,16,2,1,14,13,16,2,4,2,15,16,1,1,17,16,16,4,4,19,20,16,1,1,17,21,16,2,4,2,23,16,2,1,14,25,16,1,1,11,26,16,1,4,2,27,16,1,1,4,28,16,1,1,5,29,16,3,1,4,32,16,1,1,3,33,16,2,4,2,3,17,1,2,4,4,17,4,2,5,8,17,1,2,3,10,17,1,2,6,11,17,1,2,14,12,17,1,2,13,15,17,1,2,18,20,17,1,2,18,23,17,1,2,13,24,17,1,2,14,25,17,1,2,6,27,17,1,2,9,28,17,4,2,5,32,17,1,2,4,3,19,1,1,3,4,19,3,1,4,7,19,1,1,5,8,19,1,1,9,10,19,1,1,11,11,19,2,1,14,15,19,1,1,17,20,19,1,1,17,23,19,2,1,14,25,19,1,1,11,27,19,1,1,4,28,19,1,1,5,29,19,3,1,4,32,19,1,1,3,1,20,6,1,2,7,20,1,1,4,8,20,1,1,8,9,20,2,2,2,11,20,1,1,13,12,20,1,1,14,13,20,1,1,16,14,20,2,1,2,16,20,1,1,17,17,20,2,1,18,19,20,1,1,17,20,20,2,1,2,22,20,1,1,16,23,20,1,1,14,24,20,1,1,13,25,20,2,2,2,27,20,1,1,8,28,20,1,1,4,29,20,6,1,2,1,21,1,1,1,2,21,5,1,2,7,21,1,1,6,8,21,1,1,5,11,21,1,1,12,12,21,2,1,14,14,21,1,1,6,15,21,6,1,2,21,21,1,1,6,22,21,2,1,14,24,21,1,1,12,27,21,1,1,5,28,21,1,1,6,29,21,5,1,2,34,21,1,1,1,6,22,2,2,2,8,22,1,1,7,9,22,1,1,4,10,22,2,1,2,12,22,1,1,15,13,22,2,1,14,15,22,1,1,16,16,22,4,1,2,20,22,1,1,16,21,22,2,1,14,23,22,1,1,15,24,22,2,1,2,26,22,1,1,4,27,22,1,1,7,28,22,2,2,2,8,23,1,1,6,9,23,1,2,5,10,23,3,1,2,13,23,1,1,15,14,23,3,1,14,17,23,2,1,13,19,23,3,1,14,22,23,1,1,15,23,23,3,1,2,26,23,1,1,10,27,23,1,1,6,6,24,3,1,2,10,24,1,1,7,11,24,3,1,2,14,24,1,1,12,15,24,1,1,13,16,24,4,1,14,20,24,1,1,13,21,24,1,1,12,22,24,3,1,2,25,24,1,1,7,26,24,1,1,5,27,24,3,1,2,5,25,3,1,2,8,25,1,1,4,9,25,2,1,5,11,25,1,1,7,12,25,4,1,2,16,25,1,1,11,17,25,2,1,6,19,25,1,1,11,20,25,4,1,2,24,25,1,1,7,25,25,2,1,5,27,25,1,1,4,28,25,3,1,2,4,26,3,3,2,7,26,1,1,8,8,26,5,1,5,13,26,1,1,4,14,26,8,1,2,22,26,1,1,4,23,26,1,1,10,24,26,4,1,5,28,26,1,1,8,29,26,3,3,2,7,27,1,1,7,8,27,2,1,5,10,27,1,1,4,11,27,1,1,2,12,27,1,1,6,13,27,1,1,7,14,27,1,1,5,15,27,1,1,8,16,27,4,1,9,20,27,1,1,8,21,27,1,1,5,22,27,1,1,7,23,27,1,1,6,24,27,1,1,2,25,27,1,1,4,26,27,2,1,5,28,27,1,1,7,7,28,1,1,6,8,28,1,1,7,9,28,1,1,8,10,28,4,1,2,14,28,1,1,6,15,28,1,1,4,16,28,4,1,5,20,28,1,1,4,21,28,1,1,6,22,28,4,1,2,26,28,1,1,8,27,28,1,1,7,28,28,1,1,6,5,29,11,1,2,16,29,1,3,4,17,29,2,3,5,19,29,1,3,4,20,29,11,1,2,6,30,5,1,2,14,30,2,3,2,20,30,2,3,2,25,30,5,1,2,7,31,3,1,2,26,31,3,1,2,16,32,1,1,3,17,32,2,1,4,19,32,1,1,3,14,33,8,1,2,14,34,1,1,1,15,34,6,1,2,21,34,1,1,1}},
Inventory = {colors={Color3.fromHex("402040"),Color3.fromHex("202040"),Color3.fromHex("604040"),Color3.fromHex("ffc040"),Color3.fromHex("c08040"),Color3.fromHex("a08040"),Color3.fromHex("e0a040"),Color3.fromHex("802040"),Color3.fromHex("a04040"),Color3.fromHex("c04040"),Color3.fromHex("e04040"),Color3.fromHex("a02040"),Color3.fromHex("602040"),Color3.fromHex("ff4040"),Color3.fromHex("ff6040"),Color3.fromHex("ff8060"),Color3.fromHex("ffa080"),Color3.fromHex("ffc080"),Color3.fromHex("ffa060"),Color3.fromHex("ffe080"),Color3.fromHex("ff6060"),Color3.fromHex("804040"),Color3.fromHex("a06040"),Color3.fromHex("c06040"),Color3.fromHex("e06040"),Color3.fromHex("ff8020")}, rects={15,1,2,1,1,17,1,1,1,2,18,1,1,1,1,13,2,9,1,1,13,3,3,1,1,16,3,2,1,3,18,3,5,1,1,12,4,2,2,1,14,4,1,1,3,15,4,4,1,4,19,4,1,1,5,20,4,1,1,3,21,4,2,1,1,14,5,1,1,6,15,5,4,1,7,19,5,2,1,4,21,5,1,2,3,22,5,2,2,1,11,6,10,1,1,9,7,16,1,1,7,8,5,1,1,12,8,1,1,8,13,8,1,1,9,14,8,2,1,10,16,8,1,1,11,17,8,3,1,10,20,8,1,1,12,21,8,1,1,13,22,8,5,1,1,6,9,1,1,2,7,9,3,1,1,10,9,1,1,10,11,9,2,1,14,13,9,1,1,15,14,9,1,1,16,15,9,1,1,17,16,9,3,1,18,19,9,1,1,19,20,9,1,1,16,21,9,1,1,15,22,9,1,1,14,23,9,1,1,9,24,9,4,1,1,6,10,2,2,1,8,10,1,1,13,9,10,1,1,11,10,10,1,1,14,11,10,1,1,15,12,10,1,1,19,13,10,8,1,20,21,10,1,2,18,22,10,1,2,15,23,10,1,1,14,24,10,1,1,11,25,10,1,1,13,26,10,3,1,1,5,11,1,1,2,8,11,1,1,11,9,11,1,1,14,10,11,1,1,21,11,11,1,1,18,12,11,3,1,20,15,11,1,1,18,16,11,3,1,19,19,11,1,1,18,20,11,1,1,20,23,11,3,1,14,26,11,1,1,13,27,11,2,2,1,5,12,2,6,1,7,12,1,1,8,8,12,1,2,14,9,12,1,2,15,10,12,1,2,18,11,12,2,1,20,13,12,1,1,19,14,12,1,1,15,15,12,5,1,14,20,12,2,1,15,22,12,5,1,14,29,12,1,1,2,7,13,1,2,10,11,13,1,1,20,12,13,1,1,16,13,13,14,1,14,27,13,1,1,9,28,13,2,1,1,8,14,2,1,14,10,14,2,1,15,12,14,16,1,14,28,14,3,1,1,7,15,1,2,11,8,15,20,2,14,28,15,1,1,8,29,15,2,6,1,28,16,1,1,9,7,17,8,1,14,15,17,4,1,11,19,17,9,1,14,28,17,1,1,10,4,18,3,2,1,7,18,4,1,14,11,18,1,1,10,12,18,1,1,8,13,18,1,1,13,14,18,6,1,1,20,18,1,1,13,21,18,1,1,8,22,18,1,1,10,23,18,5,1,14,28,18,1,1,11,7,19,1,1,14,8,19,1,1,11,9,19,1,1,12,10,19,14,1,1,24,19,1,1,12,25,19,1,1,11,26,19,3,1,14,4,20,2,11,1,6,20,1,2,13,7,20,1,10,11,8,20,5,1,1,13,20,1,1,22,14,20,1,1,23,15,20,1,1,24,16,20,1,1,25,17,20,2,1,24,19,20,1,1,23,20,20,1,1,22,21,20,5,1,1,26,20,1,10,11,27,20,2,10,14,8,21,2,7,1,10,21,1,1,22,11,21,1,1,24,12,21,10,1,26,22,21,1,1,24,23,21,1,1,22,24,21,2,7,1,29,21,3,1,1,6,22,1,2,8,10,22,1,5,25,11,22,12,5,26,23,22,1,5,25,29,22,1,2,13,30,22,2,9,1,6,24,1,1,12,29,24,1,1,8,6,25,1,1,9,29,25,1,1,12,6,26,1,4,10,29,26,1,1,9,10,27,1,1,24,11,27,12,1,25,23,27,1,1,24,29,27,1,3,10,8,28,18,2,1,6,30,1,1,8,7,30,1,1,14,8,30,18,1,11,26,30,3,1,14,29,30,1,1,8,4,31,3,1,1,7,31,1,1,8,8,31,2,1,10,10,31,16,1,11,26,31,2,1,10,28,31,1,1,8,29,31,3,1,1,5,32,26,1,1,6,33,23,1,1,29,33,1,1,2}},
Bonus = {colors={Color3.fromHex("402040"),Color3.fromHex("202040"),Color3.fromHex("802040"),Color3.fromHex("c04060"),Color3.fromHex("a04040"),Color3.fromHex("602040"),Color3.fromHex("ff4060"),Color3.fromHex("e04060"),Color3.fromHex("a02040"),Color3.fromHex("a04060"),Color3.fromHex("c0a040"),Color3.fromHex("e0c040"),Color3.fromHex("ffe040"),Color3.fromHex("c08020"),Color3.fromHex("e08020"),Color3.fromHex("ffa020")}, rects={7,3,5,1,1,23,3,4,1,1,27,3,1,1,2,6,4,8,1,1,21,4,8,1,1,5,5,3,1,1,8,5,1,1,3,9,5,1,1,4,10,5,1,1,5,11,5,4,1,1,20,5,3,1,1,23,5,1,1,6,24,5,2,1,4,26,5,1,1,3,27,5,3,1,1,5,6,2,2,1,7,6,1,1,4,8,6,4,1,7,12,6,1,1,3,13,6,3,1,1,20,6,2,1,1,22,6,1,1,3,23,6,4,1,7,27,6,1,1,5,28,6,2,1,1,4,7,1,2,2,7,7,6,1,7,13,7,1,1,6,14,7,2,1,1,19,7,3,1,1,22,7,6,2,7,28,7,3,1,1,5,8,1,1,1,6,8,1,1,6,7,8,7,2,7,14,8,3,1,1,18,8,3,1,1,21,8,1,1,4,28,8,1,1,3,29,8,2,2,1,4,9,3,1,1,14,9,1,2,4,15,9,2,1,1,17,9,1,1,2,18,9,2,1,1,20,9,1,1,6,21,9,7,1,7,28,9,1,1,6,5,10,2,1,1,7,10,1,1,6,8,10,1,1,4,9,10,5,1,8,15,10,1,1,6,16,10,4,1,1,20,10,1,1,9,21,10,1,1,4,22,10,4,1,8,26,10,1,1,10,27,10,1,1,6,28,10,2,1,1,30,10,1,1,2,2,11,32,2,1,2,13,2,5,1,4,13,1,1,11,5,13,8,1,12,13,13,1,1,11,14,13,2,5,1,16,13,1,1,4,17,13,2,1,8,19,13,1,1,4,20,13,2,5,1,22,13,1,1,11,23,13,8,1,12,31,13,1,1,11,32,13,2,5,1,4,14,1,3,12,5,14,8,3,13,13,14,1,3,12,16,14,1,16,8,17,14,2,16,7,19,14,1,16,8,22,14,1,3,12,23,14,8,3,13,31,14,1,3,12,4,17,1,1,11,5,17,8,1,12,13,17,1,1,11,22,17,1,1,11,23,17,8,1,12,31,17,1,1,11,2,18,14,2,1,20,18,14,2,1,4,20,2,11,1,6,20,1,1,14,7,20,6,1,15,13,20,1,1,14,14,20,2,11,1,20,20,2,11,1,22,20,1,1,14,23,20,6,1,15,29,20,1,1,14,30,20,2,11,1,6,21,1,9,15,7,21,6,9,16,13,21,1,9,15,22,21,1,9,15,23,21,6,9,16,29,21,1,9,15,6,30,1,1,14,7,30,6,1,15,13,30,1,1,14,16,30,1,1,4,17,30,2,1,8,19,30,1,1,4,22,30,1,1,14,23,30,6,1,15,29,30,1,1,14,4,31,28,2,1}},
Shop = {colors={Color3.fromHex("402040"),Color3.fromHex("2080c0"),Color3.fromHex("00a0e0"),Color3.fromHex("202060"),Color3.fromHex("202040"),Color3.fromHex("206080"),Color3.fromHex("8080a0"),Color3.fromHex("2060a0"),Color3.fromHex("00c0ff"),Color3.fromHex("204060"),Color3.fromHex("40c0ff"),Color3.fromHex("e0ffff"),Color3.fromHex("606080"),Color3.fromHex("20c0e0"),Color3.fromHex("c0ffff"),Color3.fromHex("00a0c0"),Color3.fromHex("a0e0ff"),Color3.fromHex("a0c0c0"),Color3.fromHex("80e0ff"),Color3.fromHex("204080"),Color3.fromHex("0080c0"),Color3.fromHex("00a0ff")}, rects={8,3,20,1,1,7,4,22,1,1,6,5,4,1,1,10,5,1,1,2,11,5,5,1,3,16,5,4,1,4,20,5,5,1,3,25,5,1,1,2,26,5,4,1,1,5,6,1,1,5,6,6,2,1,1,8,6,1,1,6,9,6,1,1,7,10,6,1,1,8,11,6,4,1,9,15,6,1,1,8,16,6,1,1,5,17,6,2,1,3,19,6,1,1,5,20,6,1,1,8,21,6,4,1,9,25,6,1,1,6,26,6,1,1,5,27,6,1,1,6,28,6,3,1,1,5,7,2,1,1,7,7,1,1,10,8,7,1,1,11,9,7,1,2,12,10,7,1,1,13,11,7,3,1,9,14,7,1,1,3,15,7,1,1,5,16,7,1,1,8,17,7,2,1,9,19,7,1,1,8,20,7,1,1,5,21,7,1,1,3,22,7,3,1,9,25,7,1,1,5,26,7,1,1,6,27,7,1,2,9,28,7,1,1,10,29,7,2,1,1,4,8,2,1,1,6,8,1,1,5,7,8,1,1,14,8,8,1,1,15,10,8,1,1,7,11,8,1,1,16,12,8,2,1,9,14,8,2,1,10,16,8,4,2,9,20,8,2,1,10,22,8,2,1,9,24,8,1,1,16,25,8,1,1,1,26,8,1,1,16,28,8,1,1,3,29,8,1,1,5,30,8,2,1,1,3,9,2,1,1,5,9,1,1,5,6,9,1,1,2,7,9,1,1,17,8,9,2,1,12,10,9,1,1,18,11,9,1,1,6,12,9,1,1,9,13,9,1,1,8,14,9,1,1,5,15,9,1,1,3,20,9,1,1,3,21,9,1,1,5,22,9,1,1,8,23,9,1,1,9,24,9,1,1,6,25,9,1,1,5,26,9,3,1,9,29,9,1,1,16,30,9,1,1,5,31,9,2,1,1,2,10,3,1,1,5,10,1,1,8,6,10,1,1,19,7,10,3,1,12,10,10,1,1,15,11,10,1,1,5,12,10,1,1,3,13,10,1,1,5,14,10,1,1,8,15,10,6,1,9,21,10,1,1,8,22,10,1,1,5,23,10,1,1,3,24,10,1,1,5,25,10,1,1,6,26,10,4,1,9,30,10,1,1,8,31,10,3,1,1,2,11,2,1,1,4,11,1,1,20,5,11,5,1,9,10,11,1,1,16,11,11,1,1,1,12,11,1,1,5,13,11,1,2,10,14,11,8,1,9,22,11,1,2,10,23,11,1,1,5,24,11,1,1,1,25,11,1,1,16,26,11,5,1,9,31,11,1,1,20,32,11,2,1,1,1,12,2,2,1,3,12,1,2,5,4,12,7,2,20,11,12,2,1,1,14,12,8,1,20,23,12,2,1,1,25,12,7,2,20,32,12,1,2,5,33,12,2,2,1,11,13,1,1,10,12,13,1,2,1,13,13,10,1,20,23,13,1,2,1,24,13,1,1,10,2,14,2,1,1,4,14,1,1,10,5,14,6,1,9,11,14,1,1,21,13,14,1,1,3,14,14,8,3,9,22,14,1,1,3,24,14,1,1,21,25,14,6,1,9,31,14,1,1,10,32,14,2,1,1,2,15,3,1,1,5,15,1,1,8,6,15,6,1,9,12,15,1,1,5,13,15,1,1,8,22,15,1,1,8,23,15,1,1,5,24,15,6,1,9,30,15,1,1,8,31,15,3,1,1,3,16,3,1,1,6,16,1,1,2,7,16,5,1,9,12,16,1,1,20,13,16,1,1,10,22,16,1,1,10,23,16,1,1,20,24,16,5,1,9,29,16,1,1,21,30,16,3,1,1,4,17,2,1,1,6,17,1,1,5,7,17,1,1,3,8,17,4,1,9,12,17,1,1,2,13,17,1,2,1,14,17,1,1,3,15,17,6,4,9,21,17,1,1,3,22,17,1,2,1,23,17,1,1,2,24,17,4,1,9,28,17,1,1,3,29,17,1,1,5,30,17,2,1,1,5,18,2,1,1,7,18,1,1,5,8,18,1,1,3,9,18,3,1,9,12,18,1,1,3,14,18,1,1,2,21,18,1,1,2,23,18,1,1,3,24,18,3,1,9,27,18,1,1,22,28,18,1,1,4,29,18,2,1,1,6,19,2,1,1,8,19,1,1,10,9,19,4,1,9,13,19,1,1,10,14,19,1,1,20,21,19,1,1,20,22,19,1,1,10,23,19,4,1,9,27,19,1,1,10,28,19,2,1,1,6,20,3,1,1,9,20,1,1,8,10,20,3,1,9,13,20,1,1,8,14,20,1,1,5,21,20,1,1,5,22,20,1,1,8,23,20,3,1,9,26,20,1,1,8,27,20,3,1,1,7,21,3,1,1,10,21,1,1,2,11,21,2,1,9,13,21,1,1,3,14,21,1,1,1,15,21,1,1,21,16,21,4,3,9,20,21,1,1,21,21,21,1,1,1,22,21,1,1,3,23,21,2,1,9,25,21,1,1,21,26,21,3,1,1,8,22,2,1,1,10,22,1,1,5,11,22,1,1,3,12,22,2,1,9,14,22,1,1,5,15,22,1,1,6,20,22,1,1,6,21,22,1,1,5,22,22,2,1,9,24,22,1,1,3,25,22,1,1,5,26,22,2,1,1,9,23,2,1,1,11,23,1,1,5,12,23,1,1,3,13,23,1,2,9,14,23,1,1,6,15,23,1,1,5,20,23,1,1,5,21,23,1,1,6,22,23,1,2,9,23,23,1,1,22,24,23,1,1,4,25,23,2,1,1,10,24,2,1,1,12,24,1,1,10,14,24,1,1,21,15,24,1,1,1,16,24,1,1,3,17,24,2,3,9,19,24,1,1,3,20,24,1,1,1,21,24,1,1,21,23,24,1,1,10,24,24,2,1,1,10,25,3,1,1,13,25,1,1,8,14,25,1,1,9,15,25,1,1,5,16,25,1,1,8,19,25,1,1,8,20,25,1,1,5,21,25,1,1,9,22,25,1,1,8,23,25,3,1,1,11,26,3,1,1,14,26,1,1,2,15,26,1,1,20,16,26,1,1,10,19,26,1,1,10,20,26,1,1,20,21,26,1,1,21,22,26,3,1,1,12,27,2,1,1,14,27,1,1,5,15,27,1,1,8,16,27,1,2,1,17,27,2,1,3,19,27,1,2,1,20,27,1,1,8,21,27,1,1,5,22,27,2,1,1,13,28,2,1,1,15,28,1,1,5,17,28,2,1,2,20,28,1,1,5,21,28,2,1,1,14,29,2,1,1,16,29,1,1,5,17,29,2,1,20,19,29,1,1,5,20,29,2,1,1,14,30,3,1,1,17,30,2,1,5,19,30,3,1,1,15,31,6,1,1,16,32,4,1,1,17,33,2,1,1}},
Shoot = {colors={Color3.fromHex("402040"),Color3.fromHex("202040"),Color3.fromHex("806080"),Color3.fromHex("c0a0a0"),Color3.fromHex("c0c0c0"),Color3.fromHex("e0e0e0"),Color3.fromHex("ffffe0"),Color3.fromHex("a08080"),Color3.fromHex("606060"),Color3.fromHex("e0e0c0"),Color3.fromHex("404040"),Color3.fromHex("e0c0c0"),Color3.fromHex("808080"),Color3.fromHex("ffe0e0"),Color3.fromHex("202020"),Color3.fromHex("604060"),Color3.fromHex("c0c0a0"),Color3.fromHex("a0a0a0")}, rects={13,1,10,1,1,10,2,1,1,1,11,2,1,1,2,12,2,14,1,1,9,3,18,1,1,7,4,1,1,2,8,4,21,1,1,6,5,24,1,1,5,6,26,1,1,4,7,1,1,2,5,7,8,1,1,13,7,1,1,3,14,7,1,1,4,15,7,2,1,5,17,7,1,1,4,18,7,1,1,3,19,7,13,1,1,4,8,7,1,1,11,8,1,1,3,12,8,1,1,6,13,8,6,1,7,19,8,1,1,6,20,8,1,1,3,21,8,11,1,1,3,9,7,1,1,10,9,1,1,8,11,9,3,1,7,14,9,1,1,4,15,9,2,1,9,17,9,1,1,4,18,9,3,1,7,21,9,1,1,8,22,9,11,1,1,2,10,7,1,1,9,10,1,1,3,10,10,3,2,7,13,10,1,1,8,14,10,4,1,1,18,10,1,1,8,19,10,3,2,7,22,10,1,1,3,23,10,10,1,1,2,11,1,1,2,3,11,6,1,1,9,11,1,1,6,13,11,2,1,1,15,11,2,1,4,17,11,2,1,1,22,11,1,1,6,23,11,11,1,1,2,12,6,2,1,8,12,1,1,3,9,12,3,1,7,12,12,1,1,10,13,12,1,1,1,14,12,1,1,11,15,12,2,1,7,17,12,1,1,11,18,12,1,1,1,19,12,1,1,10,20,12,3,1,7,23,12,1,1,3,24,12,10,1,1,1,13,1,1,2,8,13,1,1,4,9,13,4,2,7,13,13,2,1,1,15,13,2,1,3,17,13,2,1,1,19,13,4,2,7,23,13,1,1,4,24,13,11,3,1,1,14,7,4,1,8,14,1,2,5,13,14,1,1,8,14,14,4,1,1,18,14,1,1,8,23,14,1,2,5,9,15,3,3,7,12,15,1,1,12,13,15,6,1,1,19,15,1,1,12,20,15,3,3,7,8,16,1,1,4,12,16,1,1,9,13,16,1,1,1,14,16,1,1,13,15,16,2,3,7,17,16,1,1,13,18,16,1,1,1,19,16,1,1,9,23,16,1,1,4,24,16,7,2,1,31,16,1,1,2,32,16,3,5,1,8,17,1,1,3,12,17,2,1,1,14,17,1,1,14,17,17,1,1,14,18,17,2,1,1,23,17,1,1,3,31,17,1,1,15,1,18,8,2,1,9,18,1,1,6,10,18,2,2,7,12,18,1,1,11,13,18,1,2,1,14,18,1,1,12,17,18,1,1,12,18,18,1,2,1,19,18,1,1,11,20,18,2,2,7,22,18,1,1,6,23,18,7,1,1,30,18,2,1,15,9,19,1,1,3,12,19,1,1,13,14,19,1,1,16,15,19,2,1,17,17,19,1,1,16,19,19,1,1,13,22,19,1,1,3,23,19,6,1,1,29,19,1,1,2,30,19,1,1,15,31,19,1,2,2,1,20,9,1,1,10,20,1,1,8,11,20,1,1,7,12,20,1,1,14,13,20,1,1,16,14,20,4,1,1,18,20,1,1,16,19,20,1,1,14,20,20,1,1,7,21,20,1,1,8,22,20,6,1,1,28,20,1,1,2,29,20,2,1,15,1,21,5,2,1,6,21,1,1,2,7,21,4,1,1,11,21,1,1,3,12,21,1,1,6,13,21,1,1,7,14,21,1,1,18,15,21,2,1,9,17,21,1,1,18,18,21,1,1,7,19,21,1,1,6,20,21,1,1,3,21,21,7,1,1,28,21,3,1,15,31,21,4,2,1,6,22,2,1,2,8,22,5,1,1,13,22,1,1,3,14,22,1,1,4,15,22,2,1,5,17,22,1,1,4,18,22,1,1,3,19,22,8,1,1,27,22,4,1,15,2,23,4,1,1,6,23,1,1,2,7,23,1,1,15,8,23,1,1,2,9,23,17,1,1,26,23,4,1,15,30,23,1,1,2,31,23,3,1,1,2,24,5,1,1,7,24,2,1,15,9,24,1,1,2,10,24,15,1,1,25,24,5,1,15,30,24,4,2,1,2,25,1,1,2,3,25,4,1,1,7,25,1,1,2,8,25,3,1,15,11,25,12,1,1,23,25,1,1,2,24,25,5,1,15,29,25,1,1,2,3,26,5,1,1,8,26,4,1,15,12,26,1,1,2,13,26,9,1,1,22,26,7,1,15,29,26,4,1,1,4,27,5,2,1,9,27,5,1,15,14,27,2,1,2,16,27,2,1,1,18,27,2,1,2,20,27,8,1,15,28,27,4,1,1,9,28,1,1,2,10,28,17,1,15,27,28,4,1,1,31,28,1,1,2,5,29,5,1,1,10,29,1,1,2,11,29,15,1,15,26,29,4,1,1,30,29,1,1,2,6,30,6,1,1,12,30,12,1,15,24,30,1,1,2,25,30,5,1,1,7,31,7,1,1,14,31,1,1,2,15,31,6,1,15,21,31,1,1,2,22,31,7,1,1,9,32,18,1,1,11,33,15,1,1,13,34,10,1,1}},
Tutorial = {colors={Color3.fromHex("202040"),Color3.fromHex("402040"),Color3.fromHex("604040"),Color3.fromHex("a08040"),Color3.fromHex("ffc040"),Color3.fromHex("c0a040"),Color3.fromHex("804040"),Color3.fromHex("806040"),Color3.fromHex("a06040"),Color3.fromHex("c08040"),Color3.fromHex("e0c040"),Color3.fromHex("e0a040")}, rects={13,5,1,1,1,14,5,3,1,2,12,6,8,1,2,23,6,9,1,2,10,7,1,1,1,11,7,3,1,2,14,7,1,1,3,15,7,1,1,4,16,7,18,1,2,9,8,4,1,2,13,8,1,1,4,14,8,3,1,5,17,8,1,1,6,18,8,1,1,7,19,8,5,1,2,24,8,2,1,3,26,8,1,1,8,27,8,1,1,9,28,8,1,1,4,29,8,1,1,10,30,8,1,1,6,31,8,1,1,3,32,8,2,1,2,7,9,1,1,1,8,9,3,1,2,11,9,1,1,3,12,9,1,1,11,13,9,6,1,5,19,9,1,1,11,20,9,1,1,12,21,9,11,1,5,32,9,3,2,2,6,10,4,1,2,10,10,1,1,4,11,10,19,1,5,30,10,1,1,11,31,10,1,1,8,4,11,1,1,1,5,11,3,1,2,8,11,1,1,3,9,11,1,1,11,10,11,15,1,5,25,11,1,1,11,26,11,1,1,6,27,11,1,1,9,28,11,1,1,3,29,11,5,1,2,3,12,4,1,2,7,12,1,1,4,8,12,12,1,5,20,12,1,1,11,21,12,1,1,6,22,12,1,1,9,23,12,1,1,3,24,12,8,1,2,32,12,1,1,1,2,13,3,1,2,5,13,1,1,3,6,13,1,1,11,7,13,12,1,5,19,13,1,2,11,20,13,10,1,2,2,14,2,11,2,4,14,1,1,4,5,14,14,1,5,20,14,5,1,2,4,15,1,9,12,5,15,15,1,5,20,15,1,1,10,21,15,3,1,2,5,16,16,1,5,21,16,1,1,8,22,16,2,1,2,5,17,17,2,5,22,17,3,1,2,22,18,1,1,10,23,18,2,1,2,5,19,18,4,5,23,19,3,1,2,23,20,1,2,3,24,20,1,1,2,25,20,1,1,1,24,21,2,1,2,23,22,2,2,2,25,22,1,1,1,5,23,17,1,5,22,23,1,1,10,4,24,1,1,8,5,24,1,1,11,6,24,15,1,5,21,24,1,1,12,22,24,3,1,2,2,25,4,1,2,6,25,1,1,8,7,25,1,1,11,8,25,12,1,5,20,25,1,1,6,21,25,2,1,2,23,25,1,1,1,3,26,1,1,1,4,26,4,1,2,8,26,1,1,8,9,26,9,1,12,18,26,1,1,6,19,26,1,1,7,20,26,3,1,2,5,27,1,1,1,6,27,16,1,2,7,28,2,1,1,9,28,12,1,2}},
}
local function hudIcon(parent, name, size, position)
 local artwork = hudArtwork[name]
 local frame = new("Frame", {Name=name.."Icon", BackgroundTransparency=1, Position=position, Size=UDim2.fromOffset(size,size), Parent=parent})
 local rects = artwork.rects
 for i=1,#rects,5 do
  new("Frame",{BorderSizePixel=0, BackgroundColor3=artwork.colors[rects[i+4]], Position=UDim2.fromScale(rects[i]/36,rects[i+1]/36),Size=UDim2.fromScale(rects[i+2]/36,rects[i+3]/36),Parent=frame})
 end
 return frame
end

local function button(props, colors, label, size, onClick)
	local holder, body = box(props, colors[1], colors[2], props.Radius or 18, 3)
	local shine = new("Frame", { Name = "CandyGloss", Size = UDim2.new(1,-20,.38,0),
		Position = UDim2.fromOffset(10,5), BackgroundColor3 = WHITE, BackgroundTransparency = .62,
		BorderSizePixel = 0, Parent = body }, { corner(math.max(6,(props.Radius or 18)-6)) })
	shine.Visible = true -- candy gloss on every button (Figma v4)
	local sweep = props.Icon ~= "Close" and shimmer(body, props.Radius or 18, props.Hud and 2.2 or 3.4)
 local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
		Name = label ~= "" and (label or "Action") or "MenuAction", ZIndex = 5, AutoButtonColor = false, Parent = holder })
	local scale = new("UIScale", { Parent = holder })
	if not props.Hud and not props.Icon and label and label ~= "" then
		props.Icon = label:find("Sell") and "Shop" or label:find("Claim") and "Bonus" or label:find("training") and "Train" or "Inventory"
	end
	local k = math.min(42,props.Size.Y.Offset*.5)
	local inset = props.Icon and (k+16) or 10
	if props.Icon and props.Icon ~= "Close" then
		
		local glyph = not props.Hud and hudArtwork[props.Icon] and hudIcon(body,props.Icon,k,UDim2.new(0,7,.5,0)) or props.Hud and hudIcon(body,"Shoot",54,UDim2.new(0,17,.5,0)) or icon(body, props.Icon, k, UDim2.new(0,7,.5,0), INK)
		glyph.AnchorPoint = Vector2.new(0,.5)
	elseif props.Icon == "Close" then
		local glyph = icon(body, "Close", 34, UDim2.fromScale(.5,.5), INK)
		glyph.AnchorPoint = Vector2.new(.5,.5)
	end
	local big = math.floor((size or 24) * 1.32)
	local lbl = text(props.Icon == "Close" and "" or label or "", big, INK, {
		Size = UDim2.new(1, -inset - 10, 1, -8),
		Position = UDim2.fromOffset(inset,4), Parent = body, TextScaled = true, NoStroke = true,
	})
	new("UITextSizeConstraint", { MaxTextSize = big, Parent = lbl })
	if not props.Hud and label ~= "" and props.Icon ~= "Close" then
  lbl.TextColor3=WHITE
  new("UIStroke",{Color=INK,Thickness=math.clamp(big/12,2,4),Parent=lbl})
 end
 if props.Hud and label ~= "" then
  lbl.Position=UDim2.fromOffset(86,4)
  lbl.Size=UDim2.new(1,-100,1,-8)
  lbl.TextColor3=WHITE
  new("UIStroke",{Color=INK,Thickness=4,Parent=lbl})
 end
 local focus = stroke(5, WHITE)
	focus.Transparency, focus.Parent = 1, holder
	local enabled = true
	local colorKey
	hit.MouseEnter:Connect(function() if enabled then tween(scale, .15, { Scale = 1.035 }) end end)
	hit.MouseLeave:Connect(function() tween(scale, .15, { Scale = 1 }) end)
	hit.SelectionGained:Connect(function() focus.Transparency = enabled and 0 or 1 end)
	hit.SelectionLost:Connect(function() focus.Transparency = 1 end)
	hit.Activated:Connect(function()
		if not enabled then return end
		_G.PlaySfx("Click")
		scale.Scale = .94
		tween(scale, .22, { Scale = 1 }, Enum.EasingStyle.Back)
		if onClick then onClick() end
	end)
	local function setEnabled(on, cols)
		local c = on and (cols or colors) or GREY
		if enabled == on and colorKey == c then return end
		enabled, colorKey, hit.Selectable = on, c, on
		body.UIGradient.Color = ColorSequence.new(c[1],c[2])
		shine.Visible = on
		if sweep then sweep.Visible = on end
		lbl.TextTransparency = on and 0 or .24
		if not on then focus.Transparency = 1 end
	end
	return holder, body, lbl, setEnabled, hit
end

-- progress bar: returns frame, set(fraction, colour?)
local function bar(parent, pos, size, color)
	local f = new("Frame", { Position = pos, Size = size, BackgroundColor3 = rgb(230, 220, 205), Parent = parent }, { corner(math.floor(size.Y.Offset / 2)), stroke(2) })
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color or GREEN[2], Parent = f }, { corner(math.floor(size.Y.Offset / 2)) })
	return f, function(v, c)
		fill.Size = UDim2.fromScale(math.clamp(v, 0, 1), 1)
		if c then fill.BackgroundColor3 = c end
	end
end

-- 3D preview of a Blender model inside a ViewportFrame (cached MeshParts are re-parented, never rebuilt)
local previewCache = {}
local function viewport(parent, props, mesh, overrides, key, camCF, artKey, collectible)
	local vp = new("ViewportFrame", { Size = props.Size, Position = props.Position or UDim2.new(), BackgroundTransparency = 1, Ambient = rgb(200, 195, 215), LightColor = WHITE, LightDirection = Vector3.new(-1, -1, -0.6), Parent = parent })
	if collectible then
        local list=vp:FindFirstAncestorWhichIsA("ScrollingFrame")
        local displayed
        local function refresh()
            if not vp.Parent then return end
            local visible=not list or (vp.AbsolutePosition.Y+vp.AbsoluteSize.Y>list.AbsolutePosition.Y and vp.AbsolutePosition.Y<list.AbsolutePosition.Y+list.AbsoluteWindowSize.Y)
            if visible and not displayed then
                displayed=BallArt.Make(collectible,1)
                displayed.Parent=vp
            elseif not visible and displayed then
                displayed:Destroy()
                displayed=nil
            end
        end
        if list then
            local connection=vp:GetPropertyChangedSignal("AbsolutePosition"):Connect(refresh)
            local resized=list:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(refresh)
            vp.Destroying:Connect(function() connection:Disconnect();resized:Disconnect() end)
        end
        task.defer(refresh)
        local camera=new("Camera",{FieldOfView=30,CFrame=camCF,Parent=vp})
        vp.CurrentCamera=camera
        return vp
    end
	local meshReady = artKey and RS.ImportedArt:FindFirstChild(artKey)
	local cacheKey = artKey and (artKey .. tostring(meshReady and meshReady:GetAttribute("LocalAssetReady"))) or key
	local part = previewCache[cacheKey]
	if not part then
		if artKey then part = Art.Native(artKey,CFrame.identity) or Art.Fallback(artKey,CFrame.identity) end
		part = part or MeshBuilder.Create(mesh, CFrame.new(), overrides)
		if not part then -- no EditableMesh: a simple stand-in shape
			local size = mesh == "Cue" and Vector3.new(0.3, 9.2, 0.3) or mesh == "PrizeBall" and Vector3.one or Vector3.new(5.2, 2.3, 2.3)
			part = new("Part", { Size = size, Shape = mesh == "PrizeBall" and Enum.PartType.Ball or Enum.PartType.Block, Color = overrides and (overrides.Shaft or overrides.Plate or overrides.Body) or WHITE, Anchored = true })
		end
		previewCache[cacheKey] = part
	end
	part = part:Clone()
	part.Parent = vp
	local cam = new("Camera", { FieldOfView = 30, CFrame = camCF, Parent = vp })
	vp.CurrentCamera = cam
	if artKey and artKey:sub(1,3) == "Cue" then
		local connection = RunService.RenderStepped:Connect(function()
			Art.PoseCue(part,os.clock())
   cam.CFrame = CFrame.Angles(0,math.sin(os.clock()*.7)*.6,0) * camCF
		end)
		vp.Destroying:Once(function() connection:Disconnect() end)
	end
	return vp
end


-- ===== Root (design space 1920x1080) =====
local gui = new("ScreenGui", { Name = "Main", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = plr:WaitForChild("PlayerGui") })
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets -- stay clear of notches and the Roblox top bar
local root = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
local hud = new("Frame", { Name = "HUD", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = root })
-- Every HUD block is laid out in 1920x1080 design pixels inside its own frame, anchored to a screen edge and scaled
-- by the same factor: on any aspect ratio the menu hugs the left edge, SHOOT the bottom, the stats the top.
local scales = {}
local function group(name, size, anchor, pos, parent)
	local f = new("Frame", { Name = name, Size = UDim2.fromOffset(size.X, size.Y), AnchorPoint = anchor, Position = pos, BackgroundTransparency = 1, Parent = parent or hud })
	table.insert(scales, new("UIScale", { Parent = f }))
	return f
end
local topBar = group("Top", Vector2.new(640, 110), Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 8))
local leftBar = group("Left", Vector2.new(150, 532), Vector2.new(0, 0.5), UDim2.new(0, 12, 0.5, 0))
local shotBar = group("Shot", Vector2.new(640, 280), Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -6))
local cornerBar = group("Corner", Vector2.new(460, 230), Vector2.new(1, 1), UDim2.new(1, -12, 1, -12))
local backdrop = new("TextButton", { Name = "Backdrop", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(20, 10, 40),
	BackgroundTransparency = 0.5, Visible = false, ZIndex = 4, Parent = root }) -- dims the game behind an open menu; tap closes it
local center = group("Panels", Vector2.new(980, 690), Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.52), root)
center.ZIndex = 5
local trainingBar=group("TrainingControls",Vector2.new(350,88),Vector2.new(.5,1),UDim2.new(.5,0,1,-20))
trainingBar.Visible=false
local function rescale()
	local v = workspace.CurrentCamera.ViewportSize
	local portrait = v.Y > v.X
	if portrait then
		local widths = { 966, 920, 650, 580, 1005, 600 }
		for i, sc in scales do sc.Scale = math.min(.62, (v.X-20) / widths[i]) end
		leftBar.Position = UDim2.new(0,10,.48,0)
		cornerBar.Position = UDim2.new(1,-12,1,-190)
	else
		local k = math.clamp(math.min(v.X / 1920, v.Y / 1080), .36, 1.4)
		for _, sc in scales do sc.Scale = k end
		leftBar.Position = UDim2.new(0,12,.5,0)
		cornerBar.Position = UDim2.new(1,-12,1,-12)
	end
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()

local Remotes = RS:WaitForChild("Remotes")
local Request, Fx = Remotes:WaitForChild("Request"), Remotes:WaitForChild("Fx")
local state
local offlineNotice
local sending = false

-- ===== Toast stack (under the top bar, never over it) =====
local toastStack = new("Frame", { Size = UDim2.fromOffset(700, 200), Position = UDim2.fromOffset(320, 120), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, ZIndex = 30, Parent = topBar }, {
	new("UIListLayout", { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})
local toastN = 0
local function toast(msg, color)
	toastN += 1
	local items = {}
	for _, c in toastStack:GetChildren() do
		if c:IsA("Frame") then table.insert(items, c) end
	end
	if #items >= 3 then items[1]:Destroy() end
	local holder, body = box({ Size = UDim2.fromOffset(580, 60), LayoutOrder = toastN, Parent = toastStack }, CREAM[1], CREAM[2], 30, 4)
	text(msg, 30, color or U.Title, { Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), Parent = body, TextScaled = false })
	local sc = new("UIScale", { Scale = 0.5, Parent = holder })
	tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(2.6, function()
		tween(sc, 0.25, { Scale = 0 })
		task.wait(0.27)
		holder:Destroy()
	end)
end
_G.Toast = toast

local function call(action, arg)
	local ok, msg = Request:InvokeServer(action, arg)
	if msg then
		toast(msg, ok and U.Title or U.Bad)
		_G.PlaySfx(ok and (action=="Cue" and "CuePurchase" or "Reward") or "Click")
	end
	return ok
end

button({Size=UDim2.fromOffset(350,82),Parent=trainingBar,Icon="Train",Radius=30},U.Red,"STOP TRAINING",37,function()
 if state and state.training then call("TrainStop") end
end)
-- ===== HUD =====
local function pill(name,x,w,colors)
 local holder,body=box({Name=name,Size=UDim2.fromOffset(w,96),Position=UDim2.fromOffset(x,0),Parent=topBar},colors[1],colors[2],48,5)
 text(string.upper(name),17,WHITE,{Size=UDim2.fromOffset(w-96,20),Position=UDim2.fromOffset(84,8),Parent=body,TextXAlignment=Enum.TextXAlignment.Left,NoStroke=true,TextTransparency=.08})
 new("Frame",{Name="Gloss",Size=UDim2.new(1,-30,0,24),Position=UDim2.fromOffset(15,5),BackgroundColor3=WHITE,BackgroundTransparency=.68,BorderSizePixel=0,Parent=body},{corner(12)})
 new("Frame",{Name="IconChip",Size=UDim2.fromOffset(70,70),Position=UDim2.fromOffset(11,13),BackgroundColor3=WHITE,BackgroundTransparency=.05,Parent=body},{corner(35),stroke(4)})
 hudIcon(body,name,46,UDim2.fromOffset(23,25)).ZIndex=3
 shimmer(body,48,5)
 return holder,body
end
local _,cashBody=pill("Cash",26,378,GREEN)
local strHolder,strBody=pill("Strength",426,188,ORANGE)
local function statLabel(parent,x,width,size)
 return text("",size,WHITE,{Size=UDim2.fromOffset(width,56),Position=UDim2.fromOffset(x+12,30),TextScaled=true,Parent=parent})
end
local cashLabel=statLabel(cashBody,72,145,38)
local incomeLabel=statLabel(cashBody,229,133,23)
local strLabel=statLabel(strBody,73,100,38)
for _,pair in {{cashLabel,38},{incomeLabel,23},{strLabel,38}} do
 new("UITextSizeConstraint",{MaxTextSize=pair[2],Parent=pair[1]})
end
local _,cueBody=box({Size=UDim2.fromOffset(496,50),Position=UDim2.fromOffset(72,112),Parent=topBar},CREAM[1],CREAM[2],25,4)
local cueLabel=text("",25,rgb(255,189,54),{Size=UDim2.fromScale(1,1),Parent=cueBody})
local strScale = new("UIScale", { Parent = strHolder })

-- left menu with badges
local menu = new("Frame", { Size = UDim2.fromOffset(150, 532), BackgroundTransparency = 1, Parent = leftBar }, {
	new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local badges = {}
local open -- forward

-- shot area: live preview, power bar, SHOOT
local previewHolder, previewBody = box({ Size = UDim2.fromOffset(460, 56), Position = UDim2.fromOffset(320, 0), AnchorPoint = Vector2.new(0.5, 0), Parent = shotBar }, rgb(255, 227, 138), rgb(255, 184, 48), 28, 4)
local previewLabel = text("TABLE 1", 32, nil, { Size = UDim2.fromScale(1, 1), Parent = previewBody })
local powerFrame = new("Frame", { Size = UDim2.fromOffset(640, 44), Position = UDim2.fromOffset(0, 66), BackgroundColor3 = INK, Parent = shotBar }, { corner(22), stroke(4) })
local powerFill = new("Frame", { Size = UDim2.new(0, 0, 1, -12), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = WHITE, Parent = powerFrame }, {
	corner(16), new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(90, 220, 90)), ColorSequenceKeypoint.new(0.6, rgb(255, 220, 40)), ColorSequenceKeypoint.new(1, rgb(255, 60, 60)) }) }),
})
local _, _, shootLabel, setShootEnabled, shootHit = button({ Size = UDim2.fromOffset(400, 118), Position = UDim2.fromOffset(120, 122), Parent = shotBar, Radius = 44, Hud = true, Icon = "Shot" }, U.Red, "SHOOT!", 52)
do -- SHOOT halo: a golden ring breathes around the button while it can be pressed
	local halo = new("UIStroke", { Color = rgb(255, 214, 90), Thickness = 0, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = shootHit.Parent:FindFirstChild("Body") })
	RunService.Heartbeat:Connect(function()
		if not shotBar.Visible then return end
		local k = (math.sin(os.clock() * 4) + 1) / 2
		halo.Thickness = shootHit.Selectable and 4 + k * 6 or 0
		halo.Transparency = 0.15 + k * 0.5
	end)
end
shotBar.Visible = false
local hint = text("Tap at the right moment", 21, WHITE, { Size = UDim2.fromOffset(640, 26), Position = UDim2.fromOffset(0, 244), Parent = shotBar })

-- onboarding bubble
local tipHolder, tipBody = box({ Size = UDim2.fromOffset(460, 110), Position = UDim2.fromOffset(0, 0), Parent = cornerBar }, CREAM[1], CREAM[2], 26, 4)
hudIcon(tipBody,"Tutorial",24,UDim2.fromOffset(12,24))
local tipText = text("", 26, INK, { Size = UDim2.new(1, -58, 0, 56), Position = UDim2.fromOffset(44, 10), Parent = tipBody, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
local tipStep = text("", 22, PURPLE[2], { Size = UDim2.new(1, -40, 0, 24), Position = UDim2.fromOffset(20, 66), Parent = tipBody, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
tipHolder.Visible = false

-- ===== Panels =====
local panels, renderers = {}, {}
local function panel(key, title, colors)
	local holder, body = box({ Size = UDim2.fromOffset(980, 680), Position = UDim2.fromOffset(490, 345), AnchorPoint = Vector2.new(0.5, 0.5), Parent = center, Name = key, ZIndex = 10 }, CREAM[1], CREAM[2], 44, 6)
	holder.Visible = false
	-- title ribbon in the colour of the menu button, a light stripe of polka dots for a playful touch
	for i = 0, 13 do -- soft polka dots on the cream body (Figma v4 panel)
		for j = 0, 7 do
			if (i + j) % 2 == 0 then
				new("Frame", { Size = UDim2.fromOffset(10, 10), Position = UDim2.fromOffset(40 + i * 68, 150 + j * 64), BackgroundColor3 = rgb(243, 217, 178), BackgroundTransparency = .55, BorderSizePixel = 0, Parent = body }, { corner(5) })
			end
		end
	end
	local _, ribbon = box({ Size = UDim2.new(1, 24, 0, 104), Position = UDim2.fromOffset(-12, -32), Parent = body }, colors[1], colors[2], 34, 6)
	new("Frame", { Name = "Gloss", Size = UDim2.new(1, -28, 0, 30), Position = UDim2.fromOffset(14, 7), BackgroundColor3 = WHITE, BackgroundTransparency = .7, BorderSizePixel = 0, Parent = ribbon }, { corner(15) })
	shimmer(ribbon, 34, 4)
	local artKey=({Cues="Shop",Gym="Strength"})[key] or key
 hudIcon(ribbon,artKey,60,UDim2.fromOffset(28,16))
 text(title,58,WHITE,{Size=UDim2.new(1,-220,1,0),Position=UDim2.fromOffset(104,0),Parent=ribbon,TextXAlignment=Enum.TextXAlignment.Left})
 local sub = text("", 26, MUTED, { Size = UDim2.new(1, -80, 0, 30), Position = UDim2.fromOffset(40, 80), Parent = body, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
	button({ Size = UDim2.fromOffset(74, 68), Position = UDim2.fromOffset(900, -16), Parent = body, Radius = 24, Icon = "Close" }, U.Red, "X", 34, function() holder.Visible = false end)
	local content = new("Frame", { Size = UDim2.fromOffset(900, 530), Position = UDim2.fromOffset(40, 130), BackgroundTransparency = 1, Parent = body })
	panels[key] = { holder = holder, content = content, sub = sub }
end
local function clear(f)
	for _, c in f:GetChildren() do c:Destroy() end
end
local function scroller(parent, pos, size, cell, pad)
	return new("ScrollingFrame", {
		Position = pos, Size = size, BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8, ScrollBarImageColor3 = INK,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = parent,
	}, {
		new("UIGridLayout", { CellSize = cell, CellPadding = UDim2.fromOffset(pad, pad), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }),
	})
end

function open(key, force)
	if not state then return end
	local p = panels[key]
	local show = force or not p.holder.Visible
	for _, q in panels do q.holder.Visible = false end
	if not show then return end
	p.holder.Visible = true
	renderers[key]()
	local home = p.holder:GetAttribute("Home") or p.holder.Position
	p.holder:SetAttribute("Home", home)
	p.holder.Position = home + UDim2.fromOffset(0, 70) -- slides up into place
	tween(p.holder, 0.32, { Position = home }, Enum.EasingStyle.Back)
 if key=="Cues" then return end
	local sc = p.holder:FindFirstChild("Pop") or new("UIScale", { Name = "Pop", Parent = p.holder })
	sc.Scale = 0.6
	tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end
backdrop.Activated:Connect(function()
	for _, q in panels do q.holder.Visible = false end
end)
local menuBlur = new("BlurEffect", { Name = "MenuBlur", Size = 0, Parent = game:GetService("Lighting") })
local blurred = false
RunService.Heartbeat:Connect(function()
	local any = false
	for _, q in panels do any = any or q.holder.Visible end
	backdrop.Visible = any
	if any ~= blurred then -- the game softly blurs behind an open menu
		blurred = any
		tween(menuBlur, 0.25, { Size = any and 14 or 0 })
	end
end)
local function rerender() -- Settings is not rebuilt from server updates (it would interrupt a slider drag)
	for k, p in panels do
		if p.holder.Visible and k ~= "Settings" then renderers[k]() end
	end
end

-- --- Inventory ---
local BALL_CAM = CFrame.lookAt(Vector3.new(0, 0.6, 3.4), Vector3.zero)
panel("Inventory", "Inventory", { U.Menu[2][4], U.Menu[2][5] })
local sortMode = "best"
local TOTAL = #C.Balls * C.DesignCount * #C.Variants
local function sellDialog()
	local p = panels.Inventory
	local counts = {}
	for _, it in state.d.inv do
		if not it.eq and (it.v or 1) < 4 then
			local r = it.id
			counts[r] = counts[r] or { n = 0, cash = 0 }
			counts[r].n += 1
			counts[r].cash += C.ItemIncome(it) * 30
		end
	end
	local holder, body = box({ Size = UDim2.fromOffset(580, 500), Position = UDim2.fromOffset(450, 260), AnchorPoint = Vector2.new(0.5, 0.5), Parent = p.content, ZIndex = 20 }, CREAM[1], CREAM[2], 30, 5)
	text("Sell unequipped", 36, INK, { Size = UDim2.new(1, -100, 0, 50), Position = UDim2.fromOffset(24, 12), Parent = body, TextXAlignment = Enum.TextXAlignment.Left })
	text("Gold, Diamond, Galaxy and Rainbow are kept", 20, MUTED, { Size = UDim2.new(1, -100, 0, 24), Position = UDim2.fromOffset(26, 60), Parent = body, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
	button({ Size = UDim2.fromOffset(56, 50), Position = UDim2.fromOffset(498, 16), Parent = body, Radius = 18, Icon = "Close" }, U.Red, "X", 26, function() holder:Destroy() end)
	local list = new("ScrollingFrame", { Size = UDim2.fromOffset(540, 390), Position = UDim2.fromOffset(20, 96), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8, ScrollBarImageColor3 = INK, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = body }, {
		new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingRight = UDim.new(0, 10) }),
	})
	local any = false
	for r = 1, #C.Rarities do
		local c = counts[r]
		if c then
			any = true
			local rar = C.Rarities[r]
			local row = card({ Size = UDim2.new(1, 0, 0, 60), LayoutOrder = r, Parent = list }, 16)
			new("Frame", { Size = UDim2.fromOffset(10, 40), Position = UDim2.fromOffset(12, 10), BackgroundColor3 = rar[2], Parent = row }, { corner(5) })
			text(rar[1] .. "  x" .. c.n, 26, INK, { Size = UDim2.fromOffset(260, 60), Position = UDim2.fromOffset(34, 0), Parent = row, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
			button({ Size = UDim2.fromOffset(200, 46), Position = UDim2.fromOffset(310, 7), Parent = row, Radius = 16 }, U.Action, "Sell $" .. C.Short(c.cash), 22, function()
				if call("SellRarity", r) then
					holder:Destroy()
					renderers.Inventory()
				end
			end)
		end
	end
	if not any then text("Nothing to sell: every ball is on your table.", 24, MUTED, { Size = UDim2.new(1, 0, 0, 80), Parent = list, TextWrapped = true, NoStroke = true }) end
end
renderers.Inventory = function()
	local p = panels.Inventory
	clear(p.content)
	local d = state.d
	local on, found = 0, 0
	for _, it in d.inv do
		if it.eq then on += 1 end
	end
	for _ in d.found or {} do found += 1 end
	p.sub.Text = string.format("%d / %d balls   %d / %d on the table   %d / %d found", #d.inv, C.MaxInventory, on, C.MaxEquipped, state.god and TOTAL or found, TOTAL)
	local _, setCap = bar(p.content, UDim2.fromOffset(0, 4), UDim2.fromOffset(470, 14))
	setCap(#d.inv / C.MaxInventory, #d.inv >= C.MaxInventory * 0.9 and U.Bad or GREEN[2])
	button({ Size = UDim2.fromOffset(160, 46), Position = UDim2.fromOffset(478, -12), Parent = p.content }, GREEN, "Equip best", 22, function()
		if call("EquipBest") then renderers.Inventory() end
	end)
	button({ Size = UDim2.fromOffset(110, 46), Position = UDim2.fromOffset(664, -12), Parent = p.content }, U.Action, "Sell", 22, sellDialog)
	button({ Size = UDim2.fromOffset(106, 46), Position = UDim2.fromOffset(790, -12), Parent = p.content }, U.Cues, sortMode == "best" and "By income" or "Newest", 22, function()
		sortMode = sortMode == "best" and "new" or "best"
		renderers.Inventory()
	end)
	local shift=state.god and 64 or 0
 if state.god then
  local function selectPage(x,w,label,key)
   button({Size=UDim2.fromOffset(w,48),Position=UDim2.fromOffset(x,46),Parent=p.content},U.Cues,label,23,function()call("GodCatalog",key)end)
  end
  selectPage(0,110,"‹ Back","prev")
  selectPage(122,420,"Table "..state.godSection.." / "..#C.Tables.."   Next ›","next")
  selectPage(556,336,C.Variants[state.godVariant].name.."   ›","edition")
 end
 local list = scroller(p.content, UDim2.fromOffset(0, 46+shift), UDim2.fromOffset(900, 484-shift), UDim2.fromOffset(285, 250), 16)
	if #d.inv == 0 then
		text("No balls yet. Step into the arc and press Shoot.", 30, MUTED, { Size = UDim2.fromOffset(880, 160), Parent = list, TextWrapped = true, NoStroke = true })
		list.UIGridLayout.CellSize = UDim2.fromOffset(880, 160)
		return
	end
	local rank = {}
	for i in d.inv do table.insert(rank, i) end
	table.sort(rank, function(x, y)
		if sortMode == "new" then return x > y end
		return C.ItemIncome(d.inv[x]) > C.ItemIncome(d.inv[y])
	end)
	for order, i in rank do
		local it = d.inv[i]
		local ch = C.Balls[it.id]
		local rar = C.Rarities[ch.rarity]
		local V = C.Variants[it.v or 1]
		local inc = C.ItemIncome(it)
		local c = card({ Size = UDim2.fromOffset(285, 250), LayoutOrder = order, Parent = list }, 22)
		local ribbon = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = rar[2], Parent = c }, { corner(20) })
		new("Frame", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 20), BackgroundColor3 = rar[2], BorderSizePixel = 0, Parent = ribbon })
		text(string.upper(rar[1]), 24, nil, { Size = UDim2.fromScale(1, 1), Parent = ribbon })
		viewport(c, { Size = UDim2.fromOffset(96, 96), Position = UDim2.fromOffset(10, 46) }, "PrizeBall", C.BallOverrides(it), "ball" .. it.id .. "_" .. (it.v or 1), BALL_CAM,nil,it)
		if V.mult > 1 then -- variant badge
			local vb = new("Frame", { Size = UDim2.fromOffset(150, 30), Position = UDim2.fromOffset(118, 50), BackgroundColor3 = V.color or ORANGE[2], Parent = c }, { corner(15), stroke(2) })
			text(string.upper(V.name) .. " x" .. V.mult, 20, nil, { Size = UDim2.fromScale(1, 1), Parent = vb })
		end
		text(C.DesignName(it), 28, INK, { Size = UDim2.fromOffset(160, 30), Position = UDim2.fromOffset(114, 84), Parent = c, TextScaled = true, NoStroke = true, TextXAlignment = Enum.TextXAlignment.Left })
		text("$" .. C.Short(inc) .. "/s", 26, MONEY, { Size = UDim2.fromOffset(160, 30), Position = UDim2.fromOffset(114, 114), Parent = c, NoStroke = true, TextXAlignment = Enum.TextXAlignment.Left })
		text("1 in " .. C.FullNumber(C.BallOdds(it)), 20, MUTED, { Size = UDim2.fromOffset(165, 24), Position = UDim2.fromOffset(114, 146), Parent = c, TextScaled = true, NoStroke = true, TextXAlignment = Enum.TextXAlignment.Left }) -- the ball's own odds
		button({ Size = UDim2.fromOffset(150, 52), Position = UDim2.fromOffset(9, 180), Parent = c, Radius = 18 }, it.eq and U.Red or GREEN, it.eq and "Remove" or "Place", 22, function()
			if call("Equip", i) then renderers.Inventory() end
		end)
		button({ Size = UDim2.fromOffset(98, 52), Position = UDim2.fromOffset(176, 180), Parent = c, Radius = 18 }, U.Action, "Sell", 22, function()
			if call("Sell", i) then renderers.Inventory() end
		end)
		if it.eq then text("ON TABLE", 18, MONEY, { Size = UDim2.fromOffset(160, 24), Position = UDim2.fromOffset(114, 146), Parent = c, NoStroke = true, TextXAlignment = Enum.TextXAlignment.Left }) end
	end
end

-- --- Bonuses ---
panel("Bonus", "Bonuses", { U.Menu[3][4], U.Menu[3][5] })
local bonusTick
renderers.Bonus = function()
	local p = panels.Bonus
	clear(p.content)
	p.sub.Text = "Log in every day for a bigger streak, stay to earn playtime gifts"
	local day = os.time() // 86400
	local dd = state.d.daily
	local claimedToday = dd.day == day
	local streak = (dd.day == day or dd.day == day - 1) and dd.streak or 0
	local today = claimedToday and streak or streak % #C.Daily + 1
	for k = 1, #C.Daily do
		local done = k < today or (claimedToday and k == today)
		local isToday = k == today and not claimedToday
		local tile = card({ Size = UDim2.fromOffset(118, 150), Position = UDim2.fromOffset((k - 1) * 130, 0), Parent = p.content }, 20, isToday and rgb(255, 236, 170) or done and rgb(220, 248, 214) or WHITE)
		if isToday then tile.UIStroke.Thickness = 5 end
		text("Day " .. k, 24, done and MUTED or INK, { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 14), Parent = tile, NoStroke = true })
		text("$" .. C.Short(C.Daily[k]), 32, done and MUTED or MONEY, { Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 56), Parent = tile, NoStroke = true })
		text(done and "Claimed" or isToday and "Today" or "", 22, done and MONEY or ORANGE[2], { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 106), Parent = tile, NoStroke = true })
	end
	local _, _, _, setDailyBtn = button({ Size = UDim2.fromOffset(320, 64), Position = UDim2.fromOffset(290, 172), Parent = p.content, Radius = 24 }, { rgb(255, 158, 200), rgb(255, 92, 158) },
		claimedToday and "Come back tomorrow" or "Claim day " .. today, 28, function()
			if not claimedToday and call("Daily") then renderers.Bonus() end
		end)
	setDailyBtn(not claimedToday)
	local rows = {}
	for i, pt in C.Playtime do
		local y = 266 + (i - 1) * 64
		local row = card({ Size = UDim2.fromOffset(900, 54), Position = UDim2.fromOffset(0, y), Parent = p.content }, 16)
		text(pt[1] .. " min", 24, INK, { Size = UDim2.fromOffset(160, 54), Position = UDim2.fromOffset(20, 0), Parent = row, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
		local _, setBar = bar(row, UDim2.fromOffset(180, 19), UDim2.fromOffset(460, 16))
		text("$" .. C.Short(pt[2]), 24, MONEY, { Size = UDim2.fromOffset(110, 54), Position = UDim2.fromOffset(652, 0), Parent = row, NoStroke = true })
		local _, _, lbl, setBtn = button({ Size = UDim2.fromOffset(120, 42), Position = UDim2.fromOffset(760, 4), Parent = row, Radius = 16 }, GREEN, "Claim", 22, function()
			if call("Playtime", i) then renderers.Bonus() end
		end)
		rows[i] = { setBar = setBar, lbl = lbl, setBtn = setBtn }
	end
	bonusTick = function()
		for i, pt in C.Playtime do
			local left = pt[1] * 60 - (os.time() - state.join)
			local r = rows[i]
			r.setBar(1 - math.max(left, 0) / (pt[1] * 60), left <= 0 and GREEN[2] or ORANGE[2])
			if state.claimed[i] then
				r.lbl.Text = "Done"
				r.setBtn(false)
			elseif left > 0 then
				r.lbl.Text = string.format("%d:%02d", left // 60, left % 60)
				r.setBtn(false)
			else
				r.lbl.Text = "Claim"
				r.setBtn(true)
			end
		end
	end
	bonusTick()
end

-- --- Donate shop ---
panel("Shop", "Shop", { U.Menu[4][4], U.Menu[4][5] })
renderers.Shop = function()
	local p = panels.Shop
	clear(p.content)
	p.sub.Text = "Game Passes and cash packs"
	local list = new("ScrollingFrame", { Size = UDim2.fromOffset(900, 530), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8, ScrollBarImageColor3 = INK, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = p.content })
	local passes, packs = 0, 0
 local y = 0
	for _, gp in C.GamePasses do
  if gp.id <= 0 then continue end
  passes += 1
  local i = passes
		local owned = state.passes[gp.key]
		local x = ((i - 1) % 2) * 450
		y = ((i - 1) // 2) * 150
		local c = card({ Size = UDim2.fromOffset(436, 136), Position = UDim2.fromOffset(x, y), Parent = list }, 22)
		local disc = new("Frame", { Size = UDim2.fromOffset(96, 96), Position = UDim2.fromOffset(18, 20), BackgroundColor3 = WHITE, Parent = c }, { corner(48), grad(rgb(255, 227, 138), rgb(255, 174, 31)), stroke(3) })
		text(gp.badge, 32, nil, { Size = UDim2.fromScale(1, 1), Parent = disc })
		text(gp.name, 30, INK, { Size = UDim2.fromOffset(300, 40), Position = UDim2.fromOffset(130, 12), Parent = c, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
		text(gp.desc, 19, MUTED, { Size = UDim2.fromOffset(290, 40), Position = UDim2.fromOffset(130, 48), Parent = c, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, NoStroke = true })
		local _, _, _, setBtn = button({ Size = UDim2.fromOffset(160, 40), Position = UDim2.fromOffset(130, 88), Parent = c, Radius = 14 }, U.Red, owned and "Owned" or "Buy", 22, function()
			if not owned then call("Pass", gp.key) end
		end)
		setBtn(not owned)
	end
 y = math.ceil(passes/2)*150
 for i, pr in C.Products do
  if pr.id <= 0 then continue end
  if packs == 0 then
   text("Cash packs",30,INK,{Size=UDim2.fromOffset(400,40),Position=UDim2.fromOffset(0,y),Parent=list,NoStroke=true})
  end
  packs += 1
  local c = card({ Size = UDim2.fromOffset(286, 130), Position = UDim2.fromOffset(((packs-1)%3)*302, y+48+math.floor((packs-1)/3)*144), Parent = list }, 22)
		text("$" .. C.Short(pr.cash), 40, MONEY, { Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 8), Parent = c })
		button({ Size = UDim2.fromOffset(170, 42), Position = UDim2.fromOffset(58, 74), Parent = c, Radius = 14 }, U.Red, "Buy", 22, function() call("Product", i) end)
	end
 if passes+packs==0 then p.sub.Text="No offers available right now" end
end

-- --- Cue shop (opened at the kiosk): every cue in one horizontal list ---
-- Approved cue-shop carousel, in its own responsive design space.
do
 local hex=Color3.fromHex
 local ink=hex("281D40")
 local off=UDim2.fromOffset
 local shell=new("Frame",{Name="CueShopLayout",AnchorPoint=Vector2.new(.5,.5),
  Position=UDim2.fromScale(.5,.5),BackgroundTransparency=1,ZIndex=12,Parent=root})
 local zoom=new("UIScale",{Parent=shell})
 local holder,body=box({Name="Cues",Parent=shell,AnchorPoint=Vector2.new(.5,.5),
  Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1,1)},hex("FFFEF6"),hex("F5E9D6"),24,4,ink)
 holder.Visible=false
 panels.Cues={holder=holder}
 local function label(parent,value,x,y,w,h,size,color,outline)
  local node=text(value,size,color,{Position=off(x,y),Size=off(w,h),Parent=parent,
   TextScaled=true,NoStroke=not outline})
  new("UITextSizeConstraint",{MaxTextSize=size,MinTextSize=8,Parent=node})
  return node
 end
 local function tile(parent,x,y,w,h,r,a,b,edge)
  local f=new("Frame",{Position=off(x,y),Size=off(w,h),BorderSizePixel=0,
   BackgroundColor3=WHITE,Parent=parent},{corner(r),grad(hex(a),hex(b or a))})
  if edge then stroke(edge,ink).Parent=f end
  return f
 end
 local function control(parent,x,y,w,h,value,a,b,callback)
  tile(parent,x,y+3,w,h,12,"281D40")
  local surface=tile(parent,x,y,w,h,12,a,b,2)
  label(surface,value,4,0,w-8,h,20,ink)
  if callback then
   local hit=new("TextButton",{Name=value,Size=UDim2.fromScale(1,1),Text="",BackgroundTransparency=1,Parent=surface})
   hit.Activated:Connect(callback)
  end
  return surface
 end
 local ribbon=tile(body,8,7,100,84,17,"91E1FF","39AEEA",3)
 local eight=tile(ribbon,17,15,53,53,27,"302541","171726")
 label(tile(eight,10,8,30,30,16,"FFF2DB"),"8",0,0,30,30,20,ink)
 local title=label(ribbon,"Cue Shop",81,5,180,52,38,WHITE,true)
 title.TextXAlignment=Enum.TextXAlignment.Left
 local power=label(ribbon,"",83,52,182,24,16,ink)
 power.TextXAlignment=Enum.TextXAlignment.Left
 local close=control(ribbon,0,17,38,38,"×","FFB3A4","FF8585",function() holder.Visible=false end)
 -- The close control and its separate shadow move together with the right edge.
 close.Position=UDim2.new(1,-54,0,18)
 for _,f in ribbon:GetChildren() do
  if f:IsA("Frame") and f~=close and f.Size==close.Size then f.Position=UDim2.new(1,-54,0,21) end
 end
 local list=new("ScrollingFrame",{Name="CueCarousel",Position=off(12,107),Size=UDim2.new(1,-24,0,365),
  ScrollingDirection=Enum.ScrollingDirection.X,CanvasSize=UDim2.new(),ScrollBarThickness=0,
  BackgroundTransparency=1,BorderSizePixel=0,Active=true,Parent=body})
 local footer=new("Frame",{Position=off(14,480),Size=UDim2.new(1,-28,0,52),BackgroundTransparency=1,Parent=body})
 new("Frame",{Size=UDim2.new(1,0,0,2),BorderSizePixel=0,BackgroundColor3=hex("D5C6AF"),Parent=footer})
 local note=label(footer,"",58,9,200,44,17,ink)
 note.Size=UDim2.new(1,-116,0,44)
 local width,canvas,owned,pass,activeBuy,pending
 local function scroll(x)
  -- CanvasPosition uses rendered pixels, as do AbsoluteCanvasSize and AbsoluteWindowSize.
  local extent=list.AbsoluteCanvasSize.X
  if canvas and extent>0 then
   list.CanvasPosition=Vector2.new(math.clamp(x,0,math.max(0,extent-list.AbsoluteWindowSize.X)),0)
  end
 end
 local function step(dir)
  if canvas then scroll(list.CanvasPosition.X+dir*238*list.AbsoluteCanvasSize.X/canvas) end
 end
 control(footer,8,11,46,34,"‹","FFE7A8","FFCF75",function() step(-1) end)
 local rightHost=new("Frame",{Position=UDim2.new(1,-54,0,0),Size=off(50,50),BackgroundTransparency=1,Parent=footer})
 control(rightHost,0,11,46,34,"›","FFE7A8","FFCF75",function() step(1) end)
 local function sizeCanvas()
  canvas=(#C.Cues+(pass and 1 or 0))*238+8+(width==396 and 64 or 0)
  list.CanvasSize=off(canvas,0)
 end
 local function focus()
  if not canvas or not owned then return end
  local i=(pass and 1 or 0)+math.min(owned+1,#C.Cues)-1
  local x=14+i*238+109-(width-24)/2
  scroll(x*list.AbsoluteCanvasSize.X/canvas)
 end
 local function resize()
  local size=root.AbsoluteSize
  local w=(size.X<size.Y or (UserInputService.TouchEnabled and size.X<950)) and 396 or 984
  local changed=width~=w
  width=w
  shell.Size=off(w,543)
  zoom.Scale=math.max(.01,math.min((size.X-16)/w,(size.Y-20)/543,1.35))
  ribbon.Size=UDim2.new(1,-16,0,84)
  if changed and holder.Visible and owned then sizeCanvas();task.defer(focus) end
 end
 root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
 resize()
 local camera=CFrame.lookAt(Vector3.new(11,0,13),Vector3.zero)*CFrame.Angles(0,0,math.rad(42))
 local function makeCard(def,tier,index,isPass)
  local equipped=isPass and C.DragonCue[2]>C.Cues[owned][2] or not isPass and tier==owned and not (pass and C.DragonCue[2]>def[2])
  local nextCue=not isPass and tier==owned+1
  local bought=isPass or tier<=owned
  local bg=nextCue and "FFF3CC" or bought and "EBF9E6" or "F4F4F8"
  local x=14+index*238
  tile(list,x,11,218,346,19,"281D40")
  local c=tile(list,x,6,218,346,19,bg,bg,3)
  label(c,isPass and "GAME PASS" or string.format("TIER %02d",tier),7,5,204,23,14,MUTED)
  label(c,def[1],6,26,206,36,30,ink)
  local field=tile(c,9,66,200,161,13,nextCue and "FFE6AC" or bought and "B5EFCA" or "CCD8F1",
   nextCue and "FFB740" or bought and "56B99F" or "8498B9")
  field.ClipsDescendants=true
  for j=0,12 do
   local angle=j*2*math.pi/13
   local ray=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=off(100+60*math.cos(angle),80+60*math.sin(angle)),
    Size=off(110,8),Rotation=math.deg(angle),BackgroundColor3=WHITE,BackgroundTransparency=.80,BorderSizePixel=0,Parent=field})
   corner(4).Parent=ray
  end
  for _,pt in {{24,20},{150,111}} do label(field,"✦",pt[1],pt[2],18,20,18,hex("FFF9DE")) end
  local palette={}
  for slot,attr in C.CueParts do palette[slot]=def[attr] end
  local previewCam=camera
  if tier==#C.Cues and not isPass then previewCam=CFrame.new(0,-2,0)*CFrame.new(camera.Position*1.60)*camera.Rotation end
  viewport(field,{Size=off(196,157),Position=off(2,2)},"Cue",palette,def[1],previewCam,Art.CueKey(tier,isPass))
  local mult=def[2]%1==0 and string.format("%.1f",def[2]) or tostring(def[2])
  label(c,"×"..mult,4,226,210,44,38,hex("FFB63D"),true)
  -- only the luck this cue adds on top of the previous one (the pass compares with the starter cue)
  local gain=isPass and C.CueLuck(8) or C.CueLuckGain(tier)
  label(c,gain<=1 and "POWER   ·   NO LUCK BONUS" or "POWER   ·   LUCK +×"..C.FullNumber(gain),6,265,206,22,13,MUTED)
  if nextCue then
   activeBuy=control(c,12,296,194,39,"Buy · $"..C.Short(def[3]),"A7F86D","4BCF78",function()
    if pending or state.d.cue+1~=tier or (not state.ownerBoost and state.d.cash<def[3]) then return end
    pending=true
    local ok,msg=pcall(call,"Cue")
    pending=false
    if not ok then warn(msg) end
   end)
  else
   local caption=equipped and "✓  Equipped" or bought and "Owned" or "🔒  $"..C.Short(def[3])
   control(c,12,296,194,39,caption,bought and "D5F1D9" or "E2E2EC")
  end
 end
 renderers.Cues=function()
  local d=state.d
  local dragon=state.passes.DragonCue==true
  if owned~=d.cue or pass~=dragon then
   local initial=owned==nil
   local position=list.CanvasPosition.X
   clear(list)
   activeBuy=nil
   owned,pass=d.cue,dragon
   if pass then makeCard(C.DragonCue,C.DragonCue.tier,0,true) end
   for k,def in C.Cues do makeCard(def,k,k-1+(pass and 1 or 0),false) end
   sizeCanvas()
   task.defer(function() if initial then focus() else scroll(position) end end)
  end
  local mult=C.CueMult(d,state.passes)
  power.Text="Shot power ×"..(mult%1==0 and string.format("%.1f",mult) or tostring(mult))
  local nxt=C.Cues[d.cue+1]
  if activeBuy and nxt then
   activeBuy.UIGradient.Color= (state.ownerBoost or d.cash>=nxt[3]) and ColorSequence.new(hex("A7F86D"),hex("4BCF78")) or ColorSequence.new(hex("E5E1DC"),hex("CBC5CC"))
  end
  note.Text=nxt and ((state.ownerBoost or d.cash>=nxt[3]) and ("Next: "..nxt[1].."  ·  ×"..nxt[2].." power") or ("Need $"..C.Short(nxt[3]-d.cash).." more for "..nxt[1])) or "You own the best cue"
 end
 holder:GetPropertyChangedSignal("Visible"):Connect(function()
  if holder.Visible then
   task.defer(focus)
  else
   clear(list)
   activeBuy,owned,canvas=nil,nil,nil
  end
 end)
end

-- --- Gym ---
panel("Gym", "Training", {rgb(101,207,255),rgb(48,126,229)})
local BELL_CAM = CFrame.lookAt(Vector3.new(6, 4, 10), Vector3.new(0, 0, 0))
renderers.Gym = function()
	local p = panels.Gym
	clear(p.content)
	local d = state.d
	p.sub.Text = state.training and string.format("Training: %d reps, +%s strength per second", state.reps or 0, C.Short(C.RepStrength(d.dumbLevel) / C.TrainRep))
		or "Strength makes every shot longer. Train at your dumbbell."
	local info = card({ Size = UDim2.fromOffset(900, 230), Position = UDim2.fromOffset(0, 0), Parent = p.content }, 26)
	local bellKey = Art.BellKey(d.dumbLevel)
	viewport(info, { Size = UDim2.fromOffset(300, 210), Position = UDim2.fromOffset(10, 10) }, "Dumbbell", nil, bellKey, BELL_CAM, bellKey)
	text("Dumbbell · Level " .. d.dumbLevel, 40, INK, { Size = UDim2.fromOffset(560, 54), Position = UDim2.fromOffset(320, 24), Parent = info, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
	text("Each level unlocks a new model", 22, MUTED, { Size = UDim2.fromOffset(560, 30), Position = UDim2.fromOffset(322, 80), Parent = info, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
	text("Strength " .. C.Short(d.strength), 32, ORANGE[2], { Size = UDim2.fromOffset(560, 40), Position = UDim2.fromOffset(322, 124), Parent = info, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
	text(string.format("+%s per rep, one rep every %.1f s", C.Short(C.RepStrength(d.dumbLevel)), C.TrainRep), 24, INK, { Size = UDim2.fromOffset(560, 32), Position = UDim2.fromOffset(322, 168), Parent = info, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
	local cost = C.LiftCost(d.dumbLevel)
	local capped = d.dumbLevel >= C.DumbbellMax
	local can = (state.ownerBoost or d.cash >= cost) and not capped and not state.training
	local _, _, _, setBtn = button({ Size = UDim2.fromOffset(430, 84), Position = UDim2.fromOffset(0, 266), Parent = p.content, Radius = 28 }, ORANGE,
		capped and "Max level" or state.training and "Training in progress" or can and ("Upgrade  $" .. C.Short(cost)) or ("Need $" .. C.Short(cost - d.cash)), 30, function()
			if can and call("UpDumb") then renderers.Gym() end
		end)
	setBtn(can)
	button({ Size = UDim2.fromOffset(430, 84), Position = UDim2.fromOffset(453, 266), Parent = p.content, Radius = 28 }, state.training and U.Red or GREEN,
		state.training and "Stop" or "Start training", 30, function()
			local starting = not state.training
			if call(starting and "TrainStart" or "TrainStop") and starting then p.holder.Visible=false end
		end)
	text(capped and "" or string.format("Next level  +%s per rep", C.Short(C.RepStrength(d.dumbLevel + 1))), 24, MUTED, { Size = UDim2.fromOffset(430, 36), Position = UDim2.fromOffset(0, 370), Parent = p.content, NoStroke = true })
	text("Stop anytime during a set", 24, MUTED, { Size = UDim2.fromOffset(430, 36), Position = UDim2.fromOffset(470, 370), Parent = p.content, NoStroke = true })
end

-- --- Settings (saved to the account) ---
panel("Settings", "Settings", { U.Menu[1][4], U.Menu[1][5] })
local settings = { music = 0.5, sfx = 0.7, shake = true, short = false }
local saveQueued = false
local function applySettings()
	groups.Music.Volume, groups.SFX.Volume = settings.music, settings.sfx
	_G.ShakeScale = settings.shake and 1 or 0
	_G.ShortOnly = settings.short
end
local function saveSettings()
	applySettings()
	if saveQueued then return end
	saveQueued = true
	task.delay(0.6, function()
		saveQueued = false
		Request:InvokeServer("Settings", settings)
	end)
end
local sliderConns = {}
renderers.Settings = function()
	local p = panels.Settings
	clear(p.content)
	for _, c in sliderConns do c:Disconnect() end
	table.clear(sliderConns)
	p.sub.Text = "Saved to your account"
	local rowsDef = { { "Music", "music", "slider" }, { "Sound effects", "sfx", "slider" }, { "Camera shake", "shake", "toggle" }, { "Short cinematics only", "short", "toggle" } }
	for i, def in rowsDef do
		local row = card({ Size = UDim2.fromOffset(900, 90), Position = UDim2.fromOffset(0, 4 + (i - 1) * (state and state.god and 93 or 110)), Parent = p.content }, 22)
		text(def[1], 32, INK, { Size = UDim2.fromOffset(420, 90), Position = UDim2.fromOffset(30, 0), Parent = row, TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
		local key = def[2]
		if def[3] == "slider" then
			local track = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(380, 16), Position = UDim2.fromOffset(470, 37), BackgroundColor3 = GREY[1], Parent = row }, { corner(8), stroke(2) })
			local fill = new("Frame", { Size = UDim2.fromScale(settings[key], 1), BackgroundColor3 = rgb(111, 130, 255), Parent = track }, { corner(8) })
			local knob = new("Frame", { Size = UDim2.fromOffset(36, 40), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(settings[key], 0, 0.5, 0), BackgroundColor3 = WHITE, ZIndex = 3, Parent = track }, { corner(18), stroke(4) })
			local dragging = false
			local function setFromX(x)
				local v = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
				settings[key] = math.floor(v * 20 + 0.5) / 20
				fill.Size = UDim2.fromScale(settings[key], 1)
				knob.Position = UDim2.new(settings[key], 0, 0.5, 0)
				saveSettings()
			end
			track.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = true
					setFromX(input.Position.X)
				end
			end)
			table.insert(sliderConns, UserInputService.InputChanged:Connect(function(input)
				if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then setFromX(input.Position.X) end
			end))
			table.insert(sliderConns, UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
			end))
		else
			local on = settings[key]
			local sw = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(110, 50), Position = UDim2.fromOffset(760, 20), BackgroundColor3 = on and GREEN[2] or GREY[1], Parent = row }, { corner(25), stroke(3) })
			new("Frame", { Size = UDim2.fromOffset(42, 42), Position = UDim2.fromOffset(on and 64 or 4, 4), BackgroundColor3 = WHITE, Parent = sw }, { corner(21) })
			sw.Activated:Connect(function()
				settings[key] = not settings[key]
				_G.PlaySfx("Click")
				saveSettings()
				renderers.Settings()
			end)
		end
	end
 if state and state.ownerEligible then
  local function cameraMode() -- owner camera: free flight, orbit, cinematic shots, film filters (Shift+C)
   for _,q in panels do q.holder.Visible=false end
   if _G.ToggleCameraMode then _G.ToggleCameraMode() end
  end
  if state.god then
   button({Size=UDim2.fromOffset(290,60),Position=UDim2.fromOffset(0,382),Parent=p.content},U.Cues,"Cue: "..C.Cues[state.d.cue][1].."  ›",23,function() call("GodGear","cue") end)
   button({Size=UDim2.fromOffset(290,60),Position=UDim2.fromOffset(305,382),Parent=p.content},ORANGE,"Dumbbell "..state.d.dumbLevel.."  ›",23,function() call("GodGear","bell") end)
   button({Size=UDim2.fromOffset(290,60),Position=UDim2.fromOffset(610,382),Parent=p.content},PURPLE,"Camera mode",23,cameraMode)
  else
   button({Size=UDim2.fromOffset(435,60),Position=UDim2.fromOffset(0,382),Parent=p.content},PURPLE,"Camera mode",23,cameraMode)
   button({Size=UDim2.fromOffset(435,65),Position=UDim2.fromOffset(0,452),Parent=p.content},state.ownerBoost and GREEN or U.Cues,state.ownerBoost and "Owner boost  ·  ON" or "Owner boost  ·  OFF",27,function() call("OwnerBoost",not state.ownerBoost) end)
  end
  button({Size=UDim2.fromOffset(435,65),Position=UDim2.fromOffset(460,452),Parent=p.content},state.god and GREEN or ORANGE,state.god and "God Mode  ·  ON" or "God Mode  ·  OFF",30,function() call("GodMode",not state.god) end)
 end
end

-- menu buttons (Figma component "MenuButton": icon + label) with badges
for i, m in U.Menu do
	local holder, body = button({ Hud = true, Size = UDim2.fromOffset(132, 124), LayoutOrder = i, Parent = menu, Radius = 38 }, { m[4], m[5] }, "", 1, function() open(m[1]) end)
	local glyph = hudIcon(body,m[1],61,UDim2.new(.5,0,0,12))
	glyph.AnchorPoint = Vector2.new(.5,0)
	local caption=text(m[3],25,WHITE,{Size=UDim2.new(1,-14,0,35),Position=UDim2.fromOffset(7,74),TextScaled=true,Parent=body})
 new("UITextSizeConstraint",{MaxTextSize=25,Parent=caption})
 holder.Name = m[1]
	local bHolder, bBody = box({ Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(100, 8), Parent = holder, ZIndex = 6 }, rgb(255, 59, 59), rgb(255, 59, 59), 20, 4)
	badges[m[1]] = { holder = bHolder, label = text("!", 17, nil, { Size = UDim2.fromScale(1, 1), Parent = bBody }) }
	bHolder.Visible = false
end
local function setBadge(key, value)
	local b = badges[key]
	b.holder.Visible = value ~= nil
	if value then b.label.Text = tostring(value) end
end
local function updateBadges()
	if not state then return end
	local d = state.d
	local day = os.time() // 86400
	local ready = d.daily.day ~= day and 1 or 0
	for i, pt in C.Playtime do
		if not state.claimed[i] and os.time() - state.join >= pt[1] * 60 then ready += 1 end
	end
	setBadge("Bonus", ready > 0 and ready or nil)
	local on, free = 0, 0
	for _, it in d.inv do
		if it.eq then on += 1 else free += 1 end
	end
	setBadge("Inventory", (#d.inv >= C.MaxInventory * 0.9 or (on < C.MaxEquipped and free > 0)) and "!" or nil)
end

-- ===== Onboarding: 3 steps, with an arrow above the gym / kiosk =====
local TIPS = {
	{ "Step into the arc. Press Shoot when the meter peaks.", "Step 1 of 3" },
	{ "Go to the gym in front of your base and start training", "Step 2 of 3" },
	{ "Open the cue shop in front of your base and upgrade your cue", "Step 3 of 3" },
}
local arrow, arrowStep
local function baseObj(...)
	local o = workspace.World:FindFirstChild("Base" .. state.slot)
	for _, n in { ... } do o = o and o:FindFirstChild(n) end
	return o
end
local function updateTutorial()
	local step = state and state.d.tutorial or 4
	tipHolder.Visible = step <= 3 and hud.Visible
	if step == arrowStep then return end
	arrowStep = step
	if arrow then
		arrow:Destroy()
		arrow = nil
	end
	if step > 3 then return end
	tipText.Text, tipStep.Text = TIPS[step][1], TIPS[step][2]
	if step >= 2 then
		local target = step == 2 and baseObj("Gym", "TrainSpot") or baseObj("CueShop")
		if target then
			arrow = new("BillboardGui", { Size = UDim2.fromOffset(90, 90), StudsOffset = Vector3.new(0, 9, 0), AlwaysOnTop = true, Adornee = target, Parent = gui })
			local a = text("▼", 80, U.Title, { Size = UDim2.fromScale(1, 1), Parent = arrow })
			TweenService:Create(a, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.fromOffset(0, 16) }):Play()
		end
	end
end

-- ===== Kiosk hint when the next cue is affordable =====
local kioskTag
local function updateKioskTag()
	if not state then return end
	local nxt = C.Cues[state.d.cue + 1]
	local can = nxt and (state.ownerBoost or state.d.cash >= nxt[3])
	if can and not kioskTag then
		local shop = baseObj("CueShop")
		if shop then
			kioskTag = new("BillboardGui", { Size = UDim2.fromOffset(230, 46), StudsOffset = Vector3.new(0, 13.5, 0), MaxDistance = 90, Adornee = shop, Parent = gui })
			local _, b = box({ Size = UDim2.fromScale(1, 1), Parent = kioskTag }, GREEN[1], GREEN[2], 23, 3)
			text("UPGRADE READY", 24, nil, { Size = UDim2.fromScale(1, 1), Parent = b })
		end
	elseif not can and kioskTag then
		kioskTag:Destroy()
		kioskTag = nil
	end
end

-- The local player opens only their own stations. Server actions check their location again.
do
 local pads={}
 for i=1,4 do
  local base=workspace.World["Base"..i]
  for _,key in {"Gym","Cues"} do
   local model=key=="Gym" and base.GymPad or base.ShopPad
   local arcs={}
   for k=0,35 do arcs[k+1]=model[string.format("Arc%02d",k)] end
   table.insert(pads,{slot=i,key=key,zone=model.Zone,arcs=arcs})
  end
 end
 local title=new("BillboardGui",{Name="TrainingTitle",Size=UDim2.fromOffset(175,46),StudsOffsetWorldSpace=Vector3.new(0,3.4,0),LightInfluence=0,AlwaysOnTop=true,Enabled=false,Parent=gui})
 local caption=text("TRAINING",31,WHITE,{Size=UDim2.fromScale(1,1),Parent=title})
 local ink=caption:FindFirstChildOfClass("UIStroke")
 local timer,opacity=0,0
 local previousCharacter

 RunService.Heartbeat:Connect(function(dt)
  timer+=dt
  if timer<.08 then return end
  local step=timer
  timer=0
  local phase=workspace:GetServerTimeNow()*2.8
  local character=plr.Character
  local root=character and character:FindFirstChild("HumanoidRootPart")
  local hum=character and character:FindFirstChildOfClass("Humanoid")
  local alive=root and hum and hum.Health>0 and state and plr:GetAttribute("BHReady")
  local changed=character~=previousCharacter
  previousCharacter=character
  local show=false
  for _,pad in pads do
   local delta=root and root.Position-pad.zone.Position
   if delta and delta.Magnitude<100 then
    for k,arc in pad.arcs do
     arc.LocalTransparencyModifier=.14+.22*(1-math.cos(phase-k*math.pi/18))
    end
   end
   local own=alive and state.slot==pad.slot
   local radius=pad.zone.Size.Y*.5
   local inside=own and delta.Y>=-.1 and delta.Y<=6 and delta.X*delta.X+delta.Z*delta.Z<=radius*radius
   if inside and not state.training and (changed or not pad.inside) and not _G.ThrowBusy then open(pad.key,true) end
   pad.inside=inside
   if own and pad.key=="Gym" then
    title.Adornee=pad.zone.Parent.Parent.Gym.Dumbbell
    show=delta.Magnitude<=(pad.near and 14 or 12)
    pad.near=show
   else pad.near=false end
  end
  opacity=math.clamp(opacity+(show and step*5 or -step*5),0,1)
  title.Enabled=opacity>0
  caption.TextTransparency=1-opacity
  if ink then ink.Transparency=1-opacity end
 end)
end
-- The needle starts when the player crosses the line, and a single activation samples it.
local power, elapsed, inZone = 0, 0, false
local function preview(p)
	if not state then return end
	local zone = C.ZoneOf(C.Distance(p,state.d,state.passes))
	local rar = C.Rarities[zone]
	previewLabel.Text = string.format("→ TABLE %d • %s",zone,string.upper(rar[1]))
	
end
local function shoot()
	if not inZone or sending or not shotBar.Visible or _G.ThrowBusy or workspace:GetServerTimeNow() < (_G.ShotReadyAt or 0) then return end
	sending = true
	local invoked, ok, message = pcall(Request.InvokeServer,Request,"Throw",power)
	if not invoked then toast("Shot failed. Try again.",U.Bad)
	elseif message then toast(message,ok and U.Title or U.Bad) end
	sending = false
end
shootHit.Activated:Connect(shoot)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and (input.KeyCode == Enum.KeyCode.ButtonX or input.KeyCode == Enum.KeyCode.E) then shoot() end
end)

local shownZone = 0
RunService.RenderStepped:Connect(function(dt)
	local char = plr.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local modal = false
	for _, panelState in panels do if panelState.holder.Visible then modal = true; break end end
	inZone = state and plr:GetAttribute("BHReady") and root and hum and hum.Health > 0 and C.InShotZone(root.Position)
		and not state.training and not modal and hud.Visible and not _G.ThrowBusy
	if inZone then
		elapsed += dt
		power = .06 + .94 * (1 - math.abs(((elapsed * .9) % 2) - 1))
		powerFill.Size = UDim2.new(power * .98, 0, 1, -12)
		local zone = C.ZoneOf(C.Distance(power,state.d,state.passes))
		if zone ~= shownZone then shownZone = zone; preview(power) end
	else
		elapsed, power, shownZone = 0, 0, 0
	end
	local active = inZone and not sending and workspace:GetServerTimeNow() >= (_G.ShotReadyAt or 0)
	shotBar.Visible = inZone == true
	setShootEnabled(active == true)
	shootLabel.Text = active and "SHOOT!" or "WAIT"
	local input = UserInputService:GetLastInputType()
	hint.Text = input.Name:match("^Gamepad") and "X · Time your shot" or "Tap at the right moment"
end)

-- ===== Server events =====
local shownCash, targetCash = 0, 0
local function renderStats()
	if not state then return end
	local cue = C.Cues[state.d.cue] or C.Cues[1]
 if state.passes.DragonCue and C.DragonCue[2] > cue[2] then cue = C.DragonCue end
 cueLabel.Text = cue[1] .. " Cue"
 incomeLabel.Text = "+$" .. C.Short(state.income) .. "/s"
	strLabel.Text = C.Short(state.d.strength)
end
local cashPop = new("UIScale", { Parent = cashBody.Parent })
local lastGain = 0
local function cashGain(amount) -- bounce the cash pill and let the gain drift out of it
	if amount <= 0 or os.clock() - lastGain < 0.35 then return end
	lastGain = os.clock()
	cashPop.Scale = 1.1
	tween(cashPop, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	local f = text("+$" .. C.Short(amount), 34, rgb(150, 255, 140), { Size = UDim2.fromOffset(260, 44), Position = UDim2.fromOffset(120, 70), Parent = cashBody, ZIndex = 8 })
	tween(f, 1.1, { Position = UDim2.fromOffset(120, 120), TextTransparency = 1 })
	local st = f:FindFirstChildOfClass("UIStroke")
	if st then tween(st, 1.1, { Transparency = 1 }) end
	task.delay(1.2, function() f:Destroy() end)
end
RunService.Heartbeat:Connect(function(dt) -- smooth cash count-up
	shownCash += (targetCash - shownCash) * math.min(1, dt * 8)
	if math.abs(targetCash - shownCash) < 1 then shownCash = targetCash end
	cashLabel.Text = state and state.ownerBoost and "$∞" or "$" .. C.Short(shownCash)
end)

local firstState = true
Fx.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "State" then
  local ownerChanged = not state or state.god ~= a.god or (a.god and (state.d.cue~=a.d.cue or state.d.dumbLevel~=a.d.dumbLevel)) or state.ownerBoost ~= a.ownerBoost or state.ownerEligible ~= a.ownerEligible
  state = a
  if ownerChanged and panels.Settings.holder.Visible then renderers.Settings() end
        trainingBar.Visible=a.training==true
        if a.training then panels.Gym.holder.Visible=false end
		_G.MySlot, _G.MyCue = a.slot, a.d.cue
		_G.OwnerEligible = a.ownerEligible == true -- unlocks the owner camera mode (CameraDirector)
		if not firstState and a.d.cash > targetCash then cashGain(a.d.cash - targetCash) end
		targetCash = a.d.cash
		if firstState then
			firstState = false
			shownCash = a.d.cash
			for k, v in a.d.settings or {} do settings[k] = v end
			applySettings()
			offlineNotice = a.offlineAmount and a.offlineAmount > 0 and { a.offlineAmount, a.offlineElapsed }
			if offlineNotice then
				task.spawn(function()
					while not plr:GetAttribute("BHReady") do task.wait(.15) end
					local amount, seconds = table.unpack(offlineNotice)
					local label = string.format("Offline income  +$%s  ·  %dh %02dm", C.Short(amount), seconds // 3600, seconds % 3600 // 60)
					toast(label,U.Title)
					_G.PlaySfx("Reward")
				end)
			end
		end
		renderStats()
		updateBadges()
		updateTutorial()
		updateKioskTag()
		
		rerender()
        plr:SetAttribute("BHProfileUI",true)
	elseif kind == "Cash" then
		targetCash = a
		if state then state.d.cash = a end
        if state and panels.Cues.holder.Visible then renderers.Cues() end
		renderStats()
		updateBadges()
		updateKioskTag()
		if panels.Bonus.holder.Visible and bonusTick then bonusTick() end
	elseif kind == "Train" then
        trainingBar.Visible=a==true
        if a then panels.Gym.holder.Visible=false end
		if state then state.training, state.reps = a == true, 0 end
		
		if panels.Gym.holder.Visible then renderers.Gym() end
	elseif kind == "Rep" then
        _G.PlaySfx("TrainingRep")
		if state then state.d.strength, state.reps = a, c end
		renderStats()
		strScale.Scale = 1.12
		tween(strScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		if panels.Gym.holder.Visible then renderers.Gym() end
	elseif kind == "Open" then
		if panels[a] then open(a, true) end
	elseif kind == "Toast" then
		toast(a, b and U.Title or U.Bad)
		if b then _G.PlaySfx("Reward") end
	elseif kind == "CueSwap" then -- the old cue disappears in a puff
		local puff = new("Part", { Anchored = true, CanCollide = false, Transparency = 1, Size = Vector3.one, Position = a, Parent = workspace })
		local e = new("ParticleEmitter", {
			Color = ColorSequence.new(U.Title, WHITE), Speed = NumberRange.new(6, 12), Lifetime = NumberRange.new(0.4, 0.8),
			SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.8, 0), LightEmission = 1, Rate = 0, Parent = puff,
		})
		e:Emit(40)
		task.delay(2, puff.Destroy, puff)
	end
end)

_G.SetHudVisible = function(on)
	hud.Visible = on
	if not on then
		for _, p in panels do p.holder.Visible = false end
	end
	updateTutorial()
end

Request:InvokeServer("Sync")