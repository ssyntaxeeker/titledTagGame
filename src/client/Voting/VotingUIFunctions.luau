local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BrightenColor = require(ReplicatedStorage.Vendor.BrightenColor)
local MouseVisibilityService = require(ReplicatedStorage.Modules.Cursor.MouseVisibilityService)
local Net = require(ReplicatedStorage.Packages.Net)

local Assets = ReplicatedStorage.Assets

local VoteRE = Net:RemoteEvent("Vote")

local localPlayer = Players.LocalPlayer

local VotingUI = Assets.UI.VotingUI:Clone()
VotingUI.Parent = localPlayer:WaitForChild("PlayerGui")
VotingUI.Enabled = false

local showCardTweenInfo = TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local hideCardTweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local sizeChangeTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local clickChangeTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local VotingUIFunctions = {}

local lastClickedFrame
local activeRoundId = 0
local activeVoteType = "mode"

local function makeColorSequence(colors)
	local sequence = {}

	for i, color in colors do
		local position = (i - 1) / (#colors - 1)

		table.insert(sequence, ColorSequenceKeypoint.new(position, color))
	end

	return ColorSequence.new(sequence)
end

function VotingUIFunctions.CreateFrame(imageId, name, colors, mode)
	local newFrame = VotingUI.Frames.UIListLayout.Template:Clone()

	local main = newFrame.Main

	main.FrameName.Text = name
	main.FrameImage.Image = imageId
	main.Position = UDim2.fromScale(0.5, 4)
	main.Rotation = math.random(-18, 18)

	main.UIGradient.Color = makeColorSequence(colors)
	main.UIStroke.Color = BrightenColor(colors[1], 0.4)

	newFrame.Name = name
	newFrame.Visible = true
	newFrame.Parent = VotingUI.Frames

	newFrame:SetAttribute("Mode", mode)

	return newFrame
end

function VotingUIFunctions.GetUI()
	return VotingUI
end

function VotingUIFunctions.BeginSession(roundId, voteType)
	activeRoundId = roundId
	activeVoteType = voteType or "mode"
	lastClickedFrame = nil
	VotingUI.HideVoting.Visible = false
	for _, frame in VotingUI.Frames:GetChildren() do
		if frame:IsA("Frame") then frame:Destroy() end
	end
end

function VotingUIFunctions.IsSession(roundId)
	return activeRoundId == roundId
end

function VotingUIFunctions.EndSession(roundId)
	if activeRoundId ~= roundId then return false end
	activeRoundId = 0
	lastClickedFrame = nil
	VotingUI.HideVoting.Visible = false
	VotingUIFunctions.SetActive(false)
	for _, frame in VotingUI.Frames:GetChildren() do
		if frame:IsA("Frame") then frame:Destroy() end
	end
	return true
end

function VotingUIFunctions.SetActive(active)
	if active then
		MouseVisibilityService.setVisible(VotingUI, true)
		VotingUI.Enabled = true
	else
		VotingUI.Enabled = false
		MouseVisibilityService.setVisible(VotingUI, false)
	end
end

function VotingUIFunctions.ShowFrame(frame)
	TweenService:Create(frame.Main, showCardTweenInfo, { Position = UDim2.fromScale(0.5, 0.5), Rotation = math.random(-1.5, 1.5) }):Play()

	frame:SetAttribute("InUse", true)
end

function VotingUIFunctions.HideFrame(frame)
	frame:SetAttribute("InUse", false)

	local tween = TweenService:Create(frame.Main, hideCardTweenInfo, { Position = UDim2.fromScale(0.5, 4), Rotation = math.random(-18, 18) })

	tween.Completed:Connect(function(tweenStatus)
		if tweenStatus ~= Enum.PlaybackState.Completed then return end

		frame:Destroy()

		tween:Destroy()
	end)

	tween:Play()
end

function VotingUIFunctions.UpdateVotes(votesList)
	for modeName, amount in votesList do
		local frameName = modeName
		if activeVoteType == "mode" then
			local modeConfig = require(ReplicatedStorage.Shared.Configs.Modes[modeName])
			frameName = modeConfig.Name
		end
		local frame = VotingUI.Frames:FindFirstChild(frameName)
		if not frame then continue end

		frame.Main.VotesAmount.Text = amount
	end
end

function VotingUIFunctions.HookFrame(frame)
	frame.MouseEnter:Connect(function()
		if not frame:GetAttribute("InUse") then return end

		TweenService:Create(frame, sizeChangeTweenInfo, { Size = UDim2.new(1, 20, 1, 20) }):Play()
	end)

	frame.MouseLeave:Connect(function()
		if not frame:GetAttribute("InUse") then return end

		TweenService:Create(frame, sizeChangeTweenInfo, { Size = UDim2.fromScale(1, 1) }):Play()
	end)

	frame.Main.MouseButton1Down:Connect(function()
		if not frame:GetAttribute("InUse") then return end

		for _, currentFrame in VotingUI.Frames:GetChildren() do
			if not currentFrame:IsA("Frame") then continue end

			if currentFrame == frame then
				if lastClickedFrame == frame then
					TweenService:Create(currentFrame.Main, clickChangeTweenInfo, { Position = UDim2.fromScale(0.5, 0.5) }):Play()
					lastClickedFrame = nil

					VotingUI.HideVoting.Visible = false

					VoteRE:FireServer()
				else
					TweenService:Create(currentFrame.Main, clickChangeTweenInfo, { Position = UDim2.new(0.5, 0, 0.5, -50) }):Play()
					lastClickedFrame = currentFrame

					VotingUI.HideVoting.Visible = true

					VoteRE:FireServer(currentFrame:GetAttribute("Mode"))
				end
			else
				TweenService:Create(currentFrame.Main, clickChangeTweenInfo, { Position = UDim2.fromScale(0.5, 0.5) }):Play()
			end
		end
	end)
end

VotingUI.HideVoting.MouseButton1Click:Connect(function()
	VotingUI.HideVoting.Visible = false
	VotingUIFunctions.SetActive(false)

end)

return VotingUIFunctions
