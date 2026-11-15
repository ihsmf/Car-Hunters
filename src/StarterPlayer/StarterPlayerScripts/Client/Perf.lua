-- Adaptive quality: measures FPS and steps HIGH -> MED -> LOW (and back) so the game stays smooth on every device.
--   Perf.Level()        -> "HIGH" | "MED" | "LOW"
--   Perf.Changed.Event  -> fires (level) whenever the level changes
--   Perf.Start()        -> begins measuring, applies the lighting budget and the parked-car exhaust LOD
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local Perf = {}
Perf.Changed = Instance.new("BindableEvent")

local LEVELS = { "LOW", "MED", "HIGH" }
local DROP_FPS, DROP_SECS = 40, 4
local RAISE_FPS, RAISE_SECS = 55, 20
local WINDOW = 3 -- rolling average, seconds
local EXHAUST_RADIUS = { HIGH = 70, MED = 45, LOW = 0 }

-- the player's own graphics setting: Automatic -> HIGH, 1-3 LOW, 4-6 MED, 7+ HIGH
local function savedLevel()
	local ok, q = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	if not ok or typeof(q) ~= "EnumItem" or q.Value == 0 then
		return 3, false -- Automatic (or unreadable)
	end
	if q.Value <= 3 then
		return 1, true
	elseif q.Value <= 6 then
		return 2, true
	end
	return 3, true
end

local function smallTouchScreen()
	local ok, yes = pcall(function()
		if not UserInputService.TouchEnabled or UserInputService.KeyboardEnabled then
			return false
		end
		local cam = Workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
		return math.min(vp.X, vp.Y) < 600
	end)
	return ok and yes == true
end

local idx, maxIdx -- current / highest allowed level index
local function init()
	if idx then
		return
	end
	local lvl, explicit = savedLevel()
	maxIdx = explicit and lvl or 3
	idx = lvl
	if smallTouchScreen() then
		idx = math.min(idx, 2)
	end
end

function Perf.Level()
	init()
	return LEVELS[idx]
end

-- ---------------------------------------------------------------- lighting budget (client-local)
local origShadows
local function applyLighting()
	local level = LEVELS[idx]
	if origShadows == nil then
		origShadows = Lighting.GlobalShadows
	end
	local shadows = origShadows and level ~= "LOW"
	if Lighting.GlobalShadows ~= shadows then
		Lighting.GlobalShadows = shadows
	end
	-- only the permanent look effects; cinematic ones (CineBlur, RevealBlur, Trap*) are left alone
	local bloom = Lighting:FindFirstChild("CHBloom")
	if bloom and bloom:IsA("BloomEffect") then
		bloom.Enabled = level ~= "LOW"
	end
	local rays = Lighting:FindFirstChild("CHSunRays")
	if rays and rays:IsA("SunRaysEffect") then
		rays.Enabled = level == "HIGH"
	end
end

-- ---------------------------------------------------------------- exhaust LOD for parked cars
-- the server creates these disabled; only the ones near the camera run (none on LOW)
local function refreshExhaust()
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local r = EXHAUST_RADIUS[LEVELS[idx]] or 0
	local r2 = r * r
	local function near(inst)
		if r <= 0 then
			return false
		end
		local p = inst.Parent
		local pos
		if p and p:IsA("Attachment") then
			pos = p.WorldPosition
		elseif p and p:IsA("BasePart") then
			pos = p.Position
		else
			return false
		end
		local d = pos - camPos
		return d.X * d.X + d.Y * d.Y + d.Z * d.Z <= r2
	end
	for _, e in ipairs(CollectionService:GetTagged("ExhaustEmitter")) do
		if e:IsA("ParticleEmitter") then
			local want = near(e)
			if e.Enabled ~= want then
				e.Enabled = want
			end
		end
	end
	for _, l in ipairs(CollectionService:GetTagged("ExhaustLight")) do
		if l:IsA("Light") then
			local want = near(l)
			if l.Enabled ~= want then
				l.Enabled = want
			end
		end
	end
end

