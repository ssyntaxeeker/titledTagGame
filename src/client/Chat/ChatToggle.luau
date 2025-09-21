local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Announce = require(ReplicatedStorage.Modules.FX.Announce)
local Net = require(ReplicatedStorage.Packages.Net)

local ToggleChatRE = Net:RemoteEvent("ToggleChat")

ToggleChatRE.OnClientEvent:Connect(function(bool)
	if StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Chat) == bool then return end

	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, bool)

	Announce(bool == true and "You're whitelisted so you can chat!" or "You are not allowed to chat due to not being whitelisted.")
end)

return 0
