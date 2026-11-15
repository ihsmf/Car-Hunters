-- Reveal effects shared by the car showcase (UI.ShowReveal) and the batch reveal: shockwave rings, contracting
-- energy rings, confetti + star bursts with gravity, flashes and shine sweeps.
-- Every effect lives inside a parent frame the caller owns: destroying that frame ends it (rings destroy themselves
-- when their tween ends, a burst disconnects its RenderStepped as soon as its layer is gone or every piece is dead).
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local RevealFx = {}
local WHITE = Color3.new(1, 1, 1)

-- quality level from Client/Perf (another module); missing or failing = HIGH
local perfMod
function RevealFx.Level()
	if perfMod == nil then
		perfMod = false
		local m = script.Parent:FindFirstChild("Perf")
		if m then
			local ok, P = pcall(require, m)
			if ok and type(P) == "table" and type(P.Level) == "function" then
				perfMod = P
			end
		end
	end
	if perfMod then
		local ok, l = pcall(perfMod.Level)
		if ok and (l == "HIGH" or l == "MED" or l == "LOW") then
			return l
		end
	end
	return "HIGH"
end

-- confetti pieces for one burst at the current quality (scale: share of the full burst)
function RevealFx.Count(scale)
	local l = RevealFx.Level()
	local n = l == "LOW" and 12 or l == "MED" and 25 or 40
	return math.max(3, math.floor(n * (scale or 1) + 0.5))
