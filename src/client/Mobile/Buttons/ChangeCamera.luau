local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Buttons = require(ReplicatedStorage.Modules.Mobile.Buttons)
local CameraInputs = require(ReplicatedStorage.Modules.Camera.CameraInputs)

local function changeCamera()
	CameraInputs.ChangeCameraPerspective.OnBegan()
end

return Buttons.Register("ChangeCamera", { OnBegan = changeCamera })
