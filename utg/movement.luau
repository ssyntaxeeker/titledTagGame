-- Decompiled with Velocity Script Decompiler
-- Readability refactor ONLY – logic preserved exactly

--// Services
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

--// Utils
local Utils = require(game.ReplicatedFirst.Utils)

--// Events
local TeleportClientEvent = Utils.GetEvent("TeleportClient")
local AnimateJumpEvent = Utils.GetEvent("AnimateJump")
Utils.GetEvent("AnimateEvent") -- intentionally unused

--// Player & Character
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Camera = workspace.CurrentCamera

local Root = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("TouchGuiUTG")

--// Character values
local Values = Character:WaitForChild("values")
local MoveVectorValue = Values:WaitForChild("MoveVector")
local CameraXValue = Values:WaitForChild("CameraX")
local CameraYValue = Values:WaitForChild("CameraY")
local LockMoveVectorValue = Values:WaitForChild("LockMoveVector")

--// Raycast
local RayParams = RaycastParams.new()
RayParams.FilterDescendantsInstances = { Camera, Character }
RayParams.RespectCanCollide = true

--// State variables
local WorldMoveVector = Vector3.new()
local RawMoveVector = Vector3.new()
local LastJumpTime = -99
local InputConsumed = false
local GamepadVector = Vector3.new()
local JumpHeld = false

shared.gamepadEnabled = false
shared.freelook = false

--// Freelook cache
local CachedCameraX = nil
local CachedCameraY = nil

--// Gamepad types
local GamepadInputTypes = {
	Enum.UserInputType.Gamepad1,
	Enum.UserInputType.Gamepad2,
	Enum.UserInputType.Gamepad3,
	Enum.UserInputType.Gamepad4,
	Enum.UserInputType.Gamepad5,
	Enum.UserInputType.Gamepad6,
	Enum.UserInputType.Gamepad7,
	Enum.UserInputType.Gamepad8,
}

--// Keybinds (only initialized once)
if not shared.keybinds then
	shared.keybinds = {}

	Utils.AddKeybind("run", Enum.KeyCode.LeftShift)
	Utils.AddKeybind("slide", { Enum.KeyCode.C, Enum.KeyCode.ButtonL2, Enum.KeyCode.ButtonB })
	Utils.AddKeybind("jump", {
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonA,
		Enum.KeyCode.ButtonL1,
		Enum.KeyCode.ButtonR1,
	})
	Utils.AddKeybind("tag", { Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2 })
	Utils.AddKeybind("parry", { Enum.KeyCode.F, Enum.KeyCode.ButtonX })
	Utils.AddKeybind("freelook", { Enum.KeyCode.LeftAlt, Enum.UserInputType.MouseButton2 })
	Utils.AddKeybind("emote", { Enum.KeyCode.G, Enum.KeyCode.ButtonY })
	Utils.AddKeybind("leaderboard", { Enum.KeyCode.Tab, Enum.KeyCode.ButtonX })
	Utils.AddKeybind("cameralock", Enum.KeyCode.Semicolon)
end

--// Wait for options
repeat
	task.wait()
until shared.options

--// Humanoid setup
Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
Humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)

Humanoid.AutoRotate = false
Humanoid.AutoJumpEnabled = shared.options.Gameplay.AutoJump
LockMoveVectorValue.Value = false

