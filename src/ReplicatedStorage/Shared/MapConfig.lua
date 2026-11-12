local C = Color3.fromRGB

local MapConfig = {}

MapConfig.Seed = 12345
MapConfig.MapHalfWidth = 190
MapConfig.StartZ = -330
MapConfig.EndZ = 1056 -- recomputed below once every district is placed
MapConfig.PlazaEndZ = 70
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
MapConfig.PromenadeHalfWidth = 68

MapConfig.BasePlot = { x = 110, z = 95 }
MapConfig.BaseCount = 8
MapConfig.BaseCenters = {
	{ x = -125, z = -275 }, { x = 125, z = -275 },
	{ x = -125, z = -177 }, { x = 125, z = -177 },
	{ x = -125, z = -79 },  { x = 125, z = -79 },
	{ x = -125, z = 19 },   { x = 125, z = 19 },
}

-- centre of the plaza, between the garages
MapConfig.Shop = { x = -38, z = -128, yaw = -math.pi / 2 } -- faces the running lanes (+X)
MapConfig.DonateStall = { x = 38, z = -128, yaw = math.pi / 2 }
MapConfig.ContractBoard = { x = -30, z = 48 }
MapConfig.Leaderboard = { x = 34, z = 50 }
MapConfig.NoNeon = true -- map decor uses lit materials only where something is a real light source

-- Speed lanes: player WalkSpeed boost while standing on them (never cross roads)
MapConfig.WalkSpeed = 18
MapConfig.LaneSpeed = 48
MapConfig.LaneWidth = 6 -- each running lane; two lanes side by side, opposite directions

-- Route along +Z: plaza -> Tier 1 (4 districts) -> arena -> Tier 2 -> arena -> Tier 3 -> final arena.
MapConfig.ZoneOrder = {
	"city", "highway", "industrial", "neon", "scrapyard",
	"docks", "desert", "bridge", "airport", "canyon",
	"circuit", "drift", "storm", "rush", "colosseum",
}

MapConfig.Gates = {
	{ zone = "highway", z = 318 },
	{ zone = "industrial", z = 564 },
	{ zone = "neon", z = 810 },
}

MapConfig.Zones = {
	city = {
		id = "city", tier = 1, name = "CITY DISTRICT", zMin = 84, zMax = 310, roads = { 1, 2 }, hitDamage = 999,
		palette = {
			ground = C(110, 205, 95), road = C(62, 64, 72), sidewalk = C(222, 212, 192), curb = C(180, 172, 156),
			accent = C(255, 160, 50), accent2 = C(60, 170, 230),
			buildings = { C(255, 196, 120), C(255, 120, 100), C(110, 200, 255), C(255, 226, 110), C(255, 160, 180), C(130, 225, 150) },
		},
	},
	highway = {
		id = "highway", tier = 1, name = "HIGHWAY DISTRICT", zMin = 326, zMax = 556, roads = { 3, 4 }, hitDamage = 999,
		palette = {
			ground = C(126, 146, 116), road = C(50, 52, 58), sidewalk = C(176, 178, 184), curb = C(140, 142, 150),
			accent = C(255, 210, 40), accent2 = C(230, 70, 60),
			buildings = { C(200, 205, 215), C(120, 150, 190), C(230, 230, 235), C(90, 100, 120), C(255, 190, 70) },
		},
	},
	industrial = {
		id = "industrial", tier = 1, name = "INDUSTRIAL DISTRICT", zMin = 572, zMax = 802, roads = { 5, 6 }, hitDamage = 999,
		palette = {
			ground = C(150, 136, 116), road = C(52, 50, 50), sidewalk = C(168, 160, 148), curb = C(120, 114, 104),
			accent = C(255, 120, 30), accent2 = C(255, 220, 60),
			buildings = { C(150, 120, 100), C(110, 120, 130), C(170, 90, 70), C(130, 150, 120), C(190, 170, 130) },
		},
	},
	neon = {
		id = "neon", tier = 1, name = "NIGHT DISTRICT", zMin = 818, zMax = 1048, roads = { 7, 8 }, hitDamage = 999,
		palette = {
			ground = C(46, 52, 62), road = C(30, 32, 38), sidewalk = C(96, 100, 110), curb = C(70, 74, 84),
			accent = C(255, 170, 60), accent2 = C(90, 190, 255),
			buildings = { C(60, 70, 88), C(44, 52, 66), C(84, 74, 70), C(38, 42, 52), C(70, 84, 100) },
		},
	},
}

