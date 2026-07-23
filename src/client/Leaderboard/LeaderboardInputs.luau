--!strict
--[[
    LeaderboardInputs (Client)
    ==========================
    Author: Sol (3693744006)
    Updated: 26/07/20

    Binds leaderboard visibility and Tab-held mouse-wheel scrolling.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local InputsManager = require(ReplicatedStorage.Modules.Inputs.InputsManager)
local LeaderboardFunctions = require(script.Parent.LeaderboardFunctions)

InputsManager.AddInput("ToggleLeaderboard", {
	Keys = { Enum.KeyCode.Tab },
	OnBegan = function()
		LeaderboardFunctions.ToggleListVisible()
	end,
})

UserInputService.InputChanged:Connect(function(input: InputObject)
	if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
	if not UserInputService:IsKeyDown(Enum.KeyCode.Tab) then return end
	LeaderboardFunctions.Scroll(input.Position.Z)
end)

return 0