---------------------------------------------------------------------
-- Movement Update
---------------------------------------------------------------------
local function MoveUpdate(deltaTime)
	local scaledDelta = math.min(deltaTime, 1) * 60
	local lerpAlpha = math.min(scaledDelta, 1)

	-- Anchoring
	Root.Anchored = Character:GetAttribute("Anchor")
		or Character:GetAttribute("Teleport")
		or Character:GetAttribute("Frozen")
		or Character:GetAttribute("Caged")

	if Root.Anchored then
		Root.AssemblyLinearVelocity = Vector3.zero
		Root.AssemblyAngularVelocity = Vector3.zero
	end

	-- Teleport handling
	if Character:GetAttribute("Teleport") then
		Root.CFrame = Character:GetAttribute("Teleport") + Vector3.new(0, 3, 0)

		if workspace:Raycast(Root.Position, Vector3.new(0, -9999, 0), RayParams) then
			Character:SetAttribute("Teleport", nil)
		end
	end

	if not shared.controlModule or not shared.multipliers then
		return
	end

	-----------------------------------------------------------------
	-- Input
	-----------------------------------------------------------------
	local moveInput = shared.controlModule:GetMoveVector()

	if shared.gamepadEnabled then
		moveInput = GamepadVector
	end

	Humanoid.AutoRotate = not (shared.emoteData and not shared.emoteData.Unrestrictive)

	local freelookActive = shared.playMode ~= "assetCreator" and Utils.IsKeybindDown("freelook")

	-----------------------------------------------------------------
	-- Normal gameplay
	-----------------------------------------------------------------
	if shared.playMode == nil then
		if not Root.Anchored or shared.multipliers.Noclip then
			-- Sliding
			if LockMoveVectorValue.Value then
				if shared.sliding and Root.AssemblyLinearVelocity.Magnitude > 0.05 and not Humanoid.SeatPart then
					if shared.multipliers.SlideSteering and not freelookActive then
						local steerMult = shared.multipliers.SlideSteerMultiplier or 1

						Root.CFrame *= CFrame.new(moveInput.X * 0.02 * lerpAlpha, 0, 0)
						MoveVectorValue.Value = Vector3.new(moveInput.X * 0.5 * steerMult * lerpAlpha, 0, -1)

						WorldMoveVector = WorldMoveVector:Lerp(
							Root.CFrame:VectorToWorldSpace(MoveVectorValue.Value),
							Utils.DeltaLerp(4, deltaTime)
						)
					end

					local _, yaw = CFrame.lookAt(Root.Position, Root.Position + Root.AssemblyLinearVelocity)
						:ToOrientation()

					Root.CFrame = Root.CFrame.Rotation:Lerp(CFrame.Angles(0, yaw, 0), Utils.DeltaLerp(5, deltaTime))
						+ Root.Position
				end
			else
				-- Normal movement
				MoveVectorValue.Value = moveInput

				if shared.multipliers.MoveSmoothing and shared.multipliers.MoveSmoothing > 0 then
					WorldMoveVector = WorldMoveVector:Lerp(
						(CachedCameraY or CameraYValue.Value):VectorToWorldSpace(moveInput),
						lerpAlpha * (1 - shared.multipliers.MoveSmoothing)
					)
				else
					WorldMoveVector = (CachedCameraY or CameraYValue.Value):VectorToWorldSpace(moveInput)
				end

				if not Humanoid.SeatPart and not Humanoid.AutoRotate then
					if shared.multipliers.RotateInMoveDirection then
						if moveInput.Magnitude > 0.1 then
							local _, yaw = CFrame.lookAt(Vector3.zero, WorldMoveVector):ToOrientation()

							Root.CFrame = CFrame.Angles(0, yaw, 0) + Root.Position
						end
					elseif shared.multipliers.TurnSmoothing and shared.multipliers.TurnSmoothing > 0 then
						Root.CFrame = Root.CFrame.Rotation:Lerp(
							CachedCameraY or CameraYValue.Value,
							lerpAlpha * (1 - shared.multipliers.TurnSmoothing)
						) + Root.Position
					else
						Root.CFrame = (CachedCameraY or CameraYValue.Value) + Root.Position
					end
				end
			end
		end

		-- Freelook caching
		if freelookActive then
			if not CachedCameraX then
				CachedCameraX = CameraXValue.Value
				CachedCameraY = CameraYValue.Value
			end
		elseif CachedCameraX then
			CameraXValue.Value = CachedCameraX
			CameraYValue.Value = CachedCameraY
			CachedCameraX = nil
			CachedCameraY = nil
		end

		-----------------------------------------------------------------
		-- Jump handling
		-----------------------------------------------------------------
		local touchController = shared.controlModule:GetTouchController()
		local touchJumping = touchController
			and not shared.controlModule:GetActiveController():GetIsJumping()
			and touchController:GetIsJumping()

		local jumpPressed = (not touchJumping and Utils.IsKeybindDown("jump") and not InputConsumed)
			or touchJumping
			or JumpHeld

		shared.jumpInput = jumpPressed

		if LastJumpTime > time() or not Humanoid:GetAttribute("HasJumped") then
			if jumpPressed and not Humanoid:GetAttribute("HasJumped") then
				LastJumpTime = time() + 0.5
				ReplicatedStorage.Events.game.player.JumpInput:Fire()
			end

			ReplicatedStorage.Events.game.player.MovementJump:Fire(jumpPressed)
		end

		Humanoid:SetAttribute("HasJumped", jumpPressed)

		shared.freelookX = CachedCameraX
		shared.freelookY = CachedCameraY
		shared.freelook = freelookActive
	else
		-- Asset creator mode
		WorldMoveVector = Vector3.zero

		if shared.playMode == "assetCreator" and not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			shared.assetModePosition = shared.assetModePosition or Vector3.zero

			local direction = CameraYValue.Value * CFrame.Angles(math.rad(CameraXValue.Value), 0, 0)

			local speed = Utils.IsKeybindDown("run") and 75 or 35
			shared.assetModePosition += direction:VectorToWorldSpace(moveInput * speed * deltaTime)
		end
	end

	Humanoid:Move(WorldMoveVector)
