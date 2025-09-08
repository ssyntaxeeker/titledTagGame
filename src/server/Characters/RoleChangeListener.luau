local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local RolesInterface = require(ServerStorage.Modules.GameLogic.Roles.RolesInterface)

local function setCollisionGroup(character, group)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then part.CollisionGroup = group end
	end
end

RolesInterface.onRoleChange:Connect(function(player, roleName)
	local character = player.Character or player.CharacterAdded:Wait()
	local roleConfig = require(ReplicatedStorage.Shared.Configs.Roles[roleName])

	local bodyColors = character:WaitForChild("Body Colors")

	bodyColors.TorsoColor3 = roleConfig.Color
	bodyColors.RightLegColor3 = roleConfig.Color
	bodyColors.LeftLegColor3 = roleConfig.Color

	setCollisionGroup(character, roleName == "Dead" and "DeadPlayers" or "Players")
end)

return 0
