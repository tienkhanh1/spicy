--!strict
-- LocalScript @ StarterPlayerScripts
--========================================================
-- SERVICES & BIẾN CHUNG
--========================================================
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")

local player = Players.LocalPlayer
if not player then return end

--========================================================
-- CONFIG (dạng global để tái sử dụng)
--========================================================
_G.__SB_CFG__ = _G.__SB_CFG__ or {}
local config = _G.__SB_CFG__

-- Mặc định
if config.Move_CFrame == nil then config.Move_CFrame = false end
if config.SpeedBoost_Speed == nil then config.SpeedBoost_Speed = 150 end
config.SpeedBoost_Speed = math.clamp(tonumber(config.SpeedBoost_Speed) or 150, 0, 180)

local function saveConfig()
    -- Nếu bạn có hệ lưu riêng, thay vào đây (để trống vẫn OK)
end

--========================================================
-- GRAPPLE: Remote & tiện ích
--========================================================
local REMOTE_ARG: number = 1.9832406361897787
local UseItemRemote: RemoteEvent? = nil

local function resolveUseItemRemote(): RemoteEvent?
    if UseItemRemote and UseItemRemote.Parent then return UseItemRemote end
    local ok, re = pcall(function()
        return ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Net"):WaitForChild("RE/UseItem")
    end)
    if ok and re and re:IsA("RemoteEvent") then
        UseItemRemote = re
        return UseItemRemote
    end
    return nil
end

local function isGrappleTool(tool: Instance?): boolean
    if not tool or not tool:IsA("Tool") or not tool.Name then return false end
    local n = string.lower(tool.Name)
    return string.find(n, "grapple") ~= nil or tool.Name == "Grapple Hook"
end

