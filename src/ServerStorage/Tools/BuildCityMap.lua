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
				local acc = (zone == "plaza") and MapConfig.Plaza.accent or MapConfig.Zones[zone].palette.accent
				Part(f.Buildings, "WallTrim", Vector3.new(4.4, 0.6, len), CFrame.new(sx * (HW + 2), 26.3, zm), acc, M.Neon, { collide = false })
			end
		end
		for _, o in ipairs(openings) do
			seg(cursor, o[1])
			cursor = o[2]
			local W = o[3].width
			local z0 = o[3].z
			local zone = MapConfig.Zones[o[3].zone]
			Part(f.Buildings, "TunnelLintel", Vector3.new(4, 16, W), CFrame.new(sx * (HW + 2), 18, z0), zone.palette.curb, M.Concrete)
			Part(f.Buildings, "TunnelTrim", Vector3.new(4.4, 0.7, W), CFrame.new(sx * (HW + 2), 10.2, z0), zone.palette.accent, M.Neon, { collide = false })
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
			Part(f.Buildings, "BackdropBand", Vector3.new(d + 0.3, 2, w * 0.8), CFrame.new(cx, h * 0.6, z), pal.accent, M.Neon, { cast = false, collide = false })
			z = z + 58 + rr(ctx.rng, 0, 14)
		end
	end
	local crng = ctx.rng
	for _ = 1, math.floor(44 * MapConfig.DecorationDensity + 10) do
		Prefabs.Cloud(f.StreetProps, Vector3.new(rr(crng, -520, 520), rr(crng, 150, 230), rr(crng, zS - 200, zE + 200)), crng)
	end
	Part(f.Buildings, "EndWallStart", Vector3.new(2 * HW + 8, 26, 4), CFrame.new(0, 13, zS - 2), C(140, 146, 160), M.Concrete)
	Part(f.Buildings, "EndWallEnd", Vector3.new(2 * HW + 8, 26, 4), CFrame.new(0, 13, zE + 2), C(30, 50, 70), M.Concrete)
	local fin = Part(f.Buildings, "EndSign", Vector3.new(120, 14, 1), CFrame.new(0, 19, zE - 0.5), C(10, 8, 20), M.SmoothPlastic)
	Label(fin, Enum.NormalId.Front, "END OF THE CITY", C(255, 210, 60))
end

