local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local CooldownManager = require(ReplicatedStorage.Vendor.CooldownManager)
local MatchInterface = require(ReplicatedStorage.Modules.Matchmaking.MatchInterface)
local Net = require(ReplicatedStorage.Packages.Net)

local Assets = ReplicatedStorage.Assets

local QueuePlayerRE = Net:RemoteFunction("QueuePlayer")
local DequeuePlayerRE = Net:RemoteFunction("DequeuePlayer")

local localPlayer = Players.LocalPlayer

local MatchUI = Assets.UI.MatchUI:Clone()
MatchUI.Parent = localPlayer.PlayerGui

local MatchUIFunctions = {}

local function clickQueue()
	if CooldownManager.getCooldown(localPlayer, "Queue") then return end
	CooldownManager.modifyCooldown(localPlayer, "Queue", true)

	if MatchInterface.queueStatus then
		DequeuePlayerRE:InvokeServer()
		MatchUI.Full.Queue.Text = "QUEUE"
		MatchInterface.queueStatus = nil
	else
		QueuePlayerRE:InvokeServer()
		MatchUI.Full.Queue.Text = "DEQUEUE"
		MatchInterface.queueStatus = "queued"
	end

	MatchUIFunctions.UpdateUI()
	CooldownManager.modifyCooldown(localPlayer, "Queue", false)
end

function MatchUIFunctions.UpdateUI()
	if MatchInterface.queueStatus then
		MatchUI.Minimized.Description.Text = MatchInterface.queueStatus == "queued" and "You are queued up for a 1v1!"
			or MatchInterface.queueStatus == "teleporting" and "Teleporting to ranked match..."
		if MatchUI.Full.Visible == false then
			MatchUI.Minimized.Visible = true
		else
			MatchUI.Minimized.Visible = false
		end
	end

	local playersInQueue = ReplicatedStorage:GetAttribute("PlayersInQueue") or 0
	MatchUI.Minimized.PlayersInQueue.Text = "players in queue: " .. playersInQueue
	MatchUI.Full.PlayersInQueue.Text = "players in queue: " .. playersInQueue
end

function MatchUIFunctions.ToggleUI(bool)
	MatchUI.Full.Visible = bool
	UserInputService.MouseIconEnabled = bool

	MatchUIFunctions.UpdateUI()
end

function MatchUIFunctions.IsOpen()
	return MatchUI.Full.Visible
end

MatchUI.Full.Queue.MouseButton1Click:Connect(clickQueue)

return MatchUIFunctions
