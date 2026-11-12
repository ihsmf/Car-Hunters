local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("MapConfig"))
local TrafficMath = require(Shared:WaitForChild("TrafficMath"))
local VehicleFactory = require(Shared:WaitForChild("VehicleFactory"))
local VehicleKinds = require(Shared:WaitForChild("VehicleKinds"))
local Net = require(Shared:WaitForChild("Net"))
local Players = game:GetService("Players")

local Renderer = {}
local pools = {}
local ACTIVE_DIST = 380
local lastReport = 0

function Renderer.Start()
	local folder = Workspace:WaitForChild("RuntimeTraffic")
	local flip = CFrame.Angles(0, math.pi, 0)
	RunService.RenderStepped:Connect(function()
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		local camZ = cam.CFrame.Position.Z
		local t = Workspace:GetServerTimeNow()
		for ri, road in ipairs(MapConfig.Roads) do
			local active = math.abs(camZ - road.z) < ACTIVE_DIST
			for _, lane in ipairs(TrafficMath.RoadLanes[ri]) do
				local pool = pools[lane.index]
				if active then
					if not pool then
						pool = { models = {}, shown = false }
						for k = 1, lane.count do
							pool.models[k] = VehicleFactory.BuildTraffic(lane.kinds[k], MapConfig.TrafficColors[lane.colors[k]], lane.colors[k])
						end
						pools[lane.index] = pool
					end
					if not pool.shown then
						pool.shown = true
						for k, m in ipairs(pool.models) do
							m:PivotTo(CFrame.new(0, -500, 0))
							m.Parent = folder
						end
					end
					for k, m in ipairs(pool.models) do
						local x = TrafficMath.CarX(lane, k, t)
						local cf = CFrame.new(x, MapConfig.RoadTopY, TrafficMath.CarZ(lane, k, t))
						if lane.dir < 0 then
							cf = cf * flip
						end
						if lane.weaveA then
							local dz = lane.weaveA * lane.weaveW * math.cos(lane.weaveW * t + lane.weavePh[k])
							cf = cf * CFrame.Angles(0, -math.atan2(dz, lane.speed) * lane.dir, 0)
						end
						m.PrimaryPart.CFrame = cf
					end
				elseif pool and pool.shown then
					pool.shown = false
					for _, m in ipairs(pool.models) do
						m.Parent = nil
					end
				end
			end
		end
		-- local hit check against exactly what this player sees
		local char = Players.LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 and os.clock() - lastReport > 0.5 then
			local pos = hrp.Position
			local ri = TrafficMath.RoadAtZ(pos.Z, 3)
			if ri then
				for _, lane in ipairs(TrafficMath.RoadLanes[ri]) do
					for k = 1, lane.count do
						local kind = VehicleKinds[lane.kinds[k]]
						local dz = math.abs(pos.Z - TrafficMath.CarZ(lane, k, t))
						if dz <= kind.W / 2 + 1 and math.abs(pos.X - TrafficMath.CarX(lane, k, t)) <= kind.L / 2 + 1 and pos.Y < MapConfig.RoadTopY + kind.H + 2.5 then
							lastReport = os.clock()
							Net.Get("TrafficHit"):FireServer()
							return
						end
					end
				end
			end
		end
	end)
end

return Renderer
