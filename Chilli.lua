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

local Section = PlantTab:AddSection("Random Plant")
-- ======= Seed lựa chọn để trồng (Multi-Dropdown) =======
local seedOptions = {
    "All", "Carrot","Chocolate Carrot","Strawberry","Red Lollipop","Nightshade",
    "Blueberry","Orange Tulip","Tomato","Raspberry","Candy Sunflower",
    "Glowshroom","Corn","Daffodil","Watermelon","Pumpkin","Apple","Bamboo",
    "Peach","Pineapple","Dragon Fruit","Cactus","Coconut","Mango","Grape",
    "Mushroom","Pepper","Cacao","Beanstalk","Easter Egg","Candy Blossom",
    "Durian","Cranberry","Eggplant","Lotus","Venus Flytrap","Rainbow Sack",
    "Papaya","Passionfruit","Banana","Cursed Fruit","Soul Fruit","Mint",
    "Moonflower","Starfruit","Moonglow","Moon Blossom","Blood Banana","Moon Melon"
}
local selectedSeedsMap = {}
local selectedSeedsList = {}

-- ======= Auto Plant (có filter seed) =======
-- Trước tất cả, sau getMyFarm(), xác định spawnPointPart:
local spawnPointPart
do
    local farm = getMyFarm()
    if farm then
        spawnPointPart = farm:WaitForChild("Spawn_Point")
    end
end

-- Thêm vào sau phần khởi tạo các Toggle khác

-- State cho AutoSpamEgg
local autoSpamEgg = false

-- Chèn ngay dưới định nghĩa isTeleport và các toggle khác
local selectedPlantZones = {}

-- ======= Auto Plant (có filter seed + teleport) =======
local plantseedA = PlantTab:AddToggle("AutoPlant", {
    Title   = "Tự động trồng",
    Description = "Vị trí ngẫu nhiên",
    Default = config.AutoPlant,
    Callback = function(state)
        config.AutoPlant = state
        saveConfig()
        autoPlant = state
        if state then
            task.spawn(function()
                local farm = getMyFarm()
                if not farm then return end

                -- Lấy tất cả CFrame điểm trồng
                local centers = {}
                for _, cp in ipairs(farm.Important.Plant_Locations:GetChildren()) do
                    if cp.Name == "Can_Plant" and cp:IsA("BasePart") then
                        table.insert(centers, cp.CFrame)
                    end
                end

                -- Hàm tìm tool thỏa filter
                local function findSeedTool()
                    for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
                        if tool:IsA("Tool") and tool.Name:find("%[X%d+%]") then
                            local name = tool.Name:match("^(.-)%sSeed")
                            if not name then continue end
                            if selectedSeedsMap[name] then
                                return tool, name
                            end
                        end
                    end
                    for _, tool in ipairs(Character:GetChildren()) do
                        if tool:IsA("Tool") and tool.Name:find("%[X%d+%]") then
                            local name = tool.Name:match("^(.-)%sSeed")
                            if not name then continue end
                            if next(selectedSeedsMap) == nil or selectedSeedsMap[name] then
                                return tool, name
                            end
                        end
                    end
                end

                -- Hàm random điểm trồng
                local sizeX, sizeY, sizeZ = 30.5, 0.001, 59
                local function randomPoint(cf)
                    local hx, hy, hz = sizeX/2, sizeY/2, sizeZ/2
                    return (cf * CFrame.new(
                        (math.random()*2-1)*hx,
                        (math.random()*2-1)*hy,
                        (math.random()*2-1)*hz
                    )).Position
                end

                -- Hàm plant
                local function plantAt(pos, name)
                    ReplicatedStore.GameEvents.Plant_RE:FireServer(pos, name)
                    local cf = CFrame.new(pos)
                    local gateway = Character.InputGateway or LocalPlayer.PlayerScripts.InputGateway
                    for _, s in ipairs({true,false}) do
                        gateway.Activation:FireServer(s, cf)
                        task.wait(0.01)
                    end
                end
                
                local lastTp = 0

                -- Vòng lặp autoPlant
                while autoPlant do
                    if next(selectedSeedsMap) == nil then
                        warn("[AutoPlant] No seed selected → skipping entire cycle")
                        task.wait(1)
                        continue
                    end
                    -- 0) Nếu chưa chọn zone nào → skip toàn bộ, chờ rồi tiếp
                    if #selectedPlantZones == 0 then
                        warn("[AutoPlant] No zone selected → skipping entire cycle")
                        task.wait(1)
                        continue
                    end

                    -- 1) Tìm tool và seed hợp lệ
                    local tool, seedName = findSeedTool()
                    if tool and seedName then
                        -- 2) Đợi nếu đang teleport
                        while isTeleport do task.wait() end
                        isTeleport = true

                        -- 3) Teleport nếu đã chọn zone
                        if spawnPointPart and tick() - lastTp >= 5 then
                            hrp.CFrame = spawnPointPart.CFrame + Vector3.new(0, -2, 0)
                            task.wait(0.05)
                            lastTp = tick()
                        end

                        -- 4) Equip tool (chỉ khi đã có zone)
                        Humanoid:EquipTool(tool)
                        task.wait(0.1)

                        -- 5) Lọc centers theo zone
                        local usable = {}
                        for i, cf in ipairs(centers) do
                            local zoneName = "Zone " .. tostring(i)
                            if table.find(selectedPlantZones, zoneName) then
                                table.insert(usable, cf)
                            end
                        end

                        -- 6) Plant hoặc skip
                        if #usable == 0 then
                            warn("[AutoPlant] No usable zone → skipping planting")
                        else
                            local cfCenter = usable[math.random(#usable)]
                            plantAt(randomPoint(cfCenter), seedName)
                        end

                        task.wait(0.1)
                        isTeleport = false
                    else
                        -- 7) Không tìm thấy tool → đợi
                        task.wait(3)
                    end
                end
            end)
        end
    end
})

local zoneDropdown = PlantTab:AddDropdown("AutoPlantZones", {
    Title       = "Chọn zone trồng",
    Description = "Chọn 1 hoặc cả 2 zone để AutoPlant",
    Values      = { "Zone 1", "Zone 2" },
    Multi       = true,
    Default     = config.AutoPlantZones,
    Callback    = function(val)
        selectedPlantZones = {}
        for zone,on in pairs(val) do
            if on then selectedPlantZones[#selectedPlantZones+1] = zone end
        end
        config.AutoPlantZones = val; saveConfig()
        warn("[AutoPlant] Zones:", table.concat(selectedPlantZones, ", "))
    end
})
zoneDropdown:SetValue(config.AutoPlantZones)
-- Tạo dropdown
local seedDropdown = PlantTab:AddDropdown("AutoPlantSeeds", {
    Title       = "Chọn seed muốn trồng",
    Description = "All = trồng tất cả seed",
    Values      = seedOptions,
    Multi       = true,
    Default     = config.AutoPlantSeeds,
    Callback    = function(val)
        selectedSeedsMap, selectedSeedsList = {}, {}
        if val["All"] then
            for _,name in ipairs(seedOptions) do
                if name~="All" then
                    selectedSeedsMap[name]=true
                    table.insert(selectedSeedsList,name)
                end
            end
        else
            for name,on in pairs(val) do
                if on and name~="All" then
                    selectedSeedsMap[name]=true
                    table.insert(selectedSeedsList,name)
                end
            end
        end
        config.AutoPlantSeeds = val; saveConfig()
        warn("[AutoPlant] Seeds filter:", table.concat(selectedSeedsList, ", "))
    end
})
seedDropdown:SetValue(config.AutoPlantSeeds)


local Section = MainTab:AddSection("Bán trái")
-- ========== Sell Slider & Auto Sell Liên Tục với Spam ==========
local sellThreshold     = config.SellThreshold

MainTab:AddButton({
    Title       = "Bán ngay lập tức",
    Description = "Spam lệnh bán 0.1s x 5 lần, sau đó TP về vị trí cũ",
    Callback    = function()
        -- 1) Lưu vị trí hiện tại
        local originalCFrame = hrp.CFrame
        print("[Sell Now] Saved original position")

        -- 2) Tìm NPC Steven
        local steven = Workspace:WaitForChild("NPCS"):WaitForChild("Steven")
        local targetPart = steven:FindFirstChild("HumanoidRootPart")
                          or steven:FindFirstChildWhichIsA("BasePart")
        if not targetPart then
            warn("[Sell Now] Không tìm thấy Steven!")
            return
        end

        -- 3) Tạo CFrame TP đến Steven
        local backOffset = -targetPart.CFrame.LookVector * 3
        local tpCFrame  = CFrame.new(targetPart.Position + backOffset, targetPart.Position)

        -- 4) Teleport đến Steven
        hrp.CFrame = tpCFrame
        task.wait(0.05)

        -- 5) Spam bán trong 0.5s, 0.1s/lần
        local t0 = tick()
        while tick() - t0 < 0.5 do
            pcall(function()
                ReplicatedStore.GameEvents.Sell_Inventory:FireServer()
            end)
            task.wait(0.05)
        end
        print("[Sell Now] Finished spamming Sell_Inventory")

        hrp.CFrame = originalCFrame
        task.wait(0.01)
        hrp.CFrame = originalCFrame

        print("[Sell Now] Returned to original position")
    end
})

MainTab:AddToggle("AutoSell", {
    Title   = "Tự động bán trái",
    Default = config.AutoSell,
    Callback = function(state)
        config.AutoSell = state
        saveConfig()
        autoSell = state

        if state then
            task.spawn(function()
                local hrp = Character:WaitForChild("HumanoidRootPart")
                local steven = Workspace:WaitForChild("NPCS"):WaitForChild("Steven")
                local targetPart = steven:FindFirstChild("HumanoidRootPart")
                                  or steven:FindFirstChildWhichIsA("BasePart")
                if not targetPart then
                    warn("❌ Không tìm thấy Steven!")
                    return
                end

                -- chuẩn bị vị trí teleport 1 lần
                local backOffset = -targetPart.CFrame.LookVector * 3
                local upOffset   = Vector3.new(0, 0, 0)
                local tpCFrame   = CFrame.new(targetPart.Position + backOffset + upOffset, targetPart.Position)
                
                while autoSell do
                    local fruitCount    = countFruits()
                    local fullItemCount = itemCount()

                    if fruitCount >= sellThreshold or fullItemCount >= 190 then
                        
                        -- 1) Teleport một lần
                        while isTeleport do task.wait() end
                        isTeleport = true

                        hrp.CFrame = tpCFrame
                        task.wait(0.01)

                        -- 2) Gửi lệnh bán một lần
                        pcall(function()
                            ReplicatedStore.GameEvents.Sell_Inventory:FireServer()
                        end)
                        task.wait(0.1)
                        pcall(function()
                            ReplicatedStore.GameEvents.Sell_Inventory:FireServer()
                        end)
                        -- 3) Chờ 5 giây rồi kiểm lại
                        local before = fruitCount
                        task.wait(2)

                        -- 4) Nếu vẫn chưa bán được (count ≥ before), bán lại
                        if countFruits() >= before then
                            pcall(function()
                                ReplicatedStore.GameEvents.Sell_Inventory:FireServer()
                            end)
                        end
                        isTeleport = false
                    end

                    task.wait(0.1)
                end
            end)
        end
    end
})


local thresholdSlider = MainTab:AddSlider("FruitSellThreshold", {
    Title       = "Ngưỡng bán trái",
    Description = ("Số trái hiện có: %d"):format(countFruits()),
    Default     = config.SellThreshold or 100,
    Min         = 1,
    Max         = 200,
    Rounding    = 0,
    Callback    = function(value)
        config.SellThreshold = value
        saveConfig()
        sellThreshold = value
        print("[AutoSell] SellThreshold set to", value)
    end
})

-- Đảm bảo UI khởi đúng giá trị đã lưu:
thresholdSlider:SetValue(config.SellThreshold or 100)


task.spawn(function()
    while true do
        local current = countFruits()
        thresholdSlider:SetDesc(("Số trái hiện có: %d"):format(current))
        task.wait(0.5)
    end
end)

local Section = ShopTab:AddSection("Fruits Shop")
-- ========== Auto Buy ==========
-- Danh sách seed (theo thứ tự ưu tiên từ trên xuống)

local seedList = {
    "Carrot","Strawberry","Blueberry","Orange Tulip","Tomato","Corn",
    "Daffodil","Watermelon","Pumpkin","Apple","Bamboo","Coconut",
    "Cactus","Dragon Fruit","Mango","Grape","Mushroom","Pepper",
    "Cacao","Beanstalk"
}
local selectedSeeds = {} 


-- 0) Toggle Auto Buy All Seeds
-- Toggle: Tự động mua tất cả seed đang có stock trong shop
local buyseeds = ShopTab:AddToggle("AutoBuyInStock", {
    Title   = "Tự động mua tất cả các seed",
    Default = config.AutoBuyInStock,
    Callback = function(state)
        config.AutoBuyInStock = state
        saveConfig()
        autoBuyInStock = state
        if state then
            task.spawn(function()
                -- Lấy đường dẫn tới ScrollingFrame của shop
                local shopGuiRoot = LocalPlayer:WaitForChild("PlayerGui")
                                          :WaitForChild("Seed_Shop")
                                          :WaitForChild("Frame")
                                          :WaitForChild("ScrollingFrame")
                while autoBuyInStock do
                    for _, fruitFrame in ipairs(shopGuiRoot:GetChildren()) do
                        if fruitFrame:IsA("Frame") then
                            local mainF = fruitFrame:FindFirstChild("Main_Frame")
                            local stockT = mainF and mainF:FindFirstChild("Stock_Text")
                            if stockT and type(stockT.Text) == "string" then
                                -- tìm "X<number> Stock"
                                local num = stockT.Text:match("X(%d+)%sStock")
                                num = tonumber(num)
                                if num and num > 0 then
                                    -- fruitFrame.Name chính là tên seed để mua
                                    pcall(function()
                                        ReplicatedStore.GameEvents.BuySeedStock:FireServer(fruitFrame.Name)
                                    end)
                                    task.wait(0.01)  -- đợi giữa mỗi lần mua
                                end
                            end
                        end
                    end
                    task.wait(0.01)  -- quét lại sau 2s
                end
            end)
        end
    end
})

