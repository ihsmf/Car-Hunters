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
local ALL_SECTIONS = { "World", "Plaza", "CITY", "HIGHWAY", "INDUSTRIAL", "NEON" }
local ZONE_OF = { CITY = "city", HIGHWAY = "highway", INDUSTRIAL = "industrial", NEON = "neon" }

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
	Part(f.Ground, "WorldFloor", Vector3.new(2800, 2, zE - zS + 1400), CFrame.new(0, -2.2, (zS + zE) / 2), C(26, 28, 36), M.Concrete)

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
				Part(f.Buildings, "PerimeterWall", Vector3.new(4, 26, len), CFrame.new(sx * (HW + 2), 13, zm), col, M.Concrete)
				Part(f.Buildings, "WallCap", Vector3.new(4.6, 0.8, len), CFrame.new(sx * (HW + 2), 26.4, zm), C(120, 124, 132), M.Concrete, { collide = false })
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
	Part(f.Buildings, "EndWallStart", Vector3.new(2 * HW + 8, 26, 4), CFrame.new(0, 13, zS - 2), C(140, 146, 160), M.Concrete)
	Part(f.Buildings, "EndWallEnd", Vector3.new(2 * HW + 8, 26, 4), CFrame.new(0, 13, zE + 2), C(30, 50, 70), M.Concrete)
	local fin = Part(f.Buildings, "EndSign", Vector3.new(120, 14, 1), CFrame.new(0, 19, zE - 0.5), C(26, 30, 38), M.SmoothPlastic)
	Label(fin, Enum.NormalId.Front, "END OF THE CITY", C(255, 210, 60))
end

