-- Offline check of the store cars' own wheels (same rules as CarStoreTool.DetectWheels):
--   lune run tools/wheel_report.luau            -> one line per car: source, wheels found, verdict
-- A-Chassis cars: Wheels/<FL,FR,RL,RR> hubs (often invisible colliders) whose visible descendants are the real wheel.
-- Others: visible parts named wheel/tire/tyre/rim, grouped by position. Otherwise the wheels are part of the body mesh.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local function visible(p)
	return p:IsA("BasePart") and p.Transparency < 0.99
end
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

local function pickCar(objs)
	local holder = roblox.Instance.new("Model")
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
	return car, seat
end

local function detect(car)
	local wheels = car:FindFirstChild("Wheels", true)
	if wheels and (wheels:IsA("Model") or wheels:IsA("Folder")) then
		local n, sizes = 0, {}
		for _, c in ipairs(wheels:GetChildren()) do
			local vis = 0
			local maxd = 0
			local function add(p)
				vis += 1
				maxd = math.max(maxd, p.Size.Y, p.Size.Z, p.Size.X)
			end
			if visible(c) then
				add(c)
			end
			for _, d in ipairs(c:GetDescendants()) do
				if visible(d) then
					add(d)
				end
			end
			if vis > 0 then
				n += 1
				table.insert(sizes, string.format("%.1f", maxd))
			end
		end
		return "achassis", n, table.concat(sizes, "/")
	end
	local clusters = {}
	for _, d in ipairs(car:GetDescendants()) do
		if visible(d) and (wheelName(d.Name) or (d.Parent and wheelName(d.Parent.Name))) then
			local p = d.CFrame.Position
			local found = false
			for _, c in ipairs(clusters) do
				if (c - p).Magnitude < 2.5 then
					found = true
					break
				end
			end
			if not found then
				table.insert(clusters, p)
			end
		end
	end
	if #clusters >= 3 then
		return "named", #clusters, ""
	end
	return "baked", 0, ""
end

local src = fs.readFile("src/ServerStorage/Tools/CarStoreTool.lua")
local block = string.match(src, "Tool%.Candidates = (%b{})")
local bad = {}
for carId, list in string.gmatch(block, "([%w_]+) = (%b{})") do
	local verdict = "NO FILE"
	for id in string.gmatch(list, "%d+") do
		local path = "assets/rbxm/" .. id .. ".rbxm"
		if fs.isFile(path) then
			local ok, objs = pcall(roblox.deserializeModel, fs.readFile(path))
			if ok then
				local car = pickCar(objs)
				local srcKind, n, sizes = detect(car)
				local good = (srcKind == "achassis" and n >= 4) or srcKind == "named" or srcKind == "baked"
				verdict = string.format("%-9s wheels=%d %s  asset %s %s", srcKind, n, sizes, id, good and "OK" or "BAD")
				if good then
					break
				end
			end
		end
	end
	print(string.format("%-22s %s", carId, verdict))
	if not string.find(verdict, "OK") then
		table.insert(bad, carId)
	end
end
print("needs another candidate:", table.concat(bad, ", "))
