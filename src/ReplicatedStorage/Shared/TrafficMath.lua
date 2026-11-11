local MapConfig = require(script.Parent.MapConfig)

local M = {}

M.Length = 2 * (MapConfig.MapHalfWidth + MapConfig.TunnelLength)
M.MinX = -(MapConfig.MapHalfWidth + MapConfig.TunnelLength)
M.VisibleHalfX = MapConfig.MapHalfWidth + 30

local function newRng(seed)
	local s = (math.floor(seed) % 2147483646) + 1
	return function()
		s = (s * 16807) % 2147483647
		return s / 2147483647
	end
end
M.NewRng = newRng

M.Lanes = {}
M.RoadLanes = {}

for ri, road in ipairs(MapConfig.Roads) do
	local rng = newRng(MapConfig.Seed + ri * 7919)
	local lanes = {}
	local lps, lw, med = road.lanesPerSide, road.laneWidth, road.median
	for _, side in ipairs({ -1, 1 }) do
		for i = 1, lps do
			local zoff
			if side == -1 then
				zoff = -(med / 2) - lw * (i - 0.5)
			else
				zoff = (med / 2) + lw * (i - 0.5)
			end
			local dir = (side == -1) and 1 or -1
			local speed = road.speed[1] + (road.speed[2] - road.speed[1]) * rng()
			local spacing = road.spacing[1] + (road.spacing[2] - road.spacing[1]) * rng()
			local n = math.max(2, math.floor(M.Length / spacing + 0.5))
			local S = M.Length / n
			local offsets, kinds, colors = {}, {}, {}
			for k = 1, n do
				offsets[k] = (k - 1) * S + (rng() * 2 - 1) * 0.18 * S
				kinds[k] = road.kinds[math.floor(rng() * #road.kinds) + 1]
				colors[k] = math.floor(rng() * #MapConfig.TrafficColors) + 1
			end
			local lane = {
				road = ri, index = #M.Lanes + 1, side = side, dir = dir, z = road.z + zoff,
				speed = speed, count = n, spacing = S, offsets = offsets, kinds = kinds,
				colors = colors, phase = rng() * M.Length,
			}
			local sg = MapConfig.Surge
			if sg then
				local period = sg.period[1] + (sg.period[2] - sg.period[1]) * rng()
				lane.surgeW = 2 * math.pi / period
				lane.surgeA = sg.amp * speed / lane.surgeW
				lane.surgePhase = rng() * 2 * math.pi
			end
			table.insert(lanes, lane)
			table.insert(M.Lanes, lane)
		end
	end
	M.RoadLanes[ri] = lanes
end

function M.CarX(lane, k, t)
	local surge = lane.surgeA and lane.surgeA * math.sin(lane.surgeW * t + lane.surgePhase) or 0
	local d = (lane.speed * t + surge + lane.phase + lane.offsets[k]) % M.Length
	local x = M.MinX + d
	if lane.dir < 0 then
		x = -x
	end
	return x
end

function M.RoadAtZ(z, margin)
	margin = margin or 0
	for ri, road in ipairs(MapConfig.Roads) do
		if math.abs(z - road.z) <= road.width / 2 + margin then
			return ri
		end
	end
	return nil
end

return M
