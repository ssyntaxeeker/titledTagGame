local config = {
	commandPrefix = "/",

	maxMessageLength = 100,
	maxTimeBetweenMessageGrouping = 30,

	maxChatHistoryMessages = 20,
	chatTextSize = 18,

	senderNameColor = "rgb(30,30,30)",

	validWordColor = "rgb(0,0,0)",
	invalidWordColor = "rgb(255,0,0)",
	ghostWordColor = "rgb(170,170,170)",
	mentionWordColor = "rgb(30,30,200)",

	mentionLabelBackgroundColor = Color3.fromRGB(252, 255, 99),
}

config.messageTextFormat = function(messageData, ctx)
	local text = messageData.message

	text = text:gsub("(@[%w_]+)", function(mention)
		return string.format('<font color="%s"><b>%s</b></font>', config.mentionWordColor, mention)
	end)

	if not ctx.showSender then return `	  {text}` end

	local senderText = string.format('<font color="%s"><b>%s</b></font>', config.senderNameColor, messageData.sender.Name)

	return string.format("%s: %s", senderText, text)
end

return config
