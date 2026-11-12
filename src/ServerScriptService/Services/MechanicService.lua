-- Big Tony, the rich mechanic next to the contracts board: hands out finished contract rewards
-- and trades banked parts for tuning parts.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))
local TuningConfig = require(Shared:WaitForChild("TuningConfig"))

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

local function gesture()
	if anims and anims.point then
		anims.point:Play()
	elseif anims and anims.wave then
		anims.wave:Play()
	end
end

function Mechanic.Claim(player, id)
	local s = S.Data.Get(player)
	if not s or not s.ready or not S.Data.RateLimit(player, "claim", 0.3) then
		return
	end
	if not nearTony(player) then
		S.Data.Notify(player, "seeTony", nil, "warn")
		return
	end
	local d = s.data
	local total, n = 0, 0
	for i = #d.contracts, 1, -1 do
		local c = d.contracts[i]
		if (id == "all" or c.id == id) and c.ready then
			total = total + S.Contracts.Reward(player, s, c, i, true)
			n = n + 1
			gesture()
		end
	end
	if n > 0 then -- one combined message + one state push
		S.Data.Notify(player, n > 1 and "contractsDone" or "contractDone", n > 1 and { n, Util.FormatNumber(total) } or { Util.FormatNumber(total) }, "good")
		S.Data.Push(player)
	end
end

function Mechanic.Craft(player, recipeId)
	local s = S.Data.Get(player)
	local r = type(recipeId) == "string" and TuningConfig.RecipeById[recipeId]
	if not s or not s.ready or not r or not S.Data.RateLimit(player, "craft", 0.3) then
		return
	end
	if not nearTony(player) then
		S.Data.Notify(player, "seeTony", nil, "warn")
		return
	end
	local d = s.data
	if d.money < r.money then
		S.Data.Notify(player, "noMoney", nil, "error")
		return
	end
	for part, n in pairs(r.parts or {}) do
		if (d.parts[part] or 0) < n then
			S.Data.Notify(player, "noParts", nil, "error")
			return
		end
	end
	for item, n in pairs(r.tune or {}) do
		if (d.tuning[item] or 0) < n then
			S.Data.Notify(player, "noTuneParts", nil, "error")
			return
		end
	end
	d.money = d.money - r.money
	for part, n in pairs(r.parts or {}) do
		d.parts[part] = d.parts[part] - n
	end
	for item, n in pairs(r.tune or {}) do
		d.tuning[item] = d.tuning[item] - n
		if d.tuning[item] <= 0 then
			d.tuning[item] = nil
		end
	end
	d.tuning[r.out] = math.min((d.tuning[r.out] or 0) + 1, 999)
	S.Data.Notify(player, "crafted", { TuningConfig.Items[r.out].name }, "good")
	gesture()
	S.Data.Push(player)
end

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

function Mechanic.Start()
	task.spawn(function()
		local map = Workspace:WaitForChild("GeneratedMap", 60)
		local stand = map and map:FindFirstChild("ContractStand", true)
		local spot = stand and stand:FindFirstChild("TonySpot")
		if not spot then
			warn("[Mechanic] ContractStand/TonySpot not found")
			return
		end
		spotPos = spot.Position
		local prompt = stand:FindFirstChild("TonyPrompt")
		if prompt then
			local pp = Instance.new("ProximityPrompt")
			pp.ActionText = "Talk"
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
		npc:ScaleTo(1.12)
		npc:PivotTo(npc:GetPivot() + Vector3.new(0, 0.37, 0))
		-- nod at players who have rewards waiting
		local cool = 0
		while npc.Parent do
			task.wait(0.5)
			cool = cool - 0.5
			if cool <= 0 then
				for _, p in ipairs(Players:GetPlayers()) do
					local hrp = S.Data.GetRoot(p)
					if hrp and (hrp.Position - spotPos).Magnitude < 22 then
						if anims.wave then
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
