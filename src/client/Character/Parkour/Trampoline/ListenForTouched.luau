local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Packages.Net)
local PlaySound = require(ReplicatedStorage.Modules.FX.PlaySound)
local Slide = require(ReplicatedStorage.Modules.Character.Parkour.Landing.Slide)

local PlaySoundRE = Net:RemoteEvent("PlaySound")

local localPlayer = Players.LocalPlayer
local lastBounce = {}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function handleBounce(tramp)
	local character = localPlayer.Character
	local rootPart = character.HumanoidRootPart

	local bounceAmount = tramp:GetAttribute("BounceAmount") / 1.2

	if character:GetAttribute("Sliding") == true then
		bounceAmount *= 1.5
		Slide.Stop()
	end

	character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

	local rootASV = rootPart.AssemblyLinearVelocity
	rootPart.AssemblyLinearVelocity = Vector3.new(rootASV.X, bounceAmount, rootASV.Z)

	PlaySoundRE:FireServer("Trampoline", rootPart)
	PlaySound("Trampoline", rootPart)
	-- SHAKE
end

local function getTrampolineBelow(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end

	local rayOrigin = hrp.Position + Vector3.new(0, 0.2, 0)
	local rayDirection = Vector3.new(0, -3.8, 0)

	params.FilterDescendantsInstances = { character }

	local result = workspace:Raycast(rayOrigin, rayDirection, params)
	if result and CollectionService:HasTag(result.Instance, "Trampoline") then return result.Instance end

	return nil
end

RunService.RenderStepped:Connect(function()
	local character = localPlayer.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end

	local tramp = getTrampolineBelow(character)
	if tramp then
		if not lastBounce[tramp] or os.clock() - lastBounce[tramp] > 0.5 then
			handleBounce(tramp)
			lastBounce[tramp] = os.clock()
		end
	end
end)

return 0
