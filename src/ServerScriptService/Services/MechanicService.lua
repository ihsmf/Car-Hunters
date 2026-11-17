-- Big Tony's Gears: the rich mechanic in his own garage on the plaza. He sells timed gears (GearService buys them;
-- this module only places Tony + his prompt). Jobs are claimed in the safe zone (JOBS panel), see ContractService.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Mechanic = {}
local S
local spotPos
local anims

function Mechanic.Init(hub)
	S = hub
end

local function nearTony(player)
	local hrp = S.Data.GetRoot(player)
	return hrp and spotPos and (hrp.Position - spotPos).Magnitude <= 24
end
Mechanic.NearTony = nearTony

local function gesture()
	if anims and anims.point then
		anims.point:Play()
	elseif anims and anims.wave then
		anims.wave:Play()
	end
end
Mechanic.Gesture = gesture

local function dressTony(n)
	local A = S.Shop.Attach
	local GOLD, BLACK, WHITE = Color3.fromRGB(240, 190, 60), Color3.fromRGB(24, 24, 28), Color3.fromRGB(250, 250, 250)
	local M = Enum.Material
	-- fedora
	A(n, "Head", Vector3.new(1.9, 0.12, 1.9), CFrame.new(0, 0.55, 0), BLACK)
	A(n, "Head", Vector3.new(1.25, 0.6, 1.25), CFrame.new(0, 0.86, 0), BLACK)
	A(n, "Head", Vector3.new(1.28, 0.14, 1.28), CFrame.new(0, 0.66, 0), GOLD)
	-- shades + cigar
	A(n, "Head", Vector3.new(1.0, 0.22, 0.1), CFrame.new(0, 0.12, -0.6), BLACK, M.Glass)
	A(n, "Head", Vector3.new(0.12, 0.12, 0.6), CFrame.new(0.25, -0.28, -0.75), Color3.fromRGB(120, 70, 40))
	A(n, "Head", Vector3.new(0.13, 0.13, 0.08), CFrame.new(0.25, -0.28, -1.06), Color3.fromRGB(255, 120, 40), M.Neon)
	-- white shirt, gold tie, gold chain, pocket square
	A(n, "UpperTorso", Vector3.new(0.7, 1.4, 0.1), CFrame.new(0, 0.15, -0.52), WHITE)
	A(n, "UpperTorso", Vector3.new(0.22, 1.1, 0.12), CFrame.new(0, 0.05, -0.58), GOLD, M.Metal)
	A(n, "UpperTorso", Vector3.new(1.2, 0.12, 0.12), CFrame.new(0, 0.62, -0.56), GOLD, M.Metal)
	A(n, "UpperTorso", Vector3.new(0.3, 0.22, 0.1), CFrame.new(-0.6, 0.45, -0.53), Color3.fromRGB(214, 52, 44))
	-- gold watch + rings, chrome wrench
	A(n, "LeftLowerArm", Vector3.new(0.62, 0.22, 0.62), CFrame.new(0, -0.3, 0), GOLD, M.Metal)
	A(n, "RightHand", Vector3.new(0.18, 0.18, 0.18), CFrame.new(0.2, -0.1, -0.2), GOLD, M.Metal)
	local wrench = A(n, "RightHand", Vector3.new(0.22, 1.7, 0.22), CFrame.new(0, -0.6, 0), Color3.fromRGB(230, 232, 236), M.Metal)
	if wrench then
		wrench.Reflectance = 0.4
	end
	-- polished shoes
	A(n, "LeftFoot", Vector3.new(0.8, 0.3, 1.2), CFrame.new(0, -0.1, -0.1), BLACK, M.SmoothPlastic)
	A(n, "RightFoot", Vector3.new(0.8, 0.3, 1.2), CFrame.new(0, -0.1, -0.1), BLACK, M.SmoothPlastic)
end

-- the map's TonyGarage model (older maps: the contracts stand)
local function findSpot(map)
	local garage = map and map:FindFirstChild("TonyGarage", true)
	local spot = garage and garage:FindFirstChild("TonySpot", true)
	if not spot then
		garage = map and map:FindFirstChild("ContractStand", true)
		spot = garage and garage:FindFirstChild("TonySpot", true)
	end
	return garage, spot
end
Mechanic.FindSpot = findSpot

-- MakeNpc turns the NPC by the spot's Yaw attribute; without one, follow the spot's own facing
local function faceLikeSpot(npc, spot)
	if spot:GetAttribute("Yaw") ~= nil then
		return
	end
	local look = spot.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude > 0.01 then
		local pos = npc:GetPivot().Position
		npc:PivotTo(CFrame.lookAt(pos, pos + look.Unit))
	end
end
Mechanic.FaceLikeSpot = faceLikeSpot

function Mechanic.Start()
	task.spawn(function()
		local map = Workspace:WaitForChild("GeneratedMap", 60)
		local garage, spot = findSpot(map)
		if not spot then
			warn("[Mechanic] TonyGarage/TonySpot not found")
			return
		end
		spotPos = spot.Position
		local prompt = garage:FindFirstChild("TonyPrompt", true)
		if prompt and prompt:IsA("BasePart") then
			local pp = Instance.new("ProximityPrompt")
			pp.ActionText = "Gear Shop"
			pp.ObjectText = "Big Tony"
			pp.HoldDuration = 0
			pp.MaxActivationDistance = 14
			pp.RequiresLineOfSight = false
			pp.Parent = prompt
		end
		local npc
		npc, anims = S.Shop.MakeNpc("BigTony", {
			skin = Color3.fromRGB(214, 164, 126), arms = Color3.fromRGB(30, 36, 58),
			torso = Color3.fromRGB(30, 36, 58), legs = Color3.fromRGB(34, 38, 48),
		}, spot, dressTony)
		if not npc then
			return
		end
		faceLikeSpot(npc, spot)
		npc:ScaleTo(1.12)
		npc:PivotTo(npc:GetPivot() + Vector3.new(0, 0.37, 0))
		-- wave at players who walk up
		local cool = 0
		while npc.Parent do
			task.wait(0.5)
			cool = cool - 0.5
			if cool <= 0 then
				for _, p in ipairs(Players:GetPlayers()) do
					local hrp = S.Data.GetRoot(p)
					if hrp and (hrp.Position - spotPos).Magnitude < 22 then
						if anims and anims.wave then
							anims.wave:Play()
						end
						cool = 9
						break
					end
				end
			end
		end
	end)
end

return Mechanic
