local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local CommandRegistry = require(ServerStorage.Modules.Chat.Commands.CommandRegistry)
local CommandsUtils = require(ServerStorage.Modules.Admin.Commands.CommandsUtils)
local Profiles = require(ServerStorage.Modules.Data.Profiles)

local canUseCommand = {
	"Admin",
	"Ranker",
}

return CommandRegistry.RegisterCommand("rank", function(sender, rankedPlayer, rankType, newRank)
	if not rankedPlayer then return end

	local rankedPlayerInstance

	for _, player in Players:GetPlayers() do
		if player.Name:lower() ~= rankedPlayer:lower() then continue end

		rankedPlayerInstance = player
	end

	if not rankedPlayerInstance then return end

	if rankType ~= "ffa" and rankType ~= "classic" then return end
	if not newRank then return end

	local permission = CommandsUtils.CheckForPermission(Players:GetPlayerByUserId(sender.UserId), canUseCommand)
	if not RunService:IsStudio() and not permission then return end

	rankType = rankType == "ffa" and "Stars" or "Rank"

	local proxy = Profiles.ReturnProxy(rankedPlayer)
	proxy[rankType] = newRank
end)