--========================================================
-- BOOST CONTROLLER (logic CFrame-speed)
--========================================================
local function makeBoostController(params: {
    INTERVAL: number,
    EXTRA_SPEED: number,
    MAX_SPEED: number,
    RESP_GROUND: number,
    RESP_AIR: number,
    AIR_CONTROL: boolean,
    AIR_STICK_TIME: number,
    AIR_NO_INPUT_GRACE: number,
    STICK_ONLY_IF_INPUT: boolean,
    PRESERVE_MOMENTUM: boolean,
})
    local self: {
        conn: RBXScriptConnection?,
        died: RBXScriptConnection?,
        start: (self: any, hum: Humanoid, hrp: BasePart) -> (),
        stop: (self: any) -> (),
    } = {} :: any
    self.conn = nil
    self.died = nil

    local function alphaFrom(resp: number, dt: number)
        return 1 - math.exp(-resp * dt)
    end

    function self:stop()
        if self.conn then self.conn:Disconnect(); self.conn = nil end
        if self.died then self.died:Disconnect(); self.died = nil end
    end

    function self:start(hum: Humanoid, hrp: BasePart)
        self:stop()

        local DECAY_GROUND = 18
        local DECAY_AIR    = 4
        local SPEED_EPS    = 0.35

        local acc = 0
        local lastOnGround = true
        local airStartTime = 0
        local carryDir = Vector3.zero
        local tookoffHasInput = false
        local lastExitHorizSpeed = 0

        self.conn = RunService.Heartbeat:Connect(function(dt)
            acc += dt
            local step = params.INTERVAL
            if acc < step then return end

            while acc >= step do
                acc -= step
                if hum.Health <= 0 then break end
                if not hrp or not hrp.Parent then break end

                local v = hrp.AssemblyLinearVelocity
                local horiz = Vector3.new(v.X, 0, v.Z)
                local onGround = hum.FloorMaterial ~= Enum.Material.Air
                local now = os.clock()

                if lastOnGround and not onGround then
                    airStartTime = now
                    lastExitHorizSpeed = horiz.Magnitude
                    local md = hum.MoveDirection
                    tookoffHasInput = md.Magnitude > 0.05
                    carryDir = tookoffHasInput and md.Unit or Vector3.zero
                end
                lastOnGround = onGround

                local md = hum.MoveDirection
                local haveInput = md.Magnitude > 0.01
                local dir = Vector3.zero

                if haveInput then
                    dir = md.Unit
                elseif not onGround then
                    local stickT = params.AIR_STICK_TIME
                    local stickOnlyIf = (params.STICK_ONLY_IF_INPUT ~= false)
                    if (now - airStartTime) <= stickT then
                        if (stickOnlyIf and tookoffHasInput and carryDir.Magnitude > 0)
                        or ((not stickOnlyIf) and carryDir.Magnitude > 0) then
                            dir = carryDir
                        end
                    end
                end

                local inNoInputGrace = (not onGround) and (not tookoffHasInput) and (not haveInput)
                        and ((now - airStartTime) <= params.AIR_NO_INPUT_GRACE)

                if dir.Magnitude > 0 and (not inNoInputGrace) then
                    local baseWS = hum.WalkSpeed
                    local targetSpeed = math.clamp(baseWS + (params.EXTRA_SPEED or 0), 0, (params.MAX_SPEED or 180))
                    if (params.AIR_CONTROL ~= false) and (not onGround) and (params.PRESERVE_MOMENTUM ~= false) then
                        targetSpeed = math.clamp(math.max(targetSpeed, lastExitHorizSpeed), 0, (params.MAX_SPEED or 180))
                    end

                    local targetHoriz = dir * targetSpeed
                    local resp = (onGround and (params.RESP_GROUND or 14) or (params.RESP_AIR or 10))
                    local a = alphaFrom(resp, step)
                    local newHoriz = horiz:Lerp(targetHoriz, a)
                    if onGround and newHoriz.Magnitude < SPEED_EPS then newHoriz = Vector3.zero end
                    hrp.AssemblyLinearVelocity = Vector3.new(newHoriz.X, v.Y, newHoriz.Z)
                else
                    local decay = onGround and DECAY_GROUND or DECAY_AIR
                    if decay > 0 then
                        local factor = math.exp(-decay * step)
                        local newHoriz = horiz * factor
                        if onGround and newHoriz.Magnitude < SPEED_EPS then
                            newHoriz = Vector3.zero
                        end
                        hrp.AssemblyLinearVelocity = Vector3.new(newHoriz.X, v.Y, newHoriz.Z)
                    end
                end
            end
        end)

        -- KHÔNG tắt vĩnh viễn khi chết; chỉ ngắt kết nối vòng hiện tại
        self.died = hum.Died:Connect(function()
            self:stop()
        end)
    end

    return self
end

--========================================================
-- GRAPPLE CONTROLLER (auto equip + spam UseItem)
--========================================================
local function makeGrappleController()
    local self: {
        enabled: boolean,
        loopRunning: boolean,
        charConn: RBXScriptConnection?,
        diedConn: RBXScriptConnection?,
        start: (self: any) -> (),
        stop: (self: any) -> (),
    } = {} :: any

    self.enabled = false
    self.loopRunning = false
    self.charConn = nil
    self.diedConn = nil

    local INTERVAL = 1/120 -- nhịp rất nhanh, ổn định theo Heartbeat

    local function performOnce(character: Model)
        if not character then return end
        local hum = character:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end
        local backpack = player:FindFirstChild("Backpack")

        local candidates: {Tool} = {}

        if backpack then
            for _, it in ipairs(backpack:GetChildren()) do
                if isGrappleTool(it) then table.insert(candidates, it :: Tool) end
            end
        end
        for _, it in ipairs(character:GetChildren()) do
            if isGrappleTool(it) then table.insert(candidates, it :: Tool) end
        end

        local re = resolveUseItemRemote()
        for _, tool in ipairs(candidates) do
            if not self.enabled then break end
            -- Equip an toàn
            pcall(function()
                local hum2 = character:FindFirstChildOfClass("Humanoid")
                if hum2 and tool and tool.Parent ~= character then
                    hum2:EquipTool(tool)
                end
            end)
            -- Gọi remote
            if re then
                pcall(function()
                    re:FireServer(REMOTE_ARG)
                end)
            end
        end
    end

    local function startLoopFor(character: Model)
        if self.loopRunning then return end
        self.loopRunning = true
        task.spawn(function()
            local accum = 0
            local last = tick()
            while self.enabled do
                local now = tick()
                local dt = now - last
                last = now
                accum += dt
                if accum >= INTERVAL then
                    accum -= INTERVAL
                    local char = player.Character
                    if char then
                        performOnce(char)
                    end
                end
                task.wait() -- yield nhẹ
            end
            self.loopRunning = false
        end)
    end

    function self:start()
        if self.enabled then return end
        self.enabled = true

        -- bind current character
        if player.Character then
            startLoopFor(player.Character)
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                if self.diedConn then self.diedConn:Disconnect(); self.diedConn = nil end
                self.diedConn = hum.Died:Connect(function()
                    -- KHÔNG tắt feature; đợi respawn
                end)
            end
        end

        -- luôn lắng nghe respawn để tự tiếp tục
        if self.charConn then self.charConn:Disconnect(); self.charConn = nil end
        self.charConn = player.CharacterAdded:Connect(function(char)
            local hum = char:WaitForChild("Humanoid", 5)
            if hum then
                if self.diedConn then self.diedConn:Disconnect(); self.diedConn = nil end
                self.diedConn = hum.Died:Connect(function() end)
            end
            if self.enabled then
                startLoopFor(char)
            end
        end)
    end

    function self:stop()
        self.enabled = false
        if self.charConn then self.charConn:Disconnect(); self.charConn = nil end
        if self.diedConn then self.diedConn:Disconnect(); self.diedConn = nil end
        -- vòng loop sẽ tự thoát khi self.enabled=false
    end

    return self
