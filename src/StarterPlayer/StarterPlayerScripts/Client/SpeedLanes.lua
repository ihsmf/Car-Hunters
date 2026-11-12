-- Running lanes: dark strips with white arrows. Boost only while running the way the arrows point.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MapConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapConfig"))

local SpeedLanes = {}
SpeedLanes.Boosting = false

function SpeedLanes.Start(getBaseSpeed)
	local player = Players.LocalPlayer
	local fov = 70
	RunService.Heartbeat:Connect(function(dt)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local cam = Workspace.CurrentCamera
		local boost = false
		if hum and hrp and hum.Health > 0 and hrp.Position.Y < 8 then
			local lane = MapConfig.LaneAt(hrp.Position)
			local md = hum.MoveDirection
			if lane and md.Magnitude > 0.1 and (md.X * lane[5] + md.Z * lane[6]) > 0.5 then
				boost = true
			end
			local base = getBaseSpeed and getBaseSpeed() or MapConfig.WalkSpeed
			local want = boost and (MapConfig.LaneSpeed + (base - MapConfig.WalkSpeed)) or base
			if math.abs(hum.WalkSpeed - want) > 0.01 then
				hum.WalkSpeed = want
			end
		end
		SpeedLanes.Boosting = boost
		if cam and cam.CameraType == Enum.CameraType.Custom then
			local kick = boost and game:GetService("Players").LocalPlayer:GetAttribute("Opt_fov") ~= false -- Settings
			fov = fov + ((kick and 80 or 70) - fov) * math.min(1, dt * 5)
			cam.FieldOfView = fov
		end
	end)
end

return SpeedLanes
