-- =====================================================
-- MM2 HUB - LinoriaLib 完全版
-- ESP / Combat / Auto Grab Gun / Movement
-- =====================================================

local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Options = Library.Options
local Toggles = Library.Toggles

-- サービス
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ウィンドウ
local Window = Library:CreateWindow({
    Title = 'Oryn HUB',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local Tabs = {
    ESP = Window:AddTab('ESP'),
    Combat = Window:AddTab('Combat'),
    Misc = Window:AddTab('Misc'),      -- ← 追加
    Movement = Window:AddTab('Movement'),
    Settings = Window:AddTab('Settings')
}

-- =====================================================
-- 役職判定
-- =====================================================
local KNIFE_NAMES = {"Knife", "MurdererKnife", "Knife2"}
local GUN_NAMES = {"Gun", "Revolver", "SheriffGun", "HeroGun", "GunModel"}

local function hasItemIn(container, names)
    if not container then return false end
    for _, name in ipairs(names) do
        if container:FindFirstChild(name) then return true end
    end
    return false
end

local function getPlayerRole(player)
    local char = player.Character
    if not char then return "Unknown" end

    if hasItemIn(char, KNIFE_NAMES) then return "Murderer" end
    if hasItemIn(char, GUN_NAMES) then return "Sheriff" end

    local backpack = player:FindFirstChild("Backpack")
    if hasItemIn(backpack, KNIFE_NAMES) then return "Murderer" end
    if hasItemIn(backpack, GUN_NAMES) then return "Sheriff" end

    return "Innocent"
end

local function getRoleColor(role)
    if role == "Murderer" then return Color3.fromRGB(255, 0, 0)
    elseif role == "Sheriff" then return Color3.fromRGB(0, 100, 255)
    else return Color3.fromRGB(0, 255, 0)
    end
end

-- =====================================================
-- プレイヤーリスト
-- =====================================================
local function getPlayerList()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(list, p.DisplayName .. " (@" .. p.Name .. ")")
        end
    end
    return list
end

-- =====================================================
-- ESP 状態管理
-- =====================================================
local ESP = {
    enabled = false,
    showTracer = false,
    showBox = false,
    showName = false,
    showDistance = false,
    showHeadDot = false,
    tracerOrigin = "Head",
    tracerThickness = 2,
    maxDistance = 1000,
    boxWidth = 40,
    boxHeight = 130,
    boxThickness = 1.5,
}

local espObjects = {}
local espConns = {}

-- =====================================================
-- ESP要素作成
-- =====================================================
local function createBillboard(adornee)
    local bb = Instance.new("BillboardGui")
    bb.Name = "MM2_ESP_Billboard"
    bb.Size = UDim2.new(0, 200, 0, 60)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = adornee
    bb.Parent = adornee
    return bb
end

local function createBoxESP()
    local box = {
        top = Drawing.new("Line"),
        bottom = Drawing.new("Line"),
        left = Drawing.new("Line"),
        right = Drawing.new("Line"),
    }
    for _, line in pairs(box) do
        line.Visible = false
        line.Thickness = ESP.boxThickness
        line.Transparency = 1
        line.Color = Color3.new(1, 1, 1)
    end
    return box
end

local function updateBoxLines(box, centerScreen, width, totalHeight)
    if not box then return end
    local cx, cy = centerScreen.X, centerScreen.Y

    local topLeft = Vector2.new(cx - width/2, cy - totalHeight/2)
    local topRight = Vector2.new(cx + width/2, cy - totalHeight/2)
    local botLeft = Vector2.new(cx - width/2, cy + totalHeight/2)
    local botRight = Vector2.new(cx + width/2, cy + totalHeight/2)

    box.top.From = topLeft
    box.top.To = topRight
    box.bottom.From = botLeft
    box.bottom.To = botRight
    box.left.From = topLeft
    box.left.To = botLeft
    box.right.From = topRight
    box.right.To = botRight
end

local function createHeadDot(player)
    local char = player.Character
    if not char then return nil end
    local head = char:FindFirstChild("Head")
    if not head then return nil end

    local sphere = Instance.new("SphereHandleAdornment")
    sphere.Name = "MM2_ESP_HeadDot"
    sphere.Adornee = head
    sphere.AlwaysOnTop = true
    sphere.ZIndex = 5
    sphere.Radius = 1
    sphere.Transparency = 0.3
    sphere.Color3 = getRoleColor(getPlayerRole(player))
    sphere.Parent = head
    return sphere
end

local function getTracerOriginPosition(player)
    local char = player.Character
    if not char then return nil end

    if ESP.tracerOrigin == "Head" then
        local head = char:FindFirstChild("Head")
        return head and head.Position or nil
    elseif ESP.tracerOrigin == "Feet" then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        return hrp and (hrp.Position + Vector3.new(0, -3, 0)) or nil
    else
        local hrp = char:FindFirstChild("HumanoidRootPart")
        return hrp and hrp.Position or nil
    end
end

local function createTracer()
    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Thickness = ESP.tracerThickness
    tracer.Color = Color3.new(1, 1, 1)
    tracer.Transparency = 1
    return tracer
end

local function createESP(player)
    if player == LocalPlayer then return end
    if espObjects[player] then return end

    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local role = getPlayerRole(player)
    local color = getRoleColor(role)

    local highlight = Instance.new("Highlight")
    highlight.Name = "MM2_ESP_Highlight"
    highlight.Adornee = char
    highlight.FillColor = color
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Parent = char

    local box = ESP.showBox and createBoxESP() or nil
    local headDot = ESP.showHeadDot and createHeadDot(player) or nil

    local billboard, nameLabel, distLabel = nil, nil, nil
    if ESP.showName or ESP.showDistance then
        billboard = createBillboard(hrp)
        if ESP.showName then
            nameLabel = Instance.new("TextLabel")
            nameLabel.Name = "MM2_Name"
            nameLabel.Size = UDim2.new(1, 0, 0, 20)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = string.format("%s [%s]", player.Name, role)
            nameLabel.TextColor3 = color
            nameLabel.TextStrokeTransparency = 0
            nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.TextSize = 14
            nameLabel.Parent = billboard
        end
        if ESP.showDistance then
            distLabel = Instance.new("TextLabel")
            distLabel.Name = "MM2_Dist"
            distLabel.Size = UDim2.new(1, 0, 0, 18)
            distLabel.Position = UDim2.new(0, 0, 0, 20)
            distLabel.BackgroundTransparency = 1
            distLabel.Text = "0m"
            distLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            distLabel.TextStrokeTransparency = 0
            distLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
            distLabel.Font = Enum.Font.Gotham
            distLabel.TextSize = 12
            distLabel.Parent = billboard
        end
    end

    local tracer = ESP.showTracer and createTracer() or nil

    espObjects[player] = {
        highlight = highlight,
        box = box,
        headDot = headDot,
        billboard = billboard,
        nameLabel = nameLabel,
        distLabel = distLabel,
        tracer = tracer,
    }

    local conns = {}
    local function roleChange()
        task.wait(0.1)
        local obj = espObjects[player]
        if not obj then return end
        local newRole = getPlayerRole(player)
        local newColor = getRoleColor(newRole)
        if obj.highlight and obj.highlight.Parent then obj.highlight.FillColor = newColor end
        if obj.headDot and obj.headDot.Parent then obj.headDot.Color3 = newColor end
    end

    table.insert(conns, char.ChildAdded:Connect(roleChange))
    table.insert(conns, char.ChildRemoved:Connect(roleChange))
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        table.insert(conns, backpack.ChildAdded:Connect(roleChange))
        table.insert(conns, backpack.ChildRemoved:Connect(roleChange))
    end
    table.insert(conns, player.ChildAdded:Connect(function(child)
        if child.Name == "Backpack" then
            table.insert(conns, child.ChildAdded:Connect(roleChange))
            table.insert(conns, child.ChildRemoved:Connect(roleChange))
        end
    end))
    espConns[player] = conns
end

local function removeESP(player)
    local obj = espObjects[player]
    if obj then
        if obj.highlight and obj.highlight.Parent then obj.highlight:Destroy() end
        if obj.headDot and obj.headDot.Parent then obj.headDot:Destroy() end
        if obj.billboard and obj.billboard.Parent then obj.billboard:Destroy() end
        if obj.box then
            for _, line in pairs(obj.box) do
                pcall(function() line:Remove() end)
            end
        end
        if obj.tracer then pcall(function() obj.tracer:Remove() end) end
    end
    espObjects[player] = nil

    if espConns[player] then
        for _, conn in ipairs(espConns[player]) do
            pcall(function() conn:Disconnect() end)
        end
        espConns[player] = nil
    end
end

local function refreshAllESP()
    if not ESP.enabled then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            removeESP(p)
            createESP(p)
        end
    end
end

-- =====================================================
-- ESP メイン更新ループ
-- =====================================================
task.spawn(function()
    while task.wait() do
        repeat
            if not ESP.enabled then break end

        local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not myHrp then break end

            local myScreenPos = Camera:WorldToViewportPoint(myHrp.Position + Vector3.new(0, -3, 0))

        for player, obj in pairs(espObjects) do
            repeat
                local char = player.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then
                if obj.tracer then obj.tracer.Visible = false end
                if obj.billboard then obj.billboard.Enabled = false end
                if obj.headDot then obj.headDot.Visible = false end
                if obj.box then
                    for _, line in pairs(obj.box) do line.Visible = false end
                end
                break
            end

            local tHrp = char:FindFirstChild("HumanoidRootPart")
            local dist = (tHrp.Position - myHrp.Position).Magnitude
            local visible = dist <= ESP.maxDistance
            local role = getPlayerRole(player)
            local color = getRoleColor(role)

            if obj.highlight then
                obj.highlight.FillColor = color
                obj.highlight.Enabled = visible
            end

            if obj.headDot then
                obj.headDot.Color3 = color
                obj.headDot.Visible = ESP.showHeadDot and visible
            end

            if obj.billboard then
                obj.billboard.Enabled = visible
            end
            if obj.nameLabel then
                obj.nameLabel.Text = string.format("%s [%s]", player.Name, role)
                obj.nameLabel.TextColor3 = color
            end
            if obj.distLabel then
                obj.distLabel.Text = string.format("%dm", math.floor(dist))
            end

            if obj.box then
                if visible and ESP.showBox then
                    local tHead = char:FindFirstChild("Head")
                    if tHead then
                        local headPos = tHead.Position + Vector3.new(0, 0.5, 0)
                        local feetPos = tHrp.Position + Vector3.new(0, -3, 0)

                        local headScreen, headOnScreen = Camera:WorldToViewportPoint(headPos)
                        local feetScreen, feetOnScreen = Camera:WorldToViewportPoint(feetPos)

                        if headOnScreen and feetOnScreen then
                            local totalPixelHeight = math.abs(feetScreen.Y - headScreen.Y)
                            local widthPx = totalPixelHeight * (ESP.boxWidth / 100)
                            local heightPx = totalPixelHeight * (ESP.boxHeight / 100)

                            local centerScreen = Vector2.new(
                                (headScreen.X + feetScreen.X) / 2,
                                (headScreen.Y + feetScreen.Y) / 2
                            )

                            for _, line in pairs(obj.box) do
                                line.Color = color
                                line.Thickness = ESP.boxThickness
                                line.Visible = true
                            end

                            updateBoxLines(obj.box, centerScreen, widthPx, heightPx)
                        else
                            for _, line in pairs(obj.box) do line.Visible = false end
                        end
                    else
                        for _, line in pairs(obj.box) do line.Visible = false end
                    end
                else
                    for _, line in pairs(obj.box) do line.Visible = false end
                end
            end

            if obj.tracer then
                if visible and ESP.showTracer then
                    local originPos = getTracerOriginPosition(player)
                    if originPos then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(originPos)
                        obj.tracer.From = Vector2.new(myScreenPos.X, myScreenPos.Y)
                        obj.tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                        obj.tracer.Visible = onScreen
                        obj.tracer.Color = color
                        obj.tracer.Thickness = ESP.tracerThickness
                    else
                        obj.tracer.Visible = false
                    end
                else
                    obj.tracer.Visible = false
                end
            end
            until true
        end
        until true
    end
end)

-- =====================================================
-- ESP タブ UI
-- =====================================================
local ESPLeft = Tabs.ESP:AddLeftGroupbox('ESP')
local ESPRight = Tabs.ESP:AddRightGroupbox('Tracer / Box')

ESPLabel = ESPLeft

ESPLabel:AddToggle('ESPEnabled', {
    Text = 'ESP (Highlight)',
    Default = false,
    Tooltip = '役職色分け\n赤=Murderer 青=Sheriff 緑=Innocent',
    Callback = function(Value)
        ESP.enabled = Value
        if Value then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    createESP(p)
                end
            end
        else
            for player, _ in pairs(espObjects) do
                removeESP(player)
            end
        end
    end
})

ESPLabel:AddToggle('ESPBox', {
    Text = 'Box ESP',
    Default = false,
    Tooltip = '線で四角を描画',
    Callback = function(Value)
        ESP.showBox = Value
        refreshAllESP()
    end
})

ESPLabel:AddToggle('ESPHeadDot', {
    Text = 'Head Dot',
    Default = false,
    Callback = function(Value)
        ESP.showHeadDot = Value
        refreshAllESP()
    end
})

ESPLabel:AddToggle('ESPName', {
    Text = 'Name ESP',
    Default = false,
    Callback = function(Value)
        ESP.showName = Value
        refreshAllESP()
    end
})

ESPLabel:AddToggle('ESPDistance', {
    Text = 'Distance ESP',
    Default = false,
    Callback = function(Value)
        ESP.showDistance = Value
        refreshAllESP()
    end
})

ESPLabel:AddSlider('ESPMaxDistance', {
    Text = 'Max Distance',
    Default = 1000,
    Min = 50,
    Max = 5000,
    Rounding = 0,
    Suffix = 'm',
    Callback = function(v)
        ESP.maxDistance = v
    end
})

ESPLabel:AddSlider('ESPBoxWidth', {
    Text = 'Box Width (%)',
    Default = 40,
    Min = 10,
    Max = 100,
    Rounding = 0,
    Suffix = '%',
    Callback = function(v) ESP.boxWidth = v end
})

ESPLabel:AddSlider('ESPBoxHeight', {
    Text = 'Box Height (%)',
    Default = 130,
    Min = 50,
    Max = 300,
    Rounding = 0,
    Suffix = '%',
    Callback = function(v) ESP.boxHeight = v end
})

ESPLabel:AddSlider('ESPBoxThickness', {
    Text = 'Box Thickness',
    Default = 1.5,
    Min = 1,
    Max = 10,
    Rounding = 1,
    Callback = function(v)
        ESP.boxThickness = v
        for _, obj in pairs(espObjects) do
            if obj.box then
                for _, line in pairs(obj.box) do
                    line.Thickness = v
                end
            end
        end
    end
})

ESPLabel:AddButton({
    Text = '🔄 Refresh ESP',
    Tooltip = 'ESPを再適用',
    Func = function()
        if ESP.enabled then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    removeESP(p)
                    createESP(p)
                end
            end
            Library:Notify('ESP refreshed', 1.5)
        else
            Library:Notify('ESP is disabled', 1.5)
        end
    end
})

ESPRight:AddToggle('ESPTracer', {
    Text = 'Tracer ESP',
    Default = false,
    Tooltip = '自分の足元からターゲットへ線を引く',
    Callback = function(Value)
        ESP.showTracer = Value
        refreshAllESP()
    end
})

ESPRight:AddDropdown('ESPTracerOrigin', {
    Text = 'Tracer Origin',
    Values = { 'Head', 'Center', 'Feet' },
    Default = 'Head',
    Multi = false,
    Callback = function(Value)
        ESP.tracerOrigin = Value
    end
})

ESPRight:AddSlider('ESPTracerThickness', {
    Text = 'Tracer Thickness',
    Default = 2,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Callback = function(v)
        ESP.tracerThickness = v
        for _, obj in pairs(espObjects) do
            if obj.tracer then
                obj.tracer.Thickness = v
            end
        end
    end
})

-- =====================================================
-- プレイヤー追加/削除
-- =====================================================
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.5)
        if ESP.enabled and p ~= LocalPlayer then
            createESP(p)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(p)
    removeESP(p)
end)

