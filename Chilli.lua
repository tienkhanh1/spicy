-- Chilli.lua: Grow a Garden Helper Script with Fluent UI
local Fluent          = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Players         = game:GetService("Players")
local RS              = game:GetService("ReplicatedStorage")                                           -- alias cho require Remotes
local Remotes         = require(RS:WaitForChild("Modules"):WaitForChild("Remotes"))
local ReplicatedStore = RS    
local collectSend = Remotes.Crops.Collect.send
local Workspace       = game:GetService("Workspace")
local LocalPlayer     = Players.LocalPlayer
local PS = game:GetService("ProximityPromptService")
local Character       = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid        = Character:WaitForChild("Humanoid")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualInput = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService('VirtualUser')
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local gateway      = (Character:WaitForChild("InputGateway") or LocalPlayer.PlayerScripts.InputGateway):WaitForChild("Activation")
local autoFastHold = false
local extendRangeActive = false
local rangeLoop        
local showConn, hideConn, collectTask
local hrp = Character:WaitForChild("HumanoidRootPart")
local camera           = workspace.CurrentCamera
local isTeleporting = false
local weatherAttributes = {
    "MeteorShower",
    "Thunderstorm",
    "BloodMoonEvent",
    "FrostEvent",
    "RainEvent",
    "NightEvent",
    "Luck",
    "DiscoEvent",
}
local GameEvents = RS:WaitForChild("GameEvents")
local TeleportService = game:GetService("TeleportService")


do
    Players.LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0,0))
    end)
end

for _, name in ipairs(weatherAttributes) do
    if Workspace:GetAttribute(name) == nil then
        Workspace:SetAttribute(name, false)
    end
end

local Window = Fluent:CreateWindow({
    Title       = "Grow a Garden - Chilli GUI",
    SubTitle    = "Private Helper",
    TabWidth    = 160,
    Size        = UDim2.fromOffset(580, 460),
    Acrylic     = false,
    Theme       = "Light",
    MinimizeKey = Enum.KeyCode.LeftControl
})


local MainTab = Window:AddTab({ Title = "Chính", Icon = "leaf" })

local ShopTab = Window:AddTab({
    Title = "Shop",
    Icon  = "shopping-cart",   -- bạn có thể đổi icon tuỳ ý
})


local PlantTab = Window:AddTab({ Title = "Plant" })
local GearsTab = Window:AddTab({ Title = "Gear" })
local TeleportTab = Window:AddTab({ Title = "Teleport" })
local FavoriteTab = Window:AddTab({ Title = "Favorite" })
local RemoveTab = Window:AddTab({ Title = "Remove"})
local ServerTab = Window:AddTab({ Title = "Server"})



-- State
--------------------------------------------------------------------------------
-- BEGIN CONFIG SAVE/LOAD BOILERPLATE
--------------------------------------------------------------------------------
local HttpService    = game:GetService("HttpService")
local Players        = game:GetService("Players")
local LocalPlayer    = Players.LocalPlayer

local CONFIG_FOLDER  = "Chilli Hub"
local CONFIG_FILE    = LocalPlayer.Name .. ".json"
local CONFIG_PATH    = CONFIG_FOLDER .. "/" .. CONFIG_FILE

-- Tạo folder nếu chưa có
if writefile and not isfolder(CONFIG_FOLDER) then
    makefolder(CONFIG_FOLDER)
end

-- Load config nếu có
local config = {}
if isfile and isfile(CONFIG_PATH) then
    local ok, json = pcall(readfile, CONFIG_PATH)
    if ok then
        local suc, tbl = pcall(HttpService.JSONDecode, HttpService, json)
        if suc and type(tbl) == "table" then
            config = tbl
        end
    end
end

-- Khởi tạo default nếu key chưa tồn tại
config.AutoPlant      = config.AutoPlant      or false
config.AutoSell       = config.AutoSell       or false
config.SellThreshold  = config.SellThreshold  or 100
config.AutoBuySeed    = config.AutoBuySeed    or false
config.AutoBuyInStock = config.AutoBuyInStock or false
config.AutoPlantSeeds = config.AutoPlantSeeds or {}
config.SelectedSeeds = config.SelectedSeeds or {}
config.AutoPlantSeeds   = config.AutoPlantSeeds   or { All = true }
config.AutoPlantZones   = config.AutoPlantZones   or { ["Zone 1"] = true, ["Zone 2"] = true }


-- … tương tự cho tất cả các control của bạn …

