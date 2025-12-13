-- Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")

local InverseKinematics = require(ReplicatedStorage.Vendor.InverseKinematics)
local Trove = require(ReplicatedStorage.Vendor.Trove)

local LegController = {}
LegController.__index = LegController

local ikAttachments = {
	["leftHip"] = CFrame.new(-0.466, -0.944, 0),
	["leftFoot"] = CFrame.new(-0.5, -2.9, 0),
	["rightHip"] = CFrame.new(0.5, -0.944, 0),
	["rightFoot"] = CFrame.new(0.5, -2.9, 0),
}

local function nilContentsExist(Tbl: any)
	for _, Val in Tbl do
		if Val == nil then return true end
	end

	return false
end

function LegController.new(Character: Model, Configuration: any)
	local self = setmetatable({}, LegController)

	self.Trove = Trove.new() --Creating a Trove OOP object for cleanup and management

	-- Important variables --
	local Humanoid = Character:WaitForChild("Humanoid", 15)
	local RootPart = Character:WaitForChild("HumanoidRootPart", 15)

	local rootJoint = RootPart:WaitForChild("RootJoint")
	local leftHip = Character:FindFirstChild(Humanoid.RigType == Enum.HumanoidRigType.R15 and "LeftHip" or "Left Hip", true)
	local rightHip = Character:FindFirstChild(Humanoid.RigType == Enum.HumanoidRigType.R15 and "RightHip" or "Right Hip", true)

	self.States = {
		["tiltingEnabled"] = Configuration.tiltingEnabled,
		["ikEnabled"] = Configuration.ikEnabled,
	}

	local motor6D = {
		rootJoint = rootJoint.C0,
		Hips = {
			["LeftHip"] = leftHip.C0,
			["RightHip"] = rightHip.C0,
		},
	}

	local characterIK = nil
	if Humanoid.RigType == Enum.HumanoidRigType.R6 then characterIK = InverseKinematics.New(Character) end

	-- Setting up raycast params for inverse kinematics --
	local ikParams = RaycastParams.new()
	ikParams.FilterType = Enum.RaycastFilterType.Exclude
	ikParams.FilterDescendantsInstances = { Character }
	for _, exclusionObject in Configuration.ikExclude do
		table.insert(ikParams.FilterDescendantsInstances, exclusionObject)
	end

	local ikParts = {}
	for Index, CF in ikAttachments do
		local newAttachment = Instance.new("Attachment")
		newAttachment.Name = Index
		newAttachment.CFrame = CF
		newAttachment.Parent = Humanoid.RootPart

		ikParts[newAttachment.Name] = newAttachment --Adding the newly created attachment to a table
		self.Trove:Add(ikParts[newAttachment.Name])
	end

	self.Trove:Connect(RunService.Heartbeat, function(deltaTime: number)
		if not Humanoid.Parent:FindFirstChild("HumanoidRootPart") then return end

		local normalizedDeltaTime = deltaTime * 60

		local rootVelocity = Vector3.new(1, 0, 1) * Humanoid.RootPart.Velocity
		local directionalRightVelocity = Humanoid.RootPart.CFrame.RightVector:Dot(rootVelocity.unit)

		-- Inverse Kinematics --
		local ikLeftC0, ikRightC0 = nil, nil
		if characterIK and self.States.ikEnabled and not nilContentsExist(ikParts) and rootVelocity.Magnitude < Configuration.maxIkVelocity then
			local leftDir = ikParts.leftFoot.WorldCFrame.Position - ikParts.leftHip.WorldCFrame.Position
			local rightDir = ikParts.rightFoot.WorldCFrame.Position - ikParts.rightHip.WorldCFrame.Position

			local leftRay = workspace:Raycast(ikParts.leftHip.WorldCFrame.Position, leftDir, ikParams)
			local rightRay = workspace:Raycast(ikParts.rightHip.WorldCFrame.Position, rightDir, ikParams)

			if leftRay and leftRay.Material ~= Enum.Material.Water and leftRay.Instance.CanCollide then
				ikLeftC0 = characterIK:LegIK("Left", leftRay.Position)
			end
			if rightRay and rightRay.Material ~= Enum.Material.Water and rightRay.Instance.CanCollide then
				ikRightC0 = characterIK:LegIK("Right", rightRay.Position)
			end
		end

		-- For angle calculation --
		local canAngle = table.find(Configuration.onStates, Humanoid:GetState())
		local notInverse = Humanoid.RootPart.CFrame.LookVector:Dot(Humanoid.MoveDirection) < -0.1

		local rootAngle = (
			self.States.tiltingEnabled
				and canAngle
				and rootVelocity.Magnitude > Configuration.activationVelocity
				and math.rad(directionalRightVelocity * Configuration.maxRootAngle)
			or 0
		) * (notInverse and 1 or -1)
		local legAngle = (
			self.States.tiltingEnabled
				and canAngle
				and rootVelocity.Magnitude > Configuration.activationVelocity
				and math.rad(directionalRightVelocity * Configuration.maxAngle)
			or 0
		) * (notInverse and 1 or -1)

		-- Setting motor6D C0s --
		local interpolationSpeed = Configuration.interploationSpeed.Speed
			* (rootVelocity.Magnitude < Configuration.interploationSpeed.highVelocityPoint and 2.8 or 1)
		rootJoint.C0 = rootJoint.C0:Lerp(motor6D.rootJoint * CFrame.Angles(0, 0, rootAngle), interpolationSpeed * normalizedDeltaTime)
		leftHip.C0 = leftHip.C0:Lerp(ikLeftC0 or motor6D.Hips.LeftHip * CFrame.Angles(0, legAngle, 0), interpolationSpeed * normalizedDeltaTime)
		rightHip.C0 = rightHip.C0:Lerp(ikRightC0 or motor6D.Hips.RightHip * CFrame.Angles(0, legAngle, 0), interpolationSpeed * normalizedDeltaTime)
	end)

	return self
end

function LegController:setState(stateString: string, Enabled: boolean)
	if not self.States[stateString] then
		error("Invalid string")
		return
	end

	self.States[stateString] = Enabled
end

function LegController:Destroy()
	self.Trove:Destroy()

	table.clear(self)
	setmetatable(self, nil)

	return
end

return LegController
