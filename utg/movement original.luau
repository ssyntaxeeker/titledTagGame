-- Decompiled with Velocity Script Decompiler
local v1 = game:GetService("RunService")
local v_u_2 = game:GetService("ReplicatedStorage")
local v_u_3 = game:GetService("UserInputService")
local v_u_4 = require(game.ReplicatedFirst.Utils)
local v5 = v_u_4.GetEvent("TeleportClient")
local v_u_6 = v_u_4.GetEvent("AnimateJump")
v_u_4.GetEvent("AnimateEvent")
local v7 = game.Players.LocalPlayer
local v_u_8 = v7.Character or v7.CharacterAdded:Wait()
local v9 = workspace.CurrentCamera
local v_u_10 = v_u_8:WaitForChild("HumanoidRootPart")
local v_u_11 = v_u_8:WaitForChild("Humanoid")
v7:WaitForChild("PlayerGui"):WaitForChild("TouchGuiUTG")
local v12 = v_u_8:WaitForChild("values")
local v_u_13 = v12:WaitForChild("MoveVector")
local v_u_14 = v12:WaitForChild("CameraX")
local v_u_15 = v12:WaitForChild("CameraY")
local v_u_16 = v12:WaitForChild("LockMoveVector")
local v_u_17 = RaycastParams.new()
local v_u_18 = Vector3.new()
local v_u_19 = -99
local v_u_20 = false
local v_u_21 = Vector3.new()
shared.gamepadEnabled = false
local v_u_22 = false
local v_u_23 = {
	Enum.UserInputType.Gamepad1,
	Enum.UserInputType.Gamepad2,
	Enum.UserInputType.Gamepad3,
	Enum.UserInputType.Gamepad4,
	Enum.UserInputType.Gamepad5,
	Enum.UserInputType.Gamepad6,
	Enum.UserInputType.Gamepad7,
	Enum.UserInputType.Gamepad8,
}
if not shared.keybinds then
	shared.keybinds = {}
	v_u_4.AddKeybind("run", Enum.KeyCode.LeftShift)
	v_u_4.AddKeybind("slide", { Enum.KeyCode.C, Enum.KeyCode.ButtonL2, Enum.KeyCode.ButtonB })
	v_u_4.AddKeybind("jump", {
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonA,
		Enum.KeyCode.ButtonL1,
		Enum.KeyCode.ButtonR1,
	})
	v_u_4.AddKeybind("tag", { Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2 })
	v_u_4.AddKeybind("parry", { Enum.KeyCode.F, Enum.KeyCode.ButtonX })
	v_u_4.AddKeybind("freelook", { Enum.KeyCode.LeftAlt, Enum.UserInputType.MouseButton2 })
	v_u_4.AddKeybind("emote", { Enum.KeyCode.G, Enum.KeyCode.ButtonY })
	v_u_4.AddKeybind("leaderboard", { Enum.KeyCode.Tab, Enum.KeyCode.ButtonX })
	v_u_4.AddKeybind("cameralock", Enum.KeyCode.Semicolon)
end
repeat
	task.wait()