local function buildBase(ctx, i)
	local f = ctx.f
	local P = MapConfig.Plaza
	local bcf = BaseLayout.GetBaseCFrame(i)
	local model = Instance.new("Model")
	model.Name = string.format("Base%02d", i)
	model:SetAttribute("Index", i)
	local function mk(name, size, off, color, mat, o)
		return Part(model, name, size, bcf * CFrame.new(off), color, mat, o)
	end

	mk("Floor", Vector3.new(110, 1, 95), Vector3.new(0, 0, 0), P.floor, M.SmoothPlastic)
	mk("EdgeFront", Vector3.new(0.6, 0.1, 95), Vector3.new(54.7, 0.55, 0), P.accent, M.Neon, { collide = false })
	mk("EdgeL", Vector3.new(110, 0.1, 0.6), Vector3.new(0, 0.55, 47.2), P.accent, M.Neon, { collide = false })
	mk("EdgeR", Vector3.new(110, 0.1, 0.6), Vector3.new(0, 0.55, -47.2), P.accent, M.Neon, { collide = false })
	mk("BackWall", Vector3.new(2, 14, 95), Vector3.new(-54, 7, 0), C(38, 40, 50), M.SmoothPlastic)
	mk("WallGlowTop", Vector3.new(2.2, 0.6, 95), Vector3.new(-54, 14.3, 0), P.accent, M.Neon, { collide = false })
	mk("GlassL", Vector3.new(110, 5, 0.6), Vector3.new(0, 3, 47.5), C(150, 205, 240), M.Glass, { t = 0.5 })
	mk("GlassR", Vector3.new(110, 5, 0.6), Vector3.new(0, 3, -47.5), C(150, 205, 240), M.Glass, { t = 0.5 })

	local sign = mk("OwnerSign", Vector3.new(1, 5, 34), Vector3.new(-53, 11.5, 0), C(14, 16, 24), M.SmoothPlastic)
	local l1 = Label(sign, Enum.NormalId.Right, "FREE GARAGE", C(255, 255, 255))
	local screen = mk("IncomeScreen", Vector3.new(1, 4.6, 24), Vector3.new(-53, 5.2, 0), C(10, 12, 18), M.SmoothPlastic)
	local l2 = Label(screen, Enum.NormalId.Right, "", C(90, 255, 140))

	local slots = Instance.new("Folder")
	slots.Name = "Slots"
	slots.Parent = model
	for n = 1, BaseLayout.SlotCount do
		local p = BaseLayout.SlotLocal(n)
		local pad = Part(slots, "Slot" .. n, Vector3.new(22, 0.2, 12), bcf * CFrame.new(p.X, 0.6, p.Z), C(45, 46, 54), M.SmoothPlastic, { collide = false })
		local num = Label(pad, Enum.NormalId.Top, tostring(n), C(255, 255, 255))
		num.TextTransparency = 0.55
		num.Rotation = 90
		mk("SlotLineA", Vector3.new(22, 0.06, 0.4), Vector3.new(p.X, 0.53, p.Z + 6.6), C(235, 235, 240), M.SmoothPlastic, { collide = false, cast = false })
		mk("SlotLineB", Vector3.new(22, 0.06, 0.4), Vector3.new(p.X, 0.53, p.Z - 6.6), C(235, 235, 240), M.SmoothPlastic, { collide = false, cast = false })
	end
	for z = -44, 44, 8 do
		mk("LaneDash", Vector3.new(0.5, 0.06, 4), Vector3.new(BaseLayout.LaneX, 0.53, z), C(255, 210, 70), M.SmoothPlastic, { collide = false, cast = false })
	end
	mk("Canopy", Vector3.new(44, 0.4, 95), Vector3.new(-30, 15.2, 0), C(200, 230, 255), M.Glass, { t = 0.6, collide = false })
	mk("CanopyFrameF", Vector3.new(1, 1, 95), Vector3.new(-8.5, 15.2, 0), C(40, 44, 56), M.Metal, { collide = false })
	for _, z in ipairs({ -46.5, 0, 46.5 }) do
		mk("CanopyBeam", Vector3.new(44, 1, 1), Vector3.new(-30, 15.2, z), C(40, 44, 56), M.Metal, { collide = false })
		mk("CanopyPost", Vector3.new(1, 14.6, 1), Vector3.new(-8.5, 7.8, z), C(40, 44, 56), M.Metal)
	end
	mk("CanopyGlow", Vector3.new(0.4, 0.3, 95), Vector3.new(-8.5, 14.5, 0), P.accent, M.Neon, { collide = false, cast = false })
	for _, z in ipairs({ -44, 44 }) do
		Prefabs.Planter(model, bcf:PointToWorldSpace(Vector3.new(46, 0.5, z * 0.82)), C(232, 226, 216))
	end

	local t = BaseLayout.TrapLocal
	local pad = mk("TrapPad", Vector3.new(0.5, 18, 18), Vector3.new(t.X, 0.75, t.Z), C(40, 230, 255), M.Neon, { shape = CYL, collide = false })
	pad.CFrame = bcf * CFrame.new(t.X, 0.75, t.Z) * UPRIGHT
	local inner = mk("TrapInner", Vector3.new(0.6, 11, 11), Vector3.new(t.X, 0.8, t.Z), C(18, 26, 44), M.SmoothPlastic, { shape = CYL, collide = false })
	inner.CFrame = bcf * CFrame.new(t.X, 0.8, t.Z) * UPRIGHT
	mk("TrapArchL", Vector3.new(1.6, 12, 1.6), Vector3.new(t.X, 6.5, t.Z + 9.5), C(200, 205, 215), M.Metal)
	mk("TrapArchR", Vector3.new(1.6, 12, 1.6), Vector3.new(t.X, 6.5, t.Z - 9.5), C(200, 205, 215), M.Metal)
	local top = mk("TrapArchTop", Vector3.new(1.6, 2.2, 21), Vector3.new(t.X, 13, t.Z), C(30, 34, 46), M.Metal)
	Label(top, Enum.NormalId.Right, "DROP PART", C(40, 230, 255))
	mk("TrapArchGlow", Vector3.new(1.0, 0.5, 19), Vector3.new(t.X, 11.7, t.Z), C(40, 230, 255), M.Neon, { collide = false })

	local pl = BaseLayout.PortalLocal
	mk("PortalL", Vector3.new(3, 14, 3), Vector3.new(pl.X, 7.5, pl.Z + 9.5), C(30, 34, 46), M.Metal)
	mk("PortalR", Vector3.new(3, 14, 3), Vector3.new(pl.X, 7.5, pl.Z - 9.5), C(30, 34, 46), M.Metal)
	local ptop = mk("PortalTop", Vector3.new(3, 3, 22), Vector3.new(pl.X, 15.5, pl.Z), C(30, 34, 46), M.Metal)
	Label(ptop, Enum.NormalId.Right, "VEHICLE ENTRANCE", C(255, 200, 60))
	mk("PortalField", Vector3.new(0.6, 12, 16), Vector3.new(pl.X, 7.5, pl.Z), C(255, 190, 40), M.Neon, { t = 0.78, collide = false })

	local tm = BaseLayout.TerminalLocal
	local term = mk("Terminal", Vector3.new(4, 8, 7), Vector3.new(tm.X, 4.5, tm.Z), C(30, 34, 46), M.Metal)
	Label(term, Enum.NormalId.Right, "GARAGE", C(255, 255, 255))
	mk("TerminalGlow", Vector3.new(4.2, 0.5, 7.2), Vector3.new(tm.X, 8.7, tm.Z), P.accent, M.Neon, { collide = false })

	local sp = Instance.new("SpawnLocation")
	sp.Name = "Spawn"
	sp.Size = Vector3.new(8, 0.4, 8)
	sp.CFrame = bcf * CFrame.new(BaseLayout.SpawnLocal.X, 0.7, BaseLayout.SpawnLocal.Z)
	sp.Anchored = true
	sp.Neutral = true
	sp.Duration = 0
	sp.Enabled = true
	sp.Transparency = 1
	sp.CanCollide = false
	sp.Parent = model
	Prefabs.Count = Prefabs.Count + 1

	local cars = Instance.new("Folder")
	cars.Name = "Cars"
	cars.Parent = model

	Prefabs.Lamp(model, bcf:PointToWorldSpace(Vector3.new(53, 0.5, 44)), 3, P.accent, 0)
	Prefabs.Lamp(model, bcf:PointToWorldSpace(Vector3.new(53, 0.5, -44)), 3, P.accent, 0)
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