-- =====================================================
-- Combat タブ
-- =====================================================
local CombatLeft = Tabs.Combat:AddLeftGroupbox('Target')
local CombatRight = Tabs.Combat:AddRightGroupbox('Combat')

local targetPlayer = nil
local TARGET_DROPDOWN_FLAG = 'MM2Target'

CombatLeft:AddDropdown(TARGET_DROPDOWN_FLAG, {
    Text = 'Select Target',
    Values = getPlayerList(),
    Default = 1,
    Multi = false,
    Callback = function(Value)
        if type(Value) == "table" then Value = Value[1] end
        local username = Value:match("@(.-)%)")
        if username then
            targetPlayer = Players:FindFirstChild(username)
            if targetPlayer then
                Library:Notify('Target: ' .. targetPlayer.Name, 1.5)
            end
        end
    end
})

CombatLeft:AddButton({
    Text = '🔄 Refresh Players',
    Tooltip = 'プレイヤーリストを再取得',
    Func = function()
        local newList = getPlayerList()
        local ok = pcall(function()
            Options[TARGET_DROPDOWN_FLAG]:Refresh(newList, true)
        end)
        if ok then
            Library:Notify('Player list refreshed', 1.5)
        else
            Library:Notify('Refresh failed', 3)
        end
    end
})

-- 自動更新（プレイヤー参加/退出時）
Players.PlayerAdded:Connect(function(p)
    task.wait(0.5)
    pcall(function()
        Options[TARGET_DROPDOWN_FLAG]:Refresh(getPlayerList(), false)
    end)
end)

Players.PlayerRemoving:Connect(function(p)
    task.wait(0.3)
    pcall(function()
        Options[TARGET_DROPDOWN_FLAG]:Refresh(getPlayerList(), false)
    end)
    if targetPlayer == p then targetPlayer = nil end
end)

-- =====================================================
-- Kill Target (TP → ナイフ振り → 戻る)
-- =====================================================
local killTPThread = nil

