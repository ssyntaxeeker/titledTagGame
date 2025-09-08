local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationManager = require(ReplicatedStorage.Modules.Animations.AnimationManager)
local CooldownManager = require(ReplicatedStorage.Vendor.CooldownManager)
local DebugConfig = require(ReplicatedStorage.Modules.Debug.DebugConfig)
local DebugFunctions = require(ReplicatedStorage.Modules.Debug.DebugFunctions)
local Net = require(ReplicatedStorage.Packages.Net)
local PlaySound = require(ReplicatedStorage.Modules.FX.PlaySound)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)

local Assets = ReplicatedStorage.Assets

local PlaySoundRE = Net:RemoteEvent("PlaySound")

local localPlayer = Players.LocalPlayer

return function(hitResult)
	if CooldownManager.getCooldown(localPlayer, "Swing") then return end
	if not hitResult then return end

	local character = localPlayer.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return end
	if humanoid.Health <= 0 then return end

	local swingPart = hitResult.Instance
	local originalCollide = swingPart.CanCollide

	local swingAnimation = AnimationManager.GetTrack(humanoid.Animator, Assets.Animations.Parkour.Swing)

	task.spawn(function()
		swingAnimation:Play()

		PlaySound("Swing", rootPart)
		PlaySoundRE:FireServer("Swing", rootPart)
	end)

	swingPart.CanCollide = false
	if swingPart.Parent:GetAttribute("SwingBar") then swingPart.Parent.CanCollide = false end

	local targetPos = hitResult.Position + Vector3.new(0, -1.5, 0)
	local backOffset = rootPart.CFrame.LookVector * -1
	local desiredPos = Vector3.new(rootPart.Position.X, targetPos.Y, rootPart.Position.Z)

	rootPart.CFrame = rootPart.CFrame:Lerp(CFrame.new(targetPos + backOffset), 0.5)
	rootPart.CFrame = rootPart.CFrame:Lerp(CFrame.new(desiredPos), 0.5)

	local bodyPos = Instance.new("BodyPosition")
	bodyPos.MaxForce = Vector3.new(700, 9000, 700)
	bodyPos.Position = targetPos
	bodyPos.Parent = rootPart

	local velocity = rootPart.AssemblyLinearVelocity
	local swingFactor = (math.clamp(-velocity.Y, 25, 80) / 25) ^ 0.7

	CooldownManager.modifyCooldown(localPlayer, "Swing", true, 0.6)

	task.spawn(function()
		if SettingsInterface.debug.showValues ~= true then return end

		local swingPrint = string.format("%.2f%% vps", swingFactor * 100)
		local swingColors = DebugConfig.DEBUG_SWING_COLOR
		DebugFunctions.Print(swingPrint, Color3.fromHSV(swingColors[1] + (swingFactor - 1 + 0.001) / 1.8 / 2, swingColors[2], swingColors[3]))
	end)

	local elapsed = 0

	repeat
		elapsed += task.wait()
	until elapsed >= 0.4

	if bodyPos then bodyPos:Destroy() end

	local moveDir
	if humanoid.MoveDirection.Magnitude <= 0.1 or not humanoid.MoveDirection then
		moveDir = rootPart.CFrame.LookVector
	else
		moveDir = humanoid.MoveDirection
	end

	rootPart.AssemblyLinearVelocity += moveDir * (swingFactor * 50)

	swingPart.CanCollide = originalCollide
	if swingPart.Parent:GetAttribute("SwingBar") then swingPart.Parent.CanCollide = originalCollide end
end
