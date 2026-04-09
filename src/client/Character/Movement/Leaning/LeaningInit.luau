local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LeaningFunctions = require(ReplicatedStorage.Modules.Character.Movement.Leaning.LeaningFunctions)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local localPlayer = Players.LocalPlayer

local function setUpCharacter(character)
	local rootPart = character:WaitForChild("HumanoidRootPart")
	if not rootPart then return end

	local rootJoint = rootPart:WaitForChild("RootJoint")
	if not rootJoint then return end

	rootJoint:SetAttribute("OriginalC0", rootJoint.C0)
end

local function init()
	local characterExists = localPlayer.Character
	if characterExists then setUpCharacter(characterExists) end

	localPlayer.CharacterAdded:Connect(setUpCharacter)

	RunService.RenderStepped:Connect(function()
		local character = localPlayer.Character
		if not character then return end

		LeaningFunctions.UpdateSlopeTilt(character)
	end)

	RunService:BindToRenderStep("MomentumLean", Enum.RenderPriority.Character.Value + 1, function(deltaTime)
		local character = localPlayer.Character
		if not character then return end

		LeaningFunctions.UpdateLean(character, deltaTime)
	end)
end

return Schedules.Boot.job(init)
