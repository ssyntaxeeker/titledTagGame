--!strict
--[[
    BotAudioController (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Lightweight locomotion audio for client bots. Parkour action sounds are
    emitted by BotSkillController; this module only owns cadence-based steps.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local StepSounds = require(ReplicatedStorage.Modules.StepsSound.SteppingSounds)

local BotAudioController = {}

function BotAudioController.attach(character: Model): () -> ()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart or not rootPart:IsA("BasePart") then return function() end end
	local lastStepAt = 0
	local stepIndex = 0
	local activeSounds: { Sound } = {}

	local connection = RunService.Heartbeat:Connect(function()
		if not character.Parent or humanoid.FloorMaterial == Enum.Material.Air then return end
		if character:GetAttribute("Sliding") or character:GetAttribute("Rolling") then return end
		local speed = Vector2.new(rootPart.AssemblyLinearVelocity.X, rootPart.AssemblyLinearVelocity.Z).Magnitude
		if speed < 4 then return end
		local interval = math.clamp(0.42 - speed / 180, 0.2, 0.38)
		if os.clock() - lastStepAt < interval then return end
		lastStepAt = os.clock()

		local materialName = humanoid.FloorMaterial.Name
		local choices = StepSounds[materialName] or StepSounds.Default
		if not choices or #choices == 0 then return end
		stepIndex = stepIndex % #choices + 1
		local sound = Instance.new("Sound")
		sound.Name = "BotStep"
		sound.SoundId = choices[stepIndex].Id
		sound.Volume = 0.18
		sound.RollOffMaxDistance = 45
		sound.PlaybackSpeed = math.clamp(0.9 + speed / 160, 0.9, 1.18)
		sound.Parent = rootPart
		sound.Ended:Once(function()
			local index = table.find(activeSounds, sound)
			if index then table.remove(activeSounds, index) end
			sound:Destroy()
		end)
		activeSounds[#activeSounds + 1] = sound
		sound:Play()
	end)

	return function()
		connection:Disconnect()
		for _, sound in activeSounds do sound:Destroy() end
	end
end

return table.freeze(BotAudioController)
