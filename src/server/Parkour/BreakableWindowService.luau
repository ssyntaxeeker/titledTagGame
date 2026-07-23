--!strict
--[[
    BreakableWindowService (Server)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/19

    Validates UTG window-smash requests and owns replicated break/reset state.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Packages.Net)
local ParkourAssetScope = require(ReplicatedStorage.Shared.Utils.ParkourAssetScope)

local BreakWindowRE = Net:RemoteEvent("BreakParkourWindow")
local broken: { [BasePart]: boolean } = {}

BreakWindowRE.OnServerEvent:Connect(function(player: Player, part: any, hitPosition: any, _normal: any)
	if not part or not part:IsA("BasePart") then return end
	if typeof(hitPosition) ~= "Vector3" then return end
	if part:GetAttribute("CanBeBroken") ~= true and part:GetAttribute("Smashable") ~= true then return end
	if broken[part] then return end
	local character = player.Character
	local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not rootPart or not rootPart:IsA("BasePart") then return end
	if (rootPart.Position - hitPosition).Magnitude > 6 then return end
	local velocity = rootPart.AssemblyLinearVelocity
	if velocity.Magnitude < 8 then return end
	if velocity.Unit:Dot((hitPosition - rootPart.Position).Unit) < 0.1 then return end
	if not ParkourAssetScope.contains(part) then return end

	broken[part] = true
	local originalTransparency = part.Transparency
	local originalCanCollide = part.CanCollide
	local originalCanQuery = part.CanQuery
	part:SetAttribute("Broken", true)
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	local resetTime = part:GetAttribute("ResetTime")
	task.delay(if typeof(resetTime) == "number" then math.clamp(resetTime, 0.5, 60) else 8, function()
		broken[part] = nil
		if not part.Parent then return end
		part.Transparency = originalTransparency
		part.CanCollide = originalCanCollide
		part.CanQuery = originalCanQuery
		part:SetAttribute("Broken", nil)
	end)
end)

return 0
