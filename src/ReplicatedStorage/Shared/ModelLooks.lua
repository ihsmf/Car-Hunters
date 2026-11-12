-- Material + colour for Blender meshes, by mesh name (the look name). Shared by ModelService and CarModelTool.
local C = Color3.fromRGB
local M = Enum.Material
return {
	-- name = { material, colour, reflectance, transparency, collide }
	Rubber = { M.SmoothPlastic, C(26, 26, 30), 0, 0 }, Metal = { M.Metal, C(160, 164, 172), 0.05, 0 },
	Chrome = { M.Metal, C(226, 230, 236), 0.35, 0 }, Dark = { M.SmoothPlastic, C(30, 32, 38), 0, 0 },
	Copper = { M.Metal, C(190, 104, 56), 0.1, 0 }, Accent = { M.SmoothPlastic, C(214, 40, 36), 0.05, 0 },
	Glow = { M.Neon, C(255, 236, 190), 0, 0, false }, Carbon = { M.SmoothPlastic, C(20, 20, 24), 0.08, 0 },
	Blue = { M.SmoothPlastic, C(30, 110, 220), 0.05, 0 }, Gold = { M.Metal, C(255, 190, 60), 0.3, 0 },
	Green = { M.SmoothPlastic, C(40, 170, 80), 0, 0 }, White = { M.SmoothPlastic, C(244, 244, 242), 0, 0 },
	Marble = { M.Marble, C(238, 234, 226), 0.05, 0 }, Glass = { M.Glass, C(150, 200, 235), 0.1, 0.4 },
	Water = { M.Glass, C(60, 150, 230), 0.15, 0.25, false }, Leaf = { M.Grass, C(70, 160, 70), 0, 0, false },
	Wood = { M.Wood, C(150, 100, 60), 0, 0 }, Yellow = { M.SmoothPlastic, C(255, 200, 40), 0, 0 },
	Concrete = { M.Concrete, C(170, 168, 160), 0, 0 }, Orange = { M.SmoothPlastic, C(255, 130, 30), 0, 0 },
	Red = { M.SmoothPlastic, C(225, 50, 50), 0, 0 },
	-- city kit: Wall / Trim / Roof are recoloured per district by the map builder
	Wall = { M.SmoothPlastic, C(230, 200, 160), 0, 0 }, Trim = { M.SmoothPlastic, C(240, 150, 50), 0, 0 },
	Roof = { M.SmoothPlastic, C(170, 80, 64), 0, 0 }, Brick = { M.Brick, C(160, 76, 56), 0, 0 },
}
