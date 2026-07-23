--!strict
--[[
    PrivateServerCommandFeedback (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/19

    Displays concise feedback for private-server permission commands.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Net = require(ReplicatedStorage.Packages.Net)

local FeedbackRE = Net:RemoteEvent("PrivateServerCommandFeedback")

FeedbackRE.OnClientEvent:Connect(function(message: any)
	if typeof(message) ~= "string" then return end
	local success = pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "Private Server",
			Text = message,
			Duration = 4,
		})
	end)
	if not success then warn(`[PrivateServerCommandFeedback] {message}`) end
end)

return 0
