-- Chỉ load khi PlaceId đúng
local targetPlaceId = 109983668079237

if game.PlaceId == targetPlaceId then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/tienkhanh1/spicy/main/LoadGame"))()
else
    warn("No support this PlaceId " .. game.PlaceId)
end