-- 2) Toggle Auto Buy đặt lên đầu
-- ======= Toggle AutoBuySeed =======
local buyseed = ShopTab:AddToggle("AutoBuySeed", {
    Title   = "Tự động mua seed được chọn",
    Default = config.AutoBuySeed,
    Callback = function(state)
        config.AutoBuySeed = state
        saveConfig()
        autoBuySeed = state

        if state then
            task.spawn(function()
                local shopGuiRoot = LocalPlayer:WaitForChild("PlayerGui")
                                          :WaitForChild("Seed_Shop")
                                          :WaitForChild("Frame")
                                          :WaitForChild("ScrollingFrame")
                -- cho GUI kịp render
                task.wait(0.5)

                while autoBuySeed do
                    -- mua lần lượt từng seed được chọn
                    for _, fruitFrame in ipairs(shopGuiRoot:GetChildren()) do
                        if fruitFrame:IsA("Frame") then
                            local name = fruitFrame.Name
                            if selectedSeeds[name] then
                                local stockT = fruitFrame.Main_Frame:FindFirstChild("Stock_Text")
                                local num    = tonumber(stockT.Text:match("X(%d+)%sStock")) or 0
                                if num > 0 then
                                    pcall(function()
                                        ReplicatedStore.GameEvents.BuySeedStock:FireServer(name)
                                    end)
                                    task.wait(0.1)
                                end
                            end
                        end
                    end
                    -- chờ 5s rồi quét lại
                    task.wait(0.01)
                end
            end)
        end
    end
})

buyseeds:OnChanged(function(state)
    if state then
        -- nếu bật A thì tắt B, UI sẽ tự update
        buyseed:SetValue(false)
    end
end)

buyseed:OnChanged(function(state)
    if state then
        -- nếu bật A thì tắt B, UI sẽ tự update
        buyseeds:SetValue(false)
    end
end)

config.SeedSelectMulti = config.SeedSelectMulti or {}
-- 3) Multi‑Dropdown chọn seed
local dropdown = ShopTab:AddDropdown("SeedSelectMulti", {
    Title       = "Chọn seed muốn mua",
    Description = "",
    Values      = seedList,
    Multi       = true,
    Default     = {},
    Callback    = function(sel)
        config.SeedSelectMulti = sel
        saveConfig()

        selectedSeeds = {}
        for name, on in pairs(sel) do
            if on then
                selectedSeeds[name] = true
            end
        end
    end
})

-- Gán config đã lưu vào UI
dropdown:SetValue(config.SeedSelectMulti)


config.AutoBuyEggSelection = config.AutoBuyEggSelection or { All = true }  -- load default
local selectedEggs = config.AutoBuyEggSelection

-- ======= Thiết lập danh sách trứng =======
local Section = ShopTab:AddSection("Egg")
-- ==== Danh sách trứng để mua ====
local eggOptions = {
    "All",
    "Common Egg",
    "Uncommon Egg",
    "Rare Egg",
    "Legendary Egg",
    "Mythical Egg",
    "Bug Egg",
}

-- map selection
local selectedEggs = {}

-- Toggle Auto-Buy Egg
ShopTab:AddToggle("AutoBuyEgg", {
    Title   = "Tự động mua trứng",
    Default = config.AutoBuyEgg,
    Callback = function(state)
        config.AutoBuyEgg = state
        saveConfig()
        autoBuyEgg = state

        if state then
            task.spawn(function()
                local stand = workspace:WaitForChild("NPCS")
                                  :WaitForChild("Pet Stand")
                                  :WaitForChild("EggLocations")
                task.wait(0.5)

                while autoBuyEgg do
                    for i = 4, math.min(#stand:GetChildren(), 6) do
                        local eggModel = stand:GetChildren()[i]
                        local eggName  = eggModel.Name
                        if selectedEggs[eggName] then
                            local arg = i - 3
                            pcall(function()
                                ReplicatedStore.GameEvents.BuyPetEgg:FireServer(arg)
                            end)
                            task.wait(0.1)
                        end
                    end
                    task.wait(1)
                end
            end)
        end
    end
})


-- ==== Multi-Dropdown chọn trứng ====
local eggselectDropdown = ShopTab:AddDropdown("AutoBuyEggSelect", {
    Title       = "Chọn trứng muốn mua",
    Description = "Không chọn = không mua",
    Values      = eggOptions,
    Multi       = true,
    Default     = config.AutoBuyEggSelection,
    Callback    = function(val)
        -- lưu config ngay
        config.AutoBuyEggSelection = val
        saveConfig()

        -- rebuild selectedEggs map
        selectedEggs = {}
        if val["All"] then
            for _, name in ipairs(eggOptions) do
                if name ~= "All" then
                    selectedEggs[name] = true
                end
            end
        else
            for name,on in pairs(val) do
                if on and name ~= "All" then
                    selectedEggs[name] = true
                end
            end
        end

        warn("[AutoBuyEgg] Selected:", next(selectedEggs) and table.concat((function()
            local t={}
            for n in pairs(selectedEggs) do table.insert(t,n) end
            return t
        end)(), ", ") or "None")
    end
})
eggselectDropdown:SetValue(config.AutoBuyEggSelection)





local Section = MainTab:AddSection("Pet")
-- Toggle Auto-Feed All My Pets
-- ======== Config mặc định ========
config.AutoFeedAllPets      = config.AutoFeedAllPets      or false
config.FeedFruitFilter      = config.FeedFruitFilter      or {}
config.FeedPerPet           = config.FeedPerPet           or 3
config.FeedInterval         = config.FeedInterval         or 20

-- Biến runtime
local autoFeedAllPets       = config.AutoFeedAllPets
local selectedFruitFilter   = config.FeedFruitFilter
local fruitsPerPet          = config.FeedPerPet
local feedInterval          = config.FeedInterval

-- Danh sách options trái cây
local fruitFilterOptions = {
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


-- ===== Toggle Auto-Feed All My Pets =====
MainTab:AddToggle("AutoFeedAllPets", {
    Title   = "Tự cho pet ăn",
    Default = config.AutoFeedAllPets,
    Callback = function(state)
        autoFeedAllPets      = state
        config.AutoFeedAllPets = state
        saveConfig()

        if state then
            task.spawn(function()
                local svc = ReplicatedStore.GameEvents.ActivePetService

                -- Hàm lấy UUID pet mình
                local function getMyPetUUIDs()
                    local uuids = {}
                    for _, mover in ipairs(workspace.PetsPhysical:GetChildren()) do
                        if mover.Name == "PetMover"
                        and mover:GetAttribute("OWNER") == LocalPlayer.Name then
                            table.insert(uuids, mover:GetAttribute("UUID"))
                        end
                    end
                    return uuids
                end

                -- Hàm lấy fruits (đã bao gồm filter)
                local function getFruitTools()
                    local out = {}
                    for _, container in ipairs({LocalPlayer.Backpack, Character}) do
                        for _, tool in ipairs(container:GetChildren()) do
                            if tool:IsA("Tool")
                            and tool.Name:lower():find("kg")
                            and not tool.Name:find("Age") then

                                -- nếu có filter thì chỉ lấy tool khớp 1 trong các tên được chọn
                                if next(selectedFruitFilter) then
                                    local found = false
                                    for fruitName in pairs(selectedFruitFilter) do
                                        if tool.Name:find(fruitName) then
                                            found = true
                                            break
                                        end
                                    end
                                    if not found then
                                        continue
                                    end
                                end

                                table.insert(out, tool)
                            end
                        end
                    end
                    return out
                end

                local petUUIDs = getMyPetUUIDs()
                if #petUUIDs == 0 then
                    warn("Bạn không có pet nào để cho ăn!")
                    return
                end

                while autoFeedAllPets do
                    local fruits = getFruitTools()
                    if #fruits == 0 then
                        warn("Không có trái nào để cho ăn!")
                        task.wait(feedInterval)
                    else
                        local idxFruit = 1
                        -- mỗi pet ăn fruitsPerPet lần
                        for _, uuid in ipairs(petUUIDs) do
                            for i = 1, fruitsPerPet do
                                local tool = fruits[((idxFruit-1) % #fruits) + 1]
                                Humanoid:EquipTool(tool)
                                task.wait(0.001)
                                pcall(function()
                                    svc:FireServer("Feed", uuid)
                                end)
                                idxFruit = idxFruit + 1
                                task.wait(0.2)
                            end
                        end
                        -- xong 1 chu kỳ, chờ feedInterval giây
                        task.wait(feedInterval)
                    end
                end
            end)
        end
    end
})

-- ===== Dropdown Lọc Trái =====
local ddFilter = MainTab:AddDropdown("FeedFruitFilter", {
    Title       = "Lọc trái cho ăn",
    Description = "Chỉ cho ăn các trái được chọn",
    Values      = fruitFilterOptions,
    Multi       = true,
    Default     = config.FeedFruitFilter,
    Callback    = function(sel)
        selectedFruitFilter = {}
        for name, on in pairs(sel) do
            if on then selectedFruitFilter[name] = true end
        end
        config.FeedFruitFilter = sel
        saveConfig()
    end
})
-- Set lại giá trị từ config khi khởi tạo
ddFilter:SetValue(config.FeedFruitFilter)

-- ===== Slider: Số trái pet ăn mỗi chu kỳ =====
local s1 = MainTab:AddSlider("FeedPerPetSlider", {
    Title    = "Số trái pet ăn mỗi chu kỳ",
    Description = "Mỗi chu kỳ cho mỗi pet ăn đúng số lượng được chọn",
    Default  = config.FeedPerPet,
    Min      = 1,
    Max      = 10,
    Rounding = 0,
    Callback = function(v)
        fruitsPerPet = v
        config.FeedPerPet = v
        saveConfig()
    end
})
s1:SetValue(config.FeedPerPet)

-- ===== Slider: Khoảng cách giữa các chu kỳ =====
local s2 = MainTab:AddSlider("FeedIntervalSlider", {
    Title    = "Khoảng cách giữa các chu kỳ (s)",
    Description = "Thời gian chờ giữa mỗi lần cho pet ăn",
    Default  = config.FeedInterval,
    Min      = 1,
    Max      = 200,
    Rounding = 0,
    Callback = function(v)
        feedInterval = v
        config.FeedInterval = v
        saveConfig()
    end
})
s2:SetValue(config.FeedInterval)



local Section = MainTab:AddSection("Egg")
-- Sau khi đã require các service và định nghĩa getMyFarm(), HRP, VirtualInputManager, PS, … 
-- Khởi mặc định config cho lọc rarity nếu chưa có
config.EggRarityFilter = config.EggRarityFilter or {}
config.AutoPlantEgg = config.AutoPlantEgg or {}
-- 1) Định nghĩa danh sách rarity
local rarityList = {
    "Common", "Uncommon", "Rare", "Legendary", "Mythical", "Bug"
}
local selectedRarities = {}

-- 2) Tạo Multi‑Dropdown lọc rarity
local ddRarity = MainTab:AddDropdown("EggRarityFilter", {
    Title       = "Chọn rarity đặt Egg",
    Description = "Tool có tên chứa rarity sẽ được sử dụng",
    Values      = rarityList,
    Multi       = true,
    Default     = config.EggRarityFilter,
    Callback    = function(sel)
        selectedRarities = sel
        -- Lưu lại config
        config.EggRarityFilter = sel
        saveConfig()
    end
})
-- Set value ban đầu theo config
ddRarity:SetValue(config.EggRarityFilter)
-- Chèn ngay dưới định nghĩa isTeleport và các toggle khác

local autoPlantEgg = false

MainTab:AddToggle("AutoPlantEgg", {
    Title   = "Tự động đặt Egg (theo rarity)",
    Default = config.AutoPlantEgg or false,
    Callback = function(state)
        autoPlantEgg = state
        config.AutoPlantEgg = state
        saveConfig()
        if state then
            task.spawn(function()
                local farm = getMyFarm()
                if not farm then return end

                -- 1) Lấy các điểm đặt
                local centers = {}
                for _, cp in ipairs(farm.Important:WaitForChild("Plant_Locations"):GetChildren()) do
                    if cp.Name == "Can_Plant" and cp:IsA("BasePart") then
                        centers[#centers+1] = cp.CFrame
                    end
                end
                if #centers == 0 then return end

                -- 2) Chuẩn bị remote và hàm random
                local RS = game:GetService("ReplicatedStorage")
                local PetEggSvc = RS:WaitForChild("GameEvents"):WaitForChild("PetEggService")
                local eggAction = "CreateEgg"
                local sizeX, sizeY, sizeZ = 30.5, 0.001, 59
                local function randomPoint(cf)
                    local hx, hy, hz = sizeX/2, sizeY/2, sizeZ/2
                    return (cf * CFrame.new(
                        (math.random()*2-1)*hx,
                        (math.random()*2-1)*hy,
                        (math.random()*2-1)*hz
                    )).Position
                end

                while autoPlantEgg do
                    -- —— KIỂM TRA SỐ SLOT TRỨNG HIỆN TẠI ——  
                    local gui = LocalPlayer.PlayerGui:FindFirstChild("Shop_UI")
                    local amountText = ""
                    if gui then
                        local slot = gui.Frame:FindFirstChild("ScrollingFrame")
                                    :FindFirstChild("PetProducts")
                                    :FindFirstChild("List")
                                    :FindFirstChild("EggSlot")
                                    :FindFirstChild("Amount")
                        amountText = slot and slot.Text or ""
                    end
                    -- parse "X/Y"
                    local cur,max = amountText:match("(%d+)%s*/%s*(%d+)")
                    cur, max = tonumber(cur) or 0, tonumber(max) or 0
                    -- trước đây freeSlots = max - cur
                    -- giờ freeSlots = cur + 3
                    local freeSlots = cur + 3

                    -- đếm trứng đang hiện hữu trong workspace
                    local physEggs = farm.Important:WaitForChild("Objects_Physical")
                    local existing = 0
                    for _, mdl in ipairs(physEggs:GetChildren()) do
                        if mdl.Name == "PetEgg" then existing = existing + 1 end
                    end

                    -- nếu đã đầy thì chờ, không đặt thêm
                    if freeSlots <= 0 or existing >= freeSlots then
                        task.wait(2)
                        continue
                    end

                    -- —— ĐẶT TRỨNG ——  
                    if next(selectedRarities) == nil then
                        -- đặt tất cả egg tool
                        for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
                            if not autoPlantEgg then break end
                            if tool:IsA("Tool") and tool.Name:find("Egg") then
                                while isTeleport do task.wait(0.02) end
                                isTeleport = true

                                Humanoid:EquipTool(tool)
                                task.wait(0.05)
                                local pos = randomPoint(centers[math.random(#centers)])
                                pcall(function()
                                    PetEggSvc:FireServer(eggAction, pos)
                                end)
                                task.wait(0.1)

                                isTeleport = false

                                -- giảm free slot ảo để tránh đặt vượt
                                existing = existing + 1
                                if existing >= freeSlots then break end
                            end
                        end
                    else
                        -- đặt theo rarity đã chọn
                        local function findEggToolByRarity(rarity)
                            for _, container in ipairs({LocalPlayer.Backpack, Character}) do
                                for _, tool in ipairs(container:GetChildren()) do
                                    if tool:IsA("Tool") and tool.Name:find(rarity) then
                                        return tool
                                    end
                                end
                            end
                        end

                        for rarity, enabled in pairs(selectedRarities) do
                            if not autoPlantEgg then break end
                            if enabled then
                                local tool = findEggToolByRarity(rarity)
                                if tool then
                                    while isTeleport do task.wait(0.02) end
                                    isTeleport = true

                                    Humanoid:EquipTool(tool)
                                    task.wait(0.05)
                                    local pos = randomPoint(centers[math.random(#centers)])
                                    pcall(function()
                                        PetEggSvc:FireServer(eggAction, pos)
                                    end)
                                    task.wait(0.1)

                                    isTeleport = false

                                    existing = existing + 1
                                    if existing >= freeSlots then break end
                                end
                            end
                        end
                    end

                    -- đợi chút rồi loop lại
                    task.wait(0.5)
                end

                -- khi tắt
                isTeleport = false
            end)
        else
            autoPlantEgg = false
            isTeleport = false
        end
    end
})


-- ========== Auto Hatch Eggs ==========

config.AutoHatchEgg = config.AutoHatchEgg or false

-- === 1) UI: Toggle AutoHatchEgg ===
MainTab:AddToggle("AutoHatchEgg", {
    Title   = "Auto Hatch Egg",
    Default = config.AutoHatchEgg,
    Callback = function(state)
        config.AutoHatchEgg = state
        saveConfig()
        autoHatchEgg = state

        if state then
            spawn(autoHatchLoop)
        end
    end
})

-- === 2) Thu thập ProximityPrompts “Hatch!” ===
local PS = game:GetService("ProximityPromptService")
local hatchPrompts = {}      -- map prompt -> true

-- Khi prompt hiển thị, nếu là Hatch! thì lưu lại
PS.PromptShown:Connect(function(prompt)
    if prompt.ActionText == "Hatch!" then
        if prompt.Enabled then
            hatchPrompts[prompt] = true
        end
        -- luôn giữ sync nếu Enabled thay đổi
        prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
            if prompt.Enabled then
                hatchPrompts[prompt] = true
            else
                hatchPrompts[prompt] = nil
            end
        end)
    end
end)

-- Khi prompt ẩn, bỏ khỏi map
PS.PromptHidden:Connect(function(prompt)
    if prompt.ActionText == "Hatch!" then
        hatchPrompts[prompt] = nil
    end
end)

-- Khởi tạo trước các prompt có sẵn
do
    local farm = getMyFarm()
    if farm then
        local phys = farm.Important:WaitForChild("Objects_Physical")
        for _, inst in ipairs(phys:GetDescendants()) do
            if inst:IsA("ProximityPrompt") and inst.ActionText == "Hatch!" then
                if inst.Enabled then
                    hatchPrompts[inst] = true
                end
                inst:GetPropertyChangedSignal("Enabled"):Connect(function()
                    if inst.Enabled then
                        hatchPrompts[inst] = true
                    else
                        hatchPrompts[inst] = nil
                    end
                end)
            end
        end
    end
end

-- === 3) Hàm tìm instance Egg trong farm ===
local function findPetEgg()
    local farm = getMyFarm()
    if not farm then return nil end
    local phys = farm.Important:FindFirstChild("Objects_Physical")
    if not phys then return nil end

    for _, inst in ipairs(phys:GetChildren()) do
        if (inst:IsA("Model") or inst:IsA("Folder"))
        and (inst.Name:find("Egg") or inst.Name:find("PetEgg")) then
            return inst
        end
    end
    return nil
end

-- === 4) Setup remote service & helper gọi remote ===
local RS           = game:GetService("ReplicatedStorage")
local petEggService = RS:WaitForChild("GameEvents"):WaitForChild("PetEggService")

local function hatchPet(egg)
    if egg and egg.Parent then
        petEggService:FireServer("HatchPet", egg)
    else
        -- gửi dummy để tránh lỗi thiếu tham số
        local fake = Instance.new("Model")
        petEggService:FireServer("HatchPet", fake)
        fake:Destroy()
    end
end


-- === 5) Vòng loop chính ===
function autoHatchLoop()
    -- luôn refer lại farm + phys
    local farm = getMyFarm()
    if not farm then return end
    local phys = farm.Important:WaitForChild("Objects_Physical")

    while autoHatchEgg do
        -- ưu tiên dùng map hatchPrompts
        local anyPrompt = next(hatchPrompts)
        if anyPrompt then
            -- đã có prompt enabled, gọi ngay
            local egg = findPetEgg()
            hatchPet(egg)
            -- sau khi call, thường prompt sẽ disable => bị remove tự động
            -- đợi 0.1s rồi tiếp tục
            task.wait(0.1)
        else
            -- không có prompt trong map, scan thủ công để đảm bảo không bỏ sót
            local found = nil
            for _, inst in ipairs(phys:GetDescendants()) do
                if inst:IsA("ProximityPrompt")
                and inst.ActionText == "Hatch!"
                and inst.Enabled then
                    found = inst
                    break
                end
            end

            if found then
                -- prompt mới scan được
                hatchPrompts[found] = true
            else
                -- chưa có prompt, chờ lâu hơn
                task.wait(0.5)
            end
        end
    end
end






config.AutoBuyGearSelection = config.AutoBuyGearSelection or { All = true }
config.AutoBuyGear = config.AutoBuyGear or false

local Section = ShopTab:AddSection("Gear")
-- Danh sách các Gear
local gearList = {
    "All",
    "Watering Can",
    "Recall Wrench",
    "Trowel",
    "Basic Sprinkler",
    "Advanced Sprinkler",
    "Godly Sprinkler",
    "Lightning Rod",
    "Master Sprinkler",
    "Favourite Tool",
    "Harvest Tool",
}

-- Bảng lưu những Gear được chọn
local selectedGears = {}

-- 1) Toggle Auto Buy Gear
ShopTab:AddToggle("AutoBuyGear", {
    Title   = "Tự động mua Gear",
    Default = config.AutoBuyGear,
    Callback = function(state)
        config.AutoBuyGear = state
        saveConfig()
        autoBuyGear = state
        if state then
            task.spawn(function()
                local shopGui = LocalPlayer:WaitForChild("PlayerGui")
                                        :WaitForChild("Gear_Shop")
                                        :WaitForChild("Frame")
                                        :WaitForChild("ScrollingFrame")
                while autoBuyGear do
                    for _, frame in ipairs(shopGui:GetChildren()) do
                        if frame:IsA("Frame") then
                            local name   = frame.Name
                            local stockT = frame:FindFirstChild("Main_Frame")
                                                and frame.Main_Frame:FindFirstChild("Stock_Text")
                            local num = stockT and tonumber(stockT.Text:match("X(%d+)%sStock")) or 0
                            if num > 0 then
                                -- nếu chọn All hoặc name trong selectedGears
                                if selectedGears.All or selectedGears[name] then
                                    pcall(function()
                                        ReplicatedStore.GameEvents.BuyGearStock:FireServer(name)
                                    end)
                                    task.wait(0.01)
                                end
                            end
                        end
                    end
                    task.wait(0.1)
                end
            end)
        end
    end
})

