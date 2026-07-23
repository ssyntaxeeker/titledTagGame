--!strict
--[[
    MovementPhysicsController (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/19

    Owns the local character's UTG movement heartbeat and all connection
    cleanup. The movement model remains character-agnostic for bot reuse.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CharacterMovementModel = require(ReplicatedStorage.Modules.Character.Movement.CharacterMovementModel)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local LeaningInterface = require(ReplicatedStorage.Modules.Character.Movement.Leaning.LeaningInterface)
local MovementConfig = require(ReplicatedStorage.Modules.Character.Movement.MovementConfig)
local MovementInterface = require(ReplicatedStorage.Modules.Character.Movement.MovementInterface)
local Schedules = require(ReplicatedStorage.Shared.Schedules)
local Slide = require(ReplicatedStorage.Modules.Character.Parkour.Landing.Slide)

local localPlayer = Players.LocalPlayer
local characterJanitor = Janitor.new()
local activeCharacter: Model? = nil

local function sprintRequested(character: Model): boolean
	return not MovementInterface.WalkRequested
		and MovementInterface.MoveVector.Z > 0.25
		and not character:GetAttribute("Crouching")
end

local function cleanupCharacter(character: Model)
	if activeCharacter ~= character then return end
	activeCharacter = nil
	characterJanitor:Cleanup()
end

local function initCharacter(character: Model)
	if activeCharacter then cleanupCharacter(activeCharacter) end
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
	if localPlayer.Character ~= character or not character.Parent then return end
	activeCharacter = character
	character:SetAttribute("Momentum", 0)
	character:SetAttribute("Friction", 0)
	Workspace.Gravity = MovementConfig.gravity

	characterJanitor:Add(RunService.Heartbeat:Connect(function(dt)
		if activeCharacter ~= character then return end
		if not character.Parent
			or humanoid.Parent ~= character
			or rootPart.Parent ~= character
			or humanoid.Health <= 0
		then
			cleanupCharacter(character)
			return
		end
		local shouldStopSlide = CharacterMovementModel.update(character, {
			dt = dt,
			moveMagnitude = MovementInterface.MoveVector.Magnitude,
			sprinting = sprintRequested(character),
			slopeTilt = LeaningInterface.slopeTilt,
		})
		if shouldStopSlide and character:GetAttribute("Sliding") then Slide.Stop() end
	end))

	characterJanitor:Add(humanoid.Died:Connect(function() cleanupCharacter(character) end))
	characterJanitor:Add(character.Destroying:Connect(function() cleanupCharacter(character) end))
end

local function initialize()
	localPlayer.CharacterAdded:Connect(initCharacter)
	localPlayer.CharacterRemoving:Connect(cleanupCharacter)
	if localPlayer.Character then initCharacter(localPlayer.Character) end
end

return Schedules.Boot.job(initialize)
