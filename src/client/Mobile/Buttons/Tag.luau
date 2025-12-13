local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Buttons = require(ReplicatedStorage.Modules.Mobile.Buttons)
local TagFunctions = require(ReplicatedStorage.Modules.Tag.TagFunctions)

local localPlayer = Players.LocalPlayer
local tagging = false
local tagLoopConnection
local lastTagTime = 0

local function getCooldown()
	local character = localPlayer.Character
	if not character then return 1 end
	return character:GetAttribute("TagCooldown") or 1
end

local function startTag()
	if tagging then return end
	tagging = true
	lastTagTime = 0

	tagLoopConnection = RunService.Heartbeat:Connect(function()
		if not tagging then return end

		local cooldown = getCooldown()
		local now = tick()

		if (now - lastTagTime) < cooldown then return end

		TagFunctions.Tag()
		lastTagTime = now + 0.1
	end)
end

local function stopTag()
	task.wait(0.1)

	tagging = false
	if tagLoopConnection then
		tagLoopConnection:Disconnect()
		tagLoopConnection = nil
	end
end

return Buttons.Register("Tag", { OnBegan = startTag, OnEnded = stopTag })