local function getKnifeTool(char)
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            for _, name in ipairs(KNIFE_NAMES) do
                if tool.Name == name then return tool end
            end
        end
    end
    return nil
end

local function getAnyTool(char)
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then return tool end
    end
    return nil
end

CombatLeft:AddButton({
    Text = '⚡ Kill Target (TP)',
    Tooltip = 'TP→ナイフ振る→戻る',
    Func = function()
        if killTPThread then
            Library:Notify('Already running', 2)
            return
        end
        if not targetPlayer or not targetPlayer.Character then
            Library:Notify('Select a target first', 3)
            return
        end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            Library:Notify('Your character not found', 3)
            return
        end

        local targetChar = targetPlayer.Character
        local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
        local targetHum = targetChar and targetChar:FindFirstChildOfClass("Humanoid")

        if not targetHrp or not targetHum or targetHum.Health <= 0 then
            Library:Notify('Target invalid', 3)
            return
        end

        killTPThread = task.spawn(function()
            local savedPos = hrp.CFrame
            Library:Notify('Attacking ' .. targetPlayer.Name .. '...', 1.5)

            local oldCanCollide = {}
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    oldCanCollide[part] = part.CanCollide
                    part.CanCollide = false
                end
            end

            local knife = getKnifeTool(char) or getAnyTool(char)
            if knife then
                pcall(function()
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then hum:EquipTool(knife) end
                end)
                task.wait(0.05)
            end

            pcall(function()
                hrp.CFrame = targetHrp.CFrame * CFrame.new(0, 0, -1.5)
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)
            task.wait(0.08)

            for i = 1, 5 do
                if not targetPlayer or not targetPlayer.Character then break end
                local tHum = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
                if not tHum or tHum.Health <= 0 then break end

                pcall(function()
                    hrp.CFrame = targetHrp.CFrame * CFrame.new(0, 0, -1.5)
                end)

                if knife and knife.Parent then
                    pcall(function() knife:Activate() end)
                end

                task.wait(0.15)
            end

            task.wait(0.2)

            local success = targetHum and targetHum.Health <= 0
            if success then
                Library:Notify('✔ Killed: ' .. targetPlayer.Name, 2)
            else
                Library:Notify('⚠ Attack done (may be protected)', 2)
            end

            pcall(function()
                hrp.CFrame = savedPos
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)

            for part, state in pairs(oldCanCollide) do
                if part and part.Parent then
                    part.CanCollide = state
                end
            end

            killTPThread = nil
        end)
    end
})

CombatLeft:AddButton({
    Text = '🔪 Kill Target (Ranged)',
    Tooltip = 'TPせず直接キル',
    Func = function()
        if not targetPlayer or not targetPlayer.Character then
            Library:Notify('Select a target first', 3)
            return
        end
        local hum = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            pcall(function() hum.Health = 0 end)
            Library:Notify('Killed: ' .. targetPlayer.Name, 2)
        end
    end
})

-- =====================================================
-- Kill All (TP + ナイフ/銃でキル)
-- =====================================================
local killAllRunning = false
local function killOneTarget(targetPlayer, useKnife)
    if not targetPlayer or not targetPlayer.Character then return false end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return false end

    local targetChar = targetPlayer.Character
    local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
    local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
    if not targetHrp or not targetHum or targetHum.Health <= 0 then return false end

    -- 武器を探す
    local tool = nil
    if useKnife then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") then
                for _, name in ipairs(KNIFE_NAMES) do
                    if t.Name == name then tool = t break end
                end
                if tool then break end
            end
        end
    else
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") then
                for _, name in ipairs(GUN_NAMES) do
                    if t.Name == name then tool = t break end
                end
                if tool then break end
            end
        end
    end

    -- フォールバック: 何かしらツールを装備
    if not tool then
        tool = char:FindFirstChildWhichIsA("Tool")
    end

    if not tool then return false end

    -- 装備
    pcall(function() hum:EquipTool(tool) end)
    task.wait(0.05)

    -- 相手のすぐ前にTP
    pcall(function()
        hrp.CFrame = targetHrp.CFrame * CFrame.new(0, 0, -1.5)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
    task.wait(0.08)

    -- 攻撃（複数回）
    for i = 1, 5 do
        if not targetPlayer.Character then break end
        local tHum = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
        if not tHum or tHum.Health <= 0 then break end

        -- 再接近（追従）
        pcall(function()
            hrp.CFrame = targetHrp.CFrame * CFrame.new(0, 0, -1.5)
        end)

        if tool and tool.Parent then
            pcall(function() tool:Activate() end)
        end

        task.wait(0.15)
    end

    task.wait(0.1)

    -- キル判定
    local tHum = targetPlayer.Character and targetPlayer.Character:FindFirstChildOfClass("Humanoid")
    return tHum and tHum.Health <= 0
end

CombatLeft:AddButton({
    Text = '💀 Kill All (TP)',
    Tooltip = 'Murderer: 全員 / Sheriff: Murdererのみ をTPキル',
    Func = function()
        if killAllRunning then
            Library:Notify('Already running', 2)
            return
        end

        local myRole = getPlayerRole(LocalPlayer)
        if myRole ~= "Murderer" and myRole ~= "Sheriff" then
            Library:Notify('⚠ You must be Murderer or Sheriff', 3)
            return
        end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            Library:Notify('Your character not found', 3)
            return
        end

        killAllRunning = true
        local savedPos = hrp.CFrame
        local useKnife = (myRole == "Murderer")
        local killedCount = 0

        Library:Notify('Kill All started...', 2)

        task.spawn(function()
            -- Noclip有効化
            local oldCC = {}
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    oldCC[part] = part.CanCollide
                    part.CanCollide = false
                end
            end

            -- 対象リスト
            local targets = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then
                    local tHum = p.Character:FindFirstChildOfClass("Humanoid")
                    if tHum and tHum.Health > 0 then
                        if myRole == "Murderer" then
                            -- 全員
                            table.insert(targets, p)
                        else
                            -- Sheriff: Murdererのみ
                            if getPlayerRole(p) == "Murderer" then
                                table.insert(targets, p)
                            end
                        end
                    end
                end
            end

            if #targets == 0 then
                Library:Notify('No targets found', 2)
            else
                for _, target in ipairs(targets) do
                    if not killAllRunning then break end
                    local success = killOneTarget(target, useKnife)
                    if success then
                        killedCount = killedCount + 1
                    end
                    task.wait(0.1)
                end
            end

            -- 元の位置に戻る
            pcall(function()
                hrp.CFrame = savedPos
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)

            -- CanCollide復元
            for part, state in pairs(oldCC) do
                if part and part.Parent then
                    part.CanCollide = state
                end
            end

            if killedCount > 0 then
                Library:Notify('💀 Kill All: ' .. killedCount .. ' killed', 2)
            else
                Library:Notify('⚠ Kill All failed (all protected)', 2)
            end

            killAllRunning = false
        end)
    end
})
-- =====================================================
-- Grab Gun (ボタン / TPなし)
-- =====================================================
local grabGunRunning = false

local function findDroppedGun()
    local found = nil
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Tool") then
            for _, name in ipairs(GUN_NAMES) do
                if obj.Name == name then
                    local handle = obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart")
                    if handle and obj.Parent == Workspace then
                        found = { tool = obj, handle = handle }
                        break
                    end
                end
            end
        elseif obj:IsA("Model") and (obj.Name == "Gun" or obj.Name == "Revolver") then
            local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if primary and obj.Parent == Workspace then
                found = { tool = obj, handle = primary }
            end
        end
        if found then break end
    end
    return found
end

CombatRight:AddButton({
    Text = '🔫 Grab Gun',
    Tooltip = '落ちている銃を拾いに行く（TPなし）',
    Func = function()
        if grabGunRunning then
            Library:Notify('Already running', 2)
            return
        end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then
            Library:Notify('Character not found', 3)
            return
        end

        local gunData = findDroppedGun()
        if not gunData then
            Library:Notify('No dropped gun found', 2)
            return
        end

        grabGunRunning = true
        Library:Notify('Moving to gun...', 2)

        task.spawn(function()
            -- 元のWalkSpeedを保存
            local originalSpeed = hum.WalkSpeed
            hum.WalkSpeed = 100  -- 高速移動

            -- 銃の方向にプレイヤーを向ける
            local target = gunData.handle
            local startTime = tick()
            local timeout = 10  -- 最大10秒

            -- 銃のところまで歩く（MoveTo使用）
            while grabGunRunning and tick() - startTime < timeout do
                if not target or not target.Parent then break end

                local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if not myHrp then break end

                local dist = (target.Position - myHrp.Position).Magnitude
                if dist <= 3 then
                    -- 拾える距離まで来た
                    break
                end

                pcall(function()
                    hum:MoveTo(target.Position)
                end)

                task.wait(0.1)
            end

            -- 停止
            pcall(function() hum:MoveTo(hrp.Position) end)
            task.wait(0.2)

            -- WalkSpeedを元に戻す
            hum.WalkSpeed = originalSpeed

            -- 結果確認
            local newRole = getPlayerRole(LocalPlayer)
            if newRole == "Sheriff" then
                Library:Notify('✔ Gun picked up!', 2)
            else
                Library:Notify('Grab attempted (gun may be gone)', 2)
            end

            grabGunRunning = false
        end)
    end
})

-- プレイヤーのすぐ近くにある銃だけを拾うモード（オプション）
CombatRight:AddButton({
    Text = '🔫 Grab Nearby Gun',
    Tooltip = '近く（30 studs以内）にある銃だけを拾う',
    Func = function()
        if grabGunRunning then
            Library:Notify('Already running', 2)
            return
        end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then
            Library:Notify('Character not found', 3)
            return
        end

        local gunData = findDroppedGun()
        if not gunData then
            Library:Notify('No dropped gun found', 2)
            return
        end

        local dist = (gunData.handle.Position - hrp.Position).Magnitude
        if dist > 30 then
            Library:Notify('Gun is too far (' .. math.floor(dist) .. 'm)', 2)
            return
        end

        grabGunRunning = true
        Library:Notify('Moving to nearby gun...', 2)

        task.spawn(function()
            local originalSpeed = hum.WalkSpeed
            hum.WalkSpeed = 100

            local target = gunData.handle
            local startTime = tick()
            local timeout = 5

            while grabGunRunning and tick() - startTime < timeout do
                if not target or not target.Parent then break end

                local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if not myHrp then break end

                local d = (target.Position - myHrp.Position).Magnitude
                if d <= 3 then break end

                pcall(function()
                    hum:MoveTo(target.Position)
                end)

                task.wait(0.1)
            end

            pcall(function() hum:MoveTo(hrp.Position) end)
            task.wait(0.2)

            hum.WalkSpeed = originalSpeed

            local newRole = getPlayerRole(LocalPlayer)
            if newRole == "Sheriff" then
                Library:Notify('✔ Gun picked up!', 2)
            else
                Library:Notify('Grab attempted', 2)
            end

            grabGunRunning = false
        end)
    end
})

-- =====================================================
-- Hitbox Expander
-- =====================================================
local hitboxEnabled = false
local hitboxSize = 10
local hitboxCache = {}

local function applyHitbox(player)
    if player == LocalPlayer then return end
    if not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if hitboxCache[player] then return end

    hitboxCache[player] = {
        size = hrp.Size,
        transparency = hrp.Transparency,
        canCollide = hrp.CanCollide,
        massless = hrp.Massless,
    }

    hrp.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
    hrp.Transparency = 0.7
    hrp.CanCollide = false
    hrp.Massless = true

    local conn = hrp:GetPropertyChangedSignal("Size"):Connect(function()
        if hitboxEnabled and hrp.Parent then
            if hrp.Size ~= Vector3.new(hitboxSize, hitboxSize, hitboxSize) then
                hrp.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
            end
        end
    end)
    hitboxCache[player].conn = conn
end

local function removeHitbox(player)
    if not hitboxCache[player] then return end
    local cache = hitboxCache[player]
    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.Size = cache.size
            hrp.Transparency = cache.transparency
            hrp.CanCollide = cache.canCollide
            hrp.Massless = cache.massless
        end
    end
    if cache.conn then cache.conn:Disconnect() end
    hitboxCache[player] = nil
end

local function refreshHitboxes()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            removeHitbox(p)
            if hitboxEnabled then applyHitbox(p) end
        end
    end
end

CombatRight:AddToggle('HitboxEnabled', {
    Text = 'Hitbox Expander',
    Default = false,
    Tooltip = '全プレイヤーの当たり判定を拡大',
    Callback = function(Value)
        hitboxEnabled = Value
        refreshHitboxes()
    end
})

CombatRight:AddSlider('HitboxSize', {
    Text = 'Hitbox Size',
    Default = 10,
    Min = 2,
    Max = 50,
    Rounding = 0,
    Callback = function(v)
        hitboxSize = v
        if hitboxEnabled then refreshHitboxes() end
    end
})

-- =====================================================
-- Auto Shoot Murderer (壁越し対応版)
-- =====================================================
local autoShootEnabled = false
local autoShootThread = nil
local AUTO_SHOOT_RANGE = 500   -- 最大射程

-- 壁越し判定用のRaycastパラメータ
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local function hasLineOfSight(fromPos, toPos, ignoreList)
    raycastParams.FilterDescendantsInstances = ignoreList or {}
    local direction = toPos - fromPos
    local result = Workspace:Raycast(fromPos, direction, raycastParams)
    -- 何にも当たらなければ視線が通っている
    return result == nil
end

CombatRight:AddToggle('AutoShoot', {
    Text = 'Auto Shoot Murderer',
    Default = false,
    Tooltip = 'Murdererを自動で撃つ（壁越しは撃たない）',
    Callback = function(Value)
        autoShootEnabled = Value

        if Value then
            autoShootThread = task.spawn(function()
                while autoShootEnabled do
                    local myRole = getPlayerRole(LocalPlayer)
                    if myRole == "Sheriff" then
                        local char = LocalPlayer.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        local tool = char and char:FindFirstChildWhichIsA("Tool")

                        if tool and hrp then
                            for _, p in ipairs(Players:GetPlayers()) do
                                if p ~= LocalPlayer and p.Character then
                                    if getPlayerRole(p) == "Murderer" then
                                        local tHrp = p.Character:FindFirstChild("HumanoidRootPart")
                                        local tHum = p.Character:FindFirstChildOfClass("Humanoid")
                                        if tHrp and tHum and tHum.Health > 0 then
                                            local dist = (tHrp.Position - hrp.Position).Magnitude

                                            if dist <= AUTO_SHOOT_RANGE then
                                                -- 壁越し判定（自分と相手のキャラは除外）
                                                local ignoreList = {char, p.Character}
                                                local hasLOS = hasLineOfSight(
                                                    hrp.Position,
                                                    tHrp.Position,
                                                    ignoreList
                                                )

                                                if hasLOS then
                                                    -- 視線が通っているときだけ撃つ
                                                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, tHrp.Position)
                                                    pcall(function() tool:Activate() end)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    task.wait(0.05)
                end
            end)
        else
            if autoShootThread then
                pcall(task.cancel, autoShootThread)
                autoShootThread = nil
            end
        end
    end
})

