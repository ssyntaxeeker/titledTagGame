--[[
v_u_7 Sound
v_u_8 Animate
v_u_9 StopAnimation 
]]

-- Decompiled with Velocity Script Decompiler
local v1 = game:GetService("RunService")
local v_u_2 = game:GetService("TweenService")
local v_u_3 = game:GetService("ReplicatedStorage")
local v4 = game:GetService("UserInputService")
local v5 = v_u_3:WaitForChild("Effects")
local v_u_6 = require(game.ReplicatedFirst.Utils)
require(v_u_3.Modules.PartFractureModule)
local v_u_7 = v_u_6.GetEvent("SoundEvent")
local v_u_8 = v_u_6.GetEvent("AnimateEvent")
local v_u_9 = v_u_6.GetEvent("StopAnimationEvent")
v_u_6.GetEvent("AnimateJump")
local v_u_10 = v_u_6.GetEvent("AwardBadgeClient")
local v_u_11 = v_u_6.GetEvent("WindowBreak")
local v12 = v_u_6.GetEvent("ReleaseOpportunities")
local v13 = v_u_6.GetEvent("JumpInput")
local v_u_14 = v_u_6.GetEvent("KillToolAnims")
local v15 = v_u_6.GetEvent("AddFriction")
local v_u_16 = game.Players.LocalPlayer
local v_u_17 = v_u_16:WaitForChild("PlayerRole")
local v_u_18 = v_u_16.Character or v_u_16.CharacterAdded:Wait()
if script.Parent == v_u_18:FindFirstChild("scripts"):FindFirstChild("movement") then
	local v19 = 0
	for _, v20 in v_u_18:GetDescendants() do
		if v20.Name == "Parkour" and v20:IsA("LocalScript") then
			v19 = v19 + 1
		end
		if v19 > 1 then
			v_u_16:Kick("cheating is bad")
			return
		end
	end
	local v_u_21 = workspace.CurrentCamera
	local v_u_22 = v_u_18:WaitForChild("HumanoidRootPart")
	local v_u_23 = v_u_18:WaitForChild("Head")
	local v_u_24 = v_u_18:WaitForChild("Humanoid")
	local v25 = v_u_16:WaitForChild("PlayerGui")
	local v26 = v25:WaitForChild("TouchGuiUTG")
	local v_u_27 = v25:WaitForChild("Debug")
	local v_u_28 =
		v25:WaitForChild("RightSpace"):WaitForChild("Frame"):WaitForChild("Stats"):WaitForChild("SpeedContainer")
	local v_u_29 = v25:WaitForChild("Stats"):WaitForChild("BottomLeft"):WaitForChild("SpeedContainer")
	local v_u_30 = v25:WaitForChild("Stats"):WaitForChild("Speedometer")
	local v_u_31 = time()
	local v_u_32 = 60
	local v33 = v_u_18:WaitForChild("values")
	local v_u_34 = v33:WaitForChild("MoveVector")
	local v_u_35 = v33:WaitForChild("CameraX")
	local v_u_36 = v33:WaitForChild("CameraY")
	local v_u_37 = v33:WaitForChild("LockMoveVector")
	DEBUG_SWING_COLOR = { 0.74, 0.15, 1 }
	DEBUG_NORMAL_ROLL_COLOR = Color3.fromRGB(219, 234, 255)
	DEBUG_NORMAL_VAULT_COLOR = Color3.fromRGB(225, 255, 226)
	DEBUG_PERFECT_ROLL_COLOR = Color3.fromRGB(84, 252, 255)
	DEBUG_PERFECT_VAULT_COLOR = Color3.fromRGB(80, 255, 179)
	if not shared.cooldowns then
		shared.cooldowns = {}
	end
	repeat
		task.wait()
	until shared.multipliers
	shared.boosts = {}
	local v_u_38 = nil
	local v_u_39 = false
	local v_u_40 = false
	local v_u_41 = time()
	local v_u_42 = nil
	local v_u_43 = nil
	local v_u_44 = nil
	local v_u_45 = time()
	local v_u_46 = time()
	shared.tiltSwinging = nil
	local v_u_47 = nil
	local v_u_48 = 1
	local v_u_49 = nil
	local v_u_50 = time()
	shared.railGrinding = false
	local v_u_51 = false
	shared.wallrunSide = nil
	local v_u_52 = nil
	local v_u_53 = false
	shared.ziplining = false
	local v_u_54 = 0
	local v_u_55 = 0
	local v_u_56 = 0
	local v_u_57 = 0
	local v_u_58 = 0
	local v_u_59 = -99
	local v_u_60 = -99
	local v_u_61 = -99
	local v_u_62 = -99
	local v_u_63 = -99
	local v_u_64 = -99
	shared.sliding = false
	v_u_18:SetAttribute("Sliding", false)
	local v_u_65 = nil
	shared.crouching = false
	local v_u_66 = nil
	local v_u_67 = nil
	shared.inWindzone = nil
	time()
	local v_u_68 = time()
	local v_u_69 = time()
	local v_u_70 = time()
	local v_u_71 = Enum.Material.Air
	local v_u_72 = RaycastParams.new()
	v_u_72.CollisionGroup = "Player"
	v_u_72.FilterDescendantsInstances = { v_u_18, v_u_21 }
	v_u_72.CollisionGroup = "Player"
	local v_u_73 = v5:WaitForChild("RailSparks"):WaitForChild("Attachment"):Clone()
	v_u_73.Parent = v_u_22
	v_u_73.Sparks.Enabled = false
	v_u_73.Sparks:SetAttribute("Enabled", false)
	local v_u_74 = v5:WaitForChild("ZiplineEffects"):WaitForChild("Attachment"):Clone()
	v_u_74.Parent = v_u_22
	local v_u_75 = Instance.new("AlignPosition")
	local v_u_76 = Instance.new("Attachment")
	local v_u_77 = Instance.new("Attachment")
	v_u_75.Attachment0 = v_u_76
	v_u_75.Attachment1 = v_u_77
	v_u_75.Enabled = false
	v_u_75.Responsiveness = 100
	v_u_75.MaxForce = 10000
	v_u_75.Parent = v_u_22
	v_u_76.Parent = v_u_22
	v_u_77.Parent = v_u_22
	function Vault(p78)
		-- upvalues: (copy) v_u_6, (ref) v_u_68, (ref) v_u_38, (copy) v_u_8, (copy) v_u_14, (copy) v_u_7, (copy) v_u_22, (ref) v_u_54
		if shared.emoteData and not shared.emoteData.Unrestrictive then
			return
		elseif shared.multipliers.DisableVaulting then
			return
		elseif not v_u_6.InCooldown("Vault") then
			local v79 = v_u_68 < time()
			v_u_68 = time() + 0.5
			local v80 = p78 >= 2
			local v81 = p78 >= 2.5
			if shared.options.Misc.DebugPrint then
				local v82 = string.format("%.2f studs", p78)
				if p78 >= 2.745 then
					v_u_6.DebugPrint(v82, "rainbow")
				else
					local v83
					if v80 then
						v83 = DEBUG_PERFECT_VAULT_COLOR
					else
						v83 = DEBUG_NORMAL_VAULT_COLOR
					end
					v_u_6.DebugPrint(v82, v83)
				end
			end
			v_u_38 = "vault"
			v_u_8:Fire("Vault", 0.225)
			v_u_14:Fire()
			v_u_7:Fire(v81 and "HighVault" or "Vault", v_u_22, 0.15, true)
			local v84 = v_u_22
			local v85 = v_u_22.AssemblyLinearVelocity.X
			local v86 = p78 / 1.5 * 30
			local v87 = math.clamp(v86, 30, (1 / 0))
			local v88 = v_u_22.AssemblyLinearVelocity.Z
			v84.AssemblyLinearVelocity = Vector3.new(v85, v87, v88) - v_u_22.CFrame.LookVector * 2
			v_u_54 = v_u_54
				+ 3
					* shared.multipliers.VaultMomentumMultiplier
					* shared.multipliers.MomentumMultiplier
					* (v79 and 1 or (shared.multipliers.VaultStackingMomentumMultiplier or 0.45))
			v_u_6.ApplyCooldown("Vault")
		end
	end
	function StartSwingAround(p89, p_u_90, p_u_91, p92, p93)
		-- upvalues: (ref) v_u_75, (ref) v_u_76, (ref) v_u_77, (copy) v_u_18, (copy) v_u_8, (copy) v_u_9, (ref) v_u_39, (copy) v_u_22, (ref) v_u_54, (copy) v_u_24, (ref) v_u_42
		if p92 then
			p92:Destroy()
		end
		local v94 = p89.Instance.Size.X > p89.Instance.Size.Y and p89.Instance.Size.X > p89.Instance.Size.Z and "X"
			or (p89.Instance.Size.Y > p89.Instance.Size.X and p89.Instance.Size.Y > p89.Instance.Size.Z and "Y" or "Z")
		v_u_75.Responsiveness = 120
		v_u_75.MaxForce = 10000
		v_u_75.Enabled = true
		v_u_76.CFrame = CFrame.new()
		v_u_77.CFrame = CFrame.new()
		v_u_77.Parent = p89.Instance
		v_u_77.WorldPosition = p89.Position
		if v94 == "X" then
			local v95 = v_u_77
			v95.Position = v95.Position * Vector3.new(1, 0, 0)
		elseif v94 == "Y" then
			local v96 = v_u_77
			v96.Position = v96.Position * Vector3.new(0, 1, 0)
		else
			local v97 = v_u_77
			v97.Position = v97.Position * Vector3.new(0, 0, 1)
		end
		local v98 = v_u_77
		v98.WorldPosition = v98.WorldPosition - Vector3.new(0, 2.5, 0)
		v_u_18.RailGrind:Play()
		v_u_18.RailGrind.PlaybackSpeed = 0.6
		v_u_8:Fire("SwingBarLoop", 0.1, 1.25)
		shared.tiltSwinging = true
		shared.tiltSwingAngle = CFrame.new()
		shared.tiltSwingSpeed = 1
		local v99 = 1
		repeat
			v99 = v99 + task.wait() * 0.5
			v_u_18.RailGrind.PlaybackSpeed = v99 - 1 + 0.3
			shared.tiltSwingSpeed = v99
		until not (shared.jumpInput and shared.tiltSwinging)
		v_u_9:Fire("SwingBarLoop", 0.66)
		v_u_39 = false
		local v100 = v_u_18:FindFirstChild("Torso") and v_u_18.Torso.CFrame.LookVector or v_u_22.CFrame.LookVector
		local v101 = -p93.Y
		local v102 = (math.clamp(v101, 25, 80) / 25) ^ 0.7 * v99
		v_u_54 = v_u_54 + v102 * 4 * shared.multipliers.SwingBarMultiplier * shared.multipliers.MomentumMultiplier
		local v103 = v_u_22
		v103.AssemblyLinearVelocity = v103.AssemblyLinearVelocity
			+ (
					(v_u_24.MoveDirection.Magnitude > 0.1 and v_u_24.MoveDirection or v_u_22.CFrame.LookVector)
					+ v100 * 0.45
				)
				* (v102 * 45 * shared.multipliers.SwingBarMultiplier)
		local v_u_104 = v_u_42
		task.spawn(function()
			-- upvalues: (copy) v_u_104, (ref) v_u_42, (copy) p_u_90, (copy) p_u_91
			task.wait(1)
			if v_u_104 and not v_u_42 then
				v_u_104.CanCollide = p_u_90
				if v_u_104.Parent:GetAttribute("SwingBar") then
					v_u_104.Parent.CanCollide = p_u_91
				end
			end
		end)
		v_u_18.RailGrind:Pause()
		v_u_75.Enabled = false
		shared.tiltSwingAngle = nil
		shared.tiltSwinging = nil
		shared.tiltSwingSpeed = nil
		v_u_42 = nil
	end
	function DoSwing(p105)
		-- upvalues: (copy) v_u_6, (copy) v_u_24, (ref) v_u_38, (copy) v_u_7, (copy) v_u_22, (copy) v_u_8, (ref) v_u_42, (ref) v_u_39, (copy) v_u_16, (copy) v_u_10, (ref) v_u_54
		if shared.multipliers.DisableSwingBars then
			return
		elseif not v_u_6.InCooldown("SwingBar") then
			if p105 and (v_u_24 and v_u_24.Health > 0) then
				v_u_38 = "swing bar"
				v_u_7:Fire("SwingBar", v_u_22, 0.25, true)
				v_u_8:Fire("SwingBar", 0.1, 1.5)
				v_u_42 = p105.Instance
				local v106 = v_u_42.CanCollide
				v_u_42.CanCollide = false
				local v107
				if v_u_42.Parent:GetAttribute("SwingBar") then
					v107 = v_u_42.Parent.CanCollide
					v_u_42.Parent.CanCollide = false
				else
					v107 = v106
				end
				local v108 = CFrame.new(p105.Position) + Vector3.new(0, -1.5, 0) + v_u_22.CFrame.LookVector * -1
				v_u_22.CFrame = v_u_22.CFrame:Lerp(v108, 0.5)
				local v109 = v_u_22.CFrame - v_u_22.CFrame.Position
				local v110 = v_u_22.CFrame.Position.X
				local v111 = p105.Position.Y - 1.5
				local v112 = v_u_22.CFrame.Position.Z
				local v113 = v109 + Vector3.new(v110, v111, v112)
				v_u_22.CFrame = v_u_22.CFrame:Lerp(v113, 0.5)
				local v114 = Instance.new("BodyPosition")
				v114.MaxForce = Vector3.new(700, 9000, 700)
				v114.Position = p105.Position + Vector3.new(0, -1.5, 0)
				v114.Parent = v_u_22
				local v115 = v_u_22.AssemblyLinearVelocity
				v_u_39 = true
				local v116 = -v115.Y
				local v117 = (math.clamp(v116, 25, 80) / 25) ^ 0.7
				if v117 >= 1.8 and not v_u_16:GetAttribute("HasBadgeGymnast") then
					v_u_10:FireServer("Gymnast")
				end
				v_u_6.ApplyCooldown("SwingBar")
				local v118 = 0
				repeat
					v118 = v118 + task.wait()
				until shared.jumpInput and (v118 >= 0.15 and p105.Instance.Name == "ExperimentalSwingbar")
					or v118 >= 0.4
				if p105.Instance.Name == "ExperimentalSwingbar" and shared.jumpInput then
					StartSwingAround(p105, v106, v107, v114, v115)
					return
				end
				if v114 then
					v114:Destroy()
				end
				v_u_39 = false
				if shared.options.Misc.DebugPrint then
					local v119 = (v117 - 1 + 0.001) / 1.8
					local v120 = Color3.fromHSV(
						DEBUG_SWING_COLOR[1] + v119 / 2,
						DEBUG_SWING_COLOR[2] + v119,
						DEBUG_SWING_COLOR[3]
					)
					v_u_6.DebugPrint(string.format("%.2f%% vps", v117 * 100), v120)
				end
				v_u_54 = v_u_54
					+ v117 * 3 * shared.multipliers.MomentumMultiplier * shared.multipliers.SwingBarMultiplier
				local v121 = v_u_22
				v121.AssemblyLinearVelocity = v121.AssemblyLinearVelocity
					+ (v_u_24.MoveDirection.Magnitude > 0.1 and v_u_24.MoveDirection or v_u_22.CFrame.LookVector)
						* (v117 * 50 * shared.multipliers.SwingBarMultiplier)
				v_u_42.CanCollide = v106
				if v_u_42.Parent:GetAttribute("SwingBar") then
					v_u_42.Parent.CanCollide = v107
				end
				v_u_42 = nil
			end
		end
	end
	function BreakGlass(p122, p_u_123, p_u_124)
		-- upvalues: (copy) v_u_6, (ref) v_u_38, (copy) v_u_11, (copy) v_u_22, (copy) v_u_8, (ref) v_u_39, (ref) v_u_54, (ref) v_u_55
		if shared.multipliers.DisableWindowSmashing then
			return
		elseif not v_u_6.InCooldown("WindowSmash") then
			v_u_38 = "break glass"
			v_u_11:Fire(p122, v_u_22, p_u_123)
			v_u_8:Fire("Tag1", 0.1, v_u_6.Random:NextNumber(-1.75, -1.4), v_u_6.Random:NextNumber(0.6, 1))
			v_u_8:Fire("Tag2", 0.1, v_u_6.Random:NextNumber(-1.75, -1.4), v_u_6.Random:NextNumber(0.6, 1))
			v_u_6.ApplyCooldown("WindowSmash")
			local v_u_125 = v_u_22.AssemblyLinearVelocity
			local v126 = v_u_6.ShakeCamera
			local v127 = shared.multipliers.WindowSmashMultiplier
			v126(math.abs(v127) ^ 0.3 * 10)
			task.spawn(function()
				-- upvalues: (ref) v_u_39, (ref) v_u_22, (ref) v_u_54, (ref) v_u_55, (copy) v_u_125, (copy) p_u_123, (copy) p_u_124
				v_u_39 = true
				local v128 = v_u_22
				v128.AssemblyLinearVelocity = v128.AssemblyLinearVelocity * 0.5
				task.wait(0.05)
				v_u_39 = false
				if shared.multipliers.WindowSmashMultiplier < 0 then
					local v129 = v_u_54
					local v130 = 5 * shared.multipliers.MomentumMultiplier
					local v131 = shared.multipliers.WindowSmashMultiplier
					v_u_54 = v129 + v130 * math.abs(v131)
				else
					v_u_55 = v_u_55
						+ 5 * shared.multipliers.FrictionMultiplier * shared.multipliers.WindowSmashMultiplier
				end
				v_u_22.AssemblyLinearVelocity = v_u_125
					+ (p_u_123 - v_u_22.CFrame.Position).Unit * 7.5
					+ p_u_124 * -3.33 * shared.multipliers.WindowSmashMultiplier
			end)
		end
	end
	function ReleaseRope(p132)
		-- upvalues: (copy) v_u_6, (copy) v_u_22, (copy) v_u_35, (ref) v_u_43, (ref) v_u_54, (ref) v_u_45, (ref) v_u_75, (ref) v_u_76, (ref) v_u_77
		if p132 then
			::l2::
			v_u_45 = time() + 0.2
			v_u_75.Enabled = false
			v_u_76.CFrame = CFrame.new()
			v_u_77.CFrame = CFrame.new()
			v_u_77.Parent = v_u_22
			v_u_43 = nil
			return
		end
		v_u_6.ShakeCamera(4.5)
		local v133 = v_u_22.AssemblyLinearVelocity.X
		if v_u_35.Value > -37.5 then
			local v134 = v_u_35.Value * 0.5
			v142 = math.clamp(v134, 45, (1 / 0))
			if v142 then
				::l5::
				local v135 = v_u_22.AssemblyLinearVelocity.Z
				local v136 = Vector3.new(v133, v142, v135)
				local v137 = v_u_22.CFrame.LookVector
				local v138 = v_u_35.Value
				v_u_22.AssemblyLinearVelocity = (v136 + v137 * ((90 - math.abs(v138)) * 0.5)) * 0.6
					+ v_u_43.AssemblyLinearVelocity * 0.65 * shared.multipliers.RopeSwingMultiplier
				local v139 = v_u_54
				local v140 = v_u_22.AssemblyLinearVelocity.Magnitude / 65
				v_u_54 = v139
					+ math.clamp(v140, 1, 5)
						* 5
						* shared.multipliers.MomentumMultiplier
						* shared.multipliers.RopeSwingMultiplier
				goto l2
			end
		end
		local v141 = v_u_35.Value * 0.5
		local v142 = math.clamp(v141, (-1 / 0), -45)
		goto l5
	end
	function GrabRope(p143)
		-- upvalues: (ref) v_u_40, (copy) v_u_6, (ref) v_u_38, (ref) v_u_76, (ref) v_u_77, (copy) v_u_22, (ref) v_u_45, (ref) v_u_44, (ref) v_u_75, (ref) v_u_43
		if shared.emoteData and not shared.emoteData.Unrestrictive then
			return
		elseif v_u_40 then
			return
		elseif shared.multipliers.DisableRopeSwinging then
			return
		elseif not v_u_6.InCooldown("RopeSwing") then
			local v144 = v_u_6.GetEvent("GrabRope"):Invoke(p143.Instance:FindFirstAncestorOfClass("Model"))
			local v145 = v144 and v144:FindFirstChild(p143.Instance.Name, true)
			if v145 then
				v_u_6.ShakeCamera(5)
				v_u_6.ApplyCooldown("RopeSwing", p143.Position)
				v_u_38 = "rope swing"
				v_u_76.CFrame = CFrame.new()
				v_u_77.CFrame = CFrame.new()
				v_u_77.Parent = v145
				v_u_77.WorldPosition = p143.Position
				local v146 = v_u_77
				v146.Position = v146.Position * Vector3.new(1, 0, 0)
				local v147 = nil
				local v148 = nil
				for _, v149 in v145.Parent.Parent:GetDescendants() do
					if
						v149:IsA("BasePart")
						and (
							not v149.Anchored
							and (
								v149.Name ~= "Bottom"
								and (
									v149.Name ~= "Top"
									and (not v147 or v148 < (v149.Position - v_u_22.CFrame.Position).Magnitude)
								)
							)
						)
					then
						v148 = (v149.Position - v_u_22.CFrame.Position).Magnitude
						v147 = v149
					end
				end
				if v147 then
					v147.AssemblyLinearVelocity = v_u_22.AssemblyLinearVelocity
						* 0.9
						* shared.multipliers.RopeSwingMultiplier
				end
				v_u_45 = time() + 0.3
				v_u_76.Position = Vector3.new(0, 0, -1)
				v_u_44 = v_u_22.CFrame.Position
				v_u_22.CFrame = (v_u_22.CFrame - v_u_22.CFrame.Position + v_u_77.WorldPosition)
					* CFrame.new(-v_u_76.Position)
				v_u_22.AssemblyLinearVelocity = v147.AssemblyLinearVelocity
				v_u_75.Responsiveness = 120
				v_u_75.MaxForce = 10000
				v_u_75.Enabled = true
				v_u_43 = v145
			end
		end
	end
	function ReleaseWallrun(p150)
		-- upvalues: (ref) v_u_51, (copy) v_u_37, (copy) v_u_6, (copy) v_u_22, (copy) v_u_35, (ref) v_u_54, (copy) v_u_9
		if not v_u_51 then
			return
		end
		v_u_51 = nil
		v_u_37:SetAttribute("ForceVector", nil)
		shared.wallrunSide = nil
		if not p150 then
			::l4::
			v_u_6.ApplyCooldown("Wallrun")
			v_u_9:Fire("WallrunLeft", 0.1)
			v_u_9:Fire("WallrunRight", 0.1)
			v_u_37.Value = false
			return
		end
		v_u_6.ShakeCamera(4.5)
		local v151 = v_u_22.AssemblyLinearVelocity.X
		if v_u_35.Value > -37.5 then
			local v152 = v_u_35.Value * 0.5
			v160 = math.clamp(v152, 45, (1 / 0))
			if v160 then
				::l7::
				local v153 = v_u_22.AssemblyLinearVelocity.Z
				local v154 = Vector3.new(v151, v160, v153)
				local v155 = v_u_22.CFrame.LookVector
				local v156 = v_u_35.Value
				v_u_22.AssemblyLinearVelocity = (v154 + v155 * ((90 - math.abs(v156)) * 0.5)) * 0.7
				local v157 = v_u_54
				local v158 = v_u_22.AssemblyLinearVelocity.Magnitude / 65
				v_u_54 = v157 + math.clamp(v158, 1, 5) * 5 * shared.multipliers.MomentumMultiplier
				goto l4
			end
		end
		local v159 = v_u_35.Value * 0.5
		local v160 = math.clamp(v159, (-1 / 0), -45)
		goto l7
	end
	function StartWallrun(p161, p162)
		-- upvalues: (ref) v_u_40, (ref) v_u_51, (copy) v_u_22, (copy) v_u_8, (copy) v_u_6, (copy) v_u_24, (copy) v_u_37
		if shared.emoteData and not shared.emoteData.Unrestrictive then
			return
		elseif v_u_40 then
			return
		elseif not p161 or (p161.Instance:GetAttribute("Wallrun") or shared.multipliers.EnableWallrunning) then
			v_u_51 = p161
			local v163 = v_u_22.CFrame:PointToObjectSpace(p161.Position)
			local v164 = CFrame.new(Vector3.new(0, 0, 0), p161.Normal)
			v_u_22.CFrame = v_u_22.CFrame.Rotation + p161.Position + p161.Normal
			if not p162 then
				local v165 = v_u_22
				local v166 = v_u_22.AssemblyLinearVelocity.X
				local v167 = v_u_22.AssemblyLinearVelocity.Z
				v165.AssemblyLinearVelocity = Vector3.new(v166, 10, v167)
				v_u_8:Fire("Wallrun" .. (v163.X < 0 and "Left" or "Right"), 0.1)
				v_u_6.ApplyCooldown("Wallrun")
			end
			local v168 = shared
			local v169 = v163.X
			v168.wallrunSide = math.sign(v169)
			v_u_24.WalkSpeed = 32 * (p161.Instance:GetAttribute("Speed") or 1)
			local v170 = v_u_37
			local v171 = v164.RightVector
			local v172 = v163.X
			v170:SetAttribute("ForceVector", v171 * math.sign(v172))
			v_u_37.Value = true
		end
	end
	function WallrunCheck(p173)
		-- upvalues: (copy) v_u_24, (copy) v_u_22, (copy) v_u_72, (copy) v_u_6
		local v174 = nil
		local v175 = false
		if v_u_24.FloorMaterial == Enum.Material.Air then
			for v176 = 0, 1 do
				if not v174 then
					local v177 = Ray.new(v_u_22.Position, v_u_22.CFrame.RightVector * (v176 == 0 and 1 or -1) * 5)
					v174 = workspace:Raycast(v177.Origin, v177.Direction, v_u_72)
					if shared.options.Misc.DebugRaycast then
						local v178 = v_u_6.DebugRaycast
						local v179 = v177.Origin
						local v180 = v177.Direction
						local v181
						if v174 then
							v181 = v174.Position
						else
							v181 = v174
						end
						v178(v179, v180, v181, Color3.new(1, 0, 1), 5)
					end
				end
			end
		end
		if v174 and (v174.Instance:GetAttribute("Wallrun") or shared.multipliers.EnableWallrunning) then
			local v182 = v174.Normal.Y
			if math.abs(v182) < 0.15 then
				StartWallrun(v174, p173)
				v175 = true
			end
		end
		if p173 and not v175 then
			ReleaseWallrun()
		end
	end
	function ReleaseRail(p183)
		-- upvalues: (copy) v_u_6, (copy) v_u_22, (copy) v_u_35, (ref) v_u_54, (copy) v_u_18, (copy) v_u_9, (copy) v_u_7, (ref) v_u_73, (ref) v_u_75, (ref) v_u_76, (ref) v_u_77, (ref) v_u_50, (ref) v_u_47
		if p183 then
			::l2::
			v_u_18.RailGrind:Pause()
			v_u_9:Fire("StartRailGrind")
			v_u_9:Fire("RailGrind", 0.25)
			v_u_7:Fire("EndRailGrind", v_u_22, 0.25, true)
			v_u_73.Sparks.Enabled = false
			v_u_73.Sparks:SetAttribute("Enabled", false)
			v_u_75.Enabled = false
			v_u_75.RigidityEnabled = false
			v_u_76.CFrame = CFrame.new()
			v_u_77.CFrame = CFrame.new()
			v_u_77.Parent = v_u_22
			v_u_50 = time() + 0.2
			shared.railGrinding = false
			v_u_47 = nil
			return
		end
		v_u_6.ShakeCamera(4)
		local v184 = v_u_22.AssemblyLinearVelocity.X
		if v_u_35.Value > -70 then
			local v185 = v_u_35.Value * 0.5
			v193 = math.clamp(v185, 45, (1 / 0))
			if v193 then
				::l5::
				local v186 = v_u_22.AssemblyLinearVelocity.Z
				local v187 = Vector3.new(v184, v193, v186)
				local v188 = v_u_22.CFrame.LookVector
				local v189 = v_u_35.Value
				v_u_22.AssemblyLinearVelocity = (v187 + v188 * ((90 - math.abs(v189)) * 0.5))
					* 0.75
					* v_u_6.Lerp(shared.multipliers.RailGrindMultiplier, 1, 0.5)
				local v190 = v_u_54
				local v191 = v_u_22.AssemblyLinearVelocity.Magnitude / 65
				v_u_54 = v190
					+ math.clamp(v191, 1, 5)
						* 5
						* shared.multipliers.MomentumMultiplier
						* shared.multipliers.RailGrindMultiplier
				goto l2
			end
		end
		local v192 = v_u_35.Value * 0.5
		local v193 = math.clamp(v192, (-1 / 0), -45)
		goto l5
	end
	function RailFling()
		-- upvalues: (copy) v_u_6, (copy) v_u_22, (copy) v_u_35, (ref) v_u_54, (copy) v_u_9, (copy) v_u_8, (copy) v_u_7, (ref) v_u_73, (ref) v_u_50, (ref) v_u_47
		v_u_6.ShakeCamera(10)
		local v194 = v_u_22.CFrame.LookVector + v_u_22.CFrame.UpVector * 0.2
		local v195 = v_u_35.Value
		v_u_22.AssemblyLinearVelocity = v194
			* ((90 - math.abs(v195)) / 90) ^ 0.75
			* 170
			* v_u_6.Lerp(shared.multipliers.RailFlingMultiplier, 1, 0.5)
		local v196 = v_u_54
		local v197 = v_u_22.AssemblyLinearVelocity.Magnitude / 65
		v_u_54 = v196
			+ math.clamp(v197, 1, 5)
				* 5
				* shared.multipliers.MomentumMultiplier
				* shared.multipliers.RailFlingMultiplier
		v_u_9:Fire("Roll", 0.25)
		v_u_8:Fire("RailFling")
		v_u_7:Fire("RailFling", v_u_22, 0.25, true)
		v_u_73.Sparks:Emit(50)
		v_u_50 = time() + 1
		shared.railGrinding = false
		v_u_47 = nil
	end
	function AttachToRail(p198, p199)
		-- upvalues: (ref) v_u_40, (ref) v_u_50, (copy) v_u_6, (copy) v_u_8, (copy) v_u_7, (copy) v_u_22, (copy) v_u_18, (ref) v_u_73, (ref) v_u_38, (ref) v_u_48, (ref) v_u_77, (ref) v_u_76, (ref) v_u_75, (ref) v_u_47
		if v_u_40 then
			return
		elseif not shared.multipliers.DisableRailGrinding then
			if p199 then
				v_u_50 = time() + 0.015
			else
				if v_u_6.InCooldown("RailGrind") then
					return
				end
				v_u_6.ShakeCamera(4.5)
				v_u_8:Fire("StartRailGrind")
				v_u_8:Fire("RailGrind")
				v_u_7:Fire("StartRailGrind", v_u_22, 0.25, true)
				v_u_18.RailGrind.PlaybackSpeed = 1.1
				v_u_18.RailGrind:Resume()
				v_u_73.Sparks:Emit(25)
			end
			v_u_73.Sparks.Enabled = true
			v_u_73.Sparks:SetAttribute("Enabled", true)
			v_u_38 = "rail grind"
			local v200 = v_u_22.AssemblyLinearVelocity.Magnitude / 30
			v_u_48 = math.clamp(v200, 0.8, 2.5)
			local v201 = p198.Instance.Parent
			local v202 = v201.Size.X > v201.Size.Y and v201.Size.X > v201.Size.Z and "X"
				or (v201.Size.Y > v201.Size.X and v201.Size.Y > v201.Size.Z and "Y" or "Z")
			local v203 = v_u_77.WorldPosition
			v_u_76.CFrame = CFrame.new()
			v_u_77.CFrame = CFrame.new()
			v_u_77.Parent = v201
			v_u_77.WorldPosition = p199 and v203 and v203 or p198.Position
			if v202 == "X" then
				local v204 = v_u_77
				v204.Position = v204.Position * Vector3.new(1, 0, 0)
			elseif v202 == "Y" then
				local v205 = v_u_77
				v205.Position = v205.Position * Vector3.new(0, 1, 0)
			else
				local v206 = v_u_77
				v206.Position = v206.Position * Vector3.new(0, 0, 1)
			end
			v_u_6.ApplyCooldown("RailGrind")
			v_u_76.Position = Vector3.new(0, -4, 0.5)
			v_u_22.CFrame = (v_u_22.CFrame - v_u_22.CFrame.Position + v_u_77.WorldPosition)
				* CFrame.new(-v_u_76.Position)
			v_u_75.RigidityEnabled = true
			v_u_75.Responsiveness = 175
			v_u_75.MaxForce = 10000
			v_u_75.Enabled = true
			v_u_47 = v201
			shared.railGrinding = true
		end
	end
	function ReleaseZipline(p207)
		-- upvalues: (ref) v_u_52, (copy) v_u_9, (copy) v_u_6, (copy) v_u_22, (ref) v_u_75, (ref) v_u_76, (ref) v_u_77, (ref) v_u_74, (ref) v_u_53, (copy) v_u_18, (copy) v_u_21
		if v_u_52 then
			v_u_9:Fire("ZiplineEnter", 0.25)
			v_u_9:Fire("Ziplining", 0.25)
			v_u_6.PlaySound("EndZipline", v_u_22, 0.1, true)
			v_u_75.Enabled = false
			v_u_76.CFrame = CFrame.new()
			v_u_77.CFrame = CFrame.new()
			v_u_77.Parent = v_u_22
			v_u_74.Smoke.Enabled = false
			v_u_74.Sparks.Enabled = false
			v_u_74.IgniteLight.Enabled = false
			v_u_74.Smoke:SetAttribute("Enabled", false)
			v_u_74.Sparks:SetAttribute("Enabled", false)
			v_u_74.IgniteLight:SetAttribute("Enabled", false)
			if v_u_53 then
				v_u_74["Ignite" .. 1].Enabled = false
				v_u_74["Ignite" .. 1]:SetAttribute("Enabled", false)
				v_u_74["Ignite" .. 2].Enabled = false
				v_u_74["Ignite" .. 2]:SetAttribute("Enabled", false)
				v_u_74["Ignite" .. 3].Enabled = false
				v_u_74["Ignite" .. 3]:SetAttribute("Enabled", false)
				v_u_6.PlaySound("ZiplineExtinguish", v_u_22, 0.1)
			end
			v_u_53 = false
			v_u_18.Zipline:Pause()
			v_u_52.Parent:Destroy()
			v_u_52:Destroy()
			v_u_52 = nil
			shared.ziplining = false
			if p207 then
				local v208 = v_u_22
				v208.AssemblyLinearVelocity = v208.AssemblyLinearVelocity
					+ v_u_21.CFrame.LookVector * 50 * Vector3.new(1, 0.3, 0)
			end
			v_u_6.ApplyCooldown("Zipline")
		end
	end
	function AttachZipline()
		-- upvalues: (copy) v_u_6, (ref) v_u_40, (ref) v_u_52, (ref) v_u_75, (copy) v_u_22, (ref) v_u_70, (copy) v_u_8, (copy) v_u_18, (ref) v_u_77, (ref) v_u_76, (ref) v_u_74, (ref) v_u_53
		if v_u_6.InCooldown("Zipline") then
			return
		elseif shared.multipliers.DisableZiplining or v_u_40 then
			return
		elseif v_u_52 or v_u_75.Enabled then
			if v_u_52 then
				ReleaseZipline(true)
			end
		else
			for _, v209 in workspace:GetPartBoundsInRadius(v_u_22.Position, 5) do
				if v209.Parent and v209.Parent:GetAttribute("Zipline") then
					v_u_6.ApplyCooldown("Zipline")
					v_u_70 = time() + 0.5
					local v210 = {}
					for _, v211 in pairs(v209.Parent:GetChildren()) do
						if v211.Name == "ZiplinePart" then
							table.insert(v210, v211)
						end
					end
					v_u_6.PlaySound("StartZipline", v_u_22, 0.1, true)
					v_u_8:Fire("Ziplining", 0.2)
					v_u_8:Fire("ZiplineEnter", 0)
					v_u_18.Zipline:Resume()
					local v212 = Instance.new("Part", v_u_18)
					v212.CFrame = v_u_22.CFrame
					v212.AssemblyLinearVelocity = v_u_22.AssemblyLinearVelocity
					v212.CanCollide = false
					v212.Transparency = 1
					v_u_77.Parent = v212
					v_u_76.CFrame = CFrame.new(0, 2.5, 0)
					v_u_75.MaxForce = 10000
					v_u_75.Enabled = true
					v_u_74.Sparks:Emit(3)
					v_u_74.Sparks.Rate = 0
					v_u_74.Smoke.Rate = 0
					v_u_53 = false
					local v213 = Instance.new("PrismaticConstraint")
					v213.Attachment0 = v209.Parent.ZipPart:FindFirstChild("TopAttachment")
					v213.Attachment1 = v_u_77
					v213.LimitsEnabled = true
					v213.UpperLimit = v209.Parent.ZipPart.Size.Z
					v213.Parent = v212
					v_u_52 = v213
					shared.ziplining = true
					return
				end
			end
		end
	end
	function ReleaseOpportunities(p214)
		-- upvalues: (ref) v_u_40, (ref) v_u_43, (ref) v_u_47, (ref) v_u_52
		if not p214 then
			v_u_40 = true
			task.spawn(function()
				-- upvalues: (ref) v_u_40
				task.wait(2)
				v_u_40 = false
			end)
		end
		shared.tiltSwinging = nil
		if v_u_43 then
			ReleaseRope(true)
		end
		if v_u_43 then
			ReleaseWallrun()
		end
		if v_u_47 then
			ReleaseRail(true)
		end
		if v_u_52 and not shared.emoteData then
			ReleaseZipline()
		end
	end
	function Roll(p215)
		-- upvalues: (copy) v_u_6, (ref) v_u_61, (copy) v_u_37, (ref) v_u_59, (copy) v_u_16, (copy) v_u_10, (ref) v_u_57, (copy) v_u_3, (copy) v_u_7, (copy) v_u_22, (copy) v_u_34, (copy) v_u_8, (copy) v_u_24
		if shared.emoteData and not shared.emoteData.Unrestrictive then
			return
		elseif shared.multipliers.DisableRolling then
			return
		elseif not v_u_6.InCooldown("Roll") then
			v_u_61 = -99
			v_u_37:SetAttribute("ForceVector", nil)
			v_u_37.Value = true
			v_u_59 = time()
			local v216 = p215 < 0.1
			local v217 = (v216 and (1.3 + ((0.1 - p215) * 3.5) ^ 0.85 or 1.3) or 1.3)
				* shared.multipliers.RollSpeedMultiplier
			if p215 <= 0.01 and not v_u_16:GetAttribute("HasBadgeRollExpert") then
				v_u_10:FireServer("RollExpert")
			end
			if shared.options.Misc.DebugPrint then
				local v218 = p215 * 1000
				local v219 = string.format("%.2f ms", v218)
				if v218 <= 10 then
					v_u_6.DebugPrint(v219, "rainbow")
				else
					local v220
					if v216 then
						v220 = DEBUG_PERFECT_ROLL_COLOR
					else
						v220 = DEBUG_NORMAL_ROLL_COLOR
					end
					v_u_6.DebugPrint(v219, v220)
				end
			end
			v_u_57 = p215 * 1000
			if v216 then
				v_u_3.Sounds.PerfectRoll.PlaybackSpeed = v217 + 0.15
				v_u_7:Fire("PerfectRoll", v_u_22, 0, true)
			end
			v_u_3.Sounds.Roll.PlaybackSpeed = v216 and v217 and v217 or 1
			v_u_7:Fire("Roll", v_u_22, v216 and 0.05 or 0.25, true)
			local v221
			if v_u_34.Value.Z > 0.33 then
				v221 = v216 and -1.6 or -1.25
				if not v_u_16:GetAttribute("HasBadgeBackRoll") then
					v_u_10:FireServer("BackRoll")
				end
			else
				v221 = v216 and 1.4 or 1
			end
			v_u_8:Fire("Roll", 0.1, v221)
			v_u_6.ShakeCamera(5)
			local v222 = v_u_24
			v222.WalkSpeed = v222.WalkSpeed * v217
			shared.boosts.Roll = {
				["Speed"] = v217,
			}
			task.wait(0.15)
			local v223 = v_u_24
			v223.JumpPower = v223.JumpPower * (1.3 * shared.multipliers.RollBoostMultiplier)
			if shared.boosts.Roll then
				shared.boosts.Roll = {
					["Speed"] = v217,
					["Jump"] = 1.2 * shared.multipliers.RollBoostMultiplier,
				}
			end
			task.wait(v216 and 0.2 or 0.35)
			v_u_37:SetAttribute("ForceVector", nil)
			v_u_37.Value = false
			shared.boosts.Roll = nil
			v_u_6.ApplyCooldown("Roll")
			if v_u_6.IsKeybindDown("slide") then
				shared.boosts.SlideRollTransfer = shared.boosts.Roll
				SlideInput()
			end
		end
	end
	function StopSlide()
		-- upvalues: (copy) v_u_18, (ref) v_u_64, (copy) v_u_37, (copy) v_u_2, (ref) v_u_62, (copy) v_u_24, (copy) v_u_9
		shared.sliding = false
		v_u_18:SetAttribute("Sliding", false)
		v_u_64 = time() + 0.1
		v_u_37:SetAttribute("ForceVector", nil)
		v_u_37.Value = false
		v_u_2
			:Create(v_u_18.Slide, TweenInfo.new(0.75), {
				["Volume"] = 0,
			})
			:Play()
		task.spawn(function()
			-- upvalues: (ref) v_u_18
			task.wait(0.8)
			if v_u_18.Slide.Volume <= 0 then
				v_u_18.Slide:Pause()
			end
		end)
		v_u_62 = time() - 3
		shared.boosts.SlideRollTransfer = nil
		shared.boosts.Roll = nil
		v_u_24.HipHeight = 0
		v_u_9:Fire("Slide", 0.1)
	end
	function Slide()
		-- upvalues: (copy) v_u_6, (ref) v_u_62, (copy) v_u_18, (copy) v_u_2, (copy) v_u_37, (copy) v_u_24, (copy) v_u_8
		if shared.multipliers.DisableSliding then
			return
		elseif not v_u_6.InCooldown("Slide") then
			v_u_62 = time()
			shared.sliding = true
			v_u_18:SetAttribute("Sliding", true)
			v_u_18.Slide:Resume()
			v_u_2
				:Create(v_u_18.Slide, TweenInfo.new(0.5), {
					["Volume"] = 1,
				})
				:Play()
			v_u_37:SetAttribute("ForceVector", nil)
			v_u_37.Value = true
			v_u_24.HipHeight = 0.2
			v_u_8:Fire("Slide", 0.1)
			v_u_8:Fire("SlideEnter", 0.1)
			v_u_6.ApplyCooldown("Slide")
		end
	end
	function MoveUpdate(p224)
		-- upvalues: (ref) v_u_40, (copy) v_u_24, (copy) v_u_6, (ref) v_u_66, (ref) v_u_59, (copy) v_u_34, (ref) v_u_64, (copy) v_u_17, (ref) v_u_41, (copy) v_u_23, (ref) v_u_68, (ref) v_u_52, (copy) v_u_22, (copy) v_u_18, (ref) v_u_53, (ref) v_u_74, (copy) v_u_16, (copy) v_u_10, (ref) v_u_75, (ref) v_u_70, (ref) v_u_76, (ref) v_u_77, (ref) v_u_39, (ref) v_u_54, (ref) v_u_55, (ref) v_u_65, (ref) v_u_56, (ref) v_u_67, (ref) v_u_43, (ref) v_u_69, (ref) v_u_51, (copy) v_u_72, (ref) v_u_45, (ref) v_u_62, (ref) v_u_63, (ref) v_u_47, (ref) v_u_50, (copy) v_u_36, (copy) v_u_35, (ref) v_u_73, (ref) v_u_49, (ref) v_u_48, (copy) v_u_21, (ref) v_u_44, (ref) v_u_46, (copy) v_u_7, (ref) v_u_31, (ref) v_u_32, (copy) v_u_27, (copy) v_u_28, (copy) v_u_29, (copy) v_u_30, (ref) v_u_58, (ref) v_u_57
		if shared.multipliers.DisableAllUtgMovement or v_u_40 then
			return
		end
		if shared.playMode ~= nil then
			return
		end
		local v225 = v_u_24:GetState()
		local v226 = math.min(p224, 1) * 60
		local v227 = (v_u_6.IsKeybindDown("slide") or v_u_66)
			and not (shared.sliding or shared.multipliers.DisableCrouching)
		if v227 then
			if v_u_24.FloorMaterial == Enum.Material.Air then
				v227 = false
			else
				v227 = time() > v_u_59 + 1
			end
		end
		shared.crouching = v227
		local v228 = true
		if
			shared.options.Controls.SprintMode == 1 and v_u_6.IsKeybindDown("run")
			or shared.options.Controls.SprintMode == 2 and not v_u_6.IsKeybindDown("run")
		then
			v228 = false
		elseif shared.options.Controls.SprintMode == 3 and not shared.sprintToggle then
			v228 = false
		end
		local v229 = v_u_34.Value.Magnitude > 0.1
			and (
				(v_u_34.Value.Z < -0.25 or shared.multipliers.RunInAllDirections)
				and not shared.multipliers.DisableSprinting
			)
		if v229 then
			if v228 then
				v229 = not v227
			else
				v229 = shared.multipliers.DisableWalking
				if v229 then
					v229 = not v227
				end
			end
		end
		shared.sprinting = v229
		local v230 = 8 * shared.multipliers.WalkSpeedMultiplier
		local v231 = 16 * shared.multipliers.WalkSpeedMultiplier
		local v232 = 32 * shared.multipliers.RunSpeedMultiplier
		local v233 = 16 * shared.multipliers.JumpPowerMultiplier
		local v234 = 28 * shared.multipliers.JumpPowerMultiplier
		if shared.sliding or v_u_64 > time() then
			v233 = v233 * (0.925 * shared.multipliers.SlideJumpMultiplier)
			v234 = v234 * (0.925 * shared.multipliers.SlideJumpMultiplier)
		end
		if v227 then
			v231 = v230
		end
		local v235 = 1
		for v236, v237 in shared.boosts do
			local v238
			if v237 then
				v238 = v237.Role
			else
				v238 = v237
			end
			if not v238 or v_u_17.Value == v238 then
				for v239, v240 in v237 do
					if v239 == "Speed" then
						local v241 = math.max(v240, 0)
						v230 = v230 * v241
						v231 = v231 * v241
						v232 = v232 * v241
					elseif v239 == "Accel" then
						v235 = v235 * v240
					elseif v239 == "Jump" then
						v233 = v233 * v240
						v234 = v234 * v240
					elseif v239 == "Expire" and v240 < time() then
						shared.boosts[v236] = nil
					end
				end
			end
		end
		if v225 == Enum.HumanoidStateType.Climbing or shared.touchingTruss then
			v_u_41 = time() + 1
		end
		v_u_23.CanCollide = v_u_41 < time()
		v_u_24:SetStateEnabled(Enum.HumanoidStateType.Climbing, v_u_68 < time())
		local _ = v_u_68 > time()
		if v_u_52 then
			local v242 = v_u_22.AssemblyLinearVelocity.Magnitude / 48
			v_u_18.Zipline.Volume = math.clamp(v242, 0, 0.5)
			v_u_18.Zipline.PlaybackSpeed = math.clamp(v242, 0.9, 2) * 1.1
			if v_u_52.Parent then
				local v243 = v242 * 35
				local v244 = v242 >= 0.82
				local v245 = v242 >= 1.2
				local v246 = v242 >= 2
				local v247 = v_u_52.Parent
				local v248 = v247.AssemblyLinearVelocity
				local v249 = v_u_22.CFrame.LookVector
					* v_u_34.Value.Z
					* 600
					* (shared.multipliers.ZiplineMultiplier or 1)
				v247.AssemblyLinearVelocity = v248 + Vector3.new(0, 0, v249)
				if v246 ~= v_u_53 then
					v_u_53 = v246
					v_u_74.IgniteLight.Enabled = v_u_53
					v_u_74.IgniteLight:SetAttribute("Enabled", v_u_53)
					v_u_74["Ignite" .. 1].Enabled = v_u_53
					v_u_74["Ignite" .. 1]:SetAttribute("Enabled", v_u_53)
					v_u_74["Ignite" .. 2].Enabled = v_u_53
					v_u_74["Ignite" .. 2]:SetAttribute("Enabled", v_u_53)
					v_u_74["Ignite" .. 3].Enabled = v_u_53
					v_u_74["Ignite" .. 3]:SetAttribute("Enabled", v_u_53)
					if v_u_53 then
						if not v_u_16:GetAttribute("HasBadgeHighSpeedZip") then
							v_u_10:FireServer("HighSpeedZip")
						end
						v_u_6.ShakeCamera(18, 0.45)
						v_u_6.PlaySound("ZiplineIgnition", v_u_22, 0.1)
						v_u_74["Ignite" .. 1]:Emit(9)
						v_u_74["Ignite" .. 2]:Emit(9)
						v_u_74["Ignite" .. 3]:Emit(9)
					else
						v_u_6.PlaySound("ZiplineExtinguish", v_u_22, 0.1)
					end
				end
				v_u_74.Smoke.Enabled = v244
				v_u_74.Sparks.Enabled = v245
				v_u_74.Smoke.Rate = v243
				v_u_74.Sparks.Rate = v243
				v_u_74.Smoke:SetAttribute("Enabled", v244)
				v_u_74.Sparks:SetAttribute("Enabled", v245)
			end
			local v250 = v_u_6.InCooldown("Zipline")
			local v251 = v_u_75
			local v252 = v_u_6.Lerp
			local v253 = v_u_70 + 0.5 - time()
			v251.MaxForce = v252(3500, 10000, 1 - math.clamp(v253, 0, 1))
			if v_u_70 < time() then
				if (v250 and 12 or 6) < (v_u_76.WorldPosition - v_u_77.WorldPosition).Magnitude then
					ReleaseZipline()
				elseif
					v_u_52.CurrentPosition > v_u_52.UpperLimit - (v250 and 3 or 1)
					or v_u_52.CurrentPosition < (v250 and 3 or 1)
				then
					ReleaseZipline()
				end
			end
		end
		if v_u_34.Value.Magnitude > 0.1 then
			if not v_u_39 then
				local v254 = 0.0425 * shared.multipliers.MomentumDecay
				if v_u_24.FloorMaterial == Enum.Material.Air then
					v254 = 0.0375 * shared.multipliers.MomentumMidair
				end
				local v255 = 0.06 * shared.multipliers.FrictionDecay
				if v_u_24.FloorMaterial == Enum.Material.Air then
					v255 = 0.06 * shared.multipliers.FrictionMidair
				end
				local v256 = v_u_54 + -v254 * v226
				local v257 = 32 * shared.multipliers.MomentumMultiplier
				v_u_54 = math.clamp(v256, 0, v257)
				local v258 = v_u_55 + -v255 * v226
				v_u_55 = math.clamp(v258, 0, 16)
				if not shared.multipliers.DisableMomentum then
					v230 = v230 + v_u_54 * shared.multipliers.MomentumSpeed
					v231 = v231 + v_u_54 * shared.multipliers.MomentumSpeed
					v232 = v232 + v_u_54 * shared.multipliers.MomentumSpeed
				end
				if not shared.multipliers.DisableFriction then
					v230 = v230 + -(v_u_55 * shared.multipliers.FrictionSpeed)
					v231 = v231 + -(v_u_55 * shared.multipliers.FrictionSpeed)
					v232 = v232 + -(v_u_55 * shared.multipliers.FrictionSpeed)
				end
			end
			local v259 = v226 * 0.2 * shared.multipliers.AccelerationMultiplier * v235
			if v_u_24.FloorMaterial == Enum.Material.Air then
				if v229 then
					v230 = v231
					v231 = v232
				end
			elseif v229 or v231 < v_u_24.WalkSpeed then
				if not v229 then
					v259 = v226 * -0.5
				end
				v230 = v231
				v231 = v232
			end
			local v260 = v_u_24
			local v261 = v_u_24.WalkSpeed + v259
			local v262 = math.max(v231, v230)
			v260.WalkSpeed = math.clamp(v261, v230, v262)
			local v263 = v_u_24
			local v264 = v_u_24.JumpPower + v226 * 0.2
			v263.JumpPower = math.clamp(v264, v233, v234)
		else
			v_u_24.JumpPower = v233
			if v_u_24.FloorMaterial ~= Enum.Material.Air then
				v_u_24.WalkSpeed = v231
			end
			v_u_54 = 0
		end
		if shared.emoteData and not shared.emoteData.Unrestrictive then
			if not v_u_65 then
				ReleaseOpportunities(true)
			end
			v_u_24.WalkSpeed = shared.emoteData.WalkSpeed or 0
			v_u_24.JumpPower = shared.emoteData.JumpPower or 0
		end
		local v265 = shared.emoteData
		if v265 then
			v265 = not shared.emoteData.Unrestrictive
		end
		v_u_65 = v265
		if v_u_22.AssemblyLinearVelocity.Y < -5 then
			v_u_56 = v_u_22.AssemblyLinearVelocity.Y
		else
			v_u_56 = v_u_6.Lerp(v_u_56, v_u_22.AssemblyLinearVelocity.Y, v_u_6.DeltaLerp(4, p224))
		end
		if v_u_67 then
			local v266
			if v_u_67:GetAttribute("WindforceRelative") then
				v266 = v_u_67.CFrame:VectorToObjectSpace(v_u_67:GetAttribute("WindforceRelative") * v226)
			else
				v266 = v_u_67:GetAttribute("Windforce") * v226
			end
			local v267 = v_u_22
			v267.AssemblyLinearVelocity = v267.AssemblyLinearVelocity + v266
			if v_u_43 then
				local v268 = 0
				for _, v269 in v_u_43.Parent.Parent:GetDescendants() do
					if
						v269:IsA("BasePart") and (not v269.Anchored and (v269.Name ~= "Bottom" and v269.Name ~= "Top"))
					then
						v268 = v268 + 1
					end
				end
				if v268 > 0 then
					for _, v270 in v_u_43.Parent.Parent:GetDescendants() do
						if
							v270:IsA("BasePart")
							and (not v270.Anchored and (v270.Name ~= "Bottom" and v270.Name ~= "Top"))
						then
							v270.AssemblyLinearVelocity = v270.AssemblyLinearVelocity + v266
						end
					end
				end
			end
			if v_u_69 < time() then
				v_u_69 = time() + 0.25
				local v271 = nil
				for _, v272 in v_u_22:GetTouchingParts() do
					if v271 then
						break
					end
					if v272:GetAttribute("Windforce") or v272:GetAttribute("WindforceRelative") then
						v271 = true
					end
				end
				if not v271 then
					v_u_67 = nil
					shared.inWindzone = nil
				end
			end
		end
		if v_u_51 then
			local v273 = v_u_22
			local v274 = v_u_22.AssemblyLinearVelocity.X
			local v275 = v_u_22.AssemblyLinearVelocity.Y + v226 * 1
			local v276 = math.max(v275, -10)
			local v277 = v_u_22.AssemblyLinearVelocity.Z
			v273.AssemblyLinearVelocity = Vector3.new(v274, v276, v277)
			WallrunCheck(true)
		end
		workspace.Gravity = 75 * shared.multipliers.GravityMultiplier
		local v278 = Vector2.new(v_u_22.AssemblyLinearVelocity.X, v_u_22.AssemblyLinearVelocity.Z).Magnitude
		if v278 < 6.8 and not v_u_39 then
			v_u_54 = 0
		end
		shared.touchingTruss = false
		local v279 = v_u_22.AssemblyLinearVelocity.X
		local v280 = v_u_22.AssemblyLinearVelocity.Y * 2
		local v281 = v_u_22.AssemblyLinearVelocity.Z
		local v282 = Vector3.new(v279, v280, v281)
		local v283 = workspace:Raycast(v_u_22.CFrame.Position, v282.Unit * 10, v_u_72)
		if v283 then
			if v283.Instance:GetAttribute("CanBeBroken") or v283.Instance:GetAttribute("Smashable") then
				local v284 = v283.Instance
				local v285 = (v283.Position - v_u_22.Position).Magnitude
				local v286 = v_u_22.AssemblyLinearVelocity.Unit.Y
				if v285 < (math.abs(v286) > 0.75 and 3.5 or 2.5) then
					BreakGlass(v284, v283.Position, v283.Normal)
				end
			elseif
				v_u_45 < time()
				and (
					(v283.Position - v_u_22.Position).Magnitude < 2
					and (v283.Instance:GetAttribute("RopeGrab") and not v_u_43)
				)
			then
				GrabRope(v283)
			end
		end
		local v287 = workspace:Raycast(v_u_22.CFrame.Position, v_u_22.CFrame.LookVector * 4, v_u_72)
		if v287 and v287.Instance:IsA("TrussPart") then
			shared.touchingTruss = true
		end
		if shared.sliding then
			v_u_41 = time() + 1
			if
				v_u_62 + 3 * shared.multipliers.SlideLengthMultiplier < time()
					and not shared.multipliers.InfiniteSlides
				or (
					v_u_24.FloorMaterial == Enum.Material.Air and v_u_63 + 0.1 < time()
					or (v278 < 2 or shared.emoteData and not shared.emoteData.Unrestrictive)
				)
			then
				StopSlide()
			end
			local v288 = v_u_18.Slide
			local v289 = v278 / (32 * shared.multipliers.SlopesMultiplier)
			v288.PlaybackSpeed = math.clamp(v289, 1, 2.5)
			if shared.boosts.SlideRollTransfer then
				local v290 = shared.boosts.SlideRollTransfer
				v290.Speed = v290.Speed - v226 * 0.02
				if shared.boosts.SlideRollTransfer.Speed <= 1 then
					shared.boosts.SlideRollTransfer = nil
					shared.boosts.Roll = nil
				end
			end
			if not shared.boosts.SlideSlopeSpeed then
				shared.boosts.SlideSlopeSpeed = {
					["Speed"] = 1 * shared.multipliers.SlideSpeedMultiplier,
					["Accel"] = 1.5 * shared.multipliers.SlideSpeedMultiplier,
				}
			end
			if shared.slopeTilt then
				if shared.slopeTilt > 0 then
					v_u_24.HipHeight = shared.slopeTilt
				else
					v_u_24.HipHeight = shared.slopeTilt * 0.666
				end
				if shared.boosts.SlideSlopeSpeed and shared.boosts.SlideSlopeSpeed.Speed then
					local v291 = shared.slopeTilt
					local v292 = math.abs(v291) < 0.1 and 2 or 7.5
					if shared.slopeTilt < -0.1 then
						local v293 = shared.boosts.SlideSlopeSpeed
						local v294 = shared.boosts.SlideSlopeSpeed.Speed
							+ shared.slopeTilt
								* -0.025
								* v226
								* shared.multipliers.SlopesMultiplier
								* shared.multipliers.SlideSpeedMultiplier
						local v295 = 2.125 * shared.multipliers.SlideSpeedMultiplier
						v293.Speed = math.clamp(v294, 0.1, v295)
					else
						shared.boosts.SlideSlopeSpeed.Speed = v_u_6.Lerp(
							shared.boosts.SlideSlopeSpeed.Speed,
							(shared.slopeTilt * -1.75 + 1)
								* shared.multipliers.SlopesMultiplier
								* shared.multipliers.SlideSpeedMultiplier,
							v_u_6.DeltaLerp(v292, p224)
						)
					end
					shared.boosts.SlideSlopeSpeed.Accel = v_u_6.Lerp(
						shared.boosts.SlideSlopeSpeed.Speed,
						(shared.slopeTilt * -1.25 + 1.5)
							* shared.multipliers.SlopesMultiplier
							* shared.multipliers.SlideSpeedMultiplier,
						v_u_6.DeltaLerp(v292, p224)
					)
					if shared.boosts.SlideSlopeSpeed.Speed > 1.2 then
						v_u_62 = time() - 0.5
					end
				end
			else
				v_u_24.HipHeight = 0.2
				if shared.boosts.SlideSlopeSpeed then
					shared.boosts.SlideSlopeSpeed.Speed = v_u_6.Lerp(
						shared.boosts.SlideSlopeSpeed.Speed or 1,
						1 * shared.multipliers.SlideSpeedMultiplier,
						v_u_6.DeltaLerp(2, p224)
					)
				end
			end
		else
			v_u_24.HipHeight = 0
			if
				shared.boosts.SlideSlopeSpeed
				and (shared.boosts.SlideSlopeSpeed.Speed and shared.boosts.SlideSlopeSpeed.Speed > 1.2)
			then
				v_u_54 = v_u_54 + 5 * shared.multipliers.MomentumMultiplier
			end
			shared.boosts.SlideSlopeSpeed = nil
			if shared.boosts.SlideRollTransfer then
				shared.boosts.SlideRollTransfer = nil
				shared.boosts.Roll = nil
			end
		end
		local v296 = workspace:Raycast(v_u_22.CFrame.Position, v_u_22.CFrame.UpVector * -2.5, v_u_72)
		if v296 and (v296.Instance:GetAttribute("RailCollision") and (not v_u_47 and v_u_50 < time())) then
			AttachToRail(v296)
			if not shared.multipliers.DisableRailFling and time() - v_u_59 < 0.25 then
				ReleaseRail(true)
				RailFling()
			end
		end
		if v_u_47 and (v_u_75.Enabled and v_u_77.Parent == v_u_47) then
			local v297 = shared.freelookY or v_u_36.Value
			local v298 = CFrame.Angles
			local v299 = shared.freelookX or v_u_35.Value
			local v300 = v297 * v298(math.rad(v299), 0, 0)
			local v301 = v_u_18.RailGrind
			local v302 = v_u_22.AssemblyLinearVelocity.Magnitude / 48
			v301.Volume = math.clamp(v302, 0, 0.5)
			v_u_73.Sparks.Enabled = v_u_22.AssemblyLinearVelocity.Magnitude > 20
			v_u_73.Sparks:SetAttribute("Enabled", v_u_73.Sparks.Enabled)
			v_u_22.CFrame = (v_u_22.CFrame - v_u_22.CFrame.Position + v_u_77.WorldPosition)
				* CFrame.new(-v_u_76.Position)
			local v303 = v_u_47.Size.X > v_u_47.Size.Y and v_u_47.Size.X > v_u_47.Size.Z and "X"
				or (v_u_47.Size.Y > v_u_47.Size.X and v_u_47.Size.Y > v_u_47.Size.Z and "Y" or "Z")
			local v304 =
				CFrame.new(v_u_22.CFrame.Position, v_u_22.CFrame.Position + v300.LookVector * Vector3.new(1, 0, 1))
			v_u_49 = Ray.new(v_u_47.CFrame.Position + Vector3.new(0, 1, 0), v304.LookVector * 5)
			local v305 = v_u_47:GetChildren()
			local v306 = nil
			local v307 = nil
			for _, v308 in v305 do
				if v308:IsA("Attachment") and v_u_49.Unit == v_u_49.Unit then
					local v309 = v_u_49.Unit:Distance(v308.WorldPosition)
					if not v306 or v307 < v309 then
						v307 = v309
						v306 = v308
					end
				end
			end
			if v306 then
				local v310 =
					CFrame.new(v_u_22.CFrame.Position, v_u_22.CFrame.Position + v300.LookVector * Vector3.new(1, 0, 1))
				local v311 = CFrame.new(v_u_22.CFrame.Position, v306.WorldPosition)
				local _, v312, _ = (v310 * CFrame.new(
					v_u_22.CFrame.Position,
					v_u_22.CFrame.Position + v311.LookVector * Vector3.new(1, 0, 1)
				):Inverse()):ToOrientation()
				local v313 = math.deg(v312)
				local v314 = math.abs(v313) - 60
				local v315 = math.clamp(v314, 0, 90) / 90
				local v316 = v315 < 0.625 and 0 or v315
				local v317 = v316 * 1
				v_u_48 = v_u_6.Lerp(v_u_48, v317, v_u_6.DeltaLerp(v317 < v_u_48 and 13.33 or 5, p224))
				local v318 = v_u_47:FindFirstAncestorOfClass("Model")
						and v_u_47:FindFirstAncestorOfClass("Model"):GetAttribute("Speed")
					or 1
				local v319 = v_u_48 * 0.7 * shared.multipliers.RailGrindMultiplier * v318
				v_u_54 = v319 * 5 * shared.multipliers.MomentumMultiplier
				v_u_24.WalkSpeed = v232 + v_u_54
				v_u_22.AssemblyLinearVelocity = v_u_22.CFrame.LookVector * v_u_24.WalkSpeed * v316
				local v320 = v_u_77.WorldPosition
				if v303 == "X" then
					local _ = v306.Position.X < 0
					local v321 = v306.Position.X < 0 and 1 or -1
					local v322 = v_u_77
					local v323 = v322.Position
					local v324 = v319 * v321 * v226
					v322.Position = v323 + Vector3.new(v324, 0, 0)
				elseif v303 == "Y" then
					local _ = v306.Position.Y < 0
					local v325 = v306.Position.Y < 0 and 1 or -1
					local v326 = v_u_77
					local v327 = v326.Position
					local v328 = v319 * v325 * v226
					v326.Position = v327 + Vector3.new(0, v328, 0)
				else
					local _ = v306.Position.Z < 0
					local v329 = v306.Position.Z < 0 and 1 or -1
					local v330 = v_u_77
					local v331 = v330.Position
					local v332 = v319 * v329 * v226
					v330.Position = v331 + Vector3.new(0, 0, v332)
				end
				if v320.Y - 0.1 > v_u_77.WorldPosition.Y then
					v_u_48 = v_u_48 + v226 * 0.125
				end
				local v333 = false
				for _, v334 in v305 do
					if v334:IsA("Attachment") then
						local v335 = v334.Position[v303]
						local v336 = math.abs(v335)
						local v337 = v_u_77.Position[v303]
						if v336 < math.abs(v337) then
							v333 = true
						end
					end
				end
				if v333 and (v_u_47 and not v_u_47:GetAttribute("DoNotRelease")) then
					local v338 = RaycastParams.new()
					v338.CollisionGroup = "Player"
					v338.FilterDescendantsInstances = { v_u_18, v_u_21, v_u_47 }
					local v339 = false
					local v340 = CFrame.new(
						v_u_76.WorldPosition * Vector3.new(1, 0, 1),
						v_u_77.WorldPosition * Vector3.new(1, 0, 1)
					).LookVector
					local v341 = Ray.new(
						v_u_22.CFrame.Position + v340 * 1 + Vector3.new(0, 2.5, 0),
						v_u_22.CFrame.UpVector * -8.5
					)
					local v342 = workspace:Spherecast(
						v341.Origin == v341.Origin and v341.Origin or v_u_22.CFrame.Position + Vector3.new(0, 2.5, 0),
						2.5,
						v341.Direction == v341.Direction and v341.Direction or Vector3.new(0, 0, 0),
						v338
					)
					if v342 and (v342.Instance:GetAttribute("RailCollision") and v_u_50 < time()) then
						AttachToRail(v342, true)
					else
						v339 = true
					end
					if v339 then
						ReleaseRail()
					end
				end
			end
		end
		if v_u_43 and v_u_34.Value.Magnitude > 0.1 then
			local v343 = 0
			for _, v344 in v_u_43.Parent.Parent:GetDescendants() do
				if v344:IsA("BasePart") and (not v344.Anchored and (v344.Name ~= "Bottom" and v344.Name ~= "Top")) then
					v343 = v343 + 1
				end
			end
			if v343 > 0 then
				for _, v345 in v_u_43.Parent.Parent:GetDescendants() do
					if
						v345:IsA("BasePart") and (not v345.Anchored and (v345.Name ~= "Bottom" and v345.Name ~= "Top"))
					then
						v345.AssemblyLinearVelocity = v345.AssemblyLinearVelocity
							+ v_u_24.MoveDirection
								* 0.1125
								* v226
								* shared.multipliers.RopeSwingMultiplier
								/ v343 ^ 0.8
					end
				end
			end
			if v_u_44 then
				local v346 = (v_u_44 - v_u_22.CFrame.Position).Magnitude
				local v347 = (30 - v_u_22.AssemblyLinearVelocity.Magnitude) * 0.5
				if math.clamp(v347, 0.4, 1.5) * 15 < v346 and v_u_46 < time() then
					v_u_46 = time() + 1
					local v348 = v_u_7
					local v349 = v_u_22
					local v350 = (v_u_22.AssemblyLinearVelocity.Magnitude - 30) * 0.5
					v348:Fire("RopeStretches", v349, math.clamp(v350, 1, 3) * 0.25, true)
					v_u_44 = v_u_22.CFrame.Position
				end
			end
			if (v_u_76.WorldPosition - v_u_77.WorldPosition).Magnitude > 3 then
				ReleaseRope(true)
			end
		end
		local v351 = v_u_31 < time() and (v_u_32 + 1 / math.min(p224, 1)) / 2 or v_u_32
		if v_u_31 < time() then
			v_u_31 = time() + 1
		end
		v_u_27.PrintList.Visible = shared.options.Misc.DebugPrint
		v_u_27.TextLabel.Visible = shared.options.Misc.DebugMode
		v_u_28.Title.Text = string.format("%.0f", v278)
		v_u_29.Title.Text = v_u_28.Title.Text
		v_u_30.Title.Text = v_u_28.Title.Text
		v_u_30.Position = UDim2.fromScale(0.5, 0.9 + ((shared.toolbarLength or 0) > 1 and -0.08 or 0))
		if shared.options.Misc.DebugMode then
			local v352 = "debug:"
				.. "\n"
				.. "FPS: "
				.. string.format("%.2f", v351)
				.. "\n"
				.. "WalkSpeed: "
				.. string.format("%.2f", v_u_24.WalkSpeed)
				.. "\n"
				.. "JumpPower: "
				.. string.format("%.2f", v_u_24.JumpPower)
				.. "\n"
				.. "Velocity: "
				.. string.format("%.2f", v278)
				.. "\n"
				.. "falling speed: "
				.. string.format("%.2f", v_u_56)
				.. "\n"
				.. "momentum: "
				.. string.format("%.2f", v_u_54)
				.. "\n"
				.. "friction: "
				.. string.format("%.2f", v_u_55)
				.. "\n"
				.. "vault height: "
				.. string.format("%.2f", v_u_58)
				.. " studs"
				.. "\n"
				.. "roll ms: "
				.. string.format("%.2f", v_u_57)
				.. " ms"
				.. "\n"
				.. "thumbstick dist: "
				.. (shared.joystickDistanceLolAAAAAAA and string.format("%.0f", shared.joystickDistanceLolAAAAAAA) .. " px" or "N/A")
				.. "\n"
			v_u_27.TextLabel.Text = v352
		end
		v_u_32 = v351
	end
	function JumpRequest()
		-- upvalues: (ref) v_u_60, (ref) v_u_40, (copy) v_u_24, (ref) v_u_51, (ref) v_u_43, (copy) v_u_22, (copy) v_u_72, (copy) v_u_6, (ref) v_u_42, (ref) v_u_58, (ref) v_u_75, (ref) v_u_47
		if time() < v_u_60 then
			return
		elseif shared.emoteData and not shared.emoteData.Unrestrictive then
			return
		elseif shared.multipliers.DisableAllUtgMovement or v_u_40 then
			return
		elseif shared.playMode == nil then
			v_u_60 = time() + 0.1
			v_u_24.UseJumpPower = true
			local v353 = false
			if not (v_u_51 or v_u_43) then
				local v354 = nil
				local v355 = nil
				for v356 = 0.5, 2, 0.25 do
					if not v354 then
						v355 = Ray.new(
							v_u_22.Position + v_u_22.CFrame.LookVector * v356 + v_u_22.CFrame.UpVector * 2.75,
							-v_u_22.CFrame.UpVector * 3.25
						)
						v354 = workspace:Raycast(v355.Origin, v355.Direction, v_u_72)
					end
				end
				if shared.options.Misc.DebugRaycast then
					local v357 = v_u_6.DebugRaycast
					local v358
					if v355 then
						v358 = v355.Origin
					else
						v358 = v355
					end
					if v355 then
						v355 = v355.Direction
					end
					local v359
					if v354 then
						v359 = v354.Position
					else
						v359 = v354
					end
					v357(v358, v355, v359, Color3.new(1, 0, 1), 3)
				end
				if v354 then
					local v360 = Ray.new(
						v_u_22.Position + Vector3.new(0, 1.25, 0) - v_u_22.CFrame.LookVector * 2.5,
						v_u_22.CFrame.LookVector * 3
					)
					local v361 = workspace:Raycast(v360.Origin, v360.Direction, v_u_72)
					if shared.options.Misc.DebugRaycast then
						local v362 = v_u_6.DebugRaycast
						local v363 = v360.Origin
						local v364 = v360.Direction
						local v365
						if v361 then
							v365 = v361.Position
						else
							v365 = v361
						end
						v362(v363, v364, v365, Color3.new(1, 0, 0), 3)
					end
					if not v361 then
						if v354.Instance:GetAttribute("SwingBar") and not v_u_42 then
							DoSwing(v354)
							v353 = true
						elseif not v354.Instance:GetAttribute("NoClimb") then
							local v366 = true
							if shared.multipliers.FixVaultLadders then
								local v367 = Ray.new(
									v_u_22.Position + Vector3.new(0, 2.5, 0) - v_u_22.CFrame.LookVector * 1.25,
									v_u_22.CFrame.LookVector * 4
								)
								local v368 = workspace:Raycast(v367.Origin, v367.Direction, v_u_72)
								if shared.options.Misc.DebugRaycast then
									local v369 = v_u_6.DebugRaycast
									local v370 = v367.Origin
									local v371 = v367.Direction
									local v372
									if v368 then
										v372 = v368.Position
									else
										v372 = v368
									end
									v369(v370, v371, v372, Color3.new(1, 1, 0), 3)
								end
								if v368 then
									v366 = false
								end
							end
							if v366 then
								v353 = true
								local v373 = v354.Position.Y - v_u_22.Position.Y
								v_u_58 = math.abs(v373)
								local v374 = Vault
								local v375 = v354.Position.Y - v_u_22.Position.Y
								v374((math.abs(v375)))
							end
						end
					end
				end
			end
			if v_u_43 and v_u_75.Enabled then
				ReleaseRope()
			end
			if v_u_51 then
				ReleaseWallrun(true)
			elseif not v353 and (v_u_24.FloorMaterial == Enum.Material.Air and not v_u_6.InCooldown("Wallrun")) then
				WallrunCheck()
			end
			if shared.sliding then
				StopSlide()
			end
			if v_u_47 and v_u_75.Enabled then
				ReleaseRail()
			end
			AttachZipline()
		end
	end
	function FloorChanged()
		-- upvalues: (ref) v_u_71, (copy) v_u_24, (copy) v_u_3, (ref) v_u_56, (copy) v_u_7, (copy) v_u_22, (ref) v_u_61, (copy) v_u_6, (ref) v_u_63
		if v_u_71 == Enum.Material.Air and v_u_24.FloorMaterial ~= Enum.Material.Air then
			v_u_3.Sounds.FallLand.Volume = v_u_56 * -0.03125 + 1.25
			v_u_3.Sounds.FallLand.PlaybackSpeed = v_u_56 * -0.025
			if v_u_56 < -40 then
				v_u_7:Fire("FallLand", v_u_22, 0.15, true)
				local v376 = time() - v_u_61
				if v376 < 1.25 then
					Roll(v376)
				else
					local v377 = v_u_6.ShakeCamera
					local v378 = v_u_56 / 40
					v377(3, (math.abs(v378)))
				end
			else
				v_u_7:Fire("FallLand", v_u_22, 0.15, false)
				if v_u_56 < 0 then
					local v379 = v_u_6.ShakeCamera
					local v380 = v_u_56 / 55
					v379(2, (math.abs(v380)))
				end
			end
		end
		if v_u_24.FloorMaterial == Enum.Material.Air and shared.sliding then
			v_u_63 = time()
		end
		v_u_71 = v_u_24.FloorMaterial
	end
	function SlideInput()
		-- upvalues: (copy) v_u_24, (ref) v_u_61, (ref) v_u_54, (copy) v_u_37, (ref) v_u_62, (copy) v_u_34
		if not shared.emoteData or shared.emoteData.Unrestrictive then
			if v_u_24.FloorMaterial == Enum.Material.Air then
				v_u_61 = time()
			elseif shared.boosts.Roll then
				v_u_54 = 0
				v_u_37:SetAttribute("ForceVector", nil)
				v_u_37.Value = false
				shared.boosts.Roll = nil
			elseif shared.sliding then
				StopSlide()
			elseif v_u_62 + 3.5 < time() and (v_u_34.Value.Z < 0 and (shared.sprinting and not v_u_37.Value)) then
				Slide()
			end
			ReleaseOpportunities(true)
		end
	end
	function HumanoidJump()
		-- upvalues: (copy) v_u_24, (copy) v_u_6, (ref) v_u_54
		if v_u_24.FloorMaterial ~= Enum.Material.Air and not v_u_6.InCooldown("Jump") then
			v_u_6.ApplyCooldown("Jump")
			v_u_54 = v_u_54 - 0.66
		end
	end
	function InputBegan(p381, p382)
		-- upvalues: (copy) v_u_6
		if shared.keybinds then
			if shared.gamepadEnabled or not p382 then
				if v_u_6.IsKeybind(p381, "slide") then
					SlideInput()
					return
				end
				if v_u_6.IsKeybind(p381, "run") then
					shared.sprintToggle = not shared.sprintToggle
					return
				end
				if v_u_6.IsKeybind(p381, "toggle_debugvis") then
					local v383 = not shared.options.Misc.DebugMode
					v_u_6.GetEvent("UpdateOption"):Fire("DebugMode", v383)
					v_u_6.GetEvent("UpdateOption"):Fire("DebugRaycast", v383)
				end
			end
		end
	end
	function InputChanged(_, _) end
	function InputEnded(_, _) end
	function AddFriction(p384)
		-- upvalues: (ref) v_u_55
		if p384 then
			if p384 > 0 then
				v_u_55 = v_u_55 + p384
			end
		else
			return
		end
	end
	local v_u_385 = v_u_66
	local v_u_386 = v_u_67
	repeat
		task.wait()
	until shared.options
	local v_u_387 = nil
	v26.UTGButtons.SlideButton.InputBegan:connect(function(p388)
		-- upvalues: (ref) v_u_387, (ref) v_u_385
		if
			not v_u_387
			and (p388.UserInputType == Enum.UserInputType.Touch and p388.UserInputState == Enum.UserInputState.Begin)
		then
			SlideInput()
			v_u_387 = p388
			v_u_385 = true
		end
	end)
	v15.Event:Connect(AddFriction)
	v_u_6.GetEvent("SlideInput").Event:Connect(SlideInput)
	v26.UTGButtons.SlideButton.InputEnded:connect(function(p389)
		-- upvalues: (ref) v_u_387, (ref) v_u_385
		if p389 == v_u_387 then
			v_u_387 = nil
			v_u_385 = nil
		end
	end)
	v_u_22.Touched:Connect(function(p390)
		-- upvalues: (ref) v_u_386
		if p390:GetAttribute("Windforce") or p390:GetAttribute("WindforceRelative") then
			v_u_386 = p390
			shared.inWindzone = p390
		end
	end)
	v_u_22.TouchEnded:Connect(function(p391)
		-- upvalues: (copy) v_u_22, (ref) v_u_386
		if p391:GetAttribute("Windforce") or p391:GetAttribute("WindforceRelative") then
			local v392 = nil
			for _, v393 in v_u_22:GetTouchingParts() do
				if v392 then
					break
				end
				if v393:GetAttribute("Windforce") or v393:GetAttribute("WindforceRelative") then
					v392 = true
				end
			end
			if not v392 then
				v_u_386 = nil
				shared.inWindzone = nil
			end
		end
	end)
	v13.Event:Connect(JumpRequest)
	v12.Event:Connect(ReleaseOpportunities)
	v_u_24:GetPropertyChangedSignal("FloorMaterial"):Connect(FloorChanged)
	v_u_24.Jumping:Connect(HumanoidJump)
	v4.InputBegan:Connect(InputBegan)
	v4.InputChanged:Connect(InputChanged)
	v4.InputEnded:Connect(InputEnded)
	v1:BindToRenderStep("move update", Enum.RenderPriority.Input.Value + 1, MoveUpdate)
else
	v_u_16:Kick("cheating is bad")
end
