local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DebugFunctions = require(ReplicatedStorage.Modules.Debug.DebugFunctions)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local function init()
	RunService.Heartbeat:Connect(function()
		DebugFunctions.Update()
	end)
end

return Schedules.Boot.job(init)