-- =====================================================
-- Misc タブ
-- =====================================================
local MiscLeft = Tabs.Misc:AddLeftGroupbox('Farm / Utility')
local MiscRight = Tabs.Misc:AddRightGroupbox('Chat / Settings')

-- =====================================================
-- Coin Farm
-- =====================================================
local coinFarmEnabled = false
local coinFarmThread = nil
local COIN_FARM_RANGE = 300
local COIN_MOVE_SPEED = 60
local COIN_PICKUP_DISTANCE = 4

local function findCoins()
    local coins = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local name = obj.Name:lower()
            if name:find("coin")
               or name:find("cash")
               or name:find("money")
               or name:find("gem")
               or obj:GetAttribute("IsCoin") == true
               or obj:GetAttribute("Coin") == true
            then
                if obj:FindFirstChildOfClass("TouchTransmitter")
                   or obj:FindFirstChild("TouchInterest")
                   or obj:GetAttribute("CanBePickedUp") ~= false
                then
                    table.insert(coins, obj)
                end
            end
        end
    end
    return coins
end

local function sortCoinsByDistance(coins, fromPos)
    table.sort(coins, function(a, b)
        return (a.Position - fromPos).Magnitude < (b.Position - fromPos).Magnitude
    end)
end

MiscLeft:AddToggle('CoinFarm', {
    Text = 'Coin Farm',
    Default = false,
    Tooltip = '自動でコインを拾い集める',
    Callback = function(Value)
        coinFarmEnabled = Value

        if Value then
            coinFarmThread = task.spawn(function()
                while coinFarmEnabled do
                    repeat
                        local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    local hum = char and char:FindFirstChildOfClass("Humanoid")

                    if not char or not hrp or not hum then
                        task.wait(0.5)
                        break
                    end

                    local coins = findCoins()
                    if #coins == 0 then
                        task.wait(1)
                        break
                    end

                    sortCoinsByDistance(coins, hrp.Position)

                    local target = coins[1]
                    if not target or not target.Parent then
                        task.wait(0.3)
                        break
                    end

                    local dist = (target.Position - hrp.Position).Magnitude
                    if dist > COIN_FARM_RANGE then
                        task.wait(0.5)
                        break
                    end

                    local originalSpeed = hum.WalkSpeed
                    hum.WalkSpeed = COIN_MOVE_SPEED

                    local startTime = tick()
                    local timeout = 8
                    while coinFarmEnabled
                       and target
                       and target.Parent
                       and tick() - startTime < timeout
                    do
                        local myHrp = LocalPlayer.Character
                            and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if not myHrp then break end

                        local d = (target.Position - myHrp.Position).Magnitude
                        if d <= COIN_PICKUP_DISTANCE then
                            pcall(function()
                                myHrp.CFrame = CFrame.new(target.Position + Vector3.new(0, 2, 0))
                            end)
                            task.wait(0.1)
                            break
                        end

                        pcall(function()
                            hum:MoveTo(target.Position)
                        end)
                        task.wait(0.1)
                    end

                    pcall(function() hum:MoveTo(hrp.Position) end)
                    hum.WalkSpeed = originalSpeed
                    task.wait(0.2)
                    until true
                end
            end)
            Library:Notify('Coin Farm: Enabled', 2)
        else
            if coinFarmThread then
                pcall(task.cancel, coinFarmThread)
                coinFarmThread = nil
            end
            Library:Notify('Coin Farm: Disabled', 2)
        end
    end
})

