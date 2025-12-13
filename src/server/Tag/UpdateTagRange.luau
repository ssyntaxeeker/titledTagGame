local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local ClockInterface = require(ServerStorage.Modules.GameLogic.Clock.ClockInterface)

ClockInterface.updateTagRangeSignal:Connect(function()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character or character:GetAttribute("Role") ~= "Alone" then continue end

		task.spawn(function()
			local ping = player:GetNetworkPing() * 2000

			local clampedPing = math.clamp(ping, 80, 350)
			local multiplier = 1 + (clampedPing - 80) / (300 - 80) * (1.26 - 1)

			character:SetAttribute("TagRangeMultiplier", multiplier)
		end)
	end
end)

return 0
