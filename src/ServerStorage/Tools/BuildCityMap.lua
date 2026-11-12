local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("MapConfig"))
local PartConfig = require(Shared:WaitForChild("PartConfig"))
local CarConfig = require(Shared:WaitForChild("CarConfig"))
local BaseLayout = require(Shared:WaitForChild("BaseLayout"))
local TrafficMath = require(Shared:WaitForChild("TrafficMath"))
local VehicleFactory = require(Shared:WaitForChild("VehicleFactory"))
local Prefabs = require(script.Parent:WaitForChild("MapPrefabs"))
local GarageKit = require(Shared:WaitForChild("GarageKit"))
local GarageStyle = GarageKit.Style
local function GarageBay(slotsFolder, model, bcf, n, topY)
	return GarageKit.Bay(slotsFolder, model, bcf, n, topY)
end

local C = Color3.fromRGB
local M = Enum.Material
local Part, Label = Prefabs.Part, Prefabs.Label
local pick, rr = Prefabs.Pick, Prefabs.RR
local HW = MapConfig.MapHalfWidth
local CYL = Enum.PartType.Cylinder
local TL = MapConfig.TunnelLength
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

local Build = {}

local TYPE_FOLDERS = { "Ground", "Roads", "Sidewalks", "Buildings", "StreetProps", "ZoneGates", "Bases", "TrafficRoutes", "PartSpawnPoints" }
local ALL_SECTIONS = { "World", "Plaza" }
local ZONE_OF = {}
for _, zid in ipairs(MapConfig.ZoneOrder) do
	table.insert(ALL_SECTIONS, string.upper(zid))
	ZONE_OF[string.upper(zid)] = zid
end

local function getRoot()
	local root = Workspace:FindFirstChild("GeneratedMap")
	if not root then
		root = Instance.new("Folder")
		root.Name = "GeneratedMap"
		root.Parent = Workspace
	end
	for _, name in ipairs(TYPE_FOLDERS) do
		if not root:FindFirstChild(name) then
			local f = Instance.new("Folder")
			f.Name = name
			f.Parent = root
		end
	end
	return root
end

local function clearSection(root, section)
	for _, name in ipairs(TYPE_FOLDERS) do
		local sub = root[name]:FindFirstChild(section)
		if sub then
			sub:Destroy()
		end
	end
end

local function newFolders(section)
	local t = {}
	for _, name in ipairs(TYPE_FOLDERS) do
		local f = Instance.new("Folder")
		f.Name = section
		t[name] = f
	end
	return t
end

local function inFootprint(foot, x, z, margin)
	for _, r in ipairs(foot) do
		if x > r.x1 - margin and x < r.x2 + margin and z > r.z1 - margin and z < r.z2 + margin then
			return true
		end
	end
	return false
end

local WHITE = C(240, 240, 245)
local YELLOW = C(255, 205, 40)

local function buildWorld(ctx)
	local f = ctx.f
	local zS, zE = MapConfig.StartZ, MapConfig.EndZ
	for z = zS - 700, zE + 700, 2000 do
		local len = math.min(2000, zE + 700 - z)
		Part(f.Ground, "WorldFloor", Vector3.new(2000, 2, len), CFrame.new(0, -2.2, z + len / 2), C(26, 28, 36), M.Concrete)
	end

	local openings = {}
	for _, r in ipairs(MapConfig.Roads) do
		table.insert(openings, { r.z - r.width / 2, r.z + r.width / 2, r })
	end
	table.sort(openings, function(a, b) return a[1] < b[1] end)

	for _, sx in ipairs({ -1, 1 }) do
		local cursor = zS - 2
		local function seg(a, b)
			local len = b - a
			if len > 0.5 then
				local zm = (a + b) / 2
				local zone = MapConfig.ZoneAt(zm)
				local col = (zone == "plaza") and C(140, 146, 160) or MapConfig.Zones[zone].palette.curb
				-- brick wall with stone piers, a light cap, a district-coloured band and a hedge strip in front
				local BRICK, STONE = C(158, 78, 60), C(214, 206, 192)
				Part(f.Buildings, "PerimeterWall", Vector3.new(4, 24, len), CFrame.new(sx * (HW + 2), 12, zm), BRICK, M.Brick)
				Part(f.Buildings, "WallCap", Vector3.new(4.8, 1, len), CFrame.new(sx * (HW + 2), 24.5, zm), STONE, M.Slate, { collide = false })
				Part(f.Buildings, "WallBand", Vector3.new(4.4, 1.4, len), CFrame.new(sx * (HW + 2), 5, zm), col, M.SmoothPlastic, { collide = false })
				Part(f.Buildings, "WallPlinth", Vector3.new(4.6, 1.6, len), CFrame.new(sx * (HW + 2), 0.8, zm), STONE, M.Slate, { collide = false })
				local n = math.max(1, math.floor(len / 24))
				for k = 0, n do
					local pz = a + k * len / n
					Part(f.Buildings, "WallPier", Vector3.new(6, 26, 6), CFrame.new(sx * (HW + 2), 13, pz), STONE, M.Slate)
					Part(f.Buildings, "PierCap", Vector3.new(7, 1.2, 7), CFrame.new(sx * (HW + 2), 26.6, pz), C(232, 226, 214), M.Slate, { collide = false })
				end
				if len > 10 then
					Part(f.Buildings, "Hedge", Vector3.new(3, 3.2, len - 8), CFrame.new(sx * (HW - 2.5), 1.6, zm), C(72, 140, 70), M.Grass)
				end
			end
		end
		for _, o in ipairs(openings) do
			seg(cursor, o[1])
			cursor = o[2]
			local W = o[3].width
			local z0 = o[3].z
			local zone = MapConfig.Zones[o[3].zone]
			Part(f.Buildings, "TunnelLintel", Vector3.new(4, 16, W), CFrame.new(sx * (HW + 2), 18, z0), zone.palette.curb, M.Concrete)
			for k = 0, 7 do
				Part(f.Buildings, "TunnelHazard", Vector3.new(4.5, 0.9, W / 8), CFrame.new(sx * (HW + 2), 10.4, z0 - W / 2 + (k + 0.5) * W / 8), (k % 2 == 0) and C(255, 196, 40) or C(28, 28, 30), M.SmoothPlastic, { collide = false })
			end
			Part(f.Buildings, "TunnelCeiling", Vector3.new(TL, 2, W + 8), CFrame.new(sx * (HW + 2 + TL / 2), 11, z0), C(22, 22, 28), M.Concrete)
			Part(f.Buildings, "TunnelWallA", Vector3.new(TL, 12, 2), CFrame.new(sx * (HW + 2 + TL / 2), 6, z0 + W / 2 + 1), C(22, 22, 28), M.Concrete)
			Part(f.Buildings, "TunnelWallB", Vector3.new(TL, 12, 2), CFrame.new(sx * (HW + 2 + TL / 2), 6, z0 - W / 2 - 1), C(22, 22, 28), M.Concrete)
			Part(f.Buildings, "TunnelBlocker", Vector3.new(2, 16, W), CFrame.new(sx * (HW - 1), 8, z0), C(255, 255, 255), M.SmoothPlastic, { t = 1, cast = false })
		end
		seg(cursor, zE + 2)

		local z = zS
		while z < zE do
			local zone = MapConfig.ZoneAt(z)
			local pal = (zone == "plaza") and { buildings = { C(120, 130, 150), C(150, 160, 180) }, accent = C(80, 200, 255) } or MapConfig.Zones[zone].palette
			local w, d, h = rr(ctx.rng, 24, 44), rr(ctx.rng, 24, 40), rr(ctx.rng, 40, 100)
			local cx = sx * (HW + 92 + rr(ctx.rng, 0, 40))
			local tower = Part(f.Buildings, "Backdrop", Vector3.new(d, h, w), CFrame.new(cx, h / 2 - 1, z), pick(ctx.rng, pal.buildings), M.SmoothPlastic, { cast = false })
			for y = 8, h - 6, 7 do
				Part(f.Buildings, "BackdropWindows", Vector3.new(d + 0.2, 2.6, w * 0.8), CFrame.new(cx, y, z), C(70, 96, 120), M.Glass, { cast = false, collide = false, t = 0.1 })
			end
			z = z + 58 + rr(ctx.rng, 0, 14)
		end
	end
	local crng = ctx.rng
	for _ = 1, math.floor(44 * MapConfig.DecorationDensity + 10) do
		Prefabs.Cloud(f.StreetProps, Vector3.new(rr(crng, -520, 520), rr(crng, 150, 230), rr(crng, zS - 200, zE + 200)), crng)
	end
	for _, ez in ipairs({ zS - 2, zE + 2 }) do
		Part(f.Buildings, "EndWall", Vector3.new(2 * HW + 8, 24, 4), CFrame.new(0, 12, ez), C(158, 78, 60), M.Brick)
		Part(f.Buildings, "EndWallCap", Vector3.new(2 * HW + 8, 1, 4.8), CFrame.new(0, 24.5, ez), C(214, 206, 192), M.Slate, { collide = false })
		for x = -HW, HW, 24 do
			Part(f.Buildings, "WallPier", Vector3.new(6, 26, 6), CFrame.new(x, 13, ez), C(214, 206, 192), M.Slate)
			Part(f.Buildings, "PierCap", Vector3.new(7, 1.2, 7), CFrame.new(x, 26.6, ez), C(232, 226, 214), M.Slate, { collide = false })
		end
	end
	local fin = Part(f.Buildings, "EndSign", Vector3.new(120, 14, 1), CFrame.new(0, 19, zE - 0.5), C(26, 30, 38), M.SmoothPlastic)
	Label(fin, Enum.NormalId.Front, "END OF THE CITY", C(255, 210, 60))
end