local gearDropdown = ShopTab:AddDropdown("GearSelectMulti", {
    Title       = "Chọn Gear để auto mua",
    Description = "Không chọn = không mua gì",
    Values      = gearList,
    Multi       = true,
    Default     = config.AutoBuyGearSelection,
    Callback    = function(selection)
        -- lưu config
        config.AutoBuyGearSelection = selection
        saveConfig()

        -- rebuild map
        selectedGears = {}
        if selection.All then
            for _, name in ipairs(gearList) do
                if name ~= "All" then
                    selectedGears[name] = true
                end
            end
            selectedGears.All = true
        else
            for name, on in pairs(selection) do
                if on and name ~= "All" then
                    selectedGears[name] = true
                end
            end
            selectedGears.All = false
        end
        warn("[AutoBuyGear] Selected:", next(selectedGears) and table.concat((function()
            local t = {}
            for n,on in pairs(selectedGears) do
                if n ~= "All" and on then table.insert(t,n) end
            end
            return t
        end)(), ", ") or "None")
    end
})
-- 5) Đảm bảo UI khởi tạo tick sẵn “All”
gearDropdown:SetValue(config.AutoBuyGearSelection)



local Section = ShopTab:AddSection("Cosmetics")
-- ======= Cosmetic Shop Auto‑Buy =======
config.AutoBuyCosmetic         = config.AutoBuyCosmetic or false
config.CosmeticMLRSelection   = config.CosmeticMLRSelection or { All = true }
config.CosmeticCUSelection    = config.CosmeticCUSelection or { All = true }
-- 1) Danh sách cosmetic theo 2 

local mythicLegendRare = {
    "All","Statue Crate","Classic Gnome Crate","Fun Crate","Farmer Gnome Crate",
    "Red Tractor","Green Tractor","Brown Well","Blue Well","Red Well",
    "Frog Fountain","Ring Walkway","Viney Ring Walkway","Round Metal Arbour",
    "Large Wood Arbour","Common Gnome Crate","Sign Crate","Flat Canopy",
    "Curved Canopy","Small Wood Arbour","Square Metal Arbour","Lamp Post",
    "Bird Bath","Large Wood Table","Small Wood Table","Clothesline",
    "Wheelbarrow","Bamboo Wind Chime","Metal Wind Chime","Grey Stone Pillar",
    "Brown Stone Pillar","Dark Stone Pillar","Campfire","Cooking Pot"
}

local commonUncommon = {
    "All","Log Bench","White Bench","Brown Bench","Wood Fence","Small Stone Pad",
    "Large Stone Pad","Medium Stone Table","Stone Lantern","Small Stone Lantern",
    "Small Stone Table","Long Stone Table","Axe Stump","Bookshelf","Mini TV",
    "Hay Bale","Small Wood Flooring","Medium Wood Flooring","Large Wood Flooring",
    "Viney Beam","Water Trough","Shovel Grave","Light on Ground","Log",
    "Small Path Tile","Medium Circle Tile","Small Circle Tile","Medium Path Tile",
    "Large Path Tile","Orange Umbrella","Yellow Umbrella","Red Pottery",
    "White Pottery","Brick Stack","Shovel","Rock Pile","Rake","Compost Bin","Torch"
}

-- 2) Maps lưu selections
local selectedMLR = {}
local selectedCU  = {}
-- 4) Toggle Auto‑Buy Cosmetic
local autoBuyCosmetic = false
ShopTab:AddToggle("AutoBuyCosmetic", {
    Title   = "Tự động mua Cosmetic",
    Default = config.AutoBuyCosmetic,
    Callback = function(state)
        config.AutoBuyCosmetic = state
        saveConfig()
        autoBuyCosmetic = state
        if state then
            task.spawn(function()
                local RS      = game:GetService("ReplicatedStorage")
                local buyEvt  = RS:WaitForChild("GameEvents"):WaitForChild("BuyCosmeticItem")
                local playerGui = LocalPlayer:WaitForChild("PlayerGui")
                local shopGui   = playerGui:WaitForChild("CosmeticShop_UI")
                                      :WaitForChild("CosmeticShop")
                                      :WaitForChild("Main")
                                      :WaitForChild("Holder")
                                      :WaitForChild("Shop")
                                      :WaitForChild("ContentFrame")

                while autoBuyCosmetic do
                    for _, segmentName in ipairs({"TopSegment","BottomSegment"}) do
                        local seg = shopGui:FindFirstChild(segmentName)
                        if seg then
                            for _, frame in ipairs(seg:GetChildren()) do
                                if frame:IsA("Frame") then
                                    local itemName = frame.Name

                                    -- Mức 1: nếu All được chọn trong nhóm MLR
                                    local buyMLR = config.CosmeticMLRSelection.All
                                    -- nếu chưa chọn All, thì kiểm xem riêng từng item
                                    if not buyMLR then
                                        buyMLR = config.CosmeticMLRSelection[itemName] or false
                                    end

                                    -- Tương tự Common/Uncommon
                                    local buyCU = config.CosmeticCUSelection.All
                                    if not buyCU then
                                        buyCU = config.CosmeticCUSelection[itemName] or false
                                    end

                                    -- Nếu 1 trong 2 nhóm được mua
                                    if buyMLR or buyCU then
                                        pcall(function()
                                            buyEvt:FireServer(itemName)
                                        end)
                                        task.wait(0.01)
                                    end
                                end
                            end
                        end
                    end
                    task.wait(0.1)
                end
            end)
        end
    end
})

-- 3) Tạo 2 multi‑dropdown
local ddMLR = ShopTab:AddDropdown("CosmeticMLR", {
    Title       = "Mythic/Legend/Rare",
    Description = "Chọn món để mua",
    Values      = mythicLegendRare,
    Multi       = true,
    Default     = config.CosmeticMLRSelection,
    Callback    = function(sel)
        config.CosmeticMLRSelection = sel
        saveConfig()
    end
})
ddMLR:SetValue(config.CosmeticMLRSelection)

-- 4) Multi‑Dropdown Common/Uncommon (lưu config & setvalue)
local ddCU = ShopTab:AddDropdown("CosmeticCU", {
    Title       = "Common/Uncommon",
    Description = "Chọn món để mua",
    Values      = commonUncommon,
    Multi       = true,
    Default     = config.CosmeticCUSelection,
    Callback    = function(sel)
        config.CosmeticCUSelection = sel
        saveConfig()
    end
})
ddCU:SetValue(config.CosmeticCUSelection)

-- Danh sách món BloodMoon Shop
-- ===== Bloodmoon Shop Auto‑Buy =====

-- 1) Danh sách item trong Mysterious Crate
-- ======= Auto‑Buy BloodMoon Shop Items =======

-- ======= Auto-Buy BloodMoon Shop Items =======

-- 1) Danh sách item trong Bloodmoon shop
local bloodMoonItems = {
    "All",                  -- thêm dòng này
    "Mysterious Crate",
    "Night Egg",
    "Night Seed Pack",
    "Blood Banana",
    "Moon Melon",
    "Star Caller",
    "Blood Kiwi",
    "Blood Hedgehog",
    "Blood Owl",
}

-- 2) Bảng lưu lựa chọn từ Multi-Dropdown
local Section = ShopTab:AddSection("BloodMoon Shop")
local selectedBloodMoon = {}

config.AutoBuyBloodMoon   = config.AutoBuyBloodMoon   or false
config.BloodMoonSelection = config.BloodMoonSelection or { All = true }

