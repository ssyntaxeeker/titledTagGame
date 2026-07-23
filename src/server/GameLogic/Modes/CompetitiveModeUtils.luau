--!strict
--[[
    CompetitiveModeUtils (Server)
    =============================
    Author: Sol (3693744006)
    Updated: 26/07/20

    Shared player assignment and role-query operations for competitive modes.
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)

local CompetitiveModeUtils = {}
local random = Random.new()
local previousAssignmentsByRole: { [string]: { [number]: boolean } } = {}

function CompetitiveModeUtils.GetActivePlayers(): { Player }
	local result = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if character and humanoid and humanoid.Health > 0 and character:GetAttribute("Role") ~= "Dead" then
			table.insert(result, player)
		end
	end
	return result
end

function CompetitiveModeUtils.GetPlayersWithRole(roleName: string): { Player }
	local result = {}
	for _, player in Players:GetPlayers() do
		if player.Character and player.Character:GetAttribute("Role") == roleName then table.insert(result, player) end
	end
	return result
end

function CompetitiveModeUtils.AssignShuffled(players: { Player }, roleCounts: { { role: string, count: number } })
	local available = table.clone(players)
	for index = #available, 2, -1 do
		local swapIndex = random:NextInteger(1, index)
		available[index], available[swapIndex] = available[swapIndex], available[index]
	end

	local nextAssignmentsByRole: { [string]: { [number]: boolean } } = {}
	for _, roleInfo in roleCounts do
		local previousAssignments = previousAssignmentsByRole[roleInfo.role] or {}
		local candidates = {}
		for _, player in available do
			if not previousAssignments[player.UserId] then table.insert(candidates, player) end
		end
		for _, player in available do
			if previousAssignments[player.UserId] then table.insert(candidates, player) end
		end

		local assignedUserIds = {}
		nextAssignmentsByRole[roleInfo.role] = assignedUserIds
		for _ = 1, roleInfo.count do
			local player = table.remove(candidates, 1)
			if not player then break end
			local availableIndex = table.find(available, player)
			assert(availableIndex, "[CompetitiveModeUtils.AssignShuffled] candidate is unavailable")
			table.remove(available, availableIndex)
			RolesFunctions.ChangeRole(player, roleInfo.role)
			assignedUserIds[player.UserId] = true
		end
	end
	for roleName, assignments in nextAssignmentsByRole do
		previousAssignmentsByRole[roleName] = assignments
	end
end

return CompetitiveModeUtils