-- Garage v2: clean showroom. Ground floor is static; floors 2-4 are added by BaseService (GarageFloors).
-- Rule against texture flicker: no two visible faces share a plane; overlays sit >= 0.02 above what they cover.
local function buildBase(ctx, i)
	local f = ctx.f
	local bcf = BaseLayout.GetBaseCFrame(i)
	local model = Instance.new("Model")
	model.Name = string.format("Base%02d", i)
	model:SetAttribute("Index", i)
	local function mk(name, size, off, color, mat, o)
		return Part(model, name, size, bcf * CFrame.new(off), color, mat, o)
	end
	local G = GarageStyle
	local PX, PZ = MapConfig.BasePlot.x / 2, MapConfig.BasePlot.z / 2
	local EDGE = BaseLayout.DeckEdgeX
	local deckW = EDGE + PX -- deck depth along X
	local deckCX = (EDGE - PX) / 2
	local H = BaseLayout.FloorHeight

	-- floor: polished slab + darker showroom inlay under the deck
	mk("Floor", Vector3.new(PX * 2, 1, PZ * 2), Vector3.new(0, 0, 0), G.floor, M.SmoothPlastic, { refl = 0.04 })
	mk("Inlay", Vector3.new(deckW, 0.1, PZ * 2), Vector3.new(deckCX, 0.55, 0), G.inlay, M.SmoothPlastic)
	mk("DriveLine", Vector3.new(0.4, 0.06, PZ * 2 - 6), Vector3.new(BaseLayout.LaneX, 0.53, 0), G.line, M.SmoothPlastic, { collide = false, cast = false })

	local slots = Instance.new("Folder")
	slots.Name = "Slots"
	slots.Parent = model
	for n = 1, BaseLayout.SlotsPerFloor do
		GarageBay(slots, model, bcf, n, 0.6)
	end

	-- shell: charcoal back wall, side fins, white roof deck with black fascia (owner sign lives on it)
	-- walls stop under the roof slab so no faces are shared with it
	mk("BackWall", Vector3.new(2, H - 1, PZ * 2), Vector3.new(-PX + 1, H / 2, 0), G.wall, M.SmoothPlastic)
	for _, s in ipairs({ -1, 1 }) do
		mk("SideFin", Vector3.new(deckW - 2, H - 1, 0.8), Vector3.new(deckCX + 1, H / 2, s * (PZ - 0.6)), G.wall, M.SmoothPlastic)
	end
	mk("Roof", Vector3.new(deckW, 1, PZ * 2), Vector3.new(deckCX, H, 0), G.deck, M.SmoothPlastic)
	local fascia = mk("OwnerSign", Vector3.new(1.2, 2.4, PZ * 2 + 0.4), Vector3.new(EDGE + 0.4, H + 0.2, 0), G.frame, M.SmoothPlastic)
	Label(fascia, Enum.NormalId.Right, "FREE GARAGE", C(255, 255, 255))
	local screen = mk("IncomeScreen", Vector3.new(0.4, 2, 24), Vector3.new(EDGE + 1.2, H - 2.3, 0), G.frame, M.SmoothPlastic)
	Label(screen, Enum.NormalId.Right, "", C(110, 230, 140))
	for _, z in ipairs({ -PZ + 1, -15.5, 15.5, PZ - 1 }) do
		mk("Column", Vector3.new(1.2, H - 1, 1.2), Vector3.new(EDGE - 0.8, H / 2, z), G.frame, M.Metal)
	end
	for _, z in ipairs({ -30, 0, 30 }) do
		local lamp = mk("CeilingLight", Vector3.new(12, 0.12, 1.6), Vector3.new(-31, H - 0.6, z), C(255, 244, 222), M.Neon, { collide = false, cast = false, light = true })
		local sl = Instance.new("SurfaceLight")
		sl.Face = Enum.NormalId.Bottom
		sl.Range = 18
		sl.Brightness = 1.1
		sl.Angle = 100
		sl.Color = C(255, 238, 210)
		sl.Parent = lamp
	end

	-- lift shaft (ground stage) to the upper floors
	local el = BaseLayout.ElevatorLocal
	mk("ElevatorPad", Vector3.new(8, 0.4, 8), Vector3.new(el.X, 0.7, el.Z), G.frame, M.Metal)
	mk("ElevatorStripe", Vector3.new(7, 0.06, 0.4), Vector3.new(el.X, 0.95, el.Z - 3.4), G.accent, M.SmoothPlastic, { collide = false, cast = false })
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			mk("ElevatorPost", Vector3.new(0.6, H, 0.6), Vector3.new(el.X + sx * 4.3, H / 2 + 0.5, el.Z + sz * 4.3), G.frame, M.Metal)
		end
	end

	-- the trap: a clean steel car lift with a magnetic crane
	local t = BaseLayout.TrapLocal
	mk("TrapPad", Vector3.new(18, 0.8, 18), Vector3.new(t.X, 0.9, t.Z), C(74, 78, 86), M.Metal)
	for _, s in ipairs({ -1, 1 }) do
		mk("TrapEdge", Vector3.new(17, 0.06, 0.5), Vector3.new(t.X, 1.36, t.Z + s * 8.4), G.accent, M.SmoothPlastic, { collide = false, cast = false })
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			mk("LiftPost", Vector3.new(1.2, 13, 1.2), Vector3.new(t.X + sx * 9.6, 7, t.Z + sz * 9.6), G.accent2, M.Metal)
		end
		mk("LiftBeam", Vector3.new(1, 1, 20.4), Vector3.new(t.X + sx * 9.6, 14, t.Z), G.accent2, M.Metal)
	end
	mk("CraneBeam", Vector3.new(20.4, 1.2, 1.2), Vector3.new(t.X, 14.2, t.Z), G.frame, M.Metal)
	mk("CraneCable", Vector3.new(0.2, 3.4, 0.2), Vector3.new(t.X, 12, t.Z), G.frame, M.Metal, { collide = false })
	local magnet = mk("TrapMagnet", Vector3.new(1.2, 6, 6), Vector3.new(t.X, 9.8, t.Z), C(64, 68, 76), M.Metal, { shape = CYL, collide = false })
	magnet.CFrame = bcf * CFrame.new(t.X, 9.8, t.Z) * UPRIGHT
	local trapSign = mk("TrapSign", Vector3.new(0.4, 2, 12), Vector3.new(t.X + 10.4, 12, t.Z), G.frame, M.SmoothPlastic)
	Label(trapSign, Enum.NormalId.Right, "THROW PARTS HERE", G.accent)

	-- car entrance: Blender arch gate + clear sign; the roller door opens when your new car drives in
	local pl = BaseLayout.PortalLocal
	local gate = Prefabs.FromTemplate("PortalGate", model, bcf * CFrame.new(pl.X, 0.5, pl.Z))
	if not gate then
		for _, s in ipairs({ -1, 1 }) do
			mk("PortalPost", Vector3.new(1.6, 12, 1.6), Vector3.new(pl.X, 6.5, pl.Z + s * 9.4), G.frame, M.Metal)
		end
		mk("PortalHeader", Vector3.new(2, 2.4, 20.4), Vector3.new(pl.X, 13.6, pl.Z), G.frame, M.Metal)
	end
	local sign = mk("PortalSign", Vector3.new(0.6, 3.2, 17), Vector3.new(pl.X + 0.6, gate and 18.2 or 16.4, pl.Z), C(20, 24, 34), M.SmoothPlastic)
	Label(sign, Enum.NormalId.Right, "NEW CARS DRIVE IN HERE", C(255, 210, 63))
	Label(sign, Enum.NormalId.Left, "NEW CARS DRIVE IN HERE", C(255, 210, 63))
	mk("PortalDoor", Vector3.new(0.4, 11.4, 17.2), Vector3.new(pl.X - 0.4, 6.4, pl.Z), G.door, M.SmoothPlastic, { collide = false })

	-- privacy: invisible walls around the plot; each client makes them solid only for OTHER players' garages
	for _, w in ipairs({
		{ Vector3.new(1, 30, PZ * 2), Vector3.new(PX + 0.5, 15, 0) }, { Vector3.new(1, 30, PZ * 2), Vector3.new(-PX - 0.5, 15, 0) },
		{ Vector3.new(PX * 2, 30, 1), Vector3.new(0, 15, PZ + 0.5) }, { Vector3.new(PX * 2, 30, 1), Vector3.new(0, 15, -PZ - 0.5) },
	}) do
		local pw = mk("PrivacyWall", w[1], w[2], C(255, 255, 255), M.SmoothPlastic, { t = 1, collide = false, cast = false })
		pw.CanQuery = false
		pw:SetAttribute("BaseIndex", i)
	end

	-- garage terminal (menu)
	local tm = BaseLayout.TerminalLocal
	mk("Terminal", Vector3.new(2.4, 4, 4), Vector3.new(tm.X, 2.5, tm.Z), G.frame, M.SmoothPlastic)
	local scr = mk("TerminalScreen", Vector3.new(0.3, 2.4, 3.6), Vector3.new(tm.X + 1.36, 3.4, tm.Z), C(16, 18, 22), M.SmoothPlastic)
	Label(scr, Enum.NormalId.Right, "GARAGE", G.accent)

	local sp = Instance.new("SpawnLocation")
	sp.Name = "Spawn"
	sp.Size = Vector3.new(8, 0.4, 8)
	sp.CFrame = bcf * CFrame.new(BaseLayout.SpawnLocal.X, 0.6, BaseLayout.SpawnLocal.Z)
	sp.Anchored = true
	sp.Neutral = true
	sp.Duration = 0
	sp.Transparency = 1
	sp.CanCollide = false
	sp.Parent = model
	Prefabs.Count = Prefabs.Count + 1

	local cars = Instance.new("Folder")
	cars.Name = "Cars"
	cars.Parent = model
	local floors = Instance.new("Folder")
	floors.Name = "Floors"
	floors.Parent = model
	Prefabs.Lamp(model, bcf:PointToWorldSpace(Vector3.new(PX - 1.5, 0.5, PZ - 3)), 1, C(255, 230, 180), math.pi)
	Prefabs.Lamp(model, bcf:PointToWorldSpace(Vector3.new(PX - 1.5, 0.5, -PZ + 3)), 1, C(255, 230, 180), math.pi)
	model.Parent = f.Bases
end

local function nearBaseRow(z, pad)
	for i = 1, #MapConfig.BaseCenters, 2 do
		if math.abs(z - MapConfig.BaseCenters[i].z) < pad then
			return true
		end
	end
	return false
end

