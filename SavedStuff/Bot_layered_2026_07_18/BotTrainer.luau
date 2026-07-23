--!strict
--[[
    BotTrainer (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Lazy entry point for the bot trainer. Boot creates only a small launcher;
    the AI dependency graph and runtime are initialized when a bot is spawned.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local BotAccess = require(ReplicatedStorage.Shared.Configs.BotAccess)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local initialized = false
local initializing = false
local spawnAfterInitialization = false
local launcherGui: ScreenGui? = nil
local launcherStatus: TextButton? = nil
local STAGED_MODULES = table.freeze({
	"BotNavigationConfig",
	"BotNavigationTypes",
	"BotMovementRules",
	"BotRouteMemory",
	"BotSkillCalibration",
	"BotTelemetry",
	"BotTrainingRecorder",
	"BotMapModel",
	"BotAffordanceBuilder",
	"BotPolicyWeights",
	"BotPolicy",
	"BotOnlinePolicyTrainer",
	"BotPlayerLearningObserver",
	"BotRouteTeaching",
	"BotAnimator",
	"BotAudioController",
	"BotPresentation",
	"BotLearningExplorer",
	"BotStuckRecovery",
	"BotSkillController",
	"BotTactics",
	"BotRoutePlanner",
	"BotAgent",
	"BotExplorationSwarm",
	"BotDebugRenderer",
	"BotTelemetryDashboard",
})

local function initializeRuntime(spawnBot: boolean)
	if initialized or initializing then return end
	spawnAfterInitialization = spawnAfterInitialization or spawnBot
	initializing = true
	if launcherStatus then launcherStatus.Text = "Loading AI..." end
	task.spawn(function()
		RunService.Heartbeat:Wait()
		local botFolder = ReplicatedStorage.Modules.Bot
		for _, moduleName in STAGED_MODULES do
			local module = botFolder:FindFirstChild(moduleName)
			assert(module and module:IsA("ModuleScript"), `[BotTrainer.init] missing {moduleName}`)
			require(module)
			RunService.Heartbeat:Wait()
		end
		local BotRuntime = require(ReplicatedStorage.Modules.Bot.BotRuntime)
		RunService.Heartbeat:Wait()
		BotRuntime.init()
		RunService.Heartbeat:Wait()
		local BotTrainerUI = require(ReplicatedStorage.Modules.Bot.BotTrainerUI)
		RunService.Heartbeat:Wait()
		BotTrainerUI.create(BotRuntime)
		if launcherGui then
			launcherGui:Destroy()
			launcherGui = nil
			launcherStatus = nil
		end
		initialized = true
		initializing = false
		if spawnAfterInitialization then
			spawnAfterInitialization = false
			BotRuntime.spawnBot()
		end
	end)
end

local function createLauncher()
	if BotAccess.userIds[Players.LocalPlayer.UserId] ~= true then return end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("BotTrainerLauncher")
	if existing then existing:Destroy() end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BotTrainerLauncher"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.DisplayOrder = 20
	screenGui.Parent = playerGui
	launcherGui = screenGui

	local button = Instance.new("TextButton")
	button.Name = "SpawnAI"
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, -12, 0, 8)
	button.Size = UDim2.fromOffset(150, 34)
	button.BackgroundColor3 = Color3.fromRGB(31, 35, 41)
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamMedium
	button.Text = "Spawn AI"
	button.TextColor3 = Color3.fromRGB(225, 231, 238)
	button.TextSize = 13
	button.Parent = screenGui
	launcherStatus = button

	button.Activated:Connect(function()
		button.Active = false
		initializeRuntime(true)
	end)

	local bots = workspace:FindFirstChild("Bots")
	if bots and #bots:GetChildren() > 0 then initializeRuntime(false) end
end

return Schedules.Boot.job(createLauncher)
