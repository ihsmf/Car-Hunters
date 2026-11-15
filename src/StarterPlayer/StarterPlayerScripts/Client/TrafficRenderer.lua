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

local Perf = require(script.Parent:WaitForChild("Perf"))

local Renderer = {}
-- pools[lane.index] = { models = {k -> Model}, built = n, shown = bool, road = ri }
local pools = {}
local ACTIVE = { HIGH = 380, MED = 260, LOW = 190 }
local INLINE_BUILDS = 2 -- most models ever built inside RenderStepped (only for a road that is already in view)
local BG_BUDGET = 0.002 -- s of building per frame in the background
local lastReport = 0
local parked = CFrame.new(0, -500, 0)

local function activeDist()
	return ACTIVE[Perf.Level()] or ACTIVE.HIGH
end

local function getPool(lane)
	local pool = pools[lane.index]
	if not pool then
		pool = { models = {}, built = 0, shown = false, road = lane.road }
		pools[lane.index] = pool
	end
	return pool
end

-- builds the next missing model of a lane's pool; false when the pool is complete
local function buildNext(lane, folder)
	local pool = getPool(lane)
	if pool.built >= lane.count then
		return false
	end
	local k = pool.built + 1
	pool.built = k -- claimed before building, so the same car is never built twice
	local ok, m = pcall(VehicleFactory.BuildTraffic, lane.kinds[k], MapConfig.TrafficColors[lane.colors[k]], lane.colors[k])
	if ok and m and m.PrimaryPart then
		if pools[lane.index] ~= pool then
			m:Destroy() -- the pool was dropped meanwhile
			return true
		end
		pool.models[k] = m
		if pool.shown then
			m:PivotTo(parked)
			m.Parent = folder
		end
	elseif not ok then
		warn("[Traffic] could not build", lane.kinds[k], m)
	end
	return true
end

local function destroyPool(index)
	local pool = pools[index]
	pools[index] = nil
	if pool then
		for _, m in pairs(pool.models) do
			m:Destroy()
		end
	end
end

-- background: prebuild the pools of the nearest roads a few models per frame, drop the far ones
local function prebuilder(folder)
	local order = {}
	local lastSweep = 0
	while true do
		RunService.Heartbeat:Wait()
		local cam = Workspace.CurrentCamera
		if cam then
			local camZ = cam.CFrame.Position.Z
			local dist = activeDist()
			local now = os.clock()
			if now - lastSweep > 1 then
				lastSweep = now
				for index, pool in pairs(pools) do
					local road = MapConfig.Roads[pool.road]
					if not road or math.abs(camZ - road.z) > dist * 2 then
						destroyPool(index)
					end
				end
			end
			-- nearest roads first, up to 1.5x the active distance (so a road is ready before it comes into view)
			table.clear(order)
			for ri, road in ipairs(MapConfig.Roads) do
				local d = math.abs(camZ - road.z)
				if d < dist * 1.5 then
					table.insert(order, { ri = ri, d = d })
				end
			end
			table.sort(order, function(a, b) return a.d < b.d end)
			local t0 = os.clock()
			local built = 0
			for _, o in ipairs(order) do
				for _, lane in ipairs(TrafficMath.RoadLanes[o.ri]) do
					while (built == 0 or os.clock() - t0 < BG_BUDGET) and buildNext(lane, folder) do
						built = built + 1
					end
					if built > 0 and os.clock() - t0 >= BG_BUDGET then
						break
					end
				end
				if built > 0 and os.clock() - t0 >= BG_BUDGET then
					break
				end
			end
		end
	end
end

function Renderer.Start()
	local folder = Workspace:WaitForChild("RuntimeTraffic")
	local flip = CFrame.Angles(0, math.pi, 0)
	task.spawn(prebuilder, folder)
	local parts, cfs = {}, {}
	RunService.RenderStepped:Connect(function()
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		local camZ = cam.CFrame.Position.Z
		local t = Workspace:GetServerTimeNow()
		local dist = activeDist()
		local inlineLeft = INLINE_BUILDS
		table.clear(parts)
		table.clear(cfs)
		for ri, road in ipairs(MapConfig.Roads) do
			local active = math.abs(camZ - road.z) < dist
			for _, lane in ipairs(TrafficMath.RoadLanes[ri]) do
				local pool = pools[lane.index]
				if active then
					pool = pool or getPool(lane)
					while inlineLeft > 0 and pool.built < lane.count do
						inlineLeft = inlineLeft - 1
						buildNext(lane, folder)
					end
					if not pool.shown then
						pool.shown = true
						for _, m in pairs(pool.models) do
							m:PivotTo(parked)
							m.Parent = folder
						end
					end
					for k = 1, lane.count do
						local m = pool.models[k]
						local root = m and m.PrimaryPart
						if root then
							local x = TrafficMath.CarX(lane, k, t)
							local cf = CFrame.new(x, MapConfig.RoadTopY, TrafficMath.CarZ(lane, k, t))
							if lane.dir < 0 then
								cf = cf * flip
							end
							if lane.weaveA then
								local dz = lane.weaveA * lane.weaveW * math.cos(lane.weaveW * t + lane.weavePh[k])
								cf = cf * CFrame.Angles(0, -math.atan2(dz, lane.speed) * lane.dir, 0)
							end
							table.insert(parts, root)
							table.insert(cfs, cf)
						end
					end
				elseif pool and pool.shown then
					pool.shown = false
					for _, m in pairs(pool.models) do
						m.Parent = nil
					end
				end
			end
		end
		if #parts > 0 then
			-- one engine call for every car (welds carry the bodies along with each anchored root)
			Workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
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
