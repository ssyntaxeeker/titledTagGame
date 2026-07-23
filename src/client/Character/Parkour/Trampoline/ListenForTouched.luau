local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CameraShake = require(ReplicatedStorage.Modules.Camera.CameraShake)
local Net = require(ReplicatedStorage.Packages.Net)
local PlaySound = require(ReplicatedStorage.Modules.FX.PlaySound)
local ParkourMovementModel = require(ReplicatedStorage.Modules.Character.Parkour.ParkourMovementModel)
local ParkourAssetScope = require(ReplicatedStorage.Shared.Utils.ParkourAssetScope)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)
local Slide = require(ReplicatedStorage.Modules.Character.Parkour.Landing.Slide)

local PlaySoundRE = Net:RemoteEvent("PlaySound")

local localPlayer = Players.LocalPlayer
local lastBounce = {}
local probeElapsed = 0

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function handleBounce(tramp)
	local character = localPlayer.Character
	local rootPart = character.HumanoidRootPart

	local bounceAmount = tramp:GetAttribute("BounceAmount")

	if character:GetAttribute("Sliding") == true then
		--bounceAmount *= 1.5
		Slide.Stop()
	end

	character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

	local rootASV = rootPart.AssemblyLinearVelocity
	rootPart.AssemblyLinearVelocity = ParkourMovementModel.trampolineVelocity(rootASV, bounceAmount)

	PlaySoundRE:FireServer("Trampoline", rootPart)
	PlaySound("Trampoline", rootPart)
	if SettingsInterface.gameplay.cameraShake == true then CameraShake.new():Shake(0.3, bounceAmount / 1.2 / 150, 0.6) end
end

local function getTrampolineBelow(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end

	local rayOrigin = hrp.Position + Vector3.new(0, 0.2, 0)
	local rayDirection = Vector3.new(0, -3.8, 0)

	params.FilterDescendantsInstances = { character }

	local result = workspace:Raycast(rayOrigin, rayDirection, params)
	if result
		and ParkourAssetScope.contains(result.Instance)
		and CollectionService:HasTag(result.Instance, "Trampoline")
	then
		return result.Instance
	end

	return nil
end

RunService.Heartbeat:Connect(function(dt)
	probeElapsed += dt
	if probeElapsed < 1 / 30 then return end
	probeElapsed = 0
	local character = localPlayer.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end

	local tramp = getTrampolineBelow(character)
	if tramp then
		if not lastBounce[tramp] or os.clock() - lastBounce[tramp] > ParkourMovementModel.cooldowns.trampoline then
			handleBounce(tramp)
			lastBounce[tramp] = os.clock()
		end
	end
end)

return 0
