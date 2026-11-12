-- World markers (always on top) + an edge arrow pointing to the current objective.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local MapConfig = require(Shared:WaitForChild("MapConfig"))
local BaseLayout = require(Shared:WaitForChild("BaseLayout"))

local T = Strings.T
local C = Color3.fromRGB
local Markers = {}
local K, store, extra
local folder, arrow, arrowLabel
local marks = {}

local function anchorAt(name, pos)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.Position = pos
	p.Parent = folder
	return p
end

-- icon bubble + label + distance
local function makeMark(id, icon, label, color, pos, maxDist)
	local adornee = anchorAt("M_" .. id, pos)
	local bb = K.new("BillboardGui", { Name = "Mark_" .. id, Adornee = adornee, AlwaysOnTop = true, Size = UDim2.fromOffset(150, 74),
		StudsOffsetWorldSpace = Vector3.new(0, 4, 0), MaxDistance = maxDist or 2000, LightInfluence = 0, ResetOnSpawn = false }, K.gui.Parent)
	local bubble = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(42, 42), BackgroundColor3 = color }, bb)
	K.corner(bubble, 21)
	K.stroke(bubble, K.P.ink, 3)
	K.text(bubble, { Text = icon, Font = K.BODY, TextSize = 24, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	local l = K.text(bb, { Text = label, TextSize = 16, Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, Outline = 2 })
	local d = K.text(bb, { Text = "", Font = K.BODY, TextSize = 13, Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Center })
	local scale = K.new("UIScale", {}, bubble)
	local m = { id = id, bb = bb, adornee = adornee, label = l, dist = d, color = color, icon = icon, scale = scale, text = label }
	marks[id] = m
	return m
end

local function removeMark(id)
	local m = marks[id]
	if m then
		m.bb:Destroy()
		m.adornee:Destroy()
		marks[id] = nil
	end
end

function Markers.SetPos(id, pos)
	local m = marks[id]
	if m then
		m.adornee.Position = pos
	end
end

local function ensureBase()
	local st = store.State
	if not st or not st.baseIndex then
		return
	end
	local pos = BaseLayout.ToWorld(st.baseIndex, BaseLayout.TrapLocal) + Vector3.new(0, 10, 0)
	if not marks.base then
		makeMark("base", "🏠", T("map_base"), K.P.orange, pos)
	else
		Markers.SetPos("base", pos)
	end
end

local scanned = {}
local function refreshScanner()
	local st = store.State
	local level = st and st.perks and st.perks.scanner or 0
	local drops = Workspace:FindFirstChild("RuntimeDrops")
	local seen = {}
	if level >= 1 and drops then
		for _, m in ipairs(drops:GetChildren()) do
			local pid = m:GetAttribute("PartId")
			local root = m:FindFirstChild("Root")
			if root and (pid == "turbo" or pid == "core") then
				local key = "rare_" .. tostring(m:GetAttribute("PointId"))
				seen[key] = true
				if not marks[key] then
					makeMark(key, pid == "core" and "⚡" or "🌀", "", pid == "core" and C(255, 176, 32) or C(255, 77, 109), root.Position, 420)
				end
			end
		end
	end
	for key in pairs(scanned) do
		if not seen[key] then
			removeMark(key)
		end
	end
	scanned = seen
end

-- the objective arrow: hot drop > carry loot home > nothing
local function objective()
	local hot = extra.HotDrop()
	if hot and hot.kind == "start" and marks.hot then
		return marks.hot
	end
	if store.CarriedTotal() > 0 and marks.base then
		return marks.base
	end
	return nil
end

function Markers.Start(kit, extraModule)
	K = kit
	store = K.store
	extra = extraModule
	folder = Instance.new("Folder")
	folder.Name = "MarkerAnchors"
	folder.Parent = Workspace
	makeMark("shop", "🔧", T("map_shop"), K.P.red, Vector3.new(MapConfig.Shop.x, 18, MapConfig.Shop.z), 260)
	makeMark("donate", "👑", T("map_donate"), C(232, 178, 50), Vector3.new(MapConfig.DonateStall.x, 16, MapConfig.DonateStall.z), 260)
	makeMark("contracts", "📜", T("map_contracts"), C(170, 120, 70), Vector3.new(MapConfig.ContractBoard.x, 12, MapConfig.ContractBoard.z), 160)

	arrow = K.new("Frame", { Name = "ObjectiveArrow", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(64, 64), BackgroundTransparency = 1, Visible = false, ZIndex = 30 }, K.gui)
	local tri = K.text(arrow, { Text = "➤", Font = K.BODY, TextSize = 52, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 30, TextColor3 = K.P.orange })
	K.new("UIStroke", { Color = K.P.ink, Thickness = 3 }, tri)
	arrowLabel = tri

	store.Changed.Event:Connect(ensureBase)
	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t = t + dt
		local cam = Workspace.CurrentCamera
		local char = Players.LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not cam or not hrp then
			return
		end
		-- hot drop marker follows the event
		local hot = extra.HotDrop()
		if hot and hot.kind == "start" then
			if not marks.hot then
				makeMark("hot", "📦", T("hot_drop"), K.P.red, hot.pos + Vector3.new(0, 6, 0))
			end
			marks.hot.scale.Scale = 1 + 0.15 * math.sin(t * 8)
		elseif marks.hot then
			removeMark("hot")
		end
		-- distances
		for _, m in pairs(marks) do
			local d = (m.adornee.Position - hrp.Position).Magnitude
			m.dist.Text = (d > 12) and (math.floor(d) .. " m") or ""
		end
		-- edge arrow
		local obj = objective()
		local busy = K.state.open ~= nil or K.state.cine == true -- no arrow / world labels over panels or cinematics
		for _, m in pairs(marks) do
			if m.bb then
				m.bb.Enabled = not busy
			end
		end
		if obj and not busy then
			local p, onScreen = cam:WorldToViewportPoint(obj.adornee.Position)
			local vp = cam.ViewportSize
			if onScreen and p.Z > 0 and p.X > 40 and p.X < vp.X - 40 and p.Y > 40 and p.Y < vp.Y - 40 then
				arrow.Visible = false
			else
				local inset = game:GetService("GuiService"):GetGuiInset()
				vp = vp - inset
				local cx, cy = vp.X / 2, vp.Y / 2
				local dx, dy = p.X - cx, p.Y - cy
				if p.Z < 0 then
					dx, dy = -dx, -dy
				end
				local ang = math.atan2(dy, dx)
				local rx, ry = cx - 70, cy - 70
				local s = math.min(rx / math.max(math.abs(math.cos(ang)), 1e-3), ry / math.max(math.abs(math.sin(ang)), 1e-3))
				arrow.Position = UDim2.fromOffset(cx + math.cos(ang) * s, cy + math.sin(ang) * s)
				arrow.Rotation = math.deg(ang)
				arrowLabel.TextColor3 = obj.color
				arrow.Visible = true
			end
		else
			arrow.Visible = false
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			ensureBase()
			refreshScanner()
		end
	end)
end

return Markers