-- Shortcut
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local RS_EVENTS         = ReplicatedStorage:WaitForChild("GameEvents")
local LocalPlayer       = Players.LocalPlayer

-- 4) Toggle Auto-Buy cho BloodMoon shop
ShopTab:AddToggle("AutoBuyBloodMoon", {
    Title   = "Tự động mua BloodMoon Shop",
    Default = config.AutoBuyBloodMoon,
    Callback = function(state)
        config.AutoBuyBloodMoon = state
        saveConfig()
        autoBuyBloodMoon = state

        if state then
            task.spawn(function()
                local evt     = RS_EVENTS:WaitForChild("BuyEventShopStock")
                local shopUI  = LocalPlayer:WaitForChild("PlayerGui")
                                     :WaitForChild("EventShop_UI")
                                     :WaitForChild("Frame")
                                     :WaitForChild("ScrollingFrame")

                while autoBuyBloodMoon do
                    -- B1: Kiểm tra Attribute BloodMoonEvent (bật hay không)
                    local isBloodMoonActive = workspace:GetAttribute("BloodMoonEvent")
                    if not isBloodMoonActive then
                        -- Nếu chưa active thì chờ
                        task.wait(1)
                    else
                        -- Nếu active thì spam mua
                        for _, frame in ipairs(shopUI:GetChildren()) do
                            if frame:IsA("Frame") then
                                local name   = frame.Name
                                if selectedBloodMoon[name] then
                                    local stockT = frame.Main_Frame and frame.Main_Frame:FindFirstChild("Stock_Text")
                                    local num    = stockT and tonumber(stockT.Text:match("X(%d+)"))
                                    if num and num > 0 then
                                        -- Gọi remote
                                        pcall(function()
                                            evt:FireServer(name)
                                        end)
                                        task.wait(0.01)
                                    end
                                end
                            end
                        end
                        task.wait(0.1)
                    end
                end
            end)
        end
    end
})

-- 3) Tạo Multi-Dropdown để chọn item muốn auto-buy
local ddBM = ShopTab:AddDropdown("BloodMoonSelect", {
    Title       = "Chọn item BloodMoon",
    Description = "Chọn item để auto mua (All = mua tất cả)",
    Values      = bloodMoonItems,
    Multi       = true,
    Default     = config.BloodMoonSelection,
    Callback    = function(selection)
        config.BloodMoonSelection = selection
        saveConfig()

        -- Rebuild map
        selectedBloodMoon = {}
        if selection.All then
            for _, name in ipairs(bloodMoonItems) do
                if name ~= "All" then
                    selectedBloodMoon[name] = true
                end
            end
        else
            for name, on in pairs(selection) do
                if on and name ~= "All" then
                    selectedBloodMoon[name] = true
                end
            end
        end

        -- Debug
        local t = {}
        for name in pairs(selectedBloodMoon) do
            table.insert(t, name)
        end
        print("[BloodMoon] Selected:", #t>0 and table.concat(t, ", ") or "None")
    end
})
ddBM:SetValue(config.BloodMoonSelection)




-- Giả sử đã require trước:
-- local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local Players           = game:GetService("Players")
-- local LocalPlayer       = Players.LocalPlayer
-- local MainTab           = … your UI tab …
-- local config            = … your config table …

-- 0) Config mặc định
config.AutoTradeLunar = config.AutoTradeLunar or false
local autoTradeLunar  = config.AutoTradeLunar

-- 1) Lấy Remote
local nightQuestRemote = ReplicatedStorage
    :WaitForChild("GameEvents")
    :WaitForChild("NightQuestRemoteEvent")

-- 2) Hàm scan & trade
local function scanAndTradeBloodlit()
    local plr = LocalPlayer
    for _, container in ipairs({plr.Backpack, plr.Character}) do
        if not container then continue end

        for _, tool in ipairs(container:GetChildren()) do
            if not tool:IsA("Tool") then
                continue
            end

            local nameLower = tool.Name:lower()
            --  phải có "bloodlit" trong tên
            if not nameLower:find("bloodlit") then
                continue
            end

            --  phải chưa được Favorite
            --  (nil hoặc false nghĩa là chưa favorite)
            if tool:GetAttribute("Favorite") then
                -- nếu đã Favorite thì bỏ qua
                continue
            end

            -- gọi remote
            pcall(function()
                nightQuestRemote:FireServer("SubmitAllPlants")
            end)
            warn(string.format("[AutoTradeLunar] Fired SubmitAllPlants vì phát hiện tool: %s", tool.Name))
            -- tool sẽ biến mất sau khi trade, nên ta không break
        end
    end
end

-- 3) UI: Toggle
ShopTab:AddToggle("AutoTradeLunar", {
    Title   = "Auto Trade LunarPoint",
    Default = config.AutoTradeLunar,
    Callback = function(state)
        config.AutoTradeLunar = state
        saveConfig()
        autoTradeLunar = state

        if state then
            task.spawn(function()
                while autoTradeLunar do
                    scanAndTradeBloodlit()
                    -- nếu không còn tool bloodlit chưa favorite thì chờ lâu hơn
                    task.wait(0.5)
                end
            end)
        end
    end
})







local Section = ShopTab:AddSection("Twilight Shop")
-- 1) Danh sách các item trong NightEvent Shop
local nightShopItems = {
    "All",            -- thêm mục All
    "Night Egg",
    "Night Seed Pack",
    "Twilight Crate",
    "Star Caller",
    "Moon Cat",
    "Celestiberry",
    "Moon Mango"
}

-- 2) Khởi tạo config mặc định
config.AutoBuyNightShop    = config.AutoBuyNightShop    or false
config.NightShopSelection  = config.NightShopSelection  or { All = true }

-- 3) Mảng lưu lựa chọn
local selectedNightItems = {}

-- 4) Toggle Auto-Buy NightEvent Shop
local autoBuyNight = false
ShopTab:AddToggle("AutoBuyNightShop", {
    Title   = "Tự động mua NightEvent Shop",
    Default = config.AutoBuyNightShop,
    Callback = function(state)
        config.AutoBuyNightShop = state
        saveConfig()
        autoBuyNight = state

        if state then
            task.spawn(function()
                local Players            = game:GetService("Players")
                local ReplicatedStorage  = game:GetService("ReplicatedStorage")
                local LocalPlayer        = Players.LocalPlayer
                local shopGui = LocalPlayer:WaitForChild("PlayerGui")
                                      :WaitForChild("NightEventShop_UI")
                                      :WaitForChild("Frame")
                                      :WaitForChild("ScrollingFrame")
                local buyRemote = ReplicatedStorage
                                   :WaitForChild("GameEvents")
                                   :WaitForChild("BuyNightEventShopStock")

                while autoBuyNight do
                    -- Kiểm tra Attribute NightEvent
                    local nightActive = workspace:GetAttribute("NightEvent")
                    if not nightActive then
                        -- chưa active thì chờ 1s rồi continue
                        task.wait(1)
                    else
                        -- Sự kiện NightEvent đã ON → bắt đầu mua
                        if config.NightShopSelection.All then
                            -- mua tất cả (không mua "All")
                            for _, itemName in ipairs(nightShopItems) do
                                if itemName ~= "All" then
                                    local frame = shopGui:FindFirstChild(itemName)
                                    if frame then
                                        local stockT = frame.Main_Frame and frame.Main_Frame:FindFirstChild("Stock_Text")
                                        local n = stockT and tonumber(stockT.Text:match("X(%d+)")) or 0
                                        if n > 0 then
                                            pcall(function()
                                                buyRemote:FireServer(itemName)
                                            end)
                                            task.wait(0.01)
                                        end
                                    end
                                end
                            end
                        else
                            -- chỉ mua những mục được tick
                            for itemName, on in pairs(config.NightShopSelection) do
                                if itemName ~= "All" and on then
                                    local frame = shopGui:FindFirstChild(itemName)
                                    if frame then
                                        local stockT = frame.Main_Frame and frame.Main_Frame:FindFirstChild("Stock_Text")
                                        local n = stockT and tonumber(stockT.Text:match("X(%d+)")) or 0
                                        if n > 0 then
                                            pcall(function()
                                                buyRemote:FireServer(itemName)
                                            end)
                                            task.wait(0.01)
                                        end
                                    end
                                end
                            end
                        end
                        task.wait(0.1)
                    end
                end
            end)
        end
    end
})

-- 5) Multi-dropdown chọn item NightEvent Shop
local ddNight = ShopTab:AddDropdown("NightShopFilter", {
    Title       = "Chọn item NightEvent Shop",
    Description = "Mua những item được chọn khi bật AutoBuy",
    Values      = nightShopItems,
    Multi       = true,
    Default     = config.NightShopSelection,
    Callback    = function(selection)
        config.NightShopSelection = selection
        saveConfig()
    end
})
ddNight:SetValue(config.NightShopSelection)



-- Toggle AutoPlantGear
config.AutoPlantGear     = config.AutoPlantGear     or false

-- Dropdown Gear cho từng Position
config.GearForPos1       = config.GearForPos1       or nil
config.GearForPos2       = config.GearForPos2       or nil
config.GearForPos3       = config.GearForPos3       or nil
config.GearForPos4       = config.GearForPos4       or nil

local ddPosition
local selectedPosition = "Position 1"
local positionList = { "Position 1", "Position 2", "Position 3", "Position 4" }
local positionCFrames = {}
local gearList = {
    "None",
    "Basic Sprinkler",
    "Advanced Sprinkler",
    "Godly Sprinkler",
    "Lightning Rod",
    "Master Sprinkler",
    "Harvest Tool",
    "Star Caller",
    "Night Staff"
}

local selectedGearByPosition = {
    ["Position 1"] = nil,
    ["Position 2"] = nil,
    ["Position 3"] = nil,
    ["Position 4"] = nil
}

-- Data gốc từ RemoteSpy:
-- === AutoPlantGear (cập nhật với 4 vị trí + gear tương ứng) ===
local autoPlantGear = false
local GEAR_ACTION = "Create"

GearsTab:AddToggle("AutoPlantGear", {
    Title   = "Auto Plant Gear",
    Default = config.AutoPlantGear,
    Callback = function(state)
        config.AutoPlantGear = state
        saveConfig()
        autoPlantGear = state
        if state then
            task.spawn(function()
                local hrp = Character:WaitForChild("HumanoidRootPart")
                local svc = ReplicatedStore
                              :WaitForChild("GameEvents")
                              :WaitForChild("SprinklerService")  -- mặc định, sẽ override nếu cần

                -- Xác định list vị trí
                local positionNames = {
                    "Position 1","Position 2","Position 3","Position 4"
                }

                while autoPlantGear do
                    for idx, posName in ipairs(positionNames) do
                        if not autoPlantGear then break end

                        local cfBase = positionCFrames[posName]
                        local gearName = selectedGearByPosition[posName]

                        if not cfBase or not gearName then
                            warn(("[AutoPlantGear] Skipping %s: %s"):format(
                                posName,
                                not cfBase and "No CFrame saved" or "No gear selected"
                            ))
                        else
                            -- 1) Tìm và equip tool
                            local foundTool
                            for _, container in ipairs({LocalPlayer.Backpack, Character}) do
                                for _, tool in ipairs(container:GetChildren()) do
                                    if tool:IsA("Tool")
                                    and tool.Name:find(gearName) then
                                        foundTool = tool
                                        break
                                    end
                                end
                                if foundTool then break end
                            end

                            if foundTool then
                                Humanoid:EquipTool(foundTool)
                                task.wait(0.1)
                                print(("[AutoPlantGear] Equipped %s for %s"):format(
                                    gearName, posName
                                ))
                            else
                                warn(("[AutoPlantGear] Tool '%s' not found for %s"):format(
                                    gearName, posName
                                ))
                                -- bỏ qua vị trí này
                                continue
                            end

                            -- 2) Gọi remote với CFrame mới
                            local cf = CFrame.new(
                                cfBase.Position.X,
                                cfBase.Position.Y,
                                cfBase.Position.Z,
                                1,0,0, 0,1,0, 0,0,1
                            )
                            pcall(function()
                                svc:FireServer(GEAR_ACTION, cf)
                            end)
                            print(("[AutoPlantGear] Fired %s at %s"):format(
                                GEAR_ACTION, tostring(cf)
                            ))
                        end

                        task.wait(0.2)
                    end
                end

                print("[AutoPlantGear] Stopped")
            end)
        end
    end
})
local DEFAULT_Y = 0.135527045
-- Nút lưu vị trí
GearsTab:AddButton({
    Title = ("Lưu %s"):format(selectedPosition),
    Callback = function()
        if not ddPosition then return end
        local cf  = hrp.CFrame
        local x, z = cf.X, cf.Z

        -- 1) Lưu CFrame dùng cho AutoPlantGear, giữ Y mặc định
        positionCFrames[selectedPosition] = CFrame.new(x, DEFAULT_Y, z)

        -- 2) Tạo tên hiển thị, chỉ hiển thị Y = 0
        local shortName = string.format(
            "%s:  %d, %d, %d",
            selectedPosition,
            x,          -- làm tròn về số nguyên
            0,          -- hiển thị Y = 0
            z           -- làm tròn về số nguyên
        )

        -- 3) Update dropdown như cũ
        for i, name in ipairs(positionList) do
            if name:find(selectedPosition) then
                positionList[i] = shortName
                break
            end
        end
        ddPosition:SetValues(positionList)
        ddPosition:SetValue(shortName)
        -- 0) Xác định tên marker cho mỗi position
        local function markerName(pos)
            return "Marker_" .. pos:gsub(" ", "")
        end
        
        -- Trong callback "Lưu Position", thay thế đoạn xoá toàn bộ bằng chỉ xoá marker của vị trí hiện tại:
        -- 0.1) Xóa marker cũ của vị trí này (nếu có)
        local old = workspace:FindFirstChild(markerName(selectedPosition))
        if old then
            old:Destroy()
        end
        
        -- 1) Tạo Part mới kèm marker
        local markerPart = Instance.new("Part")
        markerPart.Name         = markerName(selectedPosition)
        markerPart.Size         = Vector3.new(1,1,1)
        markerPart.Transparency = 1
        markerPart.CanCollide   = false
        markerPart.Anchored     = true
        markerPart.CFrame       = positionCFrames[selectedPosition]
        markerPart.Parent       = workspace
        
        local bb = Instance.new("BillboardGui")
        bb.Name          = "PositionMarker"
        bb.Adornee       = markerPart
        bb.AlwaysOnTop   = false
        bb.ExtentsOffset = Vector3.new(0,2,0)
        bb.Size          = UDim2.new(0,75,0,40)
        bb.Parent        = markerPart
        
        local lbl = Instance.new("TextLabel")
        lbl.Size                   = UDim2.fromScale(1,1)
        lbl.BackgroundTransparency = 1
        lbl.Font                   = Enum.Font.SourceSansBold
        lbl.Text                   = selectedPosition
        lbl.TextColor3             = Color3.new(1,1,1)
        lbl.TextStrokeTransparency = 0.5
        lbl.TextScaled             = true
        lbl.Parent                 = bb
    end
})

