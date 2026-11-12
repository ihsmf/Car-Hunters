-- Plaza leaderboard: big screen with tabs (Income / Collection / Rebirths) that cycle every 8 s,
-- rank badges, avatar headshots, and the top 3 players standing as statues on the podium.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))

local LB = {}
local S
local C = Color3.fromRGB
local GOLD, SILVER, BRONZE = C(255, 200, 60), C(214, 220, 230), C(214, 140, 80)
local RANK_COLOR = { GOLD, SILVER, BRONZE }

LB.Tabs = {
	{ id = "income", title = "TOP INCOME", fmt = function(v) return "+$" .. Util.FormatNumber(v) .. "/s" end, value = function(s) return s.income or 0 end },
	{ id = "collection", title = "BIGGEST COLLECTION", fmt = function(v) return "$" .. Util.FormatNumber(v) end, value = function(s) return s.collectionValue or 0 end },
	{ id = "rebirths", title = "MOST REBIRTHS", fmt = function(v) return v .. " REBIRTHS" end, value = function(s) return s.data and s.data.rebirths or 0 end },
}

function LB.Init(hub)
	S = hub
end

local thumbs = {}
local function headshot(userId)
	if thumbs[userId] == nil then
		thumbs[userId] = ""
		task.spawn(function()
			local ok, url = pcall(function()
				return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			end)
			thumbs[userId] = ok and url or ""
		end)
	end
	return thumbs[userId]
end

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local ui = {}
local function build(screen)
	local gui = new("SurfaceGui", { Name = "Board", Face = Enum.NormalId[screen:GetAttribute("Facing") or "Front"], SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 40, LightInfluence = 0, Brightness = 1.4 }, screen)
	local bg = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(14, 16, 24), BorderSizePixel = 0 }, gui)
	new("UIGradient", { Color = ColorSequence.new(C(30, 36, 56), C(10, 12, 18)), Rotation = 90 }, bg)
	ui.title = new("TextLabel", { Size = UDim2.new(1, 0, 0.16, 0), Position = UDim2.fromScale(0, 0.02), BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy,
		TextScaled = true, TextColor3 = GOLD, Text = "" }, bg)
	new("UIStroke", { Color = C(0, 0, 0), Thickness = 3 }, ui.title)
	-- tab pills
	local tabs = new("Frame", { Size = UDim2.new(0.8, 0, 0.07, 0), Position = UDim2.fromScale(0.1, 0.19), BackgroundTransparency = 1 }, bg)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.02, 0), HorizontalAlignment = Enum.HorizontalAlignment.Center }, tabs)
	ui.tabs = {}
	for i, t in ipairs(LB.Tabs) do
		local pill = new("TextLabel", { Size = UDim2.new(0.3, 0, 1, 0), BackgroundColor3 = C(40, 46, 66), Font = Enum.Font.FredokaOne, TextScaled = true,
			TextColor3 = C(200, 206, 220), Text = string.upper(t.id), LayoutOrder = i }, tabs)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, pill)
		ui.tabs[i] = pill
	end
	-- 8 rows
	local list = new("Frame", { Size = UDim2.new(0.92, 0, 0.68, 0), Position = UDim2.fromScale(0.04, 0.3), BackgroundTransparency = 1 }, bg)
	new("UIListLayout", { Padding = UDim.new(0.012, 0) }, list)
	ui.rows = {}
	for i = 1, 8 do
		local row = new("Frame", { Size = UDim2.new(1, 0, 0.113, 0), BackgroundColor3 = i <= 3 and RANK_COLOR[i] or C(255, 255, 255), BackgroundTransparency = i <= 3 and 0.8 or 0.93, LayoutOrder = i }, list)
		new("UICorner", { CornerRadius = UDim.new(0.3, 0) }, row)
		local badge = new("TextLabel", { Size = UDim2.new(0.07, 0, 0.84, 0), Position = UDim2.fromScale(0.01, 0.08), BackgroundColor3 = i <= 3 and RANK_COLOR[i] or C(60, 66, 84),
			Font = Enum.Font.LuckiestGuy, TextScaled = true, TextColor3 = i <= 3 and C(20, 20, 24) or C(230, 230, 236), Text = tostring(i) }, row)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, badge)
		local face = new("ImageLabel", { Size = UDim2.new(0.07, 0, 0.84, 0), Position = UDim2.fromScale(0.095, 0.08), BackgroundColor3 = C(40, 44, 60), Image = "" }, row)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, face)
		local name = new("TextLabel", { Size = UDim2.new(0.48, 0, 0.8, 0), Position = UDim2.fromScale(0.18, 0.1), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne,
			TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(255, 255, 255), Text = "" }, row)
		local value = new("TextLabel", { Size = UDim2.new(0.32, 0, 0.8, 0), Position = UDim2.fromScale(0.66, 0.1), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne,
			TextScaled = true, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C(52, 208, 88), Text = "" }, row)
		ui.rows[i] = { row = row, face = face, name = name, value = value }
	end
