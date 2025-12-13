local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerReplicationModules = require(ReplicatedStorage.Modules.Replication.PlayerReplicationModules)

local function listenToVaults(character) end

return PlayerReplicationModules.RegisterModule("VaultSound", listenToVaults)
