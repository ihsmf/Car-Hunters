-- Batch throw reveal: parts rain onto the lift, a fast reel of every car (slowing down on the best one),
-- then a results grid. "SEE BEST CAR" plays the full showcase + drive-in for the best car.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarConfig = require(Shared:WaitForChild("CarConfig"))
local Util = require(Shared:WaitForChild("Util"))
local CarPreload = require(script.Parent:WaitForChild("CarPreload"))
local RevealFx = require(script.Parent:WaitForChild("RevealFx"))

local BR = {}
local K, UI, Cine, TrapFx
local P
local C = Color3.fromRGB
local root, blur, conn
local holding = false -- holds UI cinematic mode while the reel / grid is up

local function rc(r)
	return CarConfig.Rarities[r].color
end

local function close()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	if root then
		root:Destroy()
		root = nil
	end
	if blur then
		blur:Destroy()
		blur = nil
	end
	if holding then
		holding = false
		if not TrapFx.IsBusy() then -- the car showcase keeps its own blackout
			Cine.Darken(0, 0.35)
		end
		UI.SetCinematic(false)
	end
end

-- v23: white card, ink outline, shadow slab, rarity as the card's own top strip (follows the rounded corners)
-- returns the content body, the car def, the holder (position / scale it) and the outline
local function card(parent, r, order, big)
	local def = CarConfig.ById[r.typeId]
	local f, holder, _, st = K.card(parent, { Size = UDim2.fromOffset(big and 170 or 150, big and 190 or 160), Accent = rc(r.rarity), AccentTop = true, AccentSize = 6,
		Radius = 16, LayoutOrder = order, ZIndex = 72 })
	return f, def, holder, st
end

