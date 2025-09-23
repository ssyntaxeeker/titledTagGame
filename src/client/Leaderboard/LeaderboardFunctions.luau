local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Assets = ReplicatedStorage.Assets
local localPlayer = Players.LocalPlayer

local LeaderboardUI = Assets.UI.LeaderboardUI:Clone()
LeaderboardUI.Parent = localPlayer:WaitForChild("PlayerGui")

local ScrollFrame = LeaderboardUI.ScrollingFrame

local LeaderboardFunctions = {}

local visible = false

local function tween(obj, info, props)
	TweenService:Create(obj, info, props):Play()
end

function LeaderboardFunctions.GetUI()
	return LeaderboardUI, ScrollFrame
end

function LeaderboardFunctions.SetUIEnabled(b)
	LeaderboardUI.Enabled = b
end

function LeaderboardFunctions.ToggleListVisible()
	visible = not visible
	local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local anchorX = visible and 1 or 0
	tween(ScrollFrame, tweenInfo, { AnchorPoint = Vector2.new(anchorX, 0), Visible = visible })
	ScrollFrame.Visible = visible
end

function LeaderboardFunctions.Tween(obj, info, props)
	tween(obj, info, props)
end

return LeaderboardFunctions
