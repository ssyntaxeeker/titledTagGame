local Clock = {}

function Clock.SetTime(seconds)
	workspace:SetAttribute("TimeLeft", seconds)
end

return Clock
