local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Packages.Net)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local localPlayer = Players.LocalPlayer

local UpdateCameraRotationRE = Net:RemoteEvent("UpdateCameraRotation")

local updateRate = 1 / 20
local accumulated = 0
local HeadHorFactor = 0.8
local HeadVertFactor = 0.7
local UpdateSpeed = 0.7

local Dist, Diff
local Head, Torso, Neck, NeckOrgnC0

local function getMath()
	local camera = workspace.CurrentCamera
	Dist = (Head.Position - camera.CFrame.Position).Magnitude
	Diff = Head.Position.Y - camera.CFrame.Position.Y
end

local function updateHead()
	getMath()
	local HeadPosition = Head.Position
	local TorsoLookVector = Torso.CFrame.LookVector
	Neck.C0 = Neck.C0:Lerp(
		NeckOrgnC0
			* CFrame.Angles(
				-(math.asin(Diff / Dist) * HeadVertFactor),
				0,
				-(((HeadPosition - workspace.CurrentCamera.CFrame.Position).Unit):Cross(TorsoLookVector)).Y * HeadHorFactor
			),
		UpdateSpeed / 2
	)
end

local renderStepped

local function initCharacter(character)
	if renderStepped then renderStepped:Disconnect() end

	local humanoid = character:WaitForChild("Humanoid")
	Torso = character:WaitForChild("Torso")
	Head = character:WaitForChild("Head")
	Neck = Torso:WaitForChild("Neck")
	NeckOrgnC0 = Neck.C0

	if not humanoid or not Torso or not Head or not Neck then return end

	renderStepped = RunService.RenderStepped:Connect(function(deltaTime)
		accumulated += deltaTime
		updateHead()
		if accumulated >= updateRate then
			accumulated = 0
			UpdateCameraRotationRE:FireServer(Neck.C0, nil, nil, nil)
		end
	end)
end

local function init()
	localPlayer.CharacterAdded:Connect(initCharacter)
	if localPlayer.Character then initCharacter(localPlayer.Character) end
end

return Schedules.Boot.job(init)
