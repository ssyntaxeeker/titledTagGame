local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Schedules = require(ReplicatedStorage.Shared.Schedules)

local localPlayer = Players.LocalPlayer

local function init()
	print("camrea tilt dfrr")
end

return Schedules.Boot.job(init)
