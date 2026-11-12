-- Installs real car models from the Roblox Creator Store (free models) into ReplicatedStorage.CarModels.
-- Run in Studio (edit mode), View > Command Bar:
--   require(game.ServerStorage.Tools.CarStoreTool).InstallAll()
--   require(game.ServerStorage.Tools.CarStoreTool).Install("bmv_m3", 2629351758)   -- any other asset id
-- Every model is stripped of scripts, sounds, GUIs, seats logic, welds and constraints before it is used.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarConfig = require(Shared:WaitForChild("CarConfig"))
local WheelKit = require(Shared:WaitForChild("WheelKit"))

local Tool = {}

-- candidates are tried in order until one loads and looks like a car
Tool.Candidates = {
	lamborgini_uroos = { 5145872883 },
	ferarri_romma = { 15340193334 },
	rimak_nevara = { 8012562725, 7241154110 },
	hunda_jazzy = { 13200015838, 10827323038, 8076000678 },
	toyoda_korolla = { 13502579667, 17061648891, 12744369162 },
	nisan_mikra = { 15600763990, 14890692638, 13486163316 },
	kia_soal = { 108421174315791, 17354859552, 4461667186 },
	hyunday_elantro = { 16199951681, 15795666461, 862662444 },
	skodda_oktavia = { 3468009642, 17396395801, 16213430066 },
	shevy_spork = { 110188707393448, 16322614523, 11555325165 },
	volvoo_240 = { 5444945288, 5234091517 },
	toyoda_takoma = { 16618504690, 15783188346, 8764904616 },
	furd_brongo = { 1347328851, 2830914971 },
	hunda_akkord = { 13182155390, 13168066800, 11355256329 },
	volksvagen_bitle = { 136697663661166, 17259216046, 14990485245 },
	awdi_tt = { 17387944029, 15351427154, 10728717447 },
	lexxus_is = { 4385685394, 15678584948, 15234918018 },
	dodje_ramm = { 4049059151, 5921725742, 4034471434 },
	mitsubishy_evo = { 4595734476, 5196549533, 18145868673 },
	nisan_350z = { 5232405704, 134415455060063, 106665221467840 },
	kadillak_eskalade = { 123373084236456, 96104222379691, 85724115853594 },
	toyoda_landkruiser = { 116150803764919, 16615382339, 16262264263 },
	shelbi_kobra = { 17247353591, 17247351834, 17247347813 },
	pontiak_firebyrd = { 15623579806, 11149321256, 9734187152 },
	porshe_kayen = { 72050021754521, 11065956984, 8891456182 },
	mursides_amg = { 17502702727, 11842943363 },
	porshe_taykun = { 10941247427, 8623478043, 6991417619 },
	maklaren_720 = { 10743564799, 9462000605, 8033912611 },
	awdi_rs6 = { 110824542790869, 13688270910 },
	bentli_bentaiga = { 2059545883, 1491636091, 1074220268 },
	mursides_maibah = { 18898395160, 15307766180, 5179619275 },
	bugati_veiron = { 14160369856, 2524280322 },
	konigseg_jesko = { 18183642086, 17102743398, 14862893024 },
	ferarri_sf90 = { 5004337547 },
	maklaren_senna = { 10561892435, 8990440873, 5242568472 },
	pagany_huayrar = { 17183547478 },
	furd_fiasta = { 9715203503, 2868061330, 18256318351 },
	dodje_caravon = { 13197361329, 10942518460, 3260240120 },
	furd_f150 = { 17363327771, 89473521929489, 1091718142 },
	awdi_a4 = { 5608247129, 14577468462, 9411902978 },
	bmv_m3 = { 2629351758, 18559910789, 559395372 },
	mursides_e = { 8983899769, 2234209839, 4246809329 },
	tezla_model3 = { 5533424135, 9636897495, 4273602171 },
	jagwar_xe = { 1342440736, 1168793222, 11489907932 },
	furd_mustank = { 80783119829510, 2434393319, 116437016801875 },
	dodje_chalenjer = { 17452916832, 87504685753483, 546719174 },
	ranje_rover = { 14494942334, 10346868084, 386870784 },
	bmv_m4 = { 456372240, 455509902, 8647497974 },
	mursides_g = { 5141153317, 3517630561, 388473450, 12417184981 },
	awdi_r8 = { 8602130629, 628685251, 13753737483 },
	jagwar_ftype = { 2530172512, 589271703, 1305991484 },
	mazeratti_gt = { 4677306825, 510958100 },
	lamborgini_hurakan = { 13433799896, 92297472161035, 4456143600 },
	tezla_cybertrak = { 136681441105471, 12200222920, 10361152289 },
	mazeratti_mc20 = { 14282739597 },
	lamborgini_aventadoor = { 2787504744, 4495946534, 9753931902 },
	fiat_500 = { 1446854762, 4055888782, 5786113166 },
	mini_kooper = { 14465164281, 135059927696153 },
	volksvagen_gulf = { 12542198125, 82972357827322, 12807183490 },
	hunda_civik = { 2571079042, 10753971734, 10139279759 },
	jeap_rangler = { 2748312119, 10573783400, 52157214 },
	mazta_miyata = { 5095053688, 1776760727, 9118871604 },
	subaroo_wrx = { 1953105410, 123452315605219, 4393841354 },
	chevy_kamaro = { 1276268362, 361548474, 5020073007 },
	toyoda_supera = { 1853520893, 2571329549, 10414041874 },
	chevy_korvette = { 604889148, 4540718723, 549532394 },
	nisan_gtr = { 596656603, 243678092, 6644477428 },
	porshe_911 = { 6819942574, 283275641 },
	bentli_kontinental = { 10920415502, 691546254 },
	rolz_fantom = { 3707576321, 5584324966 },
	maklaren_p1 = { 8695066469 },
	ferarri_488 = { 454327510, 113588555963194, 1515769333 },
	ferarri_laferarri = { 337455034, 6837694408, 1381731876 },
	pagany_wyra = { 187020840, 606416446, 123347626205332 },
	konigseg_agera = { 3011730839, 121340003816190, 1951424848 },
	bugati_shiron = { 931219474, 2654621102, 2524280322 },
}

