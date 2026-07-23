--!strict
--[[
    BotTrainer (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Whitelisted lazy launcher for match analysis and authored route training.
	Neither feature begins work until its launcher button is requested.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotAccess = require(ReplicatedStorage.Shared.Configs.BotAccess)
local MouseModalService = require(ReplicatedStorage.Modules.Bot.Analysis.MouseModalService)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local function createLauncher()
	if BotAccess.userIds[Players.LocalPlayer.UserId] ~= true then return end
	local gui = Instance.new("ScreenGui")
	gui.Name = "MatchAnalyzerLauncher"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	MouseModalService.acquire(gui)
	local analysisButton = Instance.new("TextButton")
	analysisButton.AnchorPoint = Vector2.new(1, 0)
	analysisButton.Position = UDim2.new(1, -12, 0, 8)
	analysisButton.Size = UDim2.fromOffset(160, 34)
	analysisButton.BackgroundColor3 = Color3.fromRGB(31, 35, 41)
	analysisButton.BorderSizePixel = 0
	analysisButton.Font = Enum.Font.GothamMedium
	analysisButton.TextSize = 12
	analysisButton.TextColor3 = Color3.fromRGB(235, 239, 245)
	analysisButton.Text = "Open Match Analyzer"
	analysisButton.Parent = gui
	analysisButton.Activated:Once(function()
		analysisButton.Text = "Loading Analyzer..."
		task.spawn(function()
			local runtime = require(ReplicatedStorage.Modules.Bot.Analysis.MatchAnalysisRuntime)
			runtime.init()
			local ui = require(ReplicatedStorage.Modules.Bot.Analysis.MatchAnalysisUI)
			ui.create(runtime, analysisButton)
		end)
	end)
	local routeButton = analysisButton:Clone()
	routeButton.Position = UDim2.new(1, -12, 0, 48)
	routeButton.Text = "Open Route Trainer"
	routeButton.Parent = gui
	routeButton.Activated:Once(function()
		routeButton.Text = "Loading Routes..."
		task.spawn(function()
			local runtime = require(ReplicatedStorage.Modules.Bot.RouteTrainer.RouteTrainerRuntime)
			runtime.init()
			local ui = require(ReplicatedStorage.Modules.Bot.RouteTrainer.RouteTrainerUI)
			ui.bind(runtime, routeButton)
		end)
	end)
end

return Schedules.Boot.job(createLauncher)
