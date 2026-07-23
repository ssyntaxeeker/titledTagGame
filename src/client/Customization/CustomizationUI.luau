local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomizationInterface = require(ReplicatedStorage.Modules.Customization.CustomizationInterface)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local testUI = playerGui:WaitForChild("Test")
local scrollingFrame = testUI.ScrollingFrame

--testUI.Enabled = localPlayer.UserId == 3693744006

scrollingFrame.StaticVault.FocusLost:Connect(function(enterPressed)
	if not enterPressed then return end

	CustomizationInterface.staticVault = tonumber(scrollingFrame.StaticVault.Text)
	scrollingFrame.StaticVault.Text = ""
end)

return 0
