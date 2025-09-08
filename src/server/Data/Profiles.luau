local Players = game:GetService("Players")

local module = {}

local Profiles = {}
local Proxies = {}

module.PlayerDataTemplate = {}

local leaderstatsStats = { "Rank", "Tags" }

function module.Create(profileStore, player)
	local profile = profileStore:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile ~= nil then
		profile:AddUserId(player.UserId)
		profile:Reconcile()

		profile.OnSessionEnd:Connect(function()
			Profiles[player] = nil
			Proxies[player] = nil
			player:Kick(`Profile Session End - Please rejoin`)
		end)

		if player.Parent == Players then
			Profiles[player] = profile

			local proxy = {}
			local data = profile.Data
			local mt = {}

			local leaderstats = Instance.new("Folder")
			leaderstats.Name = "leaderstats"
			leaderstats.Parent = player

			mt.__newindex = function(_, k, v)
				data[k] = v
				player:SetAttribute(k, v)

				if table.find(leaderstatsStats, k) then
					local numberValue = leaderstats:FindFirstChild(k)

					if not numberValue then
						numberValue = Instance.new("NumberValue")
						numberValue.Name = k
						numberValue.Parent = leaderstats
					end

					numberValue.Value = v
				end
			end

			mt.__index = function(_, k)
				return data[k]
			end

			setmetatable(proxy, mt)

			Proxies[player] = proxy

			return profile
		else
			profile:EndSession()
			return
		end
	else
		player:Kick(`Profile Load Fail - Please rejoin`)
		return
	end
end

function module.ReturnProfile(player)
	return Profiles[player]
end

function module.ReturnProxy(player)
	return Proxies[player]
end

function module.AddDefaultData(key, value)
	module.PlayerDataTemplate[key] = value
end

return module
