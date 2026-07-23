local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

return {
	updateSignal = Signal.new(),

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
		changeCameraPerspective = Enum.KeyCode.V,
		unlockCamera = Enum.UserInputType.MouseButton2,
		tag = Enum.UserInputType.MouseButton1,
		vaultAndSwing = Enum.KeyCode.Space,
		slideAndCrouch = Enum.KeyCode.C,
		roll = Enum.KeyCode.C,
		walk = Enum.KeyCode.LeftShift,
		toggleSettings = Enum.KeyCode.M,
		toggleMatchmaking = Enum.KeyCode.N,
	},
	mobile = {
		toggleLeaderboard = false,
	},
}