end

--========================================================
-- KHỞI TẠO CONTROLLERS
--========================================================
local PARAMS = {
    EXTRA_SPEED         = config.SpeedBoost_Speed, -- cập nhật live
    MAX_SPEED           = 180,
    INTERVAL            = 1/120,  -- bước cố định
    RESP_GROUND         = 14,
    RESP_AIR            = 10,
    AIR_CONTROL         = true,
    AIR_STICK_TIME      = 0.25,
    AIR_NO_INPUT_GRACE  = 0.12,
    STICK_ONLY_IF_INPUT = true,
    PRESERVE_MOMENTUM   = true,
}
local boost   = makeBoostController(PARAMS)
local grapple = makeGrappleController()

local charAddedConn: RBXScriptConnection? = nil
local charRemovingConn: RBXScriptConnection? = nil

local function bindHumanoid(hum: Humanoid)
    local hrp = hum.Parent and hum.Parent:FindFirstChild("HumanoidRootPart")
    if not hrp then
        hrp = hum.Parent and hum.Parent:WaitForChild("HumanoidRootPart", 5)
    end
    if not hrp then return end
    boost:start(hum, hrp :: BasePart)
end

local function startAllIfEnabled()
    if not config.Move_CFrame then return end
    -- Boost
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid") or nil
    if not hum and char then hum = char:WaitForChild("Humanoid", 5) end
    if hum then bindHumanoid(hum) end
    -- Grapple
    grapple:start()

    -- Respawn listeners (để tự phục hồi sau chết)
    if charRemovingConn then charRemovingConn:Disconnect(); charRemovingConn = nil end
    if charAddedConn then charAddedConn:Disconnect(); charAddedConn = nil end

    charRemovingConn = player.CharacterRemoving:Connect(function()
        boost:stop() -- grapple vẫn giữ enabled=true, sẽ tiếp tục khi CharacterAdded
    end)
    charAddedConn = player.CharacterAdded:Connect(function(c)
        local h = c:WaitForChild("Humanoid", 5)
        if h then bindHumanoid(h) end
        if config.Move_CFrame then grapple:start() end
    end)
end

local function stopAll()
    boost:stop()
    grapple:stop()
    if charRemovingConn then charRemovingConn:Disconnect(); charRemovingConn = nil end
    if charAddedConn then charAddedConn:Disconnect(); charAddedConn = nil end
end

