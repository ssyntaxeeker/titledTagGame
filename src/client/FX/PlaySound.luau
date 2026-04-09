local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Packages.Net)

local SoundAssets = ReplicatedStorage.Assets.Sounds

local PlaySoundRE = Net:RemoteEvent("PlaySound")

local random = Random.new()

local function playSound(soundName, ...)
	if soundName == "Vault" then
		local rootPart, studs = unpack { ... }

		local VaultSound = (studs < 2.25 and SoundAssets.NormalVault or SoundAssets.HighVault):Clone()
		VaultSound.Parent = rootPart

		VaultSound.PlaybackSpeed += random:NextNumber(-0.2, 0.2)
		--VaultSound.Effect.Octave = 0.047 * studs + 0.97

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

		if ms > 200 then
			rollSoundName = "FailedRoll"
		elseif ms > 100 then
			rollSoundName = "normalroll"
		elseif ms > 10 then
			rollSoundName = "quickroll"
		else
			rollSoundName = "perfectroll"
		end

		local RollSound = SoundAssets[rollSoundName]:Clone()
		RollSound.Parent = rootPart

		RollSound.PlaybackSpeed += random:NextNumber(-0.1, 0.1)

		RollSound:Play()
		Debris:AddItem(RollSound, 0.7)
	elseif soundName == "Swing" then
		local rootPart = unpack { ... }

		local SwingSound = SoundAssets.Swing:Clone()
		SwingSound.Parent = rootPart

		SwingSound.PlaybackSpeed += random:NextNumber(-0.1, 0.1)

		SwingSound:Play()
		Debris:AddItem(SwingSound, 1)
	elseif soundName == "Trampoline" then
		local rootPart = unpack { ... }

		local BounceSound = SoundAssets.Trampoline[`Bounce{math.random(1, 3)}`]:Clone()
		BounceSound.Parent = rootPart

		BounceSound.PlaybackSpeed += random:NextNumber(-0.1, 0.1)

		BounceSound:Play()
		Debris:AddItem(BounceSound, 1)
	elseif soundName == "Tag" then
		local rootPart = unpack { ... }

		local TagSound = SoundAssets.Tag:Clone()
		TagSound.Parent = rootPart

		TagSound.PlaybackSpeed += random:NextNumber(-0.1, 0.1)

		TagSound:Play()
		Debris:AddItem(TagSound, 1)
	elseif soundName == "TagHit" then
		local part = unpack { ... }

		local HitSound = SoundAssets.TagHit:Clone()
		HitSound.Parent = part

		HitSound.PlaybackSpeed += random:NextNumber(-0.2, 0.2)

		HitSound:Play()
		Debris:AddItem(HitSound, 1)
	elseif soundName == "RoleChange" then
		local RoleSound = SoundAssets.RoleChange
		RoleSound:Play()
	elseif soundName == "NTBHit" then
		local rootPart = unpack { ... }

		local TagSound = SoundAssets.NoTagBackHit:Clone()
		TagSound.Parent = rootPart

		TagSound.PlaybackSpeed += random:NextNumber(-0.2, 0.2)

		TagSound:Play()
		Debris:AddItem(TagSound, 1)
	elseif soundName == "NTBHitBreak" then
		local rootPart = unpack { ... }

		local TagSound = SoundAssets.NoTagBackBreak:Clone()
		TagSound.Parent = rootPart

		TagSound.PlaybackSpeed += random:NextNumber(-0.2, 0.2)

		TagSound:Play()
		Debris:AddItem(TagSound, 1)
	end
end

PlaySoundRE.OnClientEvent:Connect(playSound)

return playSound
