local XENO_LOADER_URL = "https://api.luarmor.net/files/v4/loaders/66e067f17cbfa177b7bed91c1bdcb466.lua"
local DEFAULT_LOADER_URL = "https://raw.githubusercontent.com/tienkhanh1/Spicy-1/refs/heads/main/loo"
local DISCORD_LINK = "https://discord.gg/chilli-hub"
local POPUP_STATE_PATH = "chilli_discord_popup.json"

local function isXenoExecutor()
    local executorName = "unknown"
    pcall(function()
        if type(identifyexecutor) == "function" then
            executorName = tostring(identifyexecutor())
        elseif type(getexecutorname) == "function" then
            executorName = tostring(getexecutorname())
        end
    end)
    return executorName:lower():find("xeno", 1, true) ~= nil
end

local function loadRemote(url)
    local ok, problem = pcall(function()
        local source = game:HttpGet(url)
        local chunk, compileProblem = loadstring(source)
        if type(chunk) ~= "function" then
            error(compileProblem or "Remote script could not be compiled")
        end
        chunk()
    end)
    if not ok then
        warn("[Chilli Loader] " .. tostring(problem))
    end
end

-- Start the actual hub immediately. HttpGet yields independently while the
-- main thread below checks and, when needed, constructs the Discord popup.
task.spawn(function()
    loadRemote(isXenoExecutor() and XENO_LOADER_URL or DEFAULT_LOADER_URL)
end)

local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local function safeUiParent()
    if type(gethui) == "function" then
        local ok, hiddenUi = pcall(gethui)
        if ok and typeof(hiddenUi) == "Instance" then
            return hiddenUi
        end
    end
    if typeof(CoreGui) == "Instance" then
        return CoreGui
    end
    error("Chilli Discord popup requires gethui or CoreGui")
end

local function runtimeEnvironment()
    if type(getgenv) == "function" then
        local ok, environment = pcall(getgenv)
        if ok and type(environment) == "table" then
            return environment
        end
    end
    return _G
end

local function decodeFile(path)
    if type(isfile) ~= "function" or type(readfile) ~= "function" then
        return nil
    end
    local existsOk, exists = pcall(isfile, path)
    if not existsOk or not exists then
        return nil
    end
    local readOk, raw = pcall(readfile, path)
    if not readOk or type(raw) ~= "string" then
        return nil
    end
    local decodeOk, data = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    return decodeOk and type(data) == "table" and data or nil
end

local function discordPopupWasShown()
    local environment = runtimeEnvironment()
    if environment.__ChilliHubDiscordShown == true then
        return true
    end

    local state = decodeFile(POPUP_STATE_PATH)
    if state and state.Shown == true then
        environment.__ChilliHubDiscordShown = true
        return true
    end

    -- Honor the flag written by the older loader so existing users do not see
    -- the first-run popup again merely because the state filename changed.
    local legacy = decodeFile("chilli_config.json")
    if legacy and legacy.__ChilliHubDiscordShown == true then
        environment.__ChilliHubDiscordShown = true
        return true
    end
    return false
end

local function markDiscordPopupShown()
    runtimeEnvironment().__ChilliHubDiscordShown = true
    if type(writefile) == "function" then
        pcall(function()
            writefile(
                POPUP_STATE_PATH,
                HttpService:JSONEncode({ Shown = true })
            )
        end)
    end
end

if discordPopupWasShown() then
    return
end
markDiscordPopupShown()

local uiParent = safeUiParent()
local previous = uiParent:FindFirstChild("ChilliHubDiscord")
if previous then
    previous:Destroy()
end

local hubGui = Instance.new("ScreenGui")
hubGui.Name = "ChilliHubDiscord"
hubGui.IgnoreGuiInset = true
hubGui.ResetOnSpawn = false
hubGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
hubGui.AutoLocalize = false
hubGui.Parent = uiParent

local card = Instance.new("Frame")
card.Name = "Card"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.BackgroundColor3 = Color3.fromRGB(16, 24, 39)
card.BorderSizePixel = 0
card.Position = UDim2.new(0.5, 0, 0.31, 0)
card.Size = UDim2.fromOffset(380, 228)
card.Parent = hubGui
Instance.new("UICorner", card).CornerRadius = UDim.new(0, 20)

