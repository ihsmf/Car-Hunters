-- Owner-only filming mode: a small CAM button (top-right) or the P key turns on a free-flying camera with the whole HUD
-- hidden. WASD move, E/Q up/down, hold right mouse to look around, mouse wheel = zoom (field of view), Shift = fast,
-- Ctrl = slow. P or the button again = back to normal. The character does not move while flying.
-- Purely visual and client-side: only the experience owner sees the button.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")

local OWNERS = { [1221663569] = true }

local Photo = {}
local UI, Cine, K
local on = false
local btn, hint
local yaw, pitch, pos, fov = 0, 0, Vector3.zero, 70
local conn

local function sink()
	return Enum.ContextActionResult.Sink -- WASD / jump drive the camera, not the character
end

local function stop()
	on = false
	if conn then
		conn:Disconnect()
		conn = nil
	end
	ContextActionService:UnbindAction("PhotoModeSink")
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	local cam = Workspace.CurrentCamera
	cam.FieldOfView = 70
	Cine.Release(0.2)
	UI.SetCinematic(false)
	hint.Visible = false
	btn.holder.Visible = true
end

local function start()
	on = true
	UI.SetCinematic(true) -- hides the HUD
	local cam = Cine.Take()
	pos = cam.CFrame.Position
	local look = cam.CFrame.LookVector
	yaw = math.atan2(-look.X, -look.Z)
	pitch = math.asin(math.clamp(look.Y, -1, 1))
	fov = cam.FieldOfView
	ContextActionService:BindActionAtPriority("PhotoModeSink", sink, false, Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Space, Enum.KeyCode.E, Enum.KeyCode.Q)
	btn.holder.Visible = false
	hint.Visible = true
	task.delay(3, function()
		hint.Visible = false
	end)
	conn = RunService.RenderStepped:Connect(function(dt)
		local rmb = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
		UserInputService.MouseBehavior = rmb and Enum.MouseBehavior.LockCurrentPosition or Enum.MouseBehavior.Default
		if rmb then
			local d = UserInputService:GetMouseDelta()
			yaw = yaw - d.X * 0.004
			pitch = math.clamp(pitch - d.Y * 0.004, -1.5, 1.5)
		end
		local rot = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
		local move = Vector3.zero
		local function key(k)
			return UserInputService:IsKeyDown(k) and 1 or 0
		end
		move = move + rot.LookVector * (key(Enum.KeyCode.W) - key(Enum.KeyCode.S))
		move = move + rot.RightVector * (key(Enum.KeyCode.D) - key(Enum.KeyCode.A))
		move = move + Vector3.yAxis * (key(Enum.KeyCode.E) - key(Enum.KeyCode.Q))
		local speed = (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 90 or 28) * (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and 0.25 or 1)
		if move.Magnitude > 0 then
			pos = pos + move.Unit * speed * dt
		end
		local cam = Workspace.CurrentCamera
		cam.CFrame = CFrame.new(pos) * rot
		cam.FieldOfView = cam.FieldOfView + (fov - cam.FieldOfView) * math.min(1, dt * 10) -- smooth zoom
	end)
end

local function toggle()
	if on then
		stop()
	elseif not UI.IsCinematic() then
		start()
	end
end

function Photo.Start(ui, cine)
	if not (OWNERS[Players.LocalPlayer.UserId] or Players.LocalPlayer.UserId == game.CreatorId) then
		return -- nobody else gets the button
	end
	UI, Cine = ui, cine
	K = UI.Kit()
	-- on the overlay layer so it stays clickable; tiny, top-right under the Roblox menu
	btn = K.toy(K.overlay, { Text = "CAM", Color = K.P.grey, Size = UDim2.fromOffset(70, 36), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -150, 0, 10),
		TextSize = 16, Depth = 4, Radius = 10, ZIndex = 90, OnClick = toggle })
	hint = K.text(K.overlay, { Text = "FILM MODE  ·  WASD move · E/Q up/down · right mouse look · wheel zoom · Shift fast · P exit", TextSize = 16,
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(900, 20), TextXAlignment = Enum.TextXAlignment.Center, Visible = false, ZIndex = 90 })
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then
			return
		end
		if input.KeyCode == Enum.KeyCode.P then
			toggle()
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if on and input.UserInputType == Enum.UserInputType.MouseWheel then
			fov = math.clamp(fov - input.Position.Z * 5, 8, 110) -- wheel up = zoom in
		end
	end)
end

return Photo
