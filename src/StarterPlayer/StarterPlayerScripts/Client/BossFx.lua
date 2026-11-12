-- Boss HUD + effects: big "КИНЬ!" button appears when a monster truck is close, the cheapest part flies at it,
-- stars when it is stunned, dust when it flees.
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Strings = require(Shared:WaitForChild("Strings"))
local PartConfig = require(Shared:WaitForChild("PartConfig"))
local MapConfig = require(Shared:WaitForChild("MapConfig"))

local T = Strings.T
local BossFx = {}
local K, UI, Cine
local w = {}
local RANGE = 80
local CYR = Enum.Font.GothamBlack -- LuckiestGuy has no Cyrillic

local function cheapest(st)
	for _, id in ipairs(PartConfig.Order) do
		if (st.carried and st.carried[id] or 0) > 0 then
			return id
		end
	end
	for _, id in ipairs(PartConfig.Order) do
		if (st.parts and st.parts[id] or 0) > 0 then
			return id
		end
	end
	return nil
end

local function build()
	local root = K.root
	local holder = K.new("Frame", { Name = "BossThrow", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -170), Size = UDim2.fromOffset(300, 170),
		BackgroundTransparency = 1, Visible = false }, root)
	local hint = K.text(holder, { Text = T("boss_hint"), Font = CYR, TextSize = 24, TextColor3 = K.P.white, Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center })
	hint.Font = CYR
	w.btn = K.toy(holder, { Text = T("boss_throw"), Icon = "🔧", Color = K.P.red, Size = UDim2.fromOffset(240, 110), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 38),
		TextSize = 40, OnClick = function()
			Net.Get("BossThrow"):FireServer()
			UI.Sfx("throw")
		end })
	if w.btn.label then
		w.btn.label.Font = CYR -- LuckiestGuy cannot draw Cyrillic
	end
	w.hint = hint
	w.holder = holder
	w.pips = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 152), Size = UDim2.fromOffset(80, 16), BackgroundTransparency = 1 }, holder)
	K.list(w.pips, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
	w.pip = {}
	for i = 1, 2 do
		w.pip[i] = K.new("Frame", { Size = UDim2.fromOffset(16, 16), BackgroundColor3 = K.P.grey }, w.pips)
		K.corner(w.pip[i], 8)
		K.stroke(w.pip[i], K.P.ink, 2)
	end
end

local function nearestBoss(pos)
	local folder = Workspace:FindFirstChild("Bosses")
	if not folder then
		return nil
	end
	local best, bd
	for _, m in ipairs(folder:GetChildren()) do
		if m.PrimaryPart then
			local d = (m.PrimaryPart.Position - pos).Magnitude
			if not bd or d < bd then
				best, bd = m, d
			end
		end
	end
	return best, bd
end

local function flyPart(from, to, partId)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(1.6, 1.6, 1.6)
	p.Color = PartConfig.Parts[partId] and PartConfig.Parts[partId].color or Color3.new(1, 1, 1)
	p.Material = Enum.Material.Metal
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Parent = Workspace
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = math.min(1, (os.clock() - t0) / 0.5)
		local pos = from:Lerp(to + Vector3.new(0, 6, 0), a) + Vector3.new(0, math.sin(a * math.pi) * 12, 0)
		p.CFrame = CFrame.new(pos) * CFrame.Angles(a * 9, a * 7, 0)
		if a >= 1 then
			conn:Disconnect()
			p:Destroy()
		end
	end)
end

local function burst(pos, color, n)
	local a = Instance.new("Part")
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch = true, false, false, false
	a.Transparency = 1
	a.Size = Vector3.one
	a.CFrame = CFrame.new(pos)
	a.Parent = Workspace
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 0) })
	e.Speed = NumberRange.new(10, 22)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(0.6, 1)
	e.Rate = 0
	e.Parent = a
	e:Emit(n or 24)
	task.delay(1.5, function()
		a:Destroy()
	end)
end

function BossFx.Start(ui, cine)
	UI = ui
	K = UI.Kit()
	Cine = cine
	build()
	Net.Get("BossFx").OnClientEvent:Connect(function(ev)
		if ev.event == "throw" then
			flyPart(ev.from + Vector3.new(0, 2, 0), ev.to, ev.part)
			task.delay(0.5, function()
				burst(ev.to + Vector3.new(0, 6, 0), Color3.fromRGB(255, 220, 80), 30)
				UI.Sfx("clank")
			end)
		elseif ev.event == "flee" then
			burst(ev.pos + Vector3.new(0, 3, 0), Color3.fromRGB(200, 180, 150), 50)
			UI.Sfx("fanfare")
			if Cine then
				Cine.Title(T("boss_fleeing"), Color3.fromRGB(255, 210, 63))
			end
		elseif ev.event == "smash" then
			UI.Sfx("crash")
		end
	end)
	RunService.Heartbeat:Connect(function()
		local char = Players.LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local st = K.store.State
		local show = false
		if hrp and st then
			local zone = MapConfig.Zones[MapConfig.ZoneAt(hrp.Position.Z)]
			if zone and zone.arena then
				local boss, d = nearestBoss(hrp.Position)
				if boss and d < RANGE and boss:GetAttribute("Mode") ~= "flee" then
					show = true
					local part = cheapest(st)
					local hits = boss:GetAttribute("Hits") or 0
					for i = 1, 2 do
						w.pip[i].BackgroundColor3 = i <= hits and K.P.yellow or K.P.grey
					end
					w.btn.SetColor(part and K.P.red or K.P.grey)
					w.hint.Text = part and (T("boss_hint") .. "  " .. (K.PART_ICON[part] or "")) or T("boss_empty")
				end
			end
		end
		if w.holder.Visible ~= show then
			w.holder.Visible = show
			if show then
				w.holder.Size = UDim2.fromOffset(200, 110)
				TweenService:Create(w.holder, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(300, 170) }):Play()
				UI.Sfx("siren")
			end
		end
	end)
end

return BossFx
