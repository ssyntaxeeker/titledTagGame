--!strict
--[[
    ElevatorService (Server)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/19

    Moves models tagged Elevator between the StartPos and EndPos attachments
    authored under ElevatorRoot. One shared heartbeat owns every elevator.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Schedules = require(ReplicatedStorage.Shared.Schedules)
local ElevatorConfig = require(ServerStorage.Modules.Maps.ElevatorConfig)

type ElevatorState = {
	model: Model,
	rootPart: BasePart,
	startPosition: Vector3,
	endPosition: Vector3,
	targetPosition: Vector3,
	rootRotation: CFrame,
	rootToPivot: CFrame,
	speed: number,
	waitSeconds: number,
	waitUntil: number,
}

local states: { [Model]: ElevatorState } = {}

local function unregister(instance: Instance)
	if instance:IsA("Model") then states[instance] = nil end
end

local function register(instance: Instance)
	assert(instance:IsA("Model"), "[ElevatorService] Elevator tag must be assigned to a Model")
	if not instance:IsDescendantOf(Workspace) then return end
	if states[instance] then return end

	local rootPart = instance:FindFirstChild("ElevatorRoot")
	assert(rootPart and rootPart:IsA("BasePart"), `[ElevatorService] {instance:GetFullName()} has no ElevatorRoot part`)
	local startPos = rootPart:FindFirstChild("StartPos")
	local endPos = rootPart:FindFirstChild("EndPos")
	assert(startPos and startPos:IsA("Attachment"), `[ElevatorService] {rootPart:GetFullName()} has no StartPos attachment`)
	assert(endPos and endPos:IsA("Attachment"), `[ElevatorService] {rootPart:GetFullName()} has no EndPos attachment`)

	local speedAttribute = instance:GetAttribute(ElevatorConfig.speedAttribute)
	local waitAttribute = instance:GetAttribute(ElevatorConfig.waitAttribute)
	assert(speedAttribute == nil or typeof(speedAttribute) == "number", `[ElevatorService] {instance:GetFullName()} ElevatorSpeed must be a number`)
	assert(waitAttribute == nil or typeof(waitAttribute) == "number", `[ElevatorService] {instance:GetFullName()} ElevatorWaitTime must be a number`)
	local speed = if typeof(speedAttribute) == "number" then speedAttribute else ElevatorConfig.defaultSpeed
	local waitSeconds = if typeof(waitAttribute) == "number" then waitAttribute else ElevatorConfig.defaultWaitSeconds
	assert(speed > 0, `[ElevatorService] {instance:GetFullName()} ElevatorSpeed must be greater than zero`)
	assert(waitSeconds >= 0, `[ElevatorService] {instance:GetFullName()} ElevatorWaitTime cannot be negative`)

	local startPosition = startPos.WorldPosition
	local endPosition = endPos.WorldPosition
	assert((endPosition - startPosition).Magnitude > 0.01, `[ElevatorService] {instance:GetFullName()} endpoints overlap`)
	local distanceToStart = (rootPart.Position - startPosition).Magnitude
	local distanceToEnd = (rootPart.Position - endPosition).Magnitude
	states[instance] = {
		model = instance,
		rootPart = rootPart,
		startPosition = startPosition,
		endPosition = endPosition,
		targetPosition = if distanceToStart <= distanceToEnd then startPosition else endPosition,
		rootRotation = rootPart.CFrame.Rotation,
		rootToPivot = rootPart.CFrame:ToObjectSpace(instance:GetPivot()),
		speed = speed,
		waitSeconds = waitSeconds,
		waitUntil = 0,
	}
end

local function step(dt: number)
	local now = os.clock()
	for model, state in states do
		if not model:IsDescendantOf(Workspace) or not CollectionService:HasTag(model, "Elevator") then
			states[model] = nil
			continue
		end
		if now < state.waitUntil then continue end

		local offset = state.targetPosition - state.rootPart.Position
		local distance = offset.Magnitude
		local travelDistance = state.speed * math.min(dt, 0.1)
		local nextPosition = if distance <= travelDistance
			then state.targetPosition
			else state.rootPart.Position + offset.Unit * travelDistance
		local targetRootCFrame = state.rootRotation + nextPosition
		state.model:PivotTo(targetRootCFrame * state.rootToPivot)

		if distance > travelDistance then continue end
		state.targetPosition = if state.targetPosition == state.startPosition then state.endPosition else state.startPosition
		state.waitUntil = now + state.waitSeconds
	end
end

-- Registers existing and future tagged elevators, then owns their shared
-- movement loop for the lifetime of the server.
local function initialize()
	for _, instance in CollectionService:GetTagged("Elevator") do
		register(instance)
	end
	CollectionService:GetInstanceAddedSignal("Elevator"):Connect(register)
	CollectionService:GetInstanceRemovedSignal("Elevator"):Connect(unregister)
	RunService.Heartbeat:Connect(step)
end

return Schedules.Boot.job(initialize)
