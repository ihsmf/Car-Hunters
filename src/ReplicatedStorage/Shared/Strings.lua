local Strings = {}

local en = {
	hud_money = "Money", hud_income = "Income", hud_zone = "District", hud_carry = "Backpack",
	zone_plaza = "Safe Plaza", zone_city = "City", zone_highway = "Highway",
	zone_industrial = "Industrial", zone_neon = "Night", zone_scrapyard = "Scrapyard Arena",
	zone_docks = "Docks", zone_desert = "Desert", zone_bridge = "Bridges", zone_airport = "Airport", zone_canyon = "Canyon Arena",
	zone_circuit = "Circuit", zone_drift = "Drift", zone_storm = "Storm", zone_rush = "Rush Hour", zone_colosseum = "Colosseum",
	part_bolts = "Bolts", part_tire = "Tire", part_engine = "Engine", part_turbo = "Turbo", part_core = "Core",
	rarity_Common = "Common", rarity_Uncommon = "Uncommon", rarity_Rare = "Rare", rarity_Epic = "Epic", rarity_Legendary = "Legendary",
	btn_throw = "THROW!", btn_garage = "GARAGE", btn_zones = "TELEPORT", btn_index = "CARS", btn_close = "X",
	btn_teleport = "TELEPORT", btn_go = "GO!", btn_awesome = "AWESOME!", tp_title = "TELEPORT", tp_home = "MY GARAGE",
	tp_home_desc = "Safe zone. Bank loot, throw parts.", tp_walk = "Carrying loot? Run it home on foot!",
	hud_risky = "RISKY LOOT %d / %d", wrecked = "WRECKED!", wrecked_lost = "LOST: %s", wrecked_safe = "Cars, money and banked parts are safe",
	wrecked_back = "Back in %d...", speed_lane = "SPEED LANE",
	btn_place = "PARK", btn_remove = "REMOVE", btn_upgrade = "UPGRADE", btn_unlock = "UNLOCK", btn_max = "MAX",
	btn_buyslot = "+ SLOT", btn_sell = "SELL", btn_sure = "SURE?", btn_autopark = "PARK BEST",
	throw_title = "THROW PARTS", throw_none = "No parts yet",
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
	zone_desc_scrapyard = "BOSS: Crusher the monster truck. Throw parts to scare it!",
	zone_desc_docks = "Freight trains cross the docks. Watch the lights!", zone_desc_desert = "Three-lane highway + sandstorms.",
	zone_desc_bridge = "Narrow bridges over a deep river. Don't fall!", zone_desc_airport = "Taxiing jets. Stay out of the blast!",
	zone_desc_canyon = "BOSS: Juggernaut. Faster, wider, angrier.",
	zone_desc_circuit = "Race cars at 110 studs/s. Tuning parts drop here.", zone_desc_drift = "Cars weave between lanes. Tuning parts drop.",
	zone_desc_storm = "Night storm, low visibility. Stage 3 tuning drops.", zone_desc_rush = "Everything, everywhere, all at once.",
	zone_desc_colosseum = "FINAL BOSS: Titan. Jackpot tuning loot.",
	n_needRebirth = "Needs %d rebirth(s) first.", n_tuneDrop = "TUNING DROP: %s!",
	n_nothingToThrow = "Nothing to throw!", n_bossStunned = "Direct hit! One more to scare it off!", n_bossScared = "Boss scared off! Reward: %s",
	n_rebirthNotYet = "Not ready to rebirth yet.", n_reborn = "REBIRTH %d! +%d tokens, income bonus up!", n_noTokens = "Not enough rebirth tokens.",
	n_skinOn = "Garage skin: %s", btn_rebirth = "REBIRTH", rebirth_title = "REBIRTH", rebirth_go = "REBIRTH NOW",
	rebirth_need = "Unlock %s and have $%s", rebirth_lose = "You lose: money, cars, parts, districts, floors, tuning parts",
	rebirth_keep = "You keep: car collection index, garage skins, Pit Stop upgrades, game passes, tokens",
	rebirth_gain = "You get: +25%% income forever (now x%s) and rebirth tokens", rebirth_tokens = "TOKENS: %d", rebirth_shop = "TOKEN SHOP",
	skin_equip = "EQUIP", skin_on = "ON", skin_bonus = "+%d%% income",
	boss_throw = "THROW!", boss_hint = "Throw to scare it off", boss_empty = "Nothing to throw!", boss_fleeing = "Boss is fleeing!",
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
	n_sold = "Sold %s for $%s", n_soldMany = "Sold %d cars for $%s", n_riskOn = "RISK x%s - cross %s to cash in!", n_autoParked = "Best cars parked!",
	n_needFloor = "Build the next floor first (at the lift).", n_fillFloor = "Buy all bays on this floor first.", n_floorBuilt = "Floor %d built!",
	n_perkBought = "%s upgraded to Lv %d!", n_donateThanks = "Thank you! %s is yours!", n_donateOff = "This item is not on sale yet.",
	n_hotDropMine = "HOT DROP! +%d %s - now run home!", n_contractDone = "Contract done! +$%s",
	n_contractReady = "Contract complete! Claim it from Big Tony.", n_seeTony = "Walk up to Big Tony first.",
	n_noTuneParts = "Not enough tuning parts.", n_crafted = "Tony built you a %s!", n_tuned = "%s installed!", n_untuned = "Part removed.",
	n_tuneAtBase = "Tune your cars at your garage.",
	tony_title = "BIG TONY", tony_rewards = "REWARDS", tony_exchange = "EXCHANGE", tony_claim = "CLAIM", tony_working = "IN PROGRESS",
	tony_hint = "Finish contracts on the road, then come back here for the cash.", tony_build = "BUILD", tony_have = "Have: %d",
	tune_title = "TUNING", btn_tune = "TUNE", tune_empty = "empty", tune_remove = "REMOVE", tune_none = "No parts - trade at Big Tony",
	shop_tab_perks = "UPGRADES", shop_tab_garage = "GARAGE", map_tony = "BIG TONY",
	n_banked2 = "Banked %d parts (+%d combo bonus, x%s) +$%s",
	shop_title = "PIT STOP", shop_buy = "BUY", shop_max = "MAX", shop_lv = "Lv %d/%d",
	donate_title = "GOLDEN MAGNATE", donate_boost = "BOOSTS", donate_pack = "PACKS", donate_pass = "PASSES", donate_owned = "OWNED",
	contracts_title = "CONTRACTS", combo = "COMBO x%s", combo_hint = "Run home to bank!", speed_bonus = "Speed bonus: %ds",
	hot_drop = "HOT DROP", hot_drop_in = "Hot Drop incoming: %s in %ds", hot_drop_taken = "%s grabbed the Hot Drop!",
	hot_drop_called = "%s called a Hot Drop!", airbag = "AIRBAG SAVED YOU!", map_base = "MY GARAGE", map_shop = "PIT STOP",
	map_donate = "MAGNATE", map_contracts = "TONY + CONTRACTS", btn_magnate = "SHOP",
	c_bank_part = "Bring home %d %s from %s", c_combo = "Bank a run with combo x%s", c_speed = "Bank a run within %ds",
	c_throw = "Throw %d parts into the trap", c_road = "Grab %d road crates", c_hotdrop = "Grab a Hot Drop",
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
