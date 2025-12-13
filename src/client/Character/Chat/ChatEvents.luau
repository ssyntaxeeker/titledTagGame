local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local function IncomingMessage(message)
	if not message.TextSource then return end

	local player = Players:GetPlayerByUserId(message.TextSource.UserId)
	if not player then return end

	local character = player.Character

	local roleColor = Color3.fromRGB(255, 255, 255)

	if character then
		local role = character:GetAttribute("Role")

		if role then
			local roleConfig = require(ReplicatedStorage.Shared.Configs.Roles[role])
			roleColor = roleConfig.Color
		end
	end

	local properties = Instance.new("TextChatMessageProperties")

	if roleColor then
		local r = string.format("%.0f", roleColor.R * 255)
		local g = string.format("%.0f", roleColor.G * 255)
		local b = string.format("%.0f", roleColor.B * 255)

		local colorTag = `<font color="rgb({r},{g},{b})">`
		local crown = ""

		if player.Name == "Vesp_Ithon" then crown = `{colorTag}👑</font> ` end

		properties.PrefixText = `{crown}{colorTag}{player.DisplayName}:</font>`
	end

	return properties
end

TextChatService.OnIncomingMessage = IncomingMessage

return 0
