local Players = game:GetService("Players")

local module = {}

local Profiles = {}
local Proxies = {}

module.PlayerDataTemplate = {
	Settings = {
		gameplay = {
			moveCameraY = true,
			thirdPersonDistanceX = 0.7,
			thirdPersonDistanceZ = 0.5,
			cameraShake = false,
			turn180OnFreeLook = false,
		},
		debug = {
			showValues = true,
			showRaycasts = false,
			showDebug = false,
			numericalprecision = false,
		},
		display = {
			firstPersonTransparency = 0,
			showRoleChangeText = 1,
			disableShadows = false,
			fov = 1,
			alwaysShowHP = false,
		},
		audio = {
			musicVolume = 0.5,
			parkourVolume = 1,
			effectsVolume = 0.7,
			tagVolume = 1,
			movementVolume = 0.7,
		},
		keybinds = {
			changeCameraPerspective = "Enum.KeyCode.V",
			unlockCamera = "Enum.UserInputType.MouseButton2",
			tag = "Enum.UserInputType.MouseButton1",
			vaultAndSwing = "Enum.KeyCode.Space",
			slideAndCrouch = "Enum.KeyCode.C",
			roll = "Enum.KeyCode.C",
			walk = "Enum.KeyCode.LeftShift",
			toggleSettings = "Enum.KeyCode.M",
			toggleMatchmaking = "Enum.KeyCode.N",
		},
		mobile = {
			toggleLeaderboard = false,
		},
	},
	BotTrainingData = {
		tagger = {
			versions = {},
			activeVersionId = nil,
		},
		runner = {
			versions = {},
			activeVersionId = nil,
		},
	},
}

function module.Create(profileStore, player)
	local profile = profileStore:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile ~= nil then
		profile:AddUserId(player.UserId)
		profile:Reconcile()

		profile.OnSessionEnd:Connect(function()
			Profiles[player] = nil
			Proxies[player] = nil
			player:Kick(`Profile Session End - Please rejoin`)
		end)

		if player.Parent == Players then
			Profiles[player] = profile

			local proxy = {}
			local data = profile.Data
			local mt = {}

			mt.__newindex = function(_, k, v)
				data[k] = v
				player:SetAttribute(k, v)
			end

			mt.__index = function(_, k)
				return data[k]
			end

			setmetatable(proxy, mt)

			Proxies[player] = proxy

			return profile
		else
			profile:EndSession()
			return
		end
	else
		player:Kick(`Profile Load Fail - Please rejoin`)
		return
	end
end

function module.ReturnProfile(player)
	return Profiles[player]
end

function module.ReturnProxy(player)
	return Proxies[player]
end

function module.AddDefaultData(key, value)
	module.PlayerDataTemplate[key] = value
end

return module