local function buildPlaza(ctx)
	local f = ctx.f
	local P = MapConfig.Plaza
	local PW = MapConfig.PromenadeHalfWidth
	local zS, zE = MapConfig.StartZ, MapConfig.EntryZ
	local len = zE - zS
	local zm = (zS + zE) / 2
	Part(f.Ground, "PlazaGround", Vector3.new(2 * HW, 2, len), CFrame.new(0, -1, zm), P.ground, M.Grass)
	Part(f.Ground, "Promenade", Vector3.new(2 * PW, 0.4, len - 6), CFrame.new(0, 0, zm - 1), P.paving, M.Concrete)
	local band = 0
	for z = zS + 10, zE - 20, 20 do
		band = band + 1
		if band % 2 == 0 then
			Part(f.Ground, "PavingBand", Vector3.new(2 * PW - 4, 0.06, 10), CFrame.new(0, 0.23, z), C(250, 240, 222), M.Concrete, { collide = false, cast = false })
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		Part(f.Ground, "PromenadeEdge", Vector3.new(1.2, 0.5, len - 6), CFrame.new(s * PW, 0.25, zm - 1), C(255, 210, 63), M.SmoothPlastic, { collide = false })
	end

	for i = 1, MapConfig.BaseCount do
		buildBase(ctx, i)
	end

	-- entry arch (checkered finish-line style)
	for _, s in ipairs({ -1, 1 }) do
		Part(f.Buildings, "ArchPillar", Vector3.new(6, 24, 6), CFrame.new(s * 62, 12, zE - 4), C(255, 59, 59), M.SmoothPlastic)
		Part(f.Buildings, "ArchGlow", Vector3.new(1, 22, 1), CFrame.new(s * 58.8, 12, zE - 7.2), C(255, 210, 63), M.Neon, { collide = false })
	end
	local beam = Part(f.Buildings, "ArchBeam", Vector3.new(130, 6, 8), CFrame.new(0, 24, zE - 4), C(27, 31, 42), M.SmoothPlastic)
	Label(beam, Enum.NormalId.Front, "CAR HUNTERS", C(255, 210, 63))
	Label(beam, Enum.NormalId.Back, "SAFE PLAZA", C(52, 208, 88))
	Prefabs.Checker(f.Buildings, CFrame.new(0, 20.6, zE - 4), 130, 1.6, 8.4)

	-- showcase: legendary cars on podiums + fountain, off the central speed lane
	local legends = CarConfig.ByRarity.Legendary
	local spots = { Vector3.new(-55, 0, -235), Vector3.new(55, 0, -235), Vector3.new(55, 0, -135) }
	for k, pos in ipairs(spots) do
		local def = legends[k]
		Part(f.StreetProps, "Podium", Vector3.new(1.2, 20, 20), CFrame.new(pos.X, 0.8, pos.Z) * UPRIGHT, C(27, 31, 42), M.SmoothPlastic, { shape = CYL })
		Part(f.StreetProps, "PodiumRing", Vector3.new(0.3, 21, 21), CFrame.new(pos.X, 1.45, pos.Z) * UPRIGHT, def.neon or P.accent, M.Neon, { shape = CYL, collide = false })
		local car = VehicleFactory.BuildCar(def)
		car:PivotTo(CFrame.new(pos.X, 1.5, pos.Z) * CFrame.Angles(0, math.rad(35 + k * 40), 0))
		car.Parent = f.StreetProps
		CollectionService:AddTag(car, "Turntable")
		Prefabs.Count = Prefabs.Count + 1
	end
	Prefabs.Fountain(f.StreetProps, Vector3.new(-55, 0.2, -135), P.accent)
	local sb = Part(f.StreetProps, "ShowcaseSign", Vector3.new(40, 6, 1), CFrame.new(0, 16, -262), C(27, 31, 42), M.SmoothPlastic)
	Label(sb, Enum.NormalId.Front, "COLLECT THEM ALL", C(255, 210, 63))
	Part(f.StreetProps, "ShowcasePostL", Vector3.new(1, 14, 1), CFrame.new(-18, 7, -262), C(27, 31, 42), M.Metal)
	Part(f.StreetProps, "ShowcasePostR", Vector3.new(1, 14, 1), CFrame.new(18, 7, -262), C(27, 31, 42), M.Metal)

	Prefabs.DistrictSign(f.StreetProps, Vector3.new(-62, 0, 40), "GRAB PARTS - RUN HOME - THROW ON THE TRAP", C(46, 168, 255), 0)

	local lbPos = Vector3.new(62, 0, 44)
	Part(f.StreetProps, "LBPostL", Vector3.new(1, 12, 1), CFrame.new(lbPos.X - 15, 6, lbPos.Z), C(27, 31, 42), M.Metal)
	Part(f.StreetProps, "LBPostR", Vector3.new(1, 12, 1), CFrame.new(lbPos.X + 15, 6, lbPos.Z), C(27, 31, 42), M.Metal)
	local lb = Part(f.StreetProps, "Leaderboard", Vector3.new(36, 20, 1), CFrame.new(lbPos.X, 18, lbPos.Z), C(27, 31, 42), M.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Gui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	gui.Parent = lb
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 0.18)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.LuckiestGuy
	title.TextScaled = true
	title.TextColor3 = C(255, 210, 63)
	title.Text = "TOP INCOME / SEC"
	title.Parent = gui
	local rows = Instance.new("TextLabel")
	rows.Name = "Rows"
	rows.Position = UDim2.fromScale(0.04, 0.2)
	rows.Size = UDim2.fromScale(0.92, 0.76)
	rows.BackgroundTransparency = 1
	rows.Font = Enum.Font.FredokaOne
	rows.TextSize = 26
	rows.TextXAlignment = Enum.TextXAlignment.Left
	rows.TextYAlignment = Enum.TextYAlignment.Top
	rows.TextColor3 = C(255, 255, 255)
	rows.Text = ""
	rows.Parent = gui
	Part(f.StreetProps, "LBTrim", Vector3.new(37, 0.7, 1.4), CFrame.new(lbPos.X, 28.2, lbPos.Z), C(255, 210, 63), M.Neon, { collide = false })

	local rng = ctx.rng
	local lampV = 1
	for z = zS + 20, zE - 20, 40 do
		if not nearBaseRow(z, 10) then
			for _, s in ipairs({ -1, 1 }) do
				Prefabs.Lamp(f.StreetProps, Vector3.new(s * (PW - 8), 0.4, z), lampV, P.accent, (s < 0) and 0 or math.pi)
			end
			lampV = lampV % 3 + 1
		end
	end
	for z = zS + 30, zE - 30, 50 do
		if not nearBaseRow(z, 14) then
			for _, s in ipairs({ -1, 1 }) do
				Prefabs.Tree(f.StreetProps, Vector3.new(s * (PW - 22), 0.4, z), rng, "tree")
				Prefabs.Bench(f.StreetProps, Vector3.new(s * (PW - 30), 0.4, z + 12), (s < 0) and math.pi / 2 or -math.pi / 2)
			end
		end
	end
	for _, z in ipairs({ -310, -40 }) do
		for _, s in ipairs({ -1, 1 }) do
			Prefabs.FlowerBed(f.StreetProps, Vector3.new(s * 30, 0.2, z), 8, 14, rng)
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		Prefabs.TireStack(f.StreetProps, Vector3.new(s * 24, 0.2, 48), rng)
		Prefabs.TireStack(f.StreetProps, Vector3.new(s * 30, 0.2, 54), rng)
	end