-- Dropdown chọn vị trí hiện tại
ddPosition = GearsTab:AddDropdown("PositionSelector", {
    Title = "Chọn vị trí để sử dụng",
    Description = "Chọn 1 trong 4 vị trí đã lưu",
    Values = positionList,
    Default = selectedPosition,
    Callback = function(val)
        selectedPosition = val:match("^Position %d") or val
    end
})


-- Dropdown chọn Gear cho từng vị trí
local ddGear1 = GearsTab:AddDropdown("GearForPos1", {
    Title   = "Gear cho Position 1",
    Values  = gearList,              -- trong gearList bạn đã chèn "None"
    Default = config.GearForPos1,
    Callback = function(selected)
        config.GearForPos1 = selected
        saveConfig()

        -- Đây là chỗ gán selectedGearByPosition:
        if selected == "None" then
            selectedGearByPosition["Position 1"] = nil
        else
            selectedGearByPosition["Position 1"] = selected
        end
    end
})
ddGear1:SetValue(config.GearForPos1)


local ddGear2 = GearsTab:AddDropdown("GearForPos2", {
    Title   = "Gear cho Position 2",
    Values  = gearList,
    Default = config.GearForPos2,
    Callback = function(selected)
        config.GearForPos2 = selected
        saveConfig()
        if selected == "None" then
            selectedGearByPosition["Position 2"] = nil
        else
            selectedGearByPosition["Position 2"] = selected
        end
    end
})
ddGear2:SetValue(config.GearForPos2)

local ddGear3 = GearsTab:AddDropdown("GearForPos3", {
    Title   = "Gear cho Position 3",
    Values  = gearList,
    Default = config.GearForPos3,
    Callback = function(selected)
        config.GearForPos3 = selected
        saveConfig()
        if selected == "None" then
            selectedGearByPosition["Position 3"] = nil
        else
            selectedGearByPosition["Position 3"] = selected
        end
    end
})
ddGear3:SetValue(config.GearForPos3)

local ddGear4 = GearsTab:AddDropdown("GearForPos4", {
    Title   = "Gear cho Position 4",
    Values  = gearList,
    Default = config.GearForPos4,
    Callback = function(selected)
        config.GearForPos4 = selected
        saveConfig()
        if selected == "None" then
            selectedGearByPosition["Position 4"] = nil
        else
            selectedGearByPosition["Position 4"] = selected
        end
    end
})
ddGear4:SetValue(config.GearForPos4)







local Section = PlantTab:AddSection("Position Plant")
-- Section gom mấy control liên quan
-- khởi mặc định nếu chưa có
config.AutoPlantSeedLoc      = config.AutoPlantSeedLoc      or false
config.RandomOthersSeed      = config.RandomOthersSeed      or false
config.SeedForLoc1           = config.SeedForLoc1           or {}
config.SeedForLoc2           = config.SeedForLoc2           or {}
config.SeedForLoc3           = config.SeedForLoc3           or {}
config.SeedForLoc4           = config.SeedForLoc4           or {}
config.ZoneSelector          = config.ZoneSelector          or { ["Zone 1"] = true, ["Zone 2"] = true }
-- === Khai báo chung ===
local ddLocation
local selectedLocation = "Location 1"
local locationList   = { "Location 1", "Location 2", "Location 3", "Location 4" }
local locationCFrames = {}
local selectedZones = {}
local seedOptions    = {
    "Carrot","Chocolate Carrot","Strawberry","Red Lollipop","Nightshade",
    "Blueberry","Orange Tulip","Tomato","Raspberry","Candy Sunflower",
    "Glowshroom","Corn","Daffodil","Watermelon","Pumpkin","Apple","Bamboo",
    "Peach","Pineapple","Dragon Fruit","Cactus","Coconut","Mango","Grape",
    "Mushroom","Pepper","Cacao","Beanstalk","Easter Egg","Candy Blossom",
    "Durian","Cranberry","Eggplant","Lotus","Venus Flytrap","Rainbow Sack",
    "Papaya","Passionfruit","Banana","Cursed Fruit","Soul Fruit","Mint",
    "Moonflower","Starfruit","Moonglow","Moon Blossom","Blood Banana","Moon Melon"
}
local selectedSeedsByLocation = {
    ["Location 1"] = {},
    ["Location 2"] = {},
    ["Location 3"] = {},
    ["Location 4"] = {}
}

local DEFAULT_Y = 0.135527045

-- === 1) Toggle AutoPlantSeed (location) ===
local autoPlantSeedLoc = false
local randomOthersSeed = false
plantAt = function(pos, name)
    ReplicatedStore.GameEvents.Plant_RE:FireServer(pos, name)
    local cf = CFrame.new(pos)
    local gateway = Character.InputGateway or LocalPlayer.PlayerScripts.InputGateway
    for _, s in ipairs({true,false}) do
        gateway.Activation:FireServer(s, cf)
        task.wait(0.01)
    end
end
local sizeX, sizeY, sizeZ = 30.5, 0.001, 59
local function randomPoint(cf)
    local hx, hy, hz = sizeX/2, sizeY/2, sizeZ/2
    return (cf * CFrame.new(
        (math.random()*2-1)*hx,
        (math.random()*2-1)*hy,
        (math.random()*2-1)*hz
    )).Position
end


-- === AutoPlantSeedLoc Logic ===
local plantseedB = PlantTab:AddToggle("AutoPlantSeedLoc", {
    Title   = "AutoPlantSeed (location)",
    Default = config.AutoPlantSeedLoc,
    Callback = function(state)
        config.AutoPlantSeedLoc = state; saveConfig()
        autoPlantSeedLoc = state
        print("[AutoPlantSeedLoc] Toggled:", state)
        if state then
            task.spawn(function()
                local hrp = Character:WaitForChild("HumanoidRootPart")
                local lastTp = 0
                -- danh sách location keys
                local locNames = {"Location 1","Location 2","Location 3","Location 4"}

                local farm    = getMyFarm()
                local zoneCenters = {}
                if farm then
                    for idx, cp in ipairs(farm.Important.Plant_Locations:GetChildren()) do
                        if cp.Name=="Can_Plant" then
                            zoneCenters[idx] = cp.CFrame  -- idx=1 → Zone1, idx=2 → Zone2
                        end
                    end
                end

                while autoPlantSeedLoc do
                    print("[AutoPlantSeedLoc] randomOthersSeed =", randomOthersSeed)
                    for _, loc in ipairs(locNames) do
                        if not autoPlantSeedLoc then break end

                        local baseCF = locationCFrames[loc]
                        local seeds  = selectedSeedsByLocation[loc]
                        if not baseCF then
                            warn("[AutoPlantSeedLoc] Skipping", loc, "- no CFrame saved")
                        elseif not seeds or next(seeds)==nil then
                            warn("[AutoPlantSeedLoc] Skipping", loc, "- no seeds selected")
                        else
                            -- random point trong bán kính 3 studs
                            local dx = (math.random()*2-1)*3
                            local dz = (math.random()*2-1)*3
                            local plantPos = Vector3.new(
                                baseCF.Position.X + dx,
                                baseCF.Position.Y,
                                baseCF.Position.Z + dz
                            )

                            -- teleport về spawnPointPart mỗi 3s
                            if spawnPointPart and tick()-lastTp >= 3 then
                                hrp.CFrame = spawnPointPart.CFrame + Vector3.new(0,-2,0)
                                task.wait(0.05)
                                lastTp = tick()
                                print("[AutoPlantSeedLoc] Teleported to spawn point")
                            end

                            -- Duyệt từng seed trong map (sel map[name]=true)
                            for seedName, on in pairs(seeds) do
                                if not autoPlantSeedLoc then break end
                                if on then
                                    -- tìm tool seed trong Backpack/Character
                                    local foundTool
                                    for _,container in ipairs({LocalPlayer.Backpack, Character}) do
                                        for _,tool in ipairs(container:GetChildren()) do
                                            if tool:IsA("Tool")
                                            and tool.Name:find(seedName .. " Seed")        -- chứa đúng "Carrot Seed", "Tomato Seed", ...
                                            and tool.Name:find("%[X%d+%]") then            -- chứa [X<number>]
                                                foundTool = tool
                                                break
                                            end
                                        end
                                        if foundTool then break end
                                    end
                                    if not foundTool then
                                        warn("[AutoPlantSeedLoc] Tool not found:", seedName)
                                        continue
                                    end

                                    -- Equip tool
                                    Humanoid:EquipTool(foundTool)
                                    task.wait(0.1)
                                    print(("[AutoPlantSeedLoc] Equipped %s for %s"):format(seedName, loc))

                                    -- Gọi plantAt
                                    local success, err = pcall(function()
                                        plantAt(plantPos, seedName)
                                    end)
                                    if success then
                                        print(("[AutoPlantSeedLoc] Planted %s at %s"):format(
                                            seedName, tostring(plantPos)
                                        ))
                                    else
                                        warn("[AutoPlantSeedLoc] Error planting:", err)
                                    end

                                    task.wait(0.2)
                                end
                            end
                        end
                    end
                    print("[AutoPlantSeedLoc] Checking RandomOthersSeed")
                    if randomOthersSeed then
                        -- build filtered centers theo selectedZones
                        local centersFiltered = {}
                        for idx, cf in ipairs(zoneCenters) do
                            if selectedZones["Zone "..idx] then
                                table.insert(centersFiltered, cf)
                            end
                        end
                        if #centersFiltered == 0 then
                            warn("[RandomOthersSeed] No zone selected, skipping")
                        else
                            -- Xây blacklist từ seeds đã được dùng ở 4 location
                            local used = {}
                            for _, loc in ipairs({"Location 1", "Location 2", "Location 3", "Location 4"}) do
                                for seedName, on in pairs(selectedSeedsByLocation[loc]) do
                                    if on then used[seedName] = true end
                                end
                            end

                            -- Tạo danh sách seed chưa dùng
                            local avail = {}
                            for _, name in ipairs(seedOptions) do
                                if not used[name] then
                                    table.insert(avail, name)
                                end
                            end

                            -- Chọn và trồng 2 seed ngẫu nhiên
                            for i = 1, 2 do
                                if #avail == 0 then break end
                                local idx = math.random(#avail)
                                local seedName = table.remove(avail, idx)

                                local cfCenter = centersFiltered[math.random(#centersFiltered)]
                                local plantPos = randomPoint(cfCenter)

                                -- teleport nếu cần
                                if spawnPointPart and tick() - lastTp >= 3 then
                                    hrp.CFrame = spawnPointPart.CFrame + Vector3.new(0, -2, 0)
                                    task.wait(0.05)
                                    lastTp = tick()
                                    print("[RandomOthersSeed] Teleported to spawn")
                                end

                                -- tìm tool
                                local tool
                                for _, cont in ipairs({LocalPlayer.Backpack, Character}) do
                                    for _, t in ipairs(cont:GetChildren()) do
                                        if t:IsA("Tool")
                                        and t.Name:find(seedName .. " Seed")
                                        and t.Name:find("%[X%d+%]") then
                                            tool = t
                                            break
                                        end
                                    end
                                    if tool then break end
                                end
                                if not tool then
                                    warn("[RandomOthersSeed] Tool not found for", seedName)
                                    continue
                                end

                                Humanoid:EquipTool(tool)
                                task.wait(0.1)
                                pcall(function()
                                    plantAt(plantPos, seedName)
                                end)
                                print(("[RandomOthersSeed] Planted %s at %s"):format(seedName, tostring(plantPos)))
                                task.wait(0.2)
                            end
                        end
                    end

                    task.wait(0.5)
                end
                print("[AutoPlantSeedLoc] Stopped")
            end)
        end
    end
})

plantseedA:OnChanged(function(state)
    if state then
        -- nếu bật B thì tắt A
        plantseedB:SetValue(false)
    end
end)

plantseedB:OnChanged(function(state)
    if state then
        -- nếu bật B thì tắt A
        plantseedA:SetValue(false)
    end
end)


-- === 2) Button “Lưu Location” ===
PlantTab:AddButton({
    Title       = ("Lưu %s"):format(selectedLocation),
    Description = "Ghi nhớ CFrame cho location này",
    Callback    = function()
        if not ddLocation then return end

        local cf = hrp.CFrame
        local x, z = cf.X, cf.Z

        -- 1) Lưu CFrame với Y cố định
        locationCFrames[selectedLocation] = CFrame.new(x, DEFAULT_Y, z)

        -- 2) Đổi tên dropdown hiển thị, Y hiển thị = 0
        local shortName = string.format(
            "%s: %d, %d, %d",
            selectedLocation,
            x,
            0,
            z
        )
        for i, name in ipairs(locationList) do
            if name:find(selectedLocation) then
                locationList[i] = shortName
                break
            end
        end
        ddLocation:SetValues(locationList)
        ddLocation:SetValue(shortName)

        -- 3) Xoá marker cũ cho location này nếu có
        local markerName = "Marker_" .. selectedLocation:gsub(" ", "")
        local old = workspace:FindFirstChild(markerName)
        if old then old:Destroy() end

        -- 4) Tạo marker 3D với BillboardGui
        local part = Instance.new("Part")
        part.Name         = markerName
        part.Size         = Vector3.new(1,1,1)
        part.Transparency = 1
        part.Anchored     = true
        part.CanCollide   = false
        part.CFrame       = locationCFrames[selectedLocation]
        part.Parent       = workspace

        local bb = Instance.new("BillboardGui", part)
        bb.Name          = "LocationMarker"
        bb.Adornee       = part
        bb.AlwaysOnTop   = false
        bb.ExtentsOffset = Vector3.new(0,2,0)
        bb.Size          = UDim2.new(0,75,0,40)

        local lbl = Instance.new("TextLabel", bb)
        lbl.Size                   = UDim2.fromScale(1,1)
        lbl.BackgroundTransparency = 1
        lbl.Font                   = Enum.Font.SourceSansBold
        lbl.Text                   = selectedLocation
        lbl.TextColor3             = Color3.new(1,1,1)
        lbl.TextStrokeTransparency = 0.5
        lbl.TextScaled             = true
    end
})

