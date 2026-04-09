local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local ChatUIInterface = require(ReplicatedStorage.Modules.Chat.UI.ChatUIInterface)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local Assets = ReplicatedStorage.Assets

local localPlayer = Players.LocalPlayer

local function init()
	local ChatUI = Assets.UI.Chat:Clone()
	ChatUI.Parent = localPlayer:WaitForChild("PlayerGui")

	ChatUIInterface.UI = ChatUI
	ChatUIInterface.createdChatUISignal:Fire()

	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
end

return Schedules.Boot.job(init)
