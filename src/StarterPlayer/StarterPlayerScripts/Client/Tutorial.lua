-- First-time tutorial (7 steps) and, afterwards, the "next goal" card. One objective card at the top,
-- a guide beam + marker in the world, and a pulse on the button you need. Progress is saved on the server.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local MapConfig = require(Shared:WaitForChild("MapConfig"))
local CarConfig = require(Shared:WaitForChild("CarConfig"))
local Util = require(Shared:WaitForChild("Util"))
local PartConfig = require(Shared:WaitForChild("PartConfig"))

local Tut = {}
local K, UI, Cine, Guide
local P
local C = Color3.fromRGB
local w = {}
local DONE = 9
local localStep -- optimistic step while the server confirms
local events = { banked = false, checkpoint = false }
local stepSince = {} -- step -> os.clock() when it was first shown

local function trapPad(st)
	local map = Workspace:FindFirstChild("GeneratedMap")
	local base = st.baseIndex and map and map:FindFirstChild("Bases") and map.Bases:FindFirstChild(string.format("Base%02d", st.baseIndex), true)
	return base and base:FindFirstChild("TrapPad")
end

local function nearestDrop(hrp)
	local drops = Workspace:FindFirstChild("RuntimeDrops")
	local best, target = math.huge, nil
	for _, m in ipairs(drops and drops:GetChildren() or {}) do
		local root = m:FindFirstChild("Root")
		if root then
			local d = (root.Position - hrp.Position).Magnitude
			if d < best then
				best, target = d, root
			end
		end
	end
	return target
end

-- cheapest upgrade; .ok = the player can pay for it right now
local function cheapestUpgrade(st)
	local best
	for _, c in ipairs(st.cars) do
		local def = CarConfig.ById[c.typeId]
		if def and c.level < def.maxLevel then
			local cost = CarConfig.UpgradeCost(def, c.level)
			if not best or cost < best.cost then
				local part, n = CarConfig.UpgradeParts(def, c.level)
				best = { cost = cost, part = part, n = n, ok = K.store.Money >= cost and K.store.Banked(part) >= n }
			end
		end
	end
	return best
end

-- step definitions: title, body, colour, target(st, hrp), done(st, hrp) -> bool, progress(st) -> 0..1, text
local STEPS = {
	{ "GO HUNTING", "Walk out through the big arch into the City", P and P.yellow,
		function() return Vector3.new(0, 2, MapConfig.EntryZ + 22) end,
		function(_, hrp) return hrp.Position.Z > MapConfig.EntryZ + 6 end },
	{ "GRAB 3 GLOWING PARTS", "Cars are deadly: one hit and you lose what you carry", nil,
		function(_, hrp) return nearestDrop(hrp) end,
		function() return K.store.CarriedTotal() >= 3 end,
		function() return math.min(K.store.CarriedTotal(), 3) / 3, string.format("%d / 3", math.min(K.store.CarriedTotal(), 3)) end },
	{ "RUN HOME TO BANK THEM", "Back through the arch to the plaza - the dark lanes in the middle make you faster", nil,
		function() return Vector3.new(0, 2, MapConfig.EntryZ - 30) end,
		function() return events.banked end },
	{ "THROW PARTS INTO YOUR TRAP", "Go to the lift in your garage, press THROW, then ALL", nil,
		function(st) return trapPad(st) end,
		function(st) return (st.stats and st.stats.throws or 0) > 0 end, nil, "throw" },
	{ "OPEN YOUR GARAGE", "Your car is parked and earning money every second", nil,
		function() return nil end,
		function() return K.state.open == "garage" end, nil, "garage" },
	{ "UPGRADE A CAR", "Press UPGRADE on a car: more levels = more money", nil,
		function() return nil end,
		-- also passes when nothing is affordable yet (after a short look), so a broke player never gets stuck here
		function(st)
			local up = cheapestUpgrade(st)
			return (st.stats and st.stats.upgrades or 0) > 0 or ((not up or not up.ok) and os.clock() - (stepSince[6] or os.clock()) > 6)
		end, nil, "garage" },
	{ "REACH A CHECKPOINT", "Carry parts to the yellow arch at the far end of the City, then SAVE or RISK", nil,
		function() return Vector3.new(0, 2, MapConfig.Zones.city.zMax - 5) end,
		function() return events.checkpoint end },
	{ "UNLOCK THE HIGHWAY", "Open TELEPORT and unlock the Highway: better parts live there", nil,
		function() return nil end,
		function(st) return st.zones and st.zones.highway == true end, nil, "teleport" },
}

