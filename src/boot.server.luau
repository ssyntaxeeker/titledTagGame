local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Dev = require(ReplicatedStorage.Shared.Configs.Dev)
local ChatConfig = require(ReplicatedStorage.Shared.Configs.ChatConfig)
local Sandwich = require(ReplicatedStorage.Packages.Sandwich)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

Schedules["Boot"] = Sandwich.schedule()

print("INITIALIZING SERVER")
print("-------------------")

local chatModules = ServerStorage.Modules:FindFirstChild("Chat")
local botModules = ServerStorage.Modules:FindFirstChild("Bot")
for _, module in ServerStorage.Modules:GetDescendants() do
	if not module:IsA("ModuleScript") then continue end
	if chatModules and module:IsDescendantOf(chatModules) and not ChatConfig.enabled then continue end
	if botModules and module:IsDescendantOf(botModules)
		and module.Name ~= "MatchAnalysisData"
		and module.Name ~= "RouteTrainerData"
	then
		continue
	end

	if Dev.debugMode == true and RunService:IsStudio() then print("INITIALIZING " .. module.Name) end

	require(module)
end

print("-------------------")
print("SERVER INITIALIZED")

Schedules["Boot"].start()
