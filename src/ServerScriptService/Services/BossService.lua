-- Arena bosses: a monster truck per arena hunts the nearest player. Touch = WRECKED.
-- Players scare it by throwing their cheapest part: 1st hit stuns it, 2nd hit makes it flee for a while.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local PartConfig = require(Shared:WaitForChild("PartConfig"))
local SV = require(Shared:WaitForChild("SpecialVehicles"))

local Boss = {}
local S
local bosses = {}

Boss.Stats = {
	crusher = { speed = 34, turn = 1.5, accel = 22 },
	juggernaut = { speed = 44, turn = 1.7, accel = 28 },
	titan = { speed = 52, turn = 1.9, accel = 34, jump = true },
}
Boss.ThrowRange = 80
Boss.HitsToScare = 2
Boss.StunTime = 2.2
Boss.FleeTime = 25

function Boss.Init(hub)
	S = hub
end

local function inArena(b, pos)
	return math.abs(pos.X - b.center.X) < b.halfX and math.abs(pos.Z - b.center.Z) < b.halfZ
end

-- cheapest part the player owns: carried loot first, then the garage stash
local function cheapestPart(s)
	for _, id in ipairs(PartConfig.Order) do
		if (s.carried[id] or 0) > 0 then
			return id, "carried"
		end
	end
	for _, id in ipairs(PartConfig.Order) do
		if (s.data.parts[id] or 0) > 0 then
			return id, "banked"
		end
	end
	return nil
end
Boss.CheapestPart = cheapestPart

local function setMode(b, mode, dur)
	b.mode = mode
	b.modeUntil = os.clock() + (dur or 0)
	b.model:SetAttribute("Mode", mode)
	b.model:SetAttribute("Hits", b.hits)
end

local function pickTarget(b)
	local best, bestD
	for _, p in ipairs(Players:GetPlayers()) do
		local hrp, hum = S.Data.GetRoot(p)
		if hrp and hum and hum.Health > 0 and inArena(b, hrp.Position) then
			local d = (hrp.Position - b.pos).Magnitude
			if not bestD or d < bestD then
				best, bestD = p, d
			end
		end
	end
	return best
end

local function steer(b, dt, goal, speedMul)
	local st = b.stats
	local to = goal - b.pos
	to = Vector3.new(to.X, 0, to.Z)
	local want = to.Magnitude > 0.1 and math.atan2(-to.X, -to.Z) or b.yaw
	-- push away from cover so the truck drives around containers/rocks/columns
	for _, c in ipairs(b.covers) do
		local d = Vector3.new(b.pos.X - c.p.X, 0, b.pos.Z - c.p.Z)
		local m = d.Magnitude
		if m < c.r + b.halfW + 6 and m > 0.01 then
			local away = math.atan2(-d.X, -d.Z)
			want = want + math.clamp(((away - want + math.pi) % (2 * math.pi)) - math.pi, -0.8, 0.8)
		end
	end
	local diff = ((want - b.yaw + math.pi) % (2 * math.pi)) - math.pi
	b.yaw = b.yaw + math.clamp(diff, -st.turn * dt, st.turn * dt)
	local target = st.speed * speedMul * (1 - math.min(0.6, math.abs(diff) / math.pi)) -- slows in tight turns
	b.speed = b.speed + math.clamp(target - b.speed, -st.accel * 2 * dt, st.accel * dt)
	local fwd = Vector3.new(-math.sin(b.yaw), 0, -math.cos(b.yaw))
	local np = b.pos + fwd * b.speed * dt
	np = Vector3.new(math.clamp(np.X, b.center.X - b.halfX + b.halfW, b.center.X + b.halfX - b.halfW), 0,
		math.clamp(np.Z, b.center.Z - b.halfZ + b.halfL, b.center.Z + b.halfZ - b.halfL))
	b.pos = np
end

local function hitPlayers(b)
	if b.mode == "stun" or b.mode == "flee" or b.speed < 6 then
		return
	end
	local cf = CFrame.new(b.pos) * CFrame.Angles(0, b.yaw + math.pi / 2, 0) -- local +X = forward
	for _, p in ipairs(Players:GetPlayers()) do
		local hrp = S.Data.GetRoot(p)
		if hrp and hrp.Position.Y < b.height + 3 then
			local lp = cf:PointToObjectSpace(hrp.Position)
			if math.abs(lp.X) < b.halfL + 1.5 and math.abs(lp.Z) < b.halfW + 1.5 then
				local dirX = math.sign(cf.LookVector.X)
				if S.Traffic.Wreck(p, dirX ~= 0 and dirX or 1) then
					Net.Get("BossFx"):FireAllClients({ event = "smash", boss = b.id, pos = hrp.Position })
				end
			end
		end
	end
end

