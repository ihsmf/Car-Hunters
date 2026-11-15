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
	bmv_x5 = { 8279706011, 16433029079, 12921108207 },
	astin_db11 = { 126653195676594, 1622500043, 4650221396 },
	lamborgini_sian = { 3028907177, 9978931772, 2514843993 },
	astin_valkyry = { 112712673059901, 8898530010, 15912387566 },
	golden_magnat_gt = { 3755485353, 6433330180, 113680197852489 },
	lamborgini_uroos = { 10175247739, 14439525651, 5145872883 },
	ferarri_romma = { 8861089923, 8406803980, 17151937207 },
	rimak_nevara = { 8012562725, 7241154110, 10294081115 },
	hunda_jazzy = { 17727814860, 11152313525, 13200015838 },
	toyoda_korolla = { 15260961760, 17061648891, 12744369162 },
	nisan_mikra = { 9109933681, 15600763990, 8030335411 },
	kia_soal = { 3825123259, 17354859552, 4461667186 },
	hyunday_elantro = { 3781334527, 15795666461, 16199951681 },
	skodda_oktavia = { 4782998363, 14543674593, 3468009642 },
	shevy_spork = { 110188707393448, 9854985826, 3864018536 },
	volvoo_240 = { 16317978924, 8651913823, 12766089627 },
	toyoda_takoma = { 16618504690, 15783188346, 3631732489 },
	furd_brongo = { 1347328851, 9040766098, 2830914971 },
	hunda_akkord = { 9104808136, 13168066800, 3721631739 },
	volksvagen_bitle = { 136697663661166, 5202507457, 8091992065 },
	awdi_tt = { 17387944029, 5182430700, 15046501880 },
	lexxus_is = { 4385685394, 15234918018, 12970780356 },
	dodje_ramm = { 4049059151, 4555527998, 1498064912 },
	mitsubishy_evo = { 4595734476, 11399473372, 2993228252 },
	nisan_350z = { 5232405704, 4994755989, 1898218413 },
	kadillak_eskalade = { 85724115853594, 17583780803, 123373084236456 },
	toyoda_landkruiser = { 116150803764919, 17300567937, 16431614375 },
	shelbi_kobra = { 17630914968, 1944900459, 17247353591 },
	pontiak_firebyrd = { 13032299607, 5193928724, 15623579806 },
	porshe_kayen = { 6724192900, 11065956984, 11051340414 },
	mursides_amg = { 5530022267, 17502702727, 14610943608 },
	porshe_taykun = { 10941247427, 8623478043, 17458737315 },
	maklaren_720 = { 9462000605, 8033912611, 3045988749 },
	awdi_rs6 = { 13226858497, 13688270910, 13776674951 },
	bentli_bentaiga = { 16267027001, 5524902514, 1491636091 },
	mursides_maibah = { 5696256322, 5978695098, 18898395160 },
	bugati_veiron = { 2524280322, 15192203018, 14160369856 },
	konigseg_jesko = { 18183642086, 121354826754403, 4746949741 },
	ferarri_sf90 = { 8155772981, 5004337547, 125623543046525 },
	maklaren_senna = { 10561892435, 8990440873, 5242568472 },
	pagany_huayrar = { 17183547478, 7904060729, 1096332974 },
	furd_fiasta = { 9715203503, 7206982828, 11843888914 },
	dodje_caravon = { 2189496554, 1474163019, 5009107092 },
	furd_f150 = { 2684990975, 2553769670, 5019282828 },
	awdi_a4 = { 925913083, 5608247129, 3596184530 },
	bmv_m3 = { 5345483943, 1246154957, 91350607811717 },
	mursides_e = { 8983899769, 17291252516, 3831215190 },
	tezla_model3 = { 14187840055, 5533424135, 9636897495 },
	jagwar_xe = { 1342440736, 4773975824, 1168793222 },
	furd_mustank = { 121253153949633, 80783119829510, 2434393319 },
	dodje_chalenjer = { 17452916832, 138405532655179, 87504685753483 },
	ranje_rover = { 14494942334, 10346868084, 14363800640 },
	bmv_m4 = { 13675389090, 120350527834673, 137153302707012 },
	mursides_g = { 130141881679290, 5141153317, 2919583384 },
	awdi_r8 = { 6460842628, 8602130629, 12852987735 },
	jagwar_ftype = { 913087698, 1001533863, 2530172512 },
	mazeratti_gt = { 4441217343, 4677306825, 4568311415 },
	lamborgini_hurakan = { 2787411651, 4672696631, 17211618342 },
	tezla_cybertrak = { 4821106773, 4589880300, 16169776439 },
	mazeratti_mc20 = { 9186839859, 7064512139, 5526504712 },
	lamborgini_aventadoor = { 2787504744, 4451439162, 16168398017 },
	fiat_500 = { 1446854762, 4055888782, 10975634300 },
	mini_kooper = { 5617171401, 2741110996, 14465164281 },
	volksvagen_gulf = { 16006083480, 10295038865, 12542198125 },
	hunda_civik = { 1915618441, 2571079042, 10139279759 },
	jeap_rangler = { 2748312119, 122764043739196, 2927641114 },
	mazta_miyata = { 9118871604, 5095053688, 2699421199 },
	subaroo_wrx = { 2301685918, 10122044621, 1953105410 },
	chevy_kamaro = { 86007030654126, 1276268362, 361548474 },
	toyoda_supera = { 1853520893, 2571329549, 12786329366 },
	chevy_korvette = { 10583574430, 4886088618, 604889148 },
	nisan_gtr = { 596656603, 4708295832, 2376988254 },
	porshe_911 = { 6819942574, 1904824296, 4624884815 },
	bentli_kontinental = { 119003203375239, 10920415502, 2405967537 },
	rolz_fantom = { 8732726268, 5491060188, 9096963664 },
	maklaren_p1 = { 8695066469, 5690976603, 12219544955 },
	ferarri_488 = { 4831160779, 92939196915701, 454327510 },
	ferarri_laferarri = { 337455034, 6837694408, 6310233502 },
	pagany_wyra = { 7963925341, 15431885468, 187020840 },
	konigseg_agera = { 3011730839, 9296419444, 1499460631 },
	bugati_shiron = { 84178602199680, 5498081110, 931219474 },
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

