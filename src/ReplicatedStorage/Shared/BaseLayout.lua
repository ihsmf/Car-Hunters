local MapConfig = require(script.Parent.MapConfig)

local BaseLayout = {}

BaseLayout.FloorY = 0.5
BaseLayout.SlotCount = 12
BaseLayout.TrapLocal = Vector3.new(30, 0, -26)
BaseLayout.PortalLocal = Vector3.new(52, 0, 20)
BaseLayout.TerminalLocal = Vector3.new(30, 0, 40)
BaseLayout.SpawnLocal = Vector3.new(44, 0, 0)
BaseLayout.BackWallX = -52
BaseLayout.LaneX = 14

function BaseLayout.SlotLocal(slot)
	local row = math.floor((slot - 1) / 6)
	local col = (slot - 1) % 6
	local x = (row == 0) and -35 or -8
	local z = -37.5 + col * 15
	return Vector3.new(x, 0, z)
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
	return BaseLayout.GetBaseCFrame(index) * CFrame.new(p.X, BaseLayout.FloorY, p.Z)
end

return BaseLayout
