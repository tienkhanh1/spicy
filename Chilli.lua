-- Tải thư viện Fluent UI
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

-- Tạo cửa sổ chính
local Window = Fluent:CreateWindow({
    Title = "Grow a Garden - Chilli GUI",
    SubTitle = "Bản thử nghiệm hỗ trợ chơi",
    TabWidth = 160,
    Size = UDim2.fromOffset(520, 400),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

-- Tab chính
local MainTab = Window:AddTab({ Title = "Chính", Icon = "leaf" })

-- Toggle: Tự động tưới cây
MainTab:AddToggle("AutoWater", {
    Title = "Tự động tưới cây",
    Default = false,
    Callback = function(state)
        print("AutoWater:", state)
        -- TODO: Thêm logic tưới cây ở đây
    end
})

-- Toggle: Tự động thu hoạch
MainTab:AddToggle("AutoHarvest", {
    Title = "Tự động thu hoạch",
    Default = false,
    Callback = function(state)
        print("AutoHarvest:", state)
        -- TODO: Thêm logic thu hoạch ở đây
    end
})

-- Toggle: Tự động bán cây
MainTab:AddToggle("AutoSell", {
    Title = "Tự động bán cây",
    Default = false,
    Callback = function(state)
        print("AutoSell:", state)
        -- TODO: Thêm logic bán cây ở đây
    end
})

-- Dropdown: Lọc mutation
MainTab:AddDropdown("MutationFilter", {
    Title = "Lọc đột biến ưu tiên",
    Values = { "Tất cả", "Golden", "Rainbow", "Frozen", "Shocked", "Chocolate", "Moonlit" },
    Multi = false,
    Default = 1,
    Callback = function(selected)
        print("Đã chọn lọc mutation:", selected)
        -- TODO: Thêm xử lý lọc mutation
    end
})

-- Ghi chú
MainTab:AddParagraph({
    Title = "Thông tin",
    Content = "Đây là bản thử nghiệm. Nhấn phím Ctrl phải để ẩn/hiện GUI."
})
