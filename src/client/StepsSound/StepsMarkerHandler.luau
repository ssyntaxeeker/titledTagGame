local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SoundAssets = ReplicatedStorage.Assets.Sounds

local SteppingSounds = require(ReplicatedStorage.Modules.StepsSound.SteppingSounds)

local checkedAnimations = {}

local lastStepSound = 1

local function step(character)
	if not character:FindFirstChild("HumanoidRootPart") then return end
	if
		character:GetAttribute("Sliding")
		or character:GetAttribute("Vaulting")
		or character:GetAttribute("Swinging")
		or character:GetAttribute("Rolling")
	then
		return
	end

	local humanoid = character.Humanoid
	local humanoidRootPart = character.HumanoidRootPart

	local FloorMaterial = humanoid.FloorMaterial

	local stepSoundMaterial = SteppingSounds[FloorMaterial] or SteppingSounds.Default

	math.randomseed(math.random(1, 1000))
	local newStepSound
	repeat
		task.wait()
		newStepSound = math.random(1, 3)
	until newStepSound ~= lastStepSound

	local StepSoundInstance = humanoidRootPart:FindFirstChild(`StepSound{newStepSound}`)

	if not StepSoundInstance then
		for i = 1, #stepSoundMaterial do
			StepSoundInstance = SoundAssets.StepSound:Clone()
			StepSoundInstance.Name = `StepSound{i}`
			StepSoundInstance.SoundId = stepSoundMaterial[i].Id
			StepSoundInstance.Parent = humanoidRootPart
		end
	end

	StepSoundInstance:Play()
end

RunService.RenderStepped:Connect(function()
	for _, player in Players:GetPlayers() do
		local character = player.Character

		if not character then return end
		if not character:FindFirstChild("Humanoid") or not character:FindFirstChild("HumanoidRootPart") then return end

		character.HumanoidRootPart.Running.Volume = 0

		local humanoid = character.Humanoid
		local animator = humanoid.Animator

		for _, track in animator:GetPlayingAnimationTracks() do
			if table.find(checkedAnimations, track) then continue end

			local hadStepMarker = false

			local endedConnection
			local markerReachedConnection

			markerReachedConnection = track:GetMarkerReachedSignal("step"):Connect(function()
				hadStepMarker = true

				step(character)
			end)

			endedConnection = track.Ended:Connect(function()
				if not hadStepMarker then markerReachedConnection:Disconnect() end

				endedConnection:Disconnect()
			end)

			table.insert(checkedAnimations, track)
		end
	end
end)

return 0