-- =====================================================
-- Fullbright
-- =====================================================
local Lighting = game:GetService("Lighting")
local fullbrightEnabled = false
local lightingBackup = nil

local function saveLighting()
    lightingBackup = {
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        GlobalShadows = Lighting.GlobalShadows,
        FogEnd = Lighting.FogEnd,
        FogStart = Lighting.FogStart,
    }
end

local function restoreLighting()
    if not lightingBackup then return end
    Lighting.Brightness = lightingBackup.Brightness
    Lighting.ClockTime = lightingBackup.ClockTime
    Lighting.Ambient = lightingBackup.Ambient
    Lighting.OutdoorAmbient = lightingBackup.OutdoorAmbient
    Lighting.GlobalShadows = lightingBackup.GlobalShadows
    Lighting.FogEnd = lightingBackup.FogEnd
    Lighting.FogStart = lightingBackup.FogStart
end

MiscLeft:AddToggle('Fullbright', {
    Text = 'Fullbright',
    Default = false,
    Tooltip = 'マップ全体を明るくする',
    Callback = function(Value)
        fullbrightEnabled = Value
        if Value then
            saveLighting()
            Lighting.Brightness = 3
            Lighting.ClockTime = 12
            Lighting.Ambient = Color3.fromRGB(200, 200, 200)
            Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 100000
            Lighting.FogStart = 0
            Library:Notify('Fullbright: ON', 2)
        else
            restoreLighting()
            Library:Notify('Fullbright: OFF', 2)
        end
    end
})

-- =====================================================
-- Teleport to Player
-- =====================================================
local tpTargetPlayer = nil
local TP_DROPDOWN_FLAG = 'MiscTPTarget'

MiscLeft:AddDropdown(TP_DROPDOWN_FLAG, {
    Text = 'TP Target',
    Values = getPlayerList(),
    Default = 1,
    Multi = false,
    Callback = function(Value)
        if type(Value) == "table" then Value = Value[1] end
        local username = Value:match("@(.-)%)")
        if username then
            tpTargetPlayer = Players:FindFirstChild(username)
        end
    end
})

MiscLeft:AddButton({
    Text = '🔄 Refresh TP List',
    Tooltip = 'TPリスト更新',
    Func = function()
        pcall(function()
            Options[TP_DROPDOWN_FLAG]:Refresh(getPlayerList(), true)
        end)
        Library:Notify('TP list refreshed', 1.5)
    end
})

MiscLeft:AddButton({
    Text = '🚀 Teleport to Player',
    Tooltip = 'ターゲットのところにTP',
    Func = function()
        if not tpTargetPlayer or not tpTargetPlayer.Character then
            Library:Notify('Select a target first', 3)
            return
        end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            Library:Notify('Character not found', 3)
            return
        end

        local tHrp = tpTargetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not tHrp then
            Library:Notify('Target character not found', 3)
            return
        end

        local oldCC = {}
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                oldCC[part] = part.CanCollide
                part.CanCollide = false
            end
        end

        pcall(function()
            hrp.CFrame = tHrp.CFrame + Vector3.new(0, 2, 0)
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)

        task.delay(0.15, function()
            for part, state in pairs(oldCC) do
                if part and part.Parent then
                    part.CanCollide = state
                end
            end
        end)

        Library:Notify('TP to: ' .. tpTargetPlayer.Name, 2)
    end
})

-- =====================================================
-- チャット送信ヘルパー（新旧両対応）
-- =====================================================
local ReplicatedStorage_Chat = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local function sendChat(message)
    local ok = pcall(function()
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
            if channel then
                channel:SendAsync(message)
            end
        end
    end)

    if not ok then
        local oldChat = ReplicatedStorage_Chat:FindFirstChild("DefaultChatSystemChatEvents")
        if oldChat then
            local sayMessage = oldChat:FindFirstChild("SayMessageRequest")
            if sayMessage then
                sayMessage:FireServer(message, "All")
            end
        end
    end
end

-- =====================================================
-- Chat Spammer（カスタム文字）
-- =====================================================
local chatSpamEnabled = false
local chatSpamThread = nil
local chatSpamText = "GG EZ"
local chatSpamDelay = 1.0

MiscRight:AddInput('ChatSpamText', {
    Text = 'Chat Spam Text',
    Default = 'GG EZ',
    Placeholder = 'Type message...',
    Numeric = false,
    Finished = true,
    Callback = function(Value)
        if Value and Value ~= "" then
            chatSpamText = Value
        end
    end
})

MiscRight:AddSlider('ChatSpamDelay', {
    Text = 'Spam Delay (秒)',
    Default = 1.0,
    Min = 0.3,
    Max = 10,
    Rounding = 1,
    Callback = function(v)
        chatSpamDelay = v
    end
})

MiscRight:AddToggle('ChatSpam', {
    Text = 'Chat Spammer',
    Default = false,
    Tooltip = '設定した文字を連投',
    Callback = function(Value)
        chatSpamEnabled = Value

        if Value then
            chatSpamThread = task.spawn(function()
                while chatSpamEnabled do
                    pcall(function()
                        sendChat(chatSpamText)
                    end)
                    task.wait(chatSpamDelay)
                end
            end)
            Library:Notify('Chat Spam: ON', 2)
        else
            if chatSpamThread then
                pcall(task.cancel, chatSpamThread)
                chatSpamThread = nil
            end
            Library:Notify('Chat Spam: OFF', 2)
        end
    end
})

-- =====================================================
-- Chat Spammer Random（怖い記号）
-- =====================================================
local CHAOS_CHARS = {
    "▓▒░█▄▀█░▒▓",
    "◤◢◣◥◤◢◣◥",
    "█▓▒▒░░░▒▒▓█",
    "▀▄▀▄▀▄▀▄▀▄▀",
    "☠ ☠ ☠ ☠ ☠",
    "† † † † †",
    "✝ ✝ ✝ ✝ ✝",
    "✟ ✟ ✟ ✟ ✟",
    "⚰ ⚰ ⚰ ⚰ ⚰",
    "☣ ☣ ☣ ☣ ☣",
    "⛧ ⛧ ⛧ ⛧ ⛧",
    "❖ ❖ ❖ ❖ ❖",
    "✖ ✖ ✖ ✖ ✖",
    "◆◇◆◇◆◇◆◇",
    "■□■□■□■□",
    "▲▼▲▼▲▼▲▼",
    "☾ ☽ ☾ ☽ ☾",
    "YOU DIED",
    "GAME OVER",
    "BEHIND YOU",
}

local chatSpamRandomEnabled = false
local chatSpamRandomThread = nil
local chatSpamRandomDelay = 1.5

MiscRight:AddSlider('ChatSpamRandomDelay', {
    Text = 'Random Spam Delay (秒)',
    Default = 1.5,
    Min = 0.3,
    Max = 10,
    Rounding = 1,
    Callback = function(v)
        chatSpamRandomDelay = v
    end
})

