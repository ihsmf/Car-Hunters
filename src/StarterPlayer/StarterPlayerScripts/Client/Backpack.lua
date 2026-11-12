-- BACKPACK: right-column button -> panel with every part type: 3D icon, name, rarity and how many you have.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PartConfig = require(Shared:WaitForChild("PartConfig"))
local CarConfig = require(Shared:WaitForChild("CarConfig"))
local Icons = require(Shared:WaitForChild("Icons"))

local Backpack = {}
local K, UI, P
local cells = {}

local function refresh(_, open)
	if open ~= "backpack" then
		return
	end
	for id, c in pairs(cells) do
		local n = K.store.Banked(id)
		c.count.Text = "x" .. n
		c.icon.ImageTransparency = n > 0 and 0 or 0.6
		c.count.TextColor3 = n > 0 and P.ink or P.grey
	end
end

function Backpack.Start(ui)
	UI = ui
	K = UI.Kit()
	P = K.P
	-- 5th button in the right column
	local holder = K.new("Frame", { Size = UDim2.fromOffset(122, 104), BackgroundTransparency = 1, LayoutOrder = 5 }, K.hud.side)
	K.toy(holder, { Text = "BACKPACK", Image = "backpack", Icon = "🎒", Color = P.orange, Size = UDim2.fromOffset(122, 104), OnClick = function() UI.TogglePanel("backpack") end })

	local p = K.panelShell("backpack", "BACKPACK", 760, 520, P.orange)
	local grid = K.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 22 }, p.content)
	K.new("UIGridLayout", { CellSize = UDim2.fromOffset(132, 190), CellPadding = UDim2.fromOffset(12, 14), HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	for i, id in ipairs(PartConfig.Order) do
		local part = PartConfig.Parts[id]
		local rc = CarConfig.Rarities[part.rarity].color
		local f = K.new("Frame", { BackgroundColor3 = P.white, LayoutOrder = i, ZIndex = 23 }, grid)
		K.corner(f, 16)
		K.stroke(f, rc, 3)
		local icon = K.new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(92, 92), BackgroundTransparency = 1,
			Image = Icons.Get(id) or "", ScaleType = Enum.ScaleType.Fit, ZIndex = 24 }, f)
		K.text(f, { Text = part.name, TextSize = 16, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(6, 102), Size = UDim2.new(1, -12, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 24 })
		K.text(f, { Text = string.upper(part.rarity), Font = K.BODY, TextSize = 13, TextColor3 = rc, Position = UDim2.fromOffset(6, 124), Size = UDim2.new(1, -12, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 24 })
		local count = K.text(f, { Text = "x0", TextSize = 24, TextColor3 = P.ink, Outline = false, Position = UDim2.fromOffset(6, 146), Size = UDim2.new(1, -12, 0, 30),
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 24 })
		cells[id] = { icon = icon, count = count }
	end
	table.insert(UI.Hooks, refresh)
end

return Backpack
