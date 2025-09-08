local ModesList = {}

local list = {}

function ModesList.AddMode(modeName, callback)
	list[modeName] = callback

	return 0
end

function ModesList.GetMode(modeName)
	return list[modeName]
end

return ModesList
