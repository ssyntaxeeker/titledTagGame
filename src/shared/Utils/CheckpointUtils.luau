--!strict
--[[
    CheckpointUtils (Shared)
    ========================
    Author: Sol (3693744006)
    Updated: 26/07/19

    Resolves the ordered checkpoint contract consistently on both realms.
]]

local CollectionService = game:GetService("CollectionService")

local CheckpointUtils = {}

function CheckpointUtils.GetOrdered(map: Instance): { BasePart }
	local checkpoints = {}
	for _, instance in CollectionService:GetTagged("EscapeCheckpoint") do
		if instance:IsA("BasePart") and instance:IsDescendantOf(map) then table.insert(checkpoints, instance) end
	end
	if #checkpoints == 0 then
		local folder = map:FindFirstChild("Checkpoints")
		if folder then
			for _, instance in folder:GetDescendants() do
				if instance:IsA("BasePart") then table.insert(checkpoints, instance) end
			end
		end
	end
	if #checkpoints == 0 then
		for _, instance in map:GetDescendants() do
			if instance:IsA("SpawnLocation") then table.insert(checkpoints, instance) end
		end
	end

	table.sort(checkpoints, function(left, right)
		local leftOrder = tonumber(left:GetAttribute("Order")) or tonumber(left.Name) or math.huge
		local rightOrder = tonumber(right:GetAttribute("Order")) or tonumber(right.Name) or math.huge
		if leftOrder == rightOrder then return left:GetFullName() < right:GetFullName() end
		return leftOrder < rightOrder
	end)
	return checkpoints
end

return CheckpointUtils
