local Util = {}

function Util.Clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

function Util.IsInt(n)
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge and n == math.floor(n)
end

function Util.FormatNumber(n)
	n = math.floor((tonumber(n) or 0) + 0.5)
	if n < 1000 then
		return tostring(n)
	end
	local units = { { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
	for _, u in ipairs(units) do
		if n >= u[1] then
			local v = n / u[1]
			local s
			if v >= 100 then
				s = string.format("%d", math.floor(v))
			elseif v >= 10 then
				s = string.format("%.1f", v)
			else
				s = string.format("%.2f", v)
			end
			if string.find(s, ".", 1, true) then
				s = string.gsub(s, "0+$", "")
				s = string.gsub(s, "%.$", "")
			end
			return s .. u[2]
		end
	end
	return tostring(n)
end

function Util.WeightedPick(entries, r)
	local total = 0
	for _, e in ipairs(entries) do
		total = total + e[2]
	end
	if total <= 0 then
		return nil
	end
	local acc = 0
	local target = r * total
	for _, e in ipairs(entries) do
		acc = acc + e[2]
		if target < acc then
			return e[1]
		end
	end
	return entries[#entries][1]
end

function Util.CopyTable(t)
	local out = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			out[k] = Util.CopyTable(v)
		else
			out[k] = v
		end
	end
	return out
end

return Util