local cardGradient = Instance.new("UIGradient")
cardGradient.Rotation = 35
cardGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 18, 32)),
    ColorSequenceKeypoint.new(0.55, Color3.fromRGB(21, 30, 47)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 82, 120)),
})
cardGradient.Parent = card

local cardStroke = Instance.new("UIStroke")
cardStroke.Thickness = 2
cardStroke.Transparency = 0.15
cardStroke.Color = Color3.fromRGB(56, 189, 248)
cardStroke.Parent = card

local top = Instance.new("Frame")
top.Name = "TopBar"
top.BackgroundColor3 = Color3.fromRGB(25, 32, 48)
top.BackgroundTransparency = 0.15
top.BorderSizePixel = 0
top.Position = UDim2.new(0, 8, 0, 8)
top.Size = UDim2.new(1, -16, 0, 42)
top.Parent = card
Instance.new("UICorner", top).CornerRadius = UDim.new(0, 14)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 14, 0, 0)
title.Size = UDim2.new(1, -56, 1, 0)
title.Font = Enum.Font.GothamBold
title.Text = "Chilli Hub Discord"
title.TextColor3 = Color3.fromRGB(241, 245, 249)
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Center
title.Parent = top

local titleGradient = Instance.new("UIGradient")
titleGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 211, 238)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(99, 102, 241)),
})
titleGradient.Parent = title

local closeButton = Instance.new("TextButton")
closeButton.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.Position = UDim2.new(1, -34, 0.5, -14)
closeButton.Size = UDim2.fromOffset(28, 28)
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(241, 245, 249)
closeButton.TextSize = 14
closeButton.Parent = top
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 8)

local body = Instance.new("TextLabel")
body.BackgroundTransparency = 1
body.Position = UDim2.new(0, 18, 0, 60)
body.Size = UDim2.new(1, -36, 0, 76)
body.Font = Enum.Font.Gotham
body.Text = "Join to find secret servers\nGet update announcements\nEnter giveaways"
body.TextColor3 = Color3.fromRGB(241, 245, 249)
body.TextSize = 16
body.TextWrapped = true
body.Parent = card

local copyButton = Instance.new("TextButton")
copyButton.BackgroundColor3 = Color3.fromRGB(52, 180, 230)
copyButton.BorderSizePixel = 0
copyButton.Position = UDim2.new(0, 12, 1, -70)
copyButton.Size = UDim2.new(1, -24, 0, 38)
copyButton.Font = Enum.Font.GothamBlack
copyButton.Text = "Copy Discord Invite"
copyButton.TextColor3 = Color3.fromRGB(14, 25, 38)
copyButton.TextSize = 16
copyButton.Parent = card
Instance.new("UICorner", copyButton).CornerRadius = UDim.new(0, 12)

local toast = Instance.new("TextLabel")
toast.BackgroundTransparency = 1
toast.Position = UDim2.new(0, 12, 1, -28)
toast.Size = UDim2.new(1, -24, 0, 18)
toast.Font = Enum.Font.GothamBold
toast.Text = "discord.gg/chilli-hub"
toast.TextColor3 = Color3.fromRGB(148, 163, 184)
toast.TextSize = 13
toast.Parent = card

local function copyInvite()
    local copied = false
    if type(setclipboard) == "function" then
        copied = pcall(setclipboard, DISCORD_LINK)
    elseif type(toclipboard) == "function" then
        copied = pcall(toclipboard, DISCORD_LINK)
    elseif type(syn) == "table" and type(syn.write_clipboard) == "function" then
        copied = pcall(syn.write_clipboard, DISCORD_LINK)
    end
    toast.Text = copied
        and "Invite link copied to clipboard."
        or "Clipboard unsupported: " .. DISCORD_LINK
end

copyButton.Activated:Connect(copyInvite)
toast.Active = true
toast.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
    then
        copyInvite()
    end
end)
closeButton.Activated:Connect(function()
    hubGui:Destroy()
end)

TweenService:Create(
    card,
    TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    { Position = UDim2.new(0.5, 0, 0.34, 0) }
):Play()
