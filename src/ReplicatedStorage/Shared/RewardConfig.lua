-- Daily login streak (7 days, missing a day resets) and playtime chests per session.
local R = {}

-- money = max(min, income * seconds); parts added on top
R.Daily = {
	{ secs = 120, min = 500, parts = { tire = 3 } },
	{ secs = 180, min = 1000, parts = { engine = 2 } },
	{ secs = 240, min = 1500, parts = { tire = 6 } },
	{ secs = 360, min = 2500, parts = { engine = 3, turbo = 1 } },
	{ secs = 480, min = 4000, parts = { turbo = 2 } },
	{ secs = 600, min = 6000, parts = { engine = 5 } },
	{ secs = 900, min = 10000, parts = { core = 1, turbo = 2 }, pity = true },
}

R.Chests = {
	{ minutes = 5, secs = 60, min = 300, parts = { bolts = 5 } },
	{ minutes = 15, secs = 120, min = 800, parts = { tire = 4 } },
	{ minutes = 30, secs = 240, min = 1500, parts = { engine = 3 } },
	{ minutes = 60, secs = 480, min = 3000, parts = { turbo = 2 } },
	{ minutes = 120, secs = 900, min = 6000, parts = { core = 1 }, tuning = true },
}

function R.Money(entry, income)
	return math.max(entry.min, math.floor((income or 0) * entry.secs))
end

function R.UtcDay(t)
	return math.floor((t or os.time()) / 86400)
end

-- next streak day the player would get today (1..7)
function R.NextDay(daily, today)
	if daily.last == today - 1 then
		return (daily.day or 0) % 7 + 1
	end
	return 1
end

return R
