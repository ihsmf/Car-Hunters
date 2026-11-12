local MapConfig = require(script.Parent.MapConfig)

local BaseLayout = {}

BaseLayout.FloorY = 0.5
BaseLayout.SlotCount = 24 -- 4 floors x 6 bays
BaseLayout.SlotsPerFloor = 6
BaseLayout.MaxFloors = 4
BaseLayout.FloorHeight = 14
BaseLayout.DeckEdgeX = -10 -- front edge of the upper decks (local X)
BaseLayout.ElevatorLocal = Vector3.new(-3, 0, 38)
BaseLayout.TrapLocal = Vector3.new(30, 0, -26)
BaseLayout.PortalLocal = Vector3.new(52, 0, 20)
BaseLayout.TerminalLocal = Vector3.new(30, 0, 40)
BaseLayout.SpawnLocal = Vector3.new(44, 0, 0)
BaseLayout.BackWallX = -52
BaseLayout.LaneX = 14

function BaseLayout.FloorOf(slot)
	return math.floor((slot - 1) / BaseLayout.SlotsPerFloor) + 1
end

-- one row of 6 bays per floor, cars face +X (towards the plaza)
function BaseLayout.SlotLocal(slot)
	local floor = BaseLayout.FloorOf(slot)
	local col = (slot - 1) % BaseLayout.SlotsPerFloor
	return Vector3.new(-31, (floor - 1) * BaseLayout.FloorHeight, -37.5 + col * 15)
end

function BaseLayout.FloorTopY(floor)
	return BaseLayout.FloorY + (floor - 1) * BaseLayout.FloorHeight
end

function BaseLayout.GetBaseCFrame(index)
	local c = MapConfig.BaseCenters[index]
	local yaw = (c.x < 0) and 0 or math.pi
	return CFrame.new(c.x, 0, c.z) * CFrame.Angles(0, yaw, 0)
end

function BaseLayout.ToWorld(index, localPos)
	return BaseLayout.GetBaseCFrame(index):PointToWorldSpace(localPos)
end

function BaseLayout.SlotCFrame(index, slot)
	local p = BaseLayout.SlotLocal(slot)
	return BaseLayout.GetBaseCFrame(index) * CFrame.new(p.X, BaseLayout.FloorY + p.Y, p.Z)
end

return BaseLayout
