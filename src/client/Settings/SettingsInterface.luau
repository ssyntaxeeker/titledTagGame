local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

return {
	updateSignal = Signal.new(),

	gameplay = {
		moveCameraY = true,
		thirdPersonDistanceX = 0.3,
		thirdPersonDistanceZ = 0.7,
		cameraShake = false,
	},
	debug = {
		showValues = true,
		showRaycasts = false,
		showDebug = false,
	},
	display = {
		firstPersonTransparency = 0,
		roleChangeVisuals = 1,
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
		toggleSettings = Enum.KeyCode.M
	}
}
