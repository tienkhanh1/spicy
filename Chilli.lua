-- Danh sách PlaceId được phép load
local allowedPlaceIds = {
    [109983668079237] = true,
    [96342491571673]  = true,
}

-- Kiểm tra và load script
if allowedPlaceIds[game.PlaceId] then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/tienkhanh1/spicy/main/LoadGame"))()
else
    warn("No support PlaceId " .. game.PlaceId)
end
