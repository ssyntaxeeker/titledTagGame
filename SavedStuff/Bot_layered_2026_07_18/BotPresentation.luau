--!strict
--[[
    BotPresentation (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Owns bot spawning, role appearance, highlights, NBT visuals, and animation
    attachment. Gameplay planning never mutates presentation instances directly.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BotAnimator = require(ReplicatedStorage.Modules.Bot.BotAnimator)
local BotAudioController = require(ReplicatedStorage.Modules.Bot.BotAudioController)
local Config = require(ReplicatedStorage.Modules.Bot.BotNavigationConfig)
local Types = require(ReplicatedStorage.Modules.Bot.BotNavigationTypes)

type BotRole = Types.BotRole

local BotPresentation = {}

local ROLE_PART_NAMES = table.freeze({
	Torso = true,
	UpperTorso = true,
	LowerTorso = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
	LeftUpperLeg = true,
	LeftLowerLeg = true,
	LeftFoot = true,
	RightUpperLeg = true,
	RightLowerLeg = true,
	RightFoot = true,
})

function BotPresentation.getBotsFolder(): Folder
	local existing = Workspace:FindFirstChild("Bots")
	if existing and existing:IsA("Folder") then return existing end
	if existing then existing:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "Bots"
	folder.Parent = Workspace
	return folder
end

function BotPresentation.applyRole(bot: Model, role: BotRole)
	local roleModule = ReplicatedStorage.Shared.Configs.Roles:FindFirstChild(role)
	assert(roleModule and roleModule:IsA("ModuleScript"), `[BotPresentation.applyRole] missing {role} role config`)
	local roleInfo = require(roleModule)
	bot:SetAttribute("Role", role)
	bot.Name = `TrainingBot_{role}`

	for _, descendant in bot:GetDescendants() do
		if descendant:IsA("BasePart") and ROLE_PART_NAMES[descendant.Name] then descendant.Color = roleInfo.Color end
	end

	local oldHighlight = bot:FindFirstChild("BotRoleHighlight")
	if oldHighlight then oldHighlight:Destroy() end
	local highlight = Instance.new("Highlight")
	highlight.Name = "BotRoleHighlight"
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = roleInfo.Color
	highlight.FillTransparency = 0.5
	highlight.OutlineColor = roleInfo.Color
	highlight.OutlineTransparency = 0.25
	highlight.Parent = bot
end

function BotPresentation.applyNtb(bot: Model, seconds: number)
	local version = (bot:GetAttribute("NBTVersion") or 0) + 1
	bot:SetAttribute("NBTVersion", version)
	bot:SetAttribute("NTBDurability", 3)
	for _, child in bot:GetChildren() do
		if not child:IsA("BasePart") or child.Name == "HumanoidRootPart" then continue end
		local box = Instance.new("SelectionBox")
		box.Name = "BotNBT"
		box.Adornee = child
		box.Color3 = Color3.new(1, 1, 1)
		box.LineThickness = 0.09
		box.Parent = child
	end
	task.delay(seconds, function()
		if not bot.Parent or bot:GetAttribute("NBTVersion") ~= version then return end
		bot:SetAttribute("NTBDurability", 0)
		for _, descendant in bot:GetDescendants() do
			if descendant.Name == "BotNBT" then descendant:Destroy() end
		end
	end)
end

function BotPresentation.spawn(name: string, cframe: CFrame, role: BotRole): (Model, Humanoid, BasePart, () -> ())
	local player = Players.LocalPlayer
	local source = player.Character or player.CharacterAdded:Wait()
	source.Archivable = true
	local bot = source:Clone()
	bot.Name = name
	for _, descendant in bot:GetDescendants() do
		if descendant:IsA("LocalScript") or descendant:IsA("Script") then descendant:Destroy() end
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.Massless = descendant.Name ~= "HumanoidRootPart"
			descendant.CollisionGroup = "Bots"
			if descendant.Name == "HumanoidRootPart" or (descendant.Parent and descendant.Parent:IsA("Accessory")) then
				descendant.CanCollide = false
			end
		end
	end
	local humanoid = bot:FindFirstChildOfClass("Humanoid")
	local rootPart = bot:FindFirstChild("HumanoidRootPart")
	assert(humanoid, "[BotPresentation.spawn] cloned character has no Humanoid")
	assert(rootPart and rootPart:IsA("BasePart"), "[BotPresentation.spawn] cloned character has no HumanoidRootPart")
	humanoid.WalkSpeed = Config.botWalkSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.botJumpPower
	bot:PivotTo(cframe)
	bot.Parent = BotPresentation.getBotsFolder()
	BotPresentation.applyRole(bot, role)
	local cleanupAnimation = BotAnimator.attach(bot)
	local cleanupAudio = BotAudioController.attach(bot)
	return bot, humanoid, rootPart, function()
		cleanupAnimation()
		cleanupAudio()
	end
end

return table.freeze(BotPresentation)