end

---------------------------------------------------------------------
-- Input handling
---------------------------------------------------------------------
local function InputBegan(input, gp)
	InputConsumed = gp

	if
		typeof(shared.keybinds.jump) == "table"
		and not gp
		and (table.find(shared.keybinds.jump, input.KeyCode) or table.find(shared.keybinds.jump, input.UserInputType))
	then
		JumpHeld = true
	end
end

local function InputChanged(input, gp)
	InputConsumed = gp

	if not table.find(GamepadInputTypes, input.UserInputType) then
		shared.gamepadEnabled = false
	end

	if input.KeyCode == Enum.KeyCode.Thumbstick1 and not gp then
		if input.Position.Magnitude > (shared.options.Controls.LeftMovementDeadzone or 0.05) then
			shared.gamepadEnabled = true
			GamepadVector = Vector3.new(input.Position.X, 0, -input.Position.Y)
		else
			GamepadVector = Vector3.zero
		end
	end
end

local function InputEnded(input, gp)
	InputConsumed = gp
	shared.gamepadEnabled = table.find(GamepadInputTypes, input.UserInputType) ~= nil

	if input.KeyCode == Enum.KeyCode.Thumbstick1 and not gp then
		GamepadVector = Vector3.zero
	end

	if
		typeof(shared.keybinds.jump) == "table"
		and (table.find(shared.keybinds.jump, input.KeyCode) or table.find(shared.keybinds.jump, input.UserInputType))
	then
		JumpHeld = false
	end
end

---------------------------------------------------------------------
-- Jump events
---------------------------------------------------------------------
local function JumpRequest(isJumping)
	if not Utils.InCooldown("Jump") then
		if isJumping and shared.multipliers and shared.multipliers.JumpDelay then
			AnimateJumpEvent:Fire()
			Utils.ApplyCooldown("Jump")
			task.wait(shared.multipliers.JumpDelay)
		end

		Humanoid.Jump = isJumping
	end
end

local function FixTeleport(cf)
	if not cf then
		Root.CFrame = cf
	end
end

---------------------------------------------------------------------
-- Connections
---------------------------------------------------------------------
Utils.GetEvent("MovementJump").Event:Connect(JumpRequest)
TeleportClientEvent.OnClientEvent:Connect(FixTeleport)

UserInputService.InputBegan:Connect(InputBegan)
UserInputService.InputChanged:Connect(InputChanged)
UserInputService.InputEnded:Connect(InputEnded)

Humanoid.Jumping:Connect(function()
	Utils.ApplyCooldown("Jump")
	if not (shared.multipliers and shared.multipliers.JumpDelay) then
		AnimateJumpEvent:Fire()
	end
end)

RunService:BindToRenderStep("move update", Enum.RenderPriority.Input.Value, MoveUpdate)
