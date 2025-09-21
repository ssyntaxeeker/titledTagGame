local Players = game:GetService("Players")
local RoundUtils = {}

function RoundUtils.CheckIfLastPlayerStanding()
    local playerAlive
  
    for _, player in Players:GetPlayers() do
        local character = player.Character 
        if not character then continue end 

        if character:GetAttribute("Role") == "Dead" then continue end  
            
        if playerAlive then return end
        playerAlive = player
    end

    return playerAlive
end

return RoundUtils