end

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function ring(parent, o, size)
	local f = make("Frame", { Name = "FxRing", AnchorPoint = Vector2.new(0.5, 0.5), Position = o.pos or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = o.z or 1 }, parent)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, f)
	local st = make("UIStroke", { Color = o.color or WHITE, Thickness = o.thick or 8, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f)
	return f, st
end

local function later(parent, delay, fn)
	if delay and delay > 0 then
		task.delay(delay, function()
			if parent.Parent then -- the layer is still up
				fn()
			end
		end)
	else
		fn()
	end
end

-- expanding ring (UIStroke circle / ellipse) that thins out and fades
-- o = { pos = UDim2, from = Vector2 px, to = Vector2 px, dur, color, thick, z, delay }
function RevealFx.Shockwave(parent, o)
	later(parent, o.delay, function()
		local from = o.from or Vector2.new(40, 40)
		local to = o.to or Vector2.new(600, 600)
		local f, st = ring(parent, o, from)
		st.Transparency = o.alpha or 0
		local info = TweenInfo.new(o.dur or 0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		TweenService:Create(f, info, { Size = UDim2.fromOffset(to.X, to.Y) }):Play()
		local t = TweenService:Create(st, info, { Transparency = 1, Thickness = 0 })
		t.Completed:Connect(function()
			f:Destroy()
		end)
		t:Play()
	end)
end

-- energy ring pulled inward (build-up): starts big and faint, shrinks onto the point and brightens
-- o = { pos, from = Vector2, to = Vector2, dur, color, thick, z }
function RevealFx.Implode(parent, o)
	local from = o.from or Vector2.new(560, 560)
	local f, st = ring(parent, o, from)
	st.Thickness = 1
	st.Transparency = 0.95
	local to = o.to or Vector2.new(30, 30)
	local info = TweenInfo.new(o.dur or 0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(f, info, { Size = UDim2.fromOffset(to.X, to.Y) }):Play()
	local t = TweenService:Create(st, info, { Transparency = 0.1, Thickness = o.thick or 6 })
	t.Completed:Connect(function()
		f:Destroy()
	end)
	t:Play()
end

-- full-size flash that fades out; o = { color, from, dur, z, corner }
function RevealFx.Flash(parent, o)
	o = o or {}
	local f = make("Frame", { Name = "FxFlash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = o.color or WHITE, BackgroundTransparency = o.from or 0,
		BorderSizePixel = 0, ZIndex = o.z or 1 }, parent)
	if o.corner then
		make("UICorner", { CornerRadius = UDim.new(0, o.corner) }, f)
	end
	local t = TweenService:Create(f, TweenInfo.new(o.dur or 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
	t.Completed:Connect(function()
		f:Destroy()
	end)
	t:Play()
end

-- shine sweep: a UIGradient's Offset runs from -1 to 1 over `dur`, then waits `pause`; repeats until cancelled
-- or the gradient is destroyed. Returns a handle with :Cancel() (like a tween, so tween lists can hold it).
function RevealFx.Sweep(gradient, dur, pause)
	dur, pause = dur or 0.8, pause or 1
	local handle = { alive = true }
	local current
	function handle.Cancel()
		handle.alive = false
		if current then
			current:Cancel()
			current = nil
		end
	end
	task.spawn(function()
		while handle.alive and gradient.Parent do
			gradient.Offset = Vector2.new(-1, 0)
			current = TweenService:Create(gradient, TweenInfo.new(dur, Enum.EasingStyle.Linear), { Offset = Vector2.new(1, 0) })
			current:Play()
			task.wait(dur + pause)
		end
		current = nil
	end)
	return handle
end

-- transparency curve of a shine band (transparent everywhere but a soft stripe in the middle)
function RevealFx.ShineBand(peak, width)
	local w = width or 0.12
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(math.max(0.001, 0.5 - w), 1), NumberSequenceKeypoint.new(0.5, peak or 0.3),
		NumberSequenceKeypoint.new(math.min(0.999, 0.5 + w), 1), NumberSequenceKeypoint.new(1, 1),
	})
end

local STARS = { "★", "✦" }

-- confetti + star burst with gravity. o = { at = UDim2 origin, count, colors = { Color3 }, power, z, spread (radians, nil = all round) }
-- Returns stop(): removes every piece at once (also happens by itself when the layer is destroyed).
function RevealFx.Burst(parent, o)
	o = o or {}
	local n = o.count or RevealFx.Count()
	local at = o.at or UDim2.fromScale(0.5, 0.5)
	local colors = o.colors or { WHITE }
	local power = o.power or 1
	local pieces = {}
	for i = 1, n do
		local c = colors[(i - 1) % #colors + 1]
		local star = i % 3 == 0
		local g
		if star then
			local sz = math.random(18, 30)
			g = make("TextLabel", { BackgroundTransparency = 1, Text = STARS[math.random(1, #STARS)], Font = Enum.Font.FredokaOne, TextSize = sz, TextColor3 = c,
				AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(sz, sz), Position = at, ZIndex = o.z or 1 }, parent)
		else
			g = make("Frame", { BackgroundColor3 = c, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 6),
				Position = at, ZIndex = o.z or 1 }, parent)
		end
		local a = o.spread and (-math.pi / 2 + (math.random() - 0.5) * o.spread) or math.random() * math.pi * 2
		local sp = (260 + math.random() * 420) * power
		table.insert(pieces, {
			g = g, star = star, x = 0, y = 0, vx = math.cos(a) * sp, vy = math.sin(a) * sp - 220 * power,
			rot = math.random() * 360, vr = (math.random() - 0.5) * 900, w = math.random(8, 14), h = math.random(4, 7),
			ph = math.random() * 6, life = 1.1 + math.random() * 0.8, t = 0,
		})
	end
	local conn
	local function stop()
		if conn then
			conn:Disconnect()
			conn = nil
		end
		for _, p in ipairs(pieces) do
			p.g:Destroy()
		end
		table.clear(pieces)
	end
	conn = RunService.RenderStepped:Connect(function(dt)
		if not parent.Parent then
			stop()
			return
		end
		dt = math.min(dt, 1 / 20)
		local alive = 0
		local drag = math.exp(-dt * 1.6)
		for _, p in ipairs(pieces) do
			if p.t < p.life then
				p.t = p.t + dt
				alive = alive + 1
				p.vx = p.vx * drag
				p.vy = p.vy * drag + 1100 * dt
				p.x = p.x + p.vx * dt
				p.y = p.y + p.vy * dt
				p.rot = p.rot + p.vr * dt
				local g = p.g
				g.Position = UDim2.new(at.X.Scale, at.X.Offset + p.x, at.Y.Scale, at.Y.Offset + p.y)
				g.Rotation = p.rot
				local fade = math.clamp((p.t / p.life - 0.65) / 0.35, 0, 1)
				if p.star then
					g.TextTransparency = fade
				else
					-- flutter: the strip turns over (its width swings through zero)
					g.Size = UDim2.fromOffset(math.max(1, p.w * math.abs(math.cos(p.ph + p.t * 9))), p.h)
					g.BackgroundTransparency = fade
				end
				if p.t >= p.life then
					g.Visible = false
				end
			end
		end
		if alive == 0 then
			stop()
		end
	end)
	return stop
end

return RevealFx
