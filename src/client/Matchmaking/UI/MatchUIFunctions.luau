local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchInterface = require(ReplicatedStorage.Modules.Matchmaking.MatchInterface)

local Assets = ReplicatedStorage.Assets

local localPlayer = Players.LocalPlayer

local MatchUI = Assets.UI.MatchUI:Clone()
MatchUI.Parent = localPlayer.PlayerGui

local MatchUIFunctions = {}

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
	MatchUIFunctions.UpdateUI()
end

return MatchUIFunctions