-- Pit Stop: upgrade shop with a mechanic NPC (NPC itself is spawned by ShopService at runtime)
local function buildShop(ctx)
	local f = ctx.f
	local cfg = MapConfig.Shop
	local cf = CFrame.new(cfg.x, 0.2, cfg.z) * CFrame.Angles(0, cfg.yaw, 0) -- local -Z = front
	local m = Instance.new("Model")
	m.Name = "PitStopShop"
	local function mk(name, size, off, color, mat, o)
		return Part(m, name, size, cf * CFrame.new(off), color, mat, o)
	end
	-- compact kiosk 12 x 8: walls never share a visible plane, the roof caps them
	local W, D, H = 12, 8, 8.5
	local G = 0.5 -- top of the slab
	local RED, WHITE, DARK2, WOOD = C(214, 52, 44), C(246, 244, 238), C(36, 40, 48), C(150, 104, 62)
	mk("Slab", Vector3.new(18, 0.6, 16), Vector3.new(0, 0.2, -2), C(206, 204, 198), M.SmoothPlastic)
	mk("BackWall", Vector3.new(W, H, 0.6), Vector3.new(0, G + H / 2, D / 2 - 0.3), WHITE)
	for _, sx in ipairs({ -1, 1 }) do
		mk("SideWall", Vector3.new(0.6, H, D - 0.6), Vector3.new(sx * (W / 2 - 0.3), G + H / 2, -0.3), WHITE)
		mk("Corner", Vector3.new(0.8, H + 0.4, 0.8), Vector3.new(sx * (W / 2 - 0.2), G + (H + 0.4) / 2, -D / 2 + 0.2), RED)
	end
	mk("Counter", Vector3.new(W - 1.6, 3.6, 1.1), Vector3.new(0, G + 1.8, -D / 2 + 0.75), RED)
	mk("CounterTop", Vector3.new(W - 1.2, 0.3, 1.8), Vector3.new(0, G + 3.75, -D / 2 + 0.7), WOOD, M.Wood)
	mk("Header", Vector3.new(W - 1.6, 1.6, 0.5), Vector3.new(0, G + H - 0.8, -D / 2 + 0.45), DARK2)
	mk("Roof", Vector3.new(W + 1.6, 0.6, D + 2), Vector3.new(0, G + H + 0.3, -0.6), DARK2)
	mk("RoofTrim", Vector3.new(W + 1.8, 0.3, 0.3), Vector3.new(0, G + H + 0.15, -D / 2 - 1.75), C(255, 196, 40))
	-- red/white awning over the counter
	for k = 0, 5 do
		Part(m, "Awning", Vector3.new(W / 6, 0.25, 3.2), cf * CFrame.new(-W / 2 + (k + 0.5) * W / 6, G + H - 1.9, -D / 2 - 1.3) * CFrame.Angles(math.rad(-18), 0, 0),
			(k % 2 == 0) and RED or WHITE, M.SmoothPlastic, { collide = false })
	end
	-- sign on the roof
	local sign = mk("ShopSign", Vector3.new(W - 1, 2.6, 0.5), Vector3.new(0, G + H + 1.9, -D / 2 + 0.6), DARK2)
	Label(sign, Enum.NormalId.Front, "PIT STOP", C(255, 210, 63))
	-- back shelves with parts for sale
	for k, y in ipairs({ 3.2, 5.6 }) do
		mk("Shelf", Vector3.new(W - 2.4, 0.25, 1.2), Vector3.new(0, G + y, D / 2 - 1.2), WOOD, M.Wood)
		for i = 0, 3 do
			local x = -W / 2 + 2.2 + i * 2.5
			if (i + k) % 2 == 0 then
				Part(m, "ShelfTire", Vector3.new(0.7, 1.5, 1.5), cf * CFrame.new(x, G + y + 0.88, D / 2 - 1.2) * CFrame.Angles(0, math.pi / 2, 0), C(34, 34, 38), M.SmoothPlastic, { shape = CYL, collide = false })
			else
				mk("OilCan", Vector3.new(0.8, 1.2, 0.6), Vector3.new(x, G + y + 0.73, D / 2 - 1.2), ({ C(255, 196, 40), C(40, 120, 200), C(50, 160, 80), RED })[i + 1], M.SmoothPlastic, { collide = false })
			end
		end
	end
	-- warm light inside
	local bulb = mk("KioskLight", Vector3.new(0.4, 0.4, 0.4), Vector3.new(0, G + H - 0.6, 0.5), C(255, 240, 210), M.SmoothPlastic, { collide = false, t = 1 })
	local l = Instance.new("PointLight")
	l.Range = 14
	l.Brightness = 1.3
	l.Color = C(255, 230, 190)
	l.Parent = bulb
	Prefabs.TireStack(m, cf:PointToWorldSpace(Vector3.new(-W / 2 - 1.6, G, -2)), ctx.rng)
	local npcSpot = mk("NpcSpot", Vector3.new(2, 0.2, 2), Vector3.new(0, G + 0.1, 0.4), WHITE, M.SmoothPlastic, { t = 1, collide = false })
	npcSpot:SetAttribute("Yaw", cfg.yaw)
	local prompt = mk("ShopPrompt", Vector3.new(6, 6, 2), Vector3.new(0, 3.5, -D / 2 - 2.4), WHITE, M.SmoothPlastic, { t = 1, collide = false })
	CollectionService:AddTag(prompt, "ShopPrompt")
	m.Parent = f.Buildings
end

-- Golden Magnate donation stall (the animated NPC is spawned by DonateService)
local function buildDonateStall(ctx)
	local f = ctx.f
	local cfg = MapConfig.DonateStall
	local cf = CFrame.new(cfg.x, 0.2, cfg.z) * CFrame.Angles(0, cfg.yaw, 0)
	local m = Instance.new("Model")
	m.Name = "MagnateStall"
	local function mk(name, size, off, color, mat, o)
		return Part(m, name, size, cf * CFrame.new(off), color, mat, o)
	end
	local GOLD, DEEP, CREAM, WOOD = C(232, 178, 50), C(28, 32, 44), C(250, 240, 214), C(110, 70, 40)
	mk("Rug", Vector3.new(18, 0.12, 14), Vector3.new(0, 0.15, -2), C(150, 30, 40), M.Fabric, { collide = false })
	mk("Counter", Vector3.new(14, 4, 3.4), Vector3.new(0, 2.2, -4), WOOD, M.Wood)
	mk("CounterTop", Vector3.new(14.6, 0.5, 4), Vector3.new(0, 4.4, -4), GOLD, M.Metal, { refl = 0.25 })
	mk("BackPanel", Vector3.new(14, 11, 1), Vector3.new(0, 5.7, 4), DEEP, M.SmoothPlastic)
	for _, s in ipairs({ -1, 1 }) do
		mk("Pillar", Vector3.new(1.2, 13, 1.2), Vector3.new(s * 7.4, 6.5, 4), GOLD, M.Metal, { refl = 0.2 })
		mk("PillarFront", Vector3.new(1, 11, 1), Vector3.new(s * 7.4, 5.5, -5.6), GOLD, M.Metal, { refl = 0.2 })
	end
	for k = 0, 6 do
		local c = (k % 2 == 0) and GOLD or CREAM
		Part(m, "Canopy", Vector3.new(16 / 7, 0.4, 11), cf * CFrame.new(-8 + (k + 0.5) * 16 / 7, 12.2, -0.8) * CFrame.Angles(math.rad(-10), 0, 0), c, M.SmoothPlastic, { collide = false })
	end
	local sign = mk("StallSign", Vector3.new(13, 3, 0.5), Vector3.new(0, 14.4, 4), DEEP, M.SmoothPlastic)
	Label(sign, Enum.NormalId.Front, "GOLDEN MAGNATE", GOLD)
	-- treasure: coin piles and gold bars
	for k = 0, 4 do
		local c = mk("Coins", Vector3.new(0.6, 1.4, 1.4), Vector3.new(-5 + k * 2.4, 5, -4), GOLD, M.Metal, { shape = CYL, refl = 0.3, collide = false })
		c.CFrame = cf * CFrame.new(-5 + k * 2.4, 4.95 + (k % 2) * 0.3, -4) * UPRIGHT
	end
	for k = 0, 2 do
		mk("GoldBar", Vector3.new(2, 0.7, 1), Vector3.new(-1.5 + k * 1.5, 1.2 + (k == 1 and 0.7 or 0), 1.5), GOLD, M.Metal, { refl = 0.35 })
	end
	local spot = mk("NpcSpot", Vector3.new(2, 0.2, 2), Vector3.new(0, 0.5, 1.6), CREAM, M.SmoothPlastic, { t = 1, collide = false })
	spot:SetAttribute("Yaw", cfg.yaw)
	local prompt = mk("DonatePrompt", Vector3.new(6, 6, 2), Vector3.new(0, 3.5, -7), CREAM, M.SmoothPlastic, { t = 1, collide = false })
	CollectionService:AddTag(prompt, "DonatePrompt")
	local glow = mk("StallLight", Vector3.new(0.6, 0.6, 0.6), Vector3.new(0, 11.4, -3), C(255, 220, 150), M.Neon, { light = true, collide = false })
	local l = Instance.new("PointLight")
	l.Range = 18
	l.Brightness = 1.6
	l.Color = C(255, 210, 120)
	l.Parent = glow
	m.Parent = f.Buildings
end


