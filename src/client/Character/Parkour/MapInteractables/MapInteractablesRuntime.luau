--!strict
--[[
    MapInteractablesRuntime (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/20

    Runs one bounded character-scoped probe loop for automatic UTG map
    affordances. Input-driven wallruns are handled by AerialInputs.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Packages.Net)
local ParkourAssetScope = require(ReplicatedStorage.Shared.Utils.ParkourAssetScope)
local ParkourMovementModel = require(ReplicatedStorage.Modules.Character.Parkour.ParkourMovementModel)
local RailController = require(ReplicatedStorage.Modules.Character.Parkour.Rail.RailController)
local RopeConfig = require(ReplicatedStorage.Modules.Character.Parkour.Rope.RopeConfig)
local RopeController = require(ReplicatedStorage.Modules.Character.Parkour.Rope.RopeController)
local Schedules = require(ReplicatedStorage.Shared.Schedules)
local WallrunController = require(ReplicatedStorage.Modules.Character.Parkour.Wallrun.WallrunController)
local WindforceController = require(ReplicatedStorage.Modules.Character.Parkour.MapInteractables.WindforceController)
local ZiplineConfig = require(ReplicatedStorage.Modules.Character.Parkour.Zipline.ZiplineConfig)
local ZiplineController = require(ReplicatedStorage.Modules.Character.Parkour.Zipline.ZiplineController)

local BreakWindowRE = Net:RemoteEvent("BreakParkourWindow")
local localPlayer = Players.LocalPlayer
local heartbeat: RBXScriptConnection? = nil
local diedConnection: RBXScriptConnection? = nil

local function initCharacter(character: Model)
	if heartbeat then heartbeat:Disconnect() end
	if diedConnection then diedConnection:Disconnect() end
	RopeController.release(false)
	RailController.release(false)
	WindforceController.reset()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.IgnoreWater = true
	raycastParams.RespectCanCollide = false
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { character }
	overlapParams.RespectCanCollide = false
	local automaticProbeElapsed = 0
	local lastWindowAt = 0
	WindforceController.bind(character, humanoid, rootPart)
	diedConnection = humanoid.Died:Connect(function()
		RopeController.release(false)
		RailController.release(false)
		WindforceController.reset()
		if heartbeat then
			heartbeat:Disconnect()
			heartbeat = nil
		end
	end)

	heartbeat = RunService.Heartbeat:Connect(function(dt)
		if humanoid.Health <= 0 or not character.Parent then return end
		RopeController.step(dt)
		RailController.step(dt)

		automaticProbeElapsed += dt
		if automaticProbeElapsed < 0.05 then return end
		automaticProbeElapsed = 0
		local actionActive = RopeController.isActive()
			or RailController.isActive()
			or ZiplineController.isActive()
			or WallrunController.isActive()
			or character:GetAttribute("Swinging") == true

		local nearestRope: BasePart? = nil
		local nearestRopePosition = Vector3.zero
		local nearestRopeDistance = math.huge
		local nearbyParts = Workspace:GetPartBoundsInRadius(rootPart.Position, ZiplineConfig.attachRadius, overlapParams)
		for _, part in nearbyParts do
			if not ParkourAssetScope.contains(part) then continue end
			if actionActive then continue end
			if ParkourMovementModel.affordanceValue(part, "RopeGrab") ~= true then continue end
			local grabPosition = part:GetClosestPointOnSurface(rootPart.Position)
			local distance = (grabPosition - rootPart.Position).Magnitude
			if distance >= nearestRopeDistance then continue end
			local direction = grabPosition - rootPart.Position
			if direction.Magnitude > 0.05 then
				local visibility = Workspace:Raycast(rootPart.Position, direction, raycastParams)
				if visibility and visibility.Instance ~= part then continue end
			end
			nearestRope = part
			nearestRopePosition = grabPosition
			nearestRopeDistance = distance
		end
		if actionActive then return end
		if nearestRope and RopeController.tryGrab(character, nearestRope, nearestRopePosition) then return end

		local forwardVelocity = rootPart.AssemblyLinearVelocity
		local probeDirection = if forwardVelocity.Magnitude > 2 then forwardVelocity.Unit else rootPart.CFrame.LookVector
		local forwardResult = Workspace:Raycast(rootPart.Position, probeDirection * RopeConfig.probeDistance, raycastParams)
		if forwardResult then
			local distance = (forwardResult.Position - rootPart.Position).Magnitude
			local breakable = forwardResult.Instance:GetAttribute("CanBeBroken") == true
				or forwardResult.Instance:GetAttribute("Smashable") == true
			local requiredDistance = if math.abs(probeDirection.Y) > 0.75 then 3.5 else 2.5
			if ParkourAssetScope.contains(forwardResult.Instance)
				and breakable
				and distance <= requiredDistance
				and os.clock() - lastWindowAt >= 0.15
			then
				lastWindowAt = os.clock()
				BreakWindowRE:FireServer(forwardResult.Instance, forwardResult.Position, forwardResult.Normal)
				local velocity = rootPart.AssemblyLinearVelocity
				rootPart.AssemblyLinearVelocity = velocity + probeDirection * 7.5 - forwardResult.Normal * 3.33
			end
		end

		local trussResult = Workspace:Raycast(rootPart.Position, rootPart.CFrame.LookVector * 4, raycastParams)
		local touchingTruss = if trussResult ~= nil and ParkourMovementModel.isTruss(trussResult.Instance) then true else nil
		if character:GetAttribute("TouchingTruss") ~= touchingTruss then
			character:SetAttribute("TouchingTruss", touchingTruss)
		end
		local railResult = Workspace:Raycast(rootPart.Position, -Vector3.yAxis * 3.5, raycastParams)
		if railResult then RailController.tryAttach(character, railResult) end
	end)
end

local function init()
	localPlayer.CharacterAdded:Connect(initCharacter)
	if localPlayer.Character then task.spawn(initCharacter, localPlayer.Character) end
end

return Schedules.Boot.job(init)
