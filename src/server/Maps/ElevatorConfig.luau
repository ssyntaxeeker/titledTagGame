--!strict
--[[
    ElevatorConfig (Server)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/19

    Default movement tuning and optional per-model attribute names for tagged
    map elevators.
]]

return table.freeze({
	defaultSpeed = 4,
	defaultWaitSeconds = 3,
	speedAttribute = "ElevatorSpeed",
	waitAttribute = "ElevatorWaitTime",
})
