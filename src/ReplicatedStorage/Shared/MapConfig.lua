local C = Color3.fromRGB

local MapConfig = {}

MapConfig.Seed = 12345
MapConfig.MapHalfWidth = 230
MapConfig.StartZ = -340
MapConfig.EndZ = 1150
MapConfig.PlazaEndZ = 66
MapConfig.DecorationDensity = 0.75
MapConfig.GraphicsQuality = "MobileFriendly"
MapConfig.Cartoon = true

MapConfig.RoadTopY = 0.2
MapConfig.SidewalkTopY = 0.8
MapConfig.SidewalkWidth = 6
MapConfig.TunnelLength = 50
MapConfig.EntryHalfWidth = 60
MapConfig.GateHalfWidth = 30
MapConfig.EntryZ = 74
MapConfig.PromenadeHalfWidth = 100

MapConfig.BasePlot = { x = 110, z = 95 }
MapConfig.BaseCount = 8
MapConfig.BaseCenters = {
	{ x = -160, z = -285 }, { x = 160, z = -285 },
	{ x = -160, z = -185 }, { x = 160, z = -185 },
	{ x = -160, z = -85 },  { x = 160, z = -85 },
	{ x = -160, z = 15 },   { x = 160, z = 15 },
}

-- Speed lanes: player WalkSpeed boost while standing on them (never cross roads)
MapConfig.WalkSpeed = 18
MapConfig.LaneSpeed = 48
MapConfig.LaneHalfWidth = 5

MapConfig.ZoneOrder = { "city", "highway", "industrial", "neon" }

MapConfig.Gates = {
	{ zone = "highway", z = 340 },
	{ zone = "industrial", z = 610 },
	{ zone = "neon", z = 880 },
}

MapConfig.Zones = {
	city = {
		id = "city", name = "CITY DISTRICT", zMin = 84, zMax = 330, roads = { 1, 2 }, hitDamage = 999,
		palette = {
			ground = C(110, 205, 95), road = C(62, 64, 72), sidewalk = C(222, 212, 192), curb = C(180, 172, 156),
			accent = C(255, 160, 50), accent2 = C(60, 170, 230),
			buildings = { C(255, 196, 120), C(255, 120, 100), C(110, 200, 255), C(255, 226, 110), C(255, 160, 180), C(130, 225, 150) },
		},
	},
	highway = {
		id = "highway", name = "HIGHWAY DISTRICT", zMin = 350, zMax = 600, roads = { 3, 4 }, hitDamage = 999,
		palette = {
			ground = C(126, 146, 116), road = C(50, 52, 58), sidewalk = C(176, 178, 184), curb = C(140, 142, 150),
			accent = C(255, 210, 40), accent2 = C(230, 70, 60),
			buildings = { C(200, 205, 215), C(120, 150, 190), C(230, 230, 235), C(90, 100, 120), C(255, 190, 70) },
		},
	},
	industrial = {
		id = "industrial", name = "INDUSTRIAL DISTRICT", zMin = 620, zMax = 870, roads = { 5, 6 }, hitDamage = 999,
		palette = {
			ground = C(150, 136, 116), road = C(52, 50, 50), sidewalk = C(168, 160, 148), curb = C(120, 114, 104),
			accent = C(255, 120, 30), accent2 = C(255, 220, 60),
			buildings = { C(150, 120, 100), C(110, 120, 130), C(170, 90, 70), C(130, 150, 120), C(190, 170, 130) },
		},
	},
	neon = {
		id = "neon", name = "NEON DISTRICT", zMin = 890, zMax = 1140, roads = { 7, 8 }, hitDamage = 999,
		palette = {
			ground = C(16, 30, 44), road = C(16, 18, 26), sidewalk = C(30, 52, 70), curb = C(40, 200, 220),
			accent = C(255, 60, 120), accent2 = C(40, 240, 255),
			buildings = { C(20, 44, 70), C(14, 30, 52), C(30, 60, 64), C(18, 24, 36), C(40, 50, 80) },
		},
	},
}

MapConfig.Plaza = {
	ground = C(110, 205, 95), paving = C(236, 228, 210), floor = C(52, 54, 62),
	accent = C(60, 200, 255),
}

