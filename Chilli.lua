local function checkExecutor()
    local execName = "unknown"
    if identifyexecutor then
        execName = tostring(identifyexecutor())
    elseif getexecutorname then
        execName = tostring(getexecutorname())
    end

    return string.find(string.lower(execName), "xeno")
end

if checkExecutor() then
    loadstring(game:HttpGet("https://api.luarmor.net/files/v4/loaders/66e067f17cbfa177b7bed91c1bdcb466.lua"))()
    
    return 
end

local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local HttpService   = game:GetService("HttpService")
local LocalPlayer   = Players.LocalPlayer
local playerGui     = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")

local DISCORD_LINK  = "https://discord.gg/chilli-hub"
local REMOTE_URL    = "https://raw.githubusercontent.com/tkhanhh/Spicy/refs/heads/main/loo"

COLOR_BASE_BG       = COLOR_BASE_BG       or Color3.fromRGB(16, 24, 39)
COLOR_CARD_GRAD_1   = COLOR_CARD_GRAD_1   or Color3.fromRGB(12, 18, 32)
COLOR_CARD_GRAD_2   = COLOR_CARD_GRAD_2   or Color3.fromRGB(21, 30, 47)
COLOR_CARD_GRAD_3   = COLOR_CARD_GRAD_3   or Color3.fromRGB(10, 82, 120)
COLOR_STROKE_GLOW   = COLOR_STROKE_GLOW   or Color3.fromRGB(56, 189, 248)
COLOR_STROKE_MAIN   = COLOR_STROKE_MAIN   or Color3.fromRGB(56, 189, 248)
COLOR_SURFACE       = COLOR_SURFACE       or Color3.fromRGB(30, 41, 59)
COLOR_SURFACE_DARK  = COLOR_SURFACE_DARK  or Color3.fromRGB(25, 32, 48)
COLOR_TEAL_ON       = COLOR_TEAL_ON       or Color3.fromRGB(52, 180, 230)
COLOR_TEXT          = COLOR_TEXT          or Color3.fromRGB(241, 245, 249)
COLOR_TEXT_MUTED    = COLOR_TEXT_MUTED    or Color3.fromRGB(148, 163, 184)

local _makeCard = (type(makeCard) == "function") and makeCard or function(parent, sizeUDim2)
    local frame = Instance.new('Frame')
    frame.BackgroundColor3 = COLOR_BASE_BG
    frame.BorderSizePixel = 0
    frame.Size = sizeUDim2
    frame.Parent = parent
    Instance.new('UICorner', frame).CornerRadius = UDim.new(0, 20)
    local g = Instance.new('UIGradient', frame)
    g.Rotation = 35
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, COLOR_CARD_GRAD_1),
        ColorSequenceKeypoint.new(0.55, COLOR_CARD_GRAD_2),
        ColorSequenceKeypoint.new(1.00, COLOR_CARD_GRAD_3),
    })
    local s1 = Instance.new('UIStroke', frame)
    s1.Thickness = 8
    s1.Transparency = 0.90
    s1.LineJoinMode = Enum.LineJoinMode.Round
    s1.Color = COLOR_STROKE_GLOW
    local s2 = Instance.new('UIStroke', frame)
    s2.Thickness = 2
    s2.Transparency = 0.15
    s2.LineJoinMode = Enum.LineJoinMode.Round
    s2.Color = COLOR_STROKE_MAIN
    return frame
end

local _makeTopBar = (type(makeTopBar) == "function") and makeTopBar or function(parent, titleText)
    local bar = Instance.new('Frame')
    bar.Parent = parent
    bar.BackgroundColor3 = COLOR_SURFACE_DARK
    bar.BackgroundTransparency = 0.15
    bar.BorderSizePixel = 0
    bar.Size = UDim2.new(1, -16, 0, 42)
    bar.Position = UDim2.new(0, 8, 0, 8)
    Instance.new('UICorner', bar).CornerRadius = UDim.new(0, 14)

    local lbl = Instance.new('TextLabel')
    lbl.Parent = bar
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.Size = UDim2.new(1, -28, 1, 0)
    lbl.Font = Enum.Font.GothamBold
    lbl.Text = titleText
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.TextSize = 18
    lbl.TextColor3 = COLOR_TEXT
    local grad = Instance.new('UIGradient', lbl)
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(34, 211, 238)),
        ColorSequenceKeypoint.new(0.50, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(99, 102, 241)),
    })
    return bar
end

config = config or {}
local CONFIG_PATH = CONFIG_PATH or "chilli_config.json"

local function fileExists(path)
    return (isfile and pcall(isfile, path) and isfile(path)) or false
end

local function readText(path)
    if not isfile then return nil end
    local ok, data = pcall(readfile, path)
    if ok then return data end
    return nil
end

local function writeText(path, text)
    if not writefile then return false end
    return pcall(writefile, path, text)
end

local function loadConfigHard()
    if fileExists(CONFIG_PATH) then
        local raw = readText(CONFIG_PATH)
        if raw then
            local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
            if ok and type(decoded) == "table" then
                for k, v in pairs(decoded) do
                    config[k] = v
                end
            end
        end
    end
end