--========================================================
-- UI: NHỎ GỌN (240px), THẨM MỸ, KÉO THẢ, THU GỌN TOPBAR
--========================================================
local function createUI()
    -- ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SpeedBoostUI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = player:WaitForChild("PlayerGui")

    -- Main Frame (nhỏ ngang)
    local frame = Instance.new("Frame")
    frame.Name = "Main"
    frame.Size = UDim2.fromOffset(240, 100) -- thu gọn chiều ngang mạnh
    frame.Position = UDim2.new(0, 40, 0, 120)
    frame.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
    frame.Parent = screenGui
    local corner = Instance.new("UICorner", frame); corner.CornerRadius = UDim.new(0, 10)
    local stroke = Instance.new("UIStroke", frame); stroke.Thickness = 1.5; stroke.Color = Color3.fromRGB(70,70,80); stroke.Transparency = 0.2

    -- Header (kéo thả)
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 36)
    header.BackgroundTransparency = 1
    header.Parent = frame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Text = "Chilli Speed Boost"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextColor3 = Color3.fromRGB(230, 230, 240)
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(12, 8)
    title.Size = UDim2.fromOffset(150, 20)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    -- Nút Thu gọn (thay cho X)
    local collapseBtn = Instance.new("TextButton")
    collapseBtn.Name = "Collapse"
    collapseBtn.Text = "X"
    collapseBtn.Font = Enum.Font.GothamBold
    collapseBtn.TextSize = 16
    collapseBtn.TextColor3 = Color3.fromRGB(240,240,240)
    collapseBtn.Size = UDim2.fromOffset(28, 28)
    collapseBtn.Position = UDim2.new(1, -34, 0, 4)
    collapseBtn.BackgroundColor3 = Color3.fromRGB(42, 44, 52)
    collapseBtn.AutoButtonColor = true
    collapseBtn.Parent = header
    local collCorner = Instance.new("UICorner", collapseBtn); collCorner.CornerRadius = UDim.new(1, 0)

    -- Toggle + INPUT ngay trên nút
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "Toggle"
    toggleBtn.Size = UDim2.fromOffset(200, 48)
    toggleBtn.Position = UDim2.fromOffset(20, 44)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(52, 56, 68)
    toggleBtn.Text = ""
    toggleBtn.Parent = frame
    local tCorner = Instance.new("UICorner", toggleBtn); tCorner.CornerRadius = UDim.new(0, 10)
    local tStroke = Instance.new("UIStroke", toggleBtn); tStroke.Thickness = 1.2; tStroke.Color = Color3.fromRGB(80,85,100)

    local onOff = Instance.new("TextLabel")
    onOff.BackgroundTransparency = 1
    onOff.Position = UDim2.fromOffset(12, 8)
    onOff.Size = UDim2.fromOffset(80, 20)
    onOff.Font = Enum.Font.GothamSemibold
    onOff.TextSize = 18
    onOff.Text = "OFF"
    onOff.TextXAlignment = Enum.TextXAlignment.Left
    onOff.TextColor3 = Color3.fromRGB(235,235,240)
    onOff.Parent = toggleBtn

    -- Ô nhập số (0–180), đặt mặc định 150
    local valueBox = Instance.new("TextBox")
    valueBox.Name = "ValueBox"
    valueBox.Size = UDim2.fromOffset(70, 30)
    valueBox.Position = UDim2.new(1, -80, 0, 9)
    valueBox.TextEditable = true
    valueBox.ClearTextOnFocus = false
    valueBox.Text = tostring(config.SpeedBoost_Speed) -- 150 mặc định
    valueBox.PlaceholderText = "0–180"
    valueBox.Font = Enum.Font.GothamSemibold
    valueBox.TextSize = 16
    valueBox.TextColor3 = Color3.fromRGB(25,25,28)
    valueBox.BackgroundColor3 = Color3.fromRGB(80, 180, 120)
    valueBox.Parent = toggleBtn
    local vbCorner = Instance.new("UICorner", valueBox); vbCorner.CornerRadius = UDim.new(0, 8)
    local vbStroke = Instance.new("UIStroke", valueBox); vbStroke.Thickness = 1; vbStroke.Color = Color3.fromRGB(30,120,80)

    -- Nút Topbar tròn (hiện khi thu gọn)
    local topButton = Instance.new("TextButton")
    topButton.Name = "SB_TopButton"
    topButton.Text = "◯"
    topButton.Font = Enum.Font.GothamBold
    topButton.TextSize = 16
    topButton.TextColor3 = Color3.fromRGB(245,245,250)
    topButton.Size = UDim2.fromOffset(28, 28)
    topButton.Position = UDim2.new(0, 12, 0, 10) -- top-left
    topButton.BackgroundColor3 = Color3.fromRGB(42, 44, 52)
    topButton.Visible = false -- mặc định ẩn
    topButton.Parent = screenGui
    local topCorner = Instance.new("UICorner", topButton); topCorner.CornerRadius = UDim.new(1, 0)
    local topStroke = Instance.new("UIStroke", topButton); topStroke.Thickness = 1; topStroke.Color = Color3.fromRGB(80,85,100)

    --====================================================
    -- DRAG KHUNG (kéo ở header)
    --====================================================
    do
        local dragging = false
        local dragStart: Vector2 = Vector2.zero
        local startPos: UDim2 = frame.Position

        local function update(input)
            local delta = input.Position - dragStart
            frame.Position = UDim2.fromOffset(startPos.X.Offset + delta.X, startPos.Y.Offset + delta.Y)
        end

        header.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
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

        header.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                update(input)
            end
        end)
    end

    --====================================================
    -- HÀM TRỢ GIÚP: CẬP NHẬT UI & GIÁ TRỊ
    --====================================================
    local function setToggleVisual(on: boolean)
        onOff.Text = on and "ON" or "OFF"
        local toColor = on and Color3.fromRGB(80, 180, 120) or Color3.fromRGB(52, 56, 68)
        TweenService:Create(toggleBtn, TweenInfo.new(0.15), {BackgroundColor3 = toColor}):Play()
    end

    local function applyValueFromBox(applyNow: boolean)
        local n = tonumber(valueBox.Text)
        if not n then
            valueBox.Text = tostring(config.SpeedBoost_Speed)
            return
        end
        n = math.clamp(math.floor(n + 0.5), 0, 180)
        valueBox.Text = tostring(n)
        config.SpeedBoost_Speed = n
        PARAMS.EXTRA_SPEED = n
        saveConfig()
        if applyNow and config.Move_CFrame then
            boost:stop()
            startAllIfEnabled()
        end
    end

    -- Khởi tạo UI theo config
    setToggleVisual(config.Move_CFrame == true)

    --====================================================
    -- SỰ KIỆN: NÚT TOGGLE (click nền trái)
    --====================================================
    toggleBtn.MouseButton1Click:Connect(function()
        -- Nếu click vào vùng valueBox thì bỏ qua (để không lẫn với nhập số)
        local absPos = valueBox.AbsolutePosition
        local absSize = valueBox.AbsoluteSize
        local mouse = UserInputService:GetMouseLocation()
        if mouse.X >= absPos.X and mouse.X <= absPos.X + absSize.X and mouse.Y >= absPos.Y and mouse.Y <= absPos.Y + absSize.Y then
            return
        end

        local on = not config.Move_CFrame
        config.Move_CFrame = on
        saveConfig()
        setToggleVisual(on)

        if on then
            startAllIfEnabled()
        else
            stopAll()
        end
    end)

    -- Nhập số trực tiếp (0–180), áp dụng khi mất focus/Enter
    valueBox.FocusLost:Connect(function()
        applyValueFromBox(true)
    end)

    --====================================================
    -- THU GỌN: ẩn khung, hiện nút tròn topbar; bấm lại mở ra
    --====================================================
    local function collapse()
        frame.Visible = false
        topButton.Visible = true
    end
    local function expand()
        frame.Visible = true
        topButton.Visible = false
    end

    collapseBtn.MouseButton1Click:Connect(function()
        collapse()
    end)
    topButton.MouseButton1Click:Connect(function()
        expand()
    end)

    return screenGui
end

--========================================================
-- KHỞI TẠO UI & START THEO CONFIG
--========================================================
local ui = createUI()

if config.Move_CFrame then
    startAllIfEnabled()
end
