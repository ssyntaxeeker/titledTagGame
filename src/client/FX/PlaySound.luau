local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Packages.Net)

local SoundAssets = ReplicatedStorage.Assets.Sounds

local PlaySoundRE = Net:RemoteEvent("PlaySound")

local function playSound(soundName, ...)
	if soundName == "Vault" then
		local rootPart, studs = unpack { ... }

		local VaultSound = SoundAssets.Vault:Clone()
		VaultSound.Parent = rootPart
		VaultSound.Effect.Octave = 0.047 * studs + 0.97

		VaultSound:Play()
		Debris:AddItem(VaultSound, 0.5)
	elseif soundName == "Land" then
		local rootPart, ALVelocityY = unpack { ... }

		local LandSound = SoundAssets.Land:Clone()
		LandSound.Parent = rootPart
		LandSound.Volume = ALVelocityY * -0.03125 + 1.25
		LandSound.PlaybackSpeed = ALVelocityY * -0.025

		LandSound:Play()
		Debris:AddItem(LandSound, 0.7)
	elseif soundName == "Roll" then
		local rootPart, ms = unpack { ... }

		local rollSoundName

		if ms > 100 then
			rollSoundName = "FailedRoll"
		elseif ms > 10 then
			rollSoundName = "GoodRoll"
		else
			rollSoundName = "PerfectRoll"
		end

		local RollSound = SoundAssets[rollSoundName]:Clone()
		RollSound.Parent = rootPart

		RollSound:Play()
		Debris:AddItem(RollSound, 0.7)
	elseif soundName == "Swing" then
		local rootPart = unpack { ... }

		local SwingSound = SoundAssets.Swing:Clone()
		SwingSound.Parent = rootPart

		SwingSound:Play()
		Debris:AddItem(SwingSound, 1)
	elseif soundName == "Trampoline" then
		local rootPart = unpack { ... }

		local BounceSound = SoundAssets.Trampoline[`Bounce{math.random(1, 3)}`]:Clone()
		BounceSound.Parent = rootPart

		BounceSound:Play()
		Debris:AddItem(BounceSound, 1)
	elseif soundName == "Tag" then
		local rootPart = unpack { ... }

		local TagSound = SoundAssets.Tag:Clone()
		TagSound.Parent = rootPart

		TagSound:Play()
		Debris:AddItem(TagSound, 1)
	elseif soundName == "TagHit" then
		local part = unpack { ... }

		local HitSound = SoundAssets.TagHit:Clone()
		HitSound.Parent = part

		HitSound:Play()
		Debris:AddItem(HitSound, 1)
	elseif soundName == "RoleChange" then
		local RoleSound = SoundAssets.RoleChange
		RoleSound:Play()
	end
end

PlaySoundRE.OnClientEvent:Connect(playSound)

return playSound