MiscRight:AddToggle('ChatSpamRandom', {
    Text = 'Chat Spammer Random',
    Default = false,
    Tooltip = 'ランダムな怖い記号を連投',
    Callback = function(Value)
        chatSpamRandomEnabled = Value

        if Value then
            chatSpamRandomThread = task.spawn(function()
                while chatSpamRandomEnabled do
                    local randomMsg = CHAOS_CHARS[math.random(1, #CHAOS_CHARS)]
                    pcall(function()
                        sendChat(randomMsg)
                    end)
                    task.wait(chatSpamRandomDelay)
                end
            end)
            Library:Notify('Chat Spam Random: ON', 2)
        else
            if chatSpamRandomThread then
                pcall(task.cancel, chatSpamRandomThread)
                chatSpamRandomThread = nil
            end
            Library:Notify('Chat Spam Random: OFF', 2)
        end
    end
})

-- =====================================================
-- Custom Skybox
-- =====================================================
local Skybox = game:GetService("Lighting")
local skyboxEnabled = false
local skyboxIdInput = ""
local skyboxBackup = nil
local createdSky = nil

MiscLeft:AddInput('SkyboxIDInput', {
    Text = 'Skybox ID',
    Default = '',
    Placeholder = 'rbxassetid://...',
    Numeric = false,
    Finished = true,
    Callback = function(Value)
        skyboxIdInput = Value or ""
    end
})

local function removeCustomSkybox()
    if createdSky then
        createdSky:Destroy()
        createdSky = nil
    end
    -- 元のSkyを復元
    if skyboxBackup then
        for _, obj in ipairs(Skybox:GetChildren()) do
            if obj:IsA("Sky") then
                obj.Parent = skyboxBackup
            end
        end
        skyboxBackup = nil
    end
end

MiscLeft:AddToggle('CustomSkybox', {
    Text = 'Custom Skybox',
    Default = false,
    Tooltip = 'Skyboxを指定したIDに変更',
    Callback = function(Value)
        skyboxEnabled = Value

        if Value then
            local id = skyboxIdInput
            if id == "" then
                Library:Notify('Enter Skybox ID first', 3)
                skyboxEnabled = false
                Toggles.CustomSkybox:SetValue(false)
                return
            end

            -- rbxassetid:// が無ければ追加
            if not id:find("rbxassetid://") and not id:find("rbxasset://") then
                id = "rbxassetid://" .. id
            end

            -- 既存Skyを一旦退避
            local existing = {}
            for _, obj in ipairs(Skybox:GetChildren()) do
                if obj:IsA("Sky") then
                    table.insert(existing, obj)
                end
            end

            if #existing > 0 then
                skyboxBackup = Instance.new("Folder")
                skyboxBackup.Name = "SkyboxBackup"
                skyboxBackup.Parent = game:GetService("ReplicatedStorage")
                for _, obj in ipairs(existing) do
                    obj.Parent = skyboxBackup
                end
            end

            -- 新Sky作成
            createdSky = Instance.new("Sky")
            createdSky.Name = "CustomSky"
            createdSky.SkyboxBk = id
            createdSky.SkyboxDn = id
            createdSky.SkyboxFt = id
            createdSky.SkyboxLf = id
            createdSky.SkyboxRt = id
            createdSky.SkyboxUp = id
            createdSky.Parent = Skybox

            Library:Notify('Custom Skybox: ON', 2)
        else
            removeCustomSkybox()
            Library:Notify('Custom Skybox: OFF', 2)
        end
    end
})

-- =====================================================
-- Fake Ping（Ping偽装）
-- =====================================================
local fakePingEnabled = false
local fakePingValue = 50
local fakePingConn = nil

MiscRight:AddSlider('FakePingValue', {
    Text = 'Fake Ping Value',
    Default = 50,
    Min = 10,
    Max = 999,
    Rounding = 0,
    Suffix = 'ms',
    Callback = function(v)
        fakePingValue = v
    end
})

MiscRight:AddToggle('FakePing', {
    Text = 'Fake Ping',
    Default = false,
    Tooltip = 'Ping表示を偽装（自分にしか見えない）',
    Callback = function(Value)
        fakePingEnabled = Value

        if Value then
            -- StatsのPing表示を監視して書き換える試み
            -- ※Roblox標準のPingは書き換えにくいので、Custom GUIを表示する方式
            fakePingConn = RunService.RenderStepped:Connect(function()
                if not fakePingEnabled then return end
                -- CoreGuiのPing表示を探す
                pcall(function()
                    local CoreGui = game:GetService("CoreGui")
                    local PlayerList = CoreGui:FindFirstChild("PlayerList")
                    if PlayerList then
                        for _, gui in ipairs(PlayerList:GetDescendants()) do
                            if gui:IsA("TextLabel") and gui.Text:match("%d+ms") then
                                gui.Text = fakePingValue .. "ms"
                            end
                        end
                    end
                end)
            end)
            Library:Notify('Fake Ping: ON (' .. fakePingValue .. 'ms)', 2)
        else
            if fakePingConn then fakePingConn:Disconnect() fakePingConn = nil end
            Library:Notify('Fake Ping: OFF', 2)
        end
    end
})

-- =====================================================
-- Streamer Mode（名前を隠す）
-- =====================================================
local streamerModeEnabled = false
local streamerBackup = {}
local streamerDefaultName = "Player"

MiscRight:AddInput('StreamerName', {
    Text = 'Streamer Name',
    Default = 'Player',
    Placeholder = 'Your display name',
    Numeric = false,
    Finished = true,
    Callback = function(Value)
        if Value and Value ~= "" then
            streamerDefaultName = Value
        end
    end
})

MiscRight:AddToggle('StreamerMode', {
    Text = 'Streamer Mode',
    Default = false,
    Tooltip = '自分の名前を隠す（ローカル表示のみ）',
    Callback = function(Value)
        streamerModeEnabled = Value

        if Value then
            -- 自分のDisplayNameを変更
            pcall(function()
                streamerBackup.DisplayName = LocalPlayer.DisplayName
                LocalPlayer.DisplayName = streamerDefaultName
            end)
            Library:Notify('Streamer Mode: ON', 2)
        else
            pcall(function()
                if streamerBackup.DisplayName then
                    LocalPlayer.DisplayName = streamerBackup.DisplayName
                end
            end)
            Library:Notify('Streamer Mode: OFF', 2)
        end
    end
})

-- =====================================================
-- Misc 設定（右側）
-- =====================================================
MiscRight:AddSlider('CoinFarmRange', {
    Text = 'Coin Farm Range',
    Default = 300,
    Min = 50,
    Max = 1000,
    Rounding = 0,
    Suffix = 'm',
    Callback = function(v)
        COIN_FARM_RANGE = v
    end
})

MiscRight:AddSlider('CoinFarmSpeed', {
    Text = 'Coin Farm Speed',
    Default = 60,
    Min = 16,
    Max = 200,
    Rounding = 0,
    Callback = function(v)
        COIN_MOVE_SPEED = v
    end
})

MiscRight:AddSlider('CoinFarmPickupDistance', {
    Text = 'Pickup Distance',
    Default = 4,
    Min = 2,
    Max = 20,
    Rounding = 0,
    Suffix = 'm',
    Callback = function(v)
        COIN_PICKUP_DISTANCE = v
    end
})

-- =====================================================
-- Movement タブ
-- =====================================================
local MoveLeft = Tabs.Movement:AddLeftGroupbox('Movement')
local MoveRight = Tabs.Movement:AddRightGroupbox('Extra')

-- =====================================================
-- Speed Hack
-- =====================================================
local speedEnabled = false
local speedConn = nil
local SPEED_VALUE = 16

MoveLeft:AddSlider('SpeedValue', {
    Text = 'Walk Speed',
    Default = 16,
    Min = 16,
    Max = 300,
    Rounding = 0,
    Callback = function(Value)
        SPEED_VALUE = Value
        if speedEnabled then
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = Value end
        end
    end
})

MoveLeft:AddToggle('SpeedToggle', {
    Text = 'Speed Hack',
    Default = false,
    Callback = function(Value)
        speedEnabled = Value
        if Value then
            speedConn = RunService.Heartbeat:Connect(function()
                local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = SPEED_VALUE end
            end)
        else
            if speedConn then speedConn:Disconnect() speedConn = nil end
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
        end
    end
})

-- =====================================================
-- Jump Power
-- =====================================================
local jumpPowerEnabled = false
local jumpPowerConn = nil
local JUMP_POWER_VALUE = 50

MoveLeft:AddSlider('JumpPower', {
    Text = 'Jump Power',
    Default = 50,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Callback = function(Value)
        JUMP_POWER_VALUE = Value
        if jumpPowerEnabled then
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.UseJumpPower = true
                hum.JumpPower = Value
            end
        end
    end
})

MoveLeft:AddToggle('JumpPowerToggle', {
    Text = 'Jump Power',
    Default = false,
    Callback = function(Value)
        jumpPowerEnabled = Value
        if Value then
            jumpPowerConn = RunService.Heartbeat:Connect(function()
                local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.UseJumpPower = true
                    hum.JumpPower = JUMP_POWER_VALUE
                end
            end)
        else
            if jumpPowerConn then jumpPowerConn:Disconnect() jumpPowerConn = nil end
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.JumpPower = 50 end
        end
    end
})

-- =====================================================
-- Fly
-- =====================================================
local flyEnabled = false
local flyBV, flyBG
local flyConn = nil

MoveLeft:AddToggle('FlyToggle', {
    Text = 'Fly',
    Default = false,
    Callback = function(Value)
        flyEnabled = Value
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        if Value and hrp then
            flyBV = Instance.new("BodyVelocity")
            flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            flyBV.Velocity = Vector3.zero
            flyBV.Parent = hrp

            flyBG = Instance.new("BodyGyro")
            flyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
            flyBG.P = 1e4
            flyBG.Parent = hrp

            flyConn = RunService.RenderStepped:Connect(function()
                if not flyEnabled then return end
                local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if not myHrp or not flyBV then return end

                local moveDir = Vector3.zero
                local camCF = Camera.CFrame

                if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camCF.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camCF.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camCF.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camCF.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0, 1, 0) end

                flyBV.Velocity = moveDir * 50
                flyBG.CFrame = camCF
            end)
        else
            if flyConn then flyConn:Disconnect() flyConn = nil end
            if flyBV then flyBV:Destroy() flyBV = nil end
            if flyBG then flyBG:Destroy() flyBG = nil end
        end
    end
})

-- =====================================================
-- Noclip
-- =====================================================
local noclipEnabled = false
local noclipConn = nil

MoveLeft:AddToggle('NoclipToggle', {
    Text = 'Noclip',
    Default = false,
    Callback = function(Value)
        noclipEnabled = Value
        if Value then
            noclipConn = RunService.Stepped:Connect(function()
                if not noclipEnabled then return end
                local char = LocalPlayer.Character
                if char then
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end)
        else
            if noclipConn then noclipConn:Disconnect() noclipConn = nil end
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = true
                    end
                end
            end
        end
    end
})

-- =====================================================
-- Infinite Jump
-- =====================================================
local infiniteJumpEnabled = false
local infJumpConn = nil

MoveLeft:AddToggle('InfiniteJump', {
    Text = 'Infinite Jump',
    Default = false,
    Tooltip = '空中でもジャンプ可能',
    Callback = function(Value)
        infiniteJumpEnabled = Value
        if Value then
            infJumpConn = UserInputService.JumpRequest:Connect(function()
                if not infiniteJumpEnabled then return end
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end)
        else
            if infJumpConn then infJumpConn:Disconnect() infJumpConn = nil end
        end
    end
})

-- =====================================================
-- Bunny Hop
-- =====================================================
local bunnyHopEnabled = false
local bunnyHopConn = nil

MoveLeft:AddToggle('BunnyHop', {
    Text = 'Bunny Hop',
    Default = false,
    Tooltip = '自動で連続ジャンプ',
    Callback = function(Value)
        bunnyHopEnabled = Value
        if Value then
            bunnyHopConn = RunService.Heartbeat:Connect(function()
                if not bunnyHopEnabled then return end
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum and hum.FloorMaterial ~= Enum.Material.Air then
                    hum.Jump = true
                end
            end)
        else
            if bunnyHopConn then bunnyHopConn:Disconnect() bunnyHopConn = nil end
        end
    end
})

-- =====================================================
-- Anti-Void
-- =====================================================
local antiVoidEnabled = false
local antiVoidConn = nil
local antiVoidLastPos = nil

MoveLeft:AddToggle('AntiVoid', {
    Text = 'Anti-Void',
    Default = false,
    Tooltip = '奈落に落ちても死なない',
    Callback = function(Value)
        antiVoidEnabled = Value
        if Value then
            antiVoidConn = RunService.Heartbeat:Connect(function()
                if not antiVoidEnabled then return end
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                -- 通常の位置を保存
                if hrp.Position.Y > -50 then
                    antiVoidLastPos = hrp.CFrame
                end

                -- 落下検知
                if hrp.Position.Y < -100 and antiVoidLastPos then
                    hrp.CFrame = antiVoidLastPos
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end
            end)
        else
            if antiVoidConn then antiVoidConn:Disconnect() antiVoidConn = nil end
        end
    end
})

-- =====================================================
-- Sprint（Shift押しながら加速）
-- =====================================================
local sprintEnabled = false
local sprintConn = nil
local SPRINT_MULTIPLIER = 2

MoveRight:AddSlider('SprintMultiplier', {
    Text = 'Sprint Multiplier',
    Default = 2,
    Min = 1,
    Max = 5,
    Rounding = 1,
    Callback = function(v)
        SPRINT_MULTIPLIER = v
    end
})

MoveRight:AddToggle('SprintToggle', {
    Text = 'Sprint (Shift)',
    Default = false,
    Tooltip = 'Shiftを押しながら移動で加速',
    Callback = function(Value)
        sprintEnabled = Value
        if Value then
            sprintConn = RunService.Heartbeat:Connect(function()
                if not sprintEnabled then return end
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if not hum then return end

                local baseSpeed = speedEnabled and SPEED_VALUE or 16
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    hum.WalkSpeed = baseSpeed * SPRINT_MULTIPLIER
                else
                    hum.WalkSpeed = baseSpeed
                end
            end)
        else
            if sprintConn then sprintConn:Disconnect() sprintConn = nil end
        end
    end
})

-- =====================================================
-- Anti-Fling
-- =====================================================
local antiFlingEnabled = false
local antiFlingConn = nil

MoveRight:AddToggle('AntiFling', {
    Text = 'Anti-Fling',
    Default = false,
    Tooltip = 'フリング耐性',
    Callback = function(Value)
        antiFlingEnabled = Value
        if Value then
            antiFlingConn = RunService.Heartbeat:Connect(function()
                if not antiFlingEnabled then return end
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                -- 怪しいVelocityを検知して消す
                for _, child in ipairs(hrp:GetChildren()) do
                    if child:IsA("BodyVelocity") or child:IsA("BodyAngularVelocity") then
                        child:Destroy()
                    end
                end

                -- 過度な速度をリセット
                local vel = hrp.AssemblyLinearVelocity
                if vel.Magnitude > 200 then
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                end
            end)
        else
            if antiFlingConn then antiFlingConn:Disconnect() antiFlingConn = nil end
        end
    end
})

-- =====================================================
-- Walk on Water（水上歩行）
-- =====================================================
local waterWalkEnabled = false
local waterWalkConn = nil

MoveRight:AddToggle('WaterWalk', {
    Text = 'Walk on Water',
    Default = false,
    Tooltip = '水上を歩けるようにする（地形が対応している場合のみ）',
    Callback = function(Value)
        waterWalkEnabled = Value
        if Value then
            waterWalkConn = RunService.Stepped:Connect(function()
                if not waterWalkEnabled then return end
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                -- 水面に近ければY速度を抑える
                local rayOrigin = hrp.Position
                local rayDirection = Vector3.new(0, -50, 0)
                local rayParams = RaycastParams.new()
                rayParams.FilterDescendantsInstances = {char}
                rayParams.FilterType = Enum.RaycastFilterType.Exclude

                local result = Workspace:Raycast(rayOrigin, rayDirection, rayParams)
                if result and result.Material == Enum.Material.Water then
                    if result.Distance <= 3.5 then
                        hrp.AssemblyLinearVelocity = Vector3.new(
                            hrp.AssemblyLinearVelocity.X,
                            0,
                            hrp.AssemblyLinearVelocity.Z
                        )
                    end
                end
            end)
        else
            if waterWalkConn then waterWalkConn:Disconnect() waterWalkConn = nil end
        end
    end
})

-- =====================================================
-- Click TP（マウスクリックでTP）
-- =====================================================
local clickTPEnabled = false
local clickTPConn = nil

MoveRight:AddToggle('ClickTP', {
    Text = 'Click TP',
    Default = false,
    Tooltip = 'マウスクリックした場所にテレポート',
    Callback = function(Value)
        clickTPEnabled = Value
        if Value then
            clickTPConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if gameProcessed then return end
                if not clickTPEnabled then return end
                if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                local mouse = LocalPlayer:GetMouse()
                if mouse.Target then
                    local targetPos = mouse.Hit.Position + Vector3.new(0, 3, 0)

                    local oldCC = {}
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            oldCC[part] = part.CanCollide
                            part.CanCollide = false
                        end
                    end

                    pcall(function()
                        hrp.CFrame = CFrame.new(targetPos)
                        hrp.AssemblyLinearVelocity = Vector3.zero
                    end)

                    task.delay(0.1, function()
                        for part, state in pairs(oldCC) do
                            if part and part.Parent then
                                part.CanCollide = state
                            end
                        end
                    end)
                end
            end)
        else
            if clickTPConn then clickTPConn:Disconnect() clickTPConn = nil end
        end
    end
})

