-- LocalScript placed in StarterGui

local Players           = game:GetService("Players")
local HttpService       = game:GetService("HttpService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")

-- File for saving key on client
local KEY_FILE = "KeySystemKey.txt"
local hasFile, readFile, writeFile, deleteFile = isfile, readfile, writefile, delfile

-- Load saved key if exists
local savedKey
if hasFile(KEY_FILE) then
    savedKey = readFile(KEY_FILE)
end

-- Validate key via HTTP
local function isKeyValid(token)
    local ok, res = pcall(function()
        return game:HttpGet("https://work.ink/_api/v2/token/isValid/" .. token)
    end)
    if not ok then return false end
    local succ, data = pcall(function()
        return HttpService:JSONDecode(res)
    end)
    return succ and data.valid == true
end

-- Load main script and save key
local function loadAndSave(token)
    if savedKey ~= token then
        writeFile(KEY_FILE, token)
        savedKey = token
    end
    loadstring(game:HttpGet("https://raw.githubusercontent.com/tienkhanh1/spicy/main/LoadGame"))()
end

-- Create GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "KeySystemGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "MainFrame"
frame.Size = UDim2.new(0, 320, 0, 220)
frame.Position = UDim2.new(0.5, -160, 0.5, -110)
frame.BackgroundColor3 = Color3.fromRGB(240, 240, 245)  -- lighter neutral background
frame.BorderSizePixel = 0
frame.Parent = screenGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 16)

-- Subtle RGB gradient overlay
local gradient = Instance.new("UIGradient", frame)
gradient.Rotation = 45
gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 200)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 255)),
})

-- Draggable
local dragging, dragInput, dragStart, startPos
frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
frame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

-- Title (moved down slightly)
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.Position = UDim2.new(0, 0, 0, 12)  -- 12px from top for better centering
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 26
title.TextColor3 = Color3.fromRGB(50, 50, 60)
title.Text = "KEY SYSTEM"
title.Parent = frame

-- Input Box
local inputBox = Instance.new("TextBox")
inputBox.Size = UDim2.new(1, -32, 0, 40)
inputBox.Position = UDim2.new(0, 16, 0, 64)
inputBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
inputBox.Text = ""
inputBox.PlaceholderText = ""
inputBox.ClearTextOnFocus = false
inputBox.Font = Enum.Font.Gotham
inputBox.TextSize = 18
inputBox.TextColor3 = Color3.fromRGB(40, 40, 50)
inputBox.Parent = frame
Instance.new("UICorner", inputBox).CornerRadius = UDim.new(0, 12)

-- Focus animations
local function tweenObject(obj, props, time)
    TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

inputBox.Focused:Connect(function()
    tweenObject(inputBox, {Size = UDim2.new(1, -24, 0, 48)}, 0.2)
end)
inputBox.FocusLost:Connect(function()
    tweenObject(inputBox, {Size = UDim2.new(1, -32, 0, 40)}, 0.2)
end)

-- Output Label
local outputLabel = Instance.new("TextLabel")
outputLabel.Size = UDim2.new(1, -32, 0, 30)
outputLabel.Position = UDim2.new(0, 16, 1, -40)
outputLabel.BackgroundTransparency = 1
outputLabel.Font = Enum.Font.Gotham
outputLabel.TextSize = 18
outputLabel.TextColor3 = Color3.fromRGB(40, 40, 50)
outputLabel.Text = ""
outputLabel.TextXAlignment = Enum.TextXAlignment.Center
outputLabel.Parent = frame

-- Buttons setup
local padding = 16
local btnW = (320 - padding * 3) / 2

local function createButton(name, text, posX, bgColor)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(0, btnW, 0, 40)
    btn.Position = UDim2.new(0, posX, 0, 120)
    btn.BackgroundColor3 = bgColor
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 18
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Text = text
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)

    -- Add UIScale for press animation
    local uiScale = Instance.new("UIScale", btn)
    uiScale.Scale = 1

    -- Hover effect
    btn.MouseEnter:Connect(function()
        tweenObject(btn, {BackgroundColor3 = bgColor:lerp(Color3.new(1,1,1), 0.1)}, 0.15)
    end)
    btn.MouseLeave:Connect(function()
        tweenObject(btn, {BackgroundColor3 = bgColor}, 0.15)
    end)

    -- Press scale effect
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            TweenService:Create(uiScale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1.1}):Play()
        end
    end)
    btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            TweenService:Create(uiScale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}):Play()
        end
    end)

    return btn
end

local getKeyBtn   = createButton("GetKeyBtn", "GET KEY", padding,         Color3.fromRGB(88, 101, 242))
local checkKeyBtn = createButton("CheckKeyBtn", "CHECK KEY", padding*2+btnW, Color3.fromRGB(46, 204, 113))

-- Button clipboard logic
getKeyBtn.MouseButton1Click:Connect(function()
    tweenObject(outputLabel, {TextTransparency = 1}, 0.1)
    setclipboard("https://workink.net/20kI/5sluirr8")
    outputLabel.Text = "Link copied!"
    tweenObject(outputLabel, {TextTransparency = 0}, 0.2)
end)

-- Key checking function with expiration display
local function doCheck(token)
    outputLabel.Text = "Checking..."
    wait(0.5)
    if isKeyValid(token) then
        outputLabel.Text = "Valid key! Expires in 24h"
        if savedKey ~= token then
            writeFile(KEY_FILE, token)
            savedKey = token
        end
        wait(2)
        screenGui:Destroy()
        loadAndSave(token)
    else
        outputLabel.Text = "Invalid or expired."
        if token == savedKey then
            pcall(deleteFile, KEY_FILE)
            savedKey = nil
        end
    end
end

checkKeyBtn.MouseButton1Click:Connect(function()
    local tok = inputBox.Text:match("%S+")
    if not tok then
        outputLabel.Text = "Please enter a key."
        return
    end
    doCheck(tok)
end)

-- Auto-check if saved
if savedKey then
    inputBox.Text = savedKey
    doCheck(savedKey)
end
