-- =====================================================
-- Oryn HUB - LinoriaLib 完全版
-- LagKick + Defense (全機能統合 + Anti Lag)
-- =====================================================

local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Options = Library.Options
local Toggles = Library.Toggles

-- =====================================================
-- サービス・変数定義
-- =====================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local PS = Players

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local RS = ReplicatedStorage
local plr = LocalPlayer
local Player = LocalPlayer

local GrabEvents = RS:FindFirstChild("GrabEvents")
local CharacterEvents = RS:FindFirstChild("CharacterEvents")
local StruggleEvent = CharacterEvents and CharacterEvents:FindFirstChild("Struggle")
local BeingHeld = Player:FindFirstChild("BeingHeld") or Instance.new("BoolValue", Player)

-- =====================================================
-- グローバル変数
-- =====================================================
_G.cons = _G.cons or {}
_G.ShurikenAntiKick = false
_G.LineLagPacketCount = 10

-- =====================================================
-- ウィンドウ作成
-- =====================================================
local Window = Library:CreateWindow({
    Title = '⚡ Oryn HUB',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local Tabs = {
    Main = Window:AddTab('Lag'),
    Defense = Window:AddTab('Defense'),
    Grab = Window:AddTab('Grab'),
    Target = Window:AddTab('Target'),
    Misc = Window:AddTab('Misc'),
    Player = Window:AddTab('Player'),
    Settings = Window:AddTab('UI Settings')
}
-- =====================================================
-- ユーティリティ関数
-- =====================================================
local function getAllPlayers()
    local players = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(players, p)
        end
    end
    return players
end

local function spamOwnership(hrp)
    if not GrabEvents then return end
    local setOwner = GrabEvents:FindFirstChild("SetNetworkOwner")
    if setOwner and hrp then
        pcall(function() setOwner:FireServer(hrp, hrp.CFrame) end)
    end
end

local function teleportToPlayer(myHrp, targetHrp)
    if not myHrp or not targetHrp then return end
    pcall(function()
        myHrp.CFrame = targetHrp.CFrame * CFrame.new(0, 5, 5)
        myHrp.AssemblyLinearVelocity = Vector3.zero
    end)
end

local function destroyLineOnPlayer(hrp)
    if not GrabEvents then return end
    local createLine = GrabEvents:FindFirstChild("CreateGrabLine")
    local destroyLine = GrabEvents:FindFirstChild("DestroyGrabLine")
    if not createLine or not destroyLine then return end
    pcall(function()
        createLine:FireServer(hrp, CFrame.new(0, 1e9, 0))
        task.wait()
        destroyLine:FireServer(hrp)
    end)
end

-- =====================================================
-- ラインラグ機能
-- =====================================================
local lineLagThread = nil
local lineLagEnabled = false

local function startLineLag()
    if lineLagEnabled then return end
    lineLagEnabled = true
    lineLagThread = task.spawn(function()
        if not GrabEvents then return end
        local createLine = GrabEvents:FindFirstChild("CreateGrabLine")
        if not createLine then
            Library:Notify('CreateGrabLine not found', 3)
            return
        end

        while lineLagEnabled do
            local target = Workspace:FindFirstChild("SpawnLocation")
                or Workspace:FindFirstChild("Spawn")
                or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"))
            if target then
                for i = 1, _G.LineLagPacketCount do
                    local randomX = math.random(-1e9, 1e9)
                    local randomZ = math.random(-1e9, 1e9)
                    pcall(function()
                        createLine:FireServer(target, CFrame.new(randomX, 0, randomZ))
                    end)
                end
            end
            task.wait(0.05)
        end
    end)
end

local function stopLineLag()
    lineLagEnabled = false
    if lineLagThread then
        task.cancel(lineLagThread)
        lineLagThread = nil
    end
end

-- =====================================================
-- LagKick タブ
-- =====================================================
local LeftGroupBox = Tabs.Main:AddLeftGroupbox('LagKick Control')
local RightGroupBox = Tabs.Main:AddRightGroupbox('オプション')

local SelectedHeight = "Spawn"
local LagKickRunning = false

LeftGroupBox:AddDropdown('HeightMode', {
    Text = 'Height Mode',
    Values = { 'Spawn (Ground)', 'Heaven' },
    Default = 1,
    Multi = false,
    Callback = function(Value)
        SelectedHeight = (Value == 'Heaven') and 'Heaven' or 'Spawn'
    end
})

LeftGroupBox:AddButton({
    Text = '🚀 Destroy Server',
    Func = function()
        if LagKickRunning then
            Library:Notify('Destroy Server is already in progress', 3)
            return
        end

        LagKickRunning = true
        Library:Notify('Destroy Server Started!', 2)

        task.spawn(function()
            local height = (SelectedHeight == "Heaven") and 1e9 or 35

            startLineLag()
            task.wait(1)

            local players = getAllPlayers()
            if #players == 0 then
                stopLineLag()
                LagKickRunning = false
                Library:Notify('No players found', 3)
                return
            end

            Library:Notify(#players .. ' players found', 2)

            local myChar = LocalPlayer.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if not myHrp then
                stopLineLag()
                LagKickRunning = false
                return
            end

            local playerData = {}
            for _, p in ipairs(players) do
                local char = p.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    table.insert(playerData, { player = p, hrp = hrp })
                end
            end

            for _, data in ipairs(playerData) do
                teleportToPlayer(myHrp, data.hrp)
                task.wait(0.2)
                spamOwnership(data.hrp)
                task.wait()
            end

            local radius = 40
            local angleStep = (math.pi * 2) / #playerData
            for idx, data in ipairs(playerData) do
                local angle = (idx - 1) * angleStep
                local x = math.cos(angle) * radius
                local z = math.sin(angle) * radius

                pcall(function()
                    data.hrp.CFrame = CFrame.new(x, height, z)
                    data.hrp.AssemblyLinearVelocity = Vector3.zero
                end)

                local bp = Instance.new("BodyPosition")
                bp.MaxForce = Vector3.new(1e9, 1e9, 1e9)
                bp.P = 40000000
                bp.Position = Vector3.new(x, height, z)
                bp.Parent = data.hrp
                task.delay(2, function() pcall(function() bp:Destroy() end) end)
                task.wait()
            end

            for i = 1, 8 do
                for _, data in ipairs(playerData) do
                    destroyLineOnPlayer(data.hrp)
                end
                task.wait(0.3)
            end

            LagKickRunning = false
            Library:Notify('Destruction complete!', 3)
        end)
    end
})

LeftGroupBox:AddButton({
    Text = '⏹ Stop Lag',
    Func = function()
        stopLineLag()
        LagKickRunning = false
        Library:Notify('Lag stopped', 2)
    end
})

LeftGroupBox:AddDivider()
LeftGroupBox:AddLabel('Status: Idle')

RightGroupBox:AddSlider('PacketCount', {
    Text = '1回あたりのパケット数',
    Default = 10,
    Min = 1,
    Max = 50,
    Rounding = 0,
    Suffix = '件',
    Callback = function(Value)
        _G.LineLagPacketCount = Value
    end
})

-- =====================================================
-- Packet Spam (新規追加)
-- =====================================================
local MiscGroup = Tabs.Main:AddRightGroupbox('Packet Spam')

MiscGroup:AddSlider('PacketSpamAmount', {
    Text = 'Packet Amount',
    Default = 900,
    Min = 10,
    Max = 5000,
    Rounding = 0,
    Compact = false,
})

MiscGroup:AddToggle('PacketLagActive', {
    Text = 'Enable Packet Lag',
    Default = false,
    Tooltip = '大量のパケットを送信してサーバーに負荷をかけます',
    Callback = function(Value)
        _G.PacketLagActive = Value

        if Value then
            task.spawn(function()
                -- 安全チェック（特定プレイヤー検出時は自動停止）
                local Players = game:GetService("Players")
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Name == "MaybeFlashh" then
                        Library:Notify("Safety Alert: MaybeFlashh detected. Packet lag disabled for safety.", 5)
                        _G.PacketLagActive = false
                        Toggles.PacketLagActive:SetValue(false)
                        return
                    end
                end

                -- パケットスパム メインループ
                local GrabEvents = RS:FindFirstChild("GrabEvents")
                if not GrabEvents then
                    Library:Notify("GrabEvents not found", 3)
                    _G.PacketLagActive = false
                    Toggles.PacketLagActive:SetValue(false)
                    return
                end

                local createLine = GrabEvents:FindFirstChild("CreateGrabLine")
                if not createLine then
                    Library:Notify("CreateGrabLine not found", 3)
                    _G.PacketLagActive = false
                    Toggles.PacketLagActive:SetValue(false)
                    return
                end

                while _G.PacketLagActive do
                    local amount = Options.PacketSpamAmount.Value

                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    local target = hrp or Workspace:FindFirstChild("SpawnLocation") or Workspace:FindFirstChild("Spawn")

                    if target then
                        for i = 1, amount do
                            local randomX = math.random(-1e9, 1e9)
                            local randomY = math.random(-1e9, 1e9)
                            local randomZ = math.random(-1e9, 1e9)
                            pcall(function()
                                createLine:FireServer(target, CFrame.new(randomX, randomY, randomZ))
                            end)

                            -- サーバーキック防止のため小刻みにウェイト
                            if i % 100 == 0 then
                                task.wait()
                            end

                            if not _G.PacketLagActive then break end
                        end
                    end

                    task.wait(0.1)
                end
            end)
            Library:Notify("Packet Lag: Enabled", 2)
        else
            Library:Notify("Packet Lag: Disabled", 2)
        end
    end
})

-- =====================================================
-- Monster Lag (新規追加)
-- =====================================================
_G.MonsterLagEnabled = false

MiscGroup:AddToggle('MonsterLagToggle', {
    Text = 'Monster Lag',
    Default = false,
    Tooltip = 'SpawnLocationに向けて大量のGrabLineを送信してサーバーを重くします',
    Callback = function(Value)
        _G.MonsterLagEnabled = Value

        if Value then
            task.spawn(function()
                local RepS = game:GetService("ReplicatedStorage")
                local WS = game:GetService("Workspace")
                local LP = game:GetService("Players").LocalPlayer
                local GrabEvents = RepS:FindFirstChild("GrabEvents")
                local CreateLine = GrabEvents and GrabEvents:FindFirstChild("CreateGrabLine")

                if not CreateLine then
                    Library:Notify('CreateGrabLine not found', 3)
                    _G.MonsterLagEnabled = false
                    Toggles.MonsterLagToggle:SetValue(false)
                    return
                end

                while _G.MonsterLagEnabled and CreateLine do
                    local spawnLocation = WS:FindFirstChild("SpawnLocation")
                        or WS:FindFirstChild("Spawn")
                        or (LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"))

                    if spawnLocation then
                        local randomX = math.random(-9e9, 9e9)
                        local randomZ = math.random(-9e9, 9e9)
                        pcall(function()
                            CreateLine:FireServer(spawnLocation, CFrame.new(randomX, 0, randomZ))
                        end)
                    end
                    task.wait()
                end
            end)
            Library:Notify('Monster Lag: Enabled', 2)
        else
            Library:Notify('Monster Lag: Disabled', 2)
        end
    end
})

-- Defense タブ
-- =====================================================
local DefenseLeft = Tabs.Defense:AddLeftGroupbox('Basic Defense')
local DefenseRight = Tabs.Defense:AddRightGroupbox('Extra Defense')

-- Anti Grab [BETA]
do
    local AntiGrab = false
    local AntiGrabProc = false
    local AGWalk = false
    local Cons = {}

    local function DiscAll()
        for k, v in pairs(Cons) do
            if v then v:Disconnect() end
        end
        table.clear(Cons)
    end

    local function ApplyAntiGrab(char)
        if not char or not AntiGrab then return end

        local hrp = char:WaitForChild("HumanoidRootPart", 5)
        local hum = char:WaitForChild("Humanoid", 5)
        local head = char:WaitForChild("Head", 5)
        if not (hrp and hum and head) then return end

        for _, v in pairs(char:GetChildren()) do
            if v:IsA("BasePart") and v:FindFirstChild("BallSocketConstraint") and v.Name ~= "Head" then
                v.BallSocketConstraint.Enabled = false
                if v:FindFirstChild("RagdollLimbPart") then
                    v.RagdollLimbPart.WeldConstraint.Enabled = false
                end
            end
        end

        Cons["AGHead"] = head.ChildAdded:Connect(function(PartOwner)
            if PartOwner.Name == "PartOwner" then
                if not AntiGrabProc then
                    AntiGrabProc = true
                    hum.Sit = false
                    if StruggleEvent then StruggleEvent:FireServer(Player) end

                    task.spawn(function()
                        while (head and head:FindFirstChild("PartOwner")) or BeingHeld.Value do
                            if StruggleEvent then StruggleEvent:FireServer(Player) end
                            pcall(function()
                                RS.CharacterEvents.RagdollRemote:FireServer(hrp, 0)
                            end)
                            task.wait()
                        end
                    end)

                    hrp.Anchored = true
                    if not AGWalk then
                        AGWalk = true
                        while BeingHeld.Value and task.wait() do
                            hrp.CFrame = hrp.CFrame + hum.MoveDirection * 0.43
                        end
                    end
                    hrp.Anchored = false
                    AntiGrabProc = false
                    AGWalk = false
                end
            end
        end)

        local ragdolled = hum:WaitForChild("Ragdolled", 5)
        if ragdolled then
            Cons["AGRagdoll"] = ragdolled.Changed:Connect(function()
                if hum.Ragdolled.Value then
                    for _, v in pairs(char:GetChildren()) do
                        if v:IsA("BasePart") and v:FindFirstChild("BallSocketConstraint") and v.Name ~= "Head" then
                            v.BallSocketConstraint.Enabled = false
                            if v:FindFirstChild("RagdollLimbPart") then
                                v.RagdollLimbPart.WeldConstraint.Enabled = false
                            end
                        end
                    end
                end
            end)
        end

        local weldHRP = hrp:WaitForChild("WeldHRP", 5)
        if weldHRP then
            Cons["AGWeld"] = weldHRP.Changed:Connect(function()
                if hrp.WeldHRP.Enabled then
                    while not hum.Sit do task.wait() end
                    hum.Sit = false
                    hum.AutoRotate = true
                    hum.HipHeight = 1
                    while hrp.WeldHRP.Enabled and task.wait() do
                        head.CFrame = hrp.CFrame + Vector3.new(0, 1.35, 0)
                    end
                    hum.HipHeight = 0
                end
            end)
        end
    end

    DefenseLeft:AddToggle('AntiGrab', {
        Text = 'Anti Grab [BEST (use solo)]',
        Default = false,
        Tooltip = '最も強力なAntiGrab（ソロ推奨）',
        Callback = function(Value)
            AntiGrab = Value
            DiscAll()

            if AntiGrab then
                ApplyAntiGrab(Player.Character)
                Cons["AGChar"] = Player.CharacterAdded:Connect(ApplyAntiGrab)
            else
                local char = Player.Character
                if char then
                    for _, v in pairs(char:GetChildren()) do
                        if v:IsA("BasePart") and v:FindFirstChild("BallSocketConstraint") and v.Name ~= "Head" then
                            v.BallSocketConstraint.Enabled = false
                            if v:FindFirstChild("RagdollLimbPart") then
                                v.RagdollLimbPart.WeldConstraint.Enabled = true
                            end
                        end
                    end
                end
            end
        end
    })
end

-- Anti Blob
do
    local antiblob = false

    DefenseLeft:AddToggle('AntiBlobKick', {
        Text = 'Anti Blob',
        Default = false,
        Tooltip = 'Blobに掴まれた際に脱出します',
        Callback = function(Value)
            antiblob = Value
            local player = LocalPlayer

            if antiblob and player.Character then
                if not player.Character:FindFirstChild("TruePositionPart") then
                    local truePosPart = Instance.new("Part")
                    truePosPart.Parent = player.Character
                    truePosPart.Name = "TruePositionPart"
                    truePosPart.Anchored = true
                    truePosPart.Transparency = 0.8
                    truePosPart.CanCollide = false
                    truePosPart.Size = Vector3.new(0.1, 0.1, 0.1)
                    truePosPart.CFrame = CFrame.new(0, -10000000, 0)
                end
            end

            task.spawn(function()
                while antiblob and task.wait() do
                    if player.Character then
                        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                        local truePosPart = player.Character:FindFirstChild("TruePositionPart")

                        if hrp and truePosPart then
                            local rootAttachment = hrp:FindFirstChild("RootAttachment")
                            if rootAttachment and rootAttachment.Parent == hrp then
                                rootAttachment.Parent = truePosPart
                            end

                            local isGrabbed = false
                            for _, part in pairs(player.Character:GetChildren()) do
                                if part:IsA("Part") and part.Massless then
                                    part.Massless = false
                                    isGrabbed = true
                                end
                            end

                            if isGrabbed then
                                hrp.AssemblyLinearVelocity = Vector3.new(0, 15000000, 0)

                                local function fireDrop(item)
                                    local blobScript = item:FindFirstChild("BlobmanSeatAndOwnerScript")
                                    local rightDetector = item:FindFirstChild("RightDetector")
                                    local leftDetector = item:FindFirstChild("LeftDetector")

                                    if blobScript and rightDetector and leftDetector then
                                        local dropEvent = blobScript:FindFirstChild("CreatureDrop")
                                        local rightWeld = rightDetector:FindFirstChild("RightWeld")
                                        local leftWeld = leftDetector:FindFirstChild("LeftWeld")

                                        if dropEvent then
                                            if rightWeld then dropEvent:FireServer(rightWeld, hrp) end
                                            if leftWeld then dropEvent:FireServer(leftWeld, hrp) end
                                        end

                                        if RS:FindFirstChild("CharacterEvents") then
                                            local struggleEvent = RS.CharacterEvents:FindFirstChild("Struggle")
                                            if struggleEvent then struggleEvent:FireServer(player) end
                                        end
                                    end
                                end

                                local plotItems = Workspace:FindFirstChild("PlotItems")
                                if plotItems then
                                    for _, plot in pairs(plotItems:GetChildren()) do
                                        if plot.Name ~= "PlayersInPlots" then
                                            for _, item in pairs(plot:GetChildren()) do
                                                if item.Name == "CreatureBlobman" then
                                                    fireDrop(item)
                                                end
                                            end
                                        end
                                    end
                                end

                                for _, p in pairs(Players:GetPlayers()) do
                                    local toyFolder = Workspace:FindFirstChild(p.Name .. "SpawnedInToys")
                                    if toyFolder then
                                        for _, item in pairs(toyFolder:GetChildren()) do
                                            if item.Name == "CreatureBlobman" then
                                                fireDrop(item)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end)

            if not antiblob and player.Character then
                local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                local truePosPart = player.Character:FindFirstChild("TruePositionPart")
                if hrp and truePosPart then
                    local rootAttachment = truePosPart:FindFirstChild("RootAttachment")
                    if rootAttachment then rootAttachment.Parent = hrp end
                    truePosPart:Destroy()
                end
            end
        end
    })
end

-- Anti Ragdoll (On Blob)
do
    local AntiRagBlob = false
    local RagdolledSit = false
    local Cons = {}

    local function ApplyAntiRagdoll(char)
        if not char or not AntiRagBlob then return end

        local hum = char:WaitForChild("Humanoid", 5)
        local HRP = char:WaitForChild("HumanoidRootPart", 5)
        if not (hum and HRP) then return end

        if Cons["ARSeat"] then Cons["ARSeat"]:Disconnect() end
        Cons["ARSeat"] = hum:GetPropertyChangedSignal("SeatPart"):Connect(function()
            if hum.SeatPart and hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "CreatureBlobman" and not RagdolledSit then
                RagdolledSit = true
                local Seat = hum.SeatPart
                while not hum.Sit do task.wait() end

                pcall(function()
                    RS.CharacterEvents.RagdollRemote:FireServer(HRP, 3)
                end)

                local ragdolledVal = hum:FindFirstChild("Ragdolled")
                while ragdolledVal and not ragdolledVal.Value and not hum.Sit do task.wait() end

                task.wait(0.4)
                hum.Sit = false
                Seat:Sit(hum)

                task.delay(0.25, function()
                    while hum and hum.SeatPart do
                        pcall(function()
                            RS.CharacterEvents.RagdollRemote:FireServer(HRP, 1)
                        end)
                        task.wait(0.05)
                    end
                    RagdolledSit = false
                end)
            end
        end)
    end

    DefenseLeft:AddToggle('AntiRagdoll', {
        Text = 'Anti Ragdoll (On Blob)',
        Default = false,
        Tooltip = 'Blobに乗った際のラグドールを防止',
        Callback = function(Value)
            AntiRagBlob = Value
            RagdolledSit = false

            if Cons["ARChar"] then Cons["ARChar"]:Disconnect() end
            if Cons["ARSeat"] then Cons["ARSeat"]:Disconnect() end

            if AntiRagBlob then
                ApplyAntiRagdoll(Player.Character)
                Cons["ARChar"] = Player.CharacterAdded:Connect(ApplyAntiRagdoll)
            end
        end
    })
end

-- Anti Banana [SIT]
do
    local antibananaSit = false

    DefenseLeft:AddToggle('AntiBananaSit', {
        Text = 'Anti Banana [SIT]',
        Default = false,
        Tooltip = 'BananaによるSIT状態を防止',
        Callback = function(Value)
            antibananaSit = Value

            task.spawn(function()
                while antibananaSit do
                    local char = Player.Character
                    if char then
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        if hum and hrp and hum.Health > 0 then
                            hum.Sit = true
                            hum:ChangeState(Enum.HumanoidStateType.Running)
                            local Vec = Camera.CFrame.LookVector
                            hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + Vector3.new(Vec.X, 0, Vec.Z))
                        end
                    end
                    task.wait()
                end
            end)
        end
    })
end

-- Anti Void
DefenseLeft:AddToggle('AntiVoid', {
    Text = 'Anti Void',
    Default = false,
    Tooltip = 'FallenPartsDestroyHeightを無効化',
    Callback = function(v)
        if v then
            Workspace.FallenPartsDestroyHeight = 0/0
        else
            Workspace.FallenPartsDestroyHeight = -100
        end
    end
})

-- Anti Explosion
do
    local antiExplodeT = false
    local conn = nil

    local function antiExplodeF()
        antiExplodeT = true
        local char = Player.Character
        if not char then return end
        local hrp = char:WaitForChild("HumanoidRootPart")
        conn = Workspace.ChildAdded:Connect(function(model)
            if model.Name == "Part" and antiExplodeT then
                local mag = (model.Position - hrp.Position).Magnitude
                if mag <= 20 then
                    hrp.Anchored = true
                    task.wait(0.01)
                    while char["Right Arm"] and char["Right Arm"].RagdollLimbPart and char["Right Arm"].RagdollLimbPart.CanCollide do
                        task.wait(0.001)
                    end
                    hrp.Anchored = false
                end
            end
        end)
    end

    DefenseLeft:AddToggle('AntiExplosion', {
        Text = 'Anti Explosion',
        Default = false,
        Tooltip = '爆発によるダメージ/ラグドールを防止',
        Callback = function(on)
            if on then
                antiExplodeF()
            else
                antiExplodeT = false
                if conn then conn:Disconnect() conn = nil end
            end
        end
    })
end

-- Anti Loop Kill
DefenseLeft:AddToggle('AntiLoopKill', {
    Text = 'Anti Loop Kill',
    Default = false,
    Tooltip = 'ループキルのターゲット位置に強制移動',
    Callback = function(v)
        if _G.cons["antiloopkill"] then
            _G.cons["antiloopkill"]:Disconnect()
            _G.cons["antiloopkill"] = nil
        end

        if v then
            _G.cons["antiloopkill"] = plr.CharacterAdded:Connect(function(char)
                local hrp = char:WaitForChild("HumanoidRootPart", 5)
                if hrp then
                    RunService.RenderStepped:Wait()
                    local target = CFrame.new(524.703979, 93.7120056, -375.040985)
                    hrp.CFrame = target
                    for i = 1, 2 do
                        RunService.RenderStepped:Wait()
                        hrp.CFrame = target
                    end
                end
            end)
        end
    end
})

-- =====================================================
-- Anti Lag（追加）
-- =====================================================
do
    local antiLagActive = false
    local originalMethods = {}

    -- GrabEvents内のRemoteEventを無効化（ネットワーク負荷軽減）
    local function disableGrabEvents()
        if not GrabEvents then return end
        for _, child in pairs(GrabEvents:GetChildren()) do
            if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
                if not originalMethods[child] then
                    originalMethods[child] = {
                        FireServer = child.FireServer,
                        InvokeServer = child.InvokeServer,
                    }
                end
                -- 何もしない関数に置き換え
                pcall(function()
                    child.FireServer = function() end
                end)
                pcall(function()
                    child.InvokeServer = function() return nil end
                end)
            end
        end
    end

    -- 元に戻す
    local function restoreGrabEvents()
        for child, methods in pairs(originalMethods) do
            if child and child.Parent then
                pcall(function()
                    child.FireServer = methods.FireServer
                end)
                pcall(function()
                    child.InvokeServer = methods.InvokeServer
                end)
            end
        end
        table.clear(originalMethods)
    end

    DefenseRight:AddToggle('AntiLag', {
        Text = 'Anti Lag',
        Default = false,
        Tooltip = 'GrabEventsの通信を無効化してラグを軽減（他プレイヤーからの干渉を防ぐ）',
        Callback = function(Value)
            antiLagActive = Value

            if Value then
                task.spawn(function()
                    while antiLagActive do
                        disableGrabEvents()
                        task.wait(0.5)
                    end
                end)
            else
                restoreGrabEvents()
            end
        end
    })
end

-- =====================================================
-- Anti Kick (Shuriken)
-- =====================================================
DefenseRight:AddToggle('ShurikenAntiKick', {
    Text = 'Anti Kick',
    Default = false,
    Tooltip = 'Shurikenによるキックを防止',
    Callback = function(Value)
        _G.ShurikenAntiKick = Value

        local function ClearKunai()
            local inv = Workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
            local destroyrem = RS:FindFirstChild("MenuToys") and RS.MenuToys:FindFirstChild("DestroyToy")
            if inv and destroyrem then
                for _, v in pairs(inv:GetChildren()) do
                    if v.Name == "AntiKick" or v.Name == "NinjaShuriken" then
                        pcall(function() destroyrem:FireServer(v) end)
                    end
                end
            end
        end

        if Value then
            task.spawn(function()
                local setOwner = RS:WaitForChild("GrabEvents"):WaitForChild("SetNetworkOwner")
                local stickyEvent = RS:WaitForChild("PlayerEvents"):WaitForChild("StickyPartEvent")
                local spawnRemote = RS:WaitForChild("MenuToys"):WaitForChild("SpawnToyRemoteFunction")
                local canSpawn = Player:WaitForChild("CanSpawnToy")

                local function getHRP()
                    if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                        return Player.Character.HumanoidRootPart
                    else
                        return Player.CharacterAdded:Wait():WaitForChild("HumanoidRootPart")
                    end
                end

                local function CheckForHome()
                    if not Workspace.PlotItems.PlayersInPlots:FindFirstChild(Player.Name) then return false end
                    for _, v in pairs(Workspace.Plots:GetChildren()) do
                        local sign = v:FindFirstChild("PlotSign")
                        local owners = sign and sign:FindFirstChild("ThisPlotsOwners")
                        if owners then
                            for _, b in pairs(owners:GetChildren()) do
                                if b.Value == Player.Name then
                                    local folder = Workspace.PlotItems:FindFirstChild(v.Name)
                                    if folder then return true, folder end
                                end
                            end
                        end
                    end
                    return false
                end

                local function StickKunai(kunai)
                    if not kunai or not kunai:FindFirstChild("StickyPart") then return end
                    local currentHRP = getHRP()
                    if not currentHRP then return end

                    if kunai:FindFirstChild("SoundPart") then
                        if not kunai.SoundPart:FindFirstChild("PartOwner") or kunai.SoundPart.PartOwner.Value ~= Player.Name then
                            setOwner:FireServer(kunai.SoundPart, kunai.SoundPart.CFrame)
                        end
                    end

                    local firePart = currentHRP:FindFirstChild("FirePlayerPart") or currentHRP:WaitForChild("FirePlayerPart", 5)
                    if firePart then
                        stickyEvent:FireServer(kunai.StickyPart, firePart, CFrame.new(0,0,0) * CFrame.Angles(0,math.rad(90),math.rad(90)))
                    end

                    for _, obj in pairs(kunai:GetChildren()) do
                        if obj.Name == "Pyramid" then
                            obj.CanTouch = false; obj.CanCollide = false; obj.CanQuery = false; obj.Transparency = 0
                            if not obj:FindFirstChild("Highlight") then
                                local high = Instance.new("Highlight", obj)
                                high.FillColor = Color3.fromRGB(0, 0, 0)
                            end
                        elseif obj.Name == "Main" then
                            obj.CanTouch = false; obj.CanCollide = false; obj.CanQuery = false; obj.Transparency = 0
                            if not obj:FindFirstChild("Highlight") then
                                local high = Instance.new("Highlight", obj)
                                high.FillColor = Color3.fromRGB(255, 255, 255)
                            end
                        elseif obj:IsA("BasePart") then
                            obj.CanTouch = false; obj.CanCollide = false; obj.CanQuery = false; obj.Transparency = 1
                        end
                    end
                end

                local function SpawnToy(name)
                    local t = tick()
                    while not canSpawn.Value do
                        if not _G.ShurikenAntiKick or tick() - t > 5 then return nil end
                        task.wait(0.1)
                    end
                    local currentHRP = getHRP()
                    if currentHRP then
                        task.spawn(function()
                            pcall(function()
                                spawnRemote:InvokeServer(name, currentHRP.CFrame * CFrame.new(0, 12, 20), Vector3.new(0,0,0))
                            end)
                        end)
                    end
                    local boolik, house = CheckForHome()
                    local inv = Workspace:FindFirstChild(Player.Name.."SpawnedInToys")
                    if boolik and house then
                        return house:WaitForChild(name, 2)
                    elseif not Workspace.PlotItems.PlayersInPlots:FindFirstChild(Player.Name) and inv then
                        return inv:WaitForChild(name, 2)
                    end
                    return nil
                end

                while _G.ShurikenAntiKick do
                    task.wait(0.005)
                    if not Player.Character or not Player.Character:FindFirstChild("Humanoid") or Player.Character.Humanoid.Health <= 0 then
                        continue
                    end

                    local inv = Workspace:FindFirstChild(Player.Name.."SpawnedInToys")
                    local kunai = inv and inv:FindFirstChild("NinjaShuriken")

                    if Workspace.PlotItems.PlayersInPlots:FindFirstChild(Player.Name) then
                        local boolik, house = CheckForHome()
                        if boolik and house and Workspace.Plots:FindFirstChild(house.Name) then
                            local sign = Workspace.Plots[house.Name]:FindFirstChild("PlotSign")
                            if sign and sign.ThisPlotsOwners.Value.TimeRemainingNum.Value > 89 then
                                kunai = SpawnToy("NinjaShuriken")
                                if kunai == nil then continue end
                                kunai.Name = "AntiKick"
                                StickKunai(kunai)
                            end
                        end
                    end

                    if not kunai then
                        if Workspace.PlotItems.PlayersInPlots:FindFirstChild(Player.Name) then continue end
                        kunai = SpawnToy("NinjaShuriken")
                        if kunai == nil then continue end
                        kunai.Name = "AntiKick"
                        if not kunai then continue end
                    end

                    repeat
                        if kunai and kunai:FindFirstChild("StickyPart") and kunai.StickyPart.CanTouch == true then
                            StickKunai(kunai)
                            kunai.Name = "AntiKick"
                        end
                        task.wait(0.3)
                    until not kunai or not _G.ShurikenAntiKick or not kunai:FindFirstChild("StickyPart") or kunai.StickyPart.CanTouch == false
                        or not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart")
                        or not kunai:FindFirstChild("StickyPart")
                        or (Player.Character.HumanoidRootPart.Position - kunai.StickyPart.Position).Magnitude >= 20

                    if not kunai or not kunai:FindFirstChild("StickyPart") or not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") or (Player.Character.HumanoidRootPart.Position - kunai.StickyPart.Position).Magnitude >= 20 then
                        ClearKunai()
                    end

                    pcall(function()
                        repeat task.wait(0.05) until not _G.ShurikenAntiKick or not Player.Character or not Player.Character:FindFirstChild("Humanoid") or not kunai or not kunai:FindFirstChild("StickyPart") or not kunai.StickyPart:FindFirstChild("StickyWeld") or not kunai.StickyPart.StickyWeld.Part1
                        if not kunai or not kunai:FindFirstChild("StickyPart") or (Player.Character and Player.Character:FindFirstChild("Humanoid") and Player.Character.Humanoid.Health <= 0) or not kunai["StickyPart"]:FindFirstChild("StickyWeld").Part1 then
                            ClearKunai()
                        end
                    end)
                end
                ClearKunai()
            end)
        else
            _G.ShurikenAntiKick = false
            ClearKunai()
        end
    end
})

-- =====================================================
-- Anti Kick [ITEM]
-- =====================================================
do
    local AntiKickItemActive = false
    local MyPCLD = nil
    local pcldConn = nil
    local ToyList = {
        ["Japanese Lantern"] = "JapaneseLantern",
        ["Spray Can"] = "SprayCanWD",
        ["Spooky Candle"] = "SpookyCandle1",
    }

    local DropdownValues = {}
    for shortName, _ in pairs(ToyList) do
        table.insert(DropdownValues, shortName)
    end
    table.sort(DropdownValues)

    local SelectedToy = ToyList["Spooky Candle"] or ToyList[DropdownValues[1]]

    DefenseRight:AddDropdown('AntiKickItemDropdown', {
        Text = 'anti kick item',
        Values = DropdownValues,
        Default = 'Spooky Candle',
        Multi = false,
        Callback = function(Value)
            SelectedToy = ToyList[Value]
        end
    })

    local function GetMagnitude(Part1, Part2)
        return (Part1.Position - Part2.Position).Magnitude
    end

    local function FWD(parent, part, timeOffset)
        return parent:FindFirstChild(part) or parent:WaitForChild(part, timeOffset or 1)
    end

    local function CheckNetworkOwnerOnPart(Part)
        local po = Part:FindFirstChild("PartOwner")
        return po and po.Value == plr.Name
    end

    local function sno(part)
        pcall(function()
            local grabEvents = RS:FindFirstChild("GrabEvents")
            local setNetOwner = grabEvents and grabEvents:FindFirstChild("SetNetworkOwner")
            if setNetOwner then
                setNetOwner:FireServer(part, part.CFrame)
            end
        end)
    end

    local function CheckForHome()
        local plotItems = Workspace:FindFirstChild("PlotItems")
        local plots = Workspace:FindFirstChild("Plots")

        if plots and plotItems then
            for i = 1, 5 do
                local Plot = plots:FindFirstChild("Plot"..i)
                if Plot then
                    local sign = Plot:FindFirstChild("PlotSign")
                    local owners = sign and sign:FindFirstChild("ThisPlotsOwners")
                    if owners then
                        for _,v in pairs(owners:GetChildren()) do
                            if v.Value == plr.Name then
                                return plotItems:FindFirstChild("Plot"..i)
                            end
                        end
                    end
                end
            end
        end
        return nil
    end

    local function SpawnToy(ToyName)
        local InPlot = plr:FindFirstChild("InPlot")
        local InOwnedPlot = plr:FindFirstChild("InOwnedPlot")
        local CanSpawnToy = plr:FindFirstChild("CanSpawnToy")
        local inv = Workspace:FindFirstChild(plr.Name.."SpawnedInToys")

        if InPlot and InPlot.Value and InOwnedPlot and not InOwnedPlot.Value then
            InPlot:GetPropertyChangedSignal("Value"):Wait()
        end
        if CanSpawnToy and not CanSpawnToy.Value then
            CanSpawnToy:GetPropertyChangedSignal("Value"):Wait()
        end

        local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil end

        local SpawnCF = (MyPCLD or hrp).CFrame * CFrame.new(0, 14, 20)
        local Container = (InOwnedPlot and InOwnedPlot.Value) and CheckForHome() or inv
        if not Container then return nil end

        local spawnedObject = nil
        local connection
        connection = Container.ChildAdded:Connect(function(child)
            if child.Name == ToyName then
                spawnedObject = child
            end
        end)

        task.spawn(function()
            pcall(function()
                local menuToys = RS:FindFirstChild("MenuToys")
                local spawnRemote = menuToys and menuToys:FindFirstChild("SpawnToyRemoteFunction")
                if spawnRemote then
                    spawnRemote:InvokeServer(ToyName, SpawnCF, Vector3.zero)
                end
            end)
        end)

        local start = tick()
        repeat task.wait() until spawnedObject or (tick() - start) > 2.5

        if connection then connection:Disconnect() end
        return spawnedObject
    end

    local function FindPCLD(hrp)
        if pcldConn then pcldConn:Disconnect() end
        MyPCLD = nil
        pcldConn = RunService.Heartbeat:Connect(function()
            if MyPCLD or not hrp or not hrp.Parent then
                if pcldConn then pcldConn:Disconnect() pcldConn = nil end
                return
            end
            for _, v in pairs(Workspace:GetChildren()) do
                if v.Name == "PlayerCharacterLocationDetector" and v:IsA("BasePart") then
                    if GetMagnitude(v, hrp) <= 2 then
                        MyPCLD = v
                        break
                    end
                end
            end
        end)
    end

    DefenseRight:AddToggle('AntiKickItemFlag', {
        Text = 'Anti Kick [ITEM]',
        Default = false,
        Tooltip = 'アイテムを使ったAnti Kick',
        Callback = function(Val)
            AntiKickItemActive = Val

            if Val then
                task.spawn(function()
                    local Item, SoundPart
                    while AntiKickItemActive and task.wait() do
                        local char = plr.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        local hum = char and char:FindFirstChild("Humanoid")
                        local inPlot = plr:FindFirstChild("InPlot")
                        local inv = Workspace:FindFirstChild(plr.Name.."SpawnedInToys")
                        local destroyToy = RS:FindFirstChild("MenuToys") and RS.MenuToys:FindFirstChild("DestroyToy")

                        if not hrp or not hum or hum.Health <= 0 or not inv then continue end
                        if inPlot and inPlot.Value then continue end

                        if not MyPCLD and not pcldConn then
                            FindPCLD(hrp)
                        end

                        Item = inv:FindFirstChild("AntiKickItem")
                        SoundPart = Item and Item:FindFirstChild("Hitbox")

                        if not Item or not SoundPart then
                            for _,v in pairs(inv:GetChildren()) do
                                if v.Name == "AntiKickItem" then
                                    pcall(function() destroyToy:FireServer(v) end)
                                end
                            end

                            Item = SpawnToy(SelectedToy)
                            if not Item then continue end

                            SoundPart = Item and FWD(Item, "Hitbox", 0.5)
                            if SoundPart then sno(SoundPart) end

                            for _,v in pairs(Item:GetChildren()) do
                                if v:IsA("BasePart") then
                                    v.CanCollide = false
                                    v.Transparency = 0.8
                                    v.Color = Color3.fromRGB(0, 255, 255)
                                end
                            end

                            Item.Name = "AntiKickItem"
                        end

                        if SoundPart and not CheckNetworkOwnerOnPart(SoundPart) then
                            sno(SoundPart)
                        end

                        local targetPart = MyPCLD or hrp:FindFirstChild("FirePlayerPart") or hrp
                        if SoundPart and targetPart then
                            SoundPart.CFrame = targetPart.CFrame
                            SoundPart.AssemblyLinearVelocity = Vector3.zero
                            SoundPart.AssemblyAngularVelocity = Vector3.zero
                        end
                    end
                end)
            else
                if pcldConn then pcldConn:Disconnect() pcldConn = nil end
                MyPCLD = nil

                task.spawn(function()
                    local inv = Workspace:FindFirstChild(plr.Name.."SpawnedInToys")
                    local destroyToy = RS:FindFirstChild("MenuToys") and RS.MenuToys:FindFirstChild("DestroyToy")
                    if inv and destroyToy then
                        for _,v in pairs(inv:GetChildren()) do
                            if v.Name == "AntiKickItem" then
                                pcall(function() destroyToy:FireServer(v) end)
                            end
                        end
                    end
                end)
            end
        end
    })
end

-- =====================================================
-- Grab タブ
-- =====================================================
local GrabLeft = Tabs.Grab:AddLeftGroupbox('Grab Control')
local GrabRight = Tabs.Grab:AddRightGroupbox('Grab Options')

-- =====================================================
-- グローバル変数
-- =====================================================
_G.strength = 400                    -- 既存のKill Grab等で参照している値
local strengthEnabled = false
local throwStrength = 400
local strengthConnection = nil

-- =====================================================
-- 投げる強化トグル（修正版）
-- =====================================================
GrabLeft:AddToggle('StrengthEnabled', {
    Text = '投げる強化 (Strength)',
    Default = false,
    Tooltip = '掴んだオブジェクトを右クリックで投擲',
    Callback = function(enabled)
        strengthEnabled = enabled

        if enabled then
            if strengthConnection then strengthConnection:Disconnect() end

            strengthConnection = Workspace.ChildAdded:Connect(function(model)
                if model.Name == "GrabParts" then
                    task.wait(0.05)

                    local grabPart = model:FindFirstChild("GrabPart")
                    if grabPart and grabPart:FindFirstChild("WeldConstraint") then
                        local partToImpulse = grabPart.WeldConstraint.Part1

                        if partToImpulse then
                            model:GetPropertyChangedSignal("Parent"):Connect(function()
                                if not model.Parent then
                                    local lastInput = UserInputService:GetLastInputType()

                                    if lastInput == Enum.UserInputType.MouseButton2 
                                       or lastInput == Enum.UserInputType.Touch then
                                        -- 投げられた瞬間にVelocityを適用する
                                        local velocityObj = Instance.new("BodyVelocity")
                                        velocityObj.MaxForce = Vector3.new(1e5, 1e5, 1e5) -- 無限ではなく適切な大きさに調整
                                        velocityObj.Velocity = Workspace.CurrentCamera.CFrame.LookVector * throwStrength
                                        velocityObj.Parent = partToImpulse
                                        
                                        -- 短時間だけ適用してすぐに消すことで、自然に飛んで落ちるようにする
                                        Debris:AddItem(velocityObj, 0.15)
                                    end
                                end
                            end)
                        end
                    end
                end
            end)
        else
            if strengthConnection then
                strengthConnection:Disconnect()
                strengthConnection = nil
            end
        end
    end
})
-- =====================================================
-- 投げる強さスライダー
-- =====================================================
GrabLeft:AddSlider('ThrowStrengthSlider', {
    Text = '投げる強さ',
    Default = 400,
    Min = 300,
    Max = 20000,
    Rounding = 0,
    Suffix = '',
    Tooltip = '右クリックで投げる強さ',
    Callback = function(v)
        throwStrength = v
        _G.strength = v   -- 既存のKill Grab等と共有
    end
})

-- =====================================================
-- Kill Grab トグル（既存のまま残す）
-- =====================================================
local killGrabEnabled = false
local killGrabConn = nil

GrabRight:AddToggle('KillGrab', {
    Text = 'Kill Grab',
    Default = false,
    Tooltip = '他プレイヤーがあなたを掴んだ時にそのプレイヤーをキルします',
    Callback = function(Value)
        killGrabEnabled = Value

        if Value then
            if killGrabConn then killGrabConn:Disconnect() end
            killGrabConn = Workspace.ChildAdded:Connect(function(v)
                if v:IsA("Model") and v.Name == "GrabParts" and killGrabEnabled then
                    task.wait(0.05)
                    local grabPart = v:FindFirstChild("GrabPart")
                    local weld = grabPart and grabPart:FindFirstChild("WeldConstraint")
                    local part1 = weld and weld.Part1

                    if part1 and part1.Parent and part1.Parent ~= Player.Character then
                        local targetChar = part1.Parent
                        local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
                        if targetHum and targetChar then
                            pcall(function()
                                targetHum.Health = 0
                                targetChar:BreakJoints()
                            end)
                        end
                    end
                end
            end)
        else
            if killGrabConn then
                killGrabConn:Disconnect()
                killGrabConn = nil
            end
        end
    end
})

-- =====================================================
-- Kill Grab トグル
-- =====================================================
local killGrabEnabled = false
local killGrabConn = nil

GrabRight:AddToggle('KillGrab', {
    Text = 'Kill Grab',
    Default = false,
    Tooltip = '他プレイヤーがあなたを掴んだ時にそのプレイヤーをキルします',
    Callback = function(Value)
        killGrabEnabled = Value

        if Value then
            if killGrabConn then killGrabConn:Disconnect() end
            killGrabConn = Workspace.ChildAdded:Connect(function(v)
                if v:IsA("Model") and v.Name == "GrabParts" and killGrabEnabled then
                    task.wait(0.05)
                    local grabPart = v:FindFirstChild("GrabPart")
                    local weld = grabPart and grabPart:FindFirstChild("WeldConstraint")
                    local part1 = weld and weld.Part1

                    if part1 and part1.Parent and part1.Parent ~= Player.Character then
                        local targetChar = part1.Parent
                        local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
                        if targetHum and targetChar then
                            pcall(function()
                                targetHum.Health = 0
                                targetChar:BreakJoints()
                            end)
                        end
                    end
                end
            end)
        else
            if killGrabConn then
                killGrabConn:Disconnect()
                killGrabConn = nil
            end
        end
    end
})

-- =====================================================
-- Target タブ（Blobman Kick）
-- =====================================================
local BlobGroup = Tabs.Target:AddLeftGroupbox('Blobman Kick')
local InfoGroup = Tabs.Target:AddRightGroupbox('Info')

-- =====================================================
-- ターゲット選択
-- =====================================================
local SelectedTarget = nil
local TARGET_FLAG = 'TargetSelectedPlayer'
local PLACEHOLDER = '-- Select Player --'

local function getPlayerList()
    local list = { PLACEHOLDER }
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(list, p.DisplayName .. " (@" .. p.Name .. ")")
        end
    end
    return list
end

local function getPlayerFromSelection(selection)
    if not selection or selection == "" then return nil end
    if type(selection) == "table" then selection = selection[1] end
    if selection == PLACEHOLDER then return nil end
    local username = selection:match("@(.-)%)")
    if username then return Players:FindFirstChild(username) end
    return nil
end

local function getSelectionString(player)
    if not player then return PLACEHOLDER end
    return player.DisplayName .. " (@" .. player.Name .. ")"
end

-- ドロップダウン作成
BlobGroup:AddDropdown(TARGET_FLAG, {
    Text = 'Select Player',
    Values = getPlayerList(),
    Default = PLACEHOLDER,
    Multi = false,
    Callback = function(Value)
        SelectedTarget = getPlayerFromSelection(Value)
        if SelectedTarget then
            Library:Notify('Target: ' .. SelectedTarget.Name, 1.5)
        else
            Library:Notify('Target cleared', 1)
        end
    end
})

-- リスト更新用関数
local function refreshPlayerDropdown(preserveSelection)
    local prevName = preserveSelection and SelectedTarget and SelectedTarget.Name or nil
    local newList = getPlayerList()

    pcall(function()
        Options[TARGET_FLAG]:Refresh(newList, true)
    end)

    task.defer(function()
        if prevName then
            local p = Players:FindFirstChild(prevName)
            if p then
                SelectedTarget = p
                pcall(function()
                    Options[TARGET_FLAG]:SetValue(getSelectionString(p))
                end)
            else
                SelectedTarget = nil
                pcall(function()
                    Options[TARGET_FLAG]:SetValue(PLACEHOLDER)
                end)
            end
        else
            SelectedTarget = nil
        end
    end)
end

-- Refresh ボタン
BlobGroup:AddButton({
    Text = '🔄 Refresh Players',
    Tooltip = 'プレイヤーリストを再取得',
    Func = function()
        refreshPlayerDropdown(true)
        Library:Notify('Player list refreshed', 1.5)
    end
})

-- プレイヤー参加時：自動更新
Players.PlayerAdded:Connect(function(p)
    task.wait(0.5)
    refreshPlayerDropdown(true)
    Library:Notify('Player joined: ' .. p.Name, 2)
end)

-- プレイヤー退出時：自動更新
Players.PlayerRemoving:Connect(function(p)
    task.wait(0.3)
    refreshPlayerDropdown(true)
end)

-- 初回：最初の他プレイヤーを自動選択（1秒後）
task.defer(function()
    task.wait(1)
    local firstPlayer = nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            firstPlayer = p
            break
        end
    end
    if firstPlayer then
        SelectedTarget = firstPlayer
        pcall(function()
            Options[TARGET_FLAG]:SetValue(getSelectionString(firstPlayer))
        end)
        Library:Notify('Auto-selected: ' .. firstPlayer.Name, 2)
    end
end)

-- =====================================================
-- Blobman Beta モジュール
-- =====================================================
local BlobmanBeta = {}

function BlobmanBeta.getLocalChar() return LocalPlayer.Character end

function BlobmanBeta.getLocalRoot()
    local char = BlobmanBeta.getLocalChar()
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
end

function BlobmanBeta.getLocalHum()
    local char = BlobmanBeta.getLocalChar()
    return char and char:FindFirstChildOfClass("Humanoid")
end

function BlobmanBeta.getInv()
    return Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
end

function BlobmanBeta.SetNetworkOwner(part)
    local root = BlobmanBeta.getLocalRoot()
    if not root or not part then return end
    pcall(function()
        RS.GrabEvents.SetNetworkOwner:FireServer(part, root.CFrame)
    end)
end

function BlobmanBeta.ungrab(part)
    if not part then return end
    pcall(function()
        RS.GrabEvents.DestroyGrabLine:FireServer(part)
    end)
end

function BlobmanBeta.getBlobman()
    local inv = BlobmanBeta.getInv()
    if inv then
        local v = inv:FindFirstChild("CreatureBlobman")
        if v and v:FindFirstChild("VehicleSeat") then return v end
    end
    local plotItems = Workspace:FindFirstChild("PlotItems")
    if plotItems then
        for _, p in ipairs(plotItems:GetChildren()) do
            local m = p:FindFirstChild("CreatureBlobman")
            if m and m:FindFirstChild("PlayerValue") and m.PlayerValue.Value == LocalPlayer.Name then
                return m
            end
        end
    end
    return nil
end

function BlobmanBeta.spawnBlobman()
    local root = BlobmanBeta.getLocalRoot()
    if not root then return nil end
    pcall(function()
        RS.MenuToys.SpawnToyRemoteFunction:InvokeServer("CreatureBlobman", root.CFrame, Vector3.zero)
    end)
    task.wait(1.0)
    return BlobmanBeta.getBlobman()
end

function BlobmanBeta.destroyBlobman()
    local blob = BlobmanBeta.getBlobman()
    if blob then
        pcall(function()
            RS.MenuToys.DestroyToy:FireServer(blob)
        end)
    end
end

function BlobmanBeta.isSittingOnBlobman()
    local hum = BlobmanBeta.getLocalHum()
    if not hum then return false end
    local blob = BlobmanBeta.getBlobman()
    if not blob or not blob:FindFirstChild("VehicleSeat") then return false end
    return hum.Sit and hum.SeatPart == blob.VehicleSeat
end

function BlobmanBeta.ensureSitBlobman()
    local blob = BlobmanBeta.getBlobman()
    if not blob or not blob:FindFirstChild("VehicleSeat") then return false end
    local seat = blob.VehicleSeat
    local hum = BlobmanBeta.getLocalHum()
    if hum and not hum.Sit then
        seat:Sit(hum)
        task.wait(0.6)
    end
    return BlobmanBeta.isSittingOnBlobman()
end

function BlobmanBeta.blobGrab(blob, target, side)
    if not blob then return end
    local detector = blob:FindFirstChild(side .. "Detector")
    if not detector then return end
    local weld = detector:FindFirstChild(side .. "Weld")
    if not weld then return end
    local script = blob:FindFirstChild("BlobmanSeatAndOwnerScript", true)
    if not script then return end
    local remote = script:FindFirstChild("CreatureGrab")
    if remote then
        pcall(function() remote:FireServer(detector, target, weld) end)
    end
end

function BlobmanBeta.blobDrop(blob, target, side)
    if not blob then return end
    local detector = blob:FindFirstChild(side .. "Detector")
    if not detector then return end
    local script = blob:FindFirstChild("BlobmanSeatAndOwnerScript", true)
    if not script then return end
    local remote = script:FindFirstChild("CreatureDrop")
    if remote then
        pcall(function() remote:FireServer(detector, target) end)
    end
end

function BlobmanBeta.blobKick(blob, targetRoot, side)
    BlobmanBeta.blobGrab(blob, BlobmanBeta.getLocalRoot(), side)
    task.wait(0.08)
    BlobmanBeta.SetNetworkOwner(targetRoot)
    task.wait(0.08)
    if targetRoot then
        targetRoot.CFrame = targetRoot.CFrame + Vector3.new(0, 16, 0)
    end
    task.wait(0.08)
    BlobmanBeta.ungrab(targetRoot)
    task.wait(0.08)
    BlobmanBeta.blobGrab(blob, targetRoot, side)
    task.wait(0.08)
    BlobmanBeta.blobDrop(blob, targetRoot, side)
    task.wait(0.08)
    BlobmanBeta.ungrab(targetRoot)
end

-- =====================================================
-- Kick 実行
-- =====================================================
local blobKickRunning = false

BlobGroup:AddButton({
    Text = '👊 Kick Selected Player',
    Tooltip = 'Blobmanを使ってターゲットをキック',
    Func = function()
        if blobKickRunning then
            Library:Notify('Already executing...', 3)
            return
        end

        if not SelectedTarget then
            Library:Notify('Please select a player first', 3)
            return
        end

        local targetPlayer = Players:FindFirstChild(SelectedTarget.Name)
        if not targetPlayer then
            Library:Notify('Player not found', 3)
            return
        end

        local targetChar = targetPlayer.Character
        if not targetChar then
            Library:Notify('Target has no character', 3)
            return
        end

        local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
        if not targetRoot then
            Library:Notify('Target has no HumanoidRootPart', 3)
            return
        end

        blobKickRunning = true
        Library:Notify('Executing kick on ' .. targetPlayer.Name .. '...', 2)

        task.spawn(function()
            local blob = BlobmanBeta.getBlobman()
            if not blob then
                blob = BlobmanBeta.spawnBlobman()
                if not blob then
                    Library:Notify('Failed to spawn Blobman', 5)
                    blobKickRunning = false
                    return
                end
            end

            if not BlobmanBeta.isSittingOnBlobman() then
                BlobmanBeta.ensureSitBlobman()
                if not BlobmanBeta.isSittingOnBlobman() then
                    Library:Notify('Not sitting on Blobman', 4)
                    blobKickRunning = false
                    return
                end
            end

            local myRoot = BlobmanBeta.getLocalRoot()
            if myRoot and targetRoot then
                local oldPos = myRoot.CFrame
                pcall(function() myRoot.CFrame = targetRoot.CFrame end)
                task.wait(0.07)
                BlobmanBeta.blobKick(blob, targetRoot, "Left")
                task.wait(0.25)
                pcall(function() myRoot.CFrame = oldPos end)
            end

            BlobmanBeta.destroyBlobman()
            Library:Notify('✔ Kicked ' .. targetPlayer.Name .. '!', 5)
            blobKickRunning = false
        end)
    end
})

-- =====================================================
-- Drift Kick（Orbit & Grab）
-- =====================================================
local DriftGroup = Tabs.Target:AddLeftGroupbox('Drift Kick')

local driftRunning = false
local driftTargetName = ""
local driftRadius = 19
local driftSpeed = 8.5
local driftHeight = 0
local driftAngle = 0
local driftCurrentLoopId = 0
local driftPlayerMap = {}
local DRIFT_PLACEHOLDER = '-- Select Player --'

local function getDriftPlayerNames()
    local names = { DRIFT_PLACEHOLDER }
    driftPlayerMap = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local displayStr = p.DisplayName .. " (@" .. p.Name .. ")"
            table.insert(names, displayStr)
            driftPlayerMap[displayStr] = p.Name
        end
    end
    return names
end

-- ドロップダウン
DriftGroup:AddDropdown('DriftTarget', {
    Text = 'Select Player (Drift)',
    Values = getDriftPlayerNames(),
    Default = DRIFT_PLACEHOLDER,
    Multi = false,
    Callback = function(Value)
        if type(Value) == "table" then Value = Value[1] end
        if Value == DRIFT_PLACEHOLDER then
            driftTargetName = ""
            Library:Notify('Drift target cleared', 1)
            return
        end
        driftTargetName = driftPlayerMap[Value] or ""
        if driftTargetName ~= "" then
            Library:Notify('Drift Target: ' .. driftTargetName, 1.5)
        end
    end
})

-- リスト更新
DriftGroup:AddButton({
    Text = '🔄 Refresh Drift List',
    Tooltip = 'ドリフトのプレイヤーリストを更新',
    Func = function()
        pcall(function()
            Options.DriftTarget:Refresh(getDriftPlayerNames(), true)
        end)
        Library:Notify('Drift list refreshed', 1.5)
    end
})

-- プレイヤー参加/退出時に自動更新
Players.PlayerAdded:Connect(function(p)
    task.wait(0.5)
    pcall(function()
        Options.DriftTarget:Refresh(getDriftPlayerNames(), false)
    end)
end)

Players.PlayerRemoving:Connect(function(p)
    task.wait(0.3)
    pcall(function()
        Options.DriftTarget:Refresh(getDriftPlayerNames(), false)
    end)
    if driftTargetName == p.Name then
        driftTargetName = ""
    end
end)

-- パラメータ調整
DriftGroup:AddSlider('DriftRadius', {
    Text = 'Orbit Radius',
    Default = 19,
    Min = 5,
    Max = 50,
    Rounding = 0,
    Tooltip = '円の半径',
    Callback = function(v)
        driftRadius = v
    end
})

DriftGroup:AddSlider('DriftSpeed', {
    Text = 'Orbit Speed',
    Default = 8.5,
    Min = 1,
    Max = 30,
    Rounding = 1,
    Tooltip = '回転速度',
    Callback = function(v)
        driftSpeed = v
    end
})

DriftGroup:AddSlider('DriftHeight', {
    Text = 'Height Offset',
    Default = 0,
    Min = -20,
    Max = 20,
    Rounding = 0,
    Tooltip = '高さオフセット（マイナスで下に）',
    Callback = function(v)
        driftHeight = v
    end
})

-- メイントグル
DriftGroup:AddToggle('DriftKickToggle', {
    Text = 'Drift Kick',
    Default = false,
    Tooltip = 'Blobmanで相手をオービットしながらキック',
    Callback = function(v)
        driftRunning = v
        driftCurrentLoopId = driftCurrentLoopId + 1
        local myLoopId = driftCurrentLoopId

        if not v then
            Library:Notify('Drift Kick: OFF', 2)
            return
        end

        -- ターゲットチェック
        if driftTargetName == "" then
            Library:Notify('Select a drift target first', 3)
            SafeSetToggle('DriftKickToggle', false)
            driftRunning = false
            return
        end

        local target = Players:FindFirstChild(driftTargetName)

        if not target or target == LocalPlayer then
            Library:Notify('Target not found', 3)
            SafeSetToggle('DriftKickToggle', false)
            driftRunning = false
            return
        end

        if not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
            Library:Notify('Target has no character', 3)
            SafeSetToggle('DriftKickToggle', false)
            driftRunning = false
            return
        end

        if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            Library:Notify('Your character not found', 3)
            SafeSetToggle('DriftKickToggle', false)
            driftRunning = false
            return
        end

        -- Blobman取得/生成
        local blobman = nil
        local spawned = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
        if spawned then
            blobman = spawned:FindFirstChild("CreatureBlobman")
        end

        if not blobman then
            local mt = RS:FindFirstChild("MenuToys")
            local st = mt and mt:FindFirstChild("SpawnToyRemoteFunction")
            if st then
                local myRoot = LocalPlayer.Character.HumanoidRootPart
                local spawnCF = myRoot and (myRoot.CFrame + Vector3.new(0, 5, 0)) or CFrame.new(0, 50, 0)
                pcall(function()
                    st:InvokeServer("CreatureBlobman", spawnCF, Vector3.zero)
                end)
                task.wait(0.8)
                spawned = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
                if spawned then
                    blobman = spawned:FindFirstChild("CreatureBlobman")
                end
            end
        end

        -- フォールバック: ワークスペース内を探す
        if not blobman then
            for _, obj in ipairs(Workspace:GetChildren()) do
                if obj.Name == "CreatureBlobman" and obj:FindFirstChild("VehicleSeat") then
                    blobman = obj
                    break
                end
            end
        end

        if not blobman then
            Library:Notify('Blobmanの取得・生成に失敗しました', 3)
            SafeSetToggle('DriftKickToggle', false)
            driftRunning = false
            return
        end

        -- 必要なオブジェクト取得
        local scriptObj = blobman:FindFirstChild("BlobmanSeatAndOwnerScript")
        local grabRemote = scriptObj and scriptObj:FindFirstChild("CreatureGrab")
        local dropRemote = scriptObj and scriptObj:FindFirstChild("CreatureDrop")

        local lDet = blobman:FindFirstChild("LeftDetector")
        local rDet = blobman:FindFirstChild("RightDetector")
        local lWeld = lDet and (lDet:FindFirstChild("LeftWeld") or lDet:FindFirstChild("RigidConstraint"))
        local rWeld = rDet and (rDet:FindFirstChild("RightWeld") or rDet:FindFirstChild("RigidConstraint"))

        local seat = blobman:FindFirstChild("VehicleSeat")
        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")

        -- 座る
        if seat and hum then
            if seat.Occupant ~= hum then
                pcall(function()
                    LocalPlayer.Character.HumanoidRootPart.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
                end)
                task.wait(0.2)
                pcall(function() seat:Sit(hum) end)
                task.wait(0.5)
            end
        end

        local GE = RS:FindFirstChild("GrabEvents")

        if not (GE and grabRemote and dropRemote and ((lDet and lWeld) or (rDet and rWeld))) then
            Library:Notify('必要なRemoteEventやDetectorが見つかりません', 5)
            SafeSetToggle('DriftKickToggle', false)
            driftRunning = false
            return
        end

        Library:Notify('Drift Kick: 開始', 3)

        -- メイン処理
        task.spawn(function()
            local blobRoot = blobman:FindFirstChild("HumanoidRootPart") or blobman.PrimaryPart
            if not blobRoot then
                Library:Notify('BlobmanRoot not found', 3)
                SafeSetToggle('DriftKickToggle', false)
                driftRunning = false
                return
            end

            local Det = rDet or lDet
            local Weld = rWeld or lWeld

            -- 初回引き寄せ
            local bringStart = tick()
            while tick() - bringStart < 0.35 do
                if myLoopId ~= driftCurrentLoopId or not driftRunning or not blobman or not blobman.Parent then
                    return
                end
                if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                    local tRoot = target.Character.HumanoidRootPart
                    blobRoot.CFrame = tRoot.CFrame
                    blobRoot.AssemblyLinearVelocity = Vector3.zero

                    pcall(function()
                        if Det then grabRemote:FireServer(Det, tRoot, Weld) end
                        GE.CreateGrabLine:FireServer(tRoot, Vector3.zero, tRoot.Position, false)
                        GE.SetNetworkOwner:FireServer(tRoot, blobRoot.CFrame)
                    end)
                end
                RunService.Heartbeat:Wait()
            end

            if not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
                return
            end

            local SavedPos = target.Character.HumanoidRootPart.CFrame
            local targetCenterCFrame = SavedPos + Vector3.new(0, 30, 0)

            local lastTime = tick()
            local lastDropTime = tick()
            local dropCount = 0

            -- メインループ
            while driftRunning and blobman and blobman.Parent do
                if myLoopId ~= driftCurrentLoopId then break end
                if not target or not target.Parent or not target.Character then break end

                local tChar = target.Character
                local tRoot = tChar:FindFirstChild("HumanoidRootPart")
                local tHum = tChar:FindFirstChild("Humanoid")

                -- 定期的にドロップ→再掴み
                if dropCount < 2 and (tick() - lastDropTime) > 0.8 then
                    dropCount = dropCount + 1

                    pcall(function()
                        local currentWeld = Det:FindFirstChild("RightWeld") or Det:FindFirstChild("LeftWeld") or Det:FindFirstChildWhichIsA("Weld") or Det:FindFirstChild("RigidConstraint")
                        if currentWeld then
                            dropRemote:FireServer(currentWeld)
                        end
                        GE.DestroyGrabLine:FireServer(tRoot)
                    end)

                    blobRoot.CFrame = SavedPos
                    blobRoot.AssemblyLinearVelocity = Vector3.zero

                    task.wait(0.1)

                    local reCaptureStart = tick()
                    while tick() - reCaptureStart < 0.35 do
                        if myLoopId ~= driftCurrentLoopId or not driftRunning or not blobman or not blobman.Parent then break end
                        if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                            local currentTRoot = target.Character.HumanoidRootPart
                            blobRoot.CFrame = currentTRoot.CFrame
                            blobRoot.AssemblyLinearVelocity = Vector3.zero

                            pcall(function()
                                if Det then grabRemote:FireServer(Det, currentTRoot, Weld) end
                                GE.CreateGrabLine:FireServer(currentTRoot, Vector3.zero, currentTRoot.Position, false)
                                GE.SetNetworkOwner:FireServer(currentTRoot, blobRoot.CFrame)
                            end)
                        end
                        RunService.Heartbeat:Wait()
                    end

                    lastTime = tick()
                    lastDropTime = tick()
                end

                if tRoot and tHum and tHum.Health > 0 and blobRoot then
                    local currentTime = tick()
                    local dt = currentTime - lastTime
                    lastTime = currentTime

                    driftAngle = driftAngle + (driftSpeed * dt)
                    local offsetX = math.cos(driftAngle) * driftRadius
                    local offsetZ = math.sin(driftAngle) * driftRadius

                    local blobPos = targetCenterCFrame.Position + Vector3.new(offsetX, driftHeight, offsetZ)
                    blobRoot.CFrame = CFrame.new(blobPos, targetCenterCFrame.Position)
                    blobRoot.AssemblyLinearVelocity = Vector3.zero
                    blobRoot.AssemblyAngularVelocity = Vector3.zero

                    tRoot.CFrame = targetCenterCFrame
                    tRoot.AssemblyLinearVelocity = Vector3.zero
                    tRoot.AssemblyAngularVelocity = Vector3.zero

                    pcall(function()
                        tHum.PlatformStand = true
                        tHum.Sit = true
                        GE.SetNetworkOwner:FireServer(tRoot, targetCenterCFrame)

                        local currentWeld = Det:FindFirstChild("RightWeld") or Det:FindFirstChild("LeftWeld") or Det:FindFirstChildWhichIsA("Weld") or Det:FindFirstChild("RigidConstraint")
                        if currentWeld then
                            dropRemote:FireServer(currentWeld)
                        end

                        GE.DestroyGrabLine:FireServer(tRoot)
                        if Det then grabRemote:FireServer(Det, tRoot, Weld) end
                        GE.CreateGrabLine:FireServer(tRoot, Vector3.zero, targetCenterCFrame.Position, false)
                    end)
                else
                    break
                end
                RunService.Heartbeat:Wait()
            end

            -- 終了処理
            if blobRoot and SavedPos then
                pcall(function()
                    local currentWeld = Det:FindFirstChild("RightWeld") or Det:FindFirstChild("LeftWeld") or Det:FindFirstChildWhichIsA("Weld") or Det:FindFirstChild("RigidConstraint")
                    if currentWeld then
                        dropRemote:FireServer(currentWeld)
                    end
                    if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                        GE.DestroyGrabLine:FireServer(target.Character.HumanoidRootPart)
                    end
                end)
                blobRoot.CFrame = SavedPos
                blobRoot.AssemblyLinearVelocity = Vector3.zero
            end

            Library:Notify('Drift Kick: 終了', 2)
        end)
    end
})

-- =====================================================
-- Info グループ（ステータス表示）
-- =====================================================
local statusLabel = InfoGroup:AddLabel('Status: Idle')
local targetLabel = InfoGroup:AddLabel('Target: None')

-- ステータスを定期的に更新
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            local status = blobKickRunning and 'Executing...' or 'Idle'
            local tgt = SelectedTarget and SelectedTarget.Name or 'None'
            statusLabel:SetText('Status: ' .. status)
            targetLabel:SetText('Target: ' .. tgt)
        end)
    end
end)

-- =====================================================
-- Misc タブ
-- =====================================================
local MiscLeft = Tabs.Misc:AddLeftGroupbox('Fun')
local MiscRight = Tabs.Misc:AddRightGroupbox('Camera')

-- =====================================================
-- Coconut Penis (FanGroup)
-- =====================================================
_G.CoconutOrbitEnabled = false

MiscLeft:AddToggle('CoconutOrbit', {
    Text = 'Coconut Penis',
    Default = false,
    Tooltip = 'ココナッツを体にまとわりつかせます',
    Callback = function(Value)
        _G.CoconutOrbitEnabled = Value

        if Value then
            task.spawn(function()
                local Me = LocalPlayer
                local RunService = game:GetService("RunService")
                local RepS = game:GetService("ReplicatedStorage")

                local GrabEvents = RepS:FindFirstChild("GrabEvents")
                local MenuToys = RepS:FindFirstChild("MenuToys")
                if not GrabEvents or not MenuToys then
                    Library:Notify('GrabEvents or MenuToys not found', 3)
                    _G.CoconutOrbitEnabled = false
                    Toggles.CoconutOrbit:SetValue(false)
                    return
                end

                local SetNetworkOwner = GrabEvents:FindFirstChild("SetNetworkOwner")
                local SpawnToy = MenuToys:FindFirstChild("SpawnToyRemoteFunction")
                local DestroyToy = MenuToys:FindFirstChild("DestroyToy")

                if not SetNetworkOwner or not SpawnToy or not DestroyToy then
                    Library:Notify('Required remotes not found', 3)
                    _G.CoconutOrbitEnabled = false
                    Toggles.CoconutOrbit:SetValue(false)
                    return
                end

                local Offsets = {
                    [1] = CFrame.new(-0.45, -1.2, -0.7),
                    [2] = CFrame.new(0.45, -1.2, -0.7),
                    [3] = CFrame.new(0, -1, 0.8)
                }

                local Length = 10

                while _G.CoconutOrbitEnabled do
                    local Char = Me.Character
                    local Root = Char and Char:FindFirstChild("HumanoidRootPart")

                    if not Root then
                        task.wait(0.1)
                        continue
                    end

                    local inv = workspace:FindFirstChild(Me.Name .. "SpawnedInToys")
                    if not inv then
                        task.wait(0.1)
                        continue
                    end

                    local Coconuts = {}
                    for _, toy in pairs(inv:GetChildren()) do
                        if toy.Name == "FoodCoconut" then
                            table.insert(Coconuts, toy)
                        end
                    end

                    if #Coconuts < (Length + 2) then
                        task.spawn(function()
                            pcall(function()
                                SpawnToy:InvokeServer(
                                    "FoodCoconut",
                                    Root.CFrame * CFrame.new(-5, 0, 10),
                                    Vector3.zero
                                )
                            end)
                        end)
                    end

                    for i, Coco in ipairs(Coconuts) do
                        local Part = Coco:FindFirstChild("SoundPart")
                        local HoldPart = Coco:FindFirstChild("HoldPart")
                        local Rigid = HoldPart and HoldPart:FindFirstChild("RigidConstraint")
                        local PartOwner = Part and Part:FindFirstChild("PartOwner")

                        if Part and HoldPart and Rigid then
                            if PartOwner and PartOwner.Value == Me.Name then
                                if i <= 2 then
                                    Part.CFrame = Root.CFrame
                                        * Offsets[i]
                                        * CFrame.new(Root.Velocity / 100)
                                else
                                    Part.CFrame = Root.CFrame
                                        * Offsets[3]
                                        * CFrame.new(Root.Velocity / 100)
                                        * CFrame.new(0, 0, Offsets[3].Z - (i + 0.2))
                                end

                                Part.Velocity = Vector3.zero
                            end

                            if not PartOwner or PartOwner.Value ~= Me.Name then
                                pcall(function()
                                    SetNetworkOwner:FireServer(Part, Part.CFrame)
                                end)
                            end

                            if Rigid.Attachment1 then
                                pcall(function()
                                    DestroyToy:FireServer(Coco)
                                end)
                            end

                            for _, part in pairs(Coco:GetChildren()) do
                                if part:IsA("BasePart") then
                                    part.CanCollide = false
                                    part.CanQuery = false
                                    if part.Transparency ~= 1 then
                                        part.Transparency = 0
                                    end
                                end
                            end
                        end
                    end

                    task.wait(0.01)
                end
            end)
            Library:Notify('Coconut Penis: Enabled', 2)
        else
            Library:Notify('Coconut Penis: Disabled', 2)
        end
    end
})

-- =====================================================
-- FOV スライダー
-- =====================================================
MiscRight:AddSlider('FOV', {
    Text = 'FOV',
    Default = 90,
    Min = 1,
    Max = 120,
    Rounding = 0,
    Suffix = '°',
    Callback = function(value)
        game.Workspace.CurrentCamera.FieldOfView = value
    end
})

-- =====================================================
-- Player タブ
-- =====================================================
local PlayerView = Tabs.Player:AddLeftGroupbox('View')
local PlayerMove = Tabs.Player:AddRightGroupbox('Movement')

-- =====================================================
-- 3rd Person View
-- =====================================================
local function enableThirdPerson()
    Player.CameraMode = Enum.CameraMode.Classic
    Camera.CameraType = Enum.CameraType.Custom
    if Player.Character then
        Camera.CameraSubject = Player.Character:WaitForChild("Humanoid", 5)
    end
    Player.CameraMaxZoomDistance = 16456456546
    Player.CameraMinZoomDistance = 0.5
end

local function disableThirdPerson()
    Player.CameraMode = Enum.CameraMode.LockFirstPerson
    Camera.CameraType = Enum.CameraType.Custom
    if Player.Character then
        Camera.CameraSubject = Player.Character:WaitForChild("Humanoid", 5)
    end
    Player.CameraMaxZoomDistance = 0
    Player.CameraMinZoomDistance = 0
end

PlayerView:AddToggle('ThirdPersonView', {
    Text = '3rd Person View',
    Default = false,
    Tooltip = '三人称視点を強制的に有効化',
    Callback = function(Value)
        if Value then
            enableThirdPerson()
        else
            disableThirdPerson()
        end
    end
})

-- =====================================================
-- Walk Speed (CFrame)
-- =====================================================
local PL_SpeedEnabled = false
local PL_SpeedValue = 16
local PL_SpeedConn = nil

PlayerMove:AddInput('WalkSpeedInput', {
    Text = 'Walk Speed',
    Default = '16',
    Placeholder = 'e.g. 16',
    Numeric = true,
    Finished = false,
    Callback = function(v)
        local n = tonumber(v)
        if n then PL_SpeedValue = n end
    end
})

PlayerMove:AddToggle('EnableSpeedCFrame', {
    Text = 'Enable Speed (CFrame)',
    Default = false,
    Tooltip = 'CFrameで直接移動速度を変更',
    Callback = function(Value)
        PL_SpeedEnabled = Value
        if Value then
            if PL_SpeedConn then PL_SpeedConn:Disconnect() end
            PL_SpeedConn = RunService.RenderStepped:Connect(function()
                if not PL_SpeedEnabled then return end
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChild("Humanoid")
                if hrp and hum then
                    pcall(function()
                        hrp.CFrame = hrp.CFrame + hum.MoveDirection * (PL_SpeedValue * 0.1)
                    end)
                end
            end)
        else
            if PL_SpeedConn then
                PL_SpeedConn:Disconnect()
                PL_SpeedConn = nil
            end
        end
    end,
})

-- =====================================================
-- Water Walk
-- =====================================================
PlayerMove:AddToggle('WaterWalk', {
    Text = 'Water Walk',
    Default = false,
    Tooltip = '海の上を歩けるようにします',
    Callback = function(v)
        -- workspace.Map 以下を安全に取得
        local map = Workspace:FindFirstChild("Map")
        local alwaysHere = map and map:FindFirstChild("AlwaysHereTweenedObjects")
        local ocean = alwaysHere and alwaysHere:FindFirstChild("Ocean")
        local obj = ocean and ocean:FindFirstChild("Object")
        local objModel = obj and obj:FindFirstChild("ObjectModel")

        if not objModel then
            Library:Notify('Ocean ObjectModel not found', 3)
            return
        end

        for _, vv in pairs(objModel:GetChildren()) do
            if vv.Name == "Ocean" then
                vv.CanCollide = v
            end
        end
    end
})

-- =====================================================
-- UI Settings タブ
-- =====================================================
local MenuGroup = Tabs.Settings:AddLeftGroupbox('Menu')

MenuGroup:AddButton('Unload', function()
    -- Lag系停止
    stopLineLag()
    _G.PacketLagActive = false
    _G.MonsterLagEnabled = false

    -- Misc系停止
    _G.CoconutOrbitEnabled = false

    -- Player系停止
    if PL_SpeedConn then PL_SpeedConn:Disconnect() PL_SpeedConn = nil end
    PL_SpeedEnabled = false

    -- Grab系停止
    if strengthConnection then strengthConnection:Disconnect() strengthConnection = nil end
    killGrabEnabled = false
    if killGrabConn then killGrabConn:Disconnect() killGrabConn = nil end

        -- Target系停止（Blobman Kick）
    blobKickRunning = false
    pcall(function() BlobmanBeta.destroyBlobman() end)

        -- Drift Kick 停止
    driftRunning = false
    driftCurrentLoopId = driftCurrentLoopId + 1

    -- カメラ戻す
    game.Workspace.CurrentCamera.FieldOfView = 70
    Player.CameraMode = Enum.CameraMode.Classic
    Player.CameraMaxZoomDistance = 128
    Player.CameraMinZoomDistance = 0.5

    Library:Unload()
end)

MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', {
    Default = 'RightShift',
    NoUI = true,
    Text = 'Menu keybind'
})

Library.ToggleKeybind = Options.MenuKeybind

-- ThemeManager & SaveManager
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })

ThemeManager:SetFolder('OrynHUB')
SaveManager:SetFolder('OrynHUB/Configs')

SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

SaveManager:LoadAutoloadConfig()

-- ウォーターマーク
Library:SetWatermark('Oryn HUB | LinoriaLib')

print('⚡ Oryn HUB Loaded! (LinoriaLib)')