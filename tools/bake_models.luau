-- Embeds downloaded Roblox assets (assets/rbxm/<id>.rbxm, from tools/fetch_assets.py) into the place file as
-- ServerStorage.Embedded.Assets.A<id>, so the game never has to download models at runtime.
--   lune run tools/bake_models.luau CarHunters.rbxlx assets/rbxm CarHunters.rbxl
-- The output is a binary .rbxl (the XML version with every model would be over 200 MB).
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local placePath = process.args[1] or "CarHunters.rbxlx"
local dir = process.args[2] or "assets/rbxm"
local outPath = process.args[3] or placePath

local game = roblox.deserializePlace(fs.readFile(placePath))
local ss = game:GetService("ServerStorage")
local old = ss:FindFirstChild("Embedded")
if old then
	old:Destroy()
end
local embedded = roblox.Instance.new("Folder")
embedded.Name = "Embedded"
local assets = roblox.Instance.new("Folder")
assets.Name = "Assets"
assets.Parent = embedded

local n, failed = 0, {}
for _, file in ipairs(fs.readDir(dir)) do
	local id = string.match(file, "^(%d+)%.rbxm$")
	if id then
		local ok, res = pcall(roblox.deserializeModel, fs.readFile(dir .. "/" .. file))
		if ok then
			local holder = roblox.Instance.new("Model")
			holder.Name = "A" .. id
			for _, inst in ipairs(res) do
				inst.Parent = holder
			end
			-- free models often carry scripts (car chassis, sometimes worse): never ship them
			for _, d in ipairs(holder:GetDescendants()) do
				if d:IsA("LuaSourceContainer") then
					d:Destroy()
				end
			end
			holder.Parent = assets
			n += 1
		else
			table.insert(failed, file .. ": " .. tostring(res))
		end
	end
end
embedded.Parent = ss
local xml = string.sub(outPath, -6) == ".rbxlx"
fs.writeFile(outPath, roblox.serializePlace(game, xml))
print(string.format("[bake] embedded %d assets into %s", n, outPath))
for _, f in ipairs(failed) do
	print("[bake] FAILED " .. f)
end