local function buildBase(ctx, i)
	local f = ctx.f
	local bcf = BaseLayout.GetBaseCFrame(i)
	local model = Instance.new("Model")
	model.Name = string.format("Base%02d", i)
	model:SetAttribute("Index", i)
	local function mk(name, size, off, color, mat, o)
		return Part(model, name, size, bcf * CFrame.new(off), color, mat, o)
	end
	local CONCRETE, ASPHALT, STEEL, DARKSTEEL = C(176, 178, 182), C(78, 82, 90), C(150, 156, 166), C(52, 56, 64)
	local BRICK, WHITE, HAZARD = C(168, 78, 62), C(242, 242, 238), C(255, 196, 40)
	local PX, PZ = MapConfig.BasePlot.x / 2, MapConfig.BasePlot.z / 2

	-- floor and markings
	mk("Floor", Vector3.new(PX * 2, 1, PZ * 2), Vector3.new(0, 0, 0), CONCRETE, M.Concrete)
	mk("Apron", Vector3.new(14, 1.02, PZ * 2), Vector3.new(PX - 7, 0.005, 0), C(196, 198, 200), M.Concrete)
	for z = -PZ + 4, PZ - 4, 8 do
		mk("LaneDash", Vector3.new(0.5, 0.04, 4), Vector3.new(BaseLayout.LaneX, 0.53, z), HAZARD, M.SmoothPlastic, { collide = false, cast = false })
	end
	local slots = Instance.new("Folder")
	slots.Name = "Slots"
	slots.Parent = model
	for n = 1, BaseLayout.SlotCount do
		local p = BaseLayout.SlotLocal(n)
		local pad = Part(slots, "Slot" .. n, Vector3.new(22, 0.06, 12.4), bcf * CFrame.new(p.X, 0.53, p.Z), ASPHALT, M.SmoothPlastic, { collide = false, cast = false })
		local num = Label(pad, Enum.NormalId.Top, tostring(n), WHITE)
		num.TextTransparency = 0.35
		num.Rotation = 90
		for _, s in ipairs({ -1, 1 }) do
			mk("SlotLine", Vector3.new(22, 0.04, 0.35), Vector3.new(p.X, 0.58, p.Z + s * 6.4), WHITE, M.SmoothPlastic, { collide = false, cast = false })
		end
		mk("WheelStop", Vector3.new(0.7, 0.45, 5), Vector3.new(p.X - 10, 0.72, p.Z), HAZARD, M.SmoothPlastic, { collide = false })
	end

	-- building: brick back wall with roller doors, concrete side walls, corrugated roof on steel columns
	mk("BackWall", Vector3.new(2, 18, PZ * 2), Vector3.new(-PX + 1, 9, 0), BRICK, M.Brick)
	mk("BackWallCap", Vector3.new(2.6, 1, PZ * 2 + 0.6), Vector3.new(-PX + 1, 18.5, 0), DARKSTEEL, M.Metal)
	for _, z in ipairs({ -30, 0, 30 }) do
		mk("RollerDoor", Vector3.new(0.4, 10, 16), Vector3.new(-PX + 2.2, 5.2, z), C(204, 208, 214), M.DiamondPlate)
		for y = 1, 9, 1.4 do
			mk("DoorRib", Vector3.new(0.2, 0.18, 16), Vector3.new(-PX + 2.45, y, z), C(160, 164, 172), M.Metal, { collide = false, cast = false })
		end
		mk("DoorFrame", Vector3.new(0.6, 1, 17.2), Vector3.new(-PX + 2.3, 10.5, z), DARKSTEEL, M.Metal)
	end
	for _, s in ipairs({ -1, 1 }) do
		mk("SideWall", Vector3.new(58, 8, 1.6), Vector3.new(-PX + 29, 4, s * (PZ - 0.8)), C(200, 200, 196), M.Concrete)
		mk("SideWallStripe", Vector3.new(58, 0.8, 1.7), Vector3.new(-PX + 29, 7.6, s * (PZ - 0.8)), C(40, 120, 200), M.SmoothPlastic)
		for x = 2, PX - 4, 8 do
			mk("Bollard", Vector3.new(0.9, 2.6, 0.9), Vector3.new(x, 1.8, s * (PZ - 0.8)), HAZARD, M.SmoothPlastic)
		end
	end
	local roofX0, roofX1 = -PX, 6
	local rw = roofX1 - roofX0
	mk("Roof", Vector3.new(rw, 0.6, PZ * 2 + 2), Vector3.new((roofX0 + roofX1) / 2, 16.4, 0), C(198, 202, 208), M.Metal)
	for z = -PZ, PZ, 4 do
		mk("RoofRib", Vector3.new(rw, 0.4, 0.5), Vector3.new((roofX0 + roofX1) / 2, 16.9, z), C(170, 175, 184), M.Metal, { collide = false, cast = false })
	end
	mk("RoofFascia", Vector3.new(1, 2.4, PZ * 2 + 2), Vector3.new(roofX1, 15.8, 0), C(40, 120, 200), M.SmoothPlastic)
	for _, z in ipairs({ -PZ + 1.5, -15, 15, PZ - 1.5 }) do
		mk("Column", Vector3.new(1.4, 15.8, 1.4), Vector3.new(roofX1 - 0.8, 7.9, z), STEEL, M.Metal)
		mk("ColumnBase", Vector3.new(2.2, 0.8, 2.2), Vector3.new(roofX1 - 0.8, 0.9, z), DARKSTEEL, M.Metal)
	end
	for _, z in ipairs({ -30, 0, 30 }) do
		local lamp = mk("CeilingLight", Vector3.new(14, 0.3, 1.2), Vector3.new(-22, 15.9, z), C(255, 246, 225), M.Neon, { collide = false, cast = false, light = true })
		local pl = Instance.new("SurfaceLight")
		pl.Face = Enum.NormalId.Bottom
		pl.Range = 22
		pl.Brightness = 1.2
		pl.Angle = 110
		pl.Color = C(255, 240, 215)
		pl.Parent = lamp
	end

	-- owner sign + income board on the back wall (BaseService writes into their SurfaceGuis)
	local sign = mk("OwnerSign", Vector3.new(1, 5, 40), Vector3.new(-PX + 2.4, 13.2, 0), C(26, 30, 38), M.SmoothPlastic)
	Label(sign, Enum.NormalId.Right, "FREE GARAGE", C(255, 255, 255))
	mk("OwnerSignFrame", Vector3.new(0.8, 5.8, 40.8), Vector3.new(-PX + 2.2, 13.2, 0), HAZARD, M.SmoothPlastic)
	local screen = mk("IncomeScreen", Vector3.new(1, 3, 22), Vector3.new(-PX + 2.4, 19.6, 0), C(16, 18, 22), M.SmoothPlastic)
	Label(screen, Enum.NormalId.Right, "", C(110, 230, 140))

	-- the trap: a car lift with a magnetic crane
	local t = BaseLayout.TrapLocal
	mk("TrapPad", Vector3.new(18, 0.7, 18), Vector3.new(t.X, 0.85, t.Z), C(96, 100, 108), M.DiamondPlate)
	for k = 0, 7 do
		for _, s in ipairs({ -1, 1 }) do
			local c = (k % 2 == 0) and HAZARD or C(28, 28, 30)
			mk("Hazard", Vector3.new(2.25, 0.06, 0.8), Vector3.new(t.X - 7.9 + k * 2.25, 1.23, t.Z + s * 8.6), c, M.SmoothPlastic, { collide = false, cast = false })
			mk("Hazard", Vector3.new(0.8, 0.06, 2.25), Vector3.new(t.X + s * 8.6, 1.23, t.Z - 7.9 + k * 2.25), c, M.SmoothPlastic, { collide = false, cast = false })
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			mk("LiftPost", Vector3.new(1.4, 14, 1.4), Vector3.new(t.X + sx * 9.4, 7, t.Z + sz * 9.4), C(220, 70, 50), M.Metal)
		end
		mk("LiftBeam", Vector3.new(1.2, 1.2, 20.2), Vector3.new(t.X + sx * 9.4, 14.2, t.Z), C(220, 70, 50), M.Metal)
	end
	mk("CraneBeam", Vector3.new(20.2, 1.4, 1.4), Vector3.new(t.X, 14.6, t.Z), DARKSTEEL, M.Metal)
	mk("CraneCable", Vector3.new(0.25, 3.6, 0.25), Vector3.new(t.X, 12.2, t.Z), C(30, 30, 30), M.Metal, { collide = false })
	local magnet = mk("TrapMagnet", Vector3.new(1.4, 6, 6), Vector3.new(t.X, 9.8, t.Z), C(70, 74, 82), M.Metal, { shape = CYL, collide = false })
	magnet.CFrame = bcf * CFrame.new(t.X, 9.8, t.Z) * UPRIGHT
	local trapSign = mk("TrapSign", Vector3.new(0.5, 2.4, 12), Vector3.new(t.X + 9.6, 12.2, t.Z), C(26, 30, 38), M.SmoothPlastic)
	Label(trapSign, Enum.NormalId.Right, "THROW PARTS HERE", HAZARD)

	-- vehicle entrance: roller door in a frame, new cars roll out of it
	local pl = BaseLayout.PortalLocal
	for _, s in ipairs({ -1, 1 }) do
		mk("PortalPost", Vector3.new(2, 13, 2), Vector3.new(pl.X, 6.5, pl.Z + s * 9.5), BRICK, M.Brick)
	end
	local header = mk("PortalHeader", Vector3.new(2.4, 3, 21), Vector3.new(pl.X, 14.2, pl.Z), DARKSTEEL, M.Metal)
	Label(header, Enum.NormalId.Right, "VEHICLE IN", WHITE)
	mk("PortalDoor", Vector3.new(0.4, 12, 17), Vector3.new(pl.X - 0.6, 6.6, pl.Z), C(204, 208, 214), M.DiamondPlate, { collide = false })

	-- terminal (opens the garage menu) = tool chest with a screen
	local tm = BaseLayout.TerminalLocal
	mk("Terminal", Vector3.new(4, 5, 7), Vector3.new(tm.X, 3, tm.Z), C(200, 40, 40), M.SmoothPlastic)
	for d = 0, 3 do
		mk("Drawer", Vector3.new(4.1, 0.15, 6.4), Vector3.new(tm.X, 1.4 + d * 1.1, tm.Z), C(150, 30, 30), M.SmoothPlastic, { collide = false, cast = false })
	end
	local scr = mk("TerminalScreen", Vector3.new(0.4, 3, 5), Vector3.new(tm.X, 7.2, tm.Z), C(16, 18, 22), M.SmoothPlastic)
	Label(scr, Enum.NormalId.Right, "GARAGE", WHITE)

	-- workshop clutter along the back wall
	local rng = ctx.rng
	Prefabs.TireStack(model, bcf:PointToWorldSpace(Vector3.new(-PX + 5, 0.5, -PZ + 5)), rng)
	Prefabs.TireStack(model, bcf:PointToWorldSpace(Vector3.new(-PX + 5, 0.5, PZ - 5)), rng)
	for k = 0, 2 do
		local b = mk("Barrel", Vector3.new(3.4, 3, 3), Vector3.new(-PX + 4, 2.2, -PZ + 10 + k * 3.2), (k == 1) and C(40, 110, 190) or C(200, 60, 50), M.Metal, { shape = CYL })
		b.CFrame = bcf * CFrame.new(-PX + 4, 2.2, -PZ + 10 + k * 3.2) * UPRIGHT
	end
	mk("Workbench", Vector3.new(4, 0.5, 9), Vector3.new(-PX + 4, 3.4, PZ - 14), C(150, 104, 64), M.Wood)
	mk("WorkbenchLegs", Vector3.new(3.6, 3, 8.6), Vector3.new(-PX + 4, 1.6, PZ - 14), DARKSTEEL, M.Metal)
	mk("Vise", Vector3.new(1.2, 1, 1.4), Vector3.new(-PX + 4, 4.1, PZ - 17), C(40, 90, 160), M.Metal)

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
	local W, D, H = 34, 22, 13
	local RED, WHITE, DARK2, GLASS2 = C(214, 52, 44), C(244, 242, 236), C(36, 40, 48), C(150, 200, 230)
	mk("Slab", Vector3.new(W + 8, 0.6, D + 12), Vector3.new(0, 0.1, -4), C(210, 206, 198), M.Concrete)
	mk("Body", Vector3.new(W, H, D), Vector3.new(0, H / 2 + 0.4, 6), WHITE, M.SmoothPlastic)
	mk("BaseStripe", Vector3.new(W + 0.2, 1.4, D + 0.2), Vector3.new(0, 1.1, 6), DARK2, M.SmoothPlastic)
	mk("RoofCap", Vector3.new(W + 1.4, 1.2, D + 1.4), Vector3.new(0, H + 1, 6), RED, M.SmoothPlastic)
	-- shop window and counter opening
	mk("Window", Vector3.new(W - 10, 6, 0.3), Vector3.new(0, 6.2, 6 - D / 2 - 0.05), GLASS2, M.Glass, { t = 0.35 })
	for x = -W / 2 + 5, W / 2 - 5, (W - 10) / 4 do
		mk("Mullion", Vector3.new(0.4, 6, 0.5), Vector3.new(x, 6.2, 6 - D / 2 - 0.1), DARK2, M.Metal)
	end
	mk("Counter", Vector3.new(W - 8, 3.6, 3), Vector3.new(0, 2.2, 6 - D / 2 - 1.6), RED, M.SmoothPlastic)
	mk("CounterTop", Vector3.new(W - 7, 0.4, 3.6), Vector3.new(0, 4.2, 6 - D / 2 - 1.6), C(60, 64, 72), M.Metal)
	-- striped awning
	for k = 0, 9 do
		local c = (k % 2 == 0) and RED or WHITE
		local x = -W / 2 + (k + 0.5) * (W / 10)
		Part(m, "Awning", Vector3.new(W / 10, 0.4, 7), cf * CFrame.new(x, 10.4, 6 - D / 2 - 3.2) * CFrame.Angles(math.rad(-16), 0, 0), c, M.SmoothPlastic, { collide = false })
	end
	-- big sign
	local sign = mk("ShopSign", Vector3.new(W - 4, 4.6, 0.6), Vector3.new(0, H + 4, 6 - D / 2 + 1), DARK2, M.SmoothPlastic)
	Label(sign, Enum.NormalId.Front, "PIT STOP  UPGRADES", C(255, 210, 63))
	for _, s in ipairs({ -1, 1 }) do
		mk("SignLeg", Vector3.new(0.6, 3, 0.6), Vector3.new(s * (W / 2 - 4), H + 1.4, 6 - D / 2 + 1), DARK2, M.Metal)
	end
	-- props: tire rack, oil cans, a lifted showcase engine
	Prefabs.TireStack(m, cf:PointToWorldSpace(Vector3.new(-W / 2 - 1, 0.4, -5)), ctx.rng)
	Prefabs.TireStack(m, cf:PointToWorldSpace(Vector3.new(W / 2 + 1, 0.4, -5)), ctx.rng)
	for k = 0, 2 do
		mk("OilCan", Vector3.new(1.2, 1.6, 1), Vector3.new(-6 + k * 1.6, 5.2, 6 - D / 2 - 1.4), ({ C(255, 196, 40), C(40, 120, 200), C(50, 160, 80) })[k + 1], M.SmoothPlastic)
	end
	local npcSpot = mk("NpcSpot", Vector3.new(2, 0.2, 2), Vector3.new(0, 0.5, 6 - D / 2 + 1.5), WHITE, M.SmoothPlastic, { t = 1, collide = false })
	npcSpot:SetAttribute("Yaw", cfg.yaw)
	local prompt = mk("ShopPrompt", Vector3.new(6, 6, 2), Vector3.new(0, 3.5, 6 - D / 2 - 4), WHITE, M.SmoothPlastic, { t = 1, collide = false })
	CollectionService:AddTag(prompt, "ShopPrompt")
	for _, s in ipairs({ -1, 1 }) do
		local lamp = mk("ShopLamp", Vector3.new(0.6, 0.6, 0.6), Vector3.new(s * 8, 9.8, 6 - D / 2 - 2), C(255, 240, 210), M.Neon, { light = true, collide = false })
		local l = Instance.new("PointLight")
		l.Range = 16
		l.Brightness = 1.4
		l.Color = C(255, 230, 190)
		l.Parent = lamp
	end
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

