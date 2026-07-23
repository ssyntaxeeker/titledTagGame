local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Buttons = require(ReplicatedStorage.Modules.Mobile.Buttons)
local CameraInputs = require(ReplicatedStorage.Modules.Camera.CameraInputs)

local active = false

local function setActive(nextActive)
	if active == nextActive then return end
	active = nextActive
	if active then
		CameraInputs.UnlockCamera.OnBegan()
	else
		CameraInputs.UnlockCamera.OnEnded()
	end
end

return Buttons.Register("FreeLook", {
	OnBegan = function()
		setActive(true)
	end,
	OnEnded = function()
		setActive(false)
	end,
	OnDisabled = function()
		setActive(false)
	end,
})