MapConfig.Plaza = {
	ground = C(110, 205, 95), paving = C(236, 228, 210), floor = C(52, 54, 62),
	accent = C(60, 200, 255),
}

MapConfig.Roads = {
	{ id = 1, zone = "city", z = 150, width = 36, lanesPerSide = 2, laneWidth = 8, median = 4,
		speed = { 30, 40 }, spacing = { 70, 95 }, kinds = { "compact", "sedan", "taxi", "van" } },
	{ id = 2, zone = "city", z = 245, width = 36, lanesPerSide = 2, laneWidth = 8, median = 4,
		speed = { 34, 44 }, spacing = { 65, 90 }, kinds = { "compact", "sedan", "taxi", "van" } },
	{ id = 3, zone = "highway", z = 395, width = 40, lanesPerSide = 2, laneWidth = 9, median = 4,
		speed = { 52, 66 }, spacing = { 70, 95 }, kinds = { "sedan", "sport", "minibus", "supercar" } },
	{ id = 4, zone = "highway", z = 488, width = 40, lanesPerSide = 2, laneWidth = 9, median = 4,
		speed = { 55, 70 }, spacing = { 65, 90 }, kinds = { "sedan", "sport", "minibus", "supercar" } },
	{ id = 5, zone = "industrial", z = 640, width = 38, lanesPerSide = 2, laneWidth = 8.5, median = 4,
		speed = { 42, 58 }, spacing = { 75, 100 }, kinds = { "truck", "pickup", "service" } },
	{ id = 6, zone = "industrial", z = 733, width = 38, lanesPerSide = 2, laneWidth = 8.5, median = 4,
		speed = { 45, 60 }, spacing = { 70, 95 }, kinds = { "truck", "pickup", "service" } },
	{ id = 7, zone = "neon", z = 886, width = 40, lanesPerSide = 2, laneWidth = 9, median = 4,
		speed = { 68, 84 }, spacing = { 70, 95 }, kinds = { "proto", "supercar", "sport" } },
	{ id = 8, zone = "neon", z = 979, width = 40, lanesPerSide = 2, laneWidth = 9, median = 4,
		speed = { 72, 90 }, spacing = { 65, 90 }, kinds = { "proto", "supercar", "sport" } },
}