local SHOWCASE_Z = (MapConfig.BaseCenters[1].z + MapConfig.BaseCenters[3].z) / 2

local function buildPlaza(ctx)
	local f = ctx.f
	local P = MapConfig.Plaza
	local PW = MapConfig.PromenadeHalfWidth
	local zS, zE = MapConfig.StartZ, MapConfig.EntryZ
	local len = zE - zS
	local zm = (zS + zE) / 2
	Part(f.Ground, "PlazaGround", Vector3.new(2 * HW, 2, len), CFrame.new(0, -1, zm), P.ground, M.Grass)
	Part(f.Ground, "Promenade", Vector3.new(2 * PW, 0.4, len - 6), CFrame.new(0, 0, zm - 1), P.paving, M.Concrete)
	-- paving pattern: large slabs with thin joints
	for z = zS + 8, zE - 8, 12 do
		Part(f.Ground, "PavingJoint", Vector3.new(2 * PW - 2, 0.04, 0.25), CFrame.new(0, 0.22, z), C(208, 200, 186), M.SmoothPlastic, { collide = false, cast = false })
	end
	for _, s in ipairs({ -1, 1 }) do
		Part(f.Ground, "Curb", Vector3.new(1.2, 0.6, len - 6), CFrame.new(s * PW, 0.3, zm - 1), C(150, 150, 146), M.Concrete)
	end

	for i = 1, MapConfig.BaseCount do
		buildBase(ctx, i)
	end
	buildShop(ctx)
	buildDonateStall(ctx)

	-- entry arch: steel truss with a checkered finish banner
	for _, s in ipairs({ -1, 1 }) do
		Part(f.Buildings, "ArchPillar", Vector3.new(3, 24, 3), CFrame.new(s * 40, 12, zE - 4), C(52, 56, 64), M.Metal)
		Part(f.Buildings, "ArchFoot", Vector3.new(5, 1.2, 5), CFrame.new(s * 40, 0.6, zE - 4), C(120, 124, 132), M.Concrete)
	end
	local beam = Part(f.Buildings, "ArchBeam", Vector3.new(83, 5, 3), CFrame.new(0, 24, zE - 4), C(26, 30, 38), M.SmoothPlastic)
	Label(beam, Enum.NormalId.Front, "CAR HUNTERS", C(255, 210, 63))
	Label(beam, Enum.NormalId.Back, "SAFE ZONE", C(255, 255, 255))
	Prefabs.Checker(f.Buildings, CFrame.new(0, 20.4, zE - 4), 80, 2.4, 2.8)

	-- leaderboard + contracts board near the exit
	local lb = MapConfig.Leaderboard
	for _, s in ipairs({ -1, 1 }) do
		Part(f.StreetProps, "LBPost", Vector3.new(1, 14, 1), CFrame.new(lb.x + s * 9, 7, lb.z), C(52, 56, 64), M.Metal)
	end
	local board = Part(f.StreetProps, "Leaderboard", Vector3.new(20, 12, 0.8), CFrame.new(lb.x, 14, lb.z), C(26, 30, 38), M.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Gui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 0.2)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.LuckiestGuy
	title.TextScaled = true
	title.TextColor3 = C(255, 210, 63)
	title.Text = "TOP INCOME / SEC"
	title.Parent = gui
	local rows = Instance.new("TextLabel")
	rows.Name = "Rows"
	rows.Position = UDim2.fromScale(0.05, 0.22)
	rows.Size = UDim2.fromScale(0.9, 0.74)
	rows.BackgroundTransparency = 1
	rows.Font = Enum.Font.FredokaOne
	rows.TextSize = 26
	rows.TextXAlignment = Enum.TextXAlignment.Left
	rows.TextYAlignment = Enum.TextYAlignment.Top
	rows.TextColor3 = C(255, 255, 255)
	rows.Text = ""
	rows.Parent = gui
	local cb = MapConfig.ContractBoard
	for _, s in ipairs({ -1, 1 }) do
		Part(f.StreetProps, "CBPost", Vector3.new(0.8, 9, 0.8), CFrame.new(cb.x + s * 7, 4.5, cb.z), C(110, 70, 40), M.Wood)
	end
	local cboard = Part(f.StreetProps, "ContractBoard", Vector3.new(15, 7, 0.6), CFrame.new(cb.x, 7, cb.z), C(140, 96, 56), M.Wood)
	Label(cboard, Enum.NormalId.Front, "CONTRACTS", C(255, 240, 200))
	CollectionService:AddTag(cboard, "ContractBoard")

	-- greenery and street furniture, kept clear of the running lanes and garage connectors
	local rng = ctx.rng
	local lampV = 1
	for z = zS + 16, zE - 16, 32 do
		if not nearBaseRow(z, 12) then
			for _, s in ipairs({ -1, 1 }) do
				Prefabs.Lamp(f.StreetProps, Vector3.new(s * (PW - 4), 0.4, z), lampV, C(255, 228, 180), (s < 0) and 0 or math.pi)
			end
			lampV = lampV % 2 + 1
		end
	end
	for z = zS + 24, zE - 24, 30 do
		local nearShop = math.abs(z - MapConfig.Shop.z) < 22 or math.abs(z - SHOWCASE_Z) < 14
		if not nearBaseRow(z, 14) and not nearShop then
			for _, s in ipairs({ -1, 1 }) do
				Prefabs.Tree(f.StreetProps, Vector3.new(s * (PW - 14), 0.4, z), rng, "tree")
				Prefabs.Bench(f.StreetProps, Vector3.new(s * 18, 0.4, z + 8), (s < 0) and math.pi / 2 or -math.pi / 2)
				Prefabs.FlowerBed(f.StreetProps, Vector3.new(s * 34, 0.2, z), 6, 10, rng)
			end
		end
	end
	-- legendary showcase between the first garage rows
	local legends = CarConfig.ByRarity.Legendary
	for k, x in ipairs({ -30, 30 }) do
		local def = legends[k]
		local z = SHOWCASE_Z
		Part(f.StreetProps, "Podium", Vector3.new(1.2, 18, 18), CFrame.new(x, 0.8, z) * UPRIGHT, C(40, 44, 52), M.Metal, { shape = CYL })
		Part(f.StreetProps, "PodiumRim", Vector3.new(0.4, 18.6, 18.6), CFrame.new(x, 1.2, z) * UPRIGHT, C(232, 178, 50), M.Metal, { shape = CYL, collide = false })
		local car = VehicleFactory.BuildCar(def)
		car:PivotTo(CFrame.new(x, 1.5, z) * CFrame.Angles(0, math.rad(40 + k * 90), 0))
		car.Parent = f.StreetProps
		CollectionService:AddTag(car, "Turntable")
		Prefabs.Count = Prefabs.Count + 1
	end
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

