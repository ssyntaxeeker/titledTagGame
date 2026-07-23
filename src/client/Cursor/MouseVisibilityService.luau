--!strict
--[[
    MouseVisibilityService (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/22

    Coordinates mouse visibility between interactive UIs and the custom camera,
    enforcing active ownership after every other render update until every owner
    releases. Interactive UIs use Roblox's built-in cursor so a custom cursor
    asset cannot delay the first visible frame.
]]

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MouseVisibilityService = {}
local RENDER_STEP_NAME = "InteractiveMouseVisibility"
local owners: { [Instance]: RBXScriptConnection } = {}
local gameplayMouseIcon: string? = nil

local function applyMouseState(visible: boolean)
	if visible then
		UserInputService.MouseIcon = ""
	elseif gameplayMouseIcon ~= nil then
		UserInputService.MouseIcon = gameplayMouseIcon
	end
	UserInputService.MouseBehavior = if visible then Enum.MouseBehavior.Default else Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = visible
end

local function beginEnforcingVisibility()
	gameplayMouseIcon = UserInputService.MouseIcon
	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Last.Value, function()
		applyMouseState(true)
	end)
	applyMouseState(true)
end

local function release(owner: Instance)
	local connection = owners[owner]
	if not connection then return end

	owners[owner] = nil
	connection:Disconnect()

	if next(owners) == nil then
		RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
		applyMouseState(false)
		gameplayMouseIcon = nil
	end
end

-- @client
-- Marks whether an interactive UI currently needs a free, visible mouse.
function MouseVisibilityService.setVisible(owner: Instance, visible: boolean)
	if visible then
		if owners[owner] then return end

		assert(owner.Parent, "[MouseVisibilityService.setVisible] owner must be parented")
		local shouldBeginEnforcing = next(owners) == nil
		owners[owner] = owner.Destroying:Connect(function()
			release(owner)
		end)

		if shouldBeginEnforcing then
			beginEnforcingVisibility()
		else
			applyMouseState(true)
		end
		return
	end

	release(owner)
end

-- @client
-- Returns true while at least one interactive UI owns the mouse.
function MouseVisibilityService.shouldShowMouse(): boolean
	return next(owners) ~= nil
end

GuiService.MenuOpened:Connect(function()
	MouseVisibilityService.setVisible(script, true)
end)

GuiService.MenuClosed:Connect(function()
	MouseVisibilityService.setVisible(script, false)
end)

return table.freeze(MouseVisibilityService)
