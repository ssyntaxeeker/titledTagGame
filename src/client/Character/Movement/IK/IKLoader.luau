local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IKModule = require(ReplicatedStorage.Modules.Character.Movement.IK.IKModule)

local CharacterTable: { [any]: any } = {}

local function OnCharacterAdded(Character: Model)
	if table.find(CharacterTable, Character.Name) then return end

	CharacterTable[Character.Name] = {}
	task.spawn(function()
		CharacterTable[Character.Name].LegController = IKModule.new(Character, {
			ikEnabled = false,
			tiltingEnabled = false,
			ikExclude = {},
			maxIkVelocity = 1.8,
			onStates = {
				Enum.HumanoidStateType.Running,
			},
			activationVelocity = 1.5,
			maxRootAngle = 24,
			maxAngle = 32,
			interploationSpeed = {
				highVelocityPoint = 1.5,
				Speed = 0.07,
			},
		})
	end)

	Character.Destroying:Connect(function()
		if CharacterTable[Character.Name].LegController then CharacterTable[Character.Name].LegController:Destroy() end
		CharacterTable[Character.Name] = nil
	end)
end

Players.PlayerAdded:Connect(function(Player)
	Player.CharacterAdded:Connect(OnCharacterAdded)
end)

for _, Player in Players:GetPlayers() do
	if Player.Character then OnCharacterAdded(Player.Character) end
	Player.CharacterAdded:Connect(OnCharacterAdded)
end

return 0