-- Hàm lưu config
local function saveConfig()
    if writefile then
        writefile(CONFIG_PATH, HttpService:JSONEncode(config))
    end
end
--------------------------------------------------------------------------------
-- END CONFIG SAVE/LOAD BOILERPLATE
--------------------------------------------------------------------------------

local autoSell, autoBuySeed, autoPlant, autoCollect = false, false, false, false
local selectedSeed = "Carrot"

local function getMyFarm()
    for _, farm in ipairs(Workspace:WaitForChild("Farm"):GetChildren()) do
        local imp   = farm:FindFirstChild("Important")
        local data  = imp   and imp:FindFirstChild("Data")
        local owner = data  and data:FindFirstChild("Owner")
        if owner and owner:IsA("StringValue") and owner.Value == LocalPlayer.Name then
            return farm
        end
    end
end

-- ========== Fruit Count Paragraph ==========
local function countFruits()
    local c = 0
    for _, tool in ipairs(Players.LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            local name = tool.Name:lower()
            if name:find("kg") and not name:find("age") then
                c = c + 1
            end
        end
    end
    return c
end

local function itemCount()
    local count = 0
    for _, item in ipairs(Players.LocalPlayer.Backpack:GetChildren()) do
        if item:IsA("Tool") then
            local name = item.Name
            -- có dấu [ và không chứa "Age"
            if name:find("%[") and not name:lower():find("age") then
                count = count + 1
            end
        end
    end
    return count
end



local Section = MainTab:AddSection("Thu hoạch")
--==== Auto Collect VIP (FastHoldCollect + Mutation & Plant Filter) ====

-- 1) Danh sách cây & mutation (giữ nguyên)
local allPlantTypes = {
    "Carrot", "Strawberry", "Blueberry", "Orange Tulip", "Tomato", "Corn",
    "Daffodil", "Watermelon", "Pumpkin", "Apple", "Bamboo", "Coconut",
    "Cactus", "Dragon Fruit", "Mango", "Grape", "Mushroom", "Pepper",
    "Cacao", "Beanstalk", "Peach", "Pineapple", "Chocolate Carrot",
    "Red Lollipop", "Candy Sunflower", "Easter Egg", "Candy Blossom",
    "Raspberry", "Durian", "Cranberry", "Eggplant", "Lotus", "Venus Flytrap",
    "Rainbow Sack", "Papaya", "Passionfruit", "Banana", "Cursed Fruit",
    "Soul Fruit", "Nightshade", "Glowshroom", "Mint", "Moonflower",
    "Starfruit", "Moonglow", "Moon Blossom", "Blood Banana", "Moon Melon"
}

local allMutions = {
    "Celestial","Shocked","Rainbow","Gold","Frozen","Bloodlit","Wet",
    "Zombified","Chilled","Chocolate","Disco"
}

-- 2) Hàm lấy farm (giữ nguyên)
local function getMyFarm()
    for _, f in ipairs(workspace.Farm:GetChildren()) do
        local data = f:FindFirstChild("Important") and f.Important:FindFirstChild("Data")
        if data and data:FindFirstChild("Owner") and data.Owner.Value == LocalPlayer.Name then
            return f
        end
    end
end

local spawnPointPart
do
    local farm = getMyFarm()
    if farm then
        spawnPointPart = farm:WaitForChild("Spawn_Point")
    end
end

-- 3) Hàm tách Present/Absent (giữ nguyên)
local function splitPlantLists()
    local farm = getMyFarm()
    local seen = {}
    if farm then
        for _, mdl in ipairs(farm.Important:WaitForChild("Plants_Physical"):GetChildren()) do
            if mdl:IsA("Model") then seen[mdl.Name] = true end
        end
    end
    local pres, abs = {}, {}
    for _, name in ipairs(allPlantTypes) do
        if seen[name] then table.insert(pres, name)
        else               table.insert(abs,  name) end
    end
    return pres, abs
end

-- 4) State cho AutoCollect
local fastHoldActive = false
local blockedMutions  = {}
local blockedPlants  = {}
local weightThreshold = 20
local weatherOptions = {
    "MeteorShower",
    "Thunderstorm",
    "BloodMoonEvent",
    "FrostEvent",
    "RainEvent",
    "NightEvent",
    "Luck",
    "DiscoEvent",
}

local selectedWeather = {}
local scanChunks, scanIndex = {}, 1
local CHUNK_SIZE = 20

