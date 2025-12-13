local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputsManager = require(ReplicatedStorage.Modules.Inputs.InputsManager)
local LeaderboardFunctions = require(script.Parent.LeaderboardFunctions)

InputsManager.AddInput("ToggleLeaderboard", {
	Keys = { Enum.KeyCode.Tab },
	OnBegan = function()
		LeaderboardFunctions.ToggleListVisible()
	end,
})

return 0
