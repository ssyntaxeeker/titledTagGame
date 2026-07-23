local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local TextChatService = game:GetService("TextChatService")

local CommandsUtils = require(ServerStorage.Modules.Admin.Commands.CommandsUtils)
local PlayerCheckerFunctions = require(ServerStorage.Modules.Admin.Whitelist.PlayerCheckerFunctions)

local canUseCommand = {
	"Admin",
	"PrivateServerOwner",
	"Playtester",
}

return TextChatService.TextChatCommands.SetChatPerms.Triggered:Connect(function(source, command)
	local parameters = CommandsUtils.ParseCommand(command)
	if not parameters then return end

	if not CommandsUtils.CheckForPermission(Players:GetPlayerByUserId(source.UserId), canUseCommand) then return end

	PlayerCheckerFunctions.Perms.chatPerms = parameters[1] == "true" and 1 or 0
	print(`Set chatPerms to {parameters[1] == "true" and 1 or 0}`)

	if PlayerCheckerFunctions.Perms.chatPerms == 1 then
		for _, player in Players:GetPlayers() do
			PlayerCheckerFunctions.CheckChatPerms(player)
		end
	end
end)
