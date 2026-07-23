local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationManager = require(ReplicatedStorage.Modules.Animations.AnimationManager)
local CharacterCollisionConfig = require(ReplicatedStorage.Shared.Configs.CharacterCollisionConfig)
local CharacterUtils = require(ReplicatedStorage.Vendor.CharacterUtils)
local CooldownManager = require(ReplicatedStorage.Vendor.CooldownManager)
local CrosshairFunctions = require(ReplicatedStorage.Modules.Cursor.CrosshairFunctions)
local DebugFunctions = require(ReplicatedStorage.Modules.Debug.DebugFunctions)
local KnockbackVelocity = require(ReplicatedStorage.Modules.FX.KnockbackVelocity)
local Net = require(ReplicatedStorage.Packages.Net)
local PlaySound = require(ReplicatedStorage.Modules.FX.PlaySound)

local Assets = ReplicatedStorage.Assets
local localPlayer = Players.LocalPlayer
local CLIENT_TAG_RANGE = 8

local TagRE = Net:RemoteEvent("Tag")
local BotTagRF = Net:RemoteFunction("BotTag")
local PlaySoundRE = Net:RemoteEvent("PlaySound")
local tagIndex = 1
local botNtbVersions: { [Model]: number } = {}

local TagFunctions = {}

local function getLocalBotTaggedEvent(): BindableEvent
	local existing = ReplicatedStorage:FindFirstChild("LocalBotTagged")
	if existing and existing:IsA("BindableEvent") then return existing end

	local event = Instance.new("BindableEvent")
	event.Name = "LocalBotTagged"
	event.Parent = ReplicatedStorage
	return event
end

local function getLocalBotFromHit(instance: Instance): Model?
	local botsFolder = workspace:FindFirstChild("Bots")
	if not botsFolder then return nil end

	local current: Instance? = instance
	while current and current ~= workspace do
		if current:IsA("Model") and current.Parent == botsFolder then
			return current
		end
		current = current.Parent
	end

	return nil
end

local function grantLocalBotNtb(bot: Model)
	bot:SetAttribute("NTBDurability", 3)
	botNtbVersions[bot] = (botNtbVersions[bot] or 0) + 1
	local version = botNtbVersions[bot]
	task.delay(3, function()
		if bot.Parent and botNtbVersions[bot] == version then bot:SetAttribute("NTBDurability", 0) end
	end)
end

