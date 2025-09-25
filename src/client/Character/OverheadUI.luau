local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraModule = require(ReplicatedStorage.Modules.Camera.CameraModule)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local Assets = ReplicatedStorage.Assets

local localPlayer = Players.LocalPlayer

local function updateOverheadUI(player)
	local character = player.Character
	if not character then return end

	local head = character:FindFirstChild("Head")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not head or not humanoid then return end

	local UI = head:FindFirstChild("PlayerName")
	if not UI then return end

	local healthRatio = humanoid.Health / humanoid.MaxHealth
	local newHealthColor = Color3.fromHSV(healthRatio * 0.3, 1, 1)

	UI.HealthContainer.Visible = healthRatio ~= 1

	UI.HealthContainer.Frame.UIStroke.Color = newHealthColor
	UI.HealthContainer.Frame.Frame.BackgroundColor3 = newHealthColor
	UI.HealthContainer.Frame.Frame.Size = UDim2.fromScale(healthRatio, 1)

	UI.NameContainer.DisplayName.Text = player.DisplayName
	UI.NameContainer.rank.Text = `rank {player:GetAttribute("Rank")}` or "rank C"

	UI.Enabled = if player == localPlayer and CameraModule.FirstPerson == true then false else true
end

local function connectCharacter(player, character)
	task.spawn(function()
		local head = character:WaitForChild("Head", 5)
		local humanoid = character:WaitForChild("Humanoid", 5)
		if not humanoid or not head then return end

		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

		local newOverheadUI = Assets.UI.Extra.PlayerName:Clone()
		newOverheadUI.Name = "PlayerName"
		newOverheadUI.Adornee = head
		newOverheadUI.Parent = head
		newOverheadUI.Enabled = false

		updateOverheadUI(player)

		humanoid:GetPropertyChangedSignal("Health"):Connect(function()
			updateOverheadUI(player)
		end)

		player:GetAttributeChangedSignal("Rank"):Connect(function()
			updateOverheadUI(player)
		end)
	end)
end

local function setupPlayer(player)
	player.CharacterAdded:Connect(function(character)
		connectCharacter(player, character)
	end)

	if player.Character then connectCharacter(player, player.Character) end
end

local function init()
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end

	Players.PlayerAdded:Connect(setupPlayer)
end

return Schedules.Boot.job(init)
