local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")

local BotAccess = require(ReplicatedStorage.Shared.Configs.BotAccess)
local ChatConfig = require(ReplicatedStorage.Shared.Configs.ChatConfig)
local Dev = require(ReplicatedStorage.Shared.Configs.Dev)
local Sandwich = require(ReplicatedStorage.Packages.Sandwich)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

print("INITIALIZING CLIENT")
print("-------------------")

Schedules["Boot"] = Sandwich.schedule()

local botModules = ReplicatedStorage.Modules:FindFirstChild("Bot")
local chatModules = ReplicatedStorage.Modules:FindFirstChild("Chat")
local canLoadBotTrainer = BotAccess.userIds[Players.LocalPlayer.UserId] == true
if not ChatConfig.enabled then
	ContextActionService:UnbindAction("CaptureChatTypeBoxFocus")
end
for _, module in ReplicatedStorage.Modules:GetDescendants() do
	if not module:IsA("ModuleScript") then continue end
	if chatModules and module:IsDescendantOf(chatModules) and not ChatConfig.enabled then continue end
	if botModules and module:IsDescendantOf(botModules) then
		if module.Name ~= "BotTrainer" or not canLoadBotTrainer then continue end
	end

	if Dev.debugMode == true and RunService:IsStudio() then print("INITIALIZING " .. module.Name) end

	require(module)
end

print("-------------------")
print("CLIENT INITIALIZED")

Schedules["Boot"].start()