local function hasVisibleDescendant(d)
	for _, x in ipairs(d:GetDescendants()) do
		if x:IsA("BasePart") and x.Transparency < 0.99 then
			return true
		end
	end
	return false
end

-- keeps only what is drawn. An invisible part that carries visible parts (A-Chassis wheel hubs: Wheels/FL holds
-- the real tire + rim meshes) stays as an invisible holder - deleting it used to delete the real wheels.
-- Hidden parts are never made visible again (they are alternative rim sets, airbags, colliders).
local function sanitize(car)
	local parts = 0
	for _, d in ipairs(car:GetDescendants()) do
		if not keep(d) then
			d:Destroy()
		end
	end
	for _, d in ipairs(car:GetDescendants()) do
		if d:IsA("BasePart") and d.Parent then
			local hidden = d.Transparency >= 0.99 and not d:FindFirstChildWhichIsA("Decal")
			if hidden and not hasVisibleDescendant(d) then
				d:Destroy() -- hitboxes, colliders, seat blocks, hidden alternative wheel sets
			else
				if hidden then
					d.Transparency = 1
				else
					parts = parts + 1
				end
				d.Anchored = true
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
				d.Massless = true
				if d:IsA("Seat") or d:IsA("VehicleSeat") then
					d.Disabled = true
				end
			end
		end
	end
	return parts
end

