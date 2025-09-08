local GuiService = game:GetService("GuiService")

local LeaderboardFunctions = require(script.Parent.LeaderboardFunctions)
local _, _, ScrollFrame = LeaderboardFunctions.GetUI()

local function updateTransparency(alpha)
	for i = 1, #ScrollFrame:GetChildren() do
		local child = ScrollFrame:GetChildren()[i]
		if child:IsA("ImageLabel") or child:IsA("ImageButton") then
			local original = child:GetAttribute("OriginalTransparency") or child.ImageTransparency
			child:SetAttribute("OriginalTransparency", original)
			child.ImageTransparency = (1 - alpha) * 0 + alpha * original
		end
	end
end

GuiService:GetPropertyChangedSignal("PreferredTransparency"):Connect(function()
	updateTransparency(GuiService.PreferredTransparency)
end)

updateTransparency(GuiService.PreferredTransparency)

return {}