end

-- top-3 avatar statues
local statues = {}
local function placeStatue(rank, player)
	local spot
	for _, d in ipairs(ui.spots or {}) do
		if d:GetAttribute("Rank") == rank then
			spot = d
		end
	end
	if not spot then
		return
	end
	local key = player and player.UserId or 0
	if statues[rank] and statues[rank].key == key then
		return
	end
	if statues[rank] then
		statues[rank].model:Destroy()
		statues[rank] = nil
	end
	if not player then
		return
	end
	task.spawn(function()
		local ok, model = pcall(function()
			return Players:CreateHumanoidModelFromUserId(player.UserId)
		end)
		if not ok or not model or not spot.Parent then
			return
		end
		model.Name = "Statue_" .. rank
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
			end
		end
		local _, size = model:GetBoundingBox()
		model:PivotTo(CFrame.new(spot.Position + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, spot:GetAttribute("Yaw") or 0, 0))
		local hl = Instance.new("Highlight")
		hl.FillColor = RANK_COLOR[rank]
		hl.FillTransparency = 0.75
		hl.OutlineColor = RANK_COLOR[rank]
		hl.Parent = model
		model.Parent = Workspace
		if statues[rank] then
			statues[rank].model:Destroy()
		end
		statues[rank] = { key = key, model = model }
	end)
end

local tabIndex = 0
local function refresh()
	tabIndex = tabIndex % #LB.Tabs + 1
	local tab = LB.Tabs[tabIndex]
	local entries = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local s = S.Data.Get(p)
		if s and s.ready then
			table.insert(entries, { player = p, v = tab.value(s) })
		end
	end
	table.sort(entries, function(a, b)
		return a.v > b.v
	end)
	ui.title.Text = tab.title
	for i, pill in ipairs(ui.tabs) do
		pill.BackgroundColor3 = i == tabIndex and GOLD or C(40, 46, 66)
		pill.TextColor3 = i == tabIndex and C(20, 20, 24) or C(200, 206, 220)
	end
	for i, r in ipairs(ui.rows) do
		local e = entries[i]
		r.row.Visible = e ~= nil
		if e then
			r.name.Text = e.player.DisplayName
			r.value.Text = tab.fmt(e.v)
			r.face.Image = headshot(e.player.UserId)
		end
	end
	-- statues always show the income podium
	local byIncome = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local s = S.Data.Get(p)
		if s and s.ready then
			table.insert(byIncome, { player = p, v = s.income or 0 })
		end
	end
	table.sort(byIncome, function(a, b)
		return a.v > b.v
	end)
	for rank = 1, 3 do
		placeStatue(rank, byIncome[rank] and byIncome[rank].player)
	end
end

function LB.Start()
	task.spawn(function()
		local map = Workspace:WaitForChild("GeneratedMap", 60)
		local screen = CollectionService:GetTagged("LeaderboardScreen")[1]
		if not map or not screen then
			warn("[Leaderboard] screen not found")
			return
		end
		build(screen)
		ui.spots = {}
		for _, d in ipairs(screen.Parent:GetChildren()) do
			if string.match(d.Name, "^StatueSpot") then
				table.insert(ui.spots, d)
			end
		end
		while true do
			pcall(refresh)
			task.wait(8)
		end
	end)
end

return LB
