local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Buttons = require(ReplicatedStorage.Modules.Mobile.Buttons)
local CameraInputs = require(ReplicatedStorage.Modules.Camera.CameraInputs)

local function stop()
	task.wait(0.1)
	CameraInputs.UnlockCamera.OnEnded()
end

local function start()
	CameraInputs.UnlockCamera.OnBegan()
end

return Buttons.Register("FreeLook", { OnBegan = start, OnEnded = stop })