local function saveConfigHard()
    if type(saveConfig) == "function" then
        local ok = pcall(saveConfig)
        if ok then return end
    end
    local ok, json = pcall(function() return HttpService:JSONEncode(config) end)
    if ok then writeText(CONFIG_PATH, json) end
end

loadConfigHard()
local firstShownFlag = (config.__ChilliHubDiscordShown == true)

local function runRemote()
    pcall(function()
        local src = game:HttpGet(REMOTE_URL)
        local f = loadstring(src)
        if type(f) == "function" then f() end
    end)
end

if firstShownFlag then
    runRemote()
    return
end

config.__ChilliHubDiscordShown = true
saveConfigHard()
runRemote()

local hubGui = Instance.new("ScreenGui")
hubGui.Name = "ChilliHubDiscord"
hubGui.IgnoreGuiInset = true
hubGui.ResetOnSpawn = false
hubGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
hubGui.AutoLocalize = false
hubGui.Parent = playerGui

local card = _makeCard(hubGui, UDim2.fromOffset(380, 228))
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.new(0.5, 0, 0.34, 0)

local top = _makeTopBar(card, "Chilli Hub Discord")

local closeBtn = Instance.new("TextButton")
closeBtn.Parent = top
closeBtn.BackgroundColor3 = COLOR_SURFACE
closeBtn.AutoButtonColor = true
closeBtn.BorderSizePixel = 0
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = COLOR_TEXT
closeBtn.Size = UDim2.fromOffset(28, 28)
closeBtn.Position = UDim2.new(1, -34, 0.5, -14)
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
local closeStroke = Instance.new("UIStroke", closeBtn)
closeStroke.Thickness = 1
closeStroke.Transparency = 0.25
closeStroke.Color = COLOR_STROKE_MAIN

local body = Instance.new("TextLabel")
body.Parent = card
body.BackgroundTransparency = 1
body.Position = UDim2.new(0, 18, 0, 60)
body.Size = UDim2.new(1, -36, 0, 76)
body.Text = "Join to find secret servers\nGet update announcements\nEnter giveaways"
body.TextWrapped = true
body.Font = Enum.Font.Gotham
body.TextSize = 16
body.TextXAlignment = Enum.TextXAlignment.Center
body.TextYAlignment = Enum.TextYAlignment.Center
body.TextColor3 = COLOR_TEXT

local copyBtn = Instance.new("TextButton")
copyBtn.Parent = card
copyBtn.Size = UDim2.new(1, -24, 0, 38)
copyBtn.Position = UDim2.new(0, 12, 1, -70)
copyBtn.BackgroundColor3 = COLOR_TEAL_ON
copyBtn.BorderSizePixel = 0
copyBtn.Text = "Copy Discord Invite"
copyBtn.Font = Enum.Font.GothamBlack
copyBtn.TextSize = 16
copyBtn.TextColor3 = Color3.fromRGB(14, 25, 38)
Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 12)
local cpStroke = Instance.new("UIStroke", copyBtn)
cpStroke.Thickness = 1
cpStroke.Transparency = 0.15
cpStroke.Color = COLOR_STROKE_MAIN

local linkBtn = Instance.new("TextButton")
linkBtn.Parent = card
linkBtn.BackgroundTransparency = 1
linkBtn.BorderSizePixel = 0
linkBtn.Position = UDim2.new(0, 12, 1, -28)
linkBtn.Size = UDim2.new(1, -24, 0, 18)
linkBtn.Text = "discord.gg/chilli-hub"
linkBtn.Font = Enum.Font.GothamBold
linkBtn.TextSize = 13
linkBtn.TextColor3 = COLOR_TEXT
linkBtn.AutoButtonColor = true

local toast = Instance.new("TextLabel")
toast.Parent = card
toast.BackgroundTransparency = 1
toast.Position = UDim2.new(0, 12, 1, -48)
toast.Size = UDim2.new(1, -24, 0, 16)
toast.Text = ""
toast.Font = Enum.Font.Gotham
toast.TextSize = 12
toast.TextXAlignment = Enum.TextXAlignment.Center
toast.TextColor3 = COLOR_TEXT_MUTED

local function copyToClipboard(text)
    if type(text) ~= "string" then return false end
    if setclipboard and type(setclipboard) == "function" then if pcall(setclipboard, text) then return true end end
    if toclipboard and type(toclipboard) == "function" then if pcall(toclipboard, text) then return true end end
    if syn and type(syn) == "table" and type(syn.write_clipboard) == "function" then if pcall(syn.write_clipboard, text) then return true end end
    return false
end

copyBtn.MouseButton1Click:Connect(function()
    if copyToClipboard(DISCORD_LINK) then
        toast.Text = "Invite link copied to clipboard."
    else
        toast.Text = "Clipboard not supported. Link: "..DISCORD_LINK
    end
end)

linkBtn.MouseButton1Click:Connect(function()
    if copyToClipboard(DISCORD_LINK) then
        toast.Text = "Link copied: discord.gg/chilli-hub"
    else
        toast.Text = "Clipboard not supported. Link: discord.gg/chilli-hub"
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    hubGui:Destroy()
end)

card.Position = UDim2.new(0.5, 0, 0.31, 0)
TweenService:Create(card, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0.34, 0) }):Play()