local function update(b, dt)
	local now = os.clock()
	if (b.mode == "stun" or b.mode == "flee") and now > b.modeUntil then
		b.hits = 0
		setMode(b, "roam")
	end
	if b.mode == "stun" then
		b.speed = math.max(0, b.speed - 60 * dt)
	elseif b.mode == "flee" then
		-- run to the far end of the arena and sulk there
		steer(b, dt, b.center + Vector3.new(0, 0, b.halfZ - b.halfL - 4), 0.8)
	else
		local target = pickTarget(b)
		if target then
			local hrp = S.Data.GetRoot(target)
			b.target = target
			if b.mode ~= "chase" then
				setMode(b, "chase")
			end
			-- aim a little ahead of the player
			local lead = hrp.AssemblyLinearVelocity * 0.35
			steer(b, dt, hrp.Position + Vector3.new(lead.X, 0, lead.Z), 1)
		else
			b.target = nil
			if b.mode ~= "roam" then
				setMode(b, "roam")
			end
			if not b.wander or (b.wander - b.pos).Magnitude < 12 then
				b.wander = b.center + Vector3.new(b.rng:NextNumber(-1, 1) * b.halfX * 0.7, 0, b.rng:NextNumber(-1, 1) * b.halfZ * 0.7)
			end
			steer(b, dt, b.wander, 0.45)
		end
	end
	local hop = 0
	if b.stats.jump and b.mode == "chase" then
		local ph = (now % 7) / 7
		if ph > 0.85 then
			hop = math.sin((ph - 0.85) / 0.15 * math.pi) * 9
		end
	end
	b.model:PivotTo(CFrame.new(b.pos + Vector3.new(0, hop, 0)) * CFrame.Angles(0, b.yaw + math.pi / 2, 0))
	if hop < 2 then
		hitPlayers(b)
	end
end

function Boss.Throw(player)
	local s = S.Data.Get(player)
	if not s or not s.ready or not S.Data.RateLimit(player, "bossThrow", 0.9) then
		return
	end
	local hrp = S.Data.GetRoot(player)
	if not hrp then
		return
	end
	local b
	for _, bb in pairs(bosses) do
		if inArena(bb, hrp.Position) and (bb.pos - hrp.Position).Magnitude < Boss.ThrowRange then
			b = bb
		end
	end
	if not b or b.mode == "flee" then
		return
	end
	local partId, from = cheapestPart(s)
	if not partId then
		S.Data.Notify(player, "nothingToThrow", nil, "warn")
		return
	end
	if from == "carried" then
		s.carried[partId] = s.carried[partId] - 1
		if s.carried[partId] <= 0 then
			s.carried[partId] = nil
		end
	else
		s.data.parts[partId] = s.data.parts[partId] - 1
	end
	b.hits = b.hits + 1
	b.helpers[player] = true
	Net.Get("BossFx"):FireAllClients({ event = "throw", boss = b.id, from = hrp.Position, to = b.pos, part = partId, hits = b.hits })
	if b.hits >= Boss.HitsToScare then
		setMode(b, "flee", Boss.FleeTime)
		Net.Get("BossFx"):FireAllClients({ event = "flee", boss = b.id, pos = b.pos })
		-- everyone who helped gets a tuning part from this arena's drop table
		local td = PartConfig.TuningDrops[b.zone]
		for p in pairs(b.helpers) do
			if p.Parent and td then
				local fams = { "ecu", "turbo", "super", "exhaust", "intake", "nitro", "tires", "aero" }
				local item = fams[math.random(1, #fams)] .. td.stages[math.random(1, #td.stages)]
				S.Tuning.Give(p, item, 1)
				S.Data.Notify(p, "bossScared", { require(Shared:WaitForChild("TuningConfig")).Items[item].name }, "good")
			end
		end
		b.helpers = {}
	else
		setMode(b, "stun", Boss.StunTime)
		S.Data.Notify(player, "bossStunned", nil, "good")
	end
	S.Data.Push(player)
end

function Boss.Start()
	task.spawn(function()
		local map = Workspace:WaitForChild("GeneratedMap", 60)
		if not map then
			return
		end
		task.wait(1)
		local folder = Instance.new("Folder")
		folder.Name = "Bosses"
		folder.Parent = Workspace
		for _, c in ipairs(CollectionService:GetTagged("Arena")) do
			local look = c:GetAttribute("Boss") or "crusher"
			local model = SV.MonsterTruck(look)
			model.Name = "Boss_" .. look
			local b = {
				id = look, zone = c:GetAttribute("ZoneId"), model = model, stats = Boss.Stats[look] or Boss.Stats.crusher,
				center = Vector3.new(c.Position.X, 0, c.Position.Z), halfX = c:GetAttribute("HalfX"), halfZ = c:GetAttribute("HalfZ"),
				halfL = model:GetAttribute("HalfL"), halfW = model:GetAttribute("HalfW"), height = model:GetAttribute("Height"),
				yaw = 0, speed = 0, hits = 0, mode = "roam", modeUntil = 0, helpers = {}, covers = {}, rng = Random.new(),
			}
			b.pos = b.center + Vector3.new(0, 0, b.halfZ * 0.5)
			for _, part in ipairs(map:GetDescendants()) do
				if part:IsA("BasePart") and (part.Name == "ScrapContainer" or part.Name == "CanyonRock" or part.Name == "Column") and inArena(b, part.Position) then
					table.insert(b.covers, { p = part.Position, r = math.max(part.Size.X, part.Size.Z) / 2 })
				end
			end
			model:SetAttribute("ZoneId", b.zone)
			model:SetAttribute("BossId", look)
			setMode(b, "roam")
			model:PivotTo(CFrame.new(b.pos))
			model.Parent = folder
			bosses[look] = b
		end
		RunService.Heartbeat:Connect(function(dt)
			dt = math.min(dt, 0.1)
			for _, b in pairs(bosses) do
				update(b, dt)
			end
		end)
	end)
end

return Boss
