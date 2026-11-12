-- Shared garage pieces: colour style, parking bay, upper floors. Used by BuildCityMap (ground floor)
-- and BaseService (floors 2-4 are built per owner). No two visible faces share a plane.
local BaseLayout = require(script.Parent:WaitForChild("BaseLayout"))
local MapConfig = require(script.Parent:WaitForChild("MapConfig"))

local C = Color3.fromRGB
local M = Enum.Material
local GarageKit = {}

GarageKit.Style = {
	floor = C(212, 214, 218), inlay = C(60, 63, 70), line = C(242, 242, 240), wall = C(38, 40, 46),
	deck = C(238, 238, 236), frame = C(28, 30, 34), accent = C(255, 196, 40), accent2 = C(214, 52, 44),
	door = C(200, 204, 210), bay = C(80, 84, 92),
}

-- part names -> style key, so a garage skin can recolour a whole garage in one pass
GarageKit.Paint = {
	Floor = "floor", Inlay = "inlay", DriveLine = "line", BayLine = "line", BackWall = "wall", SideFin = "wall",
	Roof = "deck", OwnerSign = "frame", FloorSign = "frame", Column = "frame", ElevatorPad = "frame", ElevatorPost = "frame",
	ElevatorStripe = "accent", TrapEdge = "accent", LiftPost = "accent2", LiftBeam = "accent2", Rail = "frame", RailPost = "frame",
	PortalPost = "frame", PortalHeader = "frame", PortalDoor = "door", Terminal = "frame", WheelStop = "accent",
}

local function part(parent, name, size, cf, color, mat, o)
	o = o or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or M.SmoothPlastic
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if o.collide == false then
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	end
	if o.cast == false then
		p.CastShadow = false
	end
	if o.refl then
		p.Reflectance = o.refl
	end
	if o.t then
		p.Transparency = o.t
	end
	p.Parent = parent
	return p
end
GarageKit.Part = part

function GarageKit.Label(p, face, text, color)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Gui"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	gui.Parent = p
	local l = Instance.new("TextLabel")
	l.Name = "Label"
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	l.Parent = gui
	return l
end

-- one parking bay; topY = height of the surface it lies on. Returns the pad.
-- lift cabin for one storey (y0 = floor level): steel frame, tinted glass on three sides (open towards the deck, -X),
-- a canopy with a LIFT sign and a call-button panel. mk(name, size, localPos, color, material, opts)
function GarageKit.Lift(mk, y0, H, frame, accent)
	local el = BaseLayout.ElevatorLocal
	local GLASS = C(150, 190, 215)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			mk("ElevatorPost", Vector3.new(0.6, H, 0.6), Vector3.new(el.X + sx * 4.3, y0 + H / 2, el.Z + sz * 4.3), frame, M.Metal)
		end
	end
	-- glass back (+X) and sides (+-Z), set 0.1 inside the posts so no faces touch
	mk("LiftGlass", Vector3.new(0.2, H - 1.2, 8), Vector3.new(el.X + 4.3, y0 + H / 2 - 0.3, el.Z), GLASS, M.Glass, { t = 0.55 })
	for _, sz in ipairs({ -1, 1 }) do
		mk("LiftGlass", Vector3.new(8, H - 1.2, 0.2), Vector3.new(el.X, y0 + H / 2 - 0.3, el.Z + sz * 4.3), GLASS, M.Glass, { t = 0.55 })
	end
	mk("LiftCanopy", Vector3.new(9.4, 0.5, 9.4), Vector3.new(el.X, y0 + H - 0.55, el.Z), frame, M.Metal)
	local sign = mk("LiftSign", Vector3.new(0.3, 1.2, 4), Vector3.new(el.X - 4.75, y0 + H - 1.6, el.Z), C(20, 24, 34), M.SmoothPlastic, { collide = false })
	GarageKit.Label(sign, Enum.NormalId.Left, "LIFT", accent)
	-- call panel on the front post: a small plate with two lit buttons
	mk("LiftPanel", Vector3.new(0.25, 1.6, 0.8), Vector3.new(el.X - 4.75, y0 + 4, el.Z - 3.2), C(40, 44, 52), M.Metal, { collide = false })
	for i, dy in ipairs({ 0.35, -0.35 }) do
		mk("LiftButton" .. i, Vector3.new(0.12, 0.35, 0.35), Vector3.new(el.X - 4.94, y0 + 4 + dy, el.Z - 3.2), accent, M.Neon, { collide = false, cast = false })
	end
end

