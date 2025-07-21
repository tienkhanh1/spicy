-- JoinScript.lua

-- 1) Khóa và bản đồ hex
local KEY    = { 0x5A, 0x3C, 0x7F, 0x21, 0x68 }
local hexMap = '0123456789ABCDEF'
local PREFIX = "ChilliHub"

-- 2) Hàm giải mã
local function decodeJobId(code)
    if code:sub(1, #PREFIX) ~= PREFIX then
        error("Invalid encoded JobId")
    end
    local hexs  = code:sub(#PREFIX + 1)
    local bytes = {}
    for i = 1, #hexs, 2 do
        local hi  = hexMap:find(hexs:sub(i,   i  ), 1, true) - 1
        local lo  = hexMap:find(hexs:sub(i+1, i+1), 1, true) - 1
        local x   = hi * 16 + lo
        local key = KEY[(((i-1)/2) % #KEY) + 1]
        table.insert(bytes, (x - key) % 256)
    end
    return string.char(table.unpack(bytes))
end

local realJobId = decodeJobId(encodedCode)
game:GetService("TeleportService"):TeleportToPlaceInstance(placeId, realJobId, game.Players.LocalPlayer)