local function buildRoad(ctx, road, pal, zid)
	local f = ctx.f
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
				Part(f.StreetProps, "Barrier", Vector3.new(7, 1.6, 1.6), CFrame.new(x, 1.6, z0), (zid == "highway") and C(190, 192, 200) or C(240, 190, 40), M.Concrete)
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
			Part(f.StreetProps, "Barrel", Vector3.new(3, 3.6, 3), CFrame.new(x, 2.2, z), pick(rng, { C(200, 70, 50), C(70, 110, 190) }), M.Metal, { shape = CYL }).CFrame = CFrame.new(x, 2.2, z) * UPRIGHT
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
	local ground = (zid == "industrial" or zid == "neon") and M.Concrete or M.Grass
	Part(f.Ground, "Ground_" .. zid, Vector3.new(2 * HW, 2, zEnd - zStart), CFrame.new(0, -1, (zStart + zEnd) / 2), pal.ground, ground)

	if gate then
		buildGate(ctx, gate, zone)
	else
		buildEntryFence(ctx, zone)
	end

	local roads = {}
	for _, rid in ipairs(zone.roads) do
		local r = MapConfig.Roads[rid]
		table.insert(roads, r)
		buildRoad(ctx, r, pal, zid)
	end

	local blocks = MapConfig.ZoneBlocks(zid)
	for _, blk in ipairs(blocks) do
		placeBlock(ctx, blk, pal, zid)
	end

	Prefabs.DistrictSign(f.StreetProps, Vector3.new(-45, 0.4, blocks[1][1] + 10), zone.name, pal.accent2 or pal.accent, 0)
	if zid == "industrial" then
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