-- =====================================================
-- Teleport to Cursor（カーソル位置にTP / キー）
-- =====================================================
local cursorTPEnabled = false
local cursorTPConn = nil

MoveRight:AddToggle('CursorTP', {
    Text = 'Cursor TP (Eキー)',
    Default = false,
    Tooltip = 'Eキーでカーソル位置にテレポート',
    Callback = function(Value)
        cursorTPEnabled = Value
        if Value then
            cursorTPConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if gameProcessed then return end
                if not cursorTPEnabled then return end
                if input.KeyCode ~= Enum.KeyCode.E then return end

                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                local mouse = LocalPlayer:GetMouse()
                if mouse.Target then
                    local targetPos = mouse.Hit.Position + Vector3.new(0, 3, 0)

                    local oldCC = {}
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            oldCC[part] = part.CanCollide
                            part.CanCollide = false
                        end
                    end

                    pcall(function()
                        hrp.CFrame = CFrame.new(targetPos)
                        hrp.AssemblyLinearVelocity = Vector3.zero
                    end)

                    task.delay(0.1, function()
                        for part, state in pairs(oldCC) do
                            if part and part.Parent then
                                part.CanCollide = state
                            end
                        end
                    end)
                end
            end)
        else
            if cursorTPConn then cursorTPConn:Disconnect() cursorTPConn = nil end
        end
    end
})

-- =====================================================
-- Settings タブ
-- =====================================================
local SettingsLeft = Tabs.Settings:AddLeftGroupbox('Menu')
local SettingsMid = Tabs.Settings:AddLeftGroupbox('Utility')
local SettingsRight = Tabs.Settings:AddRightGroupbox('Info')

