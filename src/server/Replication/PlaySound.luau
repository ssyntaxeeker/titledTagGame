local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CooldownManager = require(ReplicatedStorage.Vendor.CooldownManager)
local Net = require(ReplicatedStorage.Packages.Net)

local PlaySoundRE = Net:RemoteEvent("PlaySound")

local allowedSounds = {
	"Vault",
	"Land",
	"Roll",
	"Swing",
	"WallJump",
	"Trampoline",
	"Tag",
	"TagHit",
	"RoleChange",
}

PlaySoundRE.OnServerEvent:Connect(function(player, soundName, ...)
	if not table.find(allowedSounds, soundName) or CooldownManager.getCooldown(player, soundName .. "Sound") then return end
	CooldownManager.modifyCooldown(player, soundName .. "Sound", true, 0.1)

	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer == player then continue end

		PlaySoundRE:FireClient(otherPlayer, soundName, ...)
	end
end)

return 0