local function setLevel(newIdx)
	newIdx = math.clamp(newIdx, 1, maxIdx)
	if newIdx == idx then
		return
	end
	idx = newIdx
	applyLighting()
	refreshExhaust()
	Perf.Changed:Fire(LEVELS[idx])
end

-- ---------------------------------------------------------------- measuring
local started = false
function Perf.Start()
	if started then
		return
	end
	started = true
	init()
	applyLighting()
	Lighting.ChildAdded:Connect(function(c)
		if c.Name == "CHBloom" or c.Name == "CHSunRays" then
			task.defer(applyLighting)
		end
	end)
	pcall(function()
		local ugs = UserSettings():GetService("UserGameSettings")
		ugs:GetPropertyChangedSignal("SavedQualityLevel"):Connect(function()
			local lvl, explicit = savedLevel()
			maxIdx = explicit and lvl or 3
			if explicit then
				setLevel(lvl)
			elseif idx > maxIdx then
				setLevel(maxIdx)
			end
		end)
	end)

	local focused = true
	UserInputService.WindowFocusReleased:Connect(function()
		focused = false
	end)
	UserInputService.WindowFocused:Connect(function()
		focused = true
	end)

	-- per-0.5 s buckets of {frames, seconds}; the rolling average covers the last WINDOW seconds
	local buckets = {}
	local frames, elapsed = 0, 0
	local lowFor, highFor = 0, 0
	local raiseNeed = RAISE_SECS
	local lastRaise = -math.huge
	local peak = 0 -- highest recent FPS (slowly decays): the device's real frame cap
	local warmup = 6 -- loading hitches right after joining do not count
	RunService.Heartbeat:Connect(function(dt)
		if warmup > 0 then
			warmup = warmup - dt
			return
		end
		frames = frames + 1
		elapsed = elapsed + dt
		if elapsed < 0.5 then
			return
		end
		local step = elapsed
		if not focused then
			-- background windows are throttled by the engine: not a real measurement
			frames, elapsed = 0, 0
			table.clear(buckets)
			lowFor, highFor = 0, 0
			return
		end
		table.insert(buckets, { frames, elapsed })
		frames, elapsed = 0, 0
		local f, s = 0, 0
		for i = #buckets, 1, -1 do
			local b = buckets[i]
			if s >= WINDOW then
				table.remove(buckets, i)
			else
				f = f + b[1]
				s = s + b[2]
			end
		end
		if s < WINDOW * 0.8 then
			return -- not enough history yet
		end
		local fps = f / s
		-- the device's own frame cap (30 FPS limit / battery saver): judge against it, not only absolute numbers
		peak = math.max(peak * 0.995, fps)
		local dropAt = math.min(DROP_FPS, peak * 0.72)
		local raiseAt = math.min(RAISE_FPS, peak * 0.9)
		if fps < dropAt then
			lowFor = lowFor + step
		else
			lowFor = 0
		end
		if fps > raiseAt then
			highFor = highFor + step
		else
			highFor = 0
		end
		local now = os.clock()
		if lowFor >= DROP_SECS and idx > 1 then
			-- dropping again shortly after a raise: wait longer before the next try (no flip-flopping)
			if now - lastRaise < 60 then
				raiseNeed = math.min(raiseNeed * 2, 160)
			end
			setLevel(idx - 1)
			lowFor, highFor = 0, 0
			table.clear(buckets)
		elseif highFor >= raiseNeed and idx < maxIdx then
			lastRaise = now
			setLevel(idx + 1)
			lowFor, highFor = 0, 0
			table.clear(buckets)
		end
	end)

	task.spawn(function()
		while true do
			local ok, err = pcall(refreshExhaust)
			if not ok then
				warn("[Perf] exhaust LOD:", err)
			end
			task.wait(1)
		end
	end)
	Players.LocalPlayer:SetAttribute("PerfLevel", LEVELS[idx])
	Perf.Changed.Event:Connect(function(level)
		Players.LocalPlayer:SetAttribute("PerfLevel", level)
	end)
end

return Perf
