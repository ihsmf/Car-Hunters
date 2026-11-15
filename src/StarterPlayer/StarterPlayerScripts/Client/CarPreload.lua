-- Car preloading (v22): reveals must show the car on their first frame.
--  * content: ContentProvider:PreloadAsync downloads the meshes/textures of ReplicatedStorage.CarModels/<id>
--    (owned cars first, then the cars of the rarities the player can realistically catch, rarest first)
--  * templates: VehicleFactory.BuildCar prepares each real model once (clone + ScaleTo + welds, cached in its
--    templateCache under "car:<id>"); warming builds one throw-away clone so the reveal only pays a cheap Clone().
-- Background work is small batches with waits in between; caps per quality level keep phone memory modest.
-- Ensure(defs) does a car right away (a throw result just arrived); Ready(def, timeout) waits for it.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarConfig = require(Shared:WaitForChild("CarConfig"))
local PartConfig = require(Shared:WaitForChild("PartConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local VehicleFactory = require(Shared:WaitForChild("VehicleFactory"))
local Store = require(script.Parent:WaitForChild("StateStore"))

local CarPreload = {}
local loaded = {} -- id -> true: content preloaded (or nothing to download)
local warmed = {} -- id -> true: template prepared (or a procedural car, which has none)
local busy = {} -- id -> true while a priority job handles it
local started = false
local bgWarmed = 0

-- background caps per quality level: { cars whose content is downloaded, templates kept prepared }
local CAPS = { HIGH = { 60, 16 }, MED = { 32, 10 }, LOW = { 16, 5 } }

local perfMod
local function perfLevel()
	if perfMod == nil then
		perfMod = false
		local m = script.Parent:FindFirstChild("Perf")
		if m then
			local ok, P = pcall(require, m)
			if ok and type(P) == "table" and type(P.Level) == "function" then
				perfMod = P
			end
		end
	end
	if perfMod then
		local ok, l = pcall(perfMod.Level)
		if ok and CAPS[l] then
			return l
		end
	end
	return "HIGH"
end

local function realModel(id)
	local folder = ReplicatedStorage:FindFirstChild("CarModels")
	local m = folder and folder:FindFirstChild(id)
	if m and m:IsA("Model") then
		return m
	end
	return nil
end

local function toDef(x)
	if type(x) == "string" then
		return CarConfig.ById[x]
	elseif type(x) == "table" then
		return x.id and CarConfig.ById[x.id] or (x.typeId and CarConfig.ById[x.typeId]) or nil
	end
	return nil
end

-- downloads the content of these car ids (one PreloadAsync call)
local function preload(ids)
	local models, todo = {}, {}
	for _, id in ipairs(ids) do
		if not loaded[id] then
			local m = realModel(id)
			if m then
				table.insert(models, m)
				table.insert(todo, id)
			else
				loaded[id] = true -- procedural car: nothing to download
			end
		end
	end
	if #models > 0 then
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(models)
		end)
		if not ok then
			warn("[CarPreload] " .. tostring(err))
		end
	end
	for _, id in ipairs(todo) do
		loaded[id] = true -- also after a failure: never block a reveal on it
	end
end

-- prepares the VehicleFactory template (cached there); the returned clone is not needed
local function warm(def)
	if warmed[def.id] then
		return
	end
	warmed[def.id] = true
	if not realModel(def.id) then
		return -- procedural fallback: built fresh every time, nothing to cache
	end
	local ok, m = pcall(VehicleFactory.BuildCar, def, { Low = true })
	if ok and typeof(m) == "Instance" then
		m:Destroy() -- a clone of the cached template: destroying it leaves the template untouched
	elseif not ok then
		warn("[CarPreload] " .. tostring(m))
	end
end

local function isReady(id)
	return loaded[id] == true and warmed[id] == true
end

-- priority: these cars now (content and template), on their own thread
function CarPreload.Ensure(list)
	local defs = {}
	for _, x in ipairs(list or {}) do
		local def = toDef(x)
		if def and not busy[def.id] and not isReady(def.id) then
			busy[def.id] = true
			table.insert(defs, def)
		end
	end
	if #defs == 0 then
		return
	end
	local ids = {}
	for _, def in ipairs(defs) do
		table.insert(ids, def.id)
	end
	task.spawn(function()
		preload(ids)
	end)
	task.spawn(function()
		for i, def in ipairs(defs) do
			warm(def)
			if i < #defs then
				task.wait() -- one template per frame: no long hitch for a big batch
			end
		end
		for _, def in ipairs(defs) do
			busy[def.id] = nil
		end
	end)
end

function CarPreload.IsReady(x)
	local def = toDef(x)
	return def == nil or isReady(def.id)
end

-- yields until the car is downloaded and its template is warm, or `timeout` seconds; true = ready
function CarPreload.Ready(x, timeout)
	local def = toDef(x)
	if not def or isReady(def.id) then
		return true
	end
	CarPreload.Ensure({ def })
	local t0 = os.clock()
	local limit = timeout or 2
	while not isReady(def.id) do
		if os.clock() - t0 >= limit then
			return false
		end
		task.wait(0.05)
	end
	return true
end

-- several cars, one shared deadline
function CarPreload.ReadyAll(list, timeout)
	CarPreload.Ensure(list)
	local t0 = os.clock()
	local limit = timeout or 2
	local all = true
	for _, x in ipairs(list or {}) do
		local left = limit - (os.clock() - t0)
		if left <= 0 then
			return CarPreload.AllReady(list)
		end
		all = CarPreload.Ready(x, left) and all
	end
	return all
end

function CarPreload.AllReady(list)
	for _, x in ipairs(list or {}) do
		if not CarPreload.IsReady(x) then
			return false
		end
	end
	return true
end

-- what to prepare in the background: owned cars (rarest first), then every car of the rarities a full throw of the
-- banked parts reaches with a fair chance (rarest first)
local function plan()
	local st = Store.State
	local out, seen = {}, {}
	local function add(def)
		if def and not seen[def.id] then
			seen[def.id] = true
			table.insert(out, def)
		end
	end
	local function rank(def)
		return CarConfig.Rarities[def.rarity] and CarConfig.Rarities[def.rarity].index or 0
	end
	local owned = {}
	for _, c in ipairs(st and st.cars or {}) do
		local def = CarConfig.ById[c.typeId]
		if def then
			table.insert(owned, def)
		end
	end
	table.sort(owned, function(a, b)
		if rank(a) ~= rank(b) then
			return rank(a) > rank(b)
		end
		return a.id < b.id
	end)
	for _, def in ipairs(owned) do
		add(def)
	end
	-- points of the best throw the banked parts allow (rarest parts first, up to the batch limit)
	local stock = {}
	for id, n in pairs(st and st.parts or {}) do
		local p = PartConfig.Parts[id]
		if p and type(n) == "number" and n > 0 then
			table.insert(stock, { pts = p.points, n = n })
		end
	end
	table.sort(stock, function(a, b)
		return a.pts > b.pts
	end)
	local points, left = 0, EconomyConfig.MaxBatch or 50
	for _, s in ipairs(stock) do
		local take = math.min(s.n, left)
		points = points + take * s.pts
		left = left - take
		if left <= 0 then
			break
		end
	end
	local chances = CarConfig.ChancesForPoints(math.max(points, 1))
	for i = #CarConfig.RarityOrder, 1, -1 do
		local r = CarConfig.RarityOrder[i]
		if (chances[r] or 0) >= 4 then
			for _, def in ipairs(CarConfig.ByRarity[r] or {}) do
				add(def)
			end
		end
	end
	return out
end

local function background()
	while not Store.State do
		task.wait(0.5)
	end
	task.wait(3) -- let the join (map, HUD, intro) settle first
	while true do
		local caps = CAPS[perfLevel()]
		local list = plan()
		-- 1) content, 4 cars per PreloadAsync
		local batch = {}
		for i = 1, math.min(#list, caps[1]) do
			local id = list[i].id
			if not loaded[id] and not busy[id] then
				table.insert(batch, id)
				if #batch == 4 then
					preload(batch)
					batch = {}
					task.wait(0.3)
				end
			end
		end
		if #batch > 0 then
			preload(batch)
		end
		-- 2) templates, one at a time with a pause (each is a big clone + rescale)
		for i = 1, #list do
			if bgWarmed >= caps[2] then
				break
			end
			local def = list[i]
			if not warmed[def.id] and not busy[def.id] then
				if realModel(def.id) then
					bgWarmed = bgWarmed + 1
				end
				warm(def)
				task.wait(0.2)
			end
		end
		task.wait(20) -- new cars / parts: look again later (done ids are skipped)
	end
end

function CarPreload.Start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		local ok, err = pcall(background)
		if not ok then
			warn("[CarPreload] background stopped: " .. tostring(err))
		end
	end)
end

return CarPreload
