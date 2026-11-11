-- Minimap: districts, roads, running lanes, garages, shops, players, hot drop. Tap to toggle the full map.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("MapConfig"))
local BaseLayout = require(Shared:WaitForChild("BaseLayout"))

local C = Color3.fromRGB
local Minimap = {}
local K, store, extra
local frame, content, me, hotIcon, baseIcons
local dots = {}
local big = false

local HW = MapConfig.MapHalfWidth
local Z0, Z1 = MapConfig.StartZ, MapConfig.EndZ
local SMALL = { size = 190, window = 260 } -- pixels, studs shown across the small map

-- world (x, z) -> content pixel; +Z is up on the map
local function px(x, z, s)
	return (x + HW) * s, (Z1 - z) * s
end

local function rect(parent, x1, z1, x2, z2, color, s, z, corner)
	local ax, ay = px(math.min(x1, x2), math.max(z1, z2), s)
	local f = K.new("Frame", { Position = UDim2.fromOffset(ax, ay), Size = UDim2.fromOffset(math.abs(x2 - x1) * s, math.abs(z2 - z1) * s),
		BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = z or 3 }, parent)
	if corner then
		K.corner(f, corner)
	end
	return f
end

local function icon(parent, emoji, color, size)
	local f = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size or 20, size or 20), BackgroundColor3 = color, ZIndex = 8 }, parent)
	K.corner(f, (size or 20) / 2)
	K.stroke(f, K.P.ink, 2)
	K.text(f, { Text = emoji, Font = K.BODY, TextSize = (size or 20) * 0.62, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9 })
	return f
end

local function place(obj, x, z, s)
	local a, b = px(x, z, s)
	obj.Position = UDim2.fromOffset(a, b)
end

-- draws the static map at scale s (pixels per stud)
local function draw(s)
	if content then
		content:Destroy()
	end
	content = K.new("Frame", { Size = UDim2.fromOffset(2 * HW * s, (Z1 - Z0) * s), BackgroundColor3 = C(110, 180, 96), BorderSizePixel = 0, ZIndex = 2 }, frame)
	rect(content, -HW, Z0, HW, MapConfig.EntryZ, MapConfig.Plaza.ground, s, 2)
	rect(content, -MapConfig.PromenadeHalfWidth, Z0, MapConfig.PromenadeHalfWidth, MapConfig.EntryZ, MapConfig.Plaza.paving, s, 3)
	for _, zid in ipairs(MapConfig.ZoneOrder) do
		local z = MapConfig.Zones[zid]
		rect(content, -HW, z.zMin - 10, HW, z.zMax + 8, z.palette.ground, s, 2)
	end
	for _, r in ipairs(MapConfig.Roads) do
		rect(content, -HW, r.z - r.width / 2, HW, r.z + r.width / 2, C(56, 58, 66), s, 4)
		rect(content, -HW, r.z - 0.6, HW, r.z + 0.6, C(255, 210, 63), s, 5)
	end
	for _, l in ipairs(MapConfig.SpeedLanes()) do
		rect(content, l[1], l[3], l[2], l[4], C(54, 56, 62), s, 5)
	end
	baseIcons = {}
	for i, c in ipairs(MapConfig.BaseCenters) do
		local b = rect(content, c.x - MapConfig.BasePlot.x / 2, c.z - MapConfig.BasePlot.z / 2, c.x + MapConfig.BasePlot.x / 2, c.z + MapConfig.BasePlot.z / 2, C(150, 154, 162), s, 4, 4)
		baseIcons[i] = b
	end
	place(icon(content, "🔧", K.P.red, 18), MapConfig.Shop.x, MapConfig.Shop.z, s)
	place(icon(content, "👑", C(232, 178, 50), 18), MapConfig.DonateStall.x, MapConfig.DonateStall.z, s)
	place(icon(content, "📜", C(170, 120, 70), 16), MapConfig.ContractBoard.x, MapConfig.ContractBoard.z, s)
	for _, g in ipairs(MapConfig.Gates) do
		local open = store.State and store.State.zones and store.State.zones[g.zone]
		rect(content, -MapConfig.GateHalfWidth, g.z - 2, MapConfig.GateHalfWidth, g.z + 2, open and C(90, 200, 110) or K.P.red, s, 6)
		if not open then
			place(icon(content, "🔒", K.P.red, 16), 0, g.z, s)
		end
	end
	hotIcon = icon(content, "📦", K.P.red, 22)
	hotIcon.Visible = false
	dots = {}
	me = K.new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1, Text = "▲",
		Font = K.BODY, TextSize = 20, TextColor3 = K.P.white, ZIndex = 12 }, content)
	K.new("UIStroke", { Color = K.P.ink, Thickness = 2.5 }, me)
	return s
end

local scale = 1
local function setMode(isBig)
	big = isBig
	if big then
		local vp = Workspace.CurrentCamera.ViewportSize
		local h = math.min(vp.Y * 0.8, 820)
		scale = h / (Z1 - Z0)
		frame.Size = UDim2.fromOffset(2 * HW * scale, h)
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5, 0.5)
	else
		scale = SMALL.size / SMALL.window
		frame.Size = UDim2.fromOffset(SMALL.size, SMALL.size)
		frame.AnchorPoint = Vector2.new(1, 0)
		frame.Position = UDim2.new(1, -16, 0, 16)
	end
	draw(scale)
end

function Minimap.Start(kit, extraModule)
	K = kit
	store = K.store
	extra = extraModule
	frame = K.new("TextButton", { Name = "Minimap", Text = "", AutoButtonColor = false, BackgroundColor3 = C(40, 44, 52), ClipsDescendants = true, ZIndex = 2 }, K.gui)
	K.corner(frame, 18)
	K.stroke(frame, K.P.ink, 4)
	frame.Activated:Connect(function()
		setMode(not big)
	end)
	setMode(false)
	store.Changed.Event:Connect(function()
		draw(scale)
	end)
	RunService.RenderStepped:Connect(function()
		local char = Players.LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		frame.Visible = K.state.open == nil or big
		if not hrp or not content then
			return
		end
		local pos = hrp.Position
		place(me, pos.X, pos.Z, scale)
		local look = hrp.CFrame.LookVector
		me.Rotation = math.deg(math.atan2(look.X, look.Z))
		if not big then
			local a, b = px(pos.X, pos.Z, scale)
			content.Position = UDim2.fromOffset(SMALL.size / 2 - a, SMALL.size / 2 - b)
		else
			content.Position = UDim2.new()
		end
		-- own garage highlight
		local st = store.State
		for i, b in ipairs(baseIcons) do
			b.BackgroundColor3 = (st and st.baseIndex == i) and K.P.orange or C(150, 154, 162)
		end
		-- other players
		local seen = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= Players.LocalPlayer then
				local c = p.Character
				local r = c and c:FindFirstChild("HumanoidRootPart")
				if r then
					local d = dots[p]
					if not d or not d.Parent then
						d = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(9, 9), BackgroundColor3 = K.P.blue, ZIndex = 10 }, content)
						K.corner(d, 5)
						K.stroke(d, K.P.white, 1.5)
						dots[p] = d
					end
					place(d, r.Position.X, r.Position.Z, scale)
					seen[p] = true
				end
			end
		end
		for p, d in pairs(dots) do
			if not seen[p] then
				d:Destroy()
				dots[p] = nil
			end
		end
		local hot = extra.HotDrop()
		hotIcon.Visible = hot ~= nil and hot.kind == "start"
		if hotIcon.Visible then
			place(hotIcon, hot.pos.X, hot.pos.Z, scale)
		end
	end)
end

return Minimap
