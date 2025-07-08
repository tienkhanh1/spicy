local blockedPlaceIds = {
    [85451850104706]   = true,
    [120437750477306]  = true,
    [127298957482489]  = true,
}
if not blockedPlaceIds[game.PlaceId] then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/tienkhanh1/spicy/main/LoadGame"))()
else
    warn("Blocked PlaceId " .. game.PlaceId)
end
