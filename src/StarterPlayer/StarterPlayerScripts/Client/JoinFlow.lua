-- Join flow: a short camera preview of the plaza as soon as the player is in, then
--  * new players (tutorial 0): a centred "NEED A TUTORIAL?" card over the preview - YES plays the intro cinematic and
--    starts the step tutorial, SKIP marks the tutorial done;
--  * everyone else: the preview just ends.
-- It always finishes with a smooth glide to the normal camera behind the character (never looking at the floor).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MapConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapConfig"))

local Join = {}
local UI, Cine, K, Intro, Tutorial

-- camera orbit around the plaza centre while waiting; returns a stop function
local function orbit(cam)
	local centre = Vector3.new(0, 4, (MapConfig.StartZ + MapConfig.EntryZ) / 2)
	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local a = (os.clock() - t0) * 0.12 + 0.6
		cam.CFrame = CFrame.lookAt(centre + Vector3.new(math.cos(a) * 120, 58, math.sin(a) * 120), centre)
	end)
	return function()
		conn:Disconnect()
	end
end

local function rootPart()
	local char = Players.LocalPlayer.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

-- ease the camera down to "behind the character, looking ahead", then hand it back to the player
local function glideHome(cam, t)
	local hrp = rootPart()
	if hrp then
		local look = hrp.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		flat = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, -1)
		local eye = hrp.Position - flat * 14 + Vector3.new(0, 5, 0)
		local goal = CFrame.lookAt(eye, hrp.Position + flat * 10 + Vector3.new(0, 1.5, 0))
		Cine.Move(goal, t, Enum.EasingStyle.Quad)
		task.wait(t)
		Cine.Release(0.2)
		cam.CFrame = goal -- the default camera continues from here
	else
		Cine.Release(0.2)
	end
end

-- the centred question card; resolves to true (YES) or false (SKIP)
local function ask()
	local P = K.P
	local choice
	local dim = K.new("Frame", { Name = "TutorialAsk", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 80 }, K.overlay)
	local card = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(560, 290), BackgroundColor3 = P.cream,
		ZIndex = 81 }, dim)
	K.corner(card, 26)
	K.stroke(card, P.ink, 5)
	K.text(card, { Text = "WELCOME TO CAR HUNTERS!", TextSize = 22, TextColor3 = P.orange, Outline = false, Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 82 })
	K.text(card, { Text = "NEED A TUTORIAL?", TextSize = 46, Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 54), TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 82, Outline = 3 })
	K.text(card, { Text = "A short video shows how to grab parts, catch cars and earn money.", Font = K.BODY, TextSize = 17, TextColor3 = P.muted, TextWrapped = true,
		Position = UDim2.fromOffset(40, 116), Size = UDim2.new(1, -80, 0, 44), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 82 })
	K.toy(card, { Text = "YES", Color = P.green, Size = UDim2.fromOffset(220, 74), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, -12, 1, -22), TextSize = 32,
		ZIndex = 83, OnClick = function() choice = true end })
	K.toy(card, { Text = "SKIP", Color = P.grey, Size = UDim2.fromOffset(220, 74), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, 12, 1, -22), TextSize = 32,
		ZIndex = 83, OnClick = function() choice = false end })
	local sc = K.new("UIScale", { Scale = 0.6 }, card)
	K.tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	while choice == nil and dim.Parent do
		task.wait()
	end
	dim:Destroy()
	return choice == true
end

local function run(st)
	local cam = Cine.Take()
	local stop = orbit(cam)
	local newPlayer = (st.tutorial or 0) == 0
	local cineOn = false
	local ok, err = pcall(function()
		if newPlayer then
			UI.SetCinematic(true) -- HUD away while the question is on screen
			cineOn = true
			Cine.Title("CAR HUNTERS", Color3.fromRGB(255, 210, 63), 2.2, 110, 0.22)
			task.wait(1.2)
			local yes = ask()
			stop()
			UI.SetCinematic(false)
			cineOn = false
			if yes then
				Intro.Play(st) -- the shown steps; ends by starting the step tutorial
				cam = Cine.Take()
			else
				Tutorial.Skip()
			end
		else
			Cine.Title("CAR HUNTERS", Color3.fromRGB(255, 210, 63), 1.8, 110, 0.22)
			task.wait(2.4)
			stop()
		end
	end)
	stop()
	if not ok then
		warn("[JoinFlow] " .. tostring(err))
		if cineOn then
			UI.SetCinematic(false)
		end
	end
	glideHome(cam, 1.2)
end

function Join.Start(ui, cine, intro, tutorial)
	UI, Cine, Intro, Tutorial = ui, cine, intro, tutorial
	K = UI.Kit()
	task.spawn(function()
		local st
		repeat
			task.wait(0.3)
			st = K.store.State
		until st and rootPart() and Workspace:FindFirstChild("GeneratedMap")
		run(st)
	end)
end

return Join
