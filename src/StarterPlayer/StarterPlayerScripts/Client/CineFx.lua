-- Cinematic toolkit: camera shake / zoom / takeover, letterbox, darken, flash, glitch, big titles.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Cine = {}
local layer, vignette, flash, topBar, botBar, glitchHolder, titleHolder
local cc, blur
local shakes = {}
local scripted = false

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function tw(o, t, props, style, dir)
	local x = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	x:Play()
	return x
end

function Cine.Init(gui)
	layer = new("Frame", { Name = "Cine", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 45 }, gui)
	vignette = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 45, BorderSizePixel = 0 }, layer)
	topBar = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.new(1, 0, 0, 0), ZIndex = 47, BorderSizePixel = 0 }, layer)
	botBar = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 0), ZIndex = 47, BorderSizePixel = 0 }, layer)
	glitchHolder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 48, ClipsDescendants = true }, layer)
	titleHolder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 49 }, layer)
	flash = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, BorderSizePixel = 0 }, layer)
	cc = new("ColorCorrectionEffect", { Name = "CineCC" }, Lighting)
	blur = new("BlurEffect", { Name = "CineBlur", Size = 0 }, Lighting)

	RunService:BindToRenderStep("CineShake", Enum.RenderPriority.Camera.Value + 1, function()
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		local now = os.clock()
		local amp = 0
		for i = #shakes, 1, -1 do
			local s = shakes[i]
			local a = (now - s.t0) / s.dur
			if a >= 1 then
				table.remove(shakes, i)
			else
				amp = amp + s.mag * (1 - a) ^ 2
			end
		end
		-- undo last frame's offset if nothing else moved the camera (scriptable cam without tween)
		if Cine._last and cam.CFrame == Cine._last.result then
			cam.CFrame = Cine._last.base
		end
		Cine._last = nil
		if amp > 0.001 then
			local function r()
				return (math.random() * 2 - 1) * amp
			end
			local base = cam.CFrame
			cam.CFrame = base * CFrame.new(r() * 0.25, r() * 0.25, 0) * CFrame.Angles(math.rad(r()), math.rad(r()), math.rad(r() * 1.4))
			Cine._last = { base = base, result = cam.CFrame }
		end
	end)
end

function Cine.Shake(mag, dur)
	table.insert(shakes, { mag = mag, dur = dur or 0.4, t0 = os.clock() })
end

function Cine.Flash(color, from, t)
	flash.BackgroundColor3 = color or Color3.new(1, 1, 1)
	flash.BackgroundTransparency = from or 0
	tw(flash, t or 0.4, { BackgroundTransparency = 1 })
end

function Cine.Darken(alpha, t)
	tw(vignette, t or 0.3, { BackgroundTransparency = 1 - alpha })
end

function Cine.Letterbox(on, t)
	local h = on and 0.11 or 0
	tw(topBar, t or 0.35, { Size = UDim2.new(1, 0, h, 0) })
	tw(botBar, t or 0.35, { Size = UDim2.new(1, 0, h, 0) })
end

function Cine.Grade(props, t)
	tw(cc, t or 0.3, props)
end

function Cine.Blur(size, t)
	tw(blur, t or 0.3, { Size = size })
end

function Cine.Zoom(fov, t, style)
	local cam = Workspace.CurrentCamera
	if cam then
		tw(cam, t or 0.4, { FieldOfView = fov }, style)
	end
end

-- RGB-split glitch: horizontal slices + red/cyan bars + grade flicker
function Cine.Glitch(dur, power)
	power = power or 1
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < dur do
			for _, c in ipairs(glitchHolder:GetChildren()) do
				c:Destroy()
			end
			local n = math.floor(3 + 6 * power)
			for _ = 1, n do
				local red = math.random() < 0.5
				new("Frame", {
					BackgroundColor3 = red and Color3.fromRGB(255, 40, 60) or Color3.fromRGB(40, 240, 255),
					BackgroundTransparency = 0.35 + math.random() * 0.4, BorderSizePixel = 0, ZIndex = 48,
					Position = UDim2.new(math.random() * 0.3 - 0.15, 0, math.random(), 0),
					Size = UDim2.new(0.5 + math.random() * 0.8, 0, 0, math.random(3, 6 + math.floor(26 * power))),
				}, glitchHolder)
			end
			cc.TintColor = (math.random() < 0.5) and Color3.fromRGB(255, 200, 210) or Color3.fromRGB(200, 255, 255)
			Cine.Shake(0.6 * power, 0.08)
			task.wait(0.04 + math.random() * 0.05)
		end
		for _, c in ipairs(glitchHolder:GetChildren()) do
			c:Destroy()
		end
		cc.TintColor = Color3.new(1, 1, 1)
	end)
end

-- Big punchy title with RGB ghost copies
function Cine.Title(text, color, dur, sizePx, yScale)
	local holder = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, yScale or 0.4), Size = UDim2.fromOffset(1000, sizePx or 140), ZIndex = 49 }, titleHolder)
	local function lbl(col, off, tr, z)
		local l = new("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, Text = text, TextScaled = true, TextColor3 = col,
			TextTransparency = tr, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(off, 0), ZIndex = z, Rotation = -3 }, holder)
		return l
	end
	local r = lbl(Color3.fromRGB(255, 40, 60), -8, 0.3, 49)
	local c = lbl(Color3.fromRGB(40, 240, 255), 8, 0.3, 49)
	local main = lbl(color, 0, 0, 50)
	new("UIStroke", { Color = Color3.fromRGB(27, 31, 42), Thickness = 6 }, main)
	local sc = new("UIScale", { Scale = 2.4 }, holder)
	tw(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < (dur or 1.5) and holder.Parent do
			local j = math.random() < 0.25 and 14 or 4
			r.Position = UDim2.fromOffset(-j, math.random(-2, 2))
			c.Position = UDim2.fromOffset(j, math.random(-2, 2))
			task.wait(0.05)
		end
		tw(sc, 0.2, { Scale = 0.6 })
		for _, l in ipairs({ r, c, main }) do
			tw(l, 0.2, { TextTransparency = 1 })
		end
		task.wait(0.22)
		holder:Destroy()
	end)
	return holder
end

function Cine.Sub(text, color, dur, yScale)
	local l = new("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, Text = text, TextSize = 34, TextColor3 = color,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, yScale or 0.56), Size = UDim2.fromOffset(900, 44), ZIndex = 50, TextTransparency = 1 }, titleHolder)
	new("UIStroke", { Color = Color3.fromRGB(27, 31, 42), Thickness = 3 }, l)
	tw(l, 0.25, { TextTransparency = 0 })
	task.delay(dur or 1.5, function()
		tw(l, 0.25, { TextTransparency = 1 })
		task.wait(0.3)
		l:Destroy()
	end)
	return l
end

-- Camera takeover helpers
function Cine.Take()
	local cam = Workspace.CurrentCamera
	scripted = true
	cam.CameraType = Enum.CameraType.Scriptable
	return cam
end

function Cine.Move(cf, t, style)
	local cam = Workspace.CurrentCamera
	return tw(cam, t, { CFrame = cf }, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
end

function Cine.Release(t)
	local cam = Workspace.CurrentCamera
	scripted = false
	cam.CameraType = Enum.CameraType.Custom
	Cine.Zoom(70, t or 0.4)
end

function Cine.IsScripted()
	return scripted
end

function Cine.Reset(t)
	t = t or 0.4
	Cine.Darken(0, t)
	Cine.Letterbox(false, t)
	Cine.Grade({ Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) }, t)
	Cine.Blur(0, t)
end

return Cine
