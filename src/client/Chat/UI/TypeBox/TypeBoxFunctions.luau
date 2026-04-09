local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ChatConfig = require(ReplicatedStorage.Shared.Configs.ChatConfig)
local ChatTypeCheckUtils = require(ReplicatedStorage.Shared.Utils.Chat.TypeCheckUtils)
local ChatUIInterface = require(ReplicatedStorage.Modules.Chat.UI.ChatUIInterface)
local Net = require(ReplicatedStorage.Packages.Net)
local TypeBoxTypeCheck = require(ReplicatedStorage.Modules.Chat.UI.TypeBox.TypeBoxTypeCheck)

local SendChatMessageRE = Net:RemoteEvent("SendChatMessage")

local TypeBoxFunctions = {}

local function getTypeBox()
	return ChatUIInterface.UI.MainFrame.TypeBoxFrame.TypeBox
end

function TypeBoxFunctions.SetTypingToggle(enabled)
	local UI = ChatUIInterface.UI
	if not UI then return end

	getTypeBox().TextEditable = enabled
end

function TypeBoxFunctions.LimitWordsToDictionary(enabled)
	ChatUIInterface.typingMode = enabled and 1 or 2
end

function TypeBoxFunctions.SetUpHighlightLabel(typeBox)
	local highlightLabel = typeBox.HighlightLabel

	highlightLabel.RichText = true
	highlightLabel.TextWrapped = true
	highlightLabel.BackgroundTransparency = 1

	highlightLabel.Text = typeBox.Text
	highlightLabel.TextSize = ChatConfig.chatTextSize
	highlightLabel.Font = typeBox.Font
	highlightLabel.TextXAlignment = typeBox.TextXAlignment
	highlightLabel.TextYAlignment = typeBox.TextYAlignment
end

function TypeBoxFunctions.SendMessage()
	local typeBox = getTypeBox()
	local text = typeBox.Text

	if text == "" then return end

	if ChatUIInterface.typingMode == 1 then
		local isMessageValid = TypeBoxTypeCheck.IsMessageValid(text)

		if not isMessageValid then
			warn(`Blocked invalid message`)
			return
		end
	end

	local mentions = ChatTypeCheckUtils.ExtractMentions(text)

	SendChatMessageRE:FireServer {
		text = text,
		channel = "Global",
		mentions = mentions,
	}

	typeBox.Text = ""
end

function TypeBoxFunctions.HookTypeBoxEvents(typeBox)
	local label = typeBox.HighlightLabel

	local function updateTypeBoxScrollingFrame()
		local scrollingFrame = typeBox.Parent
		if not scrollingFrame:IsA("ScrollingFrame") then return end

		task.wait()

		local textHeight = label.TextBounds.Y
		local padding = 5

		local requiredHeight = textHeight + padding
		local visibleHeight = scrollingFrame.AbsoluteWindowSize.Y

		local canvasHeight = math.max(requiredHeight, visibleHeight)

		scrollingFrame.CanvasSize = UDim2.fromOffset(0, canvasHeight)
		scrollingFrame.CanvasPosition = Vector2.new(0, math.max(0, canvasHeight - visibleHeight))
	end

	local function refresh()
		if typeBox.Text:match("^%s") then
			typeBox.Text = typeBox.Text:gsub("^%s+", "")
			return
		end

		local maxLength = ChatConfig.maxMessageLength
		typeBox.Text = typeBox.Text:sub(1, maxLength)

		label.Text = TypeBoxTypeCheck.BuildHighlightedText(typeBox.Text, typeBox.CursorPosition)
		updateTypeBoxScrollingFrame()
	end

	typeBox:GetPropertyChangedSignal("Text"):Connect(refresh)
	typeBox:GetPropertyChangedSignal("CursorPosition"):Connect(refresh)

	local storedText = typeBox.Text

	UserInputService.InputBegan:Connect(function(inputObject, gameProcessedEvent)
		if not gameProcessedEvent then return end
		if not typeBox:IsFocused() then return end
		if inputObject.KeyCode ~= Enum.KeyCode.Tab then return end

		-- couldn't find another way to make it not create a space
		storedText = typeBox.Text
		task.wait()
		typeBox.Text = storedText

		local completion = TypeBoxTypeCheck.GetAutocomplete(typeBox.Text, typeBox.CursorPosition)
		if not completion then return end

		local newText, newCursor = TypeBoxTypeCheck.ApplyAutocomplete(typeBox.Text, typeBox.CursorPosition, completion)
		typeBox.Text = newText
		typeBox.CursorPosition = newCursor
	end)

	typeBox.FocusLost:Connect(function(enterPressed)
		if not enterPressed then return end

		TypeBoxFunctions.SendMessage()
	end)
end

function TypeBoxFunctions.CaptureTypeBoxFocus()
	local typeBox = getTypeBox()

	typeBox:CaptureFocus()
end

return TypeBoxFunctions
