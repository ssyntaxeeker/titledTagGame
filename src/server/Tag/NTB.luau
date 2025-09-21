local NTB = {}

local NTBVersions = {}

function NTB.Hit(player)
	local character = player.Character
	local currentDurability = character:GetAttribute("NTBDurability") or 0
	local _version = NTBVersions[character] or 0

	if currentDurability == 0 then
		character:SetAttribute("NTBDurability", 3)
		_version += 1
		NTBVersions[character] = _version

		task.delay(3, function()
			if NTBVersions[character] == _version then character:SetAttribute("NTBDurability", 0) end
		end)
		return
	end

	character:SetAttribute("NTBDurability", currentDurability - 1)
end

return NTB