Tool.MaxParts = 450

local KEEP = { "BasePart", "Model", "Folder", "DataModelMesh", "Decal", "Texture", "SurfaceAppearance" }

local function keep(inst)
	for _, class in ipairs(KEEP) do
		if inst:IsA(class) then
			return true
		end
	end
	return false
end

-- assets embedded into the place by tools/bake_models.luau: ServerStorage.Embedded.Assets.A<id>
local function embedded(id)
	local e = game:GetService("ServerStorage"):FindFirstChild("Embedded")
	local a = e and e:FindFirstChild("Assets")
	return a and a:FindFirstChild("A" .. tostring(id))
end
Tool.Embedded = embedded

local function load(id)
	local emb = embedded(id)
	if emb then
		local out = {}
		for _, c in ipairs(emb:GetChildren()) do
			table.insert(out, c:Clone())
		end
		if #out > 0 then
			return out
		end
	end
	local ok, res = pcall(function()
		return game:GetObjects("rbxassetid://" .. id)
	end)
	if ok and res and #res > 0 then
		return res
	end
	local ok2, res2 = pcall(function()
		return InsertService:LoadAsset(id)
	end)
	if ok2 and res2 then
		return res2:GetChildren()
	end
	return nil, tostring(ok and res2 or res)
end

-- the car = top-level model that contains a VehicleSeat; otherwise everything that was loaded
local function pickCar(objs)
	local holder = Instance.new("Model")
	for _, o in ipairs(objs) do
		o.Parent = holder
	end
	local seat = holder:FindFirstChildWhichIsA("VehicleSeat", true)
	local car = holder
	if seat then
		local top = seat
		while top.Parent ~= holder do
			top = top.Parent
		end
		if top:IsA("Model") then
			car = top
		end
	end
	return car, seat, holder
end

-- chassis scripts often show wheel meshes only at runtime: keep wheel-named parts that carry a real mesh
local function hiddenWheelMesh(d)
	local named = WheelKit.IsWheelName(d.Name) or (d.Parent and WheelKit.IsWheelName(d.Parent.Name))
	if not named then
		return false
	end
	local mesh = d:FindFirstChildWhichIsA("SpecialMesh") or d:FindFirstChildWhichIsA("FileMesh")
	local hasMesh = (d:IsA("MeshPart") and d.MeshId ~= "") or (mesh and mesh.MeshId ~= "")
	if hasMesh then
		d.Transparency = 0
		return true
	end
	return false
end

