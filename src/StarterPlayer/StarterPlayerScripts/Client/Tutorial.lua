-- First-time tutorial (10 steps) and, afterwards, the "next goal" line. One objective card at the top,
-- a guide beam + marker in the world, and a pulse on the button you need. Progress is saved on the server
-- (DataService.TutorialSteps must match DONE - 1).
--   1 run to the City (speed lane, arch)      6 upgrade your platform (skipped if it can't be paid)
--   2 grab 3 glowing parts                    7 Big Tony: apply your free gear to a car
--   3 run home: the safe zone banks the loot  8 check the Job Board
--   4 throw parts at your platform            9 reach a checkpoint
--   5 open your garage                       10 unlock the Highway
-- Every step is a check on the client state, so a player who already did something passes that step at once.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local MapConfig = require(Shared:WaitForChild("MapConfig"))
local TrapConfig = require(Shared:WaitForChild("TrapConfig"))
local Util = require(Shared:WaitForChild("Util"))

local Tut = {}
local K, UI, Cine, Guide
local P
local C = Color3.fromRGB
local w = {}
local DONE = 11 -- 10 steps; DataService.TutorialSteps = 10
local localStep -- optimistic step while the server confirms
local skippedLocal = false
local lastSent = 0
local events = { banked = false, checkpoint = false, gearUsed = false }
local stepSince = {} -- step -> os.clock() when it was first shown
local lastGearTotal

local function trapPad(st)
	local map = Workspace:FindFirstChild("GeneratedMap")
	local base = st.baseIndex and map and map:FindFirstChild("Bases") and map.Bases:FindFirstChild(string.format("Base%02d", st.baseIndex), true)
	return base and base:FindFirstChild("TrapPad")
end

-- a named part inside a map model (TonyGarage.TonySpot, JobBoard.JobSpot); cached, falls back to the MapConfig spot
local found = {}
local function mapSpot(model, spot, cfg)
	local hit = found[spot]
	if hit and hit.Parent then
		return hit
	end
	local map = Workspace:FindFirstChild("GeneratedMap")
	local m = map and map:FindFirstChild(model, true)
	hit = m and m:FindFirstChild(spot, true)
	if hit then
		found[spot] = hit
		return hit
	end
	return cfg and Vector3.new(cfg.x, 3, cfg.z) or nil
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

-- the speed lane on the player's side of the plaza, `dz` studs from the arch
local function lanePoint(hrp, dz)
	local lx = MapConfig.PlazaLaneX or 0
	return Vector3.new((hrp and hrp.Position.X < 0) and -lx or lx, 2, MapConfig.EntryZ + dz)
end

local function gearTotal(st)
	local n = 0
	for _, v in pairs(st.gears or {}) do
		n = n + (tonumber(v) or 0)
	end
	return n
end

local function anyCarGeared(st)
	for _, c in ipairs(st.cars or {}) do
		if c.gear then
			return true
		end
	end
	return false
end

local function mixPicked()
	for _, v in pairs(K.state.mix or {}) do
		if (tonumber(v) or 0) > 0 then
			return true
		end
	end
	return false
end

-- platform upgrade: next cost (nil at max) and whether the player can pay it now
local function platformCost(st)
	local cost = TrapConfig.NextCost(st.trapLevel or 1)
	return cost, cost ~= nil and (K.store.Money or 0) >= cost
end

local function since(step)
	return os.clock() - (stepSince[step] or os.clock())
end

-- step definitions: title, body, colour, target(st, hrp), done(st, hrp) -> bool, progress(st) -> 0..1, text,
-- pulse(st) -> toy button (or nil)
local STEPS = {
	{ "RUN TO THE CITY", "Use the speed lane beside your garage, then run through the big arch", nil,
		function(_, hrp) return lanePoint(hrp, 12) end,
		function(_, hrp) return hrp.Position.Z > MapConfig.EntryZ + 6 end },
	{ "GRAB 3 GLOWING PARTS", "One hit by a car and you lose what you carry", nil,
		function(_, hrp) return nearestDrop(hrp) end,
		function() return K.store.CarriedTotal() >= 3 end,
		function() return math.min(K.store.CarriedTotal(), 3) / 3, string.format("%d / 3", math.min(K.store.CarriedTotal(), 3)) end },
	{ "RUN HOME TO BANK THEM", "Back through the arch: the safe zone banks your loot automatically", nil,
		-- a point on the speed lane on the player's side, just inside the arch
		function(_, hrp) return lanePoint(hrp, -30) end,
		function() return events.banked end },
	{ "THROW PARTS AT YOUR PLATFORM", "At your platform open THROW, press ALL, then THROW", nil,
		function(st) return trapPad(st) end,
		function(st) return (st.stats and st.stats.throws or 0) > 0 end, nil,
		function()
			if K.state.open == "throw" then
				return mixPicked() and K.panels.throwGo or K.panels.throwAll
			end
			return K.hud.throw
		end },
	{ "YOUR GARAGE", "Open GARAGE: every parked car earns money every second", nil,
		function() return nil end,
		function() return K.state.open == "garage" end, nil,
		function() return K.hud.garageBtn end },
	{ "UPGRADE YOUR PLATFORM", "Open THROW at your platform and press UPGRADE: more luck for rarer cars", nil,
		function(st) return K.state.open == nil and trapPad(st) or nil end,
		-- also passes when the upgrade can't be paid (after a short look), so a broke player never gets stuck here
		function(st)
			local cost, ok = platformCost(st)
			return (st.trapLevel or 1) >= 2 or cost == nil or (not ok and since(6) > 8)
		end, nil,
		function()
			if K.state.open == "throw" then
				return K.panels.trapUpgradeBtn
			end
			return K.state.open == nil and K.hud.throw or nil
		end },
	{ "VISIT BIG TONY", "Walk up to Big Tony and APPLY your free gear to a car", nil,
		function() return K.state.open == nil and mapSpot("TonyGarage", "TonySpot", MapConfig.Tony) or nil end,
		-- done when a car runs a gear or a gear was used up; no gear and no car to put one on = nothing to do here
		function(st)
			return anyCarGeared(st) or events.gearUsed or #(st.cars or {}) == 0 or (gearTotal(st) == 0 and since(7) > 12)
		end },
	{ "CHECK THE JOB BOARD", "Jobs pay cash - claim the rewards in the safe zone", nil,
		function() return K.state.open == nil and mapSpot("JobBoard", "JobSpot", MapConfig.JobBoard) or nil end,
		function() return K.state.open == "jobs" end, nil,
		function() return K.state.open == nil and K.hud.jobsBtn or nil end },
	{ "REACH A CHECKPOINT", "Carry parts to the yellow arch at the far end of the City, then SAVE or RISK", nil,
		function() return Vector3.new(0, 2, MapConfig.Zones.city.zMax - 5) end,
		function() return events.checkpoint end },
	{ "UNLOCK THE HIGHWAY", "Open TELEPORT and unlock the Highway: better parts live there", nil,
		function() return nil end,
		function(st) return st.zones and st.zones.highway == true end, nil,
		function() return K.hud.teleportBtn end },
}
assert(#STEPS == DONE - 1, "Tutorial: STEPS / DONE mismatch")

local function build()
	w.goal = K.text(K.root, { Text = "", TextSize = 15, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.fromOffset(760, 18),
		TextXAlignment = Enum.TextXAlignment.Center, Visible = false, Outline = 2 })
	-- v23: K.card (white face, ink outline, dark tan shadow slab under it); w.card is the holder (position / z / visible /
	-- pop scale), the content goes on the face
	local card, holder = K.card(K.root, { Name = "Objective", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 118), Size = UDim2.fromOffset(600, 108),
		Radius = 20, Stroke = 4, ShadowColor = Color3.fromRGB(150, 138, 112), Visible = false })
	card.ClipsDescendants = true
	w.card = holder
	-- the colour badge follows the card's rounded left corners (ClipsDescendants ignores UICorner, so a square badge
	-- used to stick out of the outline): rounded badge + a square filler on its right half
	w.badge = K.new("Frame", { Size = UDim2.fromOffset(108, 108), BackgroundColor3 = P.yellow, BorderSizePixel = 0 }, card)
	K.corner(w.badge, 20)
	w.badgeFill = K.new("Frame", { Position = UDim2.fromOffset(54, 0), Size = UDim2.fromOffset(54, 108), BackgroundColor3 = P.yellow, BorderSizePixel = 0 }, w.badge)
	w.badgeText = K.text(w.badge, { Text = "1/10", TextSize = 32, ZIndex = 2, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 38), TextXAlignment = Enum.TextXAlignment.Center, Outline = 2.5 })
	w.badgeSub = K.text(w.badge, { Text = "STEP", Font = K.BODY, TextSize = 13, ZIndex = 2, Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center })
	-- one dot per step: done = white, current = big, to do = faded (10 dots fit the 88 px row: 6 px + 2 px gaps)
	local dots = K.new("Frame", { Position = UDim2.fromOffset(10, 82), Size = UDim2.new(1, -20, 0, 12), BackgroundTransparency = 1, ZIndex = 2 }, w.badge)
	K.list(dots, Enum.FillDirection.Horizontal, 2, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	w.dots = {}
	for i = 1, DONE - 1 do
		local d = K.new("Frame", { Size = UDim2.fromOffset(6, 6), BackgroundColor3 = P.white, LayoutOrder = i, ZIndex = 3 }, dots)
		K.corner(d, 4)
		w.dots[i] = d
	end
	w.title = K.text(card, { Text = "", TextSize = 26, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(124, 10), Size = UDim2.fromOffset(380, 30) })
	w.body = K.text(card, { Text = "", Font = K.BODY, TextSize = 16, TextColor3 = P.muted, TextWrapped = true, Position = UDim2.fromOffset(124, 42), Size = UDim2.fromOffset(460, 40) })
	local bar = K.inset(card, { Position = UDim2.fromOffset(124, 88), Size = UDim2.fromOffset(300, 8), Radius = 4, Stroke = 1.5, Visible = false })
	w.bar = bar
	w.fill = K.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = P.yellow }, bar)
	K.corner(w.fill, 4)
	w.progText = K.text(card, { Text = "", Font = K.BODY, TextSize = 14, TextColor3 = P.orange, Position = UDim2.fromOffset(434, 82), Size = UDim2.fromOffset(80, 20), Visible = false })
	w.skip = K.toy(card, { Text = "SKIP", Color = P.grey, Size = UDim2.fromOffset(74, 34), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), TextSize = 16, Depth = 3,
		Radius = 10, OnClick = function()
			K.confirm("SKIP THE TUTORIAL?", "You can still find every feature on your own.", "SKIP", P.red, Tut.Skip)
		end })
	w.scale = K.new("UIScale", {}, holder)
	w.tick = K.text(w.badge, { Text = "OK!", TextSize = 30, TextColor3 = C(120, 255, 150), Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Visible = false, ZIndex = 5 })
