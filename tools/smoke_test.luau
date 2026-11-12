-- Smoke test: loads every ModuleScript in the given folders with real Roblox datatypes/enums (lune) and reports
-- modules that fail while loading - e.g. a non-existing Enum.Material.Carbon broke every 3D model at runtime (v10).
--   lune run tools/smoke_test.luau <folder> [<folder> ...]
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local process = require("@lune/process")
local dir = process.args[1]
local loaded, failed = {}, 0
local function proxy(name)
	return setmetatable({}, { __index = function(_, k)
		if k == "WaitForChild" or k == "FindFirstChild" then
			return function(_, child) return proxy(child) end
		end
		return proxy(k)
	end })
end
local env
local function req(mod)
	local name = type(mod) == "string" and mod or getmetatable(mod) and mod.__name or nil
	return nil
end
local function load(name)
	if loaded[name] ~= nil then return loaded[name] end
	local path = dir .. "/" .. name .. ".lua"
	if not fs.isFile(path) then return proxy(name) end
	local src = fs.readFile(path)
	local scriptObj = { Parent = setmetatable({}, { __index = function(_, k)
		if k == "WaitForChild" or k == "FindFirstChild" then return function(_, c) return { __mod = c } end end
		return { __mod = k }
	end }) }
	local e = ({
		script = scriptObj,
		require = function(m)
			local n = type(m) == "table" and m.__mod or tostring(m)
			return load(n)
		end,
		game = setmetatable({}, { __index = function(_, k)
			if k == "GetService" then return function(_, s)
				if s == "ReplicatedStorage" then
					return { WaitForChild = function() return setmetatable({}, { __index = function(_, k2)
						if k2 == "WaitForChild" or k2 == "FindFirstChild" then return function(_, c) return { __mod = c } end end
						return { __mod = k2 } end }) end }
				end
				return proxy(s)
			end end
			return proxy(k)
		end }),
		workspace = proxy("workspace"),
	})
	for _, k in { "Color3", "Vector3", "Vector2", "CFrame", "UDim2", "UDim", "Enum", "Instance", "ColorSequence", "ColorSequenceKeypoint",
		"NumberSequence", "NumberSequenceKeypoint", "NumberRange", "Rect", "BrickColor", "Random", "TweenInfo", "PhysicalProperties", "Ray", "Font" } do
		e[k] = roblox[k]
	end
	e.math, e.string, e.table, e.os, e.pairs, e.ipairs, e.type, e.typeof = math, string, table, os, pairs, ipairs, type, typeof
	e.tostring, e.tonumber, e.setmetatable, e.getmetatable, e.pcall, e.error, e.assert = tostring, tonumber, setmetatable, getmetatable, pcall, error, assert
	e.select, e.next, e.rawget, e.rawset, e.print, e.warn, e.unpack, e.bit32, e.utf8, e.coroutine = select, next, rawget, rawset, print, print, table.unpack, bit32, utf8, coroutine
	e.Random = { new = function() return { NextNumber = function() return 0.5 end, NextInteger = function(_, a) return a end } end }
	e.task = { wait = function() end, spawn = function() end, delay = function() end, defer = function() end }
	local ok, res = pcall(function() return luau.load(src, { debugName = name, environment = e })() end)
	if not ok then
		print("FAIL", name, res)
		failed += 1
		loaded[name] = false
		return nil
	end
	loaded[name] = res
	return res
end
for _, f in fs.readDir(dir) do
	local n = string.match(f, "^(.+)%.lua$")
	if n then load(n) end
end
print("modules failing at load:", failed)
