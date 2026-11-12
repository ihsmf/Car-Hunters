-- Wheel detection / repair shared by CarStoreTool (install time) and VehicleFactory (every spawn).
-- Store cars often lose their wheels (transparent collider parts, chassis scripts); this puts real-looking
-- wheels back wherever a wheel should be and nothing visible is there.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local WheelKit = {}

local NAMES = { "^fl$", "^fr$", "^rl$", "^rr$", "^lf$", "^rf$", "^lr$", "wheel", "^tire", "^tyre", "^rim" }

function WheelKit.IsWheelName(n)
	n = string.lower(n)
	for _, pat in ipairs(NAMES) do
		if string.find(n, pat) then
			return true
		end
	end
	return false
end

local function sorted(sz)
	local d = { sz.X, sz.Y, sz.Z }
	table.sort(d)
	return d
end

-- centres of wheel-like named parts (merged when close), radius from the biggest part
function WheelKit.Candidates(root)
	local out = {}
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			local named = WheelKit.IsWheelName(d.Name) or (d.Parent and WheelKit.IsWheelName(d.Parent.Name))
			local dims = sorted(d.Size)
			local roundish = dims[3] > 0.6 and dims[2] / dims[3] > 0.8 and dims[1] < dims[3] * 0.85
			if named and roundish then
				local merged = false
				for _, w in ipairs(out) do
					if (w.pos - d.Position).Magnitude < math.max(w.r, dims[3] / 2) * 1.2 then
						w.r = math.max(w.r, dims[3] / 2)
						merged = true
						break
					end
				end
				if not merged then
					table.insert(out, { pos = d.Position, r = dims[3] / 2 })
				end
			end
		end
	end
	return out
end

-- 4 wheel spots from the bounding box; forward = unit vector of the long axis
function WheelKit.Guess(model, forward)
	local bb, size = model:GetBoundingBox()
	local right = forward:Cross(Vector3.yAxis).Unit
	local len = math.abs(size:Dot(Vector3.new(math.abs(forward.X), 0, math.abs(forward.Z))))
	local wid = math.abs(size:Dot(Vector3.new(math.abs(right.X), 0, math.abs(right.Z))))
	local r = math.clamp(size.Y * 0.21, 0.6, len * 0.12)
	local bottom = bb.Position.Y - size.Y / 2
	local out = {}
	for _, a in ipairs({ 0.32, -0.32 }) do
		for _, s in ipairs({ -1, 1 }) do
			local p = Vector3.new(bb.Position.X, bottom + r, bb.Position.Z) + forward * (len * a) + right * s * (wid / 2 - r * 0.42)
			table.insert(out, { pos = p, r = r })
		end
	end
	return out
end

-- is there a visible wheel-sized part around pos?
function WheelKit.HasVisibleAt(model, pos, r)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.9 and d.Name ~= "Root" then
			local lp = d.CFrame:PointToObjectSpace(pos)
			local h = d.Size / 2
			local m = r * 0.35
			if math.abs(lp.X) <= h.X + m and math.abs(lp.Y) <= h.Y + m and math.abs(lp.Z) <= h.Z + m then
				local dims = sorted(d.Size)
				if dims[2] >= r * 0.9 and dims[3] <= r * 4 then
					return true
				end
			end
		end
	end
	return false
end

local function part(parent, name, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	if shape then
		p.Shape = shape
	end
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = true, false, false, false, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- one wheel: Blender tire (PartModels.Part_tire) if loaded, else tire + rim + 5 spokes + hub
function WheelKit.Add(model, pos, r, right)
	local folder = model:FindFirstChild("AddedWheels") or Instance.new("Model")
	folder.Name = "AddedWheels"
	folder.Parent = model
	local axis = CFrame.lookAt(pos, pos + right) * CFrame.Angles(0, math.rad(90), 0) -- part X axis = right
	local pm = ReplicatedStorage:FindFirstChild("PartModels")
	local tpl = pm and pm:FindFirstChild("Part_tire")
	if tpl then
		local w = tpl:Clone()
		local _, ext = w:GetBoundingBox()
		w:ScaleTo(w:GetScale() * (r * 2) / math.max(ext.Y, 0.01))
		-- imported Blender wheel: axle along its Z axis, pivot at the contact point
		w:PivotTo(CFrame.lookAt(pos, pos + right) * CFrame.new(0, -r, 0))
		for _, d in ipairs(w:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Name = "AddedWheel"
				d.Anchored, d.CanCollide, d.CanTouch, d.CanQuery, d.Massless = true, false, false, false, true
			end
		end
		w.Parent = folder
		return
	end
	local w = math.max(0.6, r * 0.7)
	local CYL = Enum.PartType.Cylinder
	part(folder, "AddedWheel", Vector3.new(w, r * 2, r * 2), axis, Color3.fromRGB(24, 24, 28), Enum.Material.SmoothPlastic, CYL)
	part(folder, "AddedWheel", Vector3.new(w + 0.04, r * 1.32, r * 1.32), axis, Color3.fromRGB(196, 200, 208), Enum.Material.Metal, CYL)
	part(folder, "AddedWheel", Vector3.new(w + 0.08, r * 1.1, r * 1.1), axis, Color3.fromRGB(40, 42, 48), Enum.Material.Metal, CYL)
	for k = 0, 4 do -- spokes poke out of the dark dish on both faces
		local a = k / 5 * math.pi * 2
		part(folder, "AddedWheel", Vector3.new(w + 0.12, r * 0.6, r * 0.14), axis * CFrame.Angles(a, 0, 0) * CFrame.new(0, r * 0.33, 0),
			Color3.fromRGB(210, 214, 222), Enum.Material.Metal)
	end
	part(folder, "AddedWheel", Vector3.new(w + 0.16, r * 0.42, r * 0.42), axis, Color3.fromRGB(70, 72, 80), Enum.Material.Metal, CYL)
end

-- fills every empty wheel spot; spots = { {pos, r} } or nil (guessed). Returns how many were added.
function WheelKit.Ensure(model, forward, spots)
	local right = forward:Cross(Vector3.yAxis).Unit
	spots = (spots and #spots >= 3) and spots or WheelKit.Guess(model, forward)
	local added = 0
	for _, w in ipairs(spots) do
		if not WheelKit.HasVisibleAt(model, w.pos, w.r) then
			WheelKit.Add(model, w.pos, w.r, right)
			added = added + 1
		end
	end
	return added
end

-- wheel spots are saved on the template relative to its bounding-box centre
function WheelKit.Save(model, spots)
	local bb = model:GetBoundingBox()
	local t = {}
	for _, w in ipairs(spots) do
		local o = w.pos - bb.Position
		table.insert(t, { o.X, o.Y, o.Z, w.r })
	end
	model:SetAttribute("Wheels", HttpService:JSONEncode(t))
end

function WheelKit.Load(model, scale)
	local raw = model:GetAttribute("Wheels")
	if type(raw) ~= "string" then
		return nil
	end
	local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(t) ~= "table" then
		return nil
	end
	local bb = model:GetBoundingBox()
	local out = {}
	for _, w in ipairs(t) do
		table.insert(out, { pos = bb.Position + Vector3.new(w[1], w[2], w[3]) * scale, r = w[4] * scale })
	end
	return out
end

return WheelKit
