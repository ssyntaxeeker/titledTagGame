--!strict
--[[
    LeaderboardFunctions (Client)
    =============================
    Author: Sol (3693744006)
    Updated: 26/07/20

    Owns leaderboard visibility animation and smooth manual scrolling.
]]

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
local visibilityTween: Tween? = nil
local scrollTween: Tween? = nil
local scrollTargetY = 0
local visibilityVersion = 0

local OPEN_ANCHOR = Vector2.new(1, 0)
local CLOSED_ANCHOR = Vector2.new(0, 0)
local SCROLL_PIXELS_PER_WHEEL_STEP = 36

local function tween(obj: Instance, info: TweenInfo, props: { [string]: any }): Tween
	local createdTween = TweenService:Create(obj, info, props)
	createdTween:Play()
	return createdTween
end

function LeaderboardFunctions.GetUI()
	return LeaderboardUI, ScrollFrame
end

function LeaderboardFunctions.SetUIEnabled(b)
	LeaderboardUI.Enabled = b
end

function LeaderboardFunctions.ToggleListVisible()
	visible = not visible
	visibilityVersion += 1
	local version = visibilityVersion
	if visibilityTween then visibilityTween:Cancel() end

	if visible then
		ScrollFrame.Visible = true
		local maximumY = math.max(0, ScrollFrame.AbsoluteCanvasSize.Y - ScrollFrame.AbsoluteWindowSize.Y)
		scrollTargetY = math.clamp(ScrollFrame.CanvasPosition.Y, 0, maximumY)
		visibilityTween = tween(
			ScrollFrame,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ AnchorPoint = OPEN_ANCHOR }
		)
		return
	end

	visibilityTween = tween(
		ScrollFrame,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ AnchorPoint = CLOSED_ANCHOR }
	)
	visibilityTween.Completed:Once(function()
		if visibilityVersion == version and not visible then ScrollFrame.Visible = false end
	end)
end

function LeaderboardFunctions.Scroll(wheelDelta: number)
	if not visible or not ScrollFrame.Visible or wheelDelta == 0 then return end

	local maximumY = math.max(0, ScrollFrame.AbsoluteCanvasSize.Y - ScrollFrame.AbsoluteWindowSize.Y)
	scrollTargetY = math.clamp(scrollTargetY - wheelDelta * SCROLL_PIXELS_PER_WHEEL_STEP, 0, maximumY)
	if scrollTween then scrollTween:Cancel() end
	scrollTween = tween(
		ScrollFrame,
		TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CanvasPosition = Vector2.new(0, scrollTargetY) }
	)
end

function LeaderboardFunctions.Tween(obj, info, props)
	return tween(obj, info, props)
end

return LeaderboardFunctions
