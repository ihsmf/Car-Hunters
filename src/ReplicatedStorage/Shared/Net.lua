local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

Net.Names = {
	"StateUpdate",
	"MoneySync",
	"Notify",
	"ThrowPart",
	"ThrowResult",
	"PlaceCar",
	"RemoveCar",
	"UpgradeCar",
	"BuySlot",
	"UnlockZone",
	"HitFx",
	"SellCar",
	"AutoPark",
	"TrafficHit",
	"Teleport",
	"BuyPerk",
	"Donate",
	"DonateFx",
	"HotDrop",
	"BankFx",
	"PickupFx",
	"BuyFloor",
	"ClaimContract",
	"CraftTuning",
	"TuneCar",
	"BossThrow",
	"BossFx",
	"Rebirth",
	"SetSkin",
	"TokenPerk",
	"ThrowBatch",
	"ThrowBatchResult",
	"OfflineEarnings",
	"SellCars",
	"CheckpointOffer",
	"CheckpointChoice",
	"CheckpointFx",
	"TutorialStep",
}

function Net.Folder()
	local f = ReplicatedStorage:FindFirstChild("Remotes")
	if f then
		return f
	end
	if RunService:IsServer() then
		f = Instance.new("Folder")
		f.Name = "Remotes"
		f.Parent = ReplicatedStorage
		return f
	end
	return ReplicatedStorage:WaitForChild("Remotes")
end

function Net.Get(name)
	local folder = Net.Folder()
	local r = folder:FindFirstChild(name)
	if r then
		return r
	end
	if RunService:IsServer() then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = folder
		return r
	end
	return folder:WaitForChild(name)
end

function Net.EnsureAll()
	for _, n in ipairs(Net.Names) do
		Net.Get(n)
	end
end

return Net