-- Tier 2-3 districts and the three boss arenas. style = which Tier 1 look the builder reuses.
-- Each road: { off from zMin, lanesPerSide, laneWidth, speed, spacing, kinds, [loop, count, weave, surge] }
local EXTRA = {
	{ id = "scrapyard", tier = 1, arena = true, boss = "crusher", name = "SCRAPYARD ARENA", len = 300, style = "industrial",
		palette = { ground = C(132, 112, 88), road = C(52, 50, 50), sidewalk = C(150, 140, 126), curb = C(110, 100, 90), accent = C(255, 150, 40), accent2 = C(255, 220, 60),
			buildings = { C(140, 110, 90), C(110, 116, 122), C(160, 90, 70) } } },
	{ id = "docks", tier = 2, name = "DOCKS", len = 230, style = "industrial", hazard = "train",
		palette = { ground = C(120, 130, 136), road = C(46, 48, 52), sidewalk = C(160, 164, 168), curb = C(110, 116, 124), accent = C(255, 190, 40), accent2 = C(60, 150, 220),
			buildings = { C(200, 70, 50), C(50, 110, 180), C(230, 180, 40), C(60, 140, 90), C(220, 220, 224) } },
		roads = { { off = 66, rail = true, lanes = 1, lw = 10, speed = { 70, 80 }, loop = 1500, count = 1, kinds = { "train" } },
			{ off = 161, lanes = 2, lw = 9, speed = { 60, 76 }, spacing = { 60, 85 }, kinds = { "truck", "service", "pickup" } } } },
	{ id = "desert", tier = 2, name = "DESERT HIGHWAY", len = 230, style = "highway", hazard = "sandstorm",
		palette = { ground = C(226, 190, 130), road = C(70, 66, 62), sidewalk = C(214, 196, 160), curb = C(186, 160, 120), accent = C(255, 140, 40), accent2 = C(200, 80, 50),
			buildings = { C(226, 170, 110), C(200, 150, 100), C(240, 210, 160), C(180, 120, 80) } },
		roads = { { off = 66, lanes = 3, lw = 8.5, speed = { 62, 80 }, spacing = { 60, 85 }, kinds = { "pickup", "suv", "muscle", "truck" } },
			{ off = 166, lanes = 3, lw = 8.5, speed = { 66, 84 }, spacing = { 58, 80 }, kinds = { "pickup", "suv", "muscle", "sport" } } } },
	{ id = "bridge", tier = 2, name = "RIVER BRIDGES", len = 230, style = "city", hazard = "river",
		palette = { ground = C(104, 190, 96), road = C(58, 60, 68), sidewalk = C(214, 206, 190), curb = C(170, 164, 150), accent = C(60, 170, 230), accent2 = C(255, 160, 50),
			buildings = { C(240, 200, 150), C(200, 120, 100), C(120, 180, 220), C(250, 230, 180) } },
		roads = { { off = 52, lanes = 2, lw = 9, speed = { 66, 82 }, spacing = { 60, 85 }, kinds = { "sedan", "sport", "suv" } },
			{ off = 178, lanes = 2, lw = 9, speed = { 68, 86 }, spacing = { 58, 82 }, kinds = { "sedan", "sport", "minibus" } } } },
	{ id = "airport", tier = 2, name = "AIRPORT", len = 230, style = "highway", hazard = "jets",
		palette = { ground = C(120, 170, 100), road = C(64, 66, 72), sidewalk = C(190, 192, 196), curb = C(150, 152, 158), accent = C(255, 210, 40), accent2 = C(60, 120, 220),
			buildings = { C(220, 224, 230), C(140, 170, 210), C(240, 240, 244), C(90, 110, 140) } },
		roads = { { off = 70, lanes = 1, lw = 30, median = 8, speed = { 24, 30 }, loop = 1100, count = 2, kinds = { "plane" } },
			{ off = 168, lanes = 2, lw = 9, speed = { 60, 74 }, spacing = { 60, 82 }, kinds = { "service", "minibus", "van" } } } },
	{ id = "canyon", tier = 2, arena = true, boss = "juggernaut", name = "CANYON ARENA", len = 300, style = "highway",
		palette = { ground = C(196, 120, 80), road = C(70, 60, 56), sidewalk = C(200, 150, 110), curb = C(160, 100, 70), accent = C(255, 170, 60), accent2 = C(220, 70, 50),
			buildings = { C(190, 110, 70), C(170, 90, 60), C(210, 140, 90) } } },
	{ id = "circuit", tier = 3, name = "RACE CIRCUIT", len = 230, style = "highway", hazard = "racers",
		palette = { ground = C(96, 170, 90), road = C(44, 46, 52), sidewalk = C(230, 230, 230), curb = C(214, 52, 44), accent = C(255, 210, 40), accent2 = C(214, 52, 44),
			buildings = { C(230, 230, 236), C(214, 52, 44), C(40, 44, 52), C(255, 210, 40) } },
		roads = { { off = 66, lanes = 2, lw = 9.5, speed = { 96, 112 }, spacing = { 100, 140 }, kinds = { "racer" } },
			{ off = 161, lanes = 2, lw = 9.5, speed = { 100, 118 }, spacing = { 95, 130 }, kinds = { "racer" } } } },
	{ id = "drift", tier = 3, name = "DRIFT DISTRICT", len = 230, style = "neon", hazard = "weave",
		palette = { ground = C(52, 56, 70), road = C(32, 34, 40), sidewalk = C(100, 104, 116), curb = C(76, 80, 92), accent = C(255, 90, 140), accent2 = C(80, 200, 255),
			buildings = { C(70, 60, 90), C(50, 56, 72), C(90, 70, 80), C(40, 46, 60) } },
		roads = { { off = 66, lanes = 2, lw = 10.5, speed = { 74, 92 }, spacing = { 64, 90 }, kinds = { "sport", "muscle", "supercar" }, weave = 3.4 },
			{ off = 161, lanes = 2, lw = 10.5, speed = { 78, 96 }, spacing = { 62, 86 }, kinds = { "sport", "muscle", "supercar" }, weave = 3.8 } } },
	{ id = "storm", tier = 3, name = "STORM VALLEY", len = 230, style = "neon", hazard = "storm",
		palette = { ground = C(70, 84, 80), road = C(34, 36, 40), sidewalk = C(110, 116, 120), curb = C(84, 90, 96), accent = C(255, 230, 120), accent2 = C(120, 170, 255),
			buildings = { C(80, 90, 100), C(60, 70, 80), C(100, 104, 110), C(50, 56, 64) } },
		roads = { { off = 66, lanes = 2, lw = 9, speed = { 82, 98 }, spacing = { 62, 86 }, kinds = { "suv", "truck", "sport", "pickup" } },
			{ off = 161, lanes = 2, lw = 9, speed = { 84, 102 }, spacing = { 60, 84 }, kinds = { "suv", "sedan", "supercar" } } } },
	{ id = "rush", tier = 3, name = "RUSH HOUR", len = 230, style = "highway", hazard = "rush",
		palette = { ground = C(110, 150, 110), road = C(48, 50, 56), sidewalk = C(186, 186, 190), curb = C(146, 146, 152), accent = C(255, 120, 40), accent2 = C(255, 210, 40),
			buildings = { C(200, 205, 215), C(120, 150, 190), C(255, 190, 70), C(90, 100, 120) } },
		roads = { { off = 66, lanes = 3, lw = 8.5, speed = { 84, 104 }, spacing = { 58, 80 }, kinds = { "sedan", "taxi", "sport", "truck", "supercar" }, surge = 0.6 },
			{ off = 166, lanes = 3, lw = 8.5, speed = { 88, 108 }, spacing = { 56, 78 }, kinds = { "van", "minibus", "proto", "racer" }, surge = 0.6 } } },
	{ id = "colosseum", tier = 3, arena = true, boss = "titan", name = "COLOSSEUM", len = 300, style = "neon",
		palette = { ground = C(214, 196, 160), road = C(60, 56, 52), sidewalk = C(230, 220, 196), curb = C(190, 176, 150), accent = C(255, 200, 60), accent2 = C(214, 52, 44),
			buildings = { C(230, 216, 186), C(200, 186, 156), C(240, 230, 210) } } },
}

