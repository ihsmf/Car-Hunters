-- SETTINGS: music + sound-effect volume sliders and on/off switches. Saved in the player's profile
-- (DataService.SanitizeSettings), applied on join. Switches are read by other modules as LocalPlayer attributes
-- "Opt_<name>" (false = off): markers (Markers), guide (Guidance), shake (CineFx), fov (SpeedLanes);
-- notifications go through UI.SetNotificationsEnabled.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local Settings = {}
local K, UI, P
local cur = { music = 0.5, sfx = 0.8, markers = true, notes = true, shake = true, fov = true, guide = true }
local loaded = false
local widgets = {}
local saveToken = 0

-- only the basics on screen; guide / shake / fov keep their defaults (on) and still work from saved settings
local SWITCHES = {
	{ "markers", "Map markers" },
	{ "notes", "Notifications" },
}

local function apply()
	UI.MusicGroup.Volume = cur.music
	UI.SfxGroup.Volume = cur.sfx
	local lp = Players.LocalPlayer
	for _, key in ipairs({ "markers", "guide", "notes", "shake", "fov" }) do
		lp:SetAttribute("Opt_" .. key, cur[key])
	end
	UI.SetNotificationsEnabled(cur.notes)
end

-- one save 1 s after the last change (dragging a slider does not spam the server)
local function save()
	saveToken = saveToken + 1
	local token = saveToken
	task.delay(1, function()
		if token == saveToken then
			Net.Get("SaveSettings"):FireServer(cur)
		end
	end)
end

local function refresh()
	for key, wd in pairs(widgets) do
		if wd.fill then
			wd.fill.Size = UDim2.fromScale(cur[key], 1)
			wd.knob.Position = UDim2.new(cur[key], 0, 0.5, 0)
			wd.value.Text = math.floor(cur[key] * 100 + 0.5) .. "%"
		else
			wd.btn.SetText(cur[key] and "ON" or "OFF")
			wd.btn.SetColor(cur[key] and P.green or P.grey)
		end
	end
end

-- v23: every setting is its own white card row (ink outline + shadow) so it reads on the cream panel
local ROW_H, ROW_STEP = 54, 64
local function rowCard(parent, i)
	return K.card(parent, { Position = UDim2.fromOffset(0, (i - 1) * ROW_STEP), Size = UDim2.new(1, 0, 0, ROW_H), Radius = 16, ZIndex = 22 })
end

local function slider(parent, i, key, title)
	local r = rowCard(parent, i)
	K.text(r, { Text = title, TextSize = 20, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(16, 12), Size = UDim2.fromOffset(204, 30), ZIndex = 24 })
	-- recessed track (the knob still follows the finger over the whole track)
	local track = K.inset(r, { Class = "TextButton", Position = UDim2.fromOffset(230, 21), Size = UDim2.fromOffset(250, 12), Radius = 6, ZIndex = 24 })
	local fill = K.new("Frame", { Size = UDim2.fromScale(cur[key], 1), BackgroundColor3 = P.blue, ZIndex = 25 }, track)
	K.corner(fill, 6)
	local knob = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(cur[key], 0, 0.5, 0), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = P.white, ZIndex = 26 }, track)
	K.corner(knob, 13)
	K.stroke(knob, P.ink, 3)
	local value = K.text(r, { Text = "", Font = K.BODY, TextSize = 18, TextColor3 = P.ink, Position = UDim2.fromOffset(500, 12), Size = UDim2.fromOffset(70, 30), ZIndex = 24 })
	widgets[key] = { fill = fill, knob = knob, value = value }
	local dragging = false
	local function setFrom(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		cur[key] = math.floor(a * 100 + 0.5) / 100
		apply()
		refresh()
		save()
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFrom(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFrom(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

local function build()
	-- SETTINGS button: 4th in the left button row (same style as SHOP / JOBS / GIFTS)
	local brow = K.hud.leftCol:FindFirstChild("Buttons")
	local holder = K.new("Frame", { Size = UDim2.fromOffset(66, 94), BackgroundTransparency = 1, LayoutOrder = 4 }, brow)
	local b = K.toy(holder, { Text = "", Color = P.grey, Size = UDim2.fromOffset(66, 66), OnClick = function() UI.TogglePanel("settings") end })
	K.hud.icon(b.face, "settings", 54, UDim2.fromOffset(6, 3)).ZIndex = b.face.ZIndex + 1
	K.text(holder, { Text = "SETTINGS", TextSize = 15, Position = UDim2.fromOffset(-6, 72), Size = UDim2.new(1, 12, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, Outline = 2.5 })

	-- 4 rows x 64 px = 252 px of the 276 px content (panel 380 high: 20 px more for the row shadows)
	local p = K.panelShell("settings", "SETTINGS", 640, 380, P.blue)
	local c = p.content
	slider(c, 1, "music", "MUSIC")
	slider(c, 2, "sfx", "SOUND EFFECTS")
	for i, s in ipairs(SWITCHES) do
		local r = rowCard(c, 2 + i)
		K.text(r, { Text = s[2], Font = K.BODY, TextSize = 19, TextColor3 = P.ink, Position = UDim2.fromOffset(16, 12), Size = UDim2.fromOffset(400, 30), ZIndex = 24 })
		local key = s[1]
		widgets[key] = {
			btn = K.toy(r, { Text = "ON", Color = P.green, Size = UDim2.fromOffset(110, 44), Position = UDim2.fromOffset(464, 4), TextSize = 20, ZIndex = 24, OnClick = function()
				cur[key] = not cur[key]
				apply()
				refresh()
				save()
			end }),
		}
	end
	refresh()
end

function Settings.Start(ui)
	UI = ui
	K = UI.Kit()
	P = K.P
	build()
	apply()
	-- the saved settings arrive with the first state from the server
	local function load()
		local st = K.store.State
		if not loaded and st and type(st.settings) == "table" then
			loaded = true
			for k, v in pairs(st.settings) do
				-- guide / shake / fov have no switch any more: always on (an old saved "false" would be stuck)
				if cur[k] ~= nil and type(v) == type(cur[k]) and k ~= "guide" and k ~= "shake" and k ~= "fov" then
					cur[k] = v
				end
			end
			apply()
			refresh()
		end
	end
	K.store.Changed.Event:Connect(load)
	load()
end

return Settings
