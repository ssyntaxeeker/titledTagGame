--!strict

local Clock = {}

function Clock.SetTime(seconds: number)
	assert(seconds >= -1, "[Clock.SetTime] seconds must be -1 or non-negative")
	workspace:SetAttribute("TimeLeft", seconds)
end

return Clock
