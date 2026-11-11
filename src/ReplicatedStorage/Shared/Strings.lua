local Strings = {}

local en = {
	hud_money = "Money", hud_income = "Income", hud_zone = "District", hud_carry = "Backpack",
	zone_plaza = "Safe Plaza", zone_city = "City", zone_highway = "Highway",
	zone_industrial = "Industrial", zone_neon = "Night",
	part_bolts = "Bolts", part_tire = "Tire", part_engine = "Engine", part_turbo = "Turbo", part_core = "Core",
	rarity_Common = "Common", rarity_Uncommon = "Uncommon", rarity_Rare = "Rare", rarity_Epic = "Epic", rarity_Legendary = "Legendary",
	btn_throw = "THROW!", btn_garage = "GARAGE", btn_zones = "TELEPORT", btn_index = "CARS", btn_close = "X",
	btn_teleport = "TELEPORT", btn_go = "GO!", btn_awesome = "AWESOME!", tp_title = "TELEPORT", tp_home = "MY GARAGE",
	tp_home_desc = "Safe zone. Bank loot, throw parts.", tp_walk = "Carrying loot? Run it home on foot!",
	hud_risky = "RISKY LOOT %d / %d", wrecked = "WRECKED!", wrecked_lost = "LOST: %s", wrecked_safe = "Cars, money and banked parts are safe",
	wrecked_back = "Back in %d...", speed_lane = "SPEED LANE",
	btn_place = "PARK", btn_remove = "UNPARK", btn_upgrade = "UPGRADE", btn_unlock = "UNLOCK", btn_max = "MAX",
	btn_buyslot = "+ SLOT", btn_sell = "SELL", btn_sure = "SURE?", btn_autopark = "PARK BEST",
	throw_title = "CHOOSE BAIT", throw_none = "No parts yet",
	throw_odds = "Drop chances", throw_pity = "Epic+ guaranteed in %d throws", throw_pity_now = "Next throw: Epic+ guaranteed!",
	garage_title = "MY GARAGE", garage_slots = "Parking", garage_cars = "My Cars",
	garage_empty = "No cars yet. Grab parts in the city and throw them on your trap!",
	car_level = "Lv %d", car_income = "+%s/s", car_parked = "Slot %d", car_stored = "Storage",
	reveal_new = "NEW CAR!", reveal_got = "YOU GOT", reveal_first = "FIRST DISCOVERY  +$%s",
	reveal_placed = "Parked in slot %d", reveal_stored = "Garage full - sent to storage", reveal_pity = "Lucky guarantee!",
	index_title = "CAR COLLECTION", index_found = "%d / %d discovered", index_bonus = "Income bonus x%s",
	index_hint = "Complete a rarity row: +5% income. Complete all: +10% more.", index_unknown = "???",
	zones_title = "City Map", zones_open = "Unlocked", zones_locked = "Locked", zones_need_prev = "Unlock previous first",
	zones_cost = "Price", zones_value = "Collection value", zones_done = "Every district is open. You rule the streets!",
	zone_desc_city = "Calm streets. Bolts and tires.", zone_desc_highway = "Fast lanes. Tires, engines, turbos.",
	zone_desc_industrial = "Heavy trucks. Engines and turbos.", zone_desc_neon = "Night racers. Turbos and cores.",
	tut_find = "Grab a glowing part - one car hit = WRECKED!",
	tut_return = "Run back to the plaza to bank your loot!",
	tut_throw = "Go to the trap in your garage and press THROW!",
	tut_upgrade = "Open Garage and upgrade a car to earn faster.",
	tut_zone = "New district available! Open TELEPORT.",
	n_noPart = "You don't have that part.", n_trapBusy = "The trap is busy - one moment.",
	n_tooFar = "Get closer to your garage.", n_storageFull = "Car storage is full. Sell some cars.",
	n_dataFail = "Your data failed to load. Progress will NOT be saved this session.",
	n_studioNoSave = "Studio test without API access: progress is not saved.",
	n_carryFull = "Backpack full! Head back to the plaza.", n_picked = "+1 %s",
	n_banked = "Loot secured!", n_lost = "WRECKED! Lost %d carried part(s).", n_carryWalk = "You carry loot - run it home on foot!",
	n_tpWait = "Teleport recharging...", n_teleported = "Whoosh!",
	n_hit = "Ouch! Watch the traffic!", n_zoneLocked = "This district is locked.",
	n_zoneUnlocked = "District unlocked: %s!", n_upgraded = "Upgraded to level %d!",
	n_slotBought = "Parking slot %d unlocked!", n_noMoney = "Not enough money.", n_noParts = "Not enough parts.",
	n_maxLevel = "Already max level.", n_slow = "Too fast - slow down.", n_busy = "Please wait...",
	n_starter = "Here's a free bolt to get you going!", n_noBase = "No garage assigned.", n_stale = "Out of date - try again.",
	n_needPrev = "Unlock the previous district first.", n_needValue = "Collection value too low.",
	n_full = "Server is full.", n_moved = "Car moved.", n_removed = "Car unparked.",
	n_sold = "Sold %s for $%s", n_autoParked = "Best cars parked!",
	lb_title = "TOP INCOME / SEC", free_garage = "FREE GARAGE", garage_of = "%s's Garage",
	locked_sign = "LOCKED", income_sign = "INCOME",
}

Strings.Tables = { en = en }
Strings.Lang = "en"

function Strings.SetLocale()
	Strings.Lang = "en"
end

function Strings.T(key, ...)
	local s = en[key] or key
	if select("#", ...) > 0 then
		local ok, res = pcall(string.format, s, ...)
		if ok then
			return res
		end
	end
	return s
end

return Strings