local function sanitize(car)
	local parts = 0
	for _, d in ipairs(car:GetDescendants()) do
		if not keep(d) then
			d:Destroy()
		end
	end
	for _, d in ipairs(car:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.Name == "WheelMarker" then
				d.CanCollide = false
			elseif d.Transparency >= 0.99 and not d:FindFirstChildWhichIsA("Decal") and not (hiddenWheelMesh(d)) then
				d:Destroy() -- hitboxes, wheel colliders, seat blocks
			else
				d.Anchored = true
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
				d.Massless = true
				if d:IsA("Seat") or d:IsA("VehicleSeat") then
					d.Disabled = true
				end
				parts = parts + 1
			end
		end
	end
	return parts
end

---------------------------------------------------------------- wheels (see Shared/WheelKit.lua)
local function ensureWheels(car, forward, known)
	return WheelKit.Ensure(car, forward, known)
end

local function flat(v)
	local f = Vector3.new(v.X, 0, v.Z)
	return f.Magnitude > 0.01 and f.Unit or Vector3.new(0, 0, -1)
end

-- rotate so the nose points to -Z (VehicleFactory then maps the long axis to +X)
local function normalize(car, forward)
	car.PrimaryPart = nil
	local bb = car:GetBoundingBox()
	car.WorldPivot = CFrame.lookAt(bb.Position, bb.Position + forward)
	car:PivotTo(CFrame.new(0, 20, 0))
	local _, size = car:GetBoundingBox()
	return size
end

function Tool.Install(carId, assetId, yaw)
	local def = CarConfig.ById[carId]
	if not def then
		warn("[CarStore] unknown car id: " .. tostring(carId))
		return false
	end
	local objs, err = load(assetId)
	if not objs then
		warn(string.format("[CarStore] %s: asset %s did not load (%s)", carId, tostring(assetId), tostring(err)))
		return false
	end
	local car, seat, holder = pickCar(objs)
	local forward = seat and flat(seat.CFrame.LookVector) or Vector3.new(0, 0, -1)
	-- wheels kept in a sibling model (outside the seat's model) belong to the car too
	if holder ~= car then
		for _, o in ipairs(holder:GetChildren()) do
			if o ~= car and (WheelKit.IsWheelName(o.Name) or #WheelKit.Candidates(o) > 0) then
				o.Parent = car
			end
		end
	end
	-- markers survive sanitize/normalize so wheel positions stay in the car's own frame
	for _, w in ipairs(WheelKit.Candidates(car)) do
		local mk = Instance.new("Part")
		mk.Name = "WheelMarker"
		mk.Size = Vector3.one * 0.2
		mk.Position = w.pos
		mk.Anchored = true
		mk.Transparency = 0.5
		mk:SetAttribute("R", w.r)
		mk.Parent = car
	end
	local parts = sanitize(car)
	if parts == 0 then
		holder:Destroy()
		warn(string.format("[CarStore] %s: asset %s has no visible parts", carId, tostring(assetId)))
		return false
	end
	local size = normalize(car, forward)
	if not seat and size.X > size.Z then -- no seat to tell the direction: at least align the long axis
		normalize(car, Vector3.new(1, 0, 0))
		_, size = car:GetBoundingBox()
	end
	local known = {}
	for _, mk in ipairs(car:GetChildren()) do
		if mk.Name == "WheelMarker" then
			table.insert(known, { pos = mk.Position, r = mk:GetAttribute("R") })
			mk:Destroy()
		end
	end
	local spots = (#known >= 3) and known or WheelKit.Guess(car, Vector3.new(0, 0, -1))
	local added = ensureWheels(car, Vector3.new(0, 0, -1), spots)
	WheelKit.Save(car, spots)
	local len, wid = size.Z, size.X
	if len / math.max(wid, 0.1) < 1.4 or len / math.max(wid, 0.1) > 4.5 or len / math.max(size.Y, 0.1) < 1.5 or parts > Tool.MaxParts then
		holder:Destroy()
		warn(string.format("[CarStore] %s: asset %s rejected (%.0fx%.0fx%.0f studs, %d parts)", carId, tostring(assetId), len, wid, size.Y, parts))
		return false
	end
	local root = ReplicatedStorage:FindFirstChild("CarModels")
	if not root then
		root = Instance.new("Folder")
		root.Name = "CarModels"
		root.Parent = ReplicatedStorage
	end
	local old = root:FindFirstChild(carId)
	if old then
		old:Destroy()
	end
	car.Name = carId
	car:SetAttribute("Yaw", yaw or 0)
	car:SetAttribute("Recolor", false)
	car:SetAttribute("CarName", def.name)
	car:SetAttribute("Rarity", def.rarity)
	car:SetAttribute("StoreAssetId", tostring(assetId))
	car.Parent = root
	if holder ~= car then
		holder:Destroy()
	end
	print(string.format("[CarStore] %-22s <- asset %s  (%d parts%s)", carId, tostring(assetId), parts, added > 0 and (", rebuilt " .. added .. " wheels") or ""))
	return true
end

local running = false

-- runs in the background: the Command Bar returns at once, progress is printed to Output
function Tool.InstallAll()
	if running then
		print("[CarStore] already running, watch the Output window")
		return
	end
	running = true
	print("[CarStore] started in background - this takes a few minutes, progress is in Output. Do not stop the play/edit session.")
	task.spawn(function()
		local ok, err = pcall(Tool.InstallAllNow)
		running = false
		if not ok then
			warn("[CarStore] failed: " .. tostring(err))
		end
	end)
end

-- server start: every car that has no model yet is installed from the assets embedded in the place
-- (no downloads, works in an unpublished place and in the live game)
function Tool.InstallMissingEmbedded()
	local root = ReplicatedStorage:FindFirstChild("CarModels")
	local done = 0
	for _, def in ipairs(CarConfig.List) do
		local cur = root and root:FindFirstChild(def.id)
		if not (cur and cur:FindFirstChildWhichIsA("BasePart", true)) then
			for _, id in ipairs(Tool.Candidates[def.id] or {}) do
				if embedded(id) and Tool.Install(def.id, id) then
					done = done + 1
					break
				end
			end
		end
	end
	return done
end

function Tool.InstallAllNow()
	local done, failed = 0, {}
	for _, def in ipairs(CarConfig.List) do
		local ok = false
		for _, id in ipairs(Tool.Candidates[def.id] or {}) do
			ok = Tool.Install(def.id, id)
			if ok then
				break
			end
		end
		if ok then
			done = done + 1
		else
			table.insert(failed, def.id)
		end
		task.wait()
	end
	print(string.format("[CarStore] installed %d/%d store models", done, #CarConfig.List))
	if #failed > 0 then
		print("[CarStore] kept the previous model for: " .. table.concat(failed, ", "))
	end
	print("[CarStore] check them: require(game.ServerStorage.Tools.CarModelTool).Preview()  - nose must point along +X.")
	print("[CarStore] wrong way round? require(game.ServerStorage.Tools.CarStoreTool).Flip('car_id')")
end

-- repair wheels on models that are already installed (store or Blender)
function Tool.FixWheels()
	local root = ReplicatedStorage:FindFirstChild("CarModels")
	if not root then
		return
	end
	local fixed = 0
	for _, m in ipairs(root:GetChildren()) do
		if m:IsA("Model") and CarConfig.ById[m.Name] then
			local old = m:FindFirstChild("AddedWheels")
			if old then
				old:Destroy()
			end
			local _, size = m:GetBoundingBox()
			local yaw = math.rad(m:GetAttribute("Yaw") or 0)
			local fwd = size.Z >= size.X and Vector3.new(0, 0, -1) or Vector3.new(1, 0, 0)
			fwd = (CFrame.Angles(0, yaw, 0) * CFrame.new(fwd)).Position
			local n = ensureWheels(m, flat(fwd), WheelKit.Load(m, 1))
			if n > 0 then
				fixed = fixed + 1
				print(string.format("[CarStore] %s: rebuilt %d wheels", m.Name, n))
			end
		end
	end
	print(string.format("[CarStore] FixWheels done, %d models repaired", fixed))
end

-- how many wheels each installed car shows (real + rebuilt)
function Tool.WheelReport()
	local root = ReplicatedStorage:FindFirstChild("CarModels")
	for _, m in ipairs(root and root:GetChildren() or {}) do
		if m:IsA("Model") and CarConfig.ById[m.Name] then
			local real = #WheelKit.Candidates(m)
			local added = m:FindFirstChild("AddedWheels") and #m.AddedWheels:GetChildren() or 0
			print(string.format("[CarStore] %-22s wheels found %d, rebuilt parts %d, saved spots %s", m.Name, real, added, m:GetAttribute("Wheels") and "yes" or "no"))
		end
	end
end

function Tool.Flip(carId)
	local root = ReplicatedStorage:FindFirstChild("CarModels")
	local m = root and root:FindFirstChild(carId)
	if m then
		m:SetAttribute("Yaw", ((m:GetAttribute("Yaw") or 0) + 180) % 360)
		print("[CarStore] " .. carId .. " Yaw = " .. m:GetAttribute("Yaw"))
	end
end

return Tool
