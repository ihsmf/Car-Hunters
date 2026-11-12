-- Guide beam from the player to the current objective (set by Tutorial), plus a bobbing marker over the target.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Guidance = {}
local beam, att0, att1, marker
local target -- BasePart or Vector3

local function ensure(hrp)
	if not beam or not beam.Parent or att0.Parent ~= hrp then
		if beam then
			beam:Destroy()
		end
		att0 = Instance.new("Attachment")
		att0.Name = "GuideA"
		att0.Position = Vector3.new(0, -2, 0)
		att0.Parent = hrp
		beam = Instance.new("Beam")
		beam.Name = "GuideBeam"
		beam.Width0, beam.Width1 = 0.9, 0.9
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.Color = ColorSequence.new(Color3.fromRGB(255, 220, 60))
		beam.Transparency = NumberSequence.new(0.2)
		beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		beam.TextureMode = Enum.TextureMode.Static
		beam.TextureLength = 4
		beam.TextureSpeed = 2
		beam.Segments = 1
		beam.Attachment0 = att0
		beam.Parent = hrp
	end
	if not marker then
		marker = Instance.new("Part")
		marker.Name = "GuideMarker"
		marker.Anchored, marker.CanCollide, marker.CanQuery, marker.CanTouch = true, false, false, false
		marker.Transparency = 1
		marker.Size = Vector3.one
		att1 = Instance.new("Attachment")
		att1.Parent = marker
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(60, 60)
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.Parent = marker
		local arrow = Instance.new("TextLabel")
		arrow.Size = UDim2.fromScale(1, 1)
		arrow.BackgroundTransparency = 1
		arrow.Text = "V"
		arrow.Font = Enum.Font.LuckiestGuy
		arrow.TextScaled = true
		arrow.TextColor3 = Color3.fromRGB(255, 210, 63)
		local st = Instance.new("UIStroke")
		st.Thickness = 3
		st.Parent = arrow
		arrow.Parent = bb
		marker.Parent = workspace
	end
	beam.Attachment1 = att1
end

-- target: BasePart, Vector3 or nil (off)
function Guidance.Point(t)
	target = t
end

function Guidance.Start()
	RunService.Heartbeat:Connect(function()
		local char = Players.LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local pos = target and (typeof(target) == "Vector3" and target or (target.Parent and target.Position))
		if not hrp or not pos then
			if beam then
				beam.Enabled = false
			end
			if marker then
				marker.Parent = nil
			end
			return
		end
		ensure(hrp)
		marker.Parent = workspace
		marker.Position = pos + Vector3.new(0, 7 + math.sin(os.clock() * 4) * 0.8, 0)
		beam.Enabled = (hrp.Position - pos).Magnitude > 12
	end)
end

return Guidance