end

local function buildSpeedLanes(ctx)
	local f = ctx.f
	local ORANGE, YELLOW = C(255, 138, 31), C(255, 210, 63)
	for i, r in ipairs(MapConfig.SpeedLanes()) do
		local w, l = r[2] - r[1], r[4] - r[3]
		local cx, cz = (r[1] + r[2]) / 2, (r[3] + r[4]) / 2
		local alongZ = l >= w
		local y = (cz < MapConfig.EntryZ) and 0.32 or 0.2
		local lane = Part(f.StreetProps, "SpeedLane", Vector3.new(w, 0.12, l), CFrame.new(cx, y, cz), ORANGE, M.Neon, { collide = false, cast = false })
		lane.Transparency = 0.15
		lane:SetAttribute("LaneIndex", i)
		CollectionService:AddTag(lane, "SpeedLane")
		for _, s in ipairs({ -1, 1 }) do
			local edge = alongZ and Vector3.new(0.5, 0.14, l) or Vector3.new(w, 0.14, 0.5)
			local off = alongZ and Vector3.new(s * (w / 2 + 0.25), 0, 0) or Vector3.new(0, 0, s * (l / 2 + 0.25))
			Part(f.StreetProps, "SpeedLaneEdge", edge, CFrame.new(cx, y + 0.02, cz) + off, YELLOW, M.SmoothPlastic, { collide = false, cast = false })
		end
		-- chevrons
		local n = math.floor(math.max(w, l) / 9)
		for k = 0, n - 1 do
			local t = (k + 0.5) / n
			local p = alongZ and Vector3.new(cx, y + 0.04, r[3] + t * l) or Vector3.new(r[1] + t * w, y + 0.04, cz)
			for _, s in ipairs({ -1, 1 }) do
				local rot = alongZ and CFrame.Angles(0, s * math.rad(40), 0) or CFrame.Angles(0, math.rad(90) + s * math.rad(40), 0)
				local off = alongZ and Vector3.new(s * 1.4, 0, 0) or Vector3.new(0, 0, s * 1.4)
				local ch = Part(f.StreetProps, "Chevron", Vector3.new(0.8, 0.06, 4.2), CFrame.new(p + off) * rot, YELLOW, M.Neon, { collide = false, cast = false })
				ch:SetAttribute("Phase", t)
				CollectionService:AddTag(ch, "SpeedChevron")
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
		Part(f.ZoneGates, "FenceNeon", Vector3.new(len, 0.6, 4.4), CFrame.new(s * (gw + len / 2), 10.3, gz), pal.accent, M.Neon, { collide = false })
		Part(f.ZoneGates, "GatePillar", Vector3.new(4, 20, 5), CFrame.new(s * (gw + 2), 10, gz), C(30, 34, 46), M.Metal)
	end
	local beam = Part(f.ZoneGates, "GateBeam", Vector3.new(2 * gw + 8, 4, 5), CFrame.new(0, 22, gz), C(20, 22, 32), M.Metal)
	Label(beam, Enum.NormalId.Front, zone.name, pal.accent)
	Label(beam, Enum.NormalId.Back, zone.name, pal.accent)
	local barrier = Part(f.ZoneGates, "GateBarrier_" .. zone.id, Vector3.new(2 * gw, 20, 1.5), CFrame.new(0, 10, gz), C(255, 60, 60), M.Neon, { t = 0.5 })
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
		Part(f.ZoneGates, "EntryFenceNeon", Vector3.new(len, 0.5, 3.4), CFrame.new(s * (ow + len / 2), 8.2, ez + 1.5), pal.accent, M.Neon, { collide = false })
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
		if zid == "neon" then
			Part(f.StreetProps, "NeonEdge", Vector3.new(2 * HW, 0.15, 0.3), CFrame.new(0, 0.86, z0 + s * (W / 2 + 0.2)), pal.accent, M.Neon, { collide = false, cast = false })
		end
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
			Prefabs.HoloRing(f.StreetProps, Vector3.new(x, 16, z0), (x % 160 == 0) and pal.accent or pal.accent2, 12)
		end
	end
	if zid == "highway" then
		for _, s in ipairs({ -1, 1 }) do
			local x = s * 75
			Part(f.Buildings, "OverpassDeck", Vector3.new(14, 2, W + 28), CFrame.new(x, 16, z0), C(150, 154, 162), M.Concrete)
			Part(f.Buildings, "OverpassRailA", Vector3.new(0.6, 1.4, W + 28), CFrame.new(x - 6.7, 17.7, z0), pal.accent, M.Neon, { collide = false })
			Part(f.Buildings, "OverpassRailB", Vector3.new(0.6, 1.4, W + 28), CFrame.new(x + 6.7, 17.7, z0), pal.accent, M.Neon, { collide = false })
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
		Part(f.Ground, "BlockPathEdge", Vector3.new(0.8, 0.16, depth), CFrame.new(s * 13.4, 0.08, (zA + zB) / 2), (zid == "neon") and pal.accent or C(250, 246, 238), (zid == "neon") and M.Neon or M.Concrete, { collide = false, cast = false })
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
			Part(f.StreetProps, "NeonPost", Vector3.new(0.8, 6, 0.8), CFrame.new(x, 3.4, z), pal.curb, M.Metal)
			Part(f.StreetProps, "NeonOrb", Vector3.new(1.8, 1.8, 1.8), CFrame.new(x, 6.8, z), pick(rng, { pal.accent, pal.accent2 }), M.Neon, { shape = Enum.PartType.Ball, collide = false })
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
		for _, s in ipairs({ -1, 1 }) do
			Part(f.StreetProps, "NeonArchPillar", Vector3.new(2, 18, 2), CFrame.new(s * 42, 9, zc), C(20, 30, 50), M.Metal)
			Part(f.StreetProps, "NeonArchGlow", Vector3.new(0.5, 18, 0.5), CFrame.new(s * 42 - s * 1.1, 9, zc), pal.accent, M.Neon, { collide = false })
		end
		Part(f.StreetProps, "NeonArchTop", Vector3.new(86, 2, 3), CFrame.new(0, 19, zc), C(20, 30, 50), M.Metal)
		Part(f.StreetProps, "NeonArchTopGlow", Vector3.new(86, 0.5, 3.4), CFrame.new(0, 17.8, zc), pal.accent2, M.Neon, { collide = false })
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
		local p = Part(f.PartSpawnPoints, string.format("SP_%s_%s_%02d", zid, risk, idc), Vector3.new(2, 0.4, 2), CFrame.new(x, y + 0.2, z), (risk == "risky") and C(255, 80, 80) or C(80, 255, 140), M.Neon, { t = 0.85, collide = false })
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
	elseif zid == "neon" then
		for k = 1, 6 do
			Prefabs.HoloRing(f.StreetProps, Vector3.new(((k % 2 == 0) and 1 or -1) * rr(ctx.rng, 20, 80), rr(ctx.rng, 24, 40), zone.zMin + k * 48), (k % 2 == 0) and pal.accent or pal.accent2, rr(ctx.rng, 10, 18))
		end
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
