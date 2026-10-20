local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function isValidKey(key)
    if type(key) ~= "string" then return false end
    key = string.upper(key)
    local pattern = "^ORHB%-%w%w%w%w%-%w%w%w%w%-%w%w%w%w%-%w%w%w%w$"
    return string.match(key, pattern) ~= nil
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "KeySystem"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 2147483647
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 460, 0, 300)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(13, 13, 13)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = mainFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(35, 35, 35)
stroke.Thickness = 1
stroke.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 30)
title.Position = UDim2.new(0, 20, 0, 20)
title.BackgroundTransparency = 1
title.Text = "KEY SYSTEM"
title.TextColor3 = Color3.fromRGB(237, 237, 237)
title.TextSize = 18
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = mainFrame

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -40, 0, 20)
subtitle.Position = UDim2.new(0, 20, 0, 48)
subtitle.BackgroundTransparency = 1
subtitle.Text = "ORHB Authentication"
subtitle.TextColor3 = Color3.fromRGB(138, 138, 138)
subtitle.TextSize = 12
subtitle.Font = Enum.Font.Gotham
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = mainFrame

local step1 = Instance.new("TextLabel")
step1.Size = UDim2.new(1, -40, 0, 18)
step1.Position = UDim2.new(0, 20, 0, 85)
step1.BackgroundTransparency = 1
step1.Text = "Step 1 — Get your key from the website"
step1.TextColor3 = Color3.fromRGB(180, 180, 180)
step1.TextSize = 12
step1.Font = Enum.Font.Gotham
step1.TextXAlignment = Enum.TextXAlignment.Left
step1.Parent = mainFrame

local getKeyBtn = Instance.new("TextButton")
getKeyBtn.Size = UDim2.new(1, -40, 0, 36)
getKeyBtn.Position = UDim2.new(0, 20, 0, 110)
getKeyBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
getKeyBtn.BorderSizePixel = 0
getKeyBtn.Text = "Get Key"
getKeyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
getKeyBtn.TextSize = 13
getKeyBtn.Font = Enum.Font.GothamMedium
getKeyBtn.Parent = mainFrame

local getKeyCorner = Instance.new("UICorner")
getKeyCorner.CornerRadius = UDim.new(0, 6)
getKeyCorner.Parent = getKeyBtn

local step2 = Instance.new("TextLabel")
step2.Size = UDim2.new(1, -40, 0, 18)
step2.Position = UDim2.new(0, 20, 0, 160)
step2.BackgroundTransparency = 1
step2.Text = "Step 2 — Paste your key below"
step2.TextColor3 = Color3.fromRGB(180, 180, 180)
step2.TextSize = 12
step2.Font = Enum.Font.Gotham
step2.TextXAlignment = Enum.TextXAlignment.Left
step2.Parent = mainFrame

local keyInput = Instance.new("TextBox")
keyInput.Size = UDim2.new(1, -40, 0, 36)
keyInput.Position = UDim2.new(0, 20, 0, 185)
keyInput.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
keyInput.BorderSizePixel = 0
keyInput.Text = ""
keyInput.PlaceholderText = "Enter your key"
keyInput.TextColor3 = Color3.fromRGB(237, 237, 237)
keyInput.PlaceholderColor3 = Color3.fromRGB(85, 85, 85)
keyInput.TextSize = 13
keyInput.Font = Enum.Font.Code
keyInput.ClearTextOnFocus = false
keyInput.Parent = mainFrame

local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 6)
inputCorner.Parent = keyInput

local inputStroke = Instance.new("UIStroke")
inputStroke.Color = Color3.fromRGB(35, 35, 35)
inputStroke.Thickness = 1
inputStroke.Parent = keyInput

local verifyBtn = Instance.new("TextButton")
verifyBtn.Size = UDim2.new(1, -40, 0, 40)
verifyBtn.Position = UDim2.new(0, 20, 0, 238)
verifyBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
verifyBtn.BorderSizePixel = 0
verifyBtn.Text = "Verify"
verifyBtn.TextColor3 = Color3.fromRGB(237, 237, 237)
verifyBtn.TextSize = 14
verifyBtn.Font = Enum.Font.GothamMedium
verifyBtn.Parent = mainFrame

local verifyCorner = Instance.new("UICorner")
verifyCorner.CornerRadius = UDim.new(0, 6)
verifyCorner.Parent = verifyBtn

local function notify(text, color)
    local notifyFrame = Instance.new("Frame")
    notifyFrame.Size = UDim2.new(0, 300, 0, 50)
    notifyFrame.Position = UDim2.new(1, 20, 0, 20)
    notifyFrame.BackgroundColor3 = Color3.fromRGB(13, 13, 13)
    notifyFrame.BorderSizePixel = 0
    notifyFrame.Parent = screenGui

    local nCorner = Instance.new("UICorner")
    nCorner.CornerRadius = UDim.new(0, 8)
    nCorner.Parent = notifyFrame

    local nStroke = Instance.new("UIStroke")
    nStroke.Color = color
    nStroke.Thickness = 1
    nStroke.Parent = notifyFrame

    local nText = Instance.new("TextLabel")
    nText.Size = UDim2.new(1, -20, 1, 0)
    nText.Position = UDim2.new(0, 10, 0, 0)
    nText.BackgroundTransparency = 1
    nText.Text = text
    nText.TextColor3 = Color3.fromRGB(237, 237, 237)
    nText.TextSize = 13
    nText.Font = Enum.Font.Gotham
    nText.Parent = notifyFrame

    TweenService:Create(notifyFrame, TweenInfo.new(0.3), {
        Position = UDim2.new(1, -320, 0, 20)
    }):Play()

    task.wait(3)

    TweenService:Create(notifyFrame, TweenInfo.new(0.3), {
        Position = UDim2.new(1, 20, 0, 20)
    }):Play()

    task.wait(0.3)
    notifyFrame:Destroy()
end

getKeyBtn.MouseButton1Click:Connect(function()
    setclipboard("https://x.gd/getkey")
    notify("URL copied — open in browser", Color3.fromRGB(88, 101, 242))
end)

getKeyBtn.MouseEnter:Connect(function()
    TweenService:Create(getKeyBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(71, 82, 196)
    }):Play()
end)

getKeyBtn.MouseLeave:Connect(function()
    TweenService:Create(getKeyBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(88, 101, 242)
    }):Play()
end)

verifyBtn.MouseButton1Click:Connect(function()
    if isValidKey(keyInput.Text) then
        screenGui:Destroy()
        task.wait(0.3)
        loadstring(game:HttpGet("https://h1.nu/orynhub"))()
    else
        notify("Invalid key", Color3.fromRGB(248, 81, 73))
        inputStroke.Color = Color3.fromRGB(248, 81, 73)
        task.wait(0.5)
        inputStroke.Color = Color3.fromRGB(35, 35, 35)
    end
end)

verifyBtn.MouseEnter:Connect(function()
    TweenService:Create(verifyBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(46, 46, 46)
    }):Play()
end)

verifyBtn.MouseLeave:Connect(function()
    TweenService:Create(verifyBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    }):Play()
end)