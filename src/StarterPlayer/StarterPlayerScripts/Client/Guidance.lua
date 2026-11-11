local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BaseLayout = require(Shared:WaitForChild("BaseLayout"))

local Guidance = {}
local beam, att0, att1Holder

local function ensure(hrp)
	if not beam or not beam.Parent then
		att0 = Instance.new("Attachment")
		att0.Name = "GuideA"
		att0.Position = Vector3.new(0, -2, 0)
		att0.Parent = hrp
		beam = Instance.new("Beam")
		beam.Name = "GuideBeam"
		beam.Width0 = 0.8
		beam.Width1 = 0.8
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.Color = ColorSequence.new(Color3.fromRGB(255, 220, 60))
		beam.Transparency = NumberSequence.new(0.25)
		beam.Segments = 1
		beam.Attachment0 = att0
		beam.Parent = hrp
	end
	return beam
end

local function clear()
	if beam then
		beam.Enabled = false
	end
end

function Guidance.Start(store)
	task.spawn(function()
		while true do
			task.wait(0.4)
			local st = store.State
			local char = Players.LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if not st or not hrp or (st.stats and st.stats.throws > 0) then
				clear()
			else
				local target
				local banked, carried = store.BankedTotal(), store.CarriedTotal()
				if banked == 0 and carried == 0 then
					local drops = Workspace:FindFirstChild("RuntimeDrops")
					local best = math.huge
					if drops then
						for _, m in ipairs(drops:GetChildren()) do
							local root = m:FindFirstChild("Root")
							if root then
								local d = (root.Position - hrp.Position).Magnitude
								if d < best then
									best, target = d, root
								end
							end
						end
					end
				elseif st.baseIndex then
					local map = Workspace:FindFirstChild("GeneratedMap")
					local base = map and map.Bases:FindFirstChild(string.format("Base%02d", st.baseIndex), true)
					target = base and base:FindFirstChild("TrapPad")
				end
				if target then
					local b = ensure(hrp)
					local a1 = target:FindFirstChild("GuideB")
					if not a1 then
						a1 = Instance.new("Attachment")
						a1.Name = "GuideB"
						a1.Parent = target
					end
					b.Attachment1 = a1
					b.Enabled = true
				else
					clear()
				end
			end
		end
	end)
end

return Guidance
