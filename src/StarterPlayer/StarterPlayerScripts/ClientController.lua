local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Strings = require(Shared:WaitForChild("Strings"))
local MapConfig = require(Shared:WaitForChild("MapConfig"))
local BaseLayout = require(Shared:WaitForChild("BaseLayout"))
local Util = require(Shared:WaitForChild("Util"))

local Client = script.Parent:WaitForChild("Client")
local Store = require(Client:WaitForChild("StateStore"))
local UI = require(Client:WaitForChild("UI"))
local TrafficRenderer = require(Client:WaitForChild("TrafficRenderer"))
local TrapFx = require(Client:WaitForChild("TrapFx"))
local WorldFx = require(Client:WaitForChild("WorldFx"))
local Guidance = require(Client:WaitForChild("Guidance"))
local CineFx = require(Client:WaitForChild("CineFx"))
local DeathFx = require(Client:WaitForChild("DeathFx"))
local SpeedLanes = require(Client:WaitForChild("SpeedLanes"))
local UIExtra = require(Client:WaitForChild("UIExtra"))
local Markers = require(Client:WaitForChild("Markers"))
local ClientFx = require(Client:WaitForChild("ClientFx"))
local GaragePrompts = require(Client:WaitForChild("GaragePrompts"))
local ZoneFx = require(Client:WaitForChild("ZoneFx"))
local BossFx = require(Client:WaitForChild("BossFx"))
local BatchReveal = require(Client:WaitForChild("BatchReveal"))
local Checkpoint = require(Client:WaitForChild("Checkpoint"))
local Tutorial = require(Client:WaitForChild("Tutorial"))
local Rewards = require(Client:WaitForChild("Rewards"))
local Trade = require(Client:WaitForChild("Trade"))

local player = Players.LocalPlayer
-- keep the camera close: no flying out over the map edge
player.CameraMaxZoomDistance = 45
player.CameraMinZoomDistance = 6
Strings.SetLocale(player.LocaleId)

local actions = {
	Throw = function(partId) Net.Get("ThrowPart"):FireServer(partId) end,
	ThrowBatch = function(counts, merge) Net.Get("ThrowBatch"):FireServer(counts, merge) end,
	Place = function(uid, slot) Net.Get("PlaceCar"):FireServer(uid, slot) end,
	Remove = function(uid) Net.Get("RemoveCar"):FireServer(uid) end,
	Upgrade = function(uid, level) Net.Get("UpgradeCar"):FireServer(uid, level) end,
	BuySlot = function(count) Net.Get("BuySlot"):FireServer(count) end,
	BuyFloor = function(floors) Net.Get("BuyFloor"):FireServer(floors) end,
	Unlock = function(zoneId) Net.Get("UnlockZone"):FireServer(zoneId) end,
	Sell = function(uid) Net.Get("SellCar"):FireServer(uid) end,
	SellMany = function(uids) Net.Get("SellCars"):FireServer(uids) end,
	AutoPark = function() Net.Get("AutoPark"):FireServer() end,
	BuyPerk = function(id) Net.Get("BuyPerk"):FireServer(id) end,
	Donate = function(id) Net.Get("Donate"):FireServer(id) end,
	Claim = function(id) Net.Get("ClaimContract"):FireServer(id) end,
	Craft = function(id) Net.Get("CraftTuning"):FireServer(id) end,
	Tune = function(uid, cat, item) Net.Get("TuneCar"):FireServer(uid, cat, item) end,
	Rebirth = function() Net.Get("Rebirth"):FireServer() end,
	SetSkin = function(id) Net.Get("SetSkin"):FireServer(id) end,
	TokenPerk = function(id) Net.Get("TokenPerk"):FireServer(id) end,
	Teleport = function(dest)
		UI.Sfx("whoosh")
		CineFx.Flash(Color3.fromRGB(46, 168, 255), 0.2, 0.5)
		CineFx.Zoom(95, 0.12)
		task.delay(0.15, function() CineFx.Zoom(70, 0.4) end)
		Net.Get("Teleport"):FireServer(dest)
	end,
}

UI.Init(Store, actions)
CineFx.Init(UI.Gui())
TrapFx.SetSfx(UI.Sfx)
TrapFx.SetReveal(UI.ShowReveal, UI.HideReveal)
TrapFx.SetCinematic(UI.SetCinematic)
WorldFx.Start(Store)
TrafficRenderer.Start()
Guidance.Start()
SpeedLanes.Start(function()
	return Store.State and Store.State.walkSpeed or MapConfig.WalkSpeed
end)
UIExtra.Init(UI)
ZoneFx.Start()
BossFx.Start(UI, CineFx)
BatchReveal.Start(UI, CineFx, TrapFx)
Checkpoint.Start(UI, CineFx)
Tutorial.Start(UI, CineFx, Guidance)
Rewards.Start(UI)
Trade.Start(UI)
ClientFx.Init(UI)
Markers.Start(UI.Kit(), UIExtra)
GaragePrompts.Start(UI.Kit(), CineFx)
UI.Refresh()

Net.Get("HotDrop").OnClientEvent:Connect(function(info) UIExtra.OnHotDrop(info) end)
Net.Get("PickupFx").OnClientEvent:Connect(function(info) ClientFx.Pickup(info) end)
Net.Get("BankFx").OnClientEvent:Connect(function(info) ClientFx.Bank(info) end)
Net.Get("DonateFx").OnClientEvent:Connect(function(buyer, key) ClientFx.Donate(buyer, key) end)

Net.Get("StateUpdate").OnClientEvent:Connect(function(state) Store.Set(state) end)
Net.Get("MoneySync").OnClientEvent:Connect(function(m, inc, val) Store.SetMoney(m, inc, val) end)
Net.Get("Notify").OnClientEvent:Connect(function(payload)
	if payload and (payload.key == "lost" or payload.key == "picked" or payload.key == "banked2" or payload.key == "banked") then
		return -- shown by the WRECKED screen
	end
	UI.Notify(payload)
end)
Net.Get("HitFx").OnClientEvent:Connect(function(dir, kind)
	if kind == "airbag" then
		ClientFx.Airbag(dir or Vector3.new(1, 0, 0))
		return
	end
	local lost = Store.State and Util.CopyTable(Store.State.carried) or {}
	TrapFx.Abort()
	BatchReveal.Close()
	UI.TogglePanel(nil)
	UI.CloseOverlays()
	UI.HideReveal()
	DeathFx.Play(dir or Vector3.new(1, 0, 0), lost, UI.Sfx)
end)
Net.Get("ThrowResult").OnClientEvent:Connect(function(res)
	local idx = Store.State and Store.State.baseIndex
	TrapFx.Play(res, idx)
end)
player.CharacterAdded:Connect(function()
	DeathFx.Recover()
end)

task.spawn(function()
	while true do
		task.wait(0.2)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local st = Store.State
		if hrp then
			UI.SetZoneName(MapConfig.ZoneAt(hrp.Position.Z))
			local near = false
			if st and st.baseIndex then
				local trap = BaseLayout.ToWorld(st.baseIndex, BaseLayout.TrapLocal)
				near = Vector3.new(hrp.Position.X - trap.X, 0, hrp.Position.Z - trap.Z).Magnitude <= 35
			end
			UI.SetNearTrap(near and not CineFx.IsScripted())
		end
	end
end)
