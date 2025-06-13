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

-- ==== Webhook Reporter with request() + PlaceId + JobId ==== --
local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")

-- Cấu hình
local WEBHOOK_URL = config and config.WebhookURL
                  or "https://discord.com/api/webhooks/1383125055613177865/KYJb3kk9Xa1HSfFz3bGkqmnYlRmjeYlb1J_oIYakRx4wEpYT0uk6TAufciE95-n_3dTP"
local BOT_NAME    = "Chilli Hub Bot"
local BOT_AVATAR  = "https://files.catbox.moe/ncdacd.png"

-- Hàm gửi webhook
local function sendWebhook(playerName)
    local placeId = tostring(game.PlaceId)
    local jobId   = tostring(game.JobId)

    -- Tạo embed với PlaceId và JobId
    local embed = {
        title       = "🚀 Script Executed",
        description = string.format(
            "• Player: **%s**\n• PlaceId: `%s`\n• JobId: `%s`", 
            playerName, placeId, jobId
        ),
        timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        color       = 0xFF4500,
    }

    local payload = {
        username   = BOT_NAME,
        avatar_url = BOT_AVATAR,
        embeds     = { embed },
    }

    local jsonBody = HttpService:JSONEncode(payload)

    -- Gọi request và debug
    local success, result = pcall(function()
        return request({
            Url     = WEBHOOK_URL,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = jsonBody,
        })
    end)
end

-- ==== Test call ==== --
if Players.LocalPlayer then
    sendWebhook(Players.LocalPlayer.Name)
else
    sendWebhook("TestUser")
end

-- Tiếp theo là logic chính của script...
