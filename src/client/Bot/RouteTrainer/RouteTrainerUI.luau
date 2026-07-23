--!strict
--[[
    RouteTrainerUI (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/20

    Binds the editable StarterGui.RouteTrainerUI hierarchy created by the
    command-bar builder. This module does not construct the authored UI.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Modules.Bot.RouteTrainer.RouteTrainerConfig)
local MouseModalService = require(ReplicatedStorage.Modules.Bot.Analysis.MouseModalService)

local RouteTrainerUI = {}

local function assertChild(parent: Instance, name: string, className: string): any
	local child = parent:FindFirstChild(name)
	assert(child and child:IsA(className), `[RouteTrainerUI] {parent:GetFullName()}.{name} must be a {className}`)
	return child
end

local function invoke(status: TextLabel, callback: () -> (boolean, string))
	task.spawn(function()
		local success, message = callback()
		status.Text = message
		status.TextColor3 = if success then Color3.fromRGB(72, 211, 132) else Color3.fromRGB(255, 95, 95)
	end)
end

local function listButton(parent: Instance, text: string, callback: () -> (boolean, string), status: TextLabel): TextButton
	local value = Instance.new("TextButton")
	value.Size = UDim2.new(1, -6, 0, 30)
	value.BackgroundColor3 = Color3.fromRGB(45, 51, 59)
	value.BorderSizePixel = 0
	value.Font = Enum.Font.Code
	value.Text = text
	value.TextColor3 = Color3.fromRGB(232, 236, 242)
	value.TextSize = 11
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.Parent = parent
	value.Activated:Connect(function() invoke(status, callback) end)
	return value
end

function RouteTrainerUI.bind(runtime: any, launcherButton: TextButton?): ScreenGui
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("RouteTrainerUI")
	assert(gui and gui:IsA("ScreenGui"), "[RouteTrainerUI.bind] run docs/ROUTE_TRAINER_UI_COMMAND_BAR.luau in Studio first")
	local root = assertChild(gui, "Root", "Frame") :: Frame
	local templateRestore = assertChild(gui, "RestoreButton", "TextButton") :: TextButton
	local restore = launcherButton or templateRestore
	if launcherButton then templateRestore.Visible = false end
	local header = assertChild(root, "Header", "Frame") :: Frame
	local minimize = assertChild(header, "Minimize", "TextButton") :: TextButton
	local status = assertChild(root, "Status", "TextLabel") :: TextLabel
	local titleInput = assertChild(root, "RouteTitle", "TextBox") :: TextBox
	local controls = assertChild(root, "Controls", "Frame") :: Frame
	local deleteSelected = controls:FindFirstChild("DeleteSelected")
	assert(not deleteSelected or deleteSelected:IsA("TextButton"), "[RouteTrainerUI] Controls.DeleteSelected must be a TextButton")
	local attemptsList = assertChild(root, "AttemptsList", "ScrollingFrame") :: ScrollingFrame
	local routesList = assertChild(root, "RoutesList", "ScrollingFrame") :: ScrollingFrame
	local publishedAttempts = assertChild(root, "PublishedAttempts", "ScrollingFrame") :: ScrollingFrame
	local ratings = assertChild(root, "Ratings", "Frame") :: Frame
	local similarPrompt = assertChild(root, "SimilarPrompt", "Frame") :: Frame
	local similarText = assertChild(similarPrompt, "Message", "TextLabel") :: TextLabel
	local logFrame = assertChild(root, "LogFrame", "ScrollingFrame") :: ScrollingFrame
	local logs = assertChild(logFrame, "Logs", "TextLabel") :: TextLabel
	local responsiveScale = assertChild(root, "ResponsiveScale", "UIScale") :: UIScale

	gui.Enabled = true
	MouseModalService.acquire(gui)
	restore.Visible = false
	minimize.Activated:Connect(function() root.Visible = false restore.Visible = true end)
	restore.Activated:Connect(function() restore.Visible = false root.Visible = true end)
	titleInput:GetPropertyChangedSignal("Text"):Connect(function() runtime.setTitle(titleInput.Text) end)

	assertChild(controls, "StartAttempt", "TextButton").Activated:Connect(function()
		invoke(status, runtime.startAttempt)
	end)
	assertChild(controls, "Success", "TextButton").Activated:Connect(function()
		invoke(status, function() return runtime.finishAttempt(true) end)
	end)
	assertChild(controls, "Failure", "TextButton").Activated:Connect(function()
		invoke(status, function() return runtime.finishAttempt(false) end)
	end)
	assertChild(controls, "Publish", "TextButton").Activated:Connect(function()
		invoke(status, runtime.requestPublish)
	end)
	assertChild(controls, "Refresh", "TextButton").Activated:Connect(function()
		invoke(status, runtime.loadRoutes)
	end)
	if deleteSelected then
		(deleteSelected :: TextButton).Activated:Connect(function()
			invoke(status, runtime.deleteSelectedRoute)
		end)
	end
	assertChild(similarPrompt, "Preview", "TextButton").Activated:Connect(function()
		invoke(status, runtime.previewSelectedBest)
	end)
	assertChild(similarPrompt, "Merge", "TextButton").Activated:Connect(function()
		invoke(status, runtime.mergeSimilar)
	end)
	assertChild(similarPrompt, "Separate", "TextButton").Activated:Connect(function()
		invoke(status, runtime.publishSeparate)
	end)
	for rating = 1, 5 do
		assertChild(ratings, `Rate{rating}`, "TextButton").Activated:Connect(function()
			invoke(status, function() return runtime.rateSelected(rating) end)
		end)
	end

	local previousSignature = ""
	local wasRecording = false
	local elapsed = 0
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode == Config.startFinishKey then
			local info = runtime.getState()
			invoke(status, if info.recording then function() return runtime.finishAttempt(true) end else runtime.startAttempt)
		elseif input.KeyCode == Config.failureKey and runtime.getState().recording then
			invoke(status, function() return runtime.finishAttempt(false) end)
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 then return end
		elapsed = 0
		local viewport = if workspace.CurrentCamera then workspace.CurrentCamera.ViewportSize else Vector2.new(1920, 1080)
		responsiveScale.Scale = math.clamp(math.min((viewport.X - 24) / 900, (viewport.Y - 72) / 620), 0.58, 1)
		local info = runtime.getState()
		if info.recording and not wasRecording then
			root.Visible = false
			restore.Visible = true
		end
		wasRecording = info.recording
		if info.recording then
			restore.Text = `RECORDING | {Config.startFinishKey.Name} SUCCESS | {Config.failureKey.Name} FAIL`
			restore.Size = UDim2.fromOffset(270, 34)
			restore.Position = UDim2.new(1, -282, 0, 42)
		else
			restore.Text = `ROUTE TRAINER | {Config.startFinishKey.Name} START`
			restore.Size = UDim2.fromOffset(190, 34)
			restore.Position = UDim2.new(1, -202, 0, 42)
		end
		if not titleInput:IsFocused() and titleInput.Text ~= info.title then titleInput.Text = info.title end
		status.Text = if info.recording then "RECORDING ATTEMPT..." else info.status
		logs.Text = info.logs
		similarPrompt.Visible = info.similarRoute ~= nil
		if info.similarRoute then similarText.Text = `Similar to: {info.similarRoute.title}` end
		local selectedId = if info.selectedRoute then info.selectedRoute.id else ""
		if deleteSelected then
			local ownsSelected = info.selectedRoute ~= nil and info.selectedRoute.creatorId == Players.LocalPlayer.UserId
			(deleteSelected :: TextButton).Visible = ownsSelected
		end
		local publishedAttemptCount = if info.selectedRouteData and typeof(info.selectedRouteData.attempts) == "table"
			then #info.selectedRouteData.attempts
			else 0
		local signature = `{#info.attempts}:{#info.routes}:{selectedId}:{tostring(info.similarRoute)}:{publishedAttemptCount}`
		for index in info.best do signature ..= `:{index}` end
		for _, route in info.routes do signature ..= `:{route.id}:{route.updatedAt}:{route.rating}` end
		if signature == previousSignature then return end
		previousSignature = signature
		for _, child in attemptsList:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
		for index, attempt in info.attempts do
			local selected = info.best[index] == true
			listButton(attemptsList, `{if selected then "[BEST] " else ""}#{index} {if attempt.success then "SUCCESS" else "FAIL"} | {string.format("%.2f", attempt.duration)}s | {attempt.techCount} tech`, function()
				return runtime.previewAttempt(index)
			end, status)
			local select = listButton(attemptsList, `    Toggle best #{index}`, function() return runtime.toggleBest(index) end, status)
			select.Size = UDim2.new(0.62, -6, 0, 24)
			local delete = listButton(attemptsList, `    Delete #{index}`, function() return runtime.deleteAttempt(index) end, status)
			delete.Size = UDim2.new(0.38, -6, 0, 24)
		end
		for _, child in routesList:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
		for _, route in info.routes do
			local owned = if route.creatorId == Players.LocalPlayer.UserId then "[YOURS] " else ""
			listButton(routesList, `{if route.id == selectedId then "> " else ""}{owned}{route.title} by {route.creatorName} | {string.format("%.1f", route.rating)}/5 ({route.ratingCount}) | {route.successCount}/{route.attemptCount}`, function()
				return runtime.selectRoute(route.id)
			end, status)
		end
		for _, child in publishedAttempts:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
		local routeData = info.selectedRouteData
		if routeData and routeData.attempts then
			for index, attempt in routeData.attempts do
				listButton(publishedAttempts, `#{index} {if attempt.selected then "BEST" elseif attempt.success then "SUCCESS" else "FAIL"} | {string.format("%.2f", attempt.duration)}s`, function()
					return runtime.previewSelectedAttempt(index)
				end, status)
			end
		end
	end)
	return gui
end

return table.freeze(RouteTrainerUI)