MapConfig.Roads = {
	{ id = 1, zone = "city", z = 160, width = 36, lanesPerSide = 2, laneWidth = 8, median = 4,
		speed = { 30, 40 }, spacing = { 70, 95 }, kinds = { "compact", "sedan", "taxi", "van" } },
	{ id = 2, zone = "city", z = 265, width = 36, lanesPerSide = 2, laneWidth = 8, median = 4,
		speed = { 34, 44 }, spacing = { 65, 90 }, kinds = { "compact", "sedan", "taxi", "van" } },
	{ id = 3, zone = "highway", z = 420, width = 40, lanesPerSide = 2, laneWidth = 9, median = 4,
		speed = { 52, 66 }, spacing = { 70, 95 }, kinds = { "sedan", "sport", "minibus", "supercar" } },
	{ id = 4, zone = "highway", z = 530, width = 40, lanesPerSide = 2, laneWidth = 9, median = 4,
		speed = { 55, 70 }, spacing = { 65, 90 }, kinds = { "sedan", "sport", "minibus", "supercar" } },
	{ id = 5, zone = "industrial", z = 690, width = 38, lanesPerSide = 2, laneWidth = 8.5, median = 4,
		speed = { 42, 58 }, spacing = { 75, 100 }, kinds = { "truck", "pickup", "service" } },
	{ id = 6, zone = "industrial", z = 800, width = 38, lanesPerSide = 2, laneWidth = 8.5, median = 4,
		speed = { 45, 60 }, spacing = { 70, 95 }, kinds = { "truck", "pickup", "service" } },
	{ id = 7, zone = "neon", z = 960, width = 40, lanesPerSide = 2, laneWidth = 9, median = 4,
		speed = { 68, 84 }, spacing = { 70, 95 }, kinds = { "proto", "supercar", "sport" } },
	{ id = 8, zone = "neon", z = 1070, width = 40, lanesPerSide = 2, laneWidth = 9, median = 4,
		speed = { 72, 90 }, spacing = { 65, 90 }, kinds = { "proto", "supercar", "sport" } },
}

-- Lane "surge": whole lane periodically speeds up/slows down (deterministic, client == server)
MapConfig.Surge = { amp = 0.35, period = { 5, 9 } }

MapConfig.TrafficColors = {
	C(220, 60, 60), C(60, 120, 220), C(240, 200, 50), C(70, 70, 78),
	C(235, 235, 240), C(70, 170, 100), C(240, 130, 40), C(40, 200, 220),
}

function MapConfig.ZoneAt(z)
	if z < MapConfig.EntryZ then
		return "plaza"
	end
	for i = #MapConfig.Gates, 1, -1 do
		if z >= MapConfig.Gates[i].z then
			return MapConfig.Gates[i].zone
		end
	end
	return "city"
end

function MapConfig.GateOfZone(zoneId)
	for _, g in ipairs(MapConfig.Gates) do
		if g.zone == zoneId then
			return g
		end
	end
	return nil
end

function MapConfig.ZoneIndex(zoneId)
	for i, id in ipairs(MapConfig.ZoneOrder) do
		if id == zoneId then
			return i
		end
	end
	return 0
end

function MapConfig.ZoneSpawn(zoneId)
	local z = MapConfig.Zones[zoneId]
	if not z then
		return nil
	end
	return Vector3.new(0, 4, z.zMin + 12)
end

function MapConfig.ZoneBlocks(zoneId)
	local zone = MapConfig.Zones[zoneId]
	local blocks = {}
	local prev = (zoneId == "city") and MapConfig.EntryZ + 10 or zone.zMin
	for _, rid in ipairs(zone.roads) do
		local r = MapConfig.Roads[rid]
		table.insert(blocks, { prev, r.z - r.width / 2 - MapConfig.SidewalkWidth })
		prev = r.z + r.width / 2 + MapConfig.SidewalkWidth
	end
	table.insert(blocks, { prev, zone.zMax })
	return blocks
end

-- rectangles {x1, x2, z1, z2}
function MapConfig.SpeedLanes()
	if MapConfig._lanes then
		return MapConfig._lanes
	end
	local w = MapConfig.LaneHalfWidth
	local out = { { -w, w, MapConfig.StartZ + 20, MapConfig.EntryZ + 8 } }
	local inner = MapConfig.BaseCenters[1].x
	for i = 1, #MapConfig.BaseCenters, 2 do
		local z = MapConfig.BaseCenters[i].z
		table.insert(out, { inner + MapConfig.BasePlot.x / 2 + 2, -w, z - w, z + w })
		table.insert(out, { w, -inner - MapConfig.BasePlot.x / 2 - 2, z - w, z + w })
	end
	for _, zid in ipairs(MapConfig.ZoneOrder) do
		for _, b in ipairs(MapConfig.ZoneBlocks(zid)) do
			if b[2] - b[1] > 16 then
				table.insert(out, { -w, w, b[1] + 3, b[2] - 3 })
			end
		end
	end
	MapConfig._lanes = out
	return out
end

function MapConfig.OnSpeedLane(pos)
	for _, r in ipairs(MapConfig.SpeedLanes()) do
		if pos.X >= r[1] and pos.X <= r[2] and pos.Z >= r[3] and pos.Z <= r[4] then
			return true
		end
	end
	return false
end

function MapConfig.Validate()
	local errors = {}
	for _, r in ipairs(MapConfig.Roads) do
		local w = 2 * r.lanesPerSide * r.laneWidth + r.median
		if w ~= r.width then
			table.insert(errors, "Road" .. r.id .. ": width " .. r.width .. " ~= computed " .. w)
		end
	end
	for i = 1, #MapConfig.BaseCenters do
		for j = i + 1, #MapConfig.BaseCenters do
			local a, b = MapConfig.BaseCenters[i], MapConfig.BaseCenters[j]
			local ox = math.abs(a.x - b.x) < MapConfig.BasePlot.x
			local oz = math.abs(a.z - b.z) < MapConfig.BasePlot.z
			if ox and oz then
				table.insert(errors, "Bases " .. i .. " and " .. j .. " overlap")
			end
		end
	end
	return errors
end

return MapConfig