-- === 3) Dropdown chọn Location hiện tại ===
ddLocation = PlantTab:AddDropdown("LocationSelector", {
    Title       = "Chọn location để sử dụng",
    Description = "Chọn 1 trong 4 location đã lưu",
    Values      = locationList,
    Default     = selectedLocation,
    Callback    = function(val)
        selectedLocation = val:match("^Location %d") or val
    end
})

-- === 4–7) Bốn Multi‑Dropdown “Seed for Location X” ===
local dropdownSeedForLoc1 = PlantTab:AddDropdown("SeedForLoc1", {
    Title       = "Seed for Location 1",
    Description = "Chọn nhiều seed",
    Values      = seedOptions,
    Multi       = true,
    Default     = config.SeedForLoc1,
    Callback    = function(sel)
        config.SeedForLoc1 = sel; saveConfig()
        selectedSeedsByLocation["Location 1"] = sel
    end
})
dropdownSeedForLoc1:SetValue(config.SeedForLoc1)

local dropdownSeedForLoc2 = PlantTab:AddDropdown("SeedForLoc2", {
    Title       = "Seed for Location 2",
    Description = "Chọn nhiều seed",
    Values      = seedOptions,
    Multi       = true,
    Default     = config.SeedForLoc2,
    Callback    = function(sel)
        config.SeedForLoc2 = sel; saveConfig()
        selectedSeedsByLocation["Location 2"] = sel
    end
})
dropdownSeedForLoc2:SetValue(config.SeedForLoc2)

local dropdownSeedForLoc3 = PlantTab:AddDropdown("SeedForLoc3", {
    Title       = "Seed for Location 3",
    Description = "Chọn nhiều seed",
    Values      = seedOptions,
    Multi       = true,
    Default     = config.SeedForLoc3,
    Callback    = function(sel)
        config.SeedForLoc3 = sel; saveConfig()
        selectedSeedsByLocation["Location 3"] = sel
    end
})
dropdownSeedForLoc3:SetValue(config.SeedForLoc3)

local dropdownSeedForLoc4 = PlantTab:AddDropdown("SeedForLoc4", {
    Title       = "Seed for Location 4",
    Description = "Chọn nhiều seed",
    Values      = seedOptions,
    Multi       = true,
    Default     = config.SeedForLoc4,
    Callback    = function(sel)
        config.SeedForLoc4 = sel; saveConfig()
        selectedSeedsByLocation["Location 4"] = sel
    end
})
dropdownSeedForLoc4:SetValue(config.SeedForLoc4)

-- === 8) Toggle Random Others Seed ===

PlantTab:AddToggle("RandomOthersSeed", {
    Title   = "Random Others Seed",
    Default = config.RandomOthersSeed,
    Callback = function(state)
        config.RandomOthersSeed = state; saveConfig()
        randomOthersSeed = state
        print("[RandomOthersSeed] Toggled:", state)
    end
})

-- === 9) Multi Dropdown chọn Zone ===
local zoneDropdown = PlantTab:AddDropdown("ZoneSelector", {
    Title       = "Zone selector (for random)",
    Description = "Chọn zone sẽ áp dụng random seed",
    Values      = {"Zone 1", "Zone 2"},
    Multi       = true,
    Default     = config.ZoneSelector,
    Callback    = function(sel)
        config.ZoneSelector  = sel; saveConfig()
        selectedZones = sel
        print("[ZoneSelector] Selected zones:", table.concat(sel, ", "))
    end
})
zoneDropdown:SetValue(config.ZoneSelector)



-- Thêm section nếu cần


-- Giả sử bạn đã có biến TeleportTab tham chiếu tới tab Teleport
-- và LocalPlayer, Character, HumanoidRootPart (hrp) đã được khởi tạo sẵn

TeleportTab:AddButton({
    Title       = "Tp to Cosmetic-Gear Npc",
    Description = "Dịch chuyển đến 5 studs trước mặt NPC Chippy",
    Callback    = function()
        -- Lấy HumanoidRootPart của Chippy
        local chippyModel = workspace:FindFirstChild("NPCS")
                              and workspace.NPCS:FindFirstChild("CosmeticStand")
                              and workspace.NPCS.CosmeticStand:FindFirstChild("Chippy")
        if not chippyModel then
            warn("[Teleport] Không tìm thấy workspace.NPCS.CosmeticStand.Chippy!")
            return
        end

        local targetHRP = chippyModel:FindFirstChild("HumanoidRootPart")
        if not targetHRP then
            warn("[Teleport] Chippy không có HumanoidRootPart!")
            return
        end

        -- Tọa độ nhân vật
        local playerChar = LocalPlayer.Character
        if not playerChar then
            warn("[Teleport] Character chưa load!")
            return
        end

        local hrp = playerChar:FindFirstChild("HumanoidRootPart")
        if not hrp then
            warn("[Teleport] Không tìm thấy HumanoidRootPart của bạn!")
            return
        end

        -- Tính CFrame đích: 5 studs trước mặt Chippy
        -- Chippy hướng theo targetHRP.CFrame.LookVector
        local lookVec = targetHRP.CFrame.LookVector
        local destinationCF = CFrame.new(
            targetHRP.Position - lookVec * -5,   -- lùi 5 studs theo LookVector
            targetHRP.Position                  -- nhìn về hướng Chippy
        )
        -- Giữ cùng orientation với camera hoặc xoay thẳng về NPC
        -- nếu chỉ cần đặt vị trí: 
        -- local destinationCF = targetHRP.CFrame * CFrame.new(0, 0, -5)

        -- Teleport nhân vật
        hrp.CFrame = destinationCF

        print("[Teleport] Đã dịch chuyển tới trước Chippy 5 studs.")
    end
})

TeleportTab:AddButton({
    Title = "Tp to Owl",
    Callback = function()
        -- Lấy Part đích
        local target = workspace:WaitForChild("NightEvent")
                              :WaitForChild("OwlNPCTree")
                              :WaitForChild("26")
                              :WaitForChild("Part")
        if target:IsA("BasePart") then
            -- Bấm cao lên 1 stud so với vị trí Part
            local newCFrame = CFrame.new(target.Position + Vector3.new(0, 3, 0))
            -- Teleport người chơi
            local hrp = Character:WaitForChild("HumanoidRootPart")
            hrp.CFrame = newCFrame
        else
            warn("Không tìm thấy Part đích!")
        end
    end
})



local Section = TeleportTab:AddSection("Players Teleport")
-- === 0) Khởi tạo config để lưu Selection ===
config.TeleportPlayer = config.TeleportPlayer or nil

-- === 1) Biến chung ===
  -- giả sử bạn có tab này
local teleDropdown   = nil
local playerNames    = {}   -- mảng tên model
local selectedTarget = config.TeleportPlayer

-- Hàm lấy tất cả model player trong workspace
local function rebuildPlayerList()
    playerNames = {}
    for _, inst in ipairs(workspace:GetChildren()) do
        -- Lọc ra Model có Humanoid và có con HumanoidRootPart
        if inst:IsA("Model") and inst:FindFirstChild("Humanoid") 
        and inst:FindFirstChild("HumanoidRootPart") then
            table.insert(playerNames, inst.Name)
        end
    end
    table.sort(playerNames)      -- optional: sắp xếp theo chữ
end

-- === 2) Tạo UI ===
-- A) nút Refresh
TeleportTab:AddButton({
    Title       = "Refresh Player List",
    Description = "Cập nhật lại danh sách nhân vật trong workspace",
    Callback    = function()
        rebuildPlayerList()
        if teleDropdown then
            teleDropdown:SetValues(playerNames)
            -- nếu config.TP đã có nhưng không còn trong list thì clear
            if not table.find(playerNames, selectedTarget) then
                selectedTarget = nil
                config.TeleportPlayer = nil; saveConfig()
            end
            teleDropdown:SetValue(selectedTarget or playerNames[1])
        end
    end
})

-- B) Dropdown Teleport
teleDropdown = TeleportTab:AddDropdown("TeleportPlayer", {
    Title       = "Chọn Player để Teleport",
    Description = "Teleport tới vị trí HumanoidRootPart của player",
    Values      = playerNames,
    Default     = selectedTarget,
    Callback    = function(val)
        selectedTarget = val
        config.TeleportPlayer = val; saveConfig()
    end
})

-- C) Button Thực thi Teleport
TeleportTab:AddButton({
    Title       = "Teleport Now",
    Description = "Dịch chuyển đến vị trí player đã chọn",
    Callback    = function()
        if not selectedTarget then
            warn("Chưa chọn player để teleport!")
            return
        end
        local targetModel = workspace:FindFirstChild(selectedTarget)
        if targetModel 
        and targetModel:FindFirstChild("HumanoidRootPart") then
            local hrp = Character:FindFirstChild("HumanoidRootPart") 
                        or Character.PrimaryPart
            if hrp then
                hrp.CFrame = targetModel.HumanoidRootPart.CFrame
                print(("Đã teleport đến %s"):format(selectedTarget))
            else
                warn("Không tìm thấy HumanoidRootPart của bạn!")
            end
        else
            warn(("Không tìm thấy model của %s trong workspace"):format(selectedTarget))
        end
    end
})


-- === 3) Khởi chạy lần đầu ===
rebuildPlayerList()
teleDropdown:SetValues(playerNames)
-- nếu config có value và tồn tại thì set, ngược lại mặc định chọn first
if table.find(playerNames, selectedTarget) then
    teleDropdown:SetValue(selectedTarget)
else
    selectedTarget = playerNames[1]
    teleDropdown:SetValue(selectedTarget)
    config.TeleportPlayer = selectedTarget; saveConfig()
end




local Section = FavoriteTab:AddSection("Favorite Fruits")
-- ======= Auto Favorite Fruits =======
-- 0) Config mặc định
config.AutoFavFruit          = config.AutoFavFruit          or false
config.FavFruitSelection     = config.FavFruitSelection     or { All = true }
config.FavMutSelection       = config.FavMutSelection       or {}
config.FavWeightThreshold    = config.FavWeightThreshold    or 5   -- đưa threshold vào config luôn

-- Khởi tạo biến runtime từ config
local weightThresholdF = config.FavWeightThreshold

-- 1) Multi-Dropdown: Chọn loại trái
local fruitOptions = {
    "All","Carrot","Strawberry","Blueberry","Orange Tulip","Tomato","Corn",
    "Daffodil","Watermelon","Pumpkin","Apple","Bamboo","Coconut",
    "Cactus","Dragon Fruit","Mango","Grape","Mushroom","Pepper",
    "Cacao","Beanstalk","Peach","Pineapple","Chocolate Carrot",
    "Red Lollipop","Candy Sunflower","Easter Egg","Candy Blossom",
    "Raspberry","Durian","Cranberry","Eggplant","Lotus","Venus Flytrap",
    "Rainbow Sack","Papaya","Passionfruit","Banana","Cursed Fruit",
    "Soul Fruit","Nightshade","Glowshroom","Mint","Moonflower",
    "Starfruit","Moonglow","Moon Blossom","Blood Banana","Moon Melon"
}
local mutationOptions = {
    "Celestial","Shocked","Rainbow","Gold","Frozen","Bloodlit","Wet",
    "Zombified","Chilled","Chocolate","Disco"
}

-- 2) Toggle: Auto-favorite
-- 2) Toggle: Auto-favorite
FavoriteTab:AddToggle("AutoFavFruit", {
    Title   = "Auto favorite fruit",
    Default = config.AutoFavFruit,
    Callback = function(state)
        config.AutoFavFruit = state
        saveConfig()
        autoFavFruit = state

        if state then
            -- 1) Khởi tạo set những tool đã favorite sẵn (cả lần trước)
            local alreadyFavored = {}
            for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
                if tool:IsA("Tool") and tool:GetAttribute("Favorite") then
                    alreadyFavored[tool.Name] = true
                end
            end

            task.spawn(function()
                local plr = Players.LocalPlayer
                local favRemote = ReplicatedStorage
                    :WaitForChild("GameEvents")
                    :WaitForChild("Favorite_Item")

                while autoFavFruit do
                    for _, tool in ipairs(plr.Backpack:GetChildren()) do
                        if not tool:IsA("Tool") then continue end
                        local name = tool.Name

                        -- lọc “kg”
                        if not name:lower():find("kg") then continue end

                        -- lọc loại trái
                        local okType = config.FavFruitSelection.All
                        if not okType then
                            okType = false
                            for ft,on in pairs(config.FavFruitSelection) do
                                if on and ft~="All" and name:find(ft) then
                                    okType = true; break
                                end
                            end
                        end
                        if not okType then continue end

                        -- lọc mutation
                        local okMut = true
                        local anyMutSelected = false
                        for mut, on in pairs(config.FavMutSelection) do
                            if mut ~= "All" and on then
                                anyMutSelected = true
                                if name:find(mut) then
                                    okMut = true
                                    break
                                else
                                    okMut = false
                                end
                            end
                        end
                        -- Nếu có chọn mutation mà không tool nào khớp → continue
                        if anyMutSelected and not okMut then
                            continue
                        end

                        -- lọc weight
                        local wtStr = name:match("([%d%.]+)kg")
                        local wnum  = wtStr and tonumber(wtStr) or 0
                        if wnum <= config.FavWeightThreshold then continue end

                        -- kiểm xem đã favorite rồi không
                        if alreadyFavored[name] then
                            continue
                        end

                        -- call remote favorite
                        local args = { plr.Backpack:WaitForChild(name) }
                        pcall(function()
                            favRemote:FireServer(unpack(args))
                        end)
                        -- đánh dấu đã favorite
                        alreadyFavored[name] = true

                        task.wait(0.1)
                    end
                    task.wait(0.1)
                end
            end)
        end
    end
})


-- 3) Multi-Dropdown Fruits Filter
local ddFruit = FavoriteTab:AddDropdown("FavFruitFilter", {
    Title       = "Fruits Filter",
    Description = "Chọn loại trái để favorite",
    Values      = fruitOptions,
    Multi       = true,
    Default     = config.FavFruitSelection,
    Callback    = function(sel)
        config.FavFruitSelection = sel
        saveConfig()
    end
})
ddFruit:SetValue(config.FavFruitSelection)

-- 4) Multi-Dropdown Mutation Filter
local ddMut = FavoriteTab:AddDropdown("FavMutFilter", {
    Title       = "Mutation Filter",
    Description = "Chọn mutation cần filter",
    Values      = mutationOptions,
    Multi       = true,
    Default     = config.FavMutSelection,
    Callback    = function(sel)
        config.FavMutSelection = sel
        saveConfig()
    end
})
ddMut:SetValue(config.FavMutSelection)

