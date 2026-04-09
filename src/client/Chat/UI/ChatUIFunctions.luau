local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChatConfig = require(ReplicatedStorage.Shared.Configs.ChatConfig)
local ChatLogicInterface = require(ReplicatedStorage.Modules.Chat.Logic.ChatLogicInterface)
local ChatUIInterface = require(ReplicatedStorage.Modules.Chat.UI.ChatUIInterface)
local Net = require(ReplicatedStorage.Packages.Net)

local Assets = ReplicatedStorage.Assets

local SendChatMessageRE = Net:RemoteEvent("SendChatMessage")

local localPlayer = Players.LocalPlayer

local ChatUIFunctions = {}

local messageLayoutOrder = 0

local function createMessageLabel(messageData, ctx)
	local newLabel = Assets.UI.Templates.MessageTemplate:Clone()

	newLabel.Text = ChatConfig.messageTextFormat(messageData, ctx)
	newLabel.Size = ctx.showSender and UDim2.new(1, -15, 0, 20) or UDim2.new(1, -30, 0, 20)

	newLabel.Parent = ChatUIInterface.UI.MainFrame.Messages

	return newLabel
end

local function getRenderContext(messageData, previousMessage)
	local ctx = {
		showSender = true,
	}

	if previousMessage then
		local sameSender = previousMessage.sender.UserId == messageData.sender.UserId
		local closeInTime = (messageData.time - previousMessage.time) < ChatConfig.maxTimeBetweenMessageGrouping

		if sameSender and closeInTime then ctx.showSender = false end
	end

	return ctx
end

local function updateScrollingFrame()
	local UI = ChatUIInterface.UI
	if not UI then return end

	local messagesFrame = UI.MainFrame.Messages

	task.wait()

	local uiListLayout = messagesFrame:FindFirstChildWhichIsA("UIListLayout")
	if not uiListLayout then return end

	local totalHeight = uiListLayout.AbsoluteContentSize.Y
	messagesFrame.CanvasSize = UDim2.fromOffset(0, totalHeight)
	messagesFrame.CanvasPosition = Vector2.new(0, math.max(0, totalHeight - messagesFrame.AbsoluteSize.Y))
end

function ChatUIFunctions.AddMessage(messageData)
	local UI = ChatUIInterface.UI
	if not UI then return end

	local channel = messageData.channel
	local previousMessage = nil
	local history = ChatLogicInterface.chatHistory[channel]
	if history and #history > 1 then previousMessage = history[#history - 1] end

	local ctx = getRenderContext(messageData, previousMessage)

	local messageLabel = createMessageLabel(messageData, ctx)
	messageLayoutOrder += 1
	messageLabel.LayoutOrder = messageLayoutOrder

	if messageData.mentions and table.find(messageData.mentions, localPlayer.UserId) then
		messageLabel.BackgroundColor3 = ChatConfig.mentionLabelBackgroundColor
		messageLabel.BackgroundTransparency = 0
	end

	messageLabel.Visible = true
	messageLabel:SetAttribute("MessageId", messageData.id)

	updateScrollingFrame()
end

function ChatUIFunctions.SendMessage(text)
	SendChatMessageRE:FireServer(text)
end

function ChatUIFunctions.ClearMessages()
	local UI = ChatUIInterface.UI
	if not UI then return end

	for _, textLabel in UI.MainFrame.Messages:GetChildren() do
		if not textLabel:IsA("TextLabel") then continue end

		textLabel:Destroy()
	end

	messageLayoutOrder = 0
end

function ChatUIFunctions.GetMessagesAmountInUI()
	local UI = ChatUIInterface.UI
	if not UI then return end

	local messagesAmount = 0

	for _, textLabel in UI.MainFrame.Messages:GetChildren() do
		if not textLabel:IsA("TextLabel") then continue end

		messagesAmount += 1
	end

	return messagesAmount
end

function ChatUIFunctions.RefreshUI(channelToRefresh)
	if channelToRefresh ~= ChatUIInterface.currentChannel then return end

	local UI = ChatUIInterface.UI
	if not UI then return end

	local messagesFrame = UI.MainFrame.Messages
	local history = ChatLogicInterface.chatHistory[channelToRefresh] or {}

	-- track existing message IDs in the UI
	local uiMessagesMap = {}
	for _, child in ipairs(messagesFrame:GetChildren()) do
		if child:IsA("TextLabel") and child:GetAttribute("MessageId") then uiMessagesMap[child:GetAttribute("MessageId")] = child end
	end

	-- remove UI messages that are no longer in history
	for messageId, uiLabel in pairs(uiMessagesMap) do
		local stillExists = false
		for _, messageData in ipairs(history) do
			if messageData.id == messageId then
				stillExists = true
				break
			end
		end
		if not stillExists then uiLabel:Destroy() end
	end

	-- add new messages that aren’t in UI yet
	for _, messageData in ipairs(history) do
		if not uiMessagesMap[messageData.id] then ChatUIFunctions.AddMessage(messageData) end
	end
end

return ChatUIFunctions