until shared.options
v_u_11:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
v_u_11:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
v_u_16.Value = false
v_u_11.AutoRotate = false
v_u_11.AutoJumpEnabled = shared.options.Gameplay.AutoJump
v_u_17.FilterDescendantsInstances = { v9, v_u_8 }
v_u_17.RespectCanCollide = true
shared.freelook = false
local v_u_24 = nil
local v_u_25 = nil
function MoveUpdate(p26)
	-- upvalues: (copy) v_u_10, (copy) v_u_8, (copy) v_u_17, (ref) v_u_21, (copy) v_u_11, (copy) v_u_4, (copy) v_u_16, (copy) v_u_13, (ref) v_u_18, (ref) v_u_25, (copy) v_u_15, (ref) v_u_24, (copy) v_u_14, (ref) v_u_20, (ref) v_u_22, (ref) v_u_19, (copy) v_u_2, (copy) v_u_3
	local v27 = math.min(p26, 1) * 60
	local v28 = math.min(v27, 1)
	v_u_10.Anchored = v_u_8:GetAttribute("Anchor")
		or v_u_8:GetAttribute("Teleport")
		or (v_u_8:GetAttribute("Frozen") or v_u_8:GetAttribute("Caged"))
	if v_u_10.Anchored then
		v_u_10.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		v_u_10.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end
	if v_u_8:GetAttribute("Teleport") then
		v_u_10.CFrame = v_u_8:GetAttribute("Teleport") + Vector3.new(0, 3, 0)
		if workspace:Raycast(v_u_10.CFrame.Position, Vector3.new(-0, -9999, -0), v_u_17) then
			v_u_8:SetAttribute("Teleport", nil)
		end
	end
	if shared.controlModule then
		if shared.multipliers then
			local v29 = shared.controlModule:GetMoveVector()
			if shared.gamepadEnabled then
				v29 = v_u_21
			end
			local v30 = v_u_11
			local v31 = shared.emoteData
			if v31 then
				v31 = not shared.emoteData.Unrestrictive
			end
			v30.AutoRotate = v31
			local v32
			if shared.playMode == "assetCreator" then
				v32 = false
			else
				v32 = v_u_4.IsKeybindDown("freelook")
			end
			if shared.playMode == nil then
				if not v_u_10.Anchored or shared.multipliers.Noclip then
					if v_u_16.Value then
						if
							shared.sliding and (v_u_10.AssemblyLinearVelocity.Magnitude > 0.05 and not v_u_11.SeatPart)
						then
							if shared.multipliers.SlideSteering and not v32 then
								local v33 = shared.multipliers and shared.multipliers.SlideSteerMultiplier or 1
								local v34 = v_u_10
								v34.CFrame = v34.CFrame * CFrame.new(v29.X * 0.02 * v28, 0, 0)
								local v35 = v_u_13
								local v36 = v29.X * 0.5 * v33 * v28
								v35.Value = Vector3.new(v36, 0, -1)
								v_u_18 =
									v_u_18:Lerp(v_u_10.CFrame:VectorToWorldSpace(v_u_13.Value), v_u_4.DeltaLerp(4, p26))
							end
							local _, v37, _ = CFrame.lookAt(
								v_u_10.CFrame.Position,
								v_u_10.CFrame.Position + v_u_10.AssemblyLinearVelocity
							):ToOrientation()
							v_u_10.CFrame = v_u_10.CFrame.Rotation:Lerp(
								CFrame.Angles(0, v37, 0),
								v_u_4.DeltaLerp(5, p26)
							) + v_u_10.CFrame.Position
						end
					else
						v_u_13.Value = v29
						if
							shared.multipliers
							and (shared.multipliers.MoveSmoothing and shared.multipliers.MoveSmoothing > 0)
						then
							v_u_18 = v_u_18:Lerp(
								(v_u_25 or v_u_15.Value):VectorToWorldSpace(v_u_13.Value),
								v28 * (1 - shared.multipliers.MoveSmoothing)
							)
						else
							v_u_18 = (v_u_25 or v_u_15.Value):VectorToWorldSpace(v_u_13.Value)
						end
						if not (v_u_11.SeatPart or v_u_11.AutoRotate) then
							if shared.multipliers and shared.multipliers.RotateInMoveDirection then
								if v_u_13.Value.Magnitude > 0.1 then
									local _, v38, _ = CFrame.lookAt(Vector3.new(0, 0, 0), v_u_18):ToOrientation()
									v_u_10.CFrame = CFrame.Angles(0, v38, 0) + v_u_10.CFrame.Position
								end
							elseif
								shared.multipliers
								and (shared.multipliers.TurnSmoothing and shared.multipliers.TurnSmoothing > 0)
							then
								v_u_10.CFrame = v_u_10.CFrame.Rotation:Lerp(
									v_u_25 or v_u_15.Value,
									v28 * (1 - shared.multipliers.TurnSmoothing)
								) + v_u_10.CFrame.Position
							else
								v_u_10.CFrame = (v_u_25 or v_u_15.Value) + v_u_10.CFrame.Position
							end
						end
					end
				end
				if v32 then
					if not v_u_24 then
						v_u_24 = v_u_14.Value
						v_u_25 = v_u_15.Value
					end
				elseif v_u_24 then
					v_u_14.Value = v_u_24
					v_u_15.Value = v_u_25
					v_u_24 = nil
					v_u_25 = nil
				end
				local v39 = not (
						shared.controlModule:GetActiveController()
						and shared.controlModule:GetActiveController():GetIsJumping()
					) and shared.controlModule:GetTouchController()
				if v39 then
					v39 = shared.controlModule:GetTouchController():GetIsJumping()
				end
				local v40 = not v39 and (v_u_4.IsKeybindDown("jump") and not v_u_20) and true or v39
				if v_u_16:GetAttribute("ForceVector") then
					v_u_18 = v_u_16:GetAttribute("ForceVector")
					local _, v41, _ = CFrame.new(Vector3.new(0, 0, 0), v_u_18):ToOrientation()
					v_u_10.CFrame = v_u_10.CFrame.Rotation:Lerp(CFrame.Angles(0, v41, 0), v28 * 0.4)
						+ v_u_10.CFrame.Position
				end
				local v42 = v40 or v_u_22
				local v43 = not v42 and (shared.jumpMobileTap and shared.jumpMobileTap > time()) and true or v42
				shared.jumpInput = v43
				if v_u_19 and v_u_19 > time() or not v_u_11:GetAttribute("HasJumped") then
					if v43 and not v_u_11:GetAttribute("HasJumped") then
						v_u_19 = time() + 0.5
						v_u_2.Events.game.player.JumpInput:Fire()
					end
					v_u_2.Events.game.player.MovementJump:Fire(v43)
				end
				v_u_11:SetAttribute("HasJumped", v43)
				shared.freelookX = v_u_24
				shared.freelookY = v_u_25
				shared.freelook = v32
			else
				v_u_18 = Vector3.new(0, 0, 0)
				if shared.playMode == "assetCreator" and not v_u_3:IsKeyDown(Enum.KeyCode.LeftControl) then
					if not shared.assetModePosition then
						shared.assetModePosition = Vector3.new(0, 0, 0)
					end
					local v44 = v_u_15.Value
					local v45 = CFrame.Angles
					local v46 = v_u_14.Value
					local v47 = v44 * v45(math.rad(v46), 0, 0)
					local v48 = v_u_4.IsKeybindDown("run") and 75 or 35
					local v49 = shared
					v49.assetModePosition = v49.assetModePosition + v47:VectorToWorldSpace(v29 * v48 * p26)
				end
			end
			v_u_11:Move(v_u_18)
		end
	else
		return
	end