local function build()
	local card = K.new("Frame", { Name = "Objective", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 118), Size = UDim2.fromOffset(600, 108), BackgroundColor3 = P.white,
		ClipsDescendants = true, Visible = false }, K.root)
	K.corner(card, 20)
	K.stroke(card, P.ink, 4)
	w.card = card
	-- the colour badge follows the card's rounded left corners (ClipsDescendants ignores UICorner, so a square badge
	-- used to stick out of the outline): rounded badge + a square filler on its right half
	w.badge = K.new("Frame", { Size = UDim2.fromOffset(108, 108), BackgroundColor3 = P.yellow, BorderSizePixel = 0 }, card)
	K.corner(w.badge, 20)
	w.badgeFill = K.new("Frame", { Position = UDim2.fromOffset(54, 0), Size = UDim2.fromOffset(54, 108), BackgroundColor3 = P.yellow, BorderSizePixel = 0 }, w.badge)
	w.badgeText = K.text(w.badge, { Text = "1/8", TextSize = 32, ZIndex = 2, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 38), TextXAlignment = Enum.TextXAlignment.Center, Outline = 2.5 })
	w.badgeSub = K.text(w.badge, { Text = "STEP", Font = K.BODY, TextSize = 13, ZIndex = 2, Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center })
	-- one dot per step: done = white, current = big, to do = faded
	local dots = K.new("Frame", { Position = UDim2.fromOffset(10, 82), Size = UDim2.new(1, -20, 0, 12), BackgroundTransparency = 1, ZIndex = 2 }, w.badge)
	K.list(dots, Enum.FillDirection.Horizontal, 3, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	w.dots = {}
	for i = 1, DONE - 1 do
		local d = K.new("Frame", { Size = UDim2.fromOffset(8, 8), BackgroundColor3 = P.white, LayoutOrder = i, ZIndex = 3 }, dots)
		K.corner(d, 4)
		w.dots[i] = d
	end
	w.title = K.text(card, { Text = "", TextSize = 26, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(124, 10), Size = UDim2.fromOffset(380, 30) })
	w.body = K.text(card, { Text = "", Font = K.BODY, TextSize = 16, TextColor3 = P.muted, TextWrapped = true, Position = UDim2.fromOffset(124, 42), Size = UDim2.fromOffset(460, 40) })
	local bar = K.new("Frame", { Position = UDim2.fromOffset(124, 88), Size = UDim2.fromOffset(300, 8), BackgroundColor3 = C(230, 232, 236), Visible = false }, card)
	K.corner(bar, 4)
	w.bar = bar
	w.fill = K.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = P.yellow }, bar)
	K.corner(w.fill, 4)
	w.progText = K.text(card, { Text = "", Font = K.BODY, TextSize = 14, TextColor3 = P.orange, Position = UDim2.fromOffset(434, 82), Size = UDim2.fromOffset(80, 20), Visible = false })
	w.skip = K.toy(card, { Text = "SKIP", Color = P.grey, Size = UDim2.fromOffset(74, 34), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), TextSize = 16, Depth = 3,
		Radius = 10, OnClick = function()
			K.confirm("SKIP THE TUTORIAL?", "You can still find every feature on your own.", "SKIP", P.red, Tut.Skip)
		end })
	w.scale = K.new("UIScale", {}, card)
	w.tick = K.text(w.badge, { Text = "OK!", TextSize = 30, TextColor3 = C(120, 255, 150), Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Visible = false, ZIndex = 5 })
end

local pulses = {}
local function pulse(button)
	for b, sc in pairs(pulses) do
		if b ~= button then
			sc.Scale = 1
		end
	end
	if not button then
		return
	end
	local holder = button.holder
	local sc = pulses[button] or holder:FindFirstChild("TutPulse") or K.new("UIScale", { Name = "TutPulse" }, holder)
	pulses[button] = sc
	sc.Scale = 1 + 0.07 * math.abs(math.sin(os.clock() * 4))
end

local shownKey
local function show(key, badge, sub, color, title, body, prog, progText, canSkip)
	w.card.Visible = true
	w.badge.BackgroundColor3 = color
	w.badgeFill.BackgroundColor3 = color
	w.badgeText.Text = badge
	local lim = w.badgeText:FindFirstChildOfClass("UITextSizeConstraint")
	if lim then
		lim.MaxTextSize = #badge > 3 and 22 or 30
	end
	w.badgeSub.Text = sub
	w.title.Text = title
	w.body.Text = body
	w.bar.Visible = prog ~= nil
	w.progText.Visible = prog ~= nil
	if prog then
		w.fill.Size = UDim2.fromScale(prog, 1)
		w.fill.BackgroundColor3 = color
		w.progText.Text = progText or ""
		w.progText.TextColor3 = color
	end
	w.skip.holder.Visible = canSkip
	if shownKey ~= key then
		shownKey = key
		w.scale.Scale = 0.7
		K.tween(w.scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end
end

local function tick()
	local st = K.store.State
	local char = Players.LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not st or not hrp then
		return
	end
	local step = math.max(st.tutorial or 0, localStep or 0, 1)
	if step >= DONE then
		Guide.Point(nil)
		pulse(nil)
		local goal = K.hud.nextGoal
		w.card.ZIndex = 1
		w.card.Position = UDim2.new(0.5, 0, 0, 118)
		K.hud.tutInPanel = false
		if goal and K.state.open == nil then
			show("goal:" .. goal[1], "GOAL", "", P.blue, goal[1], goal[2], nil, nil, false)
		else
			w.card.Visible = false
		end
		return
	end
	local def = STEPS[step]
	-- lost the loot on the way home: point back at the parts
	local lostLoot = step == 3 and K.store.CarriedTotal() == 0 and not events.banked
	if lostLoot then
		def = STEPS[2]
	end
	local color = ({ P.yellow, P.orange, P.green, P.yellow, P.blue, P.blue, P.red, P.green })[step]
	local body = lostLoot and "You lost your parts - grab 3 more, then run home" or def[2]
	if step == 6 then
		local up = cheapestUpgrade(st)
		if up and up.ok then
			body = string.format("Press UPGRADE on a car  ·  needs $%s + %d %s", Util.FormatNumber(up.cost), up.n, PartConfig.Parts[up.part].name)
		elseif up then
			body = string.format("Upgrades need $%s + %d %s - you'll do it later, moving on...", Util.FormatNumber(up.cost), up.n, PartConfig.Parts[up.part].name)
		end
	end
	local prog, progText
	if def[6] then
		prog, progText = def[6]()
	end
	stepSince[step] = stepSince[step] or os.clock()
	for i, d in ipairs(w.dots) do
		d.BackgroundTransparency = i <= step and 0 or 0.6
		d.Size = UDim2.fromOffset(i == step and 11 or 7, i == step and 11 or 7)
	end
	show("step" .. step .. def[1], step .. "/" .. (DONE - 1), "STEP", color, def[1], body, prog, progText, true)
	-- steps that happen inside a panel (garage, upgrade): the card goes on top of the panel's dim, at the very top
	local inPanel = K.state.open ~= nil
	w.card.ZIndex = inPanel and 30 or 1
	K.hud.tutInPanel = inPanel
	w.card.Position = UDim2.new(0.5, 0, 0, inPanel and 4 or 118)
	Guide.Point(def[4](st, hrp))
	pulse(def[8] == "throw" and K.hud.throw or (def[8] == "garage" and K.hud.garageBtn) or (def[8] == "teleport" and K.hud.teleportBtn) or nil)
	if def == STEPS[step] and def[5](st, hrp) then
		localStep = step + 1
		events.banked = step >= 3 and events.banked
		Net.Get("TutorialStep"):FireServer(step + 1)
		UI.Sfx("step")
		if step + 1 == DONE then
			Cine.Title("TUTORIAL COMPLETE!", P.yellow, 1.6, 90, 0.35)
			Cine.Sub("Keep unlocking districts to get better parts", Color3.new(1, 1, 1), 3.2, 0.5)
		else
			-- quiet confirmation: green tick on the card
			w.tickToken = (w.tickToken or 0) + 1
			local token = w.tickToken
			w.tick.Visible = true
			w.tick.TextTransparency = 0
			K.tween(w.tick, 0.9, { TextTransparency = 1 })
			task.delay(0.9, function()
				if w.tickToken == token then -- a newer tick keeps showing
					w.tick.Visible = false
				end
			end)
		end
	end
end

-- skip the whole tutorial (SKIP button, or SKIP on the join question)
function Tut.Skip()
	localStep = DONE
	Net.Get("TutorialStep"):FireServer("skip")
end

function Tut.Start(ui, cine, guide)
	UI = ui
	K = UI.Kit()
	P = K.P
	Cine = cine
	Guide = guide
	build()
	Net.Get("BankFx").OnClientEvent:Connect(function()
		events.banked = true
	end)
	Net.Get("CheckpointOffer").OnClientEvent:Connect(function()
		events.checkpoint = true
	end)
	task.spawn(function()
		while true do
			task.wait(0.15)
			pcall(tick)
		end
	end)
end

return Tut
