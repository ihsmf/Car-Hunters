-- Install / remove tuning parts on owned cars. Removing returns the part to the inventory.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local TuningConfig = require(Shared:WaitForChild("TuningConfig"))

local Tuning = {}
local S

function Tuning.Init(hub)
	S = hub
end

local CATS = {}
for _, c in ipairs(TuningConfig.Categories) do
	CATS[c.id] = true
end

-- itemId = nil removes the part in that category
function Tuning.Set(player, uid, cat, itemId)
	local s = S.Data.Get(player)
	if not s or not s.ready or type(uid) ~= "string" or not CATS[cat] then
		return
	end
	if not S.Data.RateLimit(player, "tune", 0.3) then
		return
	end
	if not S.Base.IsNearOwnBase(player) then
		S.Data.Notify(player, "tuneAtBase", nil, "warn")
		return
	end
	local d = s.data
	local car
	for _, c in ipairs(d.cars) do
		if c.uid == uid then
			car = c
		end
	end
	if not car then
		return
	end
	car.tune = car.tune or {}
	local it = itemId ~= nil and TuningConfig.Items[itemId]
	if itemId ~= nil and (not it or it.cat ~= cat or (d.tuning[itemId] or 0) < 1) then
		return
	end
	local old = car.tune[cat]
	if old == itemId then
		return
	end
	if old then
		d.tuning[old] = (d.tuning[old] or 0) + 1
	end
	if it then
		d.tuning[itemId] = d.tuning[itemId] - 1
		if d.tuning[itemId] <= 0 then
			d.tuning[itemId] = nil
		end
	end
	car.tune[cat] = itemId
	S.Data.Notify(player, it and "tuned" or "untuned", { it and it.name or "" }, "good")
	S.Income.Recalc(player)
	S.Base.RefreshAll(player)
	S.Data.Push(player)
end

-- grant a tuning drop (Tier 3 districts, arenas)
function Tuning.Give(player, itemId, n)
	local s = S.Data.Get(player)
	if s and s.data and TuningConfig.Items[itemId] then
		s.data.tuning[itemId] = math.min((s.data.tuning[itemId] or 0) + (n or 1), 999)
		S.Data.Push(player)
	end
end

return Tuning
