-- Checkpoint choice card: SAVE & GO HOME (bank now, teleport to the garage) or RISK IT (next district, bigger multiplier).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local MapConfig = require(Shared:WaitForChild("MapConfig"))
local Util = require(Shared:WaitForChild("Util"))
local Strings = require(Shared:WaitForChild("Strings"))

local T = Strings.T
local CP = {}
local K, UI, Cine
local P
local C = Color3.fromRGB
local open

local function zoneName(z)
	return z and T("zone_" .. z) or ""
end

local function close()
	if open then
		open:Destroy()
		open = nil
	end
end

local function fmtMult(m)
	return (m % 1 == 0) and string.format("x%d", m) or string.format("x%.1f", m)
end

local function show(o)
	close()
	UI.Sfx("ping")
	local dim = K.new("Frame", { Name = "Checkpoint", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(0, 0, 0), BackgroundTransparency = 0.55, ZIndex = 80 }, K.overlay)
	open = dim
	local card = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(760, 420), BackgroundColor3 = P.cream, ZIndex = 81 }, dim)
	K.corner(card, 28)
	K.stroke(card, P.ink, 5)
	local sc = K.new("UIScale", { Scale = 0.6 }, card)
	K.tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	local head = K.new("Frame", { Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = P.yellow, ZIndex = 82 }, card)
	K.corner(head, 28)
	K.stroke(head, P.ink, 5)
	K.text(head, { Text = string.upper(zoneName(o.zone)) .. " CLEARED!", TextSize = 36, Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -56, 1, 0), ZIndex = 83, Outline = 3 })
	local banked = math.floor(o.carried * o.combo * o.risk + 0.5)
	K.text(card, { Text = string.format("You carry <b>%d parts</b>  ·  combo %s  ·  risk %s", o.carried, fmtMult(o.combo), fmtMult(o.risk)), Font = K.BODY, TextSize = 19, TextColor3 = P.ink,
		RichText = true, Position = UDim2.fromOffset(28, 84), Size = UDim2.new(1, -56, 0, 26), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 82 })
	-- two big choice cards
	local function choice(x, color, title, lines, btnText, enabled, onPick)
		local f = K.new("Frame", { Position = UDim2.fromOffset(x, 124), Size = UDim2.fromOffset(340, 270), BackgroundColor3 = P.white, ZIndex = 82 }, card)
		K.corner(f, 22)
		K.stroke(f, enabled and color or P.grey, 5)
		K.text(f, { Text = title, TextSize = 28, TextColor3 = enabled and color or P.grey, Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 34), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 83, Outline = 2 })
		K.text(f, { Text = lines, Font = K.BODY, TextSize = 17, TextColor3 = P.ink, RichText = true, TextWrapped = true, Position = UDim2.fromOffset(18, 56), Size = UDim2.new(1, -36, 0, 110),
			TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 83 })
		K.toy(f, { Text = btnText, Color = enabled and color or P.grey, Size = UDim2.fromOffset(290, 72), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), TextSize = 24, ZIndex = 84,
			OnClick = function()
				if enabled then
					close()
					onPick()
				end
			end })
	end
	choice(28, P.green, "SAVE", string.format("Bank your loot now and teleport home.\n\n<b>+%d parts</b> safe in your garage.", banked), "SAVE & GO HOME", true, function()
		Net.Get("CheckpointChoice"):FireServer("save")
	end)
	local riskText, can
	if not o.nextZone then
		riskText, can = "This is the last district. Bank your loot!", false
	elseif not o.nextOpen then
		riskText, can = string.format("Unlock <b>%s</b> first\n($%s in TELEPORT).", zoneName(o.nextZone), Util.FormatNumber(o.price or 0)), false
	else
		local after = math.floor(o.carried * o.combo * o.nextRisk + 0.5)
		riskText = string.format("Jump to <b>%s</b> and cross it.\nLoot becomes <b>%s</b> (%d parts)\n<font color=\"#D6342C\">one hit = lose everything</font>", zoneName(o.nextZone), fmtMult(o.nextRisk), after)
		can = true
	end
	choice(392, P.red, "RISK IT", riskText, "RISK & CONTINUE", can, function()
		Net.Get("CheckpointChoice"):FireServer("risk")
	end)
	K.toy(card, { Text = "X", Color = P.red, Size = UDim2.fromOffset(60, 64), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 14, 0, -18), ZIndex = 85, OnClick = close })
end

function CP.Start(ui, cine)
	UI = ui
	K = UI.Kit()
	P = K.P
	Cine = cine
	table.insert(UI.Overlays, close) -- wrecked while the card is up: the card goes away
	Net.Get("CheckpointOffer").OnClientEvent:Connect(show)
	Net.Get("CheckpointFx").OnClientEvent:Connect(function(fx)
		if fx.choice == "risk" then
			Cine.Flash(Color3.fromRGB(255, 80, 60), 0.3, 0.6)
			Cine.Title("RISK " .. fmtMult(fx.risk), Color3.fromRGB(255, 90, 70), 1.2, 110, 0.35)
			UI.Sfx("whoosh")
		else
			Cine.Flash(Color3.fromRGB(80, 220, 120), 0.3, 0.6)
			UI.Sfx("bank")
		end
	end)
end

return CP
