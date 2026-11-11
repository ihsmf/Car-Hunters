local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))
local PartConfig = require(Shared:WaitForChild("PartConfig"))
local PartVisual = require(Shared:WaitForChild("PartVisual"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))

local PartSpawn = {}
local S
local points = {}
local rng = Random.new()
local drops

function PartSpawn.Init(hub)
	S = hub
end

local function cooldownFor(risk)
	local c = PartConfig.Cooldowns[risk] or PartConfig.Cooldowns.safe
	return c[1] + rng:NextNumber() * (c[2] - c[1])
end

local function spawnAt(pt)
	local zoneTables = PartConfig.SpawnTables[pt.zone]
	local entries = zoneTables and zoneTables[pt.risk]
	if not entries then
		return
	end
	local partId = Util.WeightedPick(entries, rng:NextNumber())
	local model = PartVisual.Build(partId)
	model:PivotTo(CFrame.new(pt.pos + Vector3.new(0, 3, 0)))
	model:SetAttribute("PointId", pt.id)
	CollectionService:AddTag(model, "SpinBob")
	model.Parent = drops
	pt.model = model
	pt.partId = partId
	pt.active = true
end

function PartSpawn.Start()
	drops = Workspace:FindFirstChild("RuntimeDrops")
	if not drops then
		drops = Instance.new("Folder")
		drops.Name = "RuntimeDrops"
		drops.Parent = Workspace
	end
	local map = Workspace:WaitForChild("GeneratedMap")
	local folder = map:WaitForChild("PartSpawnPoints")
	for _, inst in ipairs(folder:GetDescendants()) do
		if inst:IsA("BasePart") and inst:GetAttribute("ZoneId") then
			table.insert(points, {
				id = inst:GetFullName(), pos = inst.Position, zone = inst:GetAttribute("ZoneId"),
				risk = inst:GetAttribute("Risk") or "safe", active = false, readyAt = 0,
			})
		end
	end
	local now = os.clock()
	for _, pt in ipairs(points) do
		pt.readyAt = now + rng:NextNumber() * 5
	end

	local acc = 0
	local warnedAt = {}
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc < EconomyConfig.PickupCheckInterval then
			return
		end
		acc = 0
		local t = os.clock()
		for _, pt in ipairs(points) do
			if not pt.active and t >= pt.readyAt then
				spawnAt(pt)
			end
		end
		local r2 = EconomyConfig.PickupRadius * EconomyConfig.PickupRadius
		for _, player in ipairs(Players:GetPlayers()) do
			local s = S.Data.Get(player)
			if s and s.ready then
				local hrp = S.Data.GetRoot(player)
				if hrp then
					local pos = hrp.Position
					for _, pt in ipairs(points) do
						if pt.active then
							local d = pt.pos - pos
							if d.X * d.X + d.Z * d.Z <= r2 and math.abs(d.Y) < 12 then
								if S.Inventory.CarriedTotal(s) >= EconomyConfig.CarryCapacity then
									if t - (warnedAt[player] or 0) > 3 then
										warnedAt[player] = t
										S.Data.Notify(player, "carryFull", nil, "warn")
									end
								else
									pt.active = false
									local partId = pt.partId
									if pt.model then
										pt.model:Destroy()
										pt.model = nil
									end
									pt.readyAt = t + cooldownFor(pt.risk)
									if S.Inventory.AddCarried(player, partId, 1) then
										S.Data.Notify(player, "picked", { partId }, "pickup")
									end
								end
							end
						end
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		warnedAt[p] = nil
	end)
end

function PartSpawn.PointCount()
	return #points
end

return PartSpawn