end

local pulses = {}
local function pulse(button)
	for b, sc in pairs(pulses) do
		if b ~= button then
			sc.Scale = 1
		end
	end
	if not button or not button.holder then
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

-- the server rate-limits TutorialStep: re-send the optimistic step until the saved state catches up
local function sendStep()
	lastSent = os.clock()
	Net.Get("TutorialStep"):FireServer(skippedLocal and "skip" or localStep)
end

local function tick()
	local st = K.store.State
	local char = Players.LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not st or not hrp then
		return
	end
	if localStep and (st.tutorial or 0) < localStep and os.clock() - lastSent > 1.5 then
		sendStep()
	end
	local step = math.max(st.tutorial or 0, localStep or 0, 1)
	-- a gear left the inventory (applied to a car) while Big Tony's step is up
	local gears = gearTotal(st)
	if step == 7 and lastGearTotal and gears < lastGearTotal then
		events.gearUsed = true
	end
	lastGearTotal = gears
	w.goal.Visible = false
	if step >= DONE then
		Guide.Point(nil)
		pulse(nil)
		local goal = K.hud.nextGoal
		K.hud.tutInPanel = false
		w.card.Visible = false
		-- after the tutorial the goal is one small line at the very bottom, under the THROW button
		w.goal.Visible = goal ~= nil and K.state.open == nil
		if goal then
			w.goal.Text = goal[1] .. "  ·  " .. goal[2]
		end
		return
	end
	local def = STEPS[step]
	-- lost the loot on the way home: point back at the parts
	local lostLoot = step == 3 and K.store.CarriedTotal() == 0 and not events.banked
	if lostLoot then
		def = STEPS[2]
	end
	local color = ({ P.yellow, P.orange, P.green, P.yellow, P.blue, P.cyan or P.blue, P.orange, P.orange, P.red, P.green })[step]
	local body = lostLoot and "You lost your parts - grab 3 more, then run home" or def[2]
	local target = def[4](st, hrp)
	if step == 4 and K.store.BankedTotal() == 0 and K.store.CarriedTotal() == 0 and (st.stats and st.stats.throws or 0) == 0 then
		-- nothing to throw: fetch parts first
		body = "No parts to throw - grab some in the City and run home"
		target = nearestDrop(hrp)
	elseif step == 6 then
		local cost, ok = platformCost(st)
		if cost and ok then
			body = string.format("Open THROW at your platform and press UPGRADE ($%s): more luck for rarer cars", Util.FormatNumber(cost))
		elseif cost then
			body = string.format("The upgrade costs $%s - you'll do it later, moving on...", Util.FormatNumber(cost))
			target = nil
		end
	elseif step == 7 and gears == 0 and not anyCarGeared(st) then
		body = "Big Tony sells GEARS: buy one, then APPLY it to a car"
	end
	local prog, progText
	if def[6] then
		prog, progText = def[6]()
	end
	stepSince[step] = stepSince[step] or os.clock()
	for i, d in ipairs(w.dots) do
		d.BackgroundTransparency = i <= step and 0 or 0.6
		d.Size = UDim2.fromOffset(i == step and 9 or 6, i == step and 9 or 6)
	end
	show("step" .. step .. def[1], step .. "/" .. (DONE - 1), "STEP", color, def[1], body, prog, progText, true)
	-- steps that happen inside a panel (garage, throw, Tony, jobs): the card goes on top of the panel's dim, at the very top
	local inPanel = K.state.open ~= nil
	w.card.ZIndex = inPanel and 30 or 1
	K.hud.tutInPanel = inPanel
	w.card.Position = UDim2.new(0.5, 0, 0, inPanel and 4 or 118)
	Guide.Point(target)
	pulse(def[7] and def[7](st) or nil)
	if def == STEPS[step] and def[5](st, hrp) then
		localStep = step + 1
		events.banked = step >= 3 and events.banked -- step 3 needs a bank after the parts were grabbed
		sendStep()
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
	skippedLocal = true
	sendStep()
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
