local ServerStorage = game:GetService("ServerStorage")

local RolesInterface = require(ServerStorage.Modules.GameLogic.Roles.RolesInterface)

local RolesFunctions = {}

local registeredRoles = {}

function RolesFunctions.ChangeRole(player, roleName)
	if not registeredRoles[roleName] then
		warn(`Couldn't change {player.Name}'s role to {roleName}: Role is not registered`)
		return
	end

	task.spawn(function()
		local character = player.Character or player.CharacterAdded:Wait()
		character:SetAttribute("Role", roleName)
		registeredRoles[roleName](player)
	end)

	RolesInterface.onRoleChange:Fire(player, roleName)
end

function RolesFunctions.RegisterRole(roleName, callback)
	registeredRoles[roleName] = callback

	return 0
end

return RolesFunctions