end
function InputBegan(p50, p51)
	-- upvalues: (ref) v_u_20, (ref) v_u_22
	v_u_20 = p51
	if shared.keybinds.jump then
		local v52 = shared.keybinds.jump
		if
			typeof(v52) == "table"
			and (
				not p51
				and (
					table.find(shared.keybinds.jump, p50.KeyCode) or table.find(shared.keybinds.jump, p50.UserInputType)
				)
			)
		then
			v_u_22 = true
		end
	end
end
function InputChanged(p53, p54)
	-- upvalues: (ref) v_u_20, (copy) v_u_23, (ref) v_u_21
	v_u_20 = p54
	if not table.find(v_u_23, p53.UserInputType) then
		shared.gamepadEnabled = false
	end
	if p53.KeyCode == Enum.KeyCode.Thumbstick1 and not p54 then
		if p53.Position.Magnitude > (shared.options and shared.options.Controls.LeftMovementDeadzone or 0.05) then
			shared.gamepadEnabled = true
			local v55 = p53.Position.X
			local v56 = -p53.Position.Y
			v_u_21 = Vector3.new(v55, 0, v56)
			return
		end
		v_u_21 = Vector3.new(0, 0, 0)
	end
end
function InputEnded(p57, p58)
	-- upvalues: (ref) v_u_20, (copy) v_u_23, (ref) v_u_21, (ref) v_u_22
	v_u_20 = p58
	if table.find(v_u_23, p57.UserInputType) then
		shared.gamepadEnabled = true
	else
		shared.gamepadEnabled = false
	end
	if p57.KeyCode == Enum.KeyCode.Thumbstick1 and not p58 then
		v_u_21 = Vector3.new(0, 0, 0)
	end
	if shared.keybinds.jump then
		local v59 = shared.keybinds.jump
		if
			typeof(v59) == "table"
			and (table.find(shared.keybinds.jump, p57.KeyCode) or table.find(shared.keybinds.jump, p57.UserInputType))
		then
			v_u_22 = false
		end
	end
end
function JumpRequest(p60)
	-- upvalues: (copy) v_u_4, (copy) v_u_6, (copy) v_u_11
	if not v_u_4.InCooldown("Jump") then
		if p60 and (shared.multipliers and shared.multipliers.JumpDelay) then
			v_u_6:Fire()
			v_u_4.ApplyCooldown("Jump")
			task.wait(shared.multipliers.JumpDelay)
		end
		v_u_11.Jump = p60
	end
end
function FixTP(p61)
	-- upvalues: (copy) v_u_10
	if not p61 then
		v_u_10.CFrame = p61
	end
end
v_u_4.GetEvent("MovementJump").Event:Connect(JumpRequest)
v5.OnClientEvent:Connect(FixTP)
v_u_3.InputBegan:Connect(InputBegan)
v_u_3.InputChanged:Connect(InputChanged)
v_u_3.InputEnded:Connect(InputEnded)
v_u_11.Jumping:Connect(function()
	-- upvalues: (copy) v_u_4, (copy) v_u_6
	v_u_4.ApplyCooldown("Jump")
	if not (shared.multipliers and shared.multipliers.JumpDelay) then
		v_u_6:Fire()
	end
end)
v1:BindToRenderStep("move update", Enum.RenderPriority.Input.Value, MoveUpdate)
v_u_11:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
v_u_11:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
