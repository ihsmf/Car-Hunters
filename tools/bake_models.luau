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

local STRIP = {
	"LuaSourceContainer", "Sound", "SoundGroup", "SoundEffect", "GuiBase", "GuiObject", "UIComponent", "ValueBase",
	"RemoteEvent", "RemoteFunction", "BindableEvent", "BindableFunction", "Camera", "BodyMover", "Constraint",
	"ParticleEmitter", "Fire", "Smoke", "Sparkles", "Trail", "Beam", "ProximityPrompt", "ClickDetector", "Tool",
	"Humanoid", "Animation", "AnimationController", "Explosion", "Configuration",
}
local function strip(d)
	for _, c in ipairs(STRIP) do
		local ok, yes = pcall(function()
			return d:IsA(c)
		end)
		if ok and yes then
			return true
		end
	end
	return false
end

-- only the ids the game uses (assets/rbxm/used.txt, written by fetch_assets.py); without the list, everything
local used
if fs.isFile(dir .. "/used.txt") then
	used = {}
	for id in string.gmatch(fs.readFile(dir .. "/used.txt"), "%d+") do
		used[id] = true
	end
end

local n, failed = 0, {}
for _, file in ipairs(fs.readDir(dir)) do
	local id = string.match(file, "^(%d+)%.rbxm$")
	if id and (not used or used[id]) then
		local ok, res = pcall(roblox.deserializeModel, fs.readFile(dir .. "/" .. file))
		if ok then
			local holder = roblox.Instance.new("Model")
			holder.Name = "A" .. id
			for _, inst in ipairs(res) do
				inst.Parent = holder
			end
			-- keep only geometry: free car models carry scripts, sounds, GUIs, remotes, values and effects whose
			-- assets belong to other creators (Studio prints "Requester does not have permission" for each of them)
			for _, d in ipairs(holder:GetDescendants()) do
				if d.Parent and strip(d) then
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
