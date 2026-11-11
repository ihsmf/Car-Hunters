-- Pit Stop: perks bought with in-game money + the mechanic NPC. All perk effects are read through this module.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShopConfig = require(Shared:WaitForChild("ShopConfig"))
local MapConfig = require(Shared:WaitForChild("MapConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))

local Shop = {}
local S

function Shop.Init(hub)
	S = hub
end

local function lvl(s, id)
	return (s and s.data and s.data.perks and s.data.perks[id]) or 0
end
Shop.Level = lvl

local function pass(s, id)
	return s and s.passes and s.passes[id] == true
end
Shop.HasPass = pass

local function boostActive(s, id)
	local b = s and s.data and s.data.boosts
	return b and (b[id] or 0) > os.time()
end
Shop.BoostActive = boostActive

---------------------------------------------------------------- effects
function Shop.WalkSpeed(s)
	return MapConfig.WalkSpeed * (1 + ShopConfig.ById.sneakers.per * lvl(s, "sneakers"))
end

function Shop.CarryCap(s)
	local cap = EconomyConfig.CarryCapacity + ShopConfig.ById.backpack.per * lvl(s, "backpack")
	return pass(s, "big_backpack") and cap * 2 or cap
end

function Shop.PickupRadius(s)
	local r = EconomyConfig.PickupRadius + ShopConfig.ById.magnet.per * lvl(s, "magnet")
	return pass(s, "auto_collect") and r * 2 or r
end

function Shop.IncomeMult(s)
	local m = 1 + ShopConfig.ById.turbo.per * lvl(s, "turbo")
	if pass(s, "vip") then
		m = m * 1.5
	end
	if boostActive(s, "income") then
		m = m * 2
	end
	return m
end

-- 0..1 shift towards rarer cars (applied to the roll's random number)
function Shop.LuckShift(s)
	local shift = ShopConfig.ById.lucky.per * lvl(s, "lucky")
	if boostActive(s, "luck") then
		shift = shift + 0.25
	end
	return math.min(shift, 0.6)
end

function Shop.RespawnTime(s)
	local q = lvl(s, "quick")
	return q > 0 and ShopConfig.ById.quick.respawn[q] or 3
end

function Shop.SpawnShield(s)
	return EconomyConfig.SpawnProtection + 0.5 * lvl(s, "quick")
end

function Shop.ThrowCooldown(s)
	return pass(s, "fast_trap") and EconomyConfig.ThrowAnimTime * 0.5 or EconomyConfig.ThrowAnimTime
end

-- airbag: returns true if a car hit is absorbed
function Shop.TryAirbag(s)
	local l = lvl(s, "airbag")
	if l <= 0 then
		return false
	end
	local now = os.clock()
	if now < (s.airbagReadyAt or 0) then
		return false
	end
	s.airbagReadyAt = now + ShopConfig.ById.airbag.cooldowns[l]
	return true
end

function Shop.AirbagReadyIn(s)
	if lvl(s, "airbag") <= 0 then
		return nil
	end
	return math.max(0, (s.airbagReadyAt or 0) - os.clock())
end

---------------------------------------------------------------- buying
function Shop.Buy(player, perkId)
	local def = type(perkId) == "string" and ShopConfig.ById[perkId]
	local s = S.Data.Get(player)
	if not def or not s or not s.ready then
		return
	end
	if not S.Data.RateLimit(player, "perk", 0.3) then
		return
	end
	local d = s.data
	local cur = d.perks[perkId] or 0
	if cur >= def.max then
		S.Data.Notify(player, "maxLevel", nil, "warn")
		return
	end
	local cost = def.costs[cur + 1]
	if d.money < cost then
		S.Data.Notify(player, "noMoney", nil, "error")
		return
	end
	d.money = d.money - cost
	d.perks[perkId] = cur + 1
	S.Data.Notify(player, "perkBought", { def.name, cur + 1 }, "good")
	S.Income.Recalc(player)
	Shop.ApplyCharacter(player)
	S.Data.Push(player)
end

function Shop.ApplyCharacter(player)
	local s = S.Data.Get(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if s and hum then
		hum.WalkSpeed = Shop.WalkSpeed(s)
	end
end

---------------------------------------------------------------- NPC
local IDLE = "rbxassetid://507766388"
local WAVE = "rbxassetid://507770239"
local POINT = "rbxassetid://507770453"

-- builds an R15 NPC from body colours + simple part accessories (no catalogue assets needed)
function Shop.MakeNpc(name, colors, spot, dressUp)
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = colors.skin
	desc.LeftArmColor, desc.RightArmColor = colors.arms, colors.arms
	desc.TorsoColor = colors.torso
	desc.LeftLegColor, desc.RightLegColor = colors.legs, colors.legs
	local ok, npc = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not npc then
		warn("[NPC] could not build " .. name .. ": " .. tostring(npc))
		return nil
	end
	npc.Name = name
	local hum = npc:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local root = npc:FindFirstChild("HumanoidRootPart")
	local yaw = spot:GetAttribute("Yaw") or 0
	npc:PivotTo(CFrame.new(spot.Position + Vector3.new(0, 3.1, 0)) * CFrame.Angles(0, yaw, 0))
	for _, p in ipairs(npc:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = p == root
		end
	end
	if dressUp then
		dressUp(npc)
	end
	npc.Parent = Workspace
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local function load(id)
		local a = Instance.new("Animation")
		a.AnimationId = id
		local ok2, track = pcall(function()
			return animator:LoadAnimation(a)
		end)
		return ok2 and track or nil
	end
	local idle = load(IDLE)
	if idle then
		idle.Looped = true
		idle:Play()
	end
	return npc, { wave = load(WAVE), point = load(POINT), animator = animator, load = load }
end

-- weld a simple part accessory to a body part
function Shop.Attach(npc, partName, size, offset, color, mat, shape)
	local host = npc:FindFirstChild(partName)
	if not host then
		return nil
	end
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
	p.CFrame = host.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = host, p
	w.Parent = p
	p.Parent = npc
	return p
end

local function makePrompt(part, text, object)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = text
	pp.ObjectText = object
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 14
	pp.RequiresLineOfSight = false
	pp.Parent = part
	return pp
end

function Shop.Start()
	task.spawn(function()
		local map = Workspace:WaitForChild("GeneratedMap", 60)
		local shop = map and map:FindFirstChild("PitStopShop", true)
		if not shop then
			warn("[Shop] PitStopShop not found in GeneratedMap")
			return
		end
		local prompt = shop:FindFirstChild("ShopPrompt")
		if prompt then
			makePrompt(prompt, "Open shop", "Pit Stop")
		end
		local spot = shop:FindFirstChild("NpcSpot")
		if spot then
			local npc, anims = Shop.MakeNpc("Mechanic", {
				skin = Color3.fromRGB(234, 184, 146), arms = Color3.fromRGB(40, 90, 170),
				torso = Color3.fromRGB(40, 90, 170), legs = Color3.fromRGB(30, 60, 120),
			}, spot, function(n)
				local CYL = Enum.PartType.Cylinder
				Shop.Attach(n, "Head", Vector3.new(1.3, 0.35, 1.35), CFrame.new(0, 0.62, 0), Color3.fromRGB(214, 52, 44))
				Shop.Attach(n, "Head", Vector3.new(0.9, 0.12, 0.7), CFrame.new(0, 0.5, -0.8), Color3.fromRGB(214, 52, 44))
				Shop.Attach(n, "UpperTorso", Vector3.new(0.9, 0.5, 0.15), CFrame.new(0.4, 0.2, -0.55), Color3.fromRGB(255, 255, 255))
				local wrench = Shop.Attach(n, "RightHand", Vector3.new(0.25, 1.6, 0.25), CFrame.new(0, -0.6, 0), Color3.fromRGB(190, 194, 200), Enum.Material.Metal)
				if wrench then
					wrench.Name = "Wrench"
				end
				Shop.Attach(n, "LeftHand", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, -0.2, 0), Color3.fromRGB(240, 240, 240), Enum.Material.Fabric, CYL)
			end)
			if npc and anims then
				-- wave at players who walk up
				task.spawn(function()
					local cool = 0
					while npc.Parent do
						task.wait(0.5)
						cool = cool - 0.5
						if cool <= 0 then
							for _, p in ipairs(Players:GetPlayers()) do
								local c = p.Character
								local hrp = c and c:FindFirstChild("HumanoidRootPart")
								if hrp and (hrp.Position - spot.Position).Magnitude < 20 then
									if anims.wave then
										anims.wave:Play()
									end
									cool = 8
									break
								end
							end
						end
					end
				end)
			end
		end
	end)
	Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Connect(function()
			task.defer(Shop.ApplyCharacter, p)
		end)
	end)
end

return Shop