function GarageKit.Bay(slotsFolder, model, bcf, slot, topY, style)
	style = style or GarageKit.Style
	local p = BaseLayout.SlotLocal(slot)
	local pad = part(slotsFolder, "Slot" .. slot, Vector3.new(22, 0.06, 12.4), bcf * CFrame.new(p.X, topY + 0.03, p.Z), style.bay, M.SmoothPlastic, { collide = false, cast = false })
	local num = GarageKit.Label(pad, Enum.NormalId.Top, tostring(slot), style.line)
	num.TextTransparency = 0.45
	num.Rotation = 90
	for _, s in ipairs({ -1, 1 }) do
		part(model, "BayLine", Vector3.new(22, 0.06, 0.3), bcf * CFrame.new(p.X, topY + 0.03, p.Z + s * 6.4), style.line, M.SmoothPlastic, { collide = false, cast = false })
	end
	part(model, "WheelStop", Vector3.new(0.6, 0.4, 5), bcf * CFrame.new(p.X - 10.6, topY + 0.2, p.Z), style.accent, M.SmoothPlastic)
	return pad
end

-- builds floor f (2..4): its deck surface is the roof of floor f-1. Returns model, pads by slot.
function GarageKit.BuildFloor(parent, bcf, f, style)
	style = style or GarageKit.Style
	local m = Instance.new("Model")
	m.Name = "Floor" .. f
	local H = BaseLayout.FloorHeight
	local PX, PZ = MapConfig.BasePlot.x / 2, MapConfig.BasePlot.z / 2
	local EDGE = BaseLayout.DeckEdgeX
	local deckW = EDGE + PX
	local deckCX = (EDGE - PX) / 2
	local y0 = (f - 1) * H + 0.5 -- deck top of this floor
	local function mk(name, size, off, color, mat, o)
		return part(m, name, size, bcf * CFrame.new(off), color, mat, o)
	end
	mk("BackWall", Vector3.new(2, H - 1, PZ * 2), Vector3.new(-PX + 1, y0 + (H - 1) / 2, 0), style.wall)
	for _, s in ipairs({ -1, 1 }) do
		mk("SideFin", Vector3.new(deckW - 2, H - 1, 0.8), Vector3.new(deckCX + 1, y0 + (H - 1) / 2, s * (PZ - 0.6)), style.wall)
	end
	mk("Roof", Vector3.new(deckW, 1, PZ * 2), Vector3.new(deckCX, f * H, 0), style.deck)
	mk("FloorSign", Vector3.new(1.2, 2.4, PZ * 2 + 0.4), Vector3.new(EDGE + 0.4, f * H + 0.2, 0), style.frame)
	for _, z in ipairs({ -PZ + 1, -15.5, 15.5, PZ - 1 }) do
		mk("Column", Vector3.new(1.2, H - 1, 1.2), Vector3.new(EDGE - 0.8, y0 + (H - 1) / 2, z), style.frame, M.Metal)
	end
	-- safety rail along the open edge, with a gap at the lift
	local el = BaseLayout.ElevatorLocal
	local gapA, gapB = el.Z - 5, el.Z + 5
	for _, seg in ipairs({ { -PZ + 1, gapA }, { gapB, PZ - 1 } }) do
		local len = seg[2] - seg[1]
		if len > 1 then
			mk("Rail", Vector3.new(0.3, 0.3, len), Vector3.new(EDGE - 0.3, y0 + 3.4, (seg[1] + seg[2]) / 2), style.frame, M.Metal)
			for z = seg[1], seg[2], 6 do
				mk("RailPost", Vector3.new(0.3, 3.4, 0.3), Vector3.new(EDGE - 0.3, y0 + 1.7, z), style.frame, M.Metal)
			end
		end
	end
	for _, z in ipairs({ -30, 0, 30 }) do
		local lamp = mk("CeilingLight", Vector3.new(12, 0.12, 1.6), Vector3.new(-31, f * H - 0.6, z), C(255, 244, 222), M.Neon, { collide = false, cast = false })
		local sl = Instance.new("SurfaceLight")
		sl.Face = Enum.NormalId.Bottom
		sl.Range = 18
		sl.Brightness = 1.1
		sl.Angle = 100
		sl.Color = C(255, 238, 210)
		sl.Parent = lamp
	end
	GarageKit.Lift(mk, y0, H, style.frame, style.accent)
	local slots = Instance.new("Folder")
	slots.Name = "Slots"
	slots.Parent = m
	local pads = {}
	for n = (f - 1) * BaseLayout.SlotsPerFloor + 1, f * BaseLayout.SlotsPerFloor do
		pads[n] = GarageKit.Bay(slots, m, bcf, n, y0, style)
	end
	m.Parent = parent
	return m, pads
end

-- recolour every known part in a garage (skins)
function GarageKit.ApplyStyle(root, style)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			local key = GarageKit.Paint[d.Name]
			if key and style[key] then
				d.Color = style[key]
			end
		end
	end
end

return GarageKit