local function buildPlaza(ctx)
	local f = ctx.f
	local P = MapConfig.Plaza
	local PW = MapConfig.PromenadeHalfWidth
	local zS, zE = MapConfig.StartZ, MapConfig.EntryZ
	local len = zE - zS
	local zm = (zS + zE) / 2
	Part(f.Ground, "PlazaGround", Vector3.new(2 * HW, 2, len), CFrame.new(0, -1, zm), P.ground, M.Grass)
	-- paving: one level of 12x12 slabs in two tones (no thin overlays -> no flicker)
	local pz0, pz1 = zS + 2, zE - 4
	local nx = math.floor(2 * PW / 12)
	local sx = 2 * PW / nx
	local nz = math.floor((pz1 - pz0) / 12)
	local sz = (pz1 - pz0) / nz
	local T1, T2 = P.paving, P.paving:Lerp(C(150, 140, 126), 0.18)
	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			local edge = i == 0 or i == nx - 1
			local col = edge and C(120, 118, 114) or (((i + j) % 2 == 0) and T1 or T2)
			Part(f.Ground, "Paving", Vector3.new(sx, 0.4, sz), CFrame.new(-PW + (i + 0.5) * sx, 0, pz0 + (j + 0.5) * sz), col, M.SmoothPlastic, { cast = false })
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		Part(f.Ground, "Curb", Vector3.new(1.2, 0.6, len - 6), CFrame.new(s * PW, 0.3, zm - 1), C(150, 150, 146), M.Concrete)
	end

	for i = 1, MapConfig.BaseCount do
		buildBase(ctx, i)
	end
	buildShop(ctx)
	buildDonateStall(ctx)

	-- entry: Blender finish arch (truss towers, checkered banner, start lights) with a lit sign
	local function tpl(name, cf, fallback)
		local m = Prefabs.FromTemplate(name, f.Buildings, cf)
		if not m and fallback then
			fallback()
		end
		return m
	end
	tpl("FinishArch", CFrame.new(0, 0.2, zE - 4) * CFrame.Angles(0, math.pi, 0), function()
		for _, s in ipairs({ -1, 1 }) do
			Part(f.Buildings, "ArchPillar", Vector3.new(3, 24, 3), CFrame.new(s * 40, 12, zE - 4), C(52, 56, 64), M.Metal)
		end
		Part(f.Buildings, "ArchBeam", Vector3.new(83, 3, 3), CFrame.new(0, 24, zE - 4), C(26, 30, 38), M.SmoothPlastic)
		Prefabs.Checker(f.Buildings, CFrame.new(0, 20.4, zE - 4), 80, 2.4, 2.8)
	end)
	local archSign = Part(f.Buildings, "ArchSign", Vector3.new(40, 4.4, 0.8), CFrame.new(0, 29.6, zE - 4), C(20, 24, 34), M.SmoothPlastic)
	Label(archSign, Enum.NormalId.Back, "CAR HUNTERS", C(255, 210, 63))
	Label(archSign, Enum.NormalId.Front, "SAFE ZONE", C(255, 255, 255))
	for _, s in ipairs({ -1, 1 }) do
		Part(f.Buildings, "ArchSignPost", Vector3.new(0.6, 3, 0.6), CFrame.new(s * 16, 26.4, zE - 4), C(40, 44, 52), M.Metal)
	end

	-- leaderboard: Blender frame + podium (screen and statues are filled by LeaderboardService)
	local lb = MapConfig.Leaderboard
	local lbcf = CFrame.new(lb.x, 0.2, lb.z) * CFrame.Angles(0, math.pi, 0) -- screen faces the incoming players (-Z)
	local lbModel = Instance.new("Model")
	lbModel.Name = "LeaderboardStand"
	if not Prefabs.FromTemplate("LeaderboardFrame", lbModel, lbcf) then
		for _, s in ipairs({ -1, 1 }) do
			Part(lbModel, "LBPost", Vector3.new(1, 14, 1), lbcf * CFrame.new(s * 10, 7, 0), C(52, 56, 64), M.Metal)
		end
		for i, step in ipairs({ { -6, 3, C(220, 222, 226) }, { 0, 4.5, C(232, 178, 50) }, { 6, 2, C(196, 120, 70) } }) do
			Part(lbModel, "PodiumStep" .. i, Vector3.new(5.6, step[2], 5), lbcf * CFrame.new(step[1], step[2] / 2, 6), step[3], M.SmoothPlastic)
		end
	end
	-- screen: plain part so the SurfaceGui renders crisply (sits just in front of the frame)
	local screen = Part(lbModel, "LeaderboardScreen", Vector3.new(24, 14, 0.2), lbcf * CFrame.new(0, 16, 0.75), C(12, 14, 20), M.SmoothPlastic)
	screen:SetAttribute("Facing", "Back")
	CollectionService:AddTag(screen, "LeaderboardScreen")
	for i, x in ipairs({ 0, -6, 6 }) do -- 1st, 2nd, 3rd statue spots on the podium
		local h = ({ 4.5, 3, 2 })[i]
		local spot = Part(lbModel, "StatueSpot" .. i, Vector3.new(2, 0.2, 2), lbcf * CFrame.new(x, h + 0.1, 6), C(255, 255, 255), M.SmoothPlastic, { t = 1, collide = false })
		spot:SetAttribute("Rank", i)
		spot:SetAttribute("Yaw", math.pi)
	end
	lbModel.Parent = f.StreetProps
	table.insert(ctx.foot, { x1 = lb.x - 14, x2 = lb.x + 14, z1 = lb.z - 10, z2 = lb.z + 2 })

	-- contracts stand: lit board with three job cards + Big Tony's spot (NPC spawned by MechanicService)
	local cb = MapConfig.ContractBoard
	local st = Instance.new("Model")
	st.Name = "ContractStand"
	local bcf = CFrame.new(cb.x, 0.4, cb.z) -- front faces -Z
	local function sp(name, size, off, color, mat, o)
		return Part(st, name, size, bcf * CFrame.new(off), color, mat, o)
	end
	local STEEL, WOODD, CREAM2, ORANGE = C(40, 44, 52), C(96, 62, 36), C(250, 240, 214), C(240, 120, 30)
	sp("StandBase", Vector3.new(30, 0.5, 9), Vector3.new(-4, 0.25, 0.5), C(196, 194, 188), M.SmoothPlastic)
	for _, x in ipairs({ -11, 11 }) do
		sp("StandPost", Vector3.new(1.2, 13.5, 1.2), Vector3.new(x, 0.5 + 6.75, 1), STEEL, M.Metal)
	end
	local panel = sp("ContractBoard", Vector3.new(21, 9.5, 0.8), Vector3.new(0, 7.3, 1), WOODD, M.Wood)
	CollectionService:AddTag(panel, "ContractBoard")
	local head = sp("BoardHeader", Vector3.new(24, 2.6, 1.4), Vector3.new(0, 13.4, 1), ORANGE, M.SmoothPlastic)
	Label(head, Enum.NormalId.Front, "CONTRACTS", C(255, 255, 255))
	sp("HeaderTrim", Vector3.new(24.4, 0.35, 1.6), Vector3.new(0, 12, 1), STEEL, M.Metal)
	for i, x in ipairs({ -6.8, 0, 6.8 }) do
		local card = sp("ContractCard" .. i, Vector3.new(6, 7.4, 0.2), Vector3.new(x, 7.1, 0.45), CREAM2, M.SmoothPlastic)
		card:SetAttribute("Index", i)
		CollectionService:AddTag(card, "ContractCard")
		sp("CardPin", Vector3.new(0.35, 0.5, 0.5), Vector3.new(x, 10.5, 0.2), C(214, 52, 44), M.SmoothPlastic, { shape = CYL, collide = false })
	end
	-- two arm lamps light the cards
	for _, x in ipairs({ -6, 6 }) do
		sp("LampArm", Vector3.new(0.3, 0.3, 2.6), Vector3.new(x, 12, -0.6), STEEL, M.Metal, { collide = false })
		local shade = sp("LampShade", Vector3.new(1.4, 0.6, 1), Vector3.new(x, 11.7, -1.9), STEEL, M.Metal, { collide = false })
		local sl = Instance.new("SpotLight")
		sl.Face = Enum.NormalId.Bottom
		sl.Angle = 80
		sl.Range = 14
		sl.Brightness = 2.2
		sl.Color = C(255, 236, 200)
		sl.Parent = shade
	end
	-- Big Tony's corner: gold-trimmed tool chest and a chrome car jack
	local TX, TZ = -15, -1
	sp("ToolChest", Vector3.new(3, 4, 2), Vector3.new(TX - 2.8, 0.5 + 2, TZ + 3), C(200, 30, 36), M.SmoothPlastic)
	for k = 0, 3 do
		sp("ChestHandle", Vector3.new(2, 0.15, 0.2), Vector3.new(TX - 2.8, 1.3 + k * 0.9, TZ + 1.93), C(240, 190, 60), M.Metal, { collide = false })
	end
	sp("Jack", Vector3.new(2.4, 0.5, 1), Vector3.new(TX + 2.4, 0.75, TZ + 2), C(220, 222, 228), M.Metal, { refl = 0.3 })
	local spot = sp("TonySpot", Vector3.new(2, 0.2, 2), Vector3.new(TX, 0.6, TZ), CREAM2, M.SmoothPlastic, { t = 1, collide = false })
	spot:SetAttribute("Yaw", 0)
	local tp = sp("TonyPrompt", Vector3.new(6, 6, 4), Vector3.new(TX, 3.5, TZ - 3), CREAM2, M.SmoothPlastic, { t = 1, collide = false })
	CollectionService:AddTag(tp, "TonyPrompt")
	st.Parent = f.StreetProps

	-- three themed areas along the promenade; everything stays clear of the central running lanes (|x| < 9)
	-- and of the garage connector lanes (base rows +-9)
	local function clearOfRows(z, pad)
		return not nearBaseRow(z, pad or 9)
	end
	local function lamp(x, z, yaw)
		if not Prefabs.FromTemplate("StreetLamp", f.StreetProps, CFrame.new(x, 0.2, z) * CFrame.Angles(0, yaw or 0, 0)) then
			Prefabs.Lamp(f.StreetProps, Vector3.new(x, 0.4, z), 1, C(255, 228, 180), yaw or 0)
		end
	end
	local function planter(x, z)
		if not Prefabs.FromTemplate("Planter", f.StreetProps, CFrame.new(x, 0.2, z)) then
			Prefabs.Tree(f.StreetProps, Vector3.new(x, 0.4, z), ctx.rng, "palm")
		end
	end
	local function bench(x, z, yaw)
		if not Prefabs.FromTemplate("Bench", f.StreetProps, CFrame.new(x, 0.2, z) * CFrame.Angles(0, yaw, 0)) then
			Prefabs.Bench(f.StreetProps, Vector3.new(x, 0.4, z), yaw)
		end
	end
	-- promenade edges: lamps + palms in a steady rhythm
	local toggle = false
	for z = zS + 14, zE - 30, 22 do
		if clearOfRows(z, 10) then
			toggle = not toggle
			for _, sx in ipairs({ -1, 1 }) do
				if toggle then
					lamp(sx * (PW - 5), z, sx < 0 and 0 or math.pi)
				else
					planter(sx * (PW - 6), z)
				end
			end
		end
	end

	-- 1) STREET CAR MEET (near the first garages): string lights, food truck, tuned cars, benches
	local meetZ1, meetZ2 = zS + 6, MapConfig.BaseCenters[3].z - 12
	for z = meetZ1 + 6, meetZ2, 18 do
		if clearOfRows(z) then
			for _, sx in ipairs({ -1, 1 }) do
				Prefabs.FromTemplate("StringLightPole", f.StreetProps, CFrame.new(sx * 16, 0.2, z) * CFrame.Angles(0, math.pi / 2, 0))
			end
		end
	end
	Prefabs.FromTemplate("FoodTruck", f.Buildings, CFrame.new(-42, 0.2, zS + 26) * CFrame.Angles(0, math.pi / 2, 0))
	for _, p in ipairs({ { 38, zS + 22 }, { 40, zS + 85 } }) do
		Prefabs.ParkedCar(f.StreetProps, CFrame.new(p[1], 0.35, p[2]) * CFrame.Angles(0, math.pi / 2, 0), ctx.rng, { "sport", "muscle", "supercar" })
	end
	for _, p in ipairs({ { -26, zS + 40, 0 }, { 26, zS + 41, math.pi }, { -28, zS + 100, math.pi / 2 } }) do
		bench(p[1], p[2], p[3])
	end
	local meetSign = Part(f.StreetProps, "MeetSign", Vector3.new(18, 3.2, 0.6), CFrame.new(-30, 9, MapConfig.BaseCenters[1].z + 20), C(20, 24, 34), M.SmoothPlastic)
	Label(meetSign, Enum.NormalId.Back, "CAR MEET", C(255, 160, 50))
	Label(meetSign, Enum.NormalId.Front, "CAR MEET", C(255, 160, 50))
	for _, sx in ipairs({ -1, 1 }) do
		Part(f.StreetProps, "MeetSignPost", Vector3.new(0.4, 8, 0.4), CFrame.new(-30 + sx * 8, 4, MapConfig.BaseCenters[1].z + 20), C(40, 44, 52), M.Metal)
	end

	-- 2) LUXURY SHOWROOM (middle): legendary cars on static lit stands (v10: no turntables - spinning glitched)
	local legends = CarConfig.ByRarity.Legendary
	local standZ = { MapConfig.BaseCenters[3].z - 28, MapConfig.Shop.z - 22, MapConfig.Shop.z + 23 }
	local k = 0
	for _, z in ipairs(standZ) do
		for _, x in ipairs({ -32, 32 }) do
			k = k + 1
			local def = legends[(k - 1) % #legends + 1]
			local cf = CFrame.new(x, 0.2, z)
			local standTop = 1.4
			local stand = Prefabs.FromTemplate("CarStand", f.StreetProps, cf * CFrame.Angles(0, x < 0 and math.pi / 2 or -math.pi / 2, 0))
			if typeof(stand) == "Instance" and stand:IsA("Model") then
				local bcf, bsize = stand:GetBoundingBox()
				standTop = bcf.Position.Y + bsize.Y / 2
			elseif not stand then
				-- simple plinth: one solid cylinder + rim in the same top plane (no thin overlays)
				Part(f.StreetProps, "Podium", Vector3.new(1.2, 18, 18), CFrame.new(x, 0.8, z) * UPRIGHT, C(40, 44, 52), M.Metal, { shape = CYL })
				Part(f.StreetProps, "PodiumRim", Vector3.new(1.0, 18.6, 18.6), CFrame.new(x, 0.7, z) * UPRIGHT, C(232, 178, 50), M.Metal, { shape = CYL, collide = false })
				standTop = 1.4
			end
			local car = VehicleFactory.BuildCar(def)
			-- static 3/4 pose towards the promenade centre; the whole car is anchored so nothing can drift or jitter
			car:PivotTo(CFrame.new(x, standTop + 3, z) * CFrame.Angles(0, (x < 0 and 0 or math.pi) + (k % 2 == 0 and 0.45 or -0.45), 0))
			local ccf, csize = car:GetBoundingBox()
			car:PivotTo(car:GetPivot() - Vector3.new(0, (ccf.Position.Y - csize.Y / 2) - (standTop + 0.02), 0)) -- wheels exactly on the stand
			for _, d in ipairs(car:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
				end
			end
			car.Parent = f.StreetProps
			-- spotlight from above (invisible holder, no geometry on the plinth)
			local lamp = Part(f.StreetProps, "StandLight", Vector3.new(1, 1, 1), CFrame.new(x, 14, z), C(0, 0, 0), M.SmoothPlastic, { collide = false })
			lamp.Transparency = 1
			lamp.CanQuery, lamp.CanTouch = false, false
			local spot = Instance.new("SpotLight")
			spot.Face = Enum.NormalId.Bottom
			spot.Angle = 55
			spot.Range = 18
			spot.Brightness = 2.5
			spot.Color = CarConfig.Rarities[def.rarity].color:Lerp(Color3.new(1, 1, 1), 0.6)
			spot.Parent = lamp
			-- plinth label (towards the promenade centre)
			local plate = Part(f.StreetProps, "StandPlate", Vector3.new(4, 1.2, 0.2), CFrame.new(x - math.sign(x) * 13.05, 2.4, z) * CFrame.Angles(0, math.sign(x) * math.pi / 2, 0), C(20, 24, 34), M.SmoothPlastic, { collide = false })
			Label(plate, Enum.NormalId.Front, string.upper(def.name), C(255, 210, 63))
			table.insert(ctx.foot, { x1 = x - 12, x2 = x + 12, z1 = z - 12, z2 = z + 12 })
			Prefabs.Count = Prefabs.Count + 1
		end
	end
	-- (marble inlay removed: overlays on the paving flickered)

	-- 3) RACE PADDOCK (towards the exit): trophy fountain, grandstand, tyre walls
	local pz = MapConfig.BaseCenters[7].z - 30
	if not Prefabs.FromTemplate("TrophyFountain", f.Buildings, CFrame.new(-36, 0.2, pz)) then
		Part(f.Buildings, "Fountain", Vector3.new(2, 18, 18), CFrame.new(-36, 1, pz) * UPRIGHT, C(230, 226, 218), M.Marble, { shape = CYL })
	end
	Prefabs.FromTemplate("Grandstand", f.Buildings, CFrame.new(40, 0.2, pz) * CFrame.Angles(0, -math.pi / 2, 0))
	table.insert(ctx.foot, { x1 = -46, x2 = -26, z1 = pz - 10, z2 = pz + 10 })
	table.insert(ctx.foot, { x1 = 30, x2 = 50, z1 = pz - 17, z2 = pz + 17 })
	for _, sx in ipairs({ -1, 1 }) do
		for z = MapConfig.BaseCenters[7].z + 12, zE - 12, 6 do
			Prefabs.TireStack(f.StreetProps, Vector3.new(sx * (PW - 3), 0.2, z), ctx.rng)
		end
	end
	bench(-20, pz + 16, math.pi)
	bench(20, pz - 16, 0)
end

-- Running lanes: dark asphalt strips, white separator, white arrows. One lane each way.
local function buildSpeedLanes(ctx)
	local f = ctx.f
	local LANE, WHITE = C(54, 56, 62), C(245, 245, 245)
	for _, r in ipairs(MapConfig.SpeedLanes()) do
		local w, l = r[2] - r[1], r[4] - r[3]
		local cx, cz = (r[1] + r[2]) / 2, (r[3] + r[4]) / 2
		local alongZ = r[5] == 0
		local y = (cz < MapConfig.EntryZ and math.abs(cx) < MapConfig.PromenadeHalfWidth) and 0.26 or 0.1
		local lane = Part(f.StreetProps, "RunLane", Vector3.new(w, 0.12, l), CFrame.new(cx, y, cz), LANE, M.SmoothPlastic, { collide = false, cast = false })
		CollectionService:AddTag(lane, "RunLane")
		-- white edge lines
		for _, s in ipairs({ -1, 1 }) do
			local size = alongZ and Vector3.new(0.3, 0.04, l) or Vector3.new(w, 0.04, 0.3)
			local off = alongZ and Vector3.new(s * (w / 2 - 0.25), 0, 0) or Vector3.new(0, 0, s * (l / 2 - 0.25))
			Part(f.StreetProps, "LaneLine", size, CFrame.new(cx, y + 0.08, cz) + off, WHITE, M.SmoothPlastic, { collide = false, cast = false })
		end
		-- arrows: shaft + two head strokes, every 14 studs
		local dir = Vector3.new(r[5], 0, r[6])
		local yaw = math.atan2(-dir.X, -dir.Z)
		local span = alongZ and l or w
		local n = math.max(1, math.floor(span / 14))
		for k = 0, n - 1 do
			local t = (k + 0.5) / n
			local p = alongZ and Vector3.new(cx, y + 0.08, r[3] + t * l) or Vector3.new(r[1] + t * w, y + 0.08, cz)
			local acf = CFrame.new(p) * CFrame.Angles(0, yaw, 0) -- local -Z = arrow direction
			Part(f.StreetProps, "Arrow", Vector3.new(0.7, 0.04, 4), acf * CFrame.new(0, 0, 0.6), WHITE, M.SmoothPlastic, { collide = false, cast = false })
			for _, s in ipairs({ -1, 1 }) do
				Part(f.StreetProps, "ArrowHead", Vector3.new(0.7, 0.04, 2.4), acf * CFrame.new(s * 0.75, 0, -1.6) * CFrame.Angles(0, s * math.rad(40), 0), WHITE, M.SmoothPlastic, { collide = false, cast = false })
			end
		end
	end
end

local function buildGate(ctx, gate, zone)
	local f = ctx.f
	local pal = zone.palette
	local gz = gate.z
	local gw = MapConfig.GateHalfWidth
	local len = HW - gw
	for _, s in ipairs({ -1, 1 }) do
		Part(f.ZoneGates, "Fence", Vector3.new(len, 10, 4), CFrame.new(s * (gw + len / 2), 5, gz), pal.curb, M.Metal)
		Part(f.ZoneGates, "FenceCap", Vector3.new(len, 0.6, 4.4), CFrame.new(s * (gw + len / 2), 10.3, gz), C(52, 56, 64), M.Metal, { collide = false })
		Part(f.ZoneGates, "GatePillar", Vector3.new(4, 20, 5), CFrame.new(s * (gw + 2), 10, gz), C(30, 34, 46), M.Metal)
	end
	local beam = Part(f.ZoneGates, "GateBeam", Vector3.new(2 * gw + 8, 4, 5), CFrame.new(0, 22, gz), C(20, 22, 32), M.Metal)
	Label(beam, Enum.NormalId.Front, zone.name, pal.accent)
	Label(beam, Enum.NormalId.Back, zone.name, pal.accent)
	local barrier = Part(f.ZoneGates, "GateBarrier_" .. zone.id, Vector3.new(2 * gw, 20, 1.5), CFrame.new(0, 10, gz), C(214, 52, 44), M.SmoothPlastic)
	barrier:SetAttribute("ZoneId", zone.id)
	CollectionService:AddTag(barrier, "ZoneGate")
	Label(barrier, Enum.NormalId.Front, "LOCKED", C(255, 255, 255))
	Label(barrier, Enum.NormalId.Back, "LOCKED", C(255, 255, 255))
end

local function buildEntryFence(ctx, zone)
	local f = ctx.f
	local pal = zone.palette
	local ez = MapConfig.EntryZ
	local ow = MapConfig.EntryHalfWidth
	local len = HW - ow
	for _, s in ipairs({ -1, 1 }) do
		Part(f.ZoneGates, "EntryFence", Vector3.new(len, 8, 3), CFrame.new(s * (ow + len / 2), 4, ez + 1.5), pal.curb, M.Metal)
		Part(f.ZoneGates, "EntryFenceCap", Vector3.new(len, 0.5, 3.4), CFrame.new(s * (ow + len / 2), 8.2, ez + 1.5), C(52, 56, 64), M.Metal, { collide = false })
	end
end

local buildRail, buildRiver, buildArena -- forward
local function buildRoad(ctx, road, pal, zid)
	local f = ctx.f
	if road.rail then
		return buildRail(ctx, road, pal)
	end
	zid = MapConfig.Zones[zid].style
	local W, z0, len = road.width, road.z, TrafficMath.Length
	local M_ = road.median
	local rid = road.id
	Part(f.Roads, "Road" .. rid, Vector3.new(len, 0.4, W), CFrame.new(0, 0, z0), pal.road, M.Asphalt)
	for _, s in ipairs({ -1, 1 }) do
		Part(f.Roads, "EdgeLine", Vector3.new(len, 0.05, 0.5), CFrame.new(0, 0.22, z0 + s * (W / 2 - 0.8)), WHITE, M.SmoothPlastic, { collide = false, cast = false })
		Part(f.Roads, "MedianLine", Vector3.new(len, 0.05, 0.35), CFrame.new(0, 0.22, z0 + s * (M_ / 2 + 0.5)), YELLOW, M.SmoothPlastic, { collide = false, cast = false })
		Part(f.Sidewalks, "Sidewalk", Vector3.new(2 * HW, 1.6, MapConfig.SidewalkWidth), CFrame.new(0, 0, z0 + s * (W / 2 + MapConfig.SidewalkWidth / 2)), pal.sidewalk, M.Concrete)
		if road.lanesPerSide >= 2 then
			local zl = z0 + s * (M_ / 2 + road.laneWidth)
			for x = -HW + 6, HW - 6, 14 do
				Part(f.Roads, "Dash", Vector3.new(6, 0.05, 0.4), CFrame.new(x, 0.22, zl), WHITE, M.SmoothPlastic, { collide = false, cast = false })
			end
		end
	end
	Part(f.Sidewalks, "Median", Vector3.new(2 * HW, 1.6, M_), CFrame.new(0, 0, z0), pal.curb, M.Concrete)
	local top = (zid == "neon") and C(50, 40, 90) or ((zid == "industrial") and C(130, 120, 100) or C(96, 160, 90))
	Part(f.Sidewalks, "MedianTop", Vector3.new(2 * HW - 4, 0.1, M_ - 1.4), CFrame.new(0, 0.85, z0), top, (zid == "city" or zid == "highway") and M.Grass or M.Concrete)

	for ri, lane in ipairs(TrafficMath.RoadLanes[rid]) do
		for _, x in ipairs({ -HW + 25, -75, 75, HW - 25 }) do
			for _, s in ipairs({ -1, 1 }) do
				Part(f.Roads, "Arrow", Vector3.new(3.5, 0.05, 0.5), CFrame.new(x, 0.23, lane.z + s * 0.9) * CFrame.Angles(0, math.atan2(-s * 1.8, -3 * lane.dir), 0), WHITE, M.SmoothPlastic, { collide = false, cast = false })
			end
		end
		local sx = TrafficMath.MinX * lane.dir
		local a = Part(f.TrafficRoutes, string.format("Road%02d_Lane%d_Start", rid, ri), Vector3.new(1, 1, 1), CFrame.new(sx, 1, lane.z), C(255, 255, 255), M.SmoothPlastic, { t = 1, collide = false })
		local b = Part(f.TrafficRoutes, string.format("Road%02d_Lane%d_End", rid, ri), Vector3.new(1, 1, 1), CFrame.new(-sx, 1, lane.z), C(255, 255, 255), M.SmoothPlastic, { t = 1, collide = false })
		for _, n in ipairs({ a, b }) do
			n:SetAttribute("RoadId", rid)
			n:SetAttribute("Dir", lane.dir)
			n:SetAttribute("Speed", math.floor(lane.speed * 10) / 10)
		end
	end
	for _, x in ipairs({ -HW * 0.5, 0, HW * 0.5 }) do
		for _, s in ipairs({ -1, 1 }) do
			local zs = z0 + s * (M_ / 2 + 1.6)
			while math.abs(zs - z0) < W / 2 - 1 do
				Part(f.Roads, "Zebra", Vector3.new(7, 0.06, 1.6), CFrame.new(x, 0.24, zs), WHITE, M.SmoothPlastic, { collide = false, cast = false })
				zs = zs + s * 3.2
			end
		end
	end
	local v = 1
	for x = -(HW - 30), HW - 30, 60 do
		for _, s in ipairs({ -1, 1 }) do
			Prefabs.Lamp(f.StreetProps, Vector3.new(x + s * 30, 0.8, z0 + s * (W / 2 + 1.6)), v, pal.accent, (s < 0) and (-math.pi / 2) or (math.pi / 2))
		end
		v = v % 3 + 1
	end
	for x = -(HW - 20), HW - 20, 50 do
		if ctx.rng() < MapConfig.DecorationDensity + 0.15 then
			if zid == "neon" then
				Prefabs.Lamp(f.StreetProps, Vector3.new(x, 0.8, z0), 3, pal.accent2, 0)
			elseif zid == "industrial" or zid == "highway" then
				Prefabs.Barrier(f.StreetProps, Vector3.new(x, 0.8, z0), 0, (zid == "highway") and C(190, 192, 200) or C(240, 190, 40))
			else
				Prefabs.Tree(f.StreetProps, Vector3.new(x, 0.8, z0), ctx.rng, "tree")
			end
		end
	end
	for _, x in ipairs({ -HW * 0.5, 0, HW * 0.5 }) do
		for _, s in ipairs({ -1, 1 }) do
			Prefabs.TrafficLight(f.StreetProps, Vector3.new(x + s * 6, 0.8, z0 + s * (W / 2 + 4.6)), (s < 0) and math.pi or 0)
		end
	end
	local srng = ctx.rng
	for x = -(HW - 10), HW - 10, 65 do
		for _, s in ipairs({ -1, 1 }) do
			local px = x + rr(srng, -8, 8)
			if math.abs(px) > 12 and math.abs(math.abs(px) - HW * 0.5) > 10 then
				local pz = z0 + s * (W / 2 + 4.8)
				local roll = srng()
				if zid == "city" or zid == "highway" then
					if roll < 0.4 then
						Prefabs.Hydrant(f.StreetProps, Vector3.new(px, 0.8, pz))
					elseif roll < 0.75 then
						Prefabs.Bin(f.StreetProps, Vector3.new(px, 0.8, pz), pal.accent2)
					end
				elseif zid == "industrial" then
					if roll < 0.6 then
						Prefabs.Cone(f.StreetProps, Vector3.new(px, 0.8, pz))
					end
				elseif roll < 0.5 then
					Prefabs.Bin(f.StreetProps, Vector3.new(px, 0.8, pz), pal.accent)
				end
			end
		end
	end
	if zid == "city" then
		for _, s in ipairs({ -1, 1 }) do
			Prefabs.BusStop(f.StreetProps, Vector3.new(s * (HW - 15), 0.8, z0 + s * (W / 2 + 4)), (s < 0) and math.pi or 0, pal.accent2)
		end
	elseif zid == "highway" then
		Prefabs.Gantry(f.StreetProps, -(HW - 35), z0, W, "NEXT EXIT  >>  INDUSTRIAL", pal.accent)
		Prefabs.Gantry(f.StreetProps, HW - 35, z0, W, "<<  CITY CENTER", pal.accent)
	elseif zid == "industrial" then
		for x = -(HW - 30), HW - 30, 80 do
			Prefabs.Cone(f.StreetProps, Vector3.new(x + 20, 0.8, z0 + M_ / 2 - 1.2))
			Prefabs.Cone(f.StreetProps, Vector3.new(x - 20, 0.8, z0 - M_ / 2 + 1.2))
		end
	elseif zid == "neon" then
		for x = -(HW - 30), HW - 30, 80 do
			Prefabs.Lamp(f.StreetProps, Vector3.new(x, 0.8, z0), 2, C(255, 200, 140), 0)
		end
	end
	if zid == "highway" then
		for _, s in ipairs({ -1, 1 }) do
			local x = s * 75
			Part(f.Buildings, "OverpassDeck", Vector3.new(14, 2, W + 28), CFrame.new(x, 16, z0), C(150, 154, 162), M.Concrete)
			Part(f.Buildings, "OverpassRailA", Vector3.new(0.6, 1.4, W + 28), CFrame.new(x - 6.7, 17.7, z0), C(190, 192, 198), M.Metal, { collide = false })
			Part(f.Buildings, "OverpassRailB", Vector3.new(0.6, 1.4, W + 28), CFrame.new(x + 6.7, 17.7, z0), C(190, 192, 198), M.Metal, { collide = false })
			for _, k in ipairs({ -1, 1 }) do
				Part(f.Buildings, "OverpassPillar", Vector3.new(6, 15, 6), CFrame.new(x, 7.5, z0 + k * (W / 2 + 12)), C(130, 134, 142), M.Concrete)
			end
		end
	end
end

local function placeBlock(ctx, blk, pal, zid)
	local f = ctx.f
	zid = MapConfig.Zones[zid].style
	local rng = ctx.rng
	local zA, zB = blk[1], blk[2]
	local depth = zB - zA
	local rows = {}
	local rd = math.max(0, math.min(34, (depth - 24) / 2))
	if rd >= 12 then
		rows = { { dir = 1, edge = zA }, { dir = -1, edge = zB } }
	elseif depth >= 40 then
		rd = math.min(24, depth - 20)
		rows = { { dir = 1, edge = zB, back = true } }
	end
	local arche = Prefabs.Archetypes[zid]
	for _, row in ipairs(rows) do
		for _, side in ipairs({ -1, 1 }) do
			local cursor = HW - 10
			local guard = 0
			while guard < 12 do
				guard = guard + 1
				local a = pick(rng, arche)
				local w = rr(rng, a[2], a[3])
				if cursor - w < 94 then break end
				local d = math.max(12, rd - rr(rng, 0, 3))
				local h = rr(rng, a[4], a[5])
				local cx = side * (cursor - w / 2)
				local zc, yaw
				if row.back then
					zc = row.edge - d / 2
					yaw = 0
				elseif row.dir == 1 then
					zc = row.edge + d / 2
					yaw = 0
				else
					zc = row.edge - d / 2
					yaw = math.pi
				end
				if a[1] == "billboard" then d = 8 end
				local cf = CFrame.new(cx, 0.4, zc) * CFrame.Angles(0, yaw, 0)
				local model = Instance.new("Model")
				model.Name = a[1]
				Prefabs.Building(a[1], model, cf, w, d, h, pal, rng)
				model.Parent = f.Buildings
				table.insert(ctx.foot, { x1 = cx - w / 2, x2 = cx + w / 2, z1 = zc - d / 2, z2 = zc + d / 2 })
				cursor = cursor - w - rr(rng, 4, 8)
			end
		end
	end

	local pathCol = (zid == "neon") and C(44, 36, 78) or ((zid == "industrial") and C(150, 142, 128) or pal.sidewalk)
	Part(f.Ground, "BlockPath", Vector3.new(26, 0.12, depth), CFrame.new(0, 0.06, (zA + zB) / 2), pathCol, M.Concrete, { collide = false })
	for _, s in ipairs({ -1, 1 }) do
		Part(f.Ground, "BlockPathEdge", Vector3.new(0.8, 0.16, depth), CFrame.new(s * 13.4, 0.08, (zA + zB) / 2), C(250, 246, 238), M.Concrete, { collide = false, cast = false })
	end
	if depth > 50 then
		if zid == "city" or zid == "highway" then
			for _, s in ipairs({ -1, 1 }) do
				Prefabs.FlowerBed(f.StreetProps, Vector3.new(s * 22, 0, zA + depth * 0.3), 6, 10, rng)
				Prefabs.Hedge(f.StreetProps, CFrame.new(s * 70, 0, zA + depth * 0.65) * CFrame.Angles(0, math.pi / 2, 0), 14)
				table.insert(ctx.foot, { x1 = s * 70 - 1.5, x2 = s * 70 + 1.5, z1 = zA + depth * 0.65 - 7, z2 = zA + depth * 0.65 + 7 })
				table.insert(ctx.foot, { x1 = s * 22 - 3, x2 = s * 22 + 3, z1 = zA + depth * 0.3 - 5, z2 = zA + depth * 0.3 + 5 })
			end
		elseif zid == "industrial" then
			local fx = rr(rng, 40, 70) * (rng() < 0.5 and -1 or 1)
			local fz = zA + depth * 0.5
			Prefabs.Forklift(f.StreetProps, Vector3.new(fx, 0, fz), rr(rng, 0, math.pi * 2))
			table.insert(ctx.foot, { x1 = fx - 6, x2 = fx + 6, z1 = fz - 6, z2 = fz + 6 })
			for k = 1, 3 do
				local px, pz = -fx + rr(rng, -10, 10), zA + depth * (0.25 + k * 0.15)
				Prefabs.Pallet(f.StreetProps, Vector3.new(px, 0, pz), rr(rng, 0, 1), rng)
				table.insert(ctx.foot, { x1 = px - 3, x2 = px + 3, z1 = pz - 3, z2 = pz + 3 })
			end
		end
	end
	-- car atmosphere: parked cars and tire stacks off the main path
	if depth > 38 and zid ~= "neon" then
		for _, sx in ipairs({ -1, 1 }) do
			local px, pz = sx * rr(rng, 48, 58), zA + depth * 0.5
			if not inFootprint(ctx.foot, px, pz, 6) then
				local kinds = (zid == "industrial") and { "pickup", "truck", "service" } or nil
				Prefabs.ParkedCar(f.StreetProps, CFrame.new(px, 0.15, pz) * CFrame.Angles(0, math.pi / 2 + (rng() < 0.5 and math.pi or 0), 0), rng, kinds)
				table.insert(ctx.foot, { x1 = px - 5, x2 = px + 5, z1 = pz - 10, z2 = pz + 10 })
			end
			local tx, tz = sx * rr(rng, 30, 40), zA + depth * rr(rng, 0.2, 0.8)
			if not inFootprint(ctx.foot, tx, tz, 4) then
				Prefabs.TireStack(f.StreetProps, Vector3.new(tx, 0, tz), rng)
				table.insert(ctx.foot, { x1 = tx - 3, x2 = tx + 3, z1 = tz - 3, z2 = tz + 3 })
			end
		end
	end
	local rngd = MapConfig.DecorationDensity
	local n = math.floor(depth / 14 * rngd)
	for _ = 1, n do
		local x = rr(rng, 14, 85) * (rng() < 0.5 and -1 or 1)
		local z = rr(rng, zA + 6, zB - 6)
		if zid == "neon" then
			Prefabs.Lamp(f.StreetProps, Vector3.new(x, 0.4, z), 3, C(255, 200, 140), 0)
		elseif zid == "industrial" then
			Prefabs.Barrel(f.StreetProps, Vector3.new(x, 0.4, z), pick(rng, { C(200, 70, 50), C(70, 110, 190) }))
		else
			Prefabs.Tree(f.StreetProps, Vector3.new(x, 0.4, z), rng, (zid == "highway") and "palm" or "tree")
		end
	end
	for _ = 1, math.floor(depth / 45) do
		Prefabs.Bench(f.StreetProps, Vector3.new(rr(rng, 16, 70) * (rng() < 0.5 and -1 or 1), 0.4, rr(rng, zA + 10, zB - 10)), rr(rng, 0, math.pi * 2))
	end
	if zid == "city" and depth > 60 then
		Prefabs.Kiosk(f.StreetProps, Vector3.new(rr(rng, 18, 40) * (rng() < 0.5 and -1 or 1), 0.4, (zA + zB) / 2), 0, pick(rng, pal.buildings), "SNACKS")
	end
	if zid == "neon" then
		local zc = (zA + zB) / 2
		for _, sx in ipairs({ -1, 1 }) do
			Part(f.StreetProps, "BannerPost", Vector3.new(1.2, 18, 1.2), CFrame.new(sx * 22, 9, zc), C(52, 56, 64), M.Metal)
		end
		local ban = Part(f.StreetProps, "Banner", Vector3.new(40, 4, 0.5), CFrame.new(0, 16, zc), C(30, 34, 44), M.SmoothPlastic)
		Label(ban, Enum.NormalId.Front, "NIGHT RACERS ONLY", C(255, 170, 60))
		Label(ban, Enum.NormalId.Back, "DRIVE SAFE", C(255, 255, 255))
	end
end

local function genSpawnPoints(ctx, zid, blocks, roads)
	local f = ctx.f
	local rng = ctx.rng
	local pal = MapConfig.Zones[zid].palette
	local counts = PartConfig.PointCounts[zid]
	local placed = {}
	local idc = 0
	local function addPoint(x, y, z, risk)
		idc = idc + 1
		local p = Part(f.PartSpawnPoints, string.format("SP_%s_%s_%02d", zid, risk, idc), Vector3.new(2, 0.4, 2), CFrame.new(x, y + 0.2, z), C(255, 255, 255), M.SmoothPlastic, { t = 1, collide = false })
		p:SetAttribute("ZoneId", zid)
		p:SetAttribute("Risk", risk)
		table.insert(placed, { x = x, z = z })
	end
	local function farFromOthers(x, z, minD)
		for _, p in ipairs(placed) do
			local dx, dz = p.x - x, p.z - z
			if dx * dx + dz * dz < minD * minD then return false end
		end
		return true
	end

	local xs = { -(HW - 30), -90, 90, HW - 30 }
	local rcount = 0
	for _, r in ipairs(roads) do
		for _, x in ipairs(xs) do
			if rcount < counts.risky then
				addPoint(x + rr(rng, -12, 12), MapConfig.SidewalkTopY, r.z, "risky")
				rcount = rcount + 1
			end
		end
	end

	for _, rp in ipairs(ctx.riverPoints or {}) do
		addPoint(rp.X, rp.Y, rp.Z, "risky") -- loot in the middle of the narrow side bridges
	end

	-- scrap crates right on the traffic lanes: the best loot, the worst place to stand
	for _, r in ipairs(roads) do
		local lanes = TrafficMath.RoadLanes[r.id]
		for k = 1, (counts.road or 0) / #roads do
			local lane = lanes[(k - 1) % #lanes + 1]
			addPoint(rr(rng, -(HW - 40), HW - 40), MapConfig.RoadTopY, lane.z, "road")
		end
	end

	local safe = 0
	if zid == "city" then
		for k = 1, 4 do
			addPoint(-60 + (k - 1) * 40 + rr(rng, -6, 6), 0, MapConfig.EntryZ + 18 + rr(rng, 0, 26), "safe")
			safe = safe + 1
		end
	end
	local tries = 0
	while safe < counts.safe and tries < 600 do
		tries = tries + 1
		local blk = blocks[math.floor(rng() * #blocks) + 1]
		local x = rr(rng, -(HW - 30), HW - 30)
		local z = rr(rng, blk[1] + 5, blk[2] - 5)
		if not inFootprint(ctx.foot, x, z, 5) and farFromOthers(x, z, 24) then
			addPoint(x, 0, z, "safe")
			safe = safe + 1
		end
	end
end

-- Docks: two railway tracks with a level crossing (lights blink client-side when a train comes)
buildRail = function(ctx, road, pal)
	local f = ctx.f
	local W, z0, len = road.width, road.z, TrafficMath.Length
	local GRAVEL, SLEEPER, RAIL = C(120, 112, 104), C(86, 62, 44), C(170, 174, 182)
	Part(f.Roads, "RailBed", Vector3.new(len, 0.4, W), CFrame.new(0, 0, z0), GRAVEL, M.Slate)
	for _, lane in ipairs(TrafficMath.RoadLanes[road.id]) do
		for x = -len / 2 + 2, len / 2 - 2, 4 do
			Part(f.Roads, "Sleeper", Vector3.new(1.2, 0.2, 7), CFrame.new(x, 0.3, lane.z), SLEEPER, M.Wood, { collide = false, cast = false })
		end
		for _, s in ipairs({ -1, 1 }) do
			Part(f.Roads, "Rail", Vector3.new(len, 0.3, 0.4), CFrame.new(0, 0.55, lane.z + s * 2.6), RAIL, M.Metal, { collide = false })
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		Part(f.Sidewalks, "Sidewalk", Vector3.new(2 * HW, 1.6, MapConfig.SidewalkWidth), CFrame.new(0, 0, z0 + s * (W / 2 + MapConfig.SidewalkWidth / 2)), pal.sidewalk, M.Concrete)
	end
	-- crossing planks + signals where the running lanes / paths cross
	Part(f.Roads, "CrossingPlanks", Vector3.new(28, 0.3, W), CFrame.new(0, 0.36, z0), C(150, 104, 62), M.Wood)
	for _, x in ipairs({ -HW * 0.5, 0, HW * 0.5 }) do
		for _, s in ipairs({ -1, 1 }) do
			local px, pz = x + s * 16, z0 + s * (W / 2 + 2.5)
			Part(f.StreetProps, "SignalPost", Vector3.new(0.6, 9, 0.6), CFrame.new(px, 5.3, pz), C(240, 240, 240), M.Metal)
			Part(f.StreetProps, "CrossBuck", Vector3.new(4, 0.6, 0.2), CFrame.new(px, 9.2, pz) * CFrame.Angles(0, 0, math.rad(35)), C(255, 255, 255), M.SmoothPlastic, { collide = false })
			Part(f.StreetProps, "CrossBuck", Vector3.new(4, 0.6, 0.2), CFrame.new(px, 9.2, pz) * CFrame.Angles(0, 0, math.rad(-35)), C(255, 255, 255), M.SmoothPlastic, { collide = false })
			for k, dx in ipairs({ -0.7, 0.7 }) do
				local l = Part(f.StreetProps, "CrossingLight", Vector3.new(0.8, 0.8, 0.4), CFrame.new(px + dx, 7.4, pz - s * 0.4), C(90, 20, 20), M.SmoothPlastic, { collide = false })
				l:SetAttribute("RoadId", road.id)
				l:SetAttribute("Phase", k)
				CollectionService:AddTag(l, "CrossingLight")
			end
			local arm = Part(f.StreetProps, "CrossingArm", Vector3.new(12, 0.5, 0.4), CFrame.new(px - s * 6.5, 3.4, pz), C(255, 255, 255), M.SmoothPlastic, { collide = false })
			arm:SetAttribute("RoadId", road.id)
			arm:SetAttribute("Side", s)
			CollectionService:AddTag(arm, "CrossingArm")
		end
	end
end

-- Bridge district: deep water between the roads, three bridges; falling in = wrecked
buildRiver = function(ctx, riv, pal)
	local f = ctx.f
	local len = riv.z2 - riv.z1
	local zc = (riv.z1 + riv.z2) / 2
	Part(f.Ground, "RiverBed", Vector3.new(2 * HW, 2, len), CFrame.new(0, -14, zc), C(60, 80, 90), M.Slate)
	Part(f.Ground, "RiverWater", Vector3.new(2 * HW, 6, len), CFrame.new(0, -6.2, zc), C(50, 140, 200), M.Glass, { collide = false, t = 0.25 })
	local kill = Part(f.Ground, "RiverKill", Vector3.new(2 * HW, 2, len - 2), CFrame.new(0, -7, zc), C(0, 0, 0), M.SmoothPlastic, { t = 1 })
	kill.CanCollide = false
	kill.CanTouch = true
	CollectionService:AddTag(kill, "KillZone")
	for _, s in ipairs({ -1, 1 }) do
		Part(f.Ground, "RiverBank", Vector3.new(2 * HW, 9, 2), CFrame.new(0, -4.5, zc + s * (len / 2 + 1)), C(150, 140, 126), M.Concrete)
	end
	for _, b in ipairs(riv.bridges) do
		Part(f.Roads, "BridgeDeck", Vector3.new(b.w, 1, len + 6), CFrame.new(b.x, -0.1, zc), C(150, 104, 62), M.Wood)
		for _, s in ipairs({ -1, 1 }) do
			Part(f.Roads, "BridgeRail", Vector3.new(0.4, 0.4, len + 6), CFrame.new(b.x + s * (b.w / 2 - 0.2), 3.2, zc), C(240, 240, 240), M.Metal, { collide = false })
			for z = riv.z1 - 2, riv.z2 + 2, 8 do
				Part(f.Roads, "BridgePost", Vector3.new(0.4, 3, 0.4), CFrame.new(b.x + s * (b.w / 2 - 0.2), 1.9, z), C(240, 240, 240), M.Metal, { collide = false })
			end
			Part(f.Roads, "BridgePier", Vector3.new(b.w, 14, 2), CFrame.new(b.x, -7.6, zc + s * len / 4), C(130, 130, 136), M.Concrete)
		end
	end
	table.insert(ctx.foot, { x1 = -HW, x2 = HW, z1 = riv.z1 - 4, z2 = riv.z2 + 4 })
	ctx.riverPoints = {}
	for _, b in ipairs(riv.bridges) do
		if b.x ~= 0 then
			table.insert(ctx.riverPoints, Vector3.new(b.x, 0.4, zc))
		end
	end
end

-- Boss arena: open ground with cover; the truck is driven by BossService
buildArena = function(ctx, zid)
	local f = ctx.f
	local zone = MapConfig.Zones[zid]
	local pal = zone.palette
	local rng = ctx.rng
	local zc = (zone.zMin + zone.zMax) / 2
	local center = Part(f.StreetProps, "ArenaCenter", Vector3.new(4, 1, 4), CFrame.new(0, 0.5, zc), C(255, 255, 255), M.SmoothPlastic, { t = 1, collide = false })
	center:SetAttribute("ZoneId", zid)
	center:SetAttribute("Boss", zone.boss)
	center:SetAttribute("HalfX", HW - 8)
	center:SetAttribute("HalfZ", (zone.zMax - zone.zMin) / 2 - 8)
	CollectionService:AddTag(center, "Arena")
	-- dirt track ring + start/finish ramps for show
	Part(f.Ground, "ArenaDirt", Vector3.new(2 * HW - 20, 0.1, zone.zMax - zone.zMin - 20), CFrame.new(0, 0.05, zc), pal.ground:Lerp(C(90, 70, 50), 0.35), M.Ground, { collide = false, cast = false })
	local covers = 0
	local tries = 0
	while covers < 14 and tries < 200 do
		tries = tries + 1
		local x = rr(rng, -(HW - 30), HW - 30)
		local z = rr(rng, zone.zMin + 30, zone.zMax - 30)
		if math.abs(x) > 14 and not inFootprint(ctx.foot, x, z, 10) then
			covers = covers + 1
			local w, d, h
			if zone.style == "industrial" then
				w, d, h = 20, 8, 8.6
				Part(f.Buildings, "ScrapContainer", Vector3.new(w, h, d), CFrame.new(x, h / 2, z) * CFrame.Angles(0, rng() < 0.5 and 0 or math.pi / 2, 0), pick(rng, pal.buildings), M.Metal)
			elseif zone.style == "highway" then
				w, d, h = rr(rng, 12, 20), rr(rng, 10, 16), rr(rng, 8, 16)
				Part(f.Buildings, "CanyonRock", Vector3.new(w, h, d), CFrame.new(x, h / 2 - 1, z) * CFrame.Angles(0, rng() * math.pi, 0), pick(rng, pal.buildings), M.Rock)
			else
				w, d, h = 6, 6, 18
				Part(f.Buildings, "Column", Vector3.new(h, w, w), CFrame.new(x, h / 2, z) * UPRIGHT, C(236, 226, 204), M.Marble, { shape = CYL })
				Part(f.Buildings, "ColumnCap", Vector3.new(8, 1.2, 8), CFrame.new(x, h + 0.6, z), C(220, 206, 176), M.Marble)
			end
			table.insert(ctx.foot, { x1 = x - w / 2 - 2, x2 = x + w / 2 + 2, z1 = z - w / 2 - 2, z2 = z + w / 2 + 2 })
		end
	end
	if zid == "colosseum" then
		for _, s in ipairs({ -1, 1 }) do
			for k = 0, 5 do
				Part(f.Buildings, "Stand", Vector3.new(8, 4 + k * 4, zone.zMax - zone.zMin), CFrame.new(s * (HW - 6 - k * 8), 2 + k * 2, zc), C(214 - k * 6, 196 - k * 6, 160 - k * 6), M.Concrete)
			end
		end
	end
	local banner = Part(f.StreetProps, "ArenaBanner", Vector3.new(60, 6, 1), CFrame.new(0, 26, zone.zMin + 4), C(28, 30, 38), M.SmoothPlastic, { collide = false })
	Label(banner, Enum.NormalId.Front, zone.name .. " - BOSS", pal.accent)
	Label(banner, Enum.NormalId.Back, "SURVIVE THE BOSS", pal.accent)
	-- loot: many safe-ish points + a rich centre
	local counts = PartConfig.PointCounts[zid] or { safe = 16, risky = 8 }
	local idc = 0
	local placed = 0
	tries = 0
	while placed < counts.safe + counts.risky and tries < 800 do
		tries = tries + 1
		local x = rr(rng, -(HW - 20), HW - 20)
		local z = rr(rng, zone.zMin + 18, zone.zMax - 18)
		if not inFootprint(ctx.foot, x, z, 4) then
			placed = placed + 1
			idc = idc + 1
			local risk = placed <= counts.safe and "safe" or "risky"
			local p = Part(f.PartSpawnPoints, string.format("SP_%s_%s_%02d", zid, risk, idc), Vector3.new(2, 0.4, 2), CFrame.new(x, 0.2, z), C(255, 255, 255), M.SmoothPlastic, { t = 1, collide = false })
			p:SetAttribute("ZoneId", zid)
			p:SetAttribute("Risk", risk)
			table.insert(ctx.foot, { x1 = x - 6, x2 = x + 6, z1 = z - 6, z2 = z + 6 })
		end
	end
end

local function buildZone(ctx, zid)
	local f = ctx.f
	local zone = MapConfig.Zones[zid]
	local pal = zone.palette
	local gate = MapConfig.GateOfZone(zid)
	local zStart = gate and gate.z or MapConfig.EntryZ
	local zEnd = MapConfig.EndZ
	for _, g in ipairs(MapConfig.Gates) do
		if g.z > zStart then
			zEnd = g.z
			break
		end
	end
	local sty = zone.style
	local ground = (sty == "industrial" or sty == "neon" or zone.arena) and M.Concrete or M.Grass
	if zid == "desert" or zid == "canyon" or zid == "colosseum" then
		ground = M.Sand
	end
	local riv = MapConfig.River.zone == zid and MapConfig.River or nil
	local function groundSeg(a, b)
		if b - a > 0.5 then
			Part(f.Ground, "Ground_" .. zid, Vector3.new(2 * HW, 2, b - a), CFrame.new(0, -1, (a + b) / 2), pal.ground, ground)
		end
	end
	if riv then
		groundSeg(zStart, riv.z1)
		groundSeg(riv.z2, zEnd)
	else
		groundSeg(zStart, zEnd)
	end

	if gate then
		buildGate(ctx, gate, zone)
	else
		buildEntryFence(ctx, zone)
	end
	-- checkpoint at the far end: SAVE & GO HOME or RISK IT (CheckpointService)
	do
		local cz = zone.zMax - 5
		local trig = Part(f.StreetProps, "CheckpointTrigger", Vector3.new(2 * HW - 12, 8, 3), CFrame.new(0, 4, cz), C(255, 255, 255), M.SmoothPlastic, { t = 1, collide = false })
		trig.CanTouch = true
		trig:SetAttribute("ZoneId", zid)
		CollectionService:AddTag(trig, "Checkpoint")
		for k = 0, 39 do
			local x = -HW + 6 + (k + 0.5) * (2 * HW - 12) / 40
			Part(f.StreetProps, "CheckpointStripe", Vector3.new((2 * HW - 12) / 40, 0.06, 2), CFrame.new(x, 0.27, cz), (k % 2 == 0) and C(255, 200, 40) or C(28, 28, 32), M.SmoothPlastic, { collide = false, cast = false })
		end
		for _, sx in ipairs({ -1, 1 }) do
			Part(f.StreetProps, "CheckpointPost", Vector3.new(1.6, 13, 1.6), CFrame.new(sx * 16, 6.5, cz), C(40, 44, 52), M.Metal)
		end
		local cb = Part(f.StreetProps, "CheckpointSign", Vector3.new(34, 3.4, 1.2), CFrame.new(0, 13.6, cz), C(255, 200, 40), M.SmoothPlastic)
		Label(cb, Enum.NormalId.Front, "CHECKPOINT - SAVE OR RISK", C(28, 28, 32))
		Label(cb, Enum.NormalId.Back, "CHECKPOINT - SAVE OR RISK", C(28, 28, 32))
	end

	if zone.arena then
		buildArena(ctx, zid)
		return
	end

	local roads = {}
	for _, rid in ipairs(zone.roads) do
		local r = MapConfig.Roads[rid]
		table.insert(roads, r)
		buildRoad(ctx, r, pal, zid)
	end
	if riv then
		buildRiver(ctx, riv, pal)
	end

	local blocks = MapConfig.ZoneBlocks(zid)
	for _, blk in ipairs(blocks) do
		if not (riv and blk[1] < riv.z2 and blk[2] > riv.z1) then
			placeBlock(ctx, blk, pal, zid)
		end
	end

	Prefabs.DistrictSign(f.StreetProps, Vector3.new(-45, 0.4, blocks[1][1] + 10), zone.name, pal.accent2 or pal.accent, 0)
	if sty == "industrial" then
		Prefabs.Crane(f.Buildings, Vector3.new(-(HW + 40), 0, (zone.zMin + zone.zMax) / 2 - 60), 0, pal.accent2)
		Prefabs.Crane(f.Buildings, Vector3.new(HW + 40, 0, (zone.zMin + zone.zMax) / 2 + 60), math.pi, pal.accent)
	end
	genSpawnPoints(ctx, zid, blocks, roads)
end

function Build.Build(opts)
	opts = opts or {}
	local seed = opts.seed or MapConfig.Seed
	local sections = opts.sections or ALL_SECTIONS
	local root = getRoot()
	local started = os.clock()
	Prefabs.Count = 0
	Prefabs.TemplateUse = { placed = 0, missing = {} }
	local summary = {}
	for idx, section in ipairs(sections) do
		clearSection(root, section)
		local ctx = { f = newFolders(section), rng = TrafficMath.NewRng(seed + idx * 1009), foot = {} }
		local before = Prefabs.Count
		if section == "World" then
			buildWorld(ctx)
			buildSpeedLanes(ctx)
		elseif section == "Plaza" then
			buildPlaza(ctx)
		elseif ZONE_OF[section] then
			buildZone(ctx, ZONE_OF[section])
		else
			warn("[BuildCityMap] unknown section:", section)
		end
		for _, name in ipairs(TYPE_FOLDERS) do
			ctx.f[name].Parent = root[name]
		end
		summary[section] = Prefabs.Count - before
	end
	root:SetAttribute("MapVersion", MapConfig.Version)
	-- how many Blender templates were available: a map built while models were missing is rebuilt once they are there
	local props = game:GetService("ServerStorage"):FindFirstChild("BuilderAssets")
	props = props and props:FindFirstChild("Props")
	root:SetAttribute("Templates", props and #props:GetChildren() or 0)
	local missing = {}
	for n in pairs(Prefabs.TemplateUse.missing) do
		table.insert(missing, n)
	end
	print(string.format("[Models] %d Blender models placed on the map%s", Prefabs.TemplateUse.placed,
		#missing > 0 and (" - procedural fallback for: " .. table.concat(missing, ", ")) or ""))
	if not opts.quiet then
		local parts = {}
		for _, s in ipairs(sections) do
			table.insert(parts, s .. "=" .. tostring(summary[s]))
		end
		print(string.format("[BuildCityMap] done in %.2fs, seed=%d, parts: %s (total %d)", os.clock() - started, seed, table.concat(parts, ", "), Prefabs.Count))
	end
	return summary
end

return Build
