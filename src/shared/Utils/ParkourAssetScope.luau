--!strict
--[[
    ParkourAssetScope (Shared)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/19

    Defines the workspace roots allowed to provide parkour affordances in live
    maps and isolated development fixtures.
]]

local Workspace = game:GetService("Workspace")

local ParkourAssetScope = {}
local mapRoot = Workspace:FindFirstChild("Map")
local devRoot = Workspace:FindFirstChild("Dev")

Workspace.ChildAdded:Connect(function(child)
	if child.Name == "Map" then mapRoot = child end
	if child.Name == "Dev" then devRoot = child end
end)

Workspace.ChildRemoved:Connect(function(child)
	if child == mapRoot then mapRoot = nil end
	if child == devRoot then devRoot = nil end
end)

function ParkourAssetScope.contains(instance: Instance): boolean
	if mapRoot and instance:IsDescendantOf(mapRoot) then return true end
	return devRoot ~= nil and instance:IsDescendantOf(devRoot)
end

return table.freeze(ParkourAssetScope)
