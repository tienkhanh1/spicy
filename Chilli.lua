local Players  = game:GetService("Players")
local placeId  = game.PlaceId

local GROW_GARDEN_ID        = 126884695634066 
local STEAL_BRAINROT_ID     = 109983668079237

if placeId == GROW_GARDEN_ID then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/tienkhanh1/spicy/main/Grow-a-Garden"))()
elseif placeId == STEAL_BRAINROT_ID then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/tienkhanh1/spicy/main/Steal-a-Brainrot"))()
else
    warn(("No supported script for PlaceId %s"):format(tostring(placeId)))
end