local function buildPromptChunks(phys)
    local all = phys:GetDescendants()
    scanChunks = {}
    for i = 1, #all, CHUNK_SIZE do
        local chunk = {}
        for j = i, math.min(i + CHUNK_SIZE - 1, #all) do
            table.insert(chunk, all[j])
        end
        table.insert(scanChunks, chunk)
    end
    scanIndex = 1
end

-- 5) FastHoldCollect toggle + scan/collect logic (giữ nguyên hoàn toàn)
MainTab:AddToggle("FastHoldCollect", {
    Title   = "Thu hoạch siêu nhanh",
    Default = false,
    Callback = function(state)
        fastHoldActive = state
        if state then
            local farm = getMyFarm()
            if not farm then return end
            local phys = farm.Important:WaitForChild("Plants_Physical")
            buildPromptChunks(phys)
            local promptQueue = {}
            local function scanPrompts()
                promptQueue = {}
            
                -- 0) Nếu weather active, abort
                for weatherName in pairs(selectedWeather) do
                    if workspace:GetAttribute(weatherName) then
                        return
                    end
                end
            
                -- 1) Lấy chunk hiện tại
                local chunk = scanChunks[scanIndex]
                if chunk then
                    for _, p in ipairs(chunk) do
                        if p:IsA("ProximityPrompt")
                        and p:HasTag("CollectPrompt")
                        and p.Enabled then
                            local mdl = p.Parent
                            while mdl and not mdl:IsA("Model") do mdl = mdl.Parent end
                            if not mdl then continue end
            
                            -- Lọc cân nặng
                            local weightNode = mdl:FindFirstChild("Weight", true)
                            if weightNode and weightNode.Value > weightThreshold then continue end
                            -- Lọc blockedPlants
                            if blockedPlants[mdl.Name] then continue end
                            -- Lọc mutation
                            local skip = false
                            local var  = mdl:FindFirstChild("Variant")
                            if var and (var.Value == "Gold" or var.Value == "Rainbow") then
                                skip = blockedMutions[var.Value]
                            else
                                for mut in pairs(blockedMutions) do
                                    if mut ~= "Gold" and mut ~= "Rainbow" and mdl:GetAttribute(mut) then
                                        skip = true; break
                                    end
                                end
                            end
                            if not skip then promptQueue[p] = true end
                        end
                    end
                end
            
                -- 2) Chuyển sang chunk kế (vòng lặp)
                scanIndex = scanIndex + 1
                if scanIndex > #scanChunks then
                    scanIndex = 1
                end
            end


            scanPrompts()
            task.spawn(function()
                while fastHoldActive do
                    task.wait(0.3)
                    scanPrompts()
                end
            end)

            local maxPerBatch     = 3
            local collectInterval = 0.050

            task.spawn(function()
                while fastHoldActive do

                    -- 0) Nếu đang có weather active, skip toàn bộ vòng này
                    local skipForWeather = false
                    for weatherName in pairs(selectedWeather) do
                        if workspace:GetAttribute(weatherName) then
                            skipForWeather = true
                            break
                        end
                    end
                    if skipForWeather then
                        task.wait(collectInterval)
                        continue
                    end

                    -- 1) Quét prompt mới sau khi đã chắc chắn không có weather active
                    promptQueue = {}
                    for _, p in ipairs(phys:GetDescendants()) do
                        if p:IsA("ProximityPrompt")
                        and p:HasTag("CollectPrompt")
                        and p.Enabled then

                            -- tìm model cha
                            local mdl = p.Parent
                            while mdl and not mdl:IsA("Model") do mdl = mdl.Parent end
                            if not mdl then continue end

                            -- lọc cân nặng
                            local weightNode = mdl:FindFirstChild("Weight", true)
                            if weightNode and weightNode.Value >= weightThreshold then
                                continue
                            end

                            -- lọc cây
                            if blockedPlants[mdl.Name] then
                                continue
                            end

                            -- lọc mutation
                            local skipMut = false
                            local var = mdl:FindFirstChild("Variant")
                            if var and (var.Value == "Gold" or var.Value == "Rainbow") then
                                if blockedMutions[var.Value] then skipMut = true end
                            else
                                for mut in pairs(blockedMutions) do
                                    if mut ~= "Gold" and mut ~= "Rainbow" and mdl:GetAttribute(mut) then
                                        skipMut = true
                                        break
                                    end
                                end
                            end
                            if skipMut then continue end

                            -- nếu qua hết, thêm vào hàng đợi
                            promptQueue[p] = true
                        end
                    end

                    -- 2) Gom các model cần collect
                    local toCollect = {}
                    for p in pairs(promptQueue) do
                        if p.Enabled then
                            local mdl = p.Parent
                            while mdl and not mdl:IsA("Model") do mdl = mdl.Parent end
                            if mdl then table.insert(toCollect, mdl) end
                        end
                    end

                    -- 3) Gửi theo từng batch
                    for i = 1, #toCollect, maxPerBatch do
                        if not fastHoldActive then break end
                        local abort = false
                        for weatherName in pairs(selectedWeather) do
                            if workspace:GetAttribute(weatherName) then
                                abort = true
                                break
                            end
                        end
                        if abort then
                            -- xóa queue để không gửi thêm
                            promptQueue = {}
                            break
                        end
                    
                        local batch = {}

                        for j = i, math.min(i + maxPerBatch - 1, #toCollect) do
                            batch[#batch+1] = toCollect[j]
                        end
                        collectSend(batch)
                        task.wait(collectInterval)
                    end
                    task.wait(collectInterval)
                end
            end)
        else
            fastHoldActive = false
        end
    end
})

