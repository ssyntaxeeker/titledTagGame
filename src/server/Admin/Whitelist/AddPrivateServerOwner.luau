local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Whitelist = require(ReplicatedStorage.Shared.Configs.Whitelist)

if not game.PrivateServerId or game.PrivateServerId == "" then return 0 end
Whitelist.PrivateServerOwner = { game.PrivateServerOwnerId }

return 0
