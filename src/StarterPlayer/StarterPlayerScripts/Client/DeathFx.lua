-- WRECKED! sequence: impact flash, heavy shake, glitch, grayscale-red grade, crane-up camera, countdown.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local PartConfig = require(Shared:WaitForChild("PartConfig"))
local Cine = require(script.Parent:WaitForChild("CineFx"))

local DeathFx = {}
local ICON = { bolts = "🔩", tire = "🛞", engine = "⚙️", turbo = "🌀", core = "⚡" }
local running = false

function DeathFx.Play(dir, lost, sfx)
	if running then
		return
	end
	running = true
	local player = Players.LocalPlayer
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then -- cartoon launch
		hrp.AssemblyLinearVelocity = dir.Unit * 90 + Vector3.new(0, 70, 0)
		hrp.AssemblyAngularVelocity = Vector3.new(math.random(-20, 20), math.random(-20, 20), math.random(-20, 20))
	end
	if sfx then
		sfx("hit")
		sfx("boom")
	end
	Cine.Flash(Color3.fromRGB(255, 59, 59), 0, 0.6)
	Cine.Shake(4, 0.7)
	Cine.Glitch(0.7, 1.2)
	Cine.Grade({ Saturation = -0.85, Contrast = 0.35, TintColor = Color3.fromRGB(255, 170, 170) }, 0.15)
	Cine.Letterbox(true, 0.2)
	Cine.Title(Strings.T("wrecked"), Color3.fromRGB(255, 59, 59), 2.4, 170, 0.36)

	local parts = {}
	for _, id in ipairs(PartConfig.Order) do
		if lost and (lost[id] or 0) > 0 then
			table.insert(parts, (ICON[id] or "") .. " x" .. lost[id])
		end
	end
	task.delay(0.4, function()
		if #parts > 0 then
			Cine.Sub(Strings.T("wrecked_lost", table.concat(parts, "   ")), Color3.fromRGB(255, 210, 63), 2.2, 0.55)
		end
		Cine.Sub(Strings.T("wrecked_safe"), Color3.fromRGB(255, 255, 255), 2.2, 0.62)
	end)

	-- crane shot rising above the crash site
	task.delay(0.25, function()
		local cam = Cine.Take()
		local focus = hrp and hrp.Position or cam.CFrame.Position
		local from = cam.CFrame
		local t0 = os.clock()
		Cine.Blur(6, 1.5)
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local a = math.min(1, (os.clock() - t0) / 2.6)
			local e = 1 - (1 - a) ^ 3
			local target = CFrame.lookAt(focus + Vector3.new(math.cos(e * 1.2) * 18, 8 + e * 38, math.sin(e * 1.2) * 18), focus)
			cam.CFrame = from:Lerp(target, math.min(1, a * 3)) * CFrame.Angles(0, 0, math.rad(8 * (1 - e)))
			if a >= 1 then
				conn:Disconnect()
			end
		end)
		for n = 3, 1, -1 do
			task.wait(0.8)
			Cine.Sub(Strings.T("wrecked_back", n), Color3.fromRGB(255, 255, 255), 0.6, 0.7)
		end
	end)
end

-- called on respawn
function DeathFx.Recover()
	if not running then
		return
	end
	running = false
	Cine.Release(0.2)
	Cine.Reset(0.5)
	Cine.Flash(Color3.new(0, 0, 0), 0, 0.6)
end

return DeathFx