local function stabilizeLocalBotAfterTag(bot: Model, rootPart: BasePart)
	for _, descendant in bot:GetDescendants() do
		if descendant:IsA("BasePart") then descendant.CanCollide = false end
	end

	task.delay(0.1, function()
		if not rootPart.Parent then return end

		rootPart.AssemblyAngularVelocity = Vector3.zero
		rootPart.AssemblyLinearVelocity = Vector3.zero
	end)

	task.delay(0.35, function()
		if not bot.Parent then return end

		for _, descendant in bot:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = CharacterCollisionConfig.collidablePartNames[descendant.Name] == true
			end
		end
		if rootPart.Parent then
			rootPart.AssemblyLinearVelocity = Vector3.zero
			rootPart.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end

function TagFunctions.Tag()
	if CooldownManager.getCooldown(localPlayer, "Tag") then return end

	local character = localPlayer.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	task.spawn(function()
		local tagCooldown = character:GetAttribute("TagCooldown") or 1
		CooldownManager.modifyCooldown(localPlayer, "Tag", true, tagCooldown)

		if tagIndex % 2 == 0 then tagIndex = 0 end
		tagIndex += 1

		local tagAnimation = AnimationManager.GetTrack(character.Humanoid.Animator, Assets.Animations.Player[`Tag{tagIndex}`])
		tagAnimation.Priority = Enum.AnimationPriority.Action3
		tagAnimation:Play()
		tagAnimation:AdjustSpeed(1 / tagCooldown)

		PlaySound("Tag", rootPart)
		PlaySoundRE:FireServer("Tag", rootPart)
		CrosshairFunctions.SetCooldown(tagCooldown)
	end)

	local camera = workspace.CurrentCamera
	local forward = camera.CFrame.LookVector
	local right = camera.CFrame.RightVector
	local up = camera.CFrame.UpVector

	local rayNumber = 9
	local circleRadius = 1
	local rangeMultiplier = character:GetAttribute("TagRangeMultiplier") or 1
	local hits = {}
	local visualsHit = {}
	local visualsMiss = {}
	local characters = { workspace:FindFirstChild("Map") }

	for _, ePlayer in Players:GetPlayers() do
		if ePlayer == localPlayer then continue end
		local eCharacter = ePlayer.Character
		if eCharacter then table.insert(characters, eCharacter) end
	end

	local botsFolder = workspace:FindFirstChild("Bots")
	if botsFolder then
		table.insert(characters, botsFolder)
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = characters
	rayParams.FilterType = Enum.RaycastFilterType.Include

	local direction = forward * rangeMultiplier * CLIENT_TAG_RANGE

	for i = 1, rayNumber do
		local angle = (i / rayNumber) * math.pi * 2
		local originOffset = right * math.cos(angle) * circleRadius + up * math.sin(angle) * circleRadius
		local origin = rootPart.Position + Vector3.new(0, 1.5, 0) + originOffset

		local raycastResult = workspace:Raycast(origin, direction, rayParams)
		if raycastResult then
			local instance = raycastResult.Instance
			if
				CharacterUtils.CheckIfInstanceIsPartOfCharacter(instance)
				or (not instance.Anchored or instance:GetAttribute("Taggable") or instance.Name == "Lamp")
			then
				table.insert(hits, { instance, raycastResult.Position })
				table.insert(visualsHit, function()
					DebugFunctions.VisualizeRaycast(origin, direction, Color3.fromRGB(255, 39, 39))
				end)
			else
				table.insert(visualsMiss, function()
					DebugFunctions.VisualizeRaycast(origin, direction, Color3.fromRGB(255, 39, 39))
				end)
			end
		else
			table.insert(visualsMiss, function()
				DebugFunctions.VisualizeRaycast(origin, direction, Color3.fromRGB(255, 39, 39))
			end)
		end
	end

	local verticalOffset = 1.5
	local sphereOrigin = rootPart.Position + Vector3.new(0, 1.5, 0)
	local spherecastResult = workspace:Spherecast(sphereOrigin, verticalOffset, direction, rayParams)

	if
		spherecastResult
		and (CharacterUtils.CheckIfInstanceIsPartOfCharacter(spherecastResult.Instance) or getLocalBotFromHit(spherecastResult.Instance))
	then
		table.insert(hits, { spherecastResult.Instance, spherecastResult.Position })
		table.insert(visualsHit, function()
			DebugFunctions.VisualizeSpherecast(sphereOrigin + direction, verticalOffset)
		end)
	else
		table.insert(visualsMiss, function()
			DebugFunctions.VisualizeSpherecast(sphereOrigin + direction, verticalOffset)
		end)
	end

	task.spawn(function()
		if #hits > 0 then
			for _, v in visualsHit do
				v()
			end
		else
			for _, v in visualsMiss do
				v()
			end
		end
	end)

	if #hits > 0 then
		local target = hits[1][1]
		local bot: Model? = nil
		for _, hit in hits do
			local hitBot = getLocalBotFromHit(hit[1])
			if hitBot then
				target = hit[1]
				bot = hitBot
				break
			end
		end

		if bot then
			local botRootPart = bot:FindFirstChild("HumanoidRootPart")
			local botRole = bot:GetAttribute("Role")
			if botRootPart and botRootPart:IsA("BasePart") and typeof(botRole) == "string" then
				local botDurability = bot:GetAttribute("NTBDurability")
				botDurability = if typeof(botDurability) == "number" then botDurability else 0
				if botDurability > 0 then
					bot:SetAttribute("NTBDurability", botDurability - 1)
					PlaySound(if botDurability - 1 == 0 then "NTBHitBreak" else "NTBHit", botRootPart)
					return
				end

				local success, result = pcall(function()
					return BotTagRF:InvokeServer("PlayerTaggedBot", botRole, botRootPart.Position)
				end)
				if success and typeof(result) == "table" and result.success == true then
					KnockbackVelocity.apply({
						targetRootPart = botRootPart,
						originPosition = rootPart.Position,
						sourceVelocity = rootPart.AssemblyLinearVelocity,
						sourceRightVector = rootPart.CFrame.RightVector,
						knockbackType = "LocalBotTag",
					})
					grantLocalBotNtb(bot)
					getLocalBotTaggedEvent():Fire(bot, result.botRole)
					stabilizeLocalBotAfterTag(bot, botRootPart)
				elseif success and typeof(result) == "table" then
					warn(`[TagFunctions] Local bot tag rejected: {tostring(result.reason)}`)
				elseif not success then
					warn(`[TagFunctions] Local bot tag failed: {tostring(result)}`)
				end
			else
				warn("[TagFunctions] Local bot tag hit has no root part or Role attribute.")
			end
			return
		end

		TagRE:FireServer(target)
	end
end

return TagFunctions
