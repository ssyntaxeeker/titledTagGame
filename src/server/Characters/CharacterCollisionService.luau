--!strict
--[[
    CharacterCollisionService (Server)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Applies the shared body collision policy authoritatively after spawning.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterCollisionConfig = require(ReplicatedStorage.Shared.Configs.CharacterCollisionConfig)

local CharacterCollisionService = {}

--[=[
	@server
	@tag Authoritative

	apply
	=====

	Makes server and client character collision state agree before gameplay.
]=]
function CharacterCollisionService.apply(character: Model)
	for _, descendant in character:GetDescendants() do
		if not descendant:IsA("BasePart") then continue end
		descendant.CanCollide = CharacterCollisionConfig.collidablePartNames[descendant.Name] == true
	end
end

return table.freeze(CharacterCollisionService)