for i, g in ipairs(MapConfig.Gates) do
	g.index = i
end
do
	local cur = MapConfig.Zones.neon.zMax + 16
	for _, e in ipairs(EXTRA) do
		local z = { id = e.id, tier = e.tier, name = e.name, arena = e.arena, boss = e.boss, style = e.style, hazard = e.hazard, palette = e.palette,
			zMin = cur, zMax = cur + e.len, roads = {}, hitDamage = 999 }
		for _, r in ipairs(e.roads or {}) do
			local med = r.median or 4
			local width = 2 * r.lanes * r.lw + med
			local road = { id = #MapConfig.Roads + 1, zone = e.id, z = z.zMin + r.off, width = width, lanesPerSide = r.lanes, laneWidth = r.lw, median = med,
				speed = r.speed, spacing = r.spacing or { 80, 100 }, kinds = r.kinds, loop = r.loop, count = r.count, weave = r.weave, surge = r.surge, rail = r.rail }
			table.insert(MapConfig.Roads, road)
			table.insert(z.roads, road.id)
		end
		MapConfig.Zones[e.id] = z
		table.insert(MapConfig.Gates, { zone = e.id, z = cur - 8 })
		cur = z.zMax + 16
	end
	MapConfig.EndZ = cur - 8
end
for _, z in pairs(MapConfig.Zones) do
	z.style = z.style or z.id
end

-- river crossing in the bridge district: z range of water between its two roads
MapConfig.River = { zone = "bridge", z1 = MapConfig.Zones.bridge.zMin + 84, z2 = MapConfig.Zones.bridge.zMin + 146, bridges = { { x = 0, w = 16 }, { x = -96, w = 8 }, { x = 96, w = 8 } } }

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
-- Running lanes: one central pair (out / back home) down the plaza and every district, stopping before roads.
-- Each lane = { x1, x2, z1, z2, dx, dz } where (dx,dz) is
-- the arrow direction; the boost only works while running that way.
function MapConfig.SpeedLanes()
	if MapConfig._lanes then
		return MapConfig._lanes
	end
	local w, g = MapConfig.LaneWidth, 0.5
	local out = {}
	local function pairZ(z1, z2)
		table.insert(out, { -g - w, -g, z1, z2, 0, 1 }) -- left lane: away from the garages
		table.insert(out, { g, g + w, z1, z2, 0, -1 }) -- right lane: back home
	end
	pairZ(MapConfig.StartZ + 14, MapConfig.EntryZ + 8)
	for _, zid in ipairs(MapConfig.ZoneOrder) do
		for _, b in ipairs(MapConfig.ZoneBlocks(zid)) do
			if b[2] - b[1] > 16 then
				pairZ(b[1] + 3, b[2] - 3)
			end
		end
	end
	MapConfig._lanes = out
	return out
end

-- returns the lane under pos (or nil)
function MapConfig.LaneAt(pos)
	for _, r in ipairs(MapConfig.SpeedLanes()) do
		if pos.X >= r[1] and pos.X <= r[2] and pos.Z >= r[3] and pos.Z <= r[4] then
			return r
		end
	end
	return nil
end

function MapConfig.OnSpeedLane(pos)
	return MapConfig.LaneAt(pos) ~= nil
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
