--!strict
--[[
    CheckpointEscape (Server)
    =========================
    Author: Sol (3693744006)
    Updated: 26/07/20

    Every player races their own locally presented ordered checkpoint course.
    Maps may use EscapeCheckpoint tags, a Map.Checkpoints folder, or spawns.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CheckpointUtils = require(ReplicatedStorage.Shared.Utils.CheckpointUtils)
local CheckpointEscapeConfig = require(ReplicatedStorage.Shared.Configs.CheckpointEscape)
local ClockFunctions = require(ServerStorage.Modules.GameLogic.Clock.ClockFunctions)
local CompetitiveModeUtils = require(ServerStorage.Modules.GameLogic.Modes.CompetitiveModeUtils)
local ModesList = require(ServerStorage.Modules.GameLogic.Modes.ModesList)
local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)

local function getRankedParticipants(): { Player }
	local speedrunners = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("CheckpointParticipant") == true then
			table.insert(speedrunners, player)
		end
	end
	table.sort(speedrunners, function(left, right)
		local leftProgress = left:GetAttribute("CheckpointProgress") or 0
		local rightProgress = right:GetAttribute("CheckpointProgress") or 0
		if leftProgress ~= rightProgress then return leftProgress > rightProgress end

		local leftReachedAt = left:GetAttribute("CheckpointReachedAt") or math.huge
		local rightReachedAt = right:GetAttribute("CheckpointReachedAt") or math.huge
		if leftReachedAt ~= rightReachedAt then return leftReachedAt < rightReachedAt end
		return left.UserId < right.UserId
	end)
	return speedrunners
end

local function updateStandings(totalProgress: number)
	local speedrunners = getRankedParticipants()

	local leaders = {}
	for place = 1, math.min(2, #speedrunners) do
		local speedrunner = speedrunners[place]
		local progress = speedrunner:GetAttribute("CheckpointProgress") or 0
		table.insert(leaders, `{place}. {speedrunner.Name} {progress}/{totalProgress}`)
	end
	workspace:SetAttribute("CheckpointStandings", table.concat(leaders, "  |  "))
end

return ModesList.AddMode("CheckpointEscape", {
	start = function(context)
		local players = Players:GetPlayers()
		for _, player in players do
			player:SetAttribute("CheckpointParticipant", true)
		end
		context.addCleanup(function()
			for _, player in Players:GetPlayers() do
				player:SetAttribute("CheckpointParticipant", nil)
			end
		end, true)
		CompetitiveModeUtils.AssignShuffled(players, {
			{ role = "Speedrunner", count = #players },
		})
		for _, player in players do
			player:SetAttribute("CheckpointProgress", 0)
			player:SetAttribute("CheckpointLap", 1)
			player:SetAttribute("CheckpointReachedAt", nil)
		end

		local map = workspace:FindFirstChild("Map")
		local checkpoints = if map then CheckpointUtils.GetOrdered(map) else {}
		if #checkpoints < CheckpointEscapeConfig.minimumCheckpoints then
			workspace:SetAttribute(
				"ModeStatus",
				`This map needs at least {CheckpointEscapeConfig.minimumCheckpoints} EscapeCheckpoint parts`
			)
			context.delay(2, function()
				context.endRound({}, "MissingCheckpoints")
			end)
			return
		end
		local totalProgress = #checkpoints * CheckpointEscapeConfig.laps
		workspace:SetAttribute("CheckpointLapCount", CheckpointEscapeConfig.laps)
		workspace:SetAttribute("CheckpointCourseLength", totalProgress)
		updateStandings(totalProgress)

		for index, checkpoint in checkpoints do
			context.addCleanup(checkpoint.Touched:Connect(function(hit)
				if not context.isActive() then return end
				local character = hit:FindFirstAncestorOfClass("Model")
				local player = if character then Players:GetPlayerFromCharacter(character) else nil
				if not character or not player or player:GetAttribute("CheckpointParticipant") ~= true then return end
				if character:GetAttribute("Role") ~= "Speedrunner" then return end
				local progress = player:GetAttribute("CheckpointProgress") or 0
				local expectedIndex = progress % #checkpoints + 1
				if index ~= expectedIndex then return end

				local nextProgress = progress + 1
				local lap = math.min(math.floor(nextProgress / #checkpoints) + 1, CheckpointEscapeConfig.laps)
				player:SetAttribute("CheckpointProgress", nextProgress)
				player:SetAttribute("CheckpointLap", lap)
				player:SetAttribute("CheckpointReachedAt", workspace:GetServerTimeNow())
				updateStandings(totalProgress)
				if nextProgress >= totalProgress then context.endRound({ player }, "Escaped") end
			end))
		end
		context.addCleanup(Players.PlayerAdded:Connect(function(player)
			player:SetAttribute("CheckpointParticipant", false)
			player:SetAttribute("CheckpointProgress", nil)
			player:SetAttribute("CheckpointLap", nil)
			player:SetAttribute("CheckpointReachedAt", nil)
			context.delay(0, function()
				if player.Parent ~= Players or not context.isActive() then return end
				assert(
					RolesFunctions.ChangeRole(player, "Dead"),
					`[CheckpointEscape.start] failed to make mid-round joiner {player.Name} Dead`
				)
			end)
		end))
		context.addCleanup(Players.PlayerRemoving:Connect(function()
			context.delay(0, function()
				updateStandings(totalProgress)
				if #getRankedParticipants() == 0 then
					context.endRound({}, "NoSpeedrunners")
				end
			end)
		end))
		ClockFunctions.SetTime(
			CheckpointEscapeConfig.baseRoundSeconds + CheckpointEscapeConfig.secondsPerPlayer * #players
		)
		workspace:SetAttribute(
			"ModeStatus",
			`Complete {CheckpointEscapeConfig.laps} laps - {totalProgress} checkpoints total`
		)
	end,
	getWinners = function(): { Player }
		local speedrunners = getRankedParticipants()
		if #speedrunners == 0 then return {} end
		local leadingProgress = speedrunners[1]:GetAttribute("CheckpointProgress") or 0
		local winners = {}
		for _, speedrunner in speedrunners do
			if (speedrunner:GetAttribute("CheckpointProgress") or 0) ~= leadingProgress then break end
			table.insert(winners, speedrunner)
		end
		return winners
	end,
})
