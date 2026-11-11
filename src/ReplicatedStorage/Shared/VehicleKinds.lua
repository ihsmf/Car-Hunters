local C = Color3.fromRGB

local Kinds = {
	compact = { L = 11.5, W = 5.8, H = 4.6, wr = 1.2, clear = 0.7, bodyH = 1.9, cabinL = 6.0, cabinH = 1.9, cabinX = -0.8, cabinW = 0.9, color = C(220, 90, 70) },
	sedan = { L = 14.5, W = 6.2, H = 4.7, wr = 1.3, clear = 0.8, bodyH = 2.0, cabinL = 7.4, cabinH = 1.9, cabinX = -1.0, cabinW = 0.9, color = C(80, 120, 200) },
	taxi = { L = 14.5, W = 6.2, H = 5.4, wr = 1.3, clear = 0.8, bodyH = 2.0, cabinL = 7.4, cabinH = 1.9, cabinX = -1.0, cabinW = 0.9, color = C(250, 205, 40), taxiSign = true },
	van = { L = 14.5, W = 6.6, H = 6.6, wr = 1.4, clear = 0.9, bodyH = 2.2, cabinL = 4.0, cabinH = 1.9, cabinX = 4.2, cabinW = 0.92,
		box = { L = 9.6, H = 3.6, x = -2.2 }, color = C(235, 235, 240) },
	minibus = { L = 18, W = 6.8, H = 7.0, wr = 1.4, clear = 0.9, bodyH = 2.6, cabinL = 14.0, cabinH = 2.6, cabinX = -0.4, cabinW = 0.94, color = C(240, 180, 40) },
	sport = { L = 14.8, W = 6.6, H = 3.9, wr = 1.2, clear = 0.55, bodyH = 1.7, cabinL = 5.0, cabinH = 1.5, cabinX = -1.8, cabinW = 0.84, color = C(210, 40, 45) },
	supercar = { L = 15.2, W = 7.0, H = 3.5, wr = 1.2, clear = 0.45, bodyH = 1.5, cabinL = 4.4, cabinH = 1.4, cabinX = -1.2, cabinW = 0.8, color = C(255, 120, 30) },
	pickup = { L = 16.5, W = 6.6, H = 5.6, wr = 1.5, clear = 1.0, bodyH = 2.3, cabinL = 5.2, cabinH = 2.0, cabinX = 2.6, cabinW = 0.9,
		bed = { L = 6.8, x = -4.6 }, color = C(196, 164, 110) },
	service = { L = 15.5, W = 6.6, H = 6.2, wr = 1.4, clear = 0.9, bodyH = 2.4, cabinL = 4.4, cabinH = 1.9, cabinX = 4.4, cabinW = 0.92,
		box = { L = 9.0, H = 3.5, x = -2.4 }, color = C(235, 170, 40) },
	truck = { L = 26, W = 7.6, H = 8.8, wr = 2.0, clear = 1.4, bodyH = 2.6, cabinL = 5.4, cabinH = 3.0, cabinX = 9.2, cabinW = 0.92,
		box = { L = 17.0, H = 5.2, x = -3.6 }, sixWheels = true, color = C(170, 80, 70) },
	proto = { L = 15.8, W = 7.0, H = 3.7, wr = 1.2, clear = 0.5, bodyH = 1.5, cabinL = 5.2, cabinH = 1.6, cabinX = -0.6, cabinW = 0.78,
		fins = true, canopyNeon = true, color = C(30, 30, 44) },
}

return Kinds
