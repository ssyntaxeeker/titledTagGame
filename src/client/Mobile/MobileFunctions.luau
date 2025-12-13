local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Buttons = require(ReplicatedStorage.Modules.Mobile.Buttons)

local localPlayer = Players.LocalPlayer
local MobileFunctions = {}
local connections = {}

function MobileFunctions.HookButtons()
	local MobileUI = localPlayer.PlayerGui:WaitForChild("MobileUI")

	for buttonName, callback in Buttons.GetList() do
		local button = MobileUI.Buttons:FindFirstChild(buttonName)
		if not button then continue end

		if callback.OnBegan then
			table.insert(
				connections,
				button.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.Touch then callback.OnBegan() end
				end)
			)
		end

		if callback.OnEnded then
			table.insert(
				connections,
				button.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.Touch then callback.OnEnded() end
				end)
			)
		end
	end
end

function MobileFunctions.UnhookButtons()
	for _, callback in Buttons.GetList() do
		if callback.OnEnded then callback.OnEnded() end
	end
	for _, c in connections do
		c:Disconnect()
	end
	connections = {}
end

return MobileFunctions
