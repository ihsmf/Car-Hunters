-- GIFTS: 7-day login streak + playtime chests. Button in the left column, red dot when something can be claimed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local R = require(Shared:WaitForChild("RewardConfig"))
local Util = require(Shared:WaitForChild("Util"))
local Icons = require(Shared:WaitForChild("Icons"))

local RW = {}
local K, UI
local P
local C = Color3.fromRGB
local w = {}
local sessionBase, sessionAt = 0, os.clock()

local function sessionNow()
	return sessionBase + (os.clock() - sessionAt)
end

local function fmt(sec)
	sec = math.max(0, math.floor(sec))
	if sec >= 3600 then
		return string.format("%dh %02dm", sec // 3600, sec % 3600 // 60)
	end
	return string.format("%d:%02d", sec // 60, sec % 60)
end

local function partsText(parts)
	local out = {}
	for _, id in ipairs({ "bolts", "tire", "engine", "turbo", "core" }) do
		if parts and parts[id] then
			table.insert(out, parts[id] .. " " .. id)
		end
	end
	return table.concat(out, ", ")
end

local function claimable(st)
	if not st or not st.daily then
		return false
	end
	if st.daily.last ~= st.daily.today then
		return true
	end
	for i, c in ipairs(R.Chests) do
		if not (st.chests and st.chests[i]) and sessionNow() >= c.minutes * 60 then
			return true
		end
	end
	return false
end

local function build()
	-- button next to SHOP / JOBS
	local brow = K.hud.leftCol:FindFirstChild("Buttons")
	local holder = K.new("Frame", { Size = UDim2.fromOffset(66, 88), BackgroundTransparency = 1, LayoutOrder = 3 }, brow)
	local b = K.toy(holder, { Text = "", Color = P.green, Size = UDim2.fromOffset(66, 66), OnClick = function() UI.TogglePanel("rewards") end })
	K.hud.icon(b.face, "gift", 46, UDim2.fromOffset(10, 8)).ZIndex = b.face.ZIndex + 1
	K.text(holder, { Text = "GIFTS", TextSize = 15, Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, Outline = 2.5 })
	w.dot = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(60, 4), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = P.red, ZIndex = 30, Visible = false }, holder)
	K.corner(w.dot, 9)
	K.stroke(w.dot, P.white, 2)

	local p = K.panelShell("rewards", "GIFTS", 940, 600, P.green)
	local c = p.content
	K.text(c, { Text = "DAILY STREAK  -  come back every day, missing a day starts again", Font = K.BODY, TextSize = 17, TextColor3 = P.ink, Size = UDim2.new(1, 0, 0, 24), ZIndex = 22 })
	w.days = K.new("Frame", { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 200), BackgroundTransparency = 1, ZIndex = 22 }, c)
	K.list(w.days, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
	K.text(c, { Text = "PLAYTIME CHESTS  -  open them as you play this session", Font = K.BODY, TextSize = 17, TextColor3 = P.ink, Position = UDim2.fromOffset(0, 246), Size = UDim2.new(1, 0, 0, 24), ZIndex = 22 })
	w.chests = K.new("Frame", { Position = UDim2.fromOffset(0, 276), Size = UDim2.new(1, 0, 0, 200), BackgroundTransparency = 1, ZIndex = 22 }, c)
	K.list(w.chests, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center)
end

local function card(parent, order, color, title, body, btnText, btnColor, onClick, highlight)
	local f = K.new("Frame", { Size = UDim2.fromOffset(order and 118 or 160, 196), BackgroundColor3 = P.white, LayoutOrder = order or 0, ZIndex = 23 }, parent)
	K.corner(f, 16)
	K.stroke(f, highlight and P.yellow or color, highlight and 5 or 3)
	local top = K.new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = color, ZIndex = 24 }, f)
	K.corner(top, 16)
	K.text(top, { Text = title, TextSize = 18, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 25, Outline = 2 })
	K.new("ImageLabel", { Position = UDim2.new(0.5, -26, 0, 40), Size = UDim2.fromOffset(52, 52), BackgroundTransparency = 1, Image = Icons.Get("gift") or "", ZIndex = 24 }, f)
	K.text(f, { Text = body, Font = K.BODY, TextSize = 13, TextColor3 = P.ink, TextWrapped = true, Position = UDim2.fromOffset(6, 96), Size = UDim2.new(1, -12, 0, 44), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 24 })
	K.toy(f, { Text = btnText, Color = btnColor, Size = UDim2.new(1, -16, 0, 44), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), TextSize = 16, ZIndex = 25, OnClick = onClick })
end

local function refresh(st, open)
	w.dot.Visible = claimable(st)
	if open ~= "rewards" or not st.daily then
		return
	end
	K.clear(w.days)
	local today = st.daily.today
	local claimedToday = st.daily.last == today
	local nextDay = claimedToday and st.daily.day or R.NextDay(st.daily, today)
	for i, e in ipairs(R.Daily) do
		local done = (claimedToday and i <= st.daily.day) or (not claimedToday and i < nextDay)
		local isNext = i == nextDay and not claimedToday
		local body = "$" .. Util.FormatNumber(R.Money(e, K.store.Income)) .. "\n" .. partsText(e.parts) .. (e.pity and "\n+ Epic guarantee" or "")
		card(w.days, i, i == 7 and P.orange or P.blue, "DAY " .. i, body, done and "DONE" or (isNext and "CLAIM" or "LOCKED"), done and P.grey or (isNext and P.green or P.grey),
			function()
				if isNext then
					Net.Get("ClaimDaily"):FireServer()
				end
			end, isNext)
	end
	K.clear(w.chests)
	local now = sessionNow()
	for i, e in ipairs(R.Chests) do
		local got = st.chests and st.chests[i]
		local left = e.minutes * 60 - now
		local body = "$" .. Util.FormatNumber(R.Money(e, K.store.Income)) .. "\n" .. partsText(e.parts) .. (e.tuning and "\n+ tuning part" or "")
		card(w.chests, nil, P.green, e.minutes .. " MIN", body, got and "OPENED" or (left <= 0 and "OPEN" or fmt(left)), got and P.grey or (left <= 0 and P.green or P.grey),
			function()
				if not got and left <= 0 then
					Net.Get("ClaimChest"):FireServer(i)
				end
			end, left <= 0 and not got)
	end
end

function RW.Start(ui)
	UI = ui
	K = UI.Kit()
	P = K.P
	build()
	K.store.Changed.Event:Connect(function()
		local st = K.store.State
		if st and st.sessionTime then
			sessionBase, sessionAt = st.sessionTime, os.clock()
		end
	end)
	table.insert(UI.Hooks, refresh)
	task.spawn(function()
		while true do
			task.wait(1)
			local st = K.store.State
			if st then
				refresh(st, K.state.open)
			end
		end
	end)
end

return RW