-- 5) Input: weight threshold
FavoriteTab:AddInput("WeightThreshold", {
    Title       = "Trái > (kg)",
    Description = "Press Enter after typing",
    Placeholder = "5",
    Default     = tostring(config.FavWeightThreshold),
    Numeric     = true,
    Finished    = true,
    Callback    = function(v)
        local num = tonumber(v)
        if num then
            weightThresholdF = num
            config.FavWeightThreshold = num
            saveConfig()
        else
            warn("Chỉ nhập số hợp lệ!")
        end
    end
})

FavoriteTab:AddButton({
    Title       = "Unfavorite All Fruits",
    Description = "Gọi Remote để unfavorite tất cả fruits đã favorite",
    Callback    = function()
        local plr = Players.LocalPlayer
        local favRemote = ReplicatedStorage
            :WaitForChild("GameEvents")
            :WaitForChild("Favorite_Item")

        -- Duyệt Backpack
        for _, tool in ipairs(plr.Backpack:GetChildren()) do
            if tool:IsA("Tool") and tool:GetAttribute("Favorite") then
                -- Gọi Remote để unfavorite
                pcall(function()
                    favRemote:FireServer(tool)
                end)
                task.wait(0.05)
            end
        end

        -- Duyệt Character (trường hợp đang cầm tool)
        for _, tool in ipairs(plr.Character:GetChildren()) do
            if tool:IsA("Tool") and tool:GetAttribute("Favorite") then
                pcall(function()
                    favRemote:FireServer(tool)
                end)
                task.wait(0.05)
            end
        end

        print("[AutoFavFruit] Đã unfavorite tất cả fruits qua Remote")
    end
})




local startTime = tick()
local uptimeParagraph = ServerTab:AddParagraph({
    Title   = "Server Uptime",
    Content = ("Hour: %02d, Minute: %02d, Second: %02d")
              :format(0, 0, 0)
})

-- Spawn một luồng để update mỗi giây
task.spawn(function()
    while true do
        local elapsed = math.floor(tick() - startTime)
        local hrs  = math.floor(elapsed / 3600)
        local mins = math.floor((elapsed % 3600) / 60)
        local secs = elapsed % 60
        local newText = ("Hour: %02d, Minute: %02d, Second: %02d")
                        :format(hrs, mins, secs)

        -- Quét và set lại text cho label chứa uptime
        for _, desc in ipairs(uptimeParagraph.Frame:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Text:match("Hour:") then
                desc.Text = newText
            end
        end

        task.wait(1)
    end
end)

-- 2) Hàm format & cập nhật lại
local function updateUptime()
    local elapsed = math.floor(tick() - startTime)
    local hrs  = math.floor(elapsed / 3600)
    local mins = math.floor((elapsed % 3600) / 60)
    local secs = elapsed % 60

    local newText = ("Hour: %02d, Minute: %02d, Second: %02d")
                    :format(hrs, mins, secs)

    -- Tùy API của lib UI, dùng method phù hợp:
    if uptimeParagraph.SetContent then
        uptimeParagraph:SetContent(newText)
    elseif uptimeParagraph.SetValue then
        uptimeParagraph:SetValue(newText)
    else
        -- Nếu control lưu text ở .Content
        uptimeParagraph.Content = newText
    end
end

-- 3) Vòng loop cập nhật mỗi 1s
spawn(function()
    while true do
        updateUptime()
        task.wait(1)
    end
end)
-- 1) Tạo Paragraph hiển thị thời gian khởi động
-- Giả sử bạn đã gọi




-- Giả sử bạn đã có biến ServerTab (ví dụ do Fluent UI tạo)
-- local ServerTab = Window:MakeTab("Server", ...)
local jobIdInput
ServerTab:AddInput("JobIdInput", {
    Title       = "Nhập JobId",
    Placeholder = "Paste JobId vào đây",
    Default     = "",
    Numeric     = false, -- JobId có chữ nên false
    Finished    = false, -- không gọi callback onEnter, ta dùng nút bấm
    Callback    = function(txt)
        jobIdInput = txt
        -- Bạn có thể in debug:
        print("[JoinJob] JobId input set to:", jobIdInput)
    end
})
-- 3) Thêm Button “Join ID”
ServerTab:AddButton({
    Title       = "Join ID",
    Description = "Teleport sang server có JobId đã nhập",
    Callback    = function()
        -- Lấy giá trị từ jobIdInput
        local jobId = jobIdInput or ""
        jobId = jobId:match("%S+") or "" -- trim
        if jobId == "" then
            warn("[JoinJob] Vui lòng nhập JobId hợp lệ!")
            return
        end

        -- Lấy PlaceId hiện tại
        local placeId = game.PlaceId

        -- Thực hiện teleport
        print(("[JoinJob] Đang teleport đến Place %d, JobId %s"):format(placeId, jobId))
        pcall(function()
            TeleportService:TeleportToPlaceInstance(placeId, jobId, LocalPlayer)
        end)
    end
})
-- Tạo nút
ServerTab:AddButton({
    Title       = "Copy Job ID",
    Description = "Nhấn để copy Job ID của server hiện tại vào clipboard",
    Callback    = function()
        -- Lấy Job ID
        local jobId = game.JobId or ""
        if jobId == "" then
            warn("[CopyJobId] Không thể lấy JobId!")
            return
        end

        -- Đưa vào clipboard (chỉ hoạt động trên studio hoặc môi trường hỗ trợ setclipboard)
        pcall(function()
            setclipboard(jobId)
        end)

        -- Thông báo cho user
        print("[CopyJobId] Job ID đã được copy vào clipboard:", jobId)
    end
})







local Section = RemoveTab:AddSection("Destroy Plants")
-- Remote event để phá cây
local RemoveItemEvent = ReplicatedStorage
    :WaitForChild("GameEvents")
    :WaitForChild("Remove_Item")

-- State cho AutoRemove
local autoRemove           = false
local selectedPlantNames   = {}

-- Lấy farm của người chơi
local function getMyFarm()
    for _, f in ipairs(workspace.Farm:GetChildren()) do
        local imp  = f:FindFirstChild("Important")
        local data = imp and imp:FindFirstChild("Data")
        local owner= data and data:FindFirstChild("Owner")
        if owner and owner.Value == LocalPlayer.Name then
            return f
        end
    end
    return nil
end

-- [1] Lấy danh sách tên cây duy nhất trong vườn của bạn
local function getUniquePlantNames()
    local farm = getMyFarm()
    if not farm then return {} end

    local phys = farm:FindFirstChild("Important") and farm.Important:FindFirstChild("Plants_Physical")
    if not phys then return {} end

    local seen, names = {}, {}
    for _, mdl in ipairs(phys:GetChildren()) do
        if mdl:IsA("Model") then
            local n = mdl.Name
            if not seen[n] then
                seen[n] = true
                table.insert(names, n)
            end
        end
    end
    return names
end

-- [2] Lấy toàn bộ BasePart con của các cây được chọn
local function getAllTreeParts()
    local parts = {}
    local farm = getMyFarm()
    if not farm then return parts end

    local phys = farm.Important:FindFirstChild("Plants_Physical")
    if not phys then return parts end

    for _, mdl in ipairs(phys:GetChildren()) do
        if mdl:IsA("Model") and selectedPlantNames[mdl.Name] then
            for _, p in ipairs(mdl:GetChildren()) do
                if p:IsA("BasePart") then
                    table.insert(parts, p)
                end
            end
        end
    end
    return parts
end

-- Khởi tạo config nếu chưa có
config.AutoRemoveTrees     = config.AutoRemoveTrees     or false
config.PlantRemoveFilter   = config.PlantRemoveFilter   or {}

-- Toggle để bật/tắt auto remove
RemoveTab:AddToggle("AutoRemoveTrees", {
    Title   = "Tự động phá cây",
    Default = config.AutoRemoveTrees,
    Callback = function(state)
        config.AutoRemoveTrees = state
        saveConfig()
        autoRemove = state

        if state then
            task.spawn(function()
                while autoRemove do
                    -- 1) Chuẩn bị shovel (nếu có trong Backpack)
                    local shovel = LocalPlayer.Backpack:FindFirstChild("Shovel [Destroy Plants]")
                    while isTeleport do task.wait() end
                    isTeleport = true
                    if shovel then
                        Humanoid:EquipTool(shovel)
                        task.wait(0.05)
                    end

                    -- 2) Lấy danh sách Parts cần phá
                    local toDestroy = getAllTreeParts()
                    for _, part in ipairs(toDestroy) do
                        if not autoRemove then break end
                        -- Gửi request phá cây
                        RemoveItemEvent:FireServer(part)
                        task.wait(0.01)
                    end
                    isTeleport = false

                    -- 3) Chờ 5s rồi quét lại
                    task.wait(0.01)
                end
            end)
        end
    end
})
-- === UI Setup (dùng Fluent UI) ===
-- Dropdown để chọn cây muốn phá
local plantDropdown =RemoveTab:AddDropdown("PlantRemoveFilter", {
    Title       = "Chọn cây để phá",
    Description = "Tick chọn những cây sẽ bị phá",
    Values      = getUniquePlantNames(),
    Multi       = true,
    Default     = config.PlantRemoveFilter,
    Callback    = function(selection)
        config.PlantRemoveFilter = selection
        saveConfig()

        -- Build lại bảng lưu tên được chọn
        selectedPlantNames = {}
        for name,on in pairs(selection) do
            if on then
                selectedPlantNames[name] = true
            end
        end

        print("[AutoRemoveTrees] Selected plants:", table.concat((function()
            local t = {}
            for n in pairs(selectedPlantNames) do table.insert(t, n) end
            return t
        end)(), ", "))
    end
})
-- Gán lại giá trị dropdown từ config
plantDropdown:SetValue(config.PlantRemoveFilter)



-- [4] Nút làm mới danh sách (chỉ sửa callback ở đây)
RemoveTab:AddButton({
    Title       = "🔄 Refresh Plant list",
    Description = "",
    Callback = function()
        -- Lấy danh sách tên cây mới
        local opts = getUniquePlantNames()

        -- Cập nhật lại values cho dropdown
        plantDropdown:SetValues(opts)

        -- Reset selection: clear config và UI
        config.PlantRemoveFilter = {}
        saveConfig()
        plantDropdown:SetValue({})

        selectedPlantNames = {}

        print("[AutoRemoveTrees] Đã làm mới danh sách cây và bỏ chọn hết")
    end
})





local Section = RemoveTab:AddSection("Sell Pet Inventory")
-- Remote Sell Pet
local SellPetRemote = ReplicatedStorage
    :WaitForChild("GameEvents")
    :WaitForChild("SellPet_RE")

-- ======== 0) Config mặc định ========
config.AutoSellPets      = config.AutoSellPets      or false
config.PetsToSell        = config.PetsToSell        or { ["All (except favorite)"] = true }

-- ======== 1) Hàm helper: Lấy tất cả tools chứa "Age" ========
local function getAllAgeTools()
    local out = {}
    for _, container in ipairs({LocalPlayer.Backpack, Character}) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") and tool.Name:find("Age") then
                    table.insert(out, tool)
                end
            end
        end
    end
    return out
end

-- ======== 2) Helper: Build danh sách dropdown ========
local function buildPetList()
    local list = {"All (except favorite Pets)"}
    for _, tool in ipairs(getAllAgeTools()) do
        table.insert(list, tool.Name)
    end
    return list
end

-- ======== 3) Toggle Auto Sell Pets ========
local autoSellPets = config.AutoSellPets
RemoveTab:AddToggle("AutoSellPets", {
    Title   = "Auto Sell Pets",
    Default = autoSellPets,
    Callback = function(state)
        config.AutoSellPets = state
        saveConfig()
        autoSellPets = state

        if state then
            -- processed map để tránh spam remote tool cũ
            local processed = {}

            task.spawn(function()
                while autoSellPets do
                    -- quét toàn bộ tools chứa "Age"
                    local list = getAllAgeTools()
                    for _, tool in ipairs(list) do
                        if not autoSellPets then break end

                        -- điều kiện:
                        -- 1) tool chưa được favorite (attribute Favorite)
                        -- 2) chưa processed
                        local fav = tool:GetAttribute("Favorite")
                        if fav then continue end
                        if processed[tool] then continue end

                        -- 3) check dropdown selection
                        local sel = config.PetsToSell
                        local allOk = sel["All (except favorite)"]
                        if not allOk then
                            if not sel[tool.Name] then continue end
                        end

                        -- gọi remote
                        pcall(function()
                            SellPetRemote:FireServer(tool)
                        end)
                        -- đánh dấu đã processed
                        processed[tool] = true

                        task.wait(0.1)
                    end

                    -- cleanup processed: bỏ tool đã biến mất
                    for t,_ in pairs(processed) do
                        if not t.Parent then
                            processed[t] = nil
                        end
                    end

                    task.wait(0.5)
                end
            end)
        end
    end
})

-- ======== 4) Dropdown chọn pets to sell ========
local petList = buildPetList()
local ddPets = RemoveTab:AddDropdown("PetsToSell", {
    Title       = "Pets to Remove",
    Description = "except favorite Pets",
    Values      = petList,
    Multi       = true,
    Default     = config.PetsToSell,
    Callback    = function(selection)
        config.PetsToSell = selection
        saveConfig()
    end
})
ddPets:SetValue(config.PetsToSell)

-- ======== 5) Button Refresh danh sách pets ========
RemoveTab:AddButton({
    Title       = "🔄 Refresh Pets List",
    Description = "",
    Callback    = function()
        local newList = buildPetList()
        ddPets:SetValues(newList)
        -- giữ selection cũ (nếu vẫn tồn tại)
        ddPets:SetValue(config.PetsToSell)
        print("[AutoSellPets] Pets list refreshed.")
    end
})






local Section = FavoriteTab:AddSection("Favorite Pets")
-- 0) Config & Require
config.AutoFavPets     = config.AutoFavPets     or false
config.PetFavSelection = config.PetFavSelection or {}    -- map[name]=true

-- Remote
local favRemote = ReplicatedStorage
    :WaitForChild("GameEvents")
    :WaitForChild("Favorite_Item")

-- 1) Hàm check một tool có match selection không
local function toolMatchesSelection(toolName)
    -- duyệt qua các key trong config.PetFavSelection
    for selectedName, on in pairs(config.PetFavSelection) do
        if on then
            -- so sánh lowercase, tránh phân biệt hoa thường
            if string.lower(toolName):find(string.lower(selectedName)) then
                return true
            end
        end
    end
    return false
end