local function grid(res)
	-- v23: shared dialog shell (drop shadow + header strip); the card stays Active so taps on it do not close
	local scr, shell = K.dialogShell(root, { Name = "Grid", Size = UDim2.fromOffset(940, 600), Radius = 28, ZIndex = 70, Active = true, Color = P.orange, HeadH = 64,
		Title = string.format("YOU GOT %d CARS", #res.cars), TitleSize = 38 })
	-- a tap outside the card closes the results (on small screens the buttons were the only way out)
	local r = root
	task.delay(0.6, function()
		if r and root == r then -- only the results screen it was made for
			r.Activated:Connect(close)
		end
	end)
	local sc = K.new("UIScale", { Scale = 0.6 }, shell)
	K.tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	local counts, bonus, merged, newN = {}, 0, 0, 0
	for _, r in ipairs(res.cars) do
		counts[r.rarity] = (counts[r.rarity] or 0) + 1
		bonus = bonus + (r.bonus or 0)
		merged = merged + (r.merged and 1 or 0)
		newN = newN + (r.isNew and 1 or 0)
	end
	local parts = {}
	for _, r in ipairs(CarConfig.RarityOrder) do
		if counts[r] then
			table.insert(parts, string.format('<font color="#%s">%d %s</font>', K.lift(rc(r), -0.3):ToHex(), counts[r], r))
		end
	end
	local extra = {}
	if newN > 0 then
		table.insert(extra, newN .. " new")
	end
	if merged > 0 then
		table.insert(extra, merged .. " merged")
	end
	if bonus > 0 then
		table.insert(extra, "discovery +$" .. Util.FormatNumber(bonus))
	end
	K.text(scr, { Text = table.concat(parts, "   ") .. (#extra > 0 and ("     ·     " .. table.concat(extra, "  ·  ")) or ""), Font = K.BODY, TextSize = 18, TextColor3 = P.ink, RichText = true,
		Position = UDim2.fromOffset(28, 72), Size = UDim2.new(1, -56, 0, 24), ZIndex = 72 })
	local list = K.new("ScrollingFrame", { Position = UDim2.fromOffset(20, 102), Size = UDim2.new(1, -40, 1, -196), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8,
		ScrollBarImageColor3 = P.ink, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 72 }, scr)
	K.new("UIGridLayout", { CellSize = UDim2.fromOffset(160, 170), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	K.padding(list, 8, 14) -- 5 x 160 + 4 x 10 = 840 of the 878 px inside: outlines and shadows of the outer cards stay visible
	-- best first, then by rarity
	local order = {}
	for i, r in ipairs(res.cars) do
		table.insert(order, { i = i, r = r })
	end
	table.sort(order, function(a, b)
		if a.i == res.best then
			return true
		elseif b.i == res.best then
			return false
		end
		local ra, rb = CarConfig.Rarities[a.r.rarity].index, CarConfig.Rarities[b.r.rarity].index
		if ra ~= rb then
			return ra > rb
		end
		return a.i < b.i
	end)
	for k, o in ipairs(order) do
		local r = o.r
		local f, def, _, outline = card(list, r, k)
		if k <= 12 then
			K.carViewport(f, def, { Position = UDim2.fromOffset(4, 6), Size = UDim2.new(1, -8, 0, 92), ZIndex = 73 })
		else
			local tile = K.new("Frame", { Position = UDim2.fromOffset(10, 12), Size = UDim2.new(1, -20, 0, 80), BackgroundColor3 = rc(r.rarity), BackgroundTransparency = 0.6, ZIndex = 73 }, f)
			K.corner(tile, 12)
		end
		K.text(f, { Text = def.name, Font = K.BODY, TextSize = 15, TextColor3 = P.ink, TextWrapped = true, Position = UDim2.fromOffset(6, 98), Size = UDim2.new(1, -12, 0, 34), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 73 })
		local tag, col
		if r.merged then
			tag, col = "MERGED  Lv" .. r.merged, P.blue
		elseif r.sold then
			tag, col = "SOLD +$" .. Util.FormatNumber(r.sold), P.grey
		elseif r.isNew then
			tag, col = "NEW!", P.orange
		elseif r.slot then
			tag, col = "PARKED", P.green
		else
			tag, col = "STORED", P.muted
		end
		local t = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -16, 0, 22), BackgroundColor3 = col, ZIndex = 73 }, f)
		K.corner(t, 11)
		K.text(t, { Text = tag, TextSize = 14, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 74 })
		if o.i == res.best then
			-- the best car: thick gold-orange outline (the ink one becomes it; a yellow rim alone vanished on cream)
			outline.Color = P.orange
			outline.Thickness = 5
		end
	end
	local btns = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(640, 72), BackgroundTransparency = 1, ZIndex = 72 }, scr)
	K.list(btns, Enum.FillDirection.Horizontal, 20, Enum.HorizontalAlignment.Center)
	K.toy(btns, { Text = "SEE BEST CAR", Color = P.orange, Size = UDim2.fromOffset(300, 70), TextSize = 26, LayoutOrder = 1, ZIndex = 72, OnClick = function()
		local best = res.cars[res.best]
		local st = K.store.State
		-- start the showcase first so the HUD does not flash back between the grid and the cinematic
		task.defer(close)
		TrapFx.Play({ partId = best.partId, typeId = best.typeId, rarity = best.rarity, slot = best.slot, merged = best.merged, sold = best.sold, isNew = best.isNew, bonus = best.bonus, speed = 1.6, animTime = 0 }, st and st.baseIndex)
	end })
	K.toy(btns, { Text = "DONE", Color = P.green, Size = UDim2.fromOffset(220, 70), TextSize = 28, LayoutOrder = 2, ZIndex = 72, OnClick = close })
end

-- fast reel: cards slide right-to-left, decelerate and stop on the best car
local function reel(res, onDone)
	local strip = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 230), BackgroundColor3 = C(14, 16, 24),
		BackgroundTransparency = 0.2, ZIndex = 70 }, root)
	local marker = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 250), BackgroundColor3 = P.yellow, ZIndex = 75 }, root)
	K.corner(marker, 3)
	local track = K.new("Frame", { Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(0, 230), BackgroundTransparency = 1, ZIndex = 71 }, strip)
	-- sequence: shuffled filler cars then the best one, padded so the strip keeps going past it
	local seq = {}
	for i, r in ipairs(res.cars) do
		if i ~= res.best then
			table.insert(seq, r)
		end
	end
	for i = #seq, 2, -1 do
		local j = math.random(1, i)
		seq[i], seq[j] = seq[j], seq[i]
	end
	while #seq < 18 do
		table.insert(seq, res.cars[math.random(1, #res.cars)])
	end
	local stopAt = #seq + 1
	table.insert(seq, res.cars[res.best])
	for _ = 1, 4 do
		table.insert(seq, res.cars[math.random(1, #res.cars)])
	end
	local W = 180
	local bestCard
	for k, r in ipairs(seq) do
		local f, _, holder = card(track, r, k)
		if k == stopAt then
			bestCard = holder
		end
		holder.Position = UDim2.fromOffset((k - 1) * W, 30)
		K.text(f, { Text = CarConfig.ById[r.typeId].name, Font = K.BODY, TextSize = 16, TextColor3 = P.ink, TextWrapped = true, Position = UDim2.fromOffset(6, 64), Size = UDim2.new(1, -12, 0, 40),
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 73 })
		K.text(f, { Text = string.upper(r.rarity), TextSize = 16, TextColor3 = rc(r.rarity), Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 73 })
	end
	local target = (stopAt - 1) * W + 75 -- card centre under the marker
	local dur = 2.6
	local t0 = os.clock()
	local done = false
	local lastTick = 0
	local function finish()
		if done then
			return
		end
		done = true
		track.Position = UDim2.new(0.5, -target, 0, 0)
		UI.Sfx(CarConfig.Rarities[res.cars[res.best].rarity].index >= 4 and "revealBig" or "reveal")
		Cine.Shake(0.6, 0.3)
		-- v22: the best card lands with a flash, shockwaves and a confetti burst (layer goes with the root / after 2.2 s)
		local best = res.cars[res.best]
		local brc = rc(best.rarity)
		local fx = K.new("Frame", { Name = "ReelFx", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 76 }, root)
		RevealFx.Flash(fx, { color = brc, from = 0.55, dur = 0.45 })
		if bestCard then
			RevealFx.Flash(bestCard, { color = P.white, from = 0, dur = 0.5, corner = 16, z = 80 })
			local pop = K.new("UIScale", { Scale = 1.25 }, bestCard)
			K.tween(pop, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		RevealFx.Shockwave(fx, { pos = UDim2.fromScale(0.5, 0.5), from = Vector2.new(150, 160), to = Vector2.new(700, 700), dur = 0.6, color = brc, thick = 10 })
		RevealFx.Shockwave(fx, { pos = UDim2.fromScale(0.5, 0.5), from = Vector2.new(120, 130), to = Vector2.new(520, 520), dur = 0.55, color = P.white, thick = 6, delay = 0.1 })
		RevealFx.Burst(fx, { at = UDim2.fromScale(0.5, 0.5), colors = { brc, P.white, P.yellow }, count = RevealFx.Count(), power = 0.9 })
		task.delay(2.2, function()
			fx:Destroy()
		end)
		task.delay(0.8, function()
			strip:Destroy()
			marker:Destroy()
			onDone()
		end)
	end
	conn = RunService.RenderStepped:Connect(function()
		if done then
			return
		end
		local a = math.min(1, (os.clock() - t0) / dur)
		local e = 1 - (1 - a) ^ 3
		local x = e * target
		track.Position = UDim2.new(0.5, -x, 0, 0)
		local tick = math.floor(x / W)
		if tick ~= lastTick then
			lastTick = tick
			UI.Sfx("click")
		end
		if a >= 1 then
			finish()
		end
	end)
	root.Activated:Connect(finish)
end

function BR.Play(res)
	if not res or not res.cars or #res.cars == 0 then
		return
	end
	close()
	holding = true
	UI.SetCinematic(true)
	-- blackout: the world fades to fully dark, the reel and the grid sit on a solid backdrop
	Cine.Darken(1, 0.25)
	Cine.Shake(0.9, 0.35)
	UI.Sfx("throw")
	root = K.new("TextButton", { Name = "BatchReveal", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(6, 7, 12), BackgroundTransparency = 1, ZIndex = 69 }, K.overlay)
	K.tween(root, 0.25, { BackgroundTransparency = 0 })
	blur = K.new("BlurEffect", { Size = 18 }, Lighting)
	local myRoot = root
	reel(res, function()
		if root ~= myRoot then
			return -- closed (or a newer batch) meanwhile
		end
		-- the grid's car viewports must not pop in: wait for their models (normally ready already), max 2 s
		local ids = {}
		for _, r in ipairs(res.cars) do
			table.insert(ids, r.typeId)
		end
		CarPreload.ReadyAll(ids, 2)
		if root and root == myRoot then
			grid(res)
		end
	end)
end

BR.Close = close

function BR.Start(ui, cine, trap)
	UI = ui
	K = UI.Kit()
	P = K.P
	Cine = cine
	TrapFx = trap
	require(Shared:WaitForChild("Net")).Get("ThrowBatchResult").OnClientEvent:Connect(BR.Play)
end

return BR
