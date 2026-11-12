-- Studio edit-mode preview: load the uploaded Blender models and build the whole map, to look around without Play.
--   require(game.ServerStorage.Tools.ModelPreview).Run()
-- Do NOT save the place afterwards if you want the server to rebuild the map itself (it rebuilds anyway when the
-- saved map is older than MapConfig.Version). Clear(): removes the preview map.
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local Preview = {}

function Preview.Run()
	task.spawn(function()
		local n = require(ServerScriptService.Services.ModelService).LoadAll()
		print("[Preview] models loaded:", n)
		require(script.Parent.BuildCityMap).Build()
	end)
end

function Preview.Clear()
	local m = Workspace:FindFirstChild("GeneratedMap")
	if m then
		m:Destroy()
	end
end

return Preview