-- the car's OWN wheels (same rules as tools/wheel_report.luau). Returns source, count:
--   "achassis": Wheels/<FL,FR,RL,RR> hubs with visible wheel meshes inside
--   "named":    visible parts called wheel/tire/tyre/rim (no steering wheels, airbags, spares), grouped by position
--   "baked":    no separate wheel parts - the wheels are part of the body mesh
local EXCLUDE = { "steer", "airbag", "spare", "detector", "hitbox", "collider" }
local function wheelName(n)
	n = string.lower(n)
	for _, x in ipairs(EXCLUDE) do
		if string.find(n, x, 1, true) then
			return false
		end
	end
	return string.find(n, "wheel", 1, true) or string.find(n, "tire", 1, true) or string.find(n, "tyre", 1, true)
		or string.find(n, "rim", 1, true) or string.find(n, "llanta", 1, true) or string.find(n, "_whl", 1, true)
end

function Tool.DetectWheels(car)
	local wheels = car:FindFirstChild("Wheels", true)
	if wheels and (wheels:IsA("Model") or wheels:IsA("Folder")) then
		local n = 0
		for _, c in ipairs(wheels:GetChildren()) do
			if (c:IsA("BasePart") and c.Transparency < 0.99) or hasVisibleDescendant(c) then
				n = n + 1
			end
		end
		return "achassis", n
	end
	local clusters = {}
	for _, d in ipairs(car:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.99 and (wheelName(d.Name) or (d.Parent and wheelName(d.Parent.Name))) then
			local found = false
			for _, c in ipairs(clusters) do
				if (c - d.Position).Magnitude < 2.5 then
					found = true
					break
				end
			end
			if not found then
				table.insert(clusters, d.Position)
			end
		end
	end
	if #clusters >= 3 then
		return "named", #clusters
	end
	-- unnamed wheel meshes: disc-shaped visible parts (two equal sides, one thin) in the lower half of the car
	local cf, size = car:GetBoundingBox()
	local bottom = cf.Position.Y - size.Y / 2
	local discs = 0
	for _, d in ipairs(car:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.99 then
			local x, y, z = d.Size.X, d.Size.Y, d.Size.Z
			local a, b, c = math.max(x, y, z), math.min(x, y, z), x + y + z - math.max(x, y, z) - math.min(x, y, z)
			if a >= 1.2 and a <= 6 and c / a > 0.9 and b / a < 0.6 and d.Position.Y < bottom + size.Y * 0.5 then
				discs = discs + 1
			end
		end
	end
	if discs >= 4 then
		return "mesh", discs
	end
	return "baked", 0 -- one-piece body mesh (wheels modelled into it)
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
			if o ~= car and (o.Name == "Wheels" or wheelName(o.Name)) then
				o.Parent = car
			end
		end
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
	-- only the model's own wheels: nothing is guessed or added (that made duplicates and wrong sizes)
	local wheelSource, wheelCount = Tool.DetectWheels(car)
	if wheelSource == "baked" then
		-- the model is drawn without separate wheel parts: fine for one-piece meshes, but say so in Output
		warn(string.format("[CarStore] %s: asset %s has no separate wheel parts (one-piece mesh) - check it with CarModelTool.Preview()", carId, tostring(assetId)))
	end
	if wheelSource == "achassis" and wheelCount < 4 then
		holder:Destroy()
		warn(string.format("[CarStore] %s: asset %s rejected (only %d of 4 wheels)", carId, tostring(assetId), wheelCount))
		return false
	end
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
	car:SetAttribute("NoWheelFix", true) -- VehicleFactory must not add wheels: the model has its own
	car:SetAttribute("WheelSource", wheelSource)
	car:SetAttribute("WheelCount", wheelCount)
	car.Parent = root
	if holder ~= car then
		holder:Destroy()
	end
	print(string.format("[CarStore] %-22s <- asset %s  (%d parts, own wheels: %s %d)", carId, tostring(assetId), parts, wheelSource, wheelCount))
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
			task.wait() -- big models: yield between cars so the server start never hits the script timeout
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
			if m:GetAttribute("NoWheelFix") then
				continue -- store model with its own wheels: never add a second set
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
			local src, n = Tool.DetectWheels(m)
			local added = m:FindFirstChild("AddedWheels") and #m.AddedWheels:GetChildren() or 0
			print(string.format("[CarStore] %-22s own wheels: %s %d, added wheel parts %d", m.Name, src, n, added))
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
