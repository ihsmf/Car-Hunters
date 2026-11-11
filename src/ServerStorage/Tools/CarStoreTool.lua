-- Installs real car models from the Roblox Creator Store (free models) into ReplicatedStorage.CarModels.
-- Run in Studio (edit mode), View > Command Bar:
--   require(game.ServerStorage.Tools.CarStoreTool).InstallAll()
--   require(game.ServerStorage.Tools.CarStoreTool).Install("bmv_m3", 2629351758)   -- any other asset id
-- Every model is stripped of scripts, sounds, GUIs, seats logic, welds and constraints before it is used.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarConfig = require(Shared:WaitForChild("CarConfig"))

local Tool = {}

-- candidates are tried in order until one loads and looks like a car
Tool.Candidates = {
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

local function load(id)
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
			elseif d.Transparency >= 0.99 and not d:FindFirstChildWhichIsA("Decal") then
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

---------------------------------------------------------------- wheels
-- Store cars often keep their visible wheels in transparent collider parts or spawn them from chassis
-- scripts (which we strip). We remember where the wheels are and rebuild any wheel that is missing.
local WHEEL_NAMES = { "^fl$", "^fr$", "^rl$", "^rr$", "^lf$", "^rf$", "^lr$", "^wheel", "^tire", "^tyre", "^rim", "wheel$" }

local function isWheelName(n)
	n = string.lower(n)
	for _, pat in ipairs(WHEEL_NAMES) do
		if string.find(n, pat) then
			return true
		end
	end
	return false
end

local function wheelCandidates(car)
	local out = {}
	for _, d in ipairs(car:GetDescendants()) do
		if d:IsA("BasePart") then
			local named = isWheelName(d.Name) or (d.Parent and isWheelName(d.Parent.Name))
			local sz = d.Size
			local dims = { sz.X, sz.Y, sz.Z }
			table.sort(dims)
			local roundish = dims[3] > 0.6 and dims[2] / dims[3] > 0.8 and dims[1] < dims[3] * 0.85
			if named and roundish then
				local pos = d.Position
				local merged = false
				for _, w in ipairs(out) do
					if (w.pos - pos).Magnitude < dims[3] * 0.6 then
						w.r = math.max(w.r, dims[3] / 2)
						merged = true
						break
					end
				end
				if not merged then
					table.insert(out, { pos = pos, r = dims[3] / 2 })
				end
			end
		end
	end
	return out
end

local function guessWheels(car, forward)
	local bb, size = car:GetBoundingBox()
	local f = forward
	local right = f:Cross(Vector3.yAxis).Unit
	local len = math.abs(size:Dot(Vector3.new(math.abs(f.X), 0, math.abs(f.Z))))
	local wid = math.abs(size:Dot(Vector3.new(math.abs(right.X), 0, math.abs(right.Z))))
	local r = math.clamp(size.Y * 0.2, 0.9, 2.2)
	local bottom = bb.Position.Y - size.Y / 2
	local out = {}
	for _, a in ipairs({ 0.33, -0.33 }) do
		for _, s in ipairs({ -1, 1 }) do
			local p = Vector3.new(bb.Position.X, bottom + r, bb.Position.Z) + f * (len * a) + right * s * (wid / 2 - r * 0.45)
			table.insert(out, { pos = p, r = r })
		end
	end
	return out
end

local function hasVisibleAt(car, pos, r)
	for _, d in ipairs(car:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.9 and d.Name ~= "AddedWheel" then
			local lp = d.CFrame:PointToObjectSpace(pos)
			local h = d.Size / 2
			local m = r * 0.35
			if math.abs(lp.X) <= h.X + m and math.abs(lp.Y) <= h.Y + m and math.abs(lp.Z) <= h.Z + m then
				local dims = { d.Size.X, d.Size.Y, d.Size.Z }
				table.sort(dims)
				-- wheel-sized: not a thin trim strip, not the whole body shell whose box covers the arch
				if dims[2] >= r * 0.9 and dims[3] <= r * 4 then
					return true
				end
			end
		end
	end
	return false
end

local function addWheel(car, pos, r, right)
	local folder = car:FindFirstChild("AddedWheels") or Instance.new("Model")
	folder.Name = "AddedWheels"
	folder.Parent = car
	local axis = CFrame.lookAt(pos, pos + right) * CFrame.Angles(0, math.rad(90), 0) -- cylinder X axis = right
	local function cyl(name, d, w, color, mat, off)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(w, d, d)
		p.CFrame = axis * CFrame.new(off or 0, 0, 0)
		p.Color = color
		p.Material = mat
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = true, false, false, false, true
		p.Parent = folder
		return p
	end
	local w = math.max(0.7, r * 0.75)
	cyl("Tire", r * 2, w, Color3.fromRGB(24, 24, 28), Enum.Material.SmoothPlastic)
	cyl("Rim", r * 1.3, w + 0.06, Color3.fromRGB(196, 200, 208), Enum.Material.Metal)
	cyl("Hub", r * 0.45, w + 0.12, Color3.fromRGB(60, 62, 70), Enum.Material.Metal)
end

-- returns how many wheels had to be rebuilt
local function ensureWheels(car, forward, known)
	local right = forward:Cross(Vector3.yAxis).Unit
	local wheels = (known and #known >= 3) and known or guessWheels(car, forward)
	local added = 0
	for _, w in ipairs(wheels) do
		if not hasVisibleAt(car, w.pos, w.r) then
			addWheel(car, w.pos, w.r, right)
			added = added + 1
		end
	end
	return added
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
	-- markers survive sanitize/normalize so wheel positions stay in the car's own frame
	for _, w in ipairs(wheelCandidates(car)) do
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
	local added = ensureWheels(car, Vector3.new(0, 0, -1), known)
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
			local n = ensureWheels(m, flat(fwd), nil)
			if n > 0 then
				fixed = fixed + 1
				print(string.format("[CarStore] %s: rebuilt %d wheels", m.Name, n))
			end
		end
	end
	print(string.format("[CarStore] FixWheels done, %d models repaired", fixed))
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