MainTab:AddInput("WeightFilterInput", {
    Title       = "Lọc trái theo cân nặng (kg)",
    Description = "Không thu hoạch trái ≥ kg",
    Placeholder = "Nhập số kg",
    Default     = config.WeightFilterInput or tostring(weightThreshold),
    Numeric = true, -- Only allows numbers
    Callback    = function(value)
        local v = tonumber(value)
        if v then
            weightThreshold = v
            config.WeightFilterInput = v
            saveConfig(config)
            print("✔ Ngưỡng cân nặng set:", v, "kg")

        else
            -- nếu nhập không phải số, giữ nguyên
            warn("Chỉ nhập số cho ngưỡng kg")
        end
    end
})

-- Dropdown mutation
MainTab:AddDropdown("MutionFilter", {
    Title       = "Lọc đột biến",
    Description = "Bỏ qua thu hoạch",
    Values      = allMutions,
    Multi       = true,
    Default     = {},
    Callback    = function(sel)
        blockedMutions = {}
        -- sel có dạng map[name] = true/false
        for name, isSel in pairs(sel) do
            if isSel then
                blockedMutions[name] = true
            end
        end
        warn("[Filter] blockedMutions =", table.concat(
            (function()
                local t={}
                for n,_ in pairs(blockedMutions) do table.insert(t,n) end
                return t
            end)(), ", "
        ))
    end
})


local weatherDropdown = MainTab:AddDropdown("WeatherFilter", {
    Title       = "Lọc thời tiết",
    Description = "Không thu hoạch khi thời tiết được chọn hiển thị",
    Values      = weatherOptions,
    Multi       = true,
    Default     = {},
})
weatherDropdown:OnChanged(function(val)
    selectedWeather = {}
    for name, on in pairs(val) do
        if on then selectedWeather[name] = true end
    end
end)

-- Dropdown cây
do
    local pres, abs = splitPlantLists()
    local combined = {}
    for _,v in ipairs(pres) do table.insert(combined, v) end
    for _,v in ipairs(abs)  do table.insert(combined, v) end

    MainTab:AddDropdown("PlantFilter", {
        Title       = "Lọc cây",
        Description = "Bỏ qua thu hoạch",
        Values      = combined,
        Multi       = true,
        Default     = {},
        Callback    = function(sel)
            blockedPlants = {}
            for name, isSel in pairs(sel) do
                if isSel then
                    blockedPlants[name] = true
                end
            end
            warn("[Filter] blockedPlants =", table.concat(
                (function()
                    local t={}
                    for n,_ in pairs(blockedPlants) do table.insert(t,n) end
                    return t
                end)(), ", "
            ))
        end
    })
end





local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "OpenButtonGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local button = Instance.new("ImageButton")
button.Size = UDim2.new(0, 50, 0, 50)
button.Position = UDim2.new(0, 20, 0, 250)
button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
button.BackgroundTransparency = 0.25
button.Image = "rbxassetid://128961717706452" -- Để trống hoặc dùng icon tròn tùy bạn
button.Name = "FloatingToggle"
button.Active = true
button.Draggable = true
button.Parent = gui

-- Làm nút thành hình tròn
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = button

-- Khi nhấn vào, giả lập nhấn RightControl
button.MouseButton1Click:Connect(function()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
    task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
end)
