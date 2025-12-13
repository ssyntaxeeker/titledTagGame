local function brighten(color, factor)
	factor = factor or 1.2
	local r = math.clamp(color.R * factor, 0, 1)
	local g = math.clamp(color.G * factor, 0, 1)
	local b = math.clamp(color.B * factor, 0, 1)
	return Color3.new(r, g, b)
end

return brighten
