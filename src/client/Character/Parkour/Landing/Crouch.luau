local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer

local Crouch = {}

function Crouch.Start()
	localPlayer.Character:SetAttribute("Crouching", true)
end

function Crouch.Stop()
	localPlayer.Character:SetAttribute("Crouching", false)
end

return Crouch
