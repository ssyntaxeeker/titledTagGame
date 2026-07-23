--!strict
--[[
    BotPresentation (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Owns local bot models, role appearance, highlights, and lightweight
    locomotion animation. Navigation has no presentation responsibilities.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimationManager = require(ReplicatedStorage.Modules.Animations.AnimationManager)
local Config = require(ReplicatedStorage.Modules.Bot.BotConfig)
local Types = require(ReplicatedStorage.Modules.Bot.BotTypes)

type BotRole = Types.BotRole

local BotPresentation = {}
local COLORED_PARTS = table.freeze({
	Torso = true, UpperTorso = true, LowerTorso = true,
	["Left Leg"] = true, ["Right Leg"] = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
	RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
})

function BotPresentation.folder(): Folder
	local existing = Workspace:FindFirstChild("Bots")
	if existing and existing:IsA("Folder") then return existing end
	if existing then existing:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "Bots"
	folder.Parent = Workspace
	return folder
end

function BotPresentation.applyRole(bot: Model, role: BotRole)
	local module = ReplicatedStorage.Shared.Configs.Roles:FindFirstChild(role)
	assert(module and module:IsA("ModuleScript"), `[BotPresentation.applyRole] missing role {role}`)
	local info = require(module)
	bot:SetAttribute("Role", role)
	bot:SetAttribute("AccelerationRate", if role == "Tagger" then 14 else 12)
	bot:SetAttribute("DecelerationRate", if role == "Tagger" then 13 else 14)
	bot.Name = `TrainingBot_{role}`
	for _, descendant in bot:GetDescendants() do
		if descendant:IsA("BasePart") and COLORED_PARTS[descendant.Name] then descendant.Color = info.Color end
	end
	local old = bot:FindFirstChild("BotRoleHighlight")
	if old then old:Destroy() end
	local highlight = Instance.new("Highlight")
	highlight.Name = "BotRoleHighlight"
	highlight.FillColor = info.Color
	highlight.OutlineColor = info.Color
	highlight.FillTransparency = 0.55
	highlight.OutlineTransparency = 0.2
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = bot
end

function BotPresentation.applyNtb(bot: Model)
	bot:SetAttribute("NTBDurability", 3)
	local version = (bot:GetAttribute("NBTVersion") or 0) + 1
	bot:SetAttribute("NBTVersion", version)
	task.delay(3, function()
		if bot.Parent and bot:GetAttribute("NBTVersion") == version then bot:SetAttribute("NTBDurability", 0) end
	end)
end

local function attachAnimation(bot: Model, humanoid: Humanoid, root: BasePart): () -> ()
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local playerAnimations = ReplicatedStorage.Assets.Animations:FindFirstChild("Player")
	if not playerAnimations then return function() end end
	local runAsset = playerAnimations:FindFirstChild("Run")
	local idleAsset = playerAnimations:FindFirstChild("Idle")
	if not runAsset or not runAsset:IsA("Animation") or not idleAsset or not idleAsset:IsA("Animation") then
		return function() end
	end
	local runTrack = AnimationManager.GetTrack(animator, runAsset)
	local idleTrack = AnimationManager.GetTrack(animator, idleAsset)
	runTrack:Play(0.1)
	idleTrack:Play(0.1)
	runTrack:AdjustWeight(0.01)
	local connection = RunService.PreAnimation:Connect(function()
		if not bot.Parent then return end
		local speed = Vector2.new(root.AssemblyLinearVelocity.X, root.AssemblyLinearVelocity.Z).Magnitude
		runTrack:AdjustSpeed(math.max(0.1, speed / Config.walkSpeed))
		runTrack:AdjustWeight(if speed > 2 and not bot:GetAttribute("Sliding") then 1 else 0.01, 0.12)
		idleTrack:AdjustWeight(if speed <= 2 then 1 else 0.01, 0.12)
	end)
	return function()
		connection:Disconnect()
		runTrack:Stop(0.1)
		idleTrack:Stop(0.1)
	end
end

function BotPresentation.spawn(cframe: CFrame, role: BotRole): (Model, Humanoid, BasePart, () -> ())
	local source = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
	source.Archivable = true
	local bot = source:Clone()
	for _, descendant in bot:GetDescendants() do
		if descendant:IsA("LocalScript") or descendant:IsA("Script") then descendant:Destroy() end
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.Massless = descendant.Name ~= "HumanoidRootPart"
			descendant.CollisionGroup = "Bots"
			if descendant.Name == "HumanoidRootPart" or descendant:FindFirstAncestorOfClass("Accessory") then
				descendant.CanCollide = false
			end
		end
	end
	local humanoid = bot:FindFirstChildOfClass("Humanoid")
	local root = bot:FindFirstChild("HumanoidRootPart")
	assert(humanoid, "[BotPresentation.spawn] cloned character has no Humanoid")
	assert(root and root:IsA("BasePart"), "[BotPresentation.spawn] cloned character has no root")
	bot:SetAttribute("MinRunSpeed", 16)
	bot:SetAttribute("MaxRunSpeed", Config.walkSpeed)
	bot:SetAttribute("MinJumpPower", 16)
	bot:SetAttribute("MaxJumpPower", Config.jumpPower)
	bot:SetAttribute("RollboostJumpPower", 33.6)
	bot:SetAttribute("VaultMomentumMultiplier", 1)
	bot:SetAttribute("Momentum", 0)
	bot:SetAttribute("Friction", 0)
	bot:SetAttribute("ForwardHeld", true)
	humanoid.WalkSpeed = 16
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 16
	bot:PivotTo(cframe)
	bot.Parent = BotPresentation.folder()
	BotPresentation.applyRole(bot, role)
	local cleanupAnimation = attachAnimation(bot, humanoid, root)
	return bot, humanoid, root, cleanupAnimation
end

return table.freeze(BotPresentation)
