-- ==== 2) JoinScript.lua (hosted on GitHub) ====
-- Chứa hàm decodeJobId để loadstring vào client

-- 1) Khóa mã hóa lặp lại
local KEY    = { 0x5A, 0x3C, 0x7F, 0x21, 0x68 }
-- 2) Bản đồ hex
local hexMap = "0123456789ABCDEF"
-- 3) Tiền tố
local PREFIX = "ChilliHub"

-- Chuyển nibble (0–15) → ký tự hex
local function toHex(n)
    return hexMap:sub(n+1, n+1)
end

-- (Thừa kế) Hàm encode để test, không cần client
-- function encodeJobId(s) ... end

-- Hàm giải mã: Chuỗi "ChilliHub..." → JobId gốc
function decodeJobId(code)
    if code:sub(1, #PREFIX) ~= PREFIX then
        error("Invalid encoded JobId")
    end
    local hexs = code:sub(#PREFIX + 1)
    local bytes = {}
    for i = 1, #hexs, 2 do
        local hi = hexMap:find(hexs:sub(i,   i  ), 1, true) - 1
        local lo = hexMap:find(hexs:sub(i+1, i+1), 1, true) - 1
        local x  = hi * 16 + lo
        local key = KEY[(((i-1)/2) % #KEY) + 1]
        local orig = (x - key) % 256
        table.insert(bytes, orig)
    end
    return string.char(table.unpack(bytes))
end

-- Lưu ý: client-side sẽ làm tiếp phần:
--   local real = decodeJobId(code)
--   TeleportService:TeleportToPlaceInstance(game.PlaceId, real, game.Players.LocalPlayer)
