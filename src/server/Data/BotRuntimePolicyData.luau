--!strict
--[[
    BotRuntimePolicyData (Server)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Authoritative persistence and structural validation for the global tiny
    runtime policy. Only explicitly trusted trainer users may read or replace it.
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Packages.Net)
local BotAccess = require(ReplicatedStorage.Shared.Configs.BotAccess)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local RetrieveBotRuntimePolicyRF = Net:RemoteFunction("RetrieveBotRuntimePolicy")
local SaveBotRuntimePolicyRF = Net:RemoteFunction("SaveBotRuntimePolicy")
local RuntimePolicyStore = DataStoreService:GetDataStore("TitledTagGameBotRuntimePolicy")

local GLOBAL_POLICY_KEY = "GlobalRuntimePolicy_v1"
local INPUT_SIZE = 12
local HIDDEN_SIZE = 24
local ACTIONS = table.freeze({
	"Walk",
	"Jump",
	"Vault",
	"HighVault",
	"TrussClimb",
	"Swing",
	"Roll",
	"RollBoost",
	"SlideBoost",
	"Trampoline",
	"Drop",
})

local cachedPolicy: { [string]: any }? = nil
local loaded = false

local function finiteNumber(value: any, maximumMagnitude: number): number?
	local numberValue = tonumber(value)
	if not numberValue or numberValue ~= numberValue or math.abs(numberValue) > maximumMagnitude then return nil end
	return numberValue
end

local function numericArray(raw: any, expectedCount: number, maximumMagnitude: number): { number }?
	if typeof(raw) ~= "table" or #raw ~= expectedCount then return nil end
	local result: { number } = {}
	for index = 1, expectedCount do
		local value = finiteNumber(raw[index], maximumMagnitude)
		if not value then return nil end
		result[index] = value
	end
	return result
end

local function layer(raw: any, rows: number, columns: number, activation: string): { [string]: any }?
	if typeof(raw) ~= "table" or raw.activation ~= activation then return nil end
	if typeof(raw.weights) ~= "table" or #raw.weights ~= rows then return nil end
	local weights: { { number } } = {}
	for rowIndex = 1, rows do
		local row = numericArray(raw.weights[rowIndex], columns, 100)
		if not row then return nil end
		weights[rowIndex] = row
	end
	local bias = numericArray(raw.bias, rows, 100)
	if not bias then return nil end
	return { activation = activation, weights = weights, bias = bias }
end

local function sanitize(raw: any): { [string]: any }?
	if typeof(raw) ~= "table" or typeof(raw.model) ~= "table" then return nil end
	local model = raw.model
	if model.inputSize ~= INPUT_SIZE or typeof(model.actions) ~= "table" or #model.actions ~= #ACTIONS then return nil end
	for index, actionName in ACTIONS do
		if model.actions[index] ~= actionName then return nil end
	end
	local inputMean = numericArray(model.inputMean, INPUT_SIZE, 100)
	local inputStd = numericArray(model.inputStd, INPUT_SIZE, 100)
	if not inputMean or not inputStd then return nil end
	for _, standardDeviation in inputStd do
		if standardDeviation < 0.0001 then return nil end
	end
	if typeof(model.layers) ~= "table" or #model.layers ~= 2 then return nil end
	local hiddenLayer = layer(model.layers[1], HIDDEN_SIZE, INPUT_SIZE, "relu")
	local outputLayer = layer(model.layers[2], #ACTIONS, HIDDEN_SIZE, "linear")
	if not hiddenLayer or not outputLayer then return nil end
	local sampleCount = math.floor(finiteNumber(raw.sampleCount, 1000000) or 0)
	local baselineLoss = finiteNumber(raw.baselineLoss, 1000000)
	local validationLoss = finiteNumber(raw.validationLoss, 1000000)
	if sampleCount < 400 or not baselineLoss or not validationLoss or validationLoss >= baselineLoss then return nil end
	return {
		model = {
			version = math.clamp(math.floor(tonumber(model.version) or 1), 1, 1000000),
			inputSize = INPUT_SIZE,
			actions = table.clone(ACTIONS),
			inputMean = inputMean,
			inputStd = inputStd,
			layers = { hiddenLayer, outputLayer },
		},
		sampleCount = sampleCount,
		baselineLoss = baselineLoss,
		validationLoss = validationLoss,
		updatedAt = os.time(),
	}
end

local function loadPolicy(): { [string]: any }?
	if loaded then return cachedPolicy end
	local success, result = pcall(function()
		return RuntimePolicyStore:GetAsync(GLOBAL_POLICY_KEY)
	end)
	if not success then
		warn(`[BotRuntimePolicyData] load failed: {tostring(result)}`)
	else
		cachedPolicy = sanitize(result)
	end
	loaded = true
	return cachedPolicy
end

local function init()
	RetrieveBotRuntimePolicyRF.OnServerInvoke = function(player)
		if BotAccess.userIds[player.UserId] ~= true then return nil end
		return loadPolicy()
	end
	SaveBotRuntimePolicyRF.OnServerInvoke = function(player, raw)
		if BotAccess.userIds[player.UserId] ~= true then return nil end
		local candidate = sanitize(raw)
		if not candidate then return nil end
		local success, result = pcall(function()
			return RuntimePolicyStore:UpdateAsync(GLOBAL_POLICY_KEY, function()
				return candidate
			end)
		end)
		if not success then
			warn(`[BotRuntimePolicyData] save failed: {tostring(result)}`)
			return nil
		end
		cachedPolicy = sanitize(result)
		loaded = true
		return cachedPolicy
	end
end

return Schedules.Boot.job(init)
