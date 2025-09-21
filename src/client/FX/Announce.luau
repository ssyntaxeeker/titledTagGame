local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage.Assets

local localPlayer = Players.LocalPlayer

local function announce(message)
	local UI = Assets.UI.AnnouncementUI:Clone()
	UI.Parent = localPlayer.PlayerGui

	UI.Frame.Message.Text = message
	UI.Frame.CloseButton.MouseButton1Click:Once(function()
		UI:Destroy()
	end)

	UI.Enabled = true
end

return announce
