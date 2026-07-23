--!strict
--[[
    WindforceController (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/19

    Tracks the local root's active UTG wind volume through touch events and
    applies the authored velocity delta with UTG's 60 Hz frame normalization.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ParkourAssetScope = require(ReplicatedStorage.Shared.Utils.ParkourAssetScope)

local WindforceController = {}
local RENDER_STEP_NAME = "UTGWindforce"
local activePart: BasePart? = nil
local boundCharacter: Model? = nil
local touchedConnection: RBXScriptConnection? = nil
local touchEndedConnection: RBXScriptConnection? = nil

local function isWindforce(part: BasePart): boolean
	return ParkourAssetScope.contains(part)
		and (typeof(part:GetAttribute("Windforce")) == "Vector3"
			or typeof(part:GetAttribute("WindforceRelative")) == "Vector3")
end

function WindforceController.reset()
	RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
	if touchedConnection then touchedConnection:Disconnect() end
	if touchEndedConnection then touchEndedConnection:Disconnect() end
	touchedConnection = nil
	touchEndedConnection = nil
	activePart = nil
	if boundCharacter then boundCharacter:SetAttribute("InWindzone", nil) end
	boundCharacter = nil
end

function WindforceController.bind(character: Model, humanoid: Humanoid, rootPart: BasePart)
	WindforceController.reset()
	boundCharacter = character
	touchedConnection = rootPart.Touched:Connect(function(part)
		if not isWindforce(part) then return end
		activePart = part
		character:SetAttribute("InWindzone", true)
	end)
	touchEndedConnection = rootPart.TouchEnded:Connect(function(part)
		if part ~= activePart then return end
		activePart = nil
		for _, touchingPart in rootPart:GetTouchingParts() do
			if not isWindforce(touchingPart) then continue end
			activePart = touchingPart
			break
		end
		if not activePart then character:SetAttribute("InWindzone", nil) end
	end)
	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Input.Value + 1, function(dt)
		local part = activePart
		if not part then return end
		if not part.Parent then
			character:SetAttribute("InWindzone", nil)
			activePart = nil
			return
		end

		local frameScale = math.min(dt, 1) * 60
		local relativeForce = part:GetAttribute("WindforceRelative")
		local worldForce = part:GetAttribute("Windforce")
		local velocityDelta: Vector3
		if typeof(relativeForce) == "Vector3" then
			velocityDelta = part.CFrame:VectorToObjectSpace(relativeForce * frameScale)
		else
			assert(typeof(worldForce) == "Vector3", "[WindforceController] active volume has no windforce")
			velocityDelta = worldForce * frameScale
		end

		-- Roblox's grounded Humanoid controller can consume a small upward velocity
		-- delta before it enters the air. UTG's wind is continuous rather than a
		-- jump, so release the grounded state without adding a jump impulse.
		if velocityDelta.Y > 0 and humanoid.FloorMaterial ~= Enum.Material.Air then
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
		rootPart.AssemblyLinearVelocity += velocityDelta
	end)
end

return table.freeze(WindforceController)
