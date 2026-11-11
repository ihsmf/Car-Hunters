-- Speed lanes: boost WalkSpeed on orange strips, animate chevrons, little FOV kick.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MapConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapConfig"))

local SpeedLanes = {}
local ORANGE, YELLOW, WHITE = Color3.fromRGB(255, 138, 31), Color3.fromRGB(255, 210, 63), Color3.fromRGB(255, 255, 255)

function SpeedLanes.Start()
	local player = Players.LocalPlayer
	local onLane = false
	local fov = 70
	local lastAnim = 0
	RunService.Heartbeat:Connect(function(dt)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local cam = Workspace.CurrentCamera
		if hum and hrp and hum.Health > 0 then
			local p = hrp.Position
			local now = p.Y < 8 and MapConfig.OnSpeedLane(p)
			if now ~= onLane then
				onLane = now
				hum.WalkSpeed = now and MapConfig.LaneSpeed or MapConfig.WalkSpeed
			end
		end
		if cam and cam.CameraType == Enum.CameraType.Custom then
			fov = fov + ((onLane and 82 or 70) - fov) * math.min(1, dt * 4)
			cam.FieldOfView = fov
		end
		if os.clock() - lastAnim < 0.08 then
			return
		end
		lastAnim = os.clock()
		local t = lastAnim * 1.6
		for _, ch in ipairs(CollectionService:GetTagged("SpeedChevron")) do
			local ph = (t - (ch:GetAttribute("Phase") or 0) * 4) % 1
			ch.Color = ph < 0.18 and WHITE or (ph < 0.45 and YELLOW or ORANGE)
		end
	end)
end

return SpeedLanes
