--!strict
--[[
    BotTelemetryDashboard (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Reusable low-churn chart widgets for bot session telemetry. Line instances
    are allocated once and repositioned during throttled dashboard refreshes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotTelemetry = require(ReplicatedStorage.Modules.Bot.BotTelemetry)

type RDashboard = BotTelemetry.RDashboard

type RChart = {
	root: Frame,
	valueLabel: TextLabel,
	plot: Frame,
	segments: { Frame },
	color: Color3,
}

export type RView = {
	summary: TextLabel,
	actions: TextLabel,
	success: RChart,
	reward: RChart,
	tech: RChart,
	techSuccess: RChart,
	churn: RChart,
}

local BotTelemetryDashboard = {}
local MAXIMUM_POINTS = 60

local function label(parent: Instance, text: string, size: UDim2, position: UDim2): TextLabel
	local result = Instance.new("TextLabel")
	result.Size = size
	result.Position = position
	result.BackgroundTransparency = 1
	result.Text = text
	result.TextColor3 = Color3.fromRGB(210, 218, 230)
	result.TextXAlignment = Enum.TextXAlignment.Left
	result.TextYAlignment = Enum.TextYAlignment.Center
	result.TextSize = 10
	result.Font = Enum.Font.Code
	result.Parent = parent
	return result
end

local function chart(parent: Instance, title: string, order: number, color: Color3): RChart
	local root = Instance.new("Frame")
	root.Name = title:gsub("%W", "")
	root.LayoutOrder = order
	root.Size = UDim2.new(1, -12, 0, 92)
	root.BackgroundColor3 = Color3.fromRGB(27, 30, 35)
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.Parent = parent
	label(root, title, UDim2.new(0.65, -8, 0, 22), UDim2.fromOffset(8, 0))
	local valueLabel = label(root, "no data", UDim2.new(0.35, -8, 0, 22), UDim2.new(0.65, 0, 0, 0))
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.TextColor3 = color

	local plot = Instance.new("Frame")
	plot.Name = "Plot"
	plot.Position = UDim2.fromOffset(8, 24)
	plot.Size = UDim2.new(1, -16, 1, -32)
	plot.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
	plot.BorderSizePixel = 0
	plot.ClipsDescendants = true
	plot.Parent = root
	local middle = Instance.new("Frame")
	middle.Size = UDim2.new(1, 0, 0, 1)
	middle.Position = UDim2.new(0, 0, 0.5, 0)
	middle.BackgroundColor3 = Color3.fromRGB(55, 60, 68)
	middle.BorderSizePixel = 0
	middle.Parent = plot

	local segments: { Frame } = {}
	for index = 1, MAXIMUM_POINTS - 1 do
		local segment = Instance.new("Frame")
		segment.Name = `Line{index}`
		segment.AnchorPoint = Vector2.new(0.5, 0.5)
		segment.BackgroundColor3 = color
		segment.BorderSizePixel = 0
		segment.Visible = false
		segment.Parent = plot
		segments[index] = segment
	end
	return { root = root, valueLabel = valueLabel, plot = plot, segments = segments, color = color }
end

local function updateChart(
	info: RChart,
	values: { number },
	minimum: number?,
	maximum: number?,
	displayMultiplier: number?,
	suffix: string?
)
	local count = math.min(#values, MAXIMUM_POINTS)
	local startIndex = #values - count + 1
	local low = minimum or math.huge
	local high = maximum or -math.huge
	if minimum == nil or maximum == nil then
		for index = startIndex, #values do
			low = math.min(low, values[index])
			high = math.max(high, values[index])
		end
		if low == math.huge then low, high = 0, 1 end
		if minimum == nil and maximum == nil then
			local magnitude = math.max(1, math.abs(low), math.abs(high))
			low, high = -magnitude, magnitude
		else
			low = minimum or low
			high = maximum or high
		end
	end
	local width = math.max(1, info.plot.AbsoluteSize.X)
	local height = math.max(1, info.plot.AbsoluteSize.Y)
	for index, segment in info.segments do
		if index >= count then
			segment.Visible = false
			continue
		end
		local leftValue = values[startIndex + index - 1]
		local rightValue = values[startIndex + index]
		local leftAlpha = math.clamp((leftValue - low) / math.max(0.0001, high - low), 0, 1)
		local rightAlpha = math.clamp((rightValue - low) / math.max(0.0001, high - low), 0, 1)
		local left = Vector2.new((index - 1) / math.max(1, count - 1) * width, (1 - leftAlpha) * height)
		local right = Vector2.new(index / math.max(1, count - 1) * width, (1 - rightAlpha) * height)
		local delta = right - left
		segment.Position = UDim2.fromOffset((left.X + right.X) * 0.5, (left.Y + right.Y) * 0.5)
		segment.Size = UDim2.fromOffset(math.max(1, delta.Magnitude), 2)
		segment.Rotation = math.deg(math.atan2(delta.Y, delta.X))
		segment.Visible = true
	end
	local latest = if count > 0 then values[#values] else nil
	local displayedValue = if latest then latest * (displayMultiplier or 1) else nil
	info.valueLabel.Text = if displayedValue
		then `{math.floor(displayedValue * 10) / 10}{suffix or ""}`
		else "no data"
end

function BotTelemetryDashboard.create(parent: Instance, order: number): RView
	local summary = label(parent, "No telemetry yet.", UDim2.new(1, -12, 0, 78), UDim2.new())
	summary.Name = "TelemetrySummary"
	summary.LayoutOrder = order
	summary.BackgroundColor3 = Color3.fromRGB(27, 30, 35)
	summary.BackgroundTransparency = 0
	summary.TextYAlignment = Enum.TextYAlignment.Top
	summary.TextWrapped = true
	local actions = label(parent, "No completed transitions yet.", UDim2.new(1, -12, 0, 138), UDim2.new())
	actions.Name = "ActionResults"
	actions.LayoutOrder = order + 1
	actions.BackgroundColor3 = Color3.fromRGB(27, 30, 35)
	actions.BackgroundTransparency = 0
	actions.TextYAlignment = Enum.TextYAlignment.Top
	actions.TextWrapped = true
	return {
		summary = summary,
		actions = actions,
		success = chart(parent, "Transition success trend (0-100%)", order + 2, Color3.fromRGB(65, 210, 125)),
		reward = chart(parent, "Reward per completed edge", order + 3, Color3.fromRGB(255, 195, 55)),
		tech = chart(parent, "Non-walk tech share trend (0-100%)", order + 4, Color3.fromRGB(60, 175, 255)),
		techSuccess = chart(parent, "Tech success trend (0-100%)", order + 5, Color3.fromRGB(205, 105, 255)),
		churn = chart(parent, "Average replans + recoveries per bucket", order + 6, Color3.fromRGB(245, 85, 105)),
	}
end

function BotTelemetryDashboard.update(view: RView, info: RDashboard)
	view.summary.Text = info.summary
	view.actions.Text = info.actions
	updateChart(view.success, info.successRate, 0, 1, 100, "%")
	updateChart(view.reward, info.rewardPerAttempt, nil, nil, nil, nil)
	updateChart(view.tech, info.techShare, 0, 1, 100, "%")
	updateChart(view.techSuccess, info.techSuccessRate, 0, 1, 100, "%")
	local maximumChurn = 1
	for _, value in info.navigationChurn do maximumChurn = math.max(maximumChurn, value) end
	updateChart(view.churn, info.navigationChurn, 0, maximumChurn, nil, nil)
end

return table.freeze(BotTelemetryDashboard)
