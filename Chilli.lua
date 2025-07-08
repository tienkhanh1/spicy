local blockedPlaceIds = {
    [85451850104706]    = true,
    [120437750477306]   = true,
    [127298957482489]   = true,
    [91820643213706]    = true,
    [135744300508963]   = true,
    [74982515691410]    = true,
    [96358739341684]    = true,
    [121424241225362]   = true,
    [84547852189035]    = true,
}

if not blockedPlaceIds[game.PlaceId] then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/tienkhanh1/spicy/main/LoadGame"))()
else
    warn("No support PlaceId " .. game.PlaceId)
end
