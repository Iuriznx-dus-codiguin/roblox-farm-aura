--!strict
-- Formatação de números para a interface: 1234 -> "1.23K", 5_000_000 -> "5M".

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

local Format = {}

function Format.short(value: number): string
	local n = math.floor(value)
	if math.abs(n) < 1000 then
		return tostring(n)
	end
	local tier = 1
	local scaled = n
	while math.abs(scaled) >= 1000 and tier < #SUFFIXES do
		scaled /= 1000
		tier += 1
	end
	local text = string.format("%.2f", scaled):gsub("%.?0+$", "")
	return text .. SUFFIXES[tier]
end

return Format
