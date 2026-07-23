--!strict
--[[
    MatchAnalysisVisuals (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/21

    Incrementally renders learned hotspots and top observed/predicted lines.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Modules.Bot.Analysis.MatchAnalysisConfig)
local Predictor = require(ReplicatedStorage.Modules.Bot.Analysis.MatchLinePredictor)
local Types = require(ReplicatedStorage.Modules.Bot.Analysis.MatchAnalysisTypes)

type RCandidate = Predictor.RCandidate
type RMemory = Types.RMemory
type ObservedRole = Types.ObservedRole

local MatchAnalysisVisuals = {}

local ACTION_COLORS = table.freeze({
	Run = Color3.fromRGB(235, 238, 242),
	Jump = Color3.fromRGB(70, 220, 105),
	Vault = Color3.fromRGB(35, 190, 255),
	Swing = Color3.fromRGB(255, 65, 210),
	Walljump = Color3.fromRGB(255, 95, 20),
	Wallrun = Color3.fromRGB(255, 140, 25),
	Zipline = Color3.fromRGB(35, 235, 220),
	Rail = Color3.fromRGB(20, 120, 255),
	Rope = Color3.fromRGB(215, 120, 35),
	Windforce = Color3.fromRGB(100, 255, 245),
	Crouch = Color3.fromRGB(150, 150, 160),
	Slide = Color3.fromRGB(130, 90, 255),
	Roll = Color3.fromRGB(255, 225, 35),
	SlideBoost = Color3.fromRGB(255, 55, 55),
	RollBoost = Color3.fromRGB(180, 255, 45),
	Tramp = Color3.fromRGB(255, 40, 145),
	Trampoline = Color3.fromRGB(20, 255, 150),
	Drop = Color3.fromRGB(170, 175, 185),
	UnknownTech = Color3.fromRGB(255, 255, 255),
})

local function part(folder: Folder, position: Vector3, color: Color3, size: number): BasePart
	local value = Instance.new("Part")
	value.Shape = Enum.PartType.Ball
	value.Size = Vector3.one * size
	value.Position = position
	value.Color = color
	value.Material = Enum.Material.Neon
	value.Transparency = 0.2
	value.Anchored = true
	value.CanCollide = false
	value.CanQuery = false
	value.CanTouch = false
	value.Parent = folder
	return value
end

local function beam(folder: Folder, from: BasePart, to: BasePart, color: Color3, width: number)
	local fromAttachment = Instance.new("Attachment")
	fromAttachment.Parent = from
	local toAttachment = Instance.new("Attachment")
	toAttachment.Parent = to
	local value = Instance.new("Beam")
	value.Attachment0 = fromAttachment
	value.Attachment1 = toAttachment
	value.Color = ColorSequence.new(color)
	value.Width0 = width
	value.Width1 = width
	value.LightEmission = 1
	value.FaceCamera = true
	value.Parent = folder
end

local function label(adornee: BasePart, text: string, color: Color3)
	local billboard = Instance.new("BillboardGui")
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 220
	billboard.Size = UDim2.fromOffset(170, 22)
	billboard.StudsOffsetWorldSpace = Vector3.yAxis * 1.3
	billboard.Adornee = adornee
	billboard.Parent = adornee
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.Font = Enum.Font.Code
	textLabel.TextSize = 11
	textLabel.TextColor3 = color
	textLabel.TextStrokeTransparency = 0.2
	textLabel.Text = text
	textLabel.Parent = billboard
end

local function cellPosition(key: string): Vector3?
	local x, y, z = string.match(key, "^(-?%d+):(-?%d+):(-?%d+)$")
	if not x or not y or not z then return nil end
	return Vector3.new(
		(tonumber(x) :: number) * Config.cellSize + Config.cellSize * 0.5,
		(tonumber(y) :: number) * Config.cellSize + Config.cellSize * 0.5,
		(tonumber(z) :: number) * Config.cellSize + Config.cellSize * 0.5
	)
end

local function renderCandidate(
	folder: Folder,
	candidate: RCandidate,
	index: number,
	detailed: boolean,
	generation: number,
	title: string?
)
	local color = if candidate.kind == "Authored"
		then Color3.fromRGB(70, 235, 145)
		elseif candidate.kind == "Observed"
		then (if candidate.role == "Runner" then Color3.fromRGB(45, 170, 255) else Color3.fromRGB(255, 65, 65))
		else Color3.fromRGB(255, 205, 40)
	local previous: BasePart? = nil
	local previousAction = ""
	for pointIndex, position in candidate.points do
		if not folder.Parent or folder:GetAttribute("RenderGeneration") ~= generation then return end
		local action = candidate.actions[pointIndex] or "Run"
		local segmentColor = if detailed then ACTION_COLORS[action] or color else color
		local marker = part(folder, position + Vector3.yAxis * (math.min(index, 3) * 0.08), color, if pointIndex == 1 then 0.65 else 0.35)
		if previous then beam(folder, previous, marker, segmentColor, if index == 1 then 0.18 else 0.09) end
		if pointIndex == 1 then
			local catchText = if (candidate.uses or 0) > 0
				then ` | caught {candidate.catches or 0}/{candidate.uses or 0}`
				else ""
			local routePrefix = if candidate.continuation then "UP NEXT" else `ROUTE #{index}`
			local opponentLabel = if candidate.role == "Runner" then "clear" else "intercept"
			local opponentText = if candidate.closestOpponentDistance
				then ` | {opponentLabel} {string.format("%.1f", candidate.closestOpponentDistance)}`
				else ""
			local routeLabel = if title then title elseif detailed
				then `{routePrefix} | {candidate.title or string.upper(candidate.verdict)} | gain {string.format("%+.1f", candidate.tacticalGain or 0)}{opponentText} | conf {string.format("%.0f%%", candidate.confidence * 100)}{catchText}`
				else `{candidate.kind} {candidate.role} #{index} | {string.format("%.1f", candidate.score)}`
			label(marker, routeLabel, color)
		elseif detailed and action ~= "Run" and action ~= previousAction then
			label(marker, action, segmentColor)
		end
		previous = marker
		previousAction = action
		if pointIndex % 12 == 0 then RunService.Heartbeat:Wait() end
	end
end

function MatchAnalysisVisuals.create(): Folder
	local old = workspace:FindFirstChild("MatchAnalysisDebug")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "MatchAnalysisDebug"
	folder:SetAttribute("RenderGeneration", 0)
	folder.Parent = workspace
	return folder
end

function MatchAnalysisVisuals.updateRecommendations(folder: Folder, candidates: { RCandidate })
	local generation = (folder:GetAttribute("RenderGeneration") or 0) + 1
	folder:SetAttribute("RenderGeneration", generation)
	folder:ClearAllChildren()
	task.spawn(function()
		for index, candidate in candidates do
			if not folder.Parent or folder:GetAttribute("RenderGeneration") ~= generation then return end
			renderCandidate(folder, candidate, index, true, generation, nil)
			RunService.Heartbeat:Wait()
		end
	end)
end

function MatchAnalysisVisuals.render(memory: RMemory, candidates: { RCandidate }): Folder
	local folder = MatchAnalysisVisuals.create()
	local generation = folder:GetAttribute("RenderGeneration") or 0
	task.spawn(function()
		local zones = {}
		for key, info in memory.zones do zones[#zones + 1] = { key = key, samples = tonumber(info.samples) or 0, techs = tonumber(info.techs) or 0 } end
		table.sort(zones, function(a, b) return a.samples > b.samples end)
		for index = 1, math.min(#zones, Config.visualMaximumHotspots) do
			if not folder.Parent then return end
			local info = zones[index]
			local position = cellPosition(info.key)
			if position then
				local ratio = math.clamp(info.techs / math.max(info.samples, 1) * 6, 0, 1)
				part(folder, position, Color3.fromRGB(255, 150 + 80 * ratio, 30), 0.3 + math.min(info.samples, 300) / 300)
			end
			if index % 30 == 0 then RunService.Heartbeat:Wait() end
		end
		for index = 1, math.min(#candidates, Config.visualMaximumLines) do
			renderCandidate(folder, candidates[index], index, false, generation, nil)
			RunService.Heartbeat:Wait()
		end
	end)
	return folder
end

function MatchAnalysisVisuals.renderFull(memory: RMemory): Folder
	local folder = MatchAnalysisVisuals.create()
	local generation = folder:GetAttribute("RenderGeneration") or 0
	task.spawn(function()
		local zoneCount = 0
		for key, info in memory.zones do
			if not folder.Parent or folder:GetAttribute("RenderGeneration") ~= generation then return end
			local position = cellPosition(key)
			if position then
				local samples = tonumber(info.samples) or 0
				local techs = tonumber(info.techs) or 0
				local ratio = math.clamp(techs / math.max(samples, 1) * 6, 0, 1)
				part(folder, position, Color3.fromRGB(255, 150 + 80 * ratio, 30), 0.28)
			end
			zoneCount += 1
			if zoneCount % 40 == 0 then RunService.Heartbeat:Wait() end
		end

		for index, observation in memory.techObservations or {} do
			if not folder.Parent or folder:GetAttribute("RenderGeneration") ~= generation then return end
			local position = observation.position
			if typeof(position) == "table" and #position >= 3 then
				local action = tostring(observation.action or "UnknownTech")
				local color = ACTION_COLORS[action] or ACTION_COLORS.UnknownTech
				local marker = part(folder, Vector3.new(position[1], position[2], position[3]), color, 0.5)
				label(marker, `{action} | v{string.format("%.1f", tonumber(observation.postSpeed) or 0)} | adv {string.format("%+.1f", tonumber(observation.advantage) or 0)}`, color)
			end
			if index % 24 == 0 then RunService.Heartbeat:Wait() end
		end

		for index, line in memory.lines do
			if not folder.Parent or folder:GetAttribute("RenderGeneration") ~= generation then return end
			local points = {}
			for _, pointInfo in line.points or {} do
				if typeof(pointInfo) == "table" and #pointInfo >= 3 then
					points[#points + 1] = Vector3.new(pointInfo[1], pointInfo[2], pointInfo[3])
				end
			end
			if #points >= 2 then
				local role: ObservedRole = if line.role == "Chaser" then "Chaser" else "Runner"
				local attempts = math.max(tonumber(line.attempts) or 1, 1)
				local averageTime = (tonumber(line.totalTime) or tonumber(line.duration) or 1) / attempts
				local averageSquared = (tonumber(line.totalTimeSquared) or averageTime ^ 2 * attempts) / attempts
				local deviation = math.sqrt(math.max(averageSquared - averageTime ^ 2, 0))
				local consistency = math.clamp(1 - deviation / math.max(averageTime, 0.1), 0, 1)
				local confidence = math.min(attempts / Config.provenRouteMinimumAttempts, 1) * 0.7 + consistency * 0.3
				local averageAdvantage = (tonumber(line.totalAdvantage) or tonumber(line.advantage) or 0) / attempts
				local averageOutcome = (tonumber(line.totalOutcome) or tonumber(line.outcome) or 0) / attempts
				local uses, catches, catchRate = Predictor.routeReview(memory, role, points)
				local catchEvidence = math.min(uses / 3, 1)
				confidence *= 1 - catchRate * catchEvidence * 0.85
				local verdict: "Proven" | "Good" | "Promising" | "Try" = "Promising"
				local authoredRating = tonumber(line.authoredRating) or 3
				local authoredRatingCount = tonumber(line.authoredRatingCount) or 0
				local authoredSuccessRate = math.clamp(tonumber(line.authoredSuccessRate) or 1, 0, 1)
				if line.authored == true then confidence *= 0.5 + authoredSuccessRate * 0.5 end
				if line.authored == true and authoredRatingCount >= 3 and authoredRating >= 4 and authoredSuccessRate >= 0.75
					and catchRate <= Config.provenRouteMaximumCatchRate
				then verdict = "Proven"
				elseif line.authored == true and authoredRatingCount >= 1 and authoredRating >= 3.5 and authoredSuccessRate >= 0.6
					and catchRate <= Config.goodRouteMaximumCatchRate
				then verdict = "Good"
				elseif line.authored ~= true and attempts >= Config.provenRouteMinimumAttempts and confidence >= Config.provenRouteMinimumConfidence
					and (averageAdvantage >= 0 or averageOutcome > 0) and catchRate <= Config.provenRouteMaximumCatchRate
				then verdict = "Proven"
				elseif line.authored ~= true and attempts >= Config.goodRouteMinimumAttempts and confidence >= Config.goodRouteMinimumConfidence
					and (averageAdvantage >= 0 or averageOutcome > 0) and catchRate <= Config.goodRouteMaximumCatchRate
				then verdict = "Good"
				end
				if uses >= 2 and catchRate >= 0.65 then verdict = "Try" end
				local candidate: RCandidate = {
					kind = if line.authored == true then "Authored" else "Observed",
					role = role,
					verdict = verdict,
					score = tonumber(line.quality) or 0,
					time = averageTime,
					advantage = averageAdvantage,
					reliability = confidence,
					confidence = confidence,
					consistency = consistency,
					improvement = math.clamp(((tonumber(line.firstTime) or averageTime) - (tonumber(line.bestTime) or averageTime)) / math.max(tonumber(line.firstTime) or averageTime, 0.1), -1, 1),
					points = points,
					actions = if typeof(line.actions) == "table" then line.actions else {},
					title = if line.authored == true then tostring(line.authoredTitle or "Authored Route") else nil,
					uses = uses,
					catches = catches,
					catchRate = catchRate,
				}
				renderCandidate(
					folder,
					candidate,
					index,
					true,
					generation,
					`LINE #{index} {candidate.title or role} | {string.upper(candidate.verdict)} | q {string.format("%.1f", candidate.score)} | adv {string.format("%+.1f", candidate.advantage)} | caught {catches}/{uses}`
				)
			end
			RunService.Heartbeat:Wait()
		end
	end)
	return folder
end

return table.freeze(MatchAnalysisVisuals)
