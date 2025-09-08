local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CrosshairFunctions = require(ReplicatedStorage.Modules.Cursor.CrosshairFunctions)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local function init()
	CrosshairFunctions.ToggleDefaultMouse(false)
end

return Schedules.Boot.job(init)
