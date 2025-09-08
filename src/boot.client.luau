local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Dev = require(ReplicatedStorage.Shared.Configs.Dev)
local Sandwich = require(ReplicatedStorage.Packages.Sandwich)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

print("INITIALIZING CLIENT")
print("-------------------")

Schedules["Boot"] = Sandwich.schedule()

for _, module in ReplicatedStorage.Modules:GetDescendants() do
	if not module:IsA("ModuleScript") then continue end

	if Dev.debugMode == true and RunService:IsStudio() then print("INITIALIZING " .. module.Name) end

	require(module)
end

print("-------------------")
print("CLIENT INITIALIZED")

Schedules["Boot"].start()
