local Helpers = {}

function Helpers.waitForCharacter(player)
	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart")
	return character
end

function Helpers.setAnchored(player, anchored)
	local character = player.Character
	if not character then return end
	character:WaitForChild("HumanoidRootPart").Anchored = anchored
end

function Helpers.teleportPlayerToSpawnFacingNext(player, mySpawnCFrame, nextSpawnCFrame)
	local character = Helpers.waitForCharacter(player)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local direction = (nextSpawnCFrame.Position - mySpawnCFrame.Position).Unit
	hrp.CFrame = CFrame.new(mySpawnCFrame.Position, mySpawnCFrame.Position + direction)
end

return Helpers
