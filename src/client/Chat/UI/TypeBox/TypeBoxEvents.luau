local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Packages.Net)
local TypeBoxFunctions = require(ReplicatedStorage.Modules.Chat.UI.TypeBox.TypeBoxFunctions)

local SetChatTypingModeRE = Net:RemoteEvent("SetChatTypingMode")

SetChatTypingModeRE.OnClientEvent:Connect(function(typingMode) -- 0 = OFF, 1 = LIMITED, 2 = FULL
	if typingMode == 0 then
		TypeBoxFunctions.SetTypingToggle(false)
	elseif typingMode == 1 then
		TypeBoxFunctions.SetTypingToggle(true)
		TypeBoxFunctions.LimitWordsToDictionary(true)
	elseif typingMode == 2 then
		TypeBoxFunctions.SetTypingToggle(true)
		TypeBoxFunctions.LimitWordsToDictionary(false)
	end
end)

return 0
