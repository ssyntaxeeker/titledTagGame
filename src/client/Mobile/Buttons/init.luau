local Buttons = {}

local buttonsList = {}

function Buttons.Register(buttonName, callbacks)
	buttonsList[buttonName] = {}
	buttonsList[buttonName].OnBegan = callbacks.OnBegan or nil
	buttonsList[buttonName].OnEnded = callbacks.OnEnded or nil

	return 0
end

function Buttons.GetList()
	return buttonsList
end

return Buttons