-- 2) UI: Dropdown chọn pet keyword
local allPetKeywords = {
    "Dragonfly","Raccoon","Red Giant Ant","Giant Ant","Mole","Praying Mantis",
    "Caterpillar","Snail","Echo Frog","Cow","Sea Otter","Moon Cat","Silver Monkey",
    "Squirrel","Chicken Zombie","Frog","Monkey","Pig","Grey Mouse","Blood Hedgehog",
    "Hedgehog","Panda","Turtle","Golden Lab","Owl","Polar Bear","Blood Kiwi","Kiwi",
    "Rooster","Blood Owl","Brown Mouse","Night Owl","Orange Tabby","Spotted Deer",
    "Cat","Chicken","Deer","Black Bunny","Bunny","Dog","Firefly"
}

local ddPets = FavoriteTab:AddDropdown("PetFavSelection", {
    Title       = "Select Pets to Favorite",
    Description = "",
    Values      = allPetKeywords,
    Multi       = true,
    Default     = config.PetFavSelection,
    Callback    = function(selection)
        config.PetFavSelection = selection
        saveConfig()
    end
})
ddPets:SetValue(config.PetFavSelection)

-- 3) Toggle Auto Favorite Pets
FavoriteTab:AddToggle("AutoFavPets", {
    Title   = "Auto Favorite Pets",
    Default = config.AutoFavPets,
    Callback = function(state)
        config.AutoFavPets = state
        saveConfig()
        autoFavPets = state

        if autoFavPets then
            task.spawn(function()
                local processed = {} -- để tránh favorite trùng
                while autoFavPets do
                    for _,tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
                        if not tool:IsA("Tool") then
                            continue
                        end

                        local name = tool.Name
                        -- 1) Tool phải match với dropdown selection
                        if not toolMatchesSelection(name) then
                            continue
                        end

                        -- 2) Tool chưa được processed và chưa favorite (Attribute)
                        if processed[tool] then
                            continue
                        end
                        if tool:GetAttribute("Favorite") then
                            processed[tool] = true
                            continue
                        end

                        -- 3) Gọi remote favorite
                        pcall(function()
                            favRemote:FireServer(tool)
                        end)
                        processed[tool] = true
                        -- dành chút thời gian để game kịp xử lý
                        task.wait(0.1)
                    end

                    -- Dọn dẹp processed map: loại bỏ tool đã bị xoá (sell, drop…)
                    for t,_ in pairs(processed) do
                        if not t.Parent then
                            processed[t] = nil
                        end
                    end

                    task.wait(0.1)
                end
            end)
        end
    end
})
-- … (phần code ở trên) …

-- 4) Button: Unfavorite All Pets
FavoriteTab:AddButton({
    Title       = "Unfavorite All Pets",
    Description = "Gọi remote để unfavorite tất cả pet tools có 'Age' & đang favorite",
    Callback    = function()
        local favRemote = ReplicatedStorage
            :WaitForChild("GameEvents")
            :WaitForChild("Favorite_Item")

        -- Duyệt cả Backpack và Character
        local function processContainer(container)
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") then
                    local nameLower = tool.Name:lower()
                    -- chỉ quan tâm tool có "age" và attribute Favorite == true
                    if nameLower:find("age") and tool:GetAttribute("Favorite") then
                        -- Gọi remote với chính instance tool đó
                        pcall(function()
                            favRemote:FireServer(tool)
                        end)
                        task.wait(0.05)
                    end
                end
            end
        end

        -- Unfavorite trong Backpack
        processContainer(LocalPlayer.Backpack)
        -- Unfavorite trên Character (nếu đang cầm tool)
        processContainer(LocalPlayer.Character or {})

        print("[PetFavorites] Đã unfavorite hết pets có 'Age'")
    end
})



-- Khởi config lần đầu
config.ReduceGraphics = config.ReduceGraphics or false

-- Toggle Reduce Graphics
local reduceToggle = ServerTab:AddToggle("ReduceGraphics", {
    Title   = "Reduce Graphics",
    Default = config.ReduceGraphics,
    Callback = function(state)
        config.ReduceGraphics = state
        saveConfig()

        if state then
            -- 1) Danh sách tên container cần xử lý
            local containerNames = {
                "TopBaseplate",
                "NightEvent",
                "PetsPhysical",
                "Farm"
            }

            -- 2) Gom container instances (chờ tối đa 5s mỗi cái)
            local containers = {}
            for _, name in ipairs(containerNames) do
                local ok, inst = pcall(function()
                    return workspace:WaitForChild(name, 5)
                end)
                if ok and inst then
                    containers[#containers+1] = inst
                else
                    warn(("[ReduceGraphics] Không tìm thấy %s sau 5s, bỏ qua"):format(name))
                end
            end

            -- 3) Set đã xử lý để không set lại chồng chéo
            local known = {}

            -- 4) Hàm đổi material + tắt cast shadow
            local function reduce(part)
                if part:IsA("BasePart") and not known[part] then
                    part.Material   = Enum.Material.Air
                    part.CastShadow = false
                    known[part]     = true
                end
            end

            -- 5) Quét một lượt tất cả container và descendants
            for _, cont in ipairs(containers) do
                -- 5a) Nếu chính nó là Part thì xử lý luôn
                reduce(cont)
                -- 5b) Quét descendants
                for _, desc in ipairs(cont:GetDescendants()) do
                    reduce(desc)
                end
            end

            -- 6) Đăng listener cho mỗi container, bắt phần tử mới
            for _, cont in ipairs(containers) do
                cont.DescendantAdded:Connect(function(inst)
                    reduce(inst)
                end)
            end

            print("[ReduceGraphics] Đã bật – mọi BasePart cũ và mới trong các container sẽ thành Air + không đổ bóng.")
        else
            print("[ReduceGraphics] Đã tắt – sẽ không tự động giảm đồ họa nữa.")
            -- Lưu ý: các Part đã chuyển sang Air + tắt đổ bóng sẽ không tự phục hồi.
        end
    end
})

-- Khởi toggle theo config
reduceToggle:SetValue(config.ReduceGraphics)






-- Final FruitValueUI.lua: updated drag logic for smooth dragging without jump
ServerTab:AddButton({
    Title = "Fruits information in your garden",
    Desc  = "Show the values of fruits and the total fruit",
    Callback = function()
        local Players           = game:GetService("Players")
        local UserInputService  = game:GetService("UserInputService")
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local player            = Players.LocalPlayer
        local PlayerGui         = player:FindFirstChild("PlayerGui")
        if not PlayerGui then
            warn("Không tìm thấy PlayerGui!")
            return
        end

        local ItemModule      = require(ReplicatedStorage:WaitForChild("Item_Module"))
        local MutationHandler = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MutationHandler"))

        local function formatNumber(num)
            local str = tostring(num)
            while true do
                str, _ = str:gsub("^(-?%d+)(%d%d%d)", "%1.%2")
                if _ == 0 then break end
            end
            return str
        end

        local function getMyFarm()
            local farmFolder = workspace:FindFirstChild("Farm")
            if not farmFolder then return nil end
            for _, farm in ipairs(farmFolder:GetChildren()) do
                local imp = farm:FindFirstChild("Important")
                local data = imp and imp:FindFirstChild("Data")
                if data and data:FindFirstChild("Owner") and data.Owner.Value == player.Name then
                    return farm
                end
            end
            return nil
        end

        local function calcFruitValue(fruitModel)
            local itemName = fruitModel:FindFirstChild("Item_String") and fruitModel.Item_String.Value or fruitModel.Name
            local variantObj = fruitModel:FindFirstChild("Variant")
            local weightObj  = fruitModel:FindFirstChild("Weight")
            if not (variantObj and weightObj) then return 0 end
            local data = ItemModule.Return_Data(itemName)
            if not data or #data < 3 then return 0 end
            local tierWeight = data[2]
            local baseValue  = data[3]
            local variantMult= ItemModule.Return_Multiplier(variantObj.Value) or 1
            local mutMult    = MutationHandler:CalcValueMulti(fruitModel)
            local ratio      = math.clamp(weightObj.Value/tierWeight,0.95,1e8)
            return math.round(baseValue * variantMult * mutMult * (ratio*ratio))
        end

        local function computeTop10()
            local farm = getMyFarm()
            if not farm then return nil, "❌ Không tìm thấy farm của bạn!" end
            local phys = farm:FindFirstChild("Important") and farm.Important:FindFirstChild("Plants_Physical")
            if not phys then return nil, "❌ Không tìm thấy Plants_Physical!" end

            local list, totalCount, totalValue = {},0,0
            for _, obj in ipairs(phys:GetChildren()) do
                if obj:IsA("Model") then
                    local function handle(f)
                        local v = calcFruitValue(f)
                        totalCount+=1; totalValue+=v
                        table.insert(list,{ Name=f:FindFirstChild("Item_String") and f.Item_String.Value or f.Name,
                                             Weight=f:FindFirstChild("Weight") and f.Weight.Value or 0,
                                             Value=v,
                                             Mutations=MutationHandler:GetMutationsAsString(f,true) or "" })
                    end
                    local pp = obj.PrimaryPart
                    if pp and pp.Name:lower():find("base") then
                        local fruits = obj:FindFirstChild("Fruits")
                        if fruits then for _, f in ipairs(fruits:GetChildren()) do if f:IsA("Model") then handle(f) end end end
                    else
                        handle(obj)
                    end
                end
            end
            table.sort(list,function(a,b)return a.Value>b.Value end)
            return {top=list,totalCount=totalCount,totalValue=totalValue}
        end

        local existing = PlayerGui:FindFirstChild("FruitValueFrame")
        if existing then existing:Destroy() end

        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "FruitValueFrame"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = PlayerGui

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0,420,0,380)
        frame.Position = UDim2.new(0.5,-210,0.5,-190)
        frame.AnchorPoint = Vector2.new(0.5,0.5)
        frame.BackgroundColor3 = Color3.fromRGB(24,24,24)
        frame.BorderSizePixel = 0
        frame.Parent = screenGui
        Instance.new("UICorner",frame).CornerRadius=UDim.new(0,12)
        Instance.new("UIStroke",frame).Transparency=0.8; frame.UIStroke.Thickness=1

        local titleBar=Instance.new("Frame",frame)
        titleBar.Size=UDim2.new(1,0,0,36)
        titleBar.BackgroundColor3=Color3.fromRGB(40,40,40)
        titleBar.BorderSizePixel=0
        Instance.new("UICorner",titleBar).CornerRadius=UDim.new(0,12)

        local title=Instance.new("TextLabel",titleBar)
        title.Text="📊 Fruit Values"
        title.Size=UDim2.new(1,-48,1,0)
        title.Position=UDim2.new(0,12,0,0)
        title.BackgroundTransparency=1
        title.Font=Enum.Font.GothamBold
        title.TextSize=20
        title.TextColor3=Color3.fromRGB(255,255,255)
        title.TextXAlignment=Enum.TextXAlignment.Left

        local closeBtn=Instance.new("TextButton",titleBar)
        closeBtn.Text="x"
        closeBtn.Size=UDim2.new(0,32,0,32)
        closeBtn.Position=UDim2.new(1,-36,0,2)
        closeBtn.BackgroundTransparency=1
        closeBtn.Font=Enum.Font.GothamBold
        closeBtn.TextSize=30
        closeBtn.TextColor3=Color3.fromRGB(200,80,80)
        closeBtn.ZIndex=5
        closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)

        local scroll=Instance.new("ScrollingFrame",frame)
        scroll.Size=UDim2.new(1,-24,1,-60)
        scroll.Position=UDim2.new(0,12,0,44)
        scroll.BackgroundTransparency=1
        scroll.ScrollBarThickness=6
        local uiList=Instance.new("UIListLayout",scroll)
        uiList.Padding=UDim.new(0,12)
        uiList.SortOrder=Enum.SortOrder.LayoutOrder
        Instance.new("UIPadding",scroll).PaddingTop=UDim.new(0,4)

        local data,err=computeTop10()
        if not data then
            local lbl=Instance.new("TextLabel",scroll)
            lbl.Text=err
            lbl.Size=UDim2.new(1,0,0,24)
            lbl.BackgroundTransparency=1
            lbl.Font=Enum.Font.Gotham
            lbl.TextSize=16
            lbl.TextColor3=Color3.fromRGB(255,150,150)
            lbl.TextXAlignment=Enum.TextXAlignment.Center
        else
            local header=Instance.new("TextLabel",scroll)
            header.Text=string.format("Total: %s fruits | Value: %s $",formatNumber(data.totalCount),formatNumber(data.totalValue))
            header.Size=UDim2.new(1,0,0,24)
            header.BackgroundTransparency=1
            header.Font=Enum.Font.GothamBold
            header.TextSize=20
            header.TextColor3=Color3.fromRGB(255,255,255)
            header.TextXAlignment=Enum.TextXAlignment.Center

            for i=1,math.min(10,#data.top) do
                local f=data.top[i]
                local entry=Instance.new("TextLabel",scroll)
                entry.RichText=true
                entry.Text=string.format(
                    "<font color=\"rgb(255,80,80)\">[%d]</font> <font color=\"rgb(255,255,255)\">%s</font> <font color=\"rgb(0,255,0)\">%s</font> <font color=\"rgb(0,255,0)\">$</font>\n<font color=\"rgb(150,150,150)\">   %.2fkg    %s</font>",
                    i, f.Name, formatNumber(f.Value), f.Weight, f.Mutations
                )
                entry.Size=UDim2.new(1,0,0,36)
                entry.BackgroundTransparency=1
                entry.Font=Enum.Font.GothamBold
                entry.TextSize=16
                entry.TextXAlignment=Enum.TextXAlignment.Center
                entry.TextYAlignment=Enum.TextYAlignment.Top
                entry.TextWrapped=true
            end
        end

        -- Smooth drag logic
        local dragging = false
        local startMouse = Vector2.new()
        local startPos = frame.Position

        titleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                startMouse = input.Position
                startPos = frame.Position
            end
        end)

        titleBar.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - startMouse
                frame.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)
    end,
})



-- Biến kiểm soát
ServerTab:AddToggle("dupe", {
	Title = "Dupe",
	Default = false,

	Callback = function(val)
		dupe_enabled = val
		if val then
			task.spawn(function()
				while dupe_enabled and task.wait(0.0001) do -- mỗi giây kiểm tra lại
					for _, pt in pairs(Players:GetPlayers()) do
						pcall(function()
							if pt ~= player and pt.Character then
								local tool = pt.Character:FindFirstChildOfClass("Tool")
								if tool and tool:GetAttribute("ItemType") == "Pet" then
									local Event = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("SellPet_RE")
									Event:FireServer(tool)
								end
							end
						end)
					end
				end
			end)
		end
	end
})




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
