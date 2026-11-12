-- HUD icons rendered from the Blender models (assets/icons), uploaded as Decals; shown through rbxthumb.
local ok, ids = pcall(require, script.Parent:WaitForChild("IconIds"))
ids = ok and ids or {}

local Icons = {}

function Icons.Get(name)
	local id = ids[name]
	if id and id > 0 then
		return string.format("rbxthumb://type=Asset&id=%d&w=150&h=150", id)
	end
	return nil
end

return Icons