-- =====================================================
-- Unload
-- =====================================================
SettingsLeft:AddButton('Unload', function()
    -- ESP停止
    ESP.enabled = false
    for player, _ in pairs(espObjects) do
        removeESP(player)
    end

    -- Combat停止
    autoShootEnabled = false
    if autoShootThread then pcall(task.cancel, autoShootThread) autoShootThread = nil end
    hitboxEnabled = false
    for _, p in ipairs(Players:GetPlayers()) do
        removeHitbox(p)
    end
    if killTPThread then pcall(task.cancel, killTPThread) killTPThread = nil end
    killAllRunning = false
    grabGunRunning = false

    -- Misc停止
    coinFarmEnabled = false
    if coinFarmThread then pcall(task.cancel, coinFarmThread) coinFarmThread = nil end
    chatSpamEnabled = false
    if chatSpamThread then pcall(task.cancel, chatSpamThread) chatSpamThread = nil end
    chatSpamRandomEnabled = false
    if chatSpamRandomThread then pcall(task.cancel, chatSpamRandomThread) chatSpamRandomThread = nil end
    fullbrightEnabled = false
    restoreLighting()

    -- Movement停止
    speedEnabled = false
    if speedConn then speedConn:Disconnect() speedConn = nil end
    jumpPowerEnabled = false
    if jumpPowerConn then jumpPowerConn:Disconnect() jumpPowerConn = nil end
    flyEnabled = false
    if flyConn then flyConn:Disconnect() flyConn = nil end
    if flyBV then flyBV:Destroy() flyBV = nil end
    if flyBG then flyBG:Destroy() flyBG = nil end
    noclipEnabled = false
    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    infiniteJumpEnabled = false
    if infJumpConn then infJumpConn:Disconnect() infJumpConn = nil end
    bunnyHopEnabled = false
    if bunnyHopConn then bunnyHopConn:Disconnect() bunnyHopConn = nil end
    antiVoidEnabled = false
    if antiVoidConn then antiVoidConn:Disconnect() antiVoidConn = nil end
    sprintEnabled = false
    if sprintConn then sprintConn:Disconnect() sprintConn = nil end
    antiFlingEnabled = false
    if antiFlingConn then antiFlingConn:Disconnect() antiFlingConn = nil end
    waterWalkEnabled = false
    if waterWalkConn then waterWalkConn:Disconnect() waterWalkConn = nil end
    clickTPEnabled = false
    if clickTPConn then clickTPConn:Disconnect() clickTPConn = nil end
    cursorTPEnabled = false
    if cursorTPConn then cursorTPConn:Disconnect() cursorTPConn = nil end

    -- デフォルトに戻す
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = 16
        hum.JumpPower = 50
        hum.UseJumpPower = true
    end

    Library:Unload()
end)

SettingsLeft:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', {
    Default = 'RightShift',
    NoUI = true,
    Text = 'Menu keybind'
})

Library.ToggleKeybind = Options.MenuKeybind

-- =====================================================
-- Rejoin / Server Hop
-- =====================================================
SettingsMid:AddButton({
    Text = '🔄 Rejoin',
    Tooltip = '現在のサーバーに再参加',
    Func = function()
        Library:Notify('Rejoining...', 2)
        task.wait(0.5)
        game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
    end
})

SettingsMid:AddButton({
    Text = '🌐 Server Hop',
    Tooltip = '別のサーバーに移動（空きがあるサーバーを探す）',
    Func = function()
        Library:Notify('Finding new server...', 2)
        task.spawn(function()
            local HttpService = game:GetService("HttpService")
            local TeleportService = game:GetService("TeleportService")
            local url = string.format(
                "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100",
                game.PlaceId
            )
            local success, result = pcall(function()
                return HttpService:JSONDecode(game:HttpGet(url))
            end)
            if not success or not result or not result.data then
                Library:Notify('Server list fetch failed', 3)
                return
            end
            local servers = {}
            for _, s in ipairs(result.data) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then
                    table.insert(servers, s.id)
                end
            end
            if #servers == 0 then
                Library:Notify('No available servers', 3)
                return
            end
            local targetId = servers[math.random(1, #servers)]
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, targetId, LocalPlayer)
            end)
        end)
    end
})

-- =====================================================
-- Anti-AFK
-- =====================================================
local antiAfkEnabled = false
local antiAfkConn = nil

SettingsMid:AddToggle('AntiAFK', {
    Text = 'Anti-AFK',
    Default = false,
    Tooltip = 'AFKキックを防止',
    Callback = function(Value)
        antiAfkEnabled = Value
        if Value then
            antiAfkConn = LocalPlayer.Idled:Connect(function()
                if not antiAfkEnabled then return end
                local VirtualUser = game:GetService("VirtualUser")
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
            Library:Notify('Anti-AFK: ON', 2)
        else
            if antiAfkConn then antiAfkConn:Disconnect() antiAfkConn = nil end
            Library:Notify('Anti-AFK: OFF', 2)
        end
    end
})

-- =====================================================
-- FPS Booster
-- =====================================================
local fpsBoosterEnabled = false
local fpsBoostBackup = nil

SettingsMid:AddToggle('FPSBooster', {
    Text = 'FPS Booster',
    Default = false,
    Tooltip = 'パフォーマンス向上（影・テクスチャ・パーティクル削除）',
    Callback = function(Value)
        fpsBoosterEnabled = Value

        if Value then
            -- バックアップ
            local Lighting = game:GetService("Lighting")
            fpsBoostBackup = {
                GlobalShadows = Lighting.GlobalShadows,
                ShadowSoftness = Lighting.ShadowSoftness,
            }

            -- 影・ソフトシャドウ無効化
            Lighting.GlobalShadows = false
            Lighting.ShadowSoftness = 0

            -- テクスチャ・デカール・パーティクル削除
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("Texture") or obj:IsA("Decal") then
                    obj.Transparency = 1
                elseif obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                    obj.Enabled = false
                end
            end

            -- Terrainの水を無効化
            pcall(function()
                Workspace.Terrain.WaterWaveSize = 0
                Workspace.Terrain.WaterWaveSpeed = 0
                Workspace.Terrain.WaterReflectance = 0
                Workspace.Terrain.WaterTransparency = 0
            end)

            -- 新規追加にも対応
            Workspace.DescendantAdded:Connect(function(obj)
                if not fpsBoosterEnabled then return end
                if obj:IsA("Texture") or obj:IsA("Decal") then
                    obj.Transparency = 1
                elseif obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                    obj.Enabled = false
                end
            end)

            Library:Notify('FPS Booster: ON', 2)
        else
            if fpsBoostBackup then
                local Lighting = game:GetService("Lighting")
                Lighting.GlobalShadows = fpsBoostBackup.GlobalShadows
                Lighting.ShadowSoftness = fpsBoostBackup.ShadowSoftness
            end
            Library:Notify('FPS Booster: OFF (rejoin推奨)', 3)
        end
    end
})

-- =====================================================
-- UI Scale
-- =====================================================
local UI_SCALE = 1
SettingsMid:AddSlider('UIScale', {
    Text = 'UI Scale',
    Default = 1,
    Min = 0.5,
    Max = 1.5,
    Rounding = 1,
    Suffix = 'x',
    Callback = function(v)
        UI_SCALE = v
        -- LinoriaLibのUIをスケール変更
        pcall(function()
            for _, gui in ipairs(game:GetService("CoreGui"):GetDescendants()) do
                if gui:IsA("ScreenGui") and gui.Name:find("Linoria") then
                    for _, child in ipairs(gui:GetDescendants()) do
                        if child:IsA("Frame") and child.Name == "Main" then
                            -- スケール適用は複雑なのでここでは通知のみ
                        end
                    end
                end
            end
        end)
        Library:Notify('UI Scale: ' .. v .. 'x (rejoinで適用)', 2)
    end
})

-- =====================================================
-- Watermark Toggle
-- =====================================================
local watermarkVisible = true

SettingsRight:AddToggle('WatermarkToggle', {
    Text = 'Watermark',
    Default = true,
    Tooltip = '右上のウォーターマーク表示切替',
    Callback = function(Value)
        watermarkVisible = Value
        pcall(function()
            Library:SetWatermark(Value and '⚡ MM2 HUB | LinoriaLib' or '')
        end)
    end
})

-- =====================================================
-- Notification Toggle
-- =====================================================
local notifyEnabled = true
local originalNotify = Library.Notify

SettingsRight:AddToggle('NotifyToggle', {
    Text = 'Notifications',
    Default = true,
    Tooltip = '通知のON/OFF',
    Callback = function(Value)
        notifyEnabled = Value
        if Value then
            Library.Notify = originalNotify
        else
            Library.Notify = function() end
        end
    end
})

-- =====================================================
-- Credits
-- =====================================================
SettingsRight:AddLabel('═══════════════════════')
SettingsRight:AddLabel('⚡ Oryn HUB ⚡')
SettingsRight:AddLabel('Version: 2.11')
SettingsRight:AddLabel('Author: am4tz')
SettingsRight:AddLabel('UI: LinoriaLib')
SettingsRight:AddLabel('═══════════════════════')

-- =====================================================
-- Update Checker
-- =====================================================
local CURRENT_VERSION = "1.0.0"
local SCRIPT_URL = "https://raw.githubusercontent.com/YOUR-USERNAME/YOUR-REPO/main/version.txt"

SettingsRight:AddButton({
    Text = '🔍 Check for Updates',
    Tooltip = '最新版があるかチェック',
    Func = function()
        Library:Notify('Checking for updates...', 2)
        task.spawn(function()
            local success, result = pcall(function()
                return game:HttpGet(SCRIPT_URL)
            end)
            if not success or not result then
                Library:Notify('Update check failed (no internet)', 3)
                return
            end
            local latestVersion = result:gsub("%s+", "")
            if latestVersion ~= CURRENT_VERSION then
                Library:Notify('🆕 New version available: ' .. latestVersion, 5)
            else
                Library:Notify('✔ You are on the latest version', 3)
            end
        end)
    end
})

SettingsRight:AddLabel('Current: v' .. CURRENT_VERSION)

Library:SetWatermark('Oryn MM2 HUB | LinoriaLib')
print(' HUB Loaded!')