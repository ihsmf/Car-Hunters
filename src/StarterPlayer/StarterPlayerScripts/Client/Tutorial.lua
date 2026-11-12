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

local Tut = {}
local K, UI, Cine, Guide
local P
local C = Color3.fromRGB
local w = {}
local DONE = 8
local localStep -- optimistic step while the server confirms
local events = { banked = false, checkpoint = false }

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

local function cheapestUpgrade(st)
	local best
	for _, c in ipairs(st.cars) do
		local def = CarConfig.ById[c.typeId]
		if def and c.level < def.maxLevel then
			local cost = CarConfig.UpgradeCost(def, c.level)
			if not best or cost < best.cost then
				local part, n = CarConfig.UpgradeParts(def, c.level)
				best = { cost = cost, part = part, n = n }
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
	{ "RUN HOME TO BANK THEM", "Back through the arch - the dark lanes in the middle make you faster", nil,
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
		function(st) return (st.stats and st.stats.upgrades or 0) > 0 end, nil, "garage" },
	{ "REACH A CHECKPOINT", "Carry parts to the yellow arch at the far end of the City, then SAVE or RISK", nil,
		function() return Vector3.new(0, 2, MapConfig.Zones.city.zMax - 5) end,
		function() return events.checkpoint end },
}

local function build()
	local card = K.new("Frame", { Name = "Objective", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 74), Size = UDim2.fromOffset(560, 96), BackgroundColor3 = P.white,
		ClipsDescendants = true, Visible = false }, K.root)
	K.corner(card, 20)
	K.stroke(card, P.ink, 4)
	w.card = card
	-- the colour badge follows the card's rounded left corners (ClipsDescendants ignores UICorner, so a square badge
	-- used to stick out of the outline): rounded badge + a square filler on its right half
	w.badge = K.new("Frame", { Size = UDim2.fromOffset(96, 96), BackgroundColor3 = P.yellow, BorderSizePixel = 0 }, card)
	K.corner(w.badge, 20)
	w.badgeFill = K.new("Frame", { Position = UDim2.fromOffset(48, 0), Size = UDim2.fromOffset(48, 96), BackgroundColor3 = P.yellow, BorderSizePixel = 0 }, w.badge)
	w.badgeText = K.text(w.badge, { Text = "1/7", TextSize = 30, ZIndex = 2, Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 36), TextXAlignment = Enum.TextXAlignment.Center, Outline = 2.5 })
	w.badgeSub = K.text(w.badge, { Text = "STEP", Font = K.BODY, TextSize = 12, ZIndex = 2, Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center })
	w.title = K.text(card, { Text = "", TextSize = 24, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(112, 10), Size = UDim2.fromOffset(400, 28) })
	w.body = K.text(card, { Text = "", Font = K.BODY, TextSize = 15, TextColor3 = P.muted, TextWrapped = true, Position = UDim2.fromOffset(112, 40), Size = UDim2.fromOffset(436, 34) })
	local bar = K.new("Frame", { Position = UDim2.fromOffset(112, 76), Size = UDim2.fromOffset(300, 8), BackgroundColor3 = C(230, 232, 236), Visible = false }, card)
	K.corner(bar, 4)
	w.bar = bar
	w.fill = K.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = P.yellow }, bar)
	K.corner(w.fill, 4)
	w.progText = K.text(card, { Text = "", Font = K.BODY, TextSize = 13, TextColor3 = P.orange, Position = UDim2.fromOffset(420, 70), Size = UDim2.fromOffset(80, 18), Visible = false })
	w.skip = K.new("TextButton", { Text = "SKIP", Font = K.BODY, TextSize = 13, TextColor3 = P.grey, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 6),
		Size = UDim2.fromOffset(50, 20) }, card)
	w.skip.Activated:Connect(function()
		localStep = DONE
		Net.Get("TutorialStep"):FireServer("skip")
	end)
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
	w.skip.Visible = canSkip
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
		w.card.Position = UDim2.new(0.5, 0, 0, 74)
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
	if step == 3 and K.store.CarriedTotal() == 0 and not events.banked then
		def = STEPS[2]
	end
	local color = ({ P.yellow, P.orange, P.green, P.yellow, P.blue, P.blue, P.red })[step]
	local body = def[2]
	if step == 6 then
		local up = cheapestUpgrade(st)
		if up then
			body = string.format("Press UPGRADE on a car  ·  needs $%s + %d %s", Util.FormatNumber(up.cost), up.n, up.part)
		end
	end
	local prog, progText
	if def[6] then
		prog, progText = def[6]()
	end
	show("step" .. step .. def[1], step .. "/7", "STEP", color, def[1], body, prog, progText, true)
	-- steps that happen inside a panel (garage, upgrade): the card goes on top of the panel's dim, at the very top
	local inPanel = K.state.open ~= nil
	w.card.ZIndex = inPanel and 30 or 1
	K.hud.tutInPanel = inPanel
	w.card.Position = UDim2.new(0.5, 0, 0, inPanel and 4 or 74)
	Guide.Point(def[4](st, hrp))
	pulse(def[8] == "throw" and K.hud.throw or (def[8] == "garage" and K.hud.garageBtn) or nil)
	if def == STEPS[step] and def[5](st, hrp) then
		localStep = step + 1
		events.banked = step >= 3 and events.banked
		Net.Get("TutorialStep"):FireServer(step + 1)
		UI.Sfx("step")
		if step + 1 == DONE then
			Cine.Title("TUTORIAL COMPLETE!", P.yellow, 1.4, 90, 0.35)
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
