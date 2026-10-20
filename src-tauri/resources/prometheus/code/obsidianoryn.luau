local repo = 'https://raw.githubusercontent.com/deividcomsono/Obsidian/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Options = Library.Options
local Toggles = Library.Toggles

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
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

_G.cons = _G.cons or {}
_G.ShurikenAntiKick = false
_G.LineLagPacketCount = 10

--  Unload 用 グローバル状態管理 

_G.OrynState = _G.OrynState or {
    connections = {},       -- 全 Disconnect すべき Connection
    instances = {},         -- 全 Destroy すべき Instance
    threads = {},           -- 全 cancel すべき thread
    flags = {},             -- 全 ON/OFF フラグ
    originals = {},         -- 元の値の保存（WalkSpeed等）
}

local function trackConn(conn)
    table.insert(_G.OrynState.connections, conn)
    return conn
end

local function trackInst(inst)
    table.insert(_G.OrynState.instances, inst)
    return inst
end

local function trackThread(thread)
    table.insert(_G.OrynState.threads, thread)
    return thread
end

local Window = Library:CreateWindow({
    Title = 'Oryn HUB',
    SubTitle = 'SKIDW',
    Footer = 'FTAP | V1.0',
    Icon = 'rbxassetid://84899256315962',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2,
    ShowCustomCursor = true,
})

local Tabs = {
    Main     = Window:AddTab('Lag',         'zap'),      
    Defense  = Window:AddTab('Defense',     'shield'), 
    Grab     = Window:AddTab('Grab',        'hand'),
    Target   = Window:AddTab('Target',      'crosshair'),
    ESP      = Window:AddTab('ESP',         'eye'), 
    Misc     = Window:AddTab('Misc',        'settings'), 
    Player   = Window:AddTab('Player',      'user'), 
    Settings = Window:AddTab('UI Settings', 'settings-2'), 
}

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

-- LagKick タブ

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

-- Packet Spam

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
                local Players = game:GetService("Players")
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Name == "MaybeFlashh" then
                        Library:Notify("Safety Alert: MaybeFlashh detected. Packet lag disabled for safety.", 5)
                        _G.PacketLagActive = false
                        Toggles.PacketLagActive:SetValue(false)
                        return
                    end
                end

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
                            if i % 100 == 0 then task.wait() end
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

-- Monster Lag

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

local DefenseLeft = Tabs.Defense:AddLeftGroupbox('Basic Defense')
local DefenseRight = Tabs.Defense:AddRightGroupbox('Extra Defense')

-- Anti Grab
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

-- Anti Lag

do
    local antiLagActive = false
    local autoAntiLag = true
    local antiLagSens = 3

    local function applyAntiLag(antiLag_)
        antiLagActive = antiLag_
        local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
        local characterAndBeamMove = playerScripts and playerScripts:FindFirstChild("CharacterAndBeamMove")
        local stickyPartsTouchDetection = playerScripts and playerScripts:FindFirstChild("StickyPartsTouchDetection")

        if characterAndBeamMove then
            characterAndBeamMove.Enabled = not antiLag_
        end

        if stickyPartsTouchDetection then
            stickyPartsTouchDetection.Enabled = not antiLag_
        end

        if antiLag_ then
            task.delay(1.5, function()
                for _, player in ipairs(Players:GetPlayers()) do
                    local character = player.Character

                    if character then
                        for _, child in ipairs(character:GetChildren()) do
                            if child.Name == "GrabParts" then
                                pcall(function() child:Destroy() end)
                            end
                        end
                    end
                end
            end)
        end
    end

    DefenseRight:AddToggle('AntiLagFull', {
        Text = 'Anti Lag (Line/Shuriken)',
        Default = false,
        Tooltip = 'Anti Line-Lag / Shuriken-Lag',
        Callback = applyAntiLag,
    })

    DefenseRight:AddToggle('AutoAntiLagFull', {
        Text = 'Auto Anti Lag',
        Default = true,
        Tooltip = 'FPSが低い時に自動でAnti Lagを有効化',
        Callback = function(v)
            autoAntiLag = v
        end,
    })

    DefenseRight:AddSlider('AntiLagSensFull', {
        Text = 'Auto Anti-Lag Sensitivity',
        Default = 3, Min = 1, Max = 20, Rounding = 0, Suffix = 'FPS',
        Callback = function(v)
            antiLagSens = v
        end,
    })

    local lastCheck = 0
    RunService.RenderStepped:Connect(function(deltaTime)
        if not autoAntiLag then return end
        if os.clock() - lastCheck < 2.5 then return end
        if deltaTime <= 0 then return end
        lastCheck = os.clock()

        local fps = math.floor(1 / deltaTime)
        if fps < antiLagSens and not antiLagActive then
            Library:Notify('Auto Anti Lag: Enabled (FPS ' .. fps .. ')', 3)
            pcall(function() Toggles.AntiLagFull:SetValue(true) end)
        end
    end)
end

-- Anti Kick (Shuriken)

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

-- Anti Kick [ITEM]

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

-- Super Strength

do
    local SuperStrengthGroup = Tabs.Grab:AddLeftGroupbox('Super Strength')

    local superStrengthEnabled = false
    local strengthValue = 5000
    local mobileTriggered = false

    local textButton = Instance.new("TextButton")
    textButton.BackgroundTransparency = 1
    textButton.Text = ""
    textButton.Active = false
    textButton.Visible = false

    -- モバイル用：Throw ボタン位置に透明ボタンを重ねる
    local function setupThrowButton()
        task.spawn(function()
            local playerGui2 = LocalPlayer:WaitForChild("PlayerGui", 5)
            playerGui2 = playerGui2 and playerGui2:WaitForChild("ContextActionGui", 5)
            playerGui2 = playerGui2 and playerGui2:WaitForChild("ContextButtonFrame", 5)
            if not playerGui2 then return end
            local connection3 = nil

            local function checkAndMove(arg)
                if arg:IsA("ImageLabel") and arg.Image == "rbxassetid://9603669631" then
                    if arg.Parent and arg.Parent:IsA("GuiObject") then
                        textButton.Parent = arg.Parent
                        textButton.Position = UDim2.new(0, 0, 0, 0)
                        textButton.Size = UDim2.new(1, 0, 1, 0)
                        return true
                    end
                end
                return false
            end

            for _, descendant in ipairs(playerGui2:GetDescendants()) do
                if checkAndMove(descendant) then return end
            end

            connection3 = playerGui2.DescendantAdded:Connect(function(descendant)
                if checkAndMove(descendant) then
                    if connection3 then connection3:Disconnect() end
                end
            end)
        end)
    end

    setupThrowButton()

    textButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            if textButton.Visible then
                mobileTriggered = true
                task.delay(0.5, function() mobileTriggered = false end)
            end
        end
    end)

    SuperStrengthGroup:AddToggle('SuperStrengthGrab', {
        Text = 'Super Strength',
        Default = false,
        Tooltip = '掴んだオブジェクトを右クリック/タッチで投擲',
        Callback = function(v)
            superStrengthEnabled = v
            textButton.Visible = v
        end,
    })

    SuperStrengthGroup:AddSlider('StrengthValue', {
        Text = 'Strength',
        Default = 5000, Min = 10, Max = 10000, Rounding = 0,
        Callback = function(v) strengthValue = v end,
    })

    -- GrabParts が消えた瞬間に速度を付与
    Workspace.ChildAdded:Connect(function(child)
        if child.Name ~= "GrabParts" then return end
        if not superStrengthEnabled then return end

        task.spawn(function()
            local grabPart = child:WaitForChild("GrabPart", 5)
            if not (grabPart and grabPart:FindFirstChild("WeldConstraint")) then return end
            local part1 = grabPart.WeldConstraint.Part1
            if not part1 then return end

            local bodyVelocity = Instance.new("BodyVelocity", part1)
            bodyVelocity.MaxForce = Vector3.zero
            bodyVelocity.Velocity = Vector3.new()
            bodyVelocity.Name = "SuperStrength"

            local connection3 = nil
            connection3 = child:GetPropertyChangedSignal("Parent"):Connect(function()
                if not child.Parent then
                    local lastInput = UserInputService:GetLastInputType()
                    local isMB2 = lastInput == Enum.UserInputType.MouseButton2
                    local isMB1 = lastInput == Enum.UserInputType.MouseButton1
                    local isTouch = lastInput == Enum.UserInputType.Touch

                    if isMB2 or (isTouch and mobileTriggered) then
                        bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                        bodyVelocity.Velocity = Workspace.CurrentCamera.CFrame.LookVector * strengthValue
                        Debris:AddItem(bodyVelocity, 1)
                    elseif isMB1 and not mobileTriggered then
                        bodyVelocity:Destroy()
                    end

                    if connection3 then connection3:Disconnect() end
                end
            end)
        end)
    end)
end

-- Grab Mode

do
    local GrabModeGroup = Tabs.Grab:AddLeftGroupbox('Grab Mode')

    local grabModes = {
        ["Kill Grab"] = false,
        ["Sky Grab"] = false,
        ["Spin Grab"] = false,
        ["Teleport Up"] = false,
        ["Teleport Down"] = false,
        ["Chaos Grab"] = false,
        ["Supersonic Grab"] = false,
        ["Freeze Grab"] = false,
        ["Noclip Grab"] = false,
    }

    local function handleKillGrab(arg)
        pcall(function()
            local grabPart = arg:FindFirstChild("GrabPart")
            local weldConstraint = grabPart and grabPart:FindFirstChild("WeldConstraint")
            if weldConstraint and weldConstraint.Part1 then
                weldConstraint.Part1.Parent:BreakJoints()
            end
        end)
    end

    local function handleSkyGrab(arg)
        pcall(function()
            local grabPart = arg:FindFirstChild("GrabPart")
            if grabPart and grabPart:FindFirstChild("WeldConstraint") then
                local bv = Instance.new("BodyVelocity")
                bv.Velocity = Vector3.new(0, 100, 0)
                bv.MaxForce = Vector3.new(0, math.huge, 0)
                bv.Parent = grabPart
            end
        end)
    end

    local function handleSpinGrab(arg)
        pcall(function()
            local grabPart = arg:FindFirstChild("GrabPart")
            grabPart = grabPart and grabPart:FindFirstChild("WeldConstraint")
            if grabPart and grabPart.Part1 then
                local bav = Instance.new("BodyAngularVelocity")
                bav.AngularVelocity = Vector3.new(0, 1000, 0)
                bav.MaxTorque = Vector3.new(0, math.huge, 0)
                bav.Parent = grabPart.Part1
                for _, child in ipairs(arg:GetChildren()) do
                    child:Destroy()
                end
            end
        end)
    end

    local function handleTeleport(arg, dir)
        pcall(function()
            local grabPart = arg:FindFirstChild("GrabPart")
            if grabPart then
                grabPart.Position = grabPart.Position + Vector3.new(0, dir == "up" and 30 or -30, 0)
            end
        end)
    end

    local function handleChaosGrab(arg, isActive)
        pcall(function()
            local grabPart = arg:FindFirstChild("GrabPart")
            if not grabPart then return end
            local bp = Instance.new("BodyPosition")
            bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bp.Parent = grabPart
            local bg = Instance.new("BodyGyro")
            bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bg.Parent = grabPart

            task.spawn(function()
                while isActive() do
                    pcall(function()
                        bp.Position = grabPart.Position + Vector3.new(
                            math.random(-50, 50),
                            math.random(-50, 50),
                            math.random(-50, 50)
                        )
                        bg.CFrame = CFrame.Angles(
                            math.rad(math.random(-180, 180)),
                            math.rad(math.random(-180, 180)),
                            math.rad(math.random(-180, 180))
                        )
                    end)
                    task.wait(0.1)
                end
                bp:Destroy()
                bg:Destroy()
            end)
        end)
    end

    local function handleSupersonicGrab(arg)
        pcall(function()
            local grabPart = arg:FindFirstChild("GrabPart")
            if grabPart then
                local bv = Instance.new("BodyVelocity")
                bv.Velocity = Vector3.new(0, 350, 0)
                bv.MaxForce = Vector3.new(0, math.huge, 0)
                bv.Parent = grabPart
            end
        end)
    end

    local function handleFreezeGrab(arg)
        pcall(function()
            local grabPart = arg:FindFirstChild("GrabPart")
            if grabPart then
                local bp = Instance.new("BodyPosition")
                bp.Position = grabPart.Position
                bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bp.Parent = grabPart
            end
        end)
    end

    local function handleNoclipGrab(arg)
        pcall(function()
            if arg:FindFirstChild("GrabPart") then
                for _, descendant in pairs(arg:GetDescendants()) do
                    if descendant:IsA("BasePart") then
                        descendant.CanCollide = false
                    end
                end
            end
        end)
    end

    for name in pairs(grabModes) do
        GrabModeGroup:AddToggle('Grab_' .. name, {
            Text = name,
            Default = false,
            Callback = function(v)
                grabModes[name] = v
            end,
        })
    end

    Workspace.ChildAdded:Connect(function(child)
        if child.Name ~= "GrabParts" then return end
        if grabModes["Kill Grab"] then handleKillGrab(child) end
        if grabModes["Sky Grab"] then handleSkyGrab(child) end
        if grabModes["Spin Grab"] then handleSpinGrab(child) end
        if grabModes["Teleport Up"] then handleTeleport(child, "up") end
        if grabModes["Teleport Down"] then handleTeleport(child, "down") end
        if grabModes["Chaos Grab"] then handleChaosGrab(child, function() return grabModes["Chaos Grab"] end) end
        if grabModes["Supersonic Grab"] then handleSupersonicGrab(child) end
        if grabModes["Freeze Grab"] then handleFreezeGrab(child) end
        if grabModes["Noclip Grab"] then handleNoclipGrab(child) end
    end)
end

-- Line Colors

do
    local LineColorsGroup = Tabs.Grab:AddRightGroupbox('Line Colors')

    local lineColors = {
        Color3.fromRGB(255, 0, 0),
        Color3.fromRGB(0, 0, 255),
        Color3.fromRGB(0, 255, 0),
        Color3.fromRGB(255, 255, 0),
        Color3.fromRGB(255, 0, 255),
        Color3.fromRGB(0, 255, 255),
    }

    for i = 1, 6 do
        local idx = i
        LineColorsGroup:AddLabel('Line Color ' .. idx):AddColorPicker('LineColor' .. idx, {
            Text = 'LineColor ' .. idx,
            Default = lineColors[idx],
            Callback = function(c)
                lineColors[idx] = c
            end,
        })
    end

    LineColorsGroup:AddButton({
        Text = 'Apply Line Color',
        Func = function()
            local keypoints = {}
            for i = 1, 6 do
                table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / 5, lineColors[i]))
            end
            pcall(function()
                RS.DataEvents.UpdateLineColorsEvent:FireServer(ColorSequence.new(keypoints))
            end)
            Library:Notify('Line Colors Applied', 2)
        end,
    })
end

-- Line Extend (Infinite Extend)

do
    local LineExtendGroup = Tabs.Grab:AddRightGroupbox('Line Extend')

    local furtherExtendEnabled = false
    local increaseLineExtend = 3
    local currentMouseDistance = 0
    local currentGrabParts = nil

    -- UI付属ボタン（モバイル用 +/-）
    local screenGui = Instance.new("ScreenGui")
    screenGui.ResetOnSpawn = false
    screenGui.Name = "OrynFurtherExtendGUI"

    if UserInputService.TouchEnabled then
        screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    local btnUp = Instance.new("ImageButton")
    btnUp.Size = UDim2.new(0, 45, 0, 45)
    btnUp.Position = UDim2.new(1, -70, 1, -259)
    btnUp.Image = "rbxassetid://97166444"
    btnUp.BackgroundTransparency = 1
    btnUp.ImageTransparency = 1
    btnUp.Visible = false
    btnUp.ImageColor3 = Color3.fromRGB(142, 142, 142)
    btnUp.Parent = screenGui

    local btnUpLabel = Instance.new("ImageLabel")
    btnUpLabel.Size = UDim2.new(1, 0, 1, 0)
    btnUpLabel.Image = "rbxassetid://9603831913"
    btnUpLabel.BackgroundTransparency = 1
    btnUpLabel.Visible = false
    btnUpLabel.Parent = btnUp

    local btnDown = Instance.new("ImageButton")
    btnDown.Size = UDim2.new(0, 45, 0, 45)
    btnDown.Position = UDim2.new(1, -70, 1, -211)
    btnDown.Image = "rbxassetid://97166444"
    btnDown.BackgroundTransparency = 1
    btnDown.ImageTransparency = 1
    btnDown.Visible = false
    btnDown.ImageColor3 = Color3.fromRGB(142, 142, 142)
    btnDown.Parent = screenGui

    local btnDownLabel = Instance.new("ImageLabel")
    btnDownLabel.Size = UDim2.new(1, 0, 1, 0)
    btnDownLabel.Image = "rbxassetid://9603826756"
    btnDownLabel.BackgroundTransparency = 1
    btnDownLabel.Visible = false
    btnDownLabel.Parent = btnDown

    local function toggleButtons(v)
        btnUp.Visible = v
        btnUp.Active = v
        btnDown.Visible = v
        btnDown.Active = v
    end

    local function setupAutoPosition(btn, imageId)
        task.spawn(function()
            local playerGui2 = LocalPlayer:WaitForChild("PlayerGui", 5)
            playerGui2 = playerGui2 and playerGui2:WaitForChild("ContextActionGui", 5)
            playerGui2 = playerGui2 and playerGui2:WaitForChild("ContextButtonFrame", 5)
            if not playerGui2 then return end
            local connection3 = nil

            local function checkAndMove(arg)
                if arg:IsA("ImageLabel") and arg.Image == imageId then
                    if arg.Parent and arg.Parent:IsA("GuiObject") then
                        btn.Parent = arg.Parent
                        btn.Position = UDim2.new(0, 0, 0, 0)
                        btn.Size = UDim2.new(1, 0, 1, 0)
                        return true
                    end
                end
                return false
            end

            for _, descendant in ipairs(playerGui2:GetDescendants()) do
                if checkAndMove(descendant) then return end
            end

            connection3 = playerGui2.DescendantAdded:Connect(function(descendant)
                if checkAndMove(descendant) then
                    if connection3 then connection3:Disconnect() end
                end
            end)
        end)
    end

    setupAutoPosition(btnUp, "rbxassetid://9603831913")
    setupAutoPosition(btnDown, "rbxassetid://9603826756")

    -- GrabParts監視
    Workspace.ChildAdded:Connect(function(child)
        if child.Name == "GrabParts" and child:IsA("Model") and furtherExtendEnabled then
            if UserInputService.MouseEnabled then
                local grabParts = child
                currentGrabParts = grabParts

                pcall(function()
                    grabParts:WaitForChild("GrabPart")
                    grabParts:WaitForChild("DragPart")

                    local bodyPosition = Instance.new("BodyPosition", grabParts.GrabPart)
                    bodyPosition.MaxForce = Vector3.new(275000, 275000, 275000)
                    bodyPosition.P = 20000
                    bodyPosition.D = 950
                    bodyPosition.Position = grabParts.GrabPart.WeldConstraint.Part1.Position
                    currentMouseDistance = (grabParts.GrabPart.Position - Camera.CFrame.Position).Magnitude
                    grabParts.DragPart.AlignPosition.Enabled = false

                    task.spawn(function()
                        while grabParts.Parent do
                            bodyPosition.Position = Camera.CFrame.Position + Camera.CFrame.LookVector * currentMouseDistance
                            task.wait()
                        end
                        currentMouseDistance = 0
                        bodyPosition:Destroy()
                    end)
                end)
            end
            toggleButtons(true)
        end
    end)

    Workspace.ChildRemoved:Connect(function(child)
        if child.Name == "GrabParts" and child:IsA("Model") then
            currentGrabParts = nil
            toggleButtons(false)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseWheel and furtherExtendEnabled then
            if currentMouseDistance < 11 then currentMouseDistance = 11 end
            if input.Position.Z <= 0 then
                if input.Position.Z < 0 then
                    currentMouseDistance -= increaseLineExtend
                end
            else
                currentMouseDistance += increaseLineExtend
            end
        end
    end)

    -- モバイル +/- 長押し
    local btnHeld = false
    local btnIsUp = false

    local function continuousAdjust()
        while btnHeld do
            if currentMouseDistance < 11 then currentMouseDistance = 11 end
            if btnIsUp then
                currentMouseDistance += increaseLineExtend
            else
                currentMouseDistance -= increaseLineExtend
            end
            task.wait(0.1)
        end
    end

    btnUp.InputBegan:Connect(function(input, gp)
        if not gp and input.UserInputType == Enum.UserInputType.Touch then
            btnHeld = true
            btnIsUp = true
            task.spawn(continuousAdjust)
        end
    end)
    btnUp.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then btnHeld = false end
    end)

    btnDown.InputBegan:Connect(function(input, gp)
        if not gp and input.UserInputType == Enum.UserInputType.Touch then
            btnHeld = true
            btnIsUp = false
            task.spawn(continuousAdjust)
        end
    end)
    btnDown.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then btnHeld = false end
    end)

    LineExtendGroup:AddToggle('InfiniteLineExtend', {
        Text = 'Infinity Extend Line',
        Default = false,
        Tooltip = 'GrabLineを無限に延長（マウスホイール / モバイルボタンで調整）',
        Callback = function(v)
            furtherExtendEnabled = v
            toggleButtons(v)
        end,
    })

    LineExtendGroup:AddSlider('ExtendSpeed', {
        Text = 'Speed',
        Default = 3, Min = 3, Max = 25, Rounding = 0,
        Callback = function(v) increaseLineExtend = v end,
    })

    LineExtendGroup:AddLabel('Mobile / Pc Supported')
end


-- Target タブ 

local BlobGroup = Tabs.Target:AddLeftGroupbox('Blobman Kick')
local InfoGroup = Tabs.Target:AddRightGroupbox('Info')

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

BlobGroup:AddButton({
    Text = 'Refresh Players',
    Tooltip = 'プレイヤーリストを再取得',
    Func = function()
        refreshPlayerDropdown(true)
        Library:Notify('Player list refreshed', 1.5)
    end
})

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

-- Blobman Beta モジュール
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

local blobKickRunning = false

BlobGroup:AddButton({
    Text = 'Kick Selected Player',
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


-- Drift Kick

local DriftGroup = Tabs.Target:AddLeftGroupbox('Drift Kick')

local driftRunning = false
local driftTargetName = ""
local driftRadius = 19
local driftSpeed = 12
local driftHeightOffset = 0
local driftCenterHeight = 30
local driftGrabCount = 2
local driftGrabInterval = 0.8
local driftAngle = 0
local driftCurrentLoopId = 0
local driftPlayerMap = {}
local DRIFT_PLACEHOLDER = '-- Select Drift Target --'

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

DriftGroup:AddDropdown('DriftTarget', {
    Text = 'ターゲット選択',
    Values = getDriftPlayerNames(),
    Default = DRIFT_PLACEHOLDER,
    Multi = false,
    Callback = function(Value)
        if type(Value) == "table" then Value = Value[1] end
        if Value == DRIFT_PLACEHOLDER then
            driftTargetName = ""
            Library:Notify('Drift ターゲット解除', 1.5)
            return
        end
        driftTargetName = driftPlayerMap[Value] or ""
        if driftTargetName ~= "" then
            Library:Notify('Drift ターゲット: ' .. driftTargetName, 1.5)
        end
    end
})

DriftGroup:AddButton({
    Text = 'Refresh Drift List',
    Func = function()
        pcall(function() Options.DriftTarget:Refresh(getDriftPlayerNames(), true) end)
        Library:Notify('Drift リスト更新完了', 1.5)
    end
})

DriftGroup:AddSlider('DriftRadius', {
    Text = '幅 (半径)', Default = 19, Min = 1, Max = 100, Rounding = 0, Suffix = 'studs',
    Callback = function(v) driftRadius = v end
})

DriftGroup:AddSlider('DriftSpeed', {
    Text = 'まわる速さ', Default = 12, Min = 0.1, Max = 100, Rounding = 1,
    Callback = function(v) driftSpeed = v end
})

DriftGroup:AddSlider('DriftHeightOffset', {
    Text = '高さ (上下オフセット)', Default = 0, Min = -50, Max = 100, Rounding = 0, Suffix = 'studs',
    Callback = function(v) driftHeightOffset = v end
})

DriftGroup:AddSlider('DriftCenterHeight', {
    Text = '中心の高さ (ターゲットから)', Default = 30, Min = 0, Max = 100, Rounding = 0, Suffix = 'studs',
    Callback = function(v) driftCenterHeight = v end
})

DriftGroup:AddSlider('DriftGrabCount', {
    Text = '掴む量 (ドロップ回数)', Default = 2, Min = 1, Max = 20, Rounding = 0, Suffix = '回',
    Callback = function(v) driftGrabCount = v end
})

DriftGroup:AddSlider('DriftGrabInterval', {
    Text = '掴み直し間隔', Default = 0.8, Min = 0.1, Max = 5, Rounding = 2, Suffix = '秒',
    Callback = function(v) driftGrabInterval = v end
})

DriftGroup:AddToggle('DriftKickToggle', {
    Text = 'Drift Kick',
    Default = false,
    Tooltip = 'Blobmanで相手を掴みながらドリフト旋回',
    Callback = function(v)
        driftRunning = v
        driftCurrentLoopId = driftCurrentLoopId + 1
        local myLoopId = driftCurrentLoopId

        if not v then
            Library:Notify('Drift Kick: OFF', 2)
            return
        end

        if driftTargetName == "" then
            Library:Notify('ターゲットを選択してください', 3)
            driftRunning = false
            pcall(function() Toggles.DriftKickToggle:SetValue(false) end)
            return
        end

        local target = Players:FindFirstChild(driftTargetName)
        if not target or target == LocalPlayer then
            Library:Notify('ターゲットが無効です', 3)
            driftRunning = false
            pcall(function() Toggles.DriftKickToggle:SetValue(false) end)
            return
        end

        if not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
            Library:Notify('ターゲットにキャラクターがありません', 3)
            driftRunning = false
            pcall(function() Toggles.DriftKickToggle:SetValue(false) end)
            return
        end

        local blobman = BlobmanBeta.getBlobman()
        if not blobman then
            blobman = BlobmanBeta.spawnBlobman()
        end
        if not blobman then
            Library:Notify('Blobmanの取得・生成に失敗しました', 5)
            driftRunning = false
            pcall(function() Toggles.DriftKickToggle:SetValue(false) end)
            return
        end

        if not BlobmanBeta.ensureSitBlobman() then
            Library:Notify('Blobmanに座れませんでした', 4)
            driftRunning = false
            pcall(function() Toggles.DriftKickToggle:SetValue(false) end)
            return
        end

        local scriptObj = blobman:FindFirstChild("BlobmanSeatAndOwnerScript") or blobman:FindFirstChild("BlobmanSeatAndOwnerScript[old]")
        local grabRemote = scriptObj and scriptObj:FindFirstChild("CreatureGrab") or blobman:FindFirstChild("CreatureGrab", true)
        local dropRemote = scriptObj and scriptObj:FindFirstChild("CreatureDrop") or blobman:FindFirstChild("CreatureDrop", true)
        local lDet = blobman:FindFirstChild("LeftDetector")
        local rDet = blobman:FindFirstChild("RightDetector")
        local lWeld = lDet and (lDet:FindFirstChild("LeftWeld") or lDet:FindFirstChildWhichIsA("Weld") or lDet:FindFirstChildWhichIsA("JointInstance") or lDet:FindFirstChild("RigidConstraint"))
        local rWeld = rDet and (rDet:FindFirstChild("RightWeld") or rDet:FindFirstChildWhichIsA("Weld") or rDet:FindFirstChildWhichIsA("JointInstance") or rDet:FindFirstChild("RigidConstraint"))
        local GE = RS:FindFirstChild("GrabEvents")

        if not (GE and grabRemote and dropRemote and ((lDet and lWeld) or (rDet and rWeld))) then
            Library:Notify('必要なRemoteEventやDetectorが見つかりません', 5)
            driftRunning = false
            pcall(function() Toggles.DriftKickToggle:SetValue(false) end)
            return
        end

        Library:Notify('Drift Kick 開始', 3)

        task.spawn(function()
            local blobRoot = blobman:FindFirstChild("HumanoidRootPart") or blobman.PrimaryPart
            local Det = rDet or lDet
            local Weld = rWeld or lWeld

            while driftRunning do
                if myLoopId ~= driftCurrentLoopId then break end
                if not target or not target.Parent then break end

                local tChar = target.Character
                local tHum = tChar and tChar:FindFirstChild("Humanoid")
                local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")

                if tChar and tRoot and tHum and tHum.Health > 0 then
                    local bringStart = tick()
                    while tick() - bringStart < 0.35 do
                        if myLoopId ~= driftCurrentLoopId or not driftRunning or not blobman or not blobman.Parent then break end
                        if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                            local currentTRoot = target.Character.HumanoidRootPart
                            blobRoot.CFrame = currentTRoot.CFrame
                            blobRoot.AssemblyLinearVelocity = Vector3.zero
                            pcall(function()
                                if Det then grabRemote:FireServer(Det, currentTRoot, Weld) end
                                if GE.CreateGrabLine then GE.CreateGrabLine:FireServer(currentTRoot, Vector3.zero, currentTRoot.Position, false) end
                                if GE.SetNetworkOwner then GE.SetNetworkOwner:FireServer(currentTRoot, blobRoot.CFrame) end
                            end)
                        end
                        RunService.Heartbeat:Wait()
                    end

                    if myLoopId ~= driftCurrentLoopId or not driftRunning or not blobman or not blobman.Parent then break end

                    tChar = target.Character
                    tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
                    tHum = tChar and tChar:FindFirstChild("Humanoid")

                    if tChar and tRoot and tHum and tHum.Health > 0 then
                        local SavedPos = tRoot.CFrame
                        local targetCenterCFrame = SavedPos + Vector3.new(0, driftCenterHeight, 0)
                        local lastTime = tick()
                        local lastDropTime = tick()
                        local dropCount = 0

                        while driftRunning and blobman and blobman.Parent do
                            if myLoopId ~= driftCurrentLoopId then break end
                            if not target or not target.Parent then break end

                            tChar = target.Character
                            tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
                            tHum = tChar and tChar:FindFirstChild("Humanoid")

                            if not tChar or not tRoot or not tHum or tHum.Health <= 0 then break end

                            if dropCount < driftGrabCount and (tick() - lastDropTime) > driftGrabInterval then
                                dropCount = dropCount + 1
                                pcall(function()
                                    local currentWeld = Det:FindFirstChild("RightWeld") or Det:FindFirstChild("LeftWeld") or Det:FindFirstChildWhichIsA("Weld") or Det:FindFirstChildWhichIsA("JointInstance") or Det:FindFirstChild("RigidConstraint")
                                    if currentWeld then dropRemote:FireServer(currentWeld) end
                                    if GE.DestroyGrabLine then GE.DestroyGrabLine:FireServer(tRoot) end
                                end)
                                blobRoot.CFrame = SavedPos
                                blobRoot.AssemblyLinearVelocity = Vector3.zero
                                RunService.Heartbeat:Wait()

                                if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                                    local currentTRoot = target.Character.HumanoidRootPart
                                    blobRoot.CFrame = currentTRoot.CFrame
                                    blobRoot.AssemblyLinearVelocity = Vector3.zero
                                    pcall(function()
                                        if Det then grabRemote:FireServer(Det, currentTRoot, Weld) end
                                        if GE.CreateGrabLine then GE.CreateGrabLine:FireServer(currentTRoot, Vector3.zero, currentTRoot.Position, false) end
                                        if GE.SetNetworkOwner then GE.SetNetworkOwner:FireServer(currentTRoot, blobRoot.CFrame) end
                                    end)
                                end
                                lastTime = tick()
                                lastDropTime = tick()
                                continue
                            end

                            if tRoot and tHum and tHum.Health > 0 and blobRoot then
                                local currentTime = tick()
                                local dt = currentTime - lastTime
                                lastTime = currentTime
                                driftAngle = driftAngle + (driftSpeed * dt)

                                local offsetX = math.cos(driftAngle) * driftRadius
                                local offsetZ = math.sin(driftAngle) * driftRadius
                                local blobPos = targetCenterCFrame.Position + Vector3.new(offsetX, driftHeightOffset, offsetZ)

                                blobRoot.CFrame = CFrame.new(blobPos, targetCenterCFrame.Position)
                                blobRoot.AssemblyLinearVelocity = Vector3.zero
                                blobRoot.AssemblyAngularVelocity = Vector3.zero

                                tRoot.CFrame = targetCenterCFrame
                                tRoot.AssemblyLinearVelocity = Vector3.zero
                                tRoot.AssemblyAngularVelocity = Vector3.zero

                                pcall(function()
                                    tHum.PlatformStand = true
                                    tHum.Sit = true
                                    if GE.SetNetworkOwner then GE.SetNetworkOwner:FireServer(tRoot, targetCenterCFrame) end
                                    local currentWeld = Det:FindFirstChild("RightWeld") or Det:FindFirstChild("LeftWeld") or Det:FindFirstChildWhichIsA("Weld") or Det:FindFirstChildWhichIsA("JointInstance") or Det:FindFirstChild("RigidConstraint")
                                    if currentWeld then dropRemote:FireServer(currentWeld) end
                                    if GE.DestroyGrabLine then GE.DestroyGrabLine:FireServer(tRoot) end
                                    if Det then grabRemote:FireServer(Det, tRoot, Weld) end
                                    if GE.CreateGrabLine then GE.CreateGrabLine:FireServer(tRoot, Vector3.zero, targetCenterCFrame.Position, false) end
                                end)
                            else
                                break
                            end
                            RunService.Heartbeat:Wait()
                        end

                        if not driftRunning or myLoopId ~= driftCurrentLoopId then
                            if blobRoot and SavedPos then
                                pcall(function()
                                    local currentWeld = Det:FindFirstChild("RightWeld") or Det:FindFirstChild("LeftWeld") or Det:FindFirstChildWhichIsA("Weld") or Det:FindFirstChildWhichIsA("JointInstance") or Det:FindFirstChild("RigidConstraint")
                                    if currentWeld then dropRemote:FireServer(currentWeld) end
                                    if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") and GE.DestroyGrabLine then
                                        GE.DestroyGrabLine:FireServer(target.Character.HumanoidRootPart)
                                    end
                                end)
                                blobRoot.CFrame = SavedPos
                                blobRoot.AssemblyLinearVelocity = Vector3.zero
                            end
                            break
                        end
                    end
                end
                RunService.Heartbeat:Wait()
            end
        end)
    end
})

DriftGroup:AddButton({
    Text = 'Drift Kick 停止',
    Func = function()
        if driftRunning then
            driftRunning = false
            driftCurrentLoopId = driftCurrentLoopId + 1
            pcall(function() Toggles.DriftKickToggle:SetValue(false) end)
            Library:Notify('Drift Kick 停止', 3)
        else
            Library:Notify('動作中のキックはありません', 3)
        end
    end
})


-- Loop Kick Blob

do
    local LoopKickGroup = Tabs.Target:AddRightGroupbox('Loop Kick Blob')

    -- 状態変数
    local loopActive = false
    local loopTargetName = ""
    local loopMode = "Default"
    local loopThread = nil
    local skyFloor = nil

    -- プレイヤーリスト
    local loopPlayerMap = {}
    local LOOP_PLACEHOLDER = '-- Select Target --'

    local function getLoopPlayerNames()
        local names = { LOOP_PLACEHOLDER }
        loopPlayerMap = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local displayStr = p.DisplayName .. " (@" .. p.Name .. ")"
                table.insert(names, displayStr)
                loopPlayerMap[displayStr] = p.Name
            end
        end
        return names
    end

    -- スカイフロア
    local function ensureSkyKickFloor()
        if skyFloor and skyFloor.Parent then return skyFloor end
        local part = Instance.new("Part")
        part.Name = "SkyKickFloor"
        part.Anchored = true
        part.CanCollide = true
        part.Size = Vector3.new(50, 1, 50)
        part.CFrame = CFrame.new(20000, 20000, 20000)
        part.BrickColor = BrickColor.new("White")
        part.Material = Enum.Material.SmoothPlastic
        part.Parent = Workspace
        skyFloor = part
        return part
    end

    local function removeSkyKickFloor()
        if skyFloor and skyFloor.Parent then
            skyFloor:Destroy()
            skyFloor = nil
        end
    end

    _G.OrynState.flags.removeSkyKickFloor = removeSkyKickFloor

    -- メイン実行関数
    local function runLoopKickBlob(targetName)
        local grabEvents = RS:WaitForChild("GrabEvents")
        local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local seatPart = character:WaitForChild("Humanoid").SeatPart

        if not seatPart or seatPart.Parent.Name ~= "CreatureBlobman" then
            Library:Notify("Loop Kick: Please ride Blobman first", 3)
            loopActive = false
            pcall(function() Toggles.LoopKickBlobToggle:SetValue(false) end)
            return
        end

        local blobModel = seatPart.Parent
        local blobRoot = blobModel:FindFirstChild("HumanoidRootPart") or blobModel.PrimaryPart
        local seatOwnerScript = blobModel:WaitForChild("BlobmanSeatAndOwnerScript")
        local creatureGrab = seatOwnerScript:WaitForChild("CreatureGrab")
        local creatureDrop = seatOwnerScript:WaitForChild("CreatureDrop")
        local rightDetector = blobModel:WaitForChild("RightDetector")
        local baseCF = CFrame.new(20000, 20000, 20000)

        if loopMode == "TP to Sky" then
            ensureSkyKickFloor()
            local skyCF = CFrame.new(20000, 20010.5, 20000)
            pcall(function() blobRoot.CFrame = skyCF end)
            local myRoot = character:FindFirstChild("HumanoidRootPart")
            if myRoot then pcall(function() myRoot.CFrame = skyCF end) end
            task.wait(0.2)
            baseCF = skyCF
        end

        local flag = false
        local tGrab = 0
        local tStart = 0

        while loopActive do
            local target = Players:FindFirstChild(targetName)

            if target then
                local myChar = LocalPlayer.Character
                local myHum = myChar and myChar:FindFirstChild("Humanoid")
                local mySeat = myHum and myHum.SeatPart

                if mySeat and mySeat.Parent.Name == "CreatureBlobman" then
                    local blobModel2 = mySeat.Parent
                    blobRoot = blobModel2:FindFirstChild("HumanoidRootPart") or blobModel2.PrimaryPart
                    local tChar = target.Character
                    local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
                    local tHum = tChar and tChar:FindFirstChild("Humanoid")

                    if tRoot and tHum and tHum.Health > 0 and blobRoot then
                        tRoot.Velocity = Vector3.zero

                        if not flag then
                            blobRoot.CFrame = tRoot.CFrame
                            blobRoot.Velocity = Vector3.zero

                            if tick() - tGrab >= 0.002 then
                                tGrab = tick()
                                pcall(function()
                                    tHum.PlatformStand = true
                                    tHum.Sit = true
                                    grabEvents.SetNetworkOwner:FireServer(tRoot, blobRoot.CFrame)
                                    grabEvents.DestroyGrabLine:FireServer(tRoot)
                                end)
                            end

                            if tStart == 0 then tStart = tick() end
                            if tick() - tStart > 0.35 then
                                blobRoot.CFrame = baseCF
                                blobRoot.Velocity = Vector3.zero
                                flag = true
                                tStart = 0
                            end
                        else
                            blobRoot.CFrame = baseCF
                            blobRoot.Velocity = Vector3.zero
                            local topCF = baseCF * CFrame.new(0, 23, 0)
                            tRoot.CFrame = topCF
                            tHum.PlatformStand = true
                            tHum.Sit = true

                            if tick() - tGrab >= 0.002 then
                                tGrab = tick()
                                pcall(function()
                                    grabEvents.SetNetworkOwner:FireServer(tRoot, topCF)
                                    grabEvents.DestroyGrabLine:FireServer(tRoot)
                                    local rightWeld = rightDetector:FindFirstChild("RightWeld") or rightDetector:FindFirstChildWhichIsA("Weld")
                                    if rightWeld then
                                        creatureDrop:FireServer(rightWeld)
                                        creatureGrab:FireServer(rightDetector, tRoot, rightWeld)
                                    end
                                end)
                            end
                        end
                    else
                        flag = false
                        tStart = 0
                    end

                    RunService.Heartbeat:Wait()
                else
                    break
                end
            else
                break
            end
        end

        if blobRoot then
            blobRoot.CFrame = baseCF
            blobRoot.Velocity = Vector3.zero
        end

        if loopMode == "TP to Sky" then
            removeSkyKickFloor()
        end
    end

    -- UI

    LoopKickGroup:AddDropdown('LoopKickBlobTargetDropdown', {
        Text = 'Loop Kick Target',
        Values = getLoopPlayerNames(),
        Default = LOOP_PLACEHOLDER,
        Multi = false,
        Callback = function(Value)
            if type(Value) == "table" then Value = Value[1] end
            if Value == LOOP_PLACEHOLDER then
                loopTargetName = ""
                return
            end
            loopTargetName = loopPlayerMap[Value] or ""
            if loopTargetName ~= "" then
                Library:Notify('Loop Kick Target: ' .. loopTargetName, 1.5)
            end
        end,
    })

    LoopKickGroup:AddButton({
        Text = 'Refresh Loop List',
        Func = function()
            pcall(function() Options.LoopKickBlobTargetDropdown:Refresh(getLoopPlayerNames(), true) end)
            Library:Notify('Loop リスト更新完了', 1.5)
        end,
    })

    LoopKickGroup:AddDropdown('LoopKickBlobModeDropdown', {
        Text = 'Loop Kick Mode',
        Values = { 'Default', 'TP to Sky' },
        Default = 1,
        Callback = function(Value)
            loopMode = Value
        end,
    })

    LoopKickGroup:AddToggle('LoopKickBlobToggle', {
        Text = 'Loop Kick Blob (Single Target)',
        Default = false,
        Tooltip = 'Blobmanに乗ってターゲットをループキック',
        Callback = function(v)
            loopActive = v

            if v then
                if loopTargetName == "" then
                    Library:Notify('Loop Kick: Please select a target first', 3)
                    loopActive = false
                    pcall(function() Toggles.LoopKickBlobToggle:SetValue(false) end)
                    return
                end

                loopThread = task.spawn(function()
                    runLoopKickBlob(loopTargetName)
                end)
                Library:Notify('Loop Kick Blob: Started on ' .. loopTargetName, 3)
            else
                loopActive = false
                if loopMode == "TP to Sky" then removeSkyKickFloor() end
                Library:Notify('Loop Kick Blob: Stopped', 2)
            end
        end,
    })

    -- プレイヤー退出時にリスト更新
    Players.PlayerAdded:Connect(function()
        task.wait(0.5)
        pcall(function() Options.LoopKickBlobTargetDropdown:Refresh(getLoopPlayerNames(), false) end)
    end)

    Players.PlayerRemoving:Connect(function(p)
        task.wait(0.3)
        pcall(function() Options.LoopKickBlobTargetDropdown:Refresh(getLoopPlayerNames(), false) end)
        if loopTargetName == p.Name then loopTargetName = "" end
    end)
end

Players.PlayerAdded:Connect(function(p)
    task.wait(0.5)
    refreshPlayerDropdown(true)
    Library:Notify('Player joined: ' .. p.Name, 2)
end)

Players.PlayerRemoving:Connect(function(p)
    task.wait(0.3)
    refreshPlayerDropdown(true)
end)

Players.PlayerAdded:Connect(function(p)
    task.wait(0.5)
    pcall(function() Options.DriftTarget:Refresh(getDriftPlayerNames(), false) end)
end)

Players.PlayerRemoving:Connect(function(p)
    task.wait(0.3)
    pcall(function() Options.DriftTarget:Refresh(getDriftPlayerNames(), false) end)
    if driftTargetName == p.Name then
        driftTargetName = ""
    end
end)

-- Info

local statusLabel = InfoGroup:AddLabel('Status: Idle')
local targetLabel = InfoGroup:AddLabel('Target: None')

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

-- Misc タブ

local MiscLeft = Tabs.Misc:AddLeftGroupbox('Fun')
local MiscRight = Tabs.Misc:AddRightGroupbox('Camera')

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

-- Player タブ

local PlayerView = Tabs.Player:AddLeftGroupbox('View')
local PlayerMove = Tabs.Player:AddRightGroupbox('Movement')

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

PlayerMove:AddToggle('WaterWalk', {
    Text = 'Water Walk',
    Default = false,
    Tooltip = '海の上を歩けるようにします',
    Callback = function(v)
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


--  Umbrella / Character Spin / Infinite Jump 

do
    -- Umbrella 
local UmbrellaGroup = Tabs.Player:AddRightGroupbox('Umbrella')

local umbrellaEnabled = false
local umbrellaRainbow = false
local umbrellaColor = Color3.fromRGB(255, 255, 255)
local umbrellaTransparency = 0.3
local umbrellaMaterial = Enum.Material.Neon
local umbrellaSize = 2.4
local umbrellaHeight = 1.1
local umbrellaPart = nil
local umbrellaConn = nil

local function destroyUmbrella()
    if umbrellaPart then
        pcall(function() umbrellaPart:Destroy() end)
        umbrellaPart = nil
    end
    if umbrellaConn then
        pcall(function() umbrellaConn:Disconnect() end)
        umbrellaConn = nil
    end
end

local function buildUmbrella()
    destroyUmbrella()

    local char = LocalPlayer.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    -- 傘パーツ作成
    local part = Instance.new("Part")
    part.Name = "_phChineseHat"
    part.Transparency = umbrellaTransparency
    part.Color = umbrellaColor
    part.Material = umbrellaMaterial
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.Massless = true
    part.Size = Vector3.new(1, 1, 1)

    local mesh = Instance.new("SpecialMesh")
    mesh.MeshId = "rbxassetid://1033714"
    mesh.Scale = Vector3.new(umbrellaSize, umbrellaSize * 0.66666666666666674, umbrellaSize)
    mesh.Parent = part

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = head
    weld.Part1 = part
    weld.Parent = part

    part.CFrame = head.CFrame * CFrame.new(0, umbrellaHeight, 0)
    part.Parent = char

    umbrellaPart = part

    -- レインボー処理
    if umbrellaRainbow then
        umbrellaConn = RunService.RenderStepped:Connect(function()
            if not umbrellaPart or not umbrellaPart.Parent then return end
            local hue = tick() % 5 / 5
            pcall(function()
                umbrellaPart.Color = Color3.fromHSV(hue, 1, 1)
            end)
        end)
    end
end

-- ★★★ Unload で呼び出せるように公開 ★★★
_G.OrynState.flags.destroyUmbrella = destroyUmbrella

UmbrellaGroup:AddToggle('UmbrellaToggle', {
    Text = 'Umbrella',
    Default = false,
    Tooltip = '頭の上に傘を付ける',
    Callback = function(v)
        umbrellaEnabled = v
        if v then
            buildUmbrella()
        else
            destroyUmbrella()
        end
    end,
}):AddColorPicker('UmbrellaColor', {
    Default = Color3.fromRGB(255, 255, 255),
    Title = 'Umbrella Color',
    Callback = function(c)
        umbrellaColor = c
        if umbrellaPart then
            pcall(function() umbrellaPart.Color = c end)
        end
    end,
})

UmbrellaGroup:AddToggle('UmbrellaRainbow', {
    Text = 'Rainbow Umbrella',
    Default = false,
    Tooltip = '傘を虹色に変化させる',
    Callback = function(v)
        umbrellaRainbow = v
        if umbrellaEnabled then
            destroyUmbrella()
            buildUmbrella()
        end
    end,
})

UmbrellaGroup:AddSlider('UmbrellaTransparency', {
    Text = 'Umbrella Transparency',
    Default = 30, Min = 0, Max = 100, Rounding = 0, Suffix = '%',
    Callback = function(v)
        umbrellaTransparency = v / 100
        if umbrellaPart then
            pcall(function() umbrellaPart.Transparency = umbrellaTransparency end)
        end
    end,
})

UmbrellaGroup:AddSlider('UmbrellaSize', {
    Text = 'Umbrella Size',
    Default = 2.4, Min = 0.5, Max = 10, Rounding = 1,
    Callback = function(v)
        umbrellaSize = v
        if umbrellaPart then
            local mesh = umbrellaPart:FindFirstChildOfClass("SpecialMesh")
            if mesh then
                pcall(function()
                    mesh.Scale = Vector3.new(v, v * 0.66666666666666674, v)
                end)
            end
        end
    end,
})

UmbrellaGroup:AddSlider('UmbrellaHeight', {
    Text = 'Umbrella Height',
    Default = 1.1, Min = -10, Max = 10, Rounding = 1,
    Callback = function(v)
        umbrellaHeight = v
        if umbrellaEnabled then
            destroyUmbrella()
            buildUmbrella()
        end
    end,
})

UmbrellaGroup:AddDropdown('UmbrellaMaterial', {
    Values = { 'Neon', 'ForceField', 'Plastic', 'SmoothPlastic', 'Glass', 'Ice', 'Wood', 'Metal', 'Foil' },
    Default = 'Neon',
    Multi = false,
    Text = 'Umbrella Material',
    Callback = function(v)
        umbrellaMaterial = Enum.Material[v]
        if umbrellaPart then
            pcall(function() umbrellaPart.Material = umbrellaMaterial end)
        end
    end,
})

-- キャラ再スポーン時
trackConn(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1.5)
    if umbrellaEnabled then
        buildUmbrella()
    end
end))
end 

-- ============ Character Spin / Infinite Jump ============
do
    local MovementGroup = Tabs.Player:AddRightGroupbox('Movement+')

    -- Character Spin
    local spinEnabled = false
    local spinSpeed = 5
    local spinConn = nil

    MovementGroup:AddToggle('CharacterSpin', {
        Text = 'Character Spin',
        Default = false,
        Tooltip = 'キャラクター全体を回転させる',
        Callback = function(v)
            spinEnabled = v
            if v then
                if spinConn then spinConn:Disconnect() end
                spinConn = RunService.RenderStepped:Connect(function(dt)
                    if not spinEnabled then return end
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        pcall(function()
                            hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(spinSpeed * 100 * dt), 0)
                        end)
                    end
                end)
            else
                if spinConn then
                    spinConn:Disconnect()
                    spinConn = nil
                end
            end
        end,
    })

    MovementGroup:AddSlider('CharacterSpinSpeed', {
        Text = 'Spin Speed',
        Default = 5, Min = 1, Max = 30, Rounding = 0,
        Callback = function(v) spinSpeed = v end,
    })

    -- Infinite Jump
    local infJumpEnabled = false

    MovementGroup:AddToggle('InfiniteJump', {
        Text = 'Infinite Jump',
        Default = false,
        Tooltip = '空中でもジャンプできる',
        Callback = function(v)
            infJumpEnabled = v
        end,
    })

    -- ジャンプリクエストを検知して空中ジャンプを実行
    UserInputService.JumpRequest:Connect(function()
        if not infJumpEnabled then return end
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function()
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end)
        end
    end)
end

-- UI Settings

local MenuGroup = Tabs.Settings:AddLeftGroupbox('Menu')

MenuGroup:AddButton('Unload', function()
    print("[OrynHUB] Unload 開始...")

    -- ========== 1. グローバルフラグを全部OFF ==========
    pcall(function()
        _G.PacketLagActive = false
        _G.MonsterLagEnabled = false
        _G.CoconutOrbitEnabled = false
        _G.ShurikenAntiKick = false
        _G.LineLagPacketCount = 10
        _G.cons = {}
    end)

    -- ========== 2. ラインラグ停止 ==========
    pcall(stopLineLag)

    -- ========== 3. Umbrella / MC Textures を復元 ==========
    pcall(function()
        if _G.OrynState.flags.destroyUmbrella then
            _G.OrynState.flags.destroyUmbrella()
            print("[OrynHUB] Umbrella 削除完了")
        end
        if _G.OrynState.flags.restoreMCTextures then
            _G.OrynState.flags.restoreMCTextures()
            print("[OrynHUB] MC Textures 復元完了")
        end
    end)

        -- ========== 3.5 Wing / Banana / Loop Kick クリーンアップ ==========
    pcall(function()
        if _G.OrynState.flags.cleanupWings then
            _G.OrynState.flags.cleanupWings()
            print("[OrynHUB] Wing 削除完了")
        end
        if _G.OrynState.flags.destroyBananaBlob then
            _G.OrynState.flags.destroyBananaBlob()
            print("[OrynHUB] Banana Blob 削除完了")
        end
        if _G.OrynState.flags.removeSkyKickFloor then
            _G.OrynState.flags.removeSkyKickFloor()
            print("[OrynHUB] SkyKickFloor 削除完了")
        end
    end)

        -- ========== 3.6 ESP クリーンアップ ==========
    pcall(function()
        if _G.OrynState.flags.cleanupBoxESP then
            _G.OrynState.flags.cleanupBoxESP()
            print("[OrynHUB] 3D Box ESP 削除完了")
        end
    end)

    -- ========== 4. Blobman / Banana 関連 ==========
    pcall(function()
        if BlobmanBeta and BlobmanBeta.destroyBlobman then
            BlobmanBeta.destroyBlobman()
        end
    end)

    -- ========== 5. 自動作成したパーツを削除 ==========
    pcall(function()
        -- Visual Effects 系フォルダ
        for _, name in ipairs({ "PoophubHalo", "PoophubAmbientAura", "PoophubAngelWings", "PoophubTrail" }) do
            local obj = Workspace:FindFirstChild(name)
            if obj then pcall(function() obj:Destroy() end) end
        end

        -- SkyKickFloor
        local sf = Workspace:FindFirstChild("SkyKickFloor")
        if sf then pcall(function() sf:Destroy() end) end

        -- Anti Blob の TruePositionPart
        local char = LocalPlayer.Character
        if char then
            local tpp = char:FindFirstChild("TruePositionPart")
            if tpp then pcall(function() tpp:Destroy() end) end
        end

        -- FurtherExtendGUI
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            local fe = pg:FindFirstChild("OrynFurtherExtendGUI")
            if fe then pcall(function() fe:Destroy() end) end
        end
    end)

    -- ========== 6. カメラ・FOV を元に戻す ==========
    pcall(function()
        local cam = Workspace.CurrentCamera
        if cam then cam.FieldOfView = 70 end
        if Player then
            Player.CameraMode = Enum.CameraMode.Classic
            Player.CameraMaxZoomDistance = 128
            Player.CameraMinZoomDistance = 0.5
        end
    end)

    -- ========== 7. WalkSpeed / JumpPower を元に戻す ==========
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.AutoRotate = true
                hum.PlatformStand = false
                hum.Sit = false
            end
        end
    end)

    -- ========== 8. FallenPartsDestroyHeight を元に戻す ==========
    pcall(function()
        Workspace.FallenPartsDestroyHeight = -100
    end)

    -- ========== 9. PlayerScripts を復元 ==========
    pcall(function()
        local ps = LocalPlayer:FindFirstChild("PlayerScripts")
        if ps then
            local cbm = ps:FindFirstChild("CharacterAndBeamMove")
            if cbm then cbm.Enabled = true end
            local sptd = ps:FindFirstChild("StickyPartsTouchDetection")
            if sptd then sptd.Enabled = true end
        end
    end)

    -- ========== 10. 状態テーブルをクリア ==========
    pcall(function()
        _G.OrynState = {
            connections = {},
            instances = {},
            threads = {},
            flags = {},
            originals = {},
        }
    end)

    -- ========== 11. Library をアンロード ==========
    print("[OrynHUB] Unload 完了")
    pcall(function() Library:Unload() end)
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

-- Wing（ウィング） - Misc タブ 

do
    local WingGroup = Tabs.Misc:AddRightGroupbox('Wing')

    local wingActive = false
    local wingItem = "TetracubeI"
    local wingSearch = "My Toys"
    local wingSpeed = 2
    local wingLength = 5
    local wingAngle = 30
    local wingTimeCounter = 0
    local wings = {}

    local wingOffsets = {
        CFrame.new(-4.125, 0, 1),
        CFrame.new(4.125, 0, 1),
    }

    local function getToyFolders()
        local folders = {}
        if wingSearch == "My Toys" or wingSearch == "All Toys" then
            local mine = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
            if mine then table.insert(folders, mine) end
        end
        if wingSearch == "Plot Toys" or wingSearch == "All Toys" then
            local plots = Workspace:FindFirstChild("Plots")
            if plots then
                for i = 1, 5 do
                    local plot = plots:FindFirstChild("Plot" .. i)
                    if plot then
                        local sign = plot:FindFirstChild("PlotSign")
                        local owners = sign and sign:FindFirstChild("ThisPlotsOwners")
                        if owners then
                            for _, child in ipairs(owners:GetChildren()) do
                                if child:IsA("ValueBase") and child.Value == LocalPlayer.Name then
                                    local plotItems = Workspace:FindFirstChild("PlotItems")
                                    if plotItems and plotItems:FindFirstChild(plot.Name) then
                                        table.insert(folders, plotItems:FindFirstChild(plot.Name))
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        return folders
    end

    local function setupPhysics(parent)
        local bp = parent:FindFirstChildOfClass("BodyPosition") or Instance.new("BodyPosition")
        local bg = parent:FindFirstChildOfClass("BodyGyro") or Instance.new("BodyGyro")
        bp.P = 15000
        bp.D = 200
        bp.MaxForce = Vector3.one * 1e10
        bp.Parent = parent
        bg.P = 15000
        bg.D = 200
        bg.MaxTorque = Vector3.one * 1e10
        bg.Parent = parent
        return bg, bp
    end

    local function cleanupWings()
        for _, wing in pairs(wings) do
            if wing.Handle then pcall(function() wing.Handle:Destroy() end) end
            for _, seg in pairs(wing.Segments) do
                if seg.Part then pcall(function() seg.Part:Destroy() end) end
            end
        end
        wings = {}
    end

    _G.OrynState.flags.cleanupWings = cleanupWings

    local function buildWings()
        cleanupWings()
        local folders = getToyFolders()
        local found = {}
        for _, folder in ipairs(folders) do
            for _, desc in ipairs(folder:GetDescendants()) do
                if desc:IsA("Model") and desc.Name == wingItem then
                    table.insert(found, desc)
                end
            end
        end
        if #found == 0 then return false end

        for i = 1, 2 do
            local segs = {}
            for i2 = 1, wingLength do
                local p = Instance.new("Part")
                p.CanCollide = false
                p.Anchored = true
                p.Transparency = 1
                p.Size = Vector3.new(4, 1, 4)
                p.Parent = Workspace
                segs[#segs + 1] = { Part = p }
            end
            local handle = Instance.new("Part")
            handle.CanCollide = false
            handle.Anchored = true
            handle.Transparency = 1
            handle.Size = Vector3.new(4, 1, 4)
            handle.Parent = Workspace
            wings[#wings + 1] = { Handle = handle, Segments = segs, Sync = {}, Reserved = nil }
        end

        for i, model in ipairs(found) do
            local n = i <= #found / 2 and 1 or 2
            local soundPart = model:FindFirstChild("SoundPart") or model:FindFirstChild("Handle") or model:FindFirstChildWhichIsA("BasePart")
            if soundPart then
                for _, c in pairs(model:GetChildren()) do
                    if c:IsA("BasePart") then c.CanCollide = false end
                end
                local bg, bp = setupPhysics(soundPart)
                if not wings[n].Reserved then
                    wings[n].Reserved = { BG = bg, BP = bp }
                else
                    table.insert(wings[n].Sync, { BG = bg, BP = bp })
                end
            end
        end
        return true
    end

    WingGroup:AddDropdown('WingItem', {
        Text = '1. Select Item',
        Values = { 'TetracubeI', 'FireworkSparkler', 'PoopPile' },
        Default = 1,
        Callback = function(v)
            wingItem = v
            if wingActive then buildWings() end
        end,
    })

    WingGroup:AddDropdown('WingSearch', {
        Text = '2. Search Range',
        Values = { 'My Toys', 'Plot Toys', 'All Toys' },
        Default = 1,
        Callback = function(v)
            wingSearch = v
            if wingActive then buildWings() end
        end,
    })

    WingGroup:AddToggle('EnableWings', {
        Text = '3. Enable Wings',
        Default = false,
        Callback = function(v)
            if v then
                if buildWings() then
                    wingActive = true
                else
                    Library:Notify('Target not found', 3)
                    wingActive = false
                end
            else
                wingActive = false
                cleanupWings()
            end
        end,
    })

    WingGroup:AddSlider('WingSpeed', {
        Text = 'Wing Speed',
        Default = 2, Min = 1, Max = 10, Rounding = 1,
        Callback = function(v) wingSpeed = v end,
    })

    RunService.RenderStepped:Connect(function(dt)
        if not (wingActive and #wings > 0) then return end
        pcall(function()
            local char = LocalPlayer.Character
            if not char then return end
            local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not (torso and hrp) then return end

            wingTimeCounter = wingTimeCounter + dt * (wingSpeed + hrp.Velocity.Magnitude / 40)

            for i, wing in ipairs(wings) do
                local sign = i == 1 and 1 or -1
                wing.Handle.CFrame = torso.CFrame * wingOffsets[i]
                    * CFrame.Angles(0, 0, math.sin(wingTimeCounter) * math.rad(wingAngle + hrp.Velocity.Magnitude / 4) * sign)

                if wing.Reserved then
                    wing.Reserved.BP.Position = wing.Handle.Position
                    wing.Reserved.BG.CFrame = wing.Handle.CFrame * CFrame.Angles(math.pi / 2, 0, math.pi / 2)
                end

                for i2, seg in ipairs(wing.Segments) do
                    seg.Part.CFrame = seg.Part.CFrame:Lerp(
                        (i2 == 1 and wing.Handle.CFrame or wing.Segments[i2 - 1].Part.CFrame) * wingOffsets[i], 0.5)
                    if wing.Sync[i2] then
                        wing.Sync[i2].BP.Position = seg.Part.Position
                        wing.Sync[i2].BG.CFrame = seg.Part.CFrame * CFrame.Angles(math.pi / 2, 0, math.pi / 2)
                    end
                end
            end
        end)
    end)
end


-- Visual Effects

do
    local FXGroup = Tabs.Player:AddLeftGroupbox('Visual Effects')

    local function newPartFolder(name)
        local f = Instance.new("Folder")
        f.Name = name
        f.Parent = Workspace
        local p = Instance.new("Part")
        p.Name = name .. "Root"
        p.Anchored = true
        p.CanCollide = false
        p.Transparency = 1
        p.Size = Vector3.new(2, 2, 1)
        p.Parent = f
        return f, p
    end

    -- === Halo ===
    local haloFolder, haloPart = newPartFolder("PoophubHalo")
    local haloAtt = Instance.new("Attachment")
    haloAtt.CFrame = CFrame.new(-0.25, 0.93, 0.25, 0.4689, -0.2499, -0.8471, -0.1171, 0.933, -0.3401, 0.8754, 0.2587, 0.4082)
    haloAtt.Parent = haloPart

    local function makeHaloRing(sizeSeq, name)
        local pe = Instance.new("ParticleEmitter")
        pe.Name = name
        pe.Texture = "rbxassetid://8819682608"
        pe.Rate = 7
        pe.Lifetime = NumberRange.new(1, 1)
        pe.Speed = NumberRange.new(0.001, 0.001)
        pe.RotSpeed = NumberRange.new(-400, 400)
        pe.Rotation = NumberRange.new(0, 360)
        pe.Size = sizeSeq
        pe.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.2, 0),
            NumberSequenceKeypoint.new(0.8, 0),
            NumberSequenceKeypoint.new(1, 1),
        })
        pe.Color = ColorSequence.new(Color3.fromRGB(133, 220, 255))
        pe.LightEmission = 1
        pe.Brightness = 2
        pe.SpreadAngle = Vector2.new(5, 5)
        pe.LockedToPart = true
        pe.Shape = Enum.ParticleEmitterShape.Box
        pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
        pe.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
        pe.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
        pe.Parent = haloAtt
        return pe
    end

    local haloRing1 = makeHaloRing(NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 3) }), "Ring1")
    local haloRing2 = makeHaloRing(NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 3) }), "Ring2")

    local haloEnabled = false
    local haloColor = Color3.fromRGB(133, 220, 255)
    local haloOffX, haloOffY, haloOffZ = 0, 1.5, 0

    -- === Aura ===
    local auraFolder, auraPart = newPartFolder("PoophubAmbientAura")
    local auraEmitters = {}
    local function makeAura(cfg)
        local pe = Instance.new("ParticleEmitter")
        for k, v in pairs(cfg) do pe[k] = v end
        pe.Parent = auraPart
        table.insert(auraEmitters, pe)
        return pe
    end
    makeAura({
        Name = "Ambient2", Texture = "rbxassetid://12713358087", Rate = 20,
        Lifetime = NumberRange.new(2, 2), Speed = NumberRange.new(0.001, 0.001),
        RotSpeed = NumberRange.new(-600, 600), Rotation = NumberRange.new(0, 360),
        Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.3, 1),
            NumberSequenceKeypoint.new(0.6, 2.5),
            NumberSequenceKeypoint.new(0.8, 4),
            NumberSequenceKeypoint.new(1, 6),
        }),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
        Color = ColorSequence.new(Color3.fromRGB(133, 220, 255)),
        LightEmission = 1, Brightness = 2, LockedToPart = true,
        EmissionDirection = Enum.NormalId.Top, Shape = Enum.ParticleEmitterShape.Box,
        ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
        ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
        Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
    })
    makeAura({
        Name = "Stars", Texture = "rbxassetid://7216849325", Rate = 20,
        Lifetime = NumberRange.new(2, 2), Speed = NumberRange.new(0.001, 0.001),
        RotSpeed = NumberRange.new(-30, 30), Rotation = NumberRange.new(0, 360),
        Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.3, 1),
            NumberSequenceKeypoint.new(0.6, 2.5),
            NumberSequenceKeypoint.new(0.8, 4),
            NumberSequenceKeypoint.new(1, 6),
        }),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.2), NumberSequenceKeypoint.new(1, 1) }),
        Color = ColorSequence.new(Color3.fromRGB(133, 220, 255)),
        LightEmission = 1, Brightness = 2, LockedToPart = true,
        EmissionDirection = Enum.NormalId.Top, Shape = Enum.ParticleEmitterShape.Box,
        ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
        ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
        Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
    })
    makeAura({
        Name = "Ambient1", Texture = "rbxassetid://7216855136", Rate = 20,
        Lifetime = NumberRange.new(2, 2), Speed = NumberRange.new(0.001, 0.001),
        RotSpeed = NumberRange.new(-40, 40), Rotation = NumberRange.new(0, 360),
        Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.3, 2),
            NumberSequenceKeypoint.new(0.6, 5),
            NumberSequenceKeypoint.new(0.8, 8),
            NumberSequenceKeypoint.new(1, 12),
        }),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.3), NumberSequenceKeypoint.new(1, 1) }),
        Color = ColorSequence.new(Color3.fromRGB(133, 220, 255)),
        LightEmission = 1, Brightness = 2, LockedToPart = true,
        EmissionDirection = Enum.NormalId.Top, Shape = Enum.ParticleEmitterShape.Box,
        ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
        ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
        Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
    })

    local auraEnabled = false
    local auraColor = Color3.fromRGB(133, 220, 255)
    local auraOffX, auraOffY, auraOffZ = 0, 0, 0

    -- === Angel Wings ===
    local angelFolder, angelPart = newPartFolder("PoophubAngelWings")
    local angelAttL = Instance.new("Attachment")
    angelAttL.CFrame = CFrame.new(-1.012, 0.5, 0.852) * CFrame.Angles(0, math.rad(15), 0)
    angelAttL.Parent = angelPart
    local angelAttR = Instance.new("Attachment")
    angelAttR.CFrame = CFrame.new(1.167, 0.5, 0.852) * CFrame.Angles(0, -math.rad(15), 0)
    angelAttR.Parent = angelPart
    local angelAttC = Instance.new("Attachment")
    angelAttC.CFrame = CFrame.new(0, 0.3, 0)
    angelAttC.Parent = angelPart

    local function mkWingParticle(parent, dir)
        local pe = Instance.new("ParticleEmitter")
        pe.Texture = "http://www.roblox.com/asset/?id=13267054240"
        pe.Rate = 4
        pe.Lifetime = NumberRange.new(1, 1)
        pe.Speed = NumberRange.new(0.05, 0.05)
        pe.RotSpeed = NumberRange.new(0, 0)
        pe.Rotation = NumberRange.new(-15, -15)
        pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.75), NumberSequenceKeypoint.new(1, 3.5) })
        pe.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.944),
            NumberSequenceKeypoint.new(0.2, 0),
            NumberSequenceKeypoint.new(0.8, 0),
            NumberSequenceKeypoint.new(1, 1),
        })
        pe.Color = ColorSequence.new(Color3.fromRGB(133, 220, 255))
        pe.LightEmission = 1
        pe.Brightness = 1
        pe.LockedToPart = true
        pe.Shape = Enum.ParticleEmitterShape.Box
        pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
        pe.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
        pe.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
        pe.EmissionDirection = dir
        pe.SpreadAngle = Vector2.new(0, 0)
        pe.VelocitySpread = 0
        pe.Parent = parent
        return pe
    end

    local angelL = mkWingParticle(angelAttL, Enum.NormalId.Back)
    local angelR = mkWingParticle(angelAttR, Enum.NormalId.Front)

    local angelEnabled = false
    local angelColor = Color3.fromRGB(133, 220, 255)
    local angelOffX, angelOffY = 0, 0

    -- === Trail ===
    local trailFolder, trailPart = newPartFolder("PoophubTrail")
    trailPart.Size = Vector3.new(0.1, 0.1, 0.1)
    local trailAtt0 = Instance.new("Attachment")
    trailAtt0.Position = Vector3.new(0, 0.5, 0)
    trailAtt0.Parent = trailPart
    local trailAtt1 = Instance.new("Attachment")
    trailAtt1.Position = Vector3.new(0, -0.5, 0)
    trailAtt1.Parent = trailPart
    local trail = Instance.new("Trail")
    trail.Attachment0 = trailAtt0
    trail.Attachment1 = trailAtt1
    trail.Lifetime = 0.4
    trail.MinLength = 0.01
    trail.FaceCamera = true
    trail.LightEmission = 1
    trail.LightInfluence = 0
    trail.Brightness = 2
    trail.WidthScale = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.4, 0.6),
        NumberSequenceKeypoint.new(0.7, 0.25),
        NumberSequenceKeypoint.new(1, 0),
    })
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.5, 0.1),
        NumberSequenceKeypoint.new(0.8, 0.5),
        NumberSequenceKeypoint.new(1, 1),
    })
    trail.Color = ColorSequence.new(Color3.fromRGB(133, 220, 255))
    trail.Parent = trailPart

    local trailEnabled = false
    local trailColor = Color3.fromRGB(133, 220, 255)

    -- === Rainbow ===
    local rainbowEnabled = false
    local rainbowSpeed = 0.5
    local rainbowHue = 0
    local rainbowHalo, rainbowAura, rainbowAngel, rainbowTrail = true, true, true, true

    -- === UI ===
    local FXSelect = FXGroup:AddDropdown('FXSelect', {
        Text = 'Select Effect to Configure',
        Values = { 'Halo', 'Aura', 'Angel Wings', 'Trail' },
        Default = 1,
        Callback = function() end,
    })

    FXGroup:AddDivider()

    local haloElems = {}
    table.insert(haloElems, FXGroup:AddToggle('HaloEnable', {
        Text = 'Enable Halo', Default = false,
        Callback = function(v)
            haloEnabled = v
            haloRing1.Enabled = v
            haloRing2.Enabled = v
        end,
    }):AddColorPicker('HaloColor', {
        Default = Color3.fromRGB(133, 220, 255), Title = 'Halo Color',
        Callback = function(c)
            haloColor = c
            haloRing1.Color = ColorSequence.new(c)
            haloRing2.Color = ColorSequence.new(c)
        end,
    }))
    table.insert(haloElems, FXGroup:AddSlider('HaloRate', {
        Text = 'Halo Particle Rate', Default = 7, Min = 1, Max = 50, Rounding = 0,
        Callback = function(v) haloRing1.Rate = v haloRing2.Rate = v end,
    }))
    table.insert(haloElems, FXGroup:AddSlider('HaloBrightness', {
        Text = 'Halo Brightness', Default = 2, Min = 0, Max = 10, Rounding = 1,
        Callback = function(v) haloRing1.Brightness = v haloRing2.Brightness = v end,
    }))
    table.insert(haloElems, FXGroup:AddSlider('HaloHeight', {
        Text = 'Halo Height (Y)', Default = 1.5, Min = -3, Max = 5, Rounding = 1,
        Callback = function(v) haloOffY = v end,
    }))
    table.insert(haloElems, FXGroup:AddSlider('HaloSide', {
        Text = 'Halo Side (X)', Default = 0, Min = -3, Max = 3, Rounding = 1,
        Callback = function(v) haloOffX = v end,
    }))
    table.insert(haloElems, FXGroup:AddSlider('HaloDepth', {
        Text = 'Halo Depth (Z)', Default = 0, Min = -3, Max = 3, Rounding = 1,
        Callback = function(v) haloOffZ = v end,
    }))

    FXGroup:AddDivider()
    local auraElems = {}
    table.insert(auraElems, FXGroup:AddToggle('AuraEnable', {
        Text = 'Enable Aura', Default = false,
        Callback = function(v)
            auraEnabled = v
            for _, pe in ipairs(auraEmitters) do pe.Enabled = v end
        end,
    }):AddColorPicker('AuraColor', {
        Default = Color3.fromRGB(133, 220, 255), Title = 'Aura Color',
        Callback = function(c)
            auraColor = c
            for _, pe in ipairs(auraEmitters) do pe.Color = ColorSequence.new(c) end
        end,
    }))
    table.insert(auraElems, FXGroup:AddSlider('AuraRate', {
        Text = 'Aura Particle Rate', Default = 20, Min = 1, Max = 60, Rounding = 0,
        Callback = function(v) for _, pe in ipairs(auraEmitters) do pe.Rate = v end end,
    }))
    table.insert(auraElems, FXGroup:AddSlider('AuraBrightness', {
        Text = 'Aura Brightness', Default = 2, Min = 0, Max = 10, Rounding = 1,
        Callback = function(v) for _, pe in ipairs(auraEmitters) do pe.Brightness = v end end,
    }))
    table.insert(auraElems, FXGroup:AddSlider('AuraHeight', {
        Text = 'Aura Height (Y)', Default = 0, Min = -3, Max = 5, Rounding = 1,
        Callback = function(v) auraOffY = v end,
    }))
    table.insert(auraElems, FXGroup:AddSlider('AuraSide', {
        Text = 'Aura Side (X)', Default = 0, Min = -3, Max = 3, Rounding = 1,
        Callback = function(v) auraOffX = v end,
    }))
    table.insert(auraElems, FXGroup:AddSlider('AuraDepth', {
        Text = 'Aura Depth (Z)', Default = 0, Min = -3, Max = 3, Rounding = 1,
        Callback = function(v) auraOffZ = v end,
    }))

    FXGroup:AddDivider()
    local angelElems = {}
    table.insert(angelElems, FXGroup:AddToggle('AngelEnable', {
        Text = 'Enable Angel Wings', Default = false,
        Callback = function(v)
            angelEnabled = v
            angelL.Enabled = v
            angelR.Enabled = v
        end,
    }):AddColorPicker('AngelColor', {
        Default = Color3.fromRGB(133, 220, 255), Title = 'Wings Color',
        Callback = function(c)
            angelColor = c
            angelL.Color = ColorSequence.new(c)
            angelR.Color = ColorSequence.new(c)
        end,
    }))
    table.insert(angelElems, FXGroup:AddSlider('AngelRate', {
        Text = 'Wings Particle Rate', Default = 4, Min = 1, Max = 30, Rounding = 0,
        Callback = function(v) angelL.Rate = v angelR.Rate = v end,
    }))
    table.insert(angelElems, FXGroup:AddSlider('AngelBrightness', {
        Text = 'Wings Brightness', Default = 1, Min = 0, Max = 5, Rounding = 1,
        Callback = function(v) angelL.Brightness = v angelR.Brightness = v end,
    }))
    table.insert(angelElems, FXGroup:AddSlider('AngelHeight', {
        Text = 'Wings Height Offset (Y)', Default = 0, Min = -3, Max = 5, Rounding = 1,
        Callback = function(v) angelOffY = v end,
    }))
    table.insert(angelElems, FXGroup:AddSlider('AngelSide', {
        Text = 'Wings Side Offset (X)', Default = 0, Min = -3, Max = 3, Rounding = 1,
        Callback = function(v) angelOffX = v end,
    }))
    table.insert(angelElems, FXGroup:AddSlider('AngelSpread', {
        Text = 'Wings Spread', Default = 1, Min = 0.3, Max = 3, Rounding = 1,
        Callback = function(v)
            angelAttL.CFrame = CFrame.new(-1.012 * v, 0.5, 0.852) * CFrame.Angles(0, math.rad(15), 0)
            angelAttR.CFrame = CFrame.new(1.167 * v, 0.5, 0.852) * CFrame.Angles(0, -math.rad(15), 0)
        end,
    }))

    FXGroup:AddDivider()
    local trailElems = {}
    table.insert(trailElems, FXGroup:AddToggle('TrailEnable', {
        Text = 'Enable Trail', Default = false,
        Callback = function(v)
            trailEnabled = v
            trail.Enabled = v
        end,
    }):AddColorPicker('TrailColor', {
        Default = Color3.fromRGB(133, 220, 255), Title = 'Trail Color',
        Callback = function(c)
            trailColor = c
            trail.Color = ColorSequence.new(c)
        end,
    }))
    table.insert(trailElems, FXGroup:AddSlider('TrailWidth', {
        Text = 'Trail Width', Default = 1.5, Min = 0.2, Max = 5, Rounding = 1,
        Callback = function(v)
            trail.WidthScale = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.4, 0.6 * v / 1.5),
                NumberSequenceKeypoint.new(0.7, 0.25 * v / 1.5),
                NumberSequenceKeypoint.new(1, 0),
            })
            trailAtt0.Position = Vector3.new(0, v / 2, 0)
            trailAtt1.Position = Vector3.new(0, -v / 2, 0)
        end,
    }))
    table.insert(trailElems, FXGroup:AddSlider('TrailLifetime', {
        Text = 'Trail Lifetime', Default = 0.4, Min = 0.05, Max = 3, Rounding = 2,
        Callback = function(v) trail.Lifetime = v end,
    }))

    local allElemGroups = { Halo = haloElems, Aura = auraElems, ['Angel Wings'] = angelElems, Trail = trailElems }
    local function setGroupVisible(group, visible)
        for _, elem in ipairs(group) do
            if elem.SetVisible then pcall(function() elem:SetVisible(visible) end)
            elseif elem.Container then elem.Container.Visible = visible end
        end
    end
    FXSelect:OnChanged(function(v)
        for k, grp in pairs(allElemGroups) do setGroupVisible(grp, k == v) end
    end)
    for k, grp in pairs(allElemGroups) do setGroupVisible(grp, k == 'Halo') end

    local rainbowGroup = Tabs.Player:AddRightGroupbox('Rainbow Settings')
    rainbowGroup:AddToggle('RainbowEnable', {
        Text = 'Enable Rainbow Mode', Default = false,
        Callback = function(v) rainbowEnabled = v end,
    })
    rainbowGroup:AddSlider('RainbowSpeed', {
        Text = 'Rainbow Speed', Default = 0.5, Min = 0.1, Max = 5, Rounding = 1,
        Callback = function(v) rainbowSpeed = v end,
    })
    rainbowGroup:AddToggle('RainbowHalo', { Text = 'Apply Rainbow to Halo', Default = true, Callback = function(v) rainbowHalo = v end })
    rainbowGroup:AddToggle('RainbowAura', { Text = 'Apply Rainbow to Aura', Default = true, Callback = function(v) rainbowAura = v end })
    rainbowGroup:AddToggle('RainbowAngel', { Text = 'Apply Rainbow to Wings', Default = true, Callback = function(v) rainbowAngel = v end })
    rainbowGroup:AddToggle('RainbowTrail', { Text = 'Apply Rainbow to Trail', Default = true, Callback = function(v) rainbowTrail = v end })

    RunService.RenderStepped:Connect(function(dt)
        if rainbowEnabled then
            rainbowHue = (rainbowHue + rainbowSpeed * dt) % 1
        end
        local rainbowColor = Color3.fromHSV(rainbowHue, 0.85, 1)

        local char = LocalPlayer.Character
        if not char then return end
        local head = char:FindFirstChild("Head")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not (head and hrp) then return end

        if haloEnabled then
            haloPart.CFrame = CFrame.new(head.Position.X + haloOffX, head.Position.Y + haloOffY, head.Position.Z + haloOffZ)
            local col = (rainbowEnabled and rainbowHalo) and rainbowColor or haloColor
            haloRing1.Color = ColorSequence.new(col)
            haloRing2.Color = ColorSequence.new(col)
        end

        if auraEnabled then
            auraPart.CFrame = CFrame.new(hrp.Position.X + auraOffX, hrp.Position.Y + auraOffY, hrp.Position.Z + auraOffZ)
            local col = (rainbowEnabled and rainbowAura) and rainbowColor or auraColor
            for _, pe in ipairs(auraEmitters) do pe.Color = ColorSequence.new(col) end
        end

        if angelEnabled then
            angelPart.CFrame = hrp.CFrame * CFrame.new(angelOffX, angelOffY, 0)
            local col = (rainbowEnabled and rainbowAngel) and rainbowColor or angelColor
            angelL.Color = ColorSequence.new(col)
            angelR.Color = ColorSequence.new(col)
        end

        if trailEnabled then
            trailPart.CFrame = hrp.CFrame
            local col = (rainbowEnabled and rainbowTrail) and rainbowColor or trailColor
            trail.Color = ColorSequence.new(col)
        end
    end)
end

-- Dance V2 - Misc タブ 

do
    local DanceV2Group = Tabs.Misc:AddRightGroupbox('Dance V2')

    local DanceV2 = {
        rawTable = {},
        list = {},
        activeData = nil,
        selectedName = '',
        isDancing = false,
        conn = nil,
        frameIndex = 1,
        frameTimer = 0,
        skipParts = { HumanoidRootPart = true, Handle = true, LArmIKPart = true, RArmIKPart = true },
    }

    local function stopDanceV2(char)
        if DanceV2.conn then
            DanceV2.conn:Disconnect()
            DanceV2.conn = nil
        end
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.PlatformStand = false
                hum.AutoRotate = true
            end
        end
    end

    local function parseCFrame(arr)
        return CFrame.new(arr[1], arr[2], arr[3], arr[4], arr[5], arr[6], arr[7], arr[8], arr[9], arr[10], arr[11], arr[12])
    end

    local function startDanceV2(char)
        if not DanceV2.activeData then return end
        stopDanceV2(char)
        local hrp = char:WaitForChild("HumanoidRootPart")
        local hum = char:WaitForChild("Humanoid")

        local ragdollRemote = ReplicatedStorage:FindFirstChild("CharacterEvents")
        ragdollRemote = ragdollRemote and ragdollRemote:FindFirstChild("RagdollRemote")

        if ragdollRemote then
            ragdollRemote:FireServer(hrp, 9999999)
        else
            hum.PlatformStand = true
            hum.AutoRotate = false
        end

        local position = hrp.Position
        local walkSpeed = hum.WalkSpeed > 0 and hum.WalkSpeed or 16
        local threshold = 8
        local frameCount = #DanceV2.activeData.frames
        if frameCount == 0 then return end
        DanceV2.frameIndex = 1
        DanceV2.frameTimer = 0

        DanceV2.conn = RunService.Heartbeat:Connect(function(dt)
            if not char or not char.Parent or not hrp or not hrp.Parent then return end
            local look = Camera.CFrame.LookVector
            local yaw = math.atan2(-look.X, -look.Z)
            local curPos = hrp.Position
            if threshold < (curPos - position).Magnitude then position = curPos end

            local moveDir = hum.MoveDirection
            if moveDir.Magnitude > 0.01 then
                position = position + moveDir * walkSpeed * dt
            end

            local baseCF = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
            hrp.CFrame = baseCF
            hrp.AssemblyLinearVelocity = Vector3.zero

            DanceV2.frameTimer = DanceV2.frameTimer + dt
            local wrapped = false
            if DanceV2.activeData.interval <= DanceV2.frameTimer then
                DanceV2.frameTimer = DanceV2.frameTimer - DanceV2.activeData.interval
                DanceV2.frameIndex = DanceV2.frameIndex + 1
                if frameCount < DanceV2.frameIndex then
                    DanceV2.frameIndex = 1
                    wrapped = true
                end
            end

            local f1 = DanceV2.activeData.frames[DanceV2.frameIndex]
            local f2 = DanceV2.activeData.frames[DanceV2.frameIndex < frameCount and DanceV2.frameIndex + 1 or 1]
            local alpha = wrapped and 1 or DanceV2.frameTimer / DanceV2.activeData.interval

            for name, partData in pairs(f1.parts) do
                if not DanceV2.skipParts[name] then
                    local part = char:FindFirstChild(name)
                    if part and part:IsA("BasePart") then
                        local nextPart = f2.parts[name] or partData
                        part.CFrame = baseCF * parseCFrame(partData):Lerp(parseCFrame(nextPart), alpha)
                        part.AssemblyLinearVelocity = Vector3.zero
                    end
                end
            end
        end)
    end

    local function refreshList()
        DanceV2.rawTable = {}

        local ok, result = pcall(function()
            return game:HttpGet("https://raw.githubusercontent.com/dcus-official/PoopHub/refs/heads/main/Assets/Emote/List_Json.lua")
        end)
        if ok and result then
            local ok2, parsed = pcall(function()
                local chunk = loadstring(result)
                if chunk then return chunk() end
            end)
            if ok2 and type(parsed) == "table" then
                for k, v in pairs(parsed) do DanceV2.rawTable[k] = v end
            end
        end

        if not isfolder("OrynHUB") then makefolder("OrynHUB") end
        if not isfolder("OrynHUB/FTAP") then makefolder("OrynHUB/FTAP") end
        if not isfolder("OrynHUB/FTAP/Emote") then makefolder("OrynHUB/FTAP/Emote") end

        local ok2, files = pcall(function() return listfiles("OrynHUB/FTAP/Emote") end)
        if ok2 and type(files) == "table" then
            for _, file in ipairs(files) do
                if file:match("%.dance$") then
                    local name = file:gsub("\\", "/"):match("([^/]+)%.dance$")
                    if name then
                        local ok3, content = pcall(function() return readfile(file) end)
                        if ok3 and content then DanceV2.rawTable[name] = content end
                    end
                end
            end
        end

        DanceV2.list = {}
        for k in pairs(DanceV2.rawTable) do table.insert(DanceV2.list, k) end
        table.sort(DanceV2.list)
        if #DanceV2.list == 0 then table.insert(DanceV2.list, "No dances found") end

        if Options.DanceV2Dropdown then
            Options.DanceV2Dropdown:SetValues(DanceV2.list)
            if #DanceV2.list > 0 and DanceV2.list[1] ~= "No dances found" then
                Options.DanceV2Dropdown:SetValue(DanceV2.list[1])
            end
        end
    end

    DanceV2Group:AddDropdown('DanceV2Dropdown', {
        Values = { 'Click Refresh...' },
        Default = 1,
        Multi = false,
        Searchable = true,
        Text = 'Select Dance V2',
        Callback = function(name)
            if name == 'Click Refresh...' or name == 'No dances found' or name == '' then return end
            DanceV2.selectedName = name
            local raw = DanceV2.rawTable[name]
            if raw then
                local ok, data = pcall(function()
                    return game:GetService("HttpService"):JSONDecode(raw)
                end)
                if ok then
                    DanceV2.activeData = data
                    if DanceV2.isDancing and LocalPlayer.Character then
                        startDanceV2(LocalPlayer.Character)
                    end
                else
                    Library:Notify('Failed to parse JSON', 3)
                    DanceV2.activeData = nil
                end
            end
        end,
    })

    DanceV2Group:AddToggle('DanceV2Toggle', {
        Text = 'Enable Dance V2',
        Default = false,
        Callback = function(v)
            DanceV2.isDancing = v
            if v then
                if DanceV2.activeData and LocalPlayer.Character then
                    startDanceV2(LocalPlayer.Character)
                else
                    Library:Notify('No dance data selected/loaded', 3)
                    Toggles.DanceV2Toggle:SetValue(false)
                end
            else
                stopDanceV2(LocalPlayer.Character)
            end
        end,
    })

    DanceV2Group:AddButton({
        Text = 'Refresh List',
        Func = function()
            refreshList()
            Library:Notify('Dance list refreshed', 3)
        end,
    })

    LocalPlayer.CharacterAdded:Connect(function(char)
        if DanceV2.isDancing and DanceV2.activeData then
            task.wait(0.3)
            startDanceV2(char)
        end
    end)

    refreshList()
end

-- Blackhole Customizer - Misc タブ 

do
    local BHGroup = Tabs.Misc:AddRightGroupbox('Blackhole Customizer')

    local blackholeEnabled = false
    local blackholeImage = ''
    local tracked = {}
    local FALLBACK = 'rbxassetid://117677503754205'

    if not isfolder("OrynHUB") then makefolder("OrynHUB") end
    if not isfolder("OrynHUB/Logo") then makefolder("OrynHUB/Logo") end
    if not isfolder("OrynHUB/Logo/UBG") then makefolder("OrynHUB/Logo/UBG") end

    local function applyToBlackhole(entry)
        if blackholeEnabled then
            if entry.large then
                entry.large.Image = blackholeImage
                entry.large.ImageColor3 = Color3.new(1, 1, 1)
                entry.large.ImageTransparency = 0
                entry.large.Visible = true
                pcall(function() entry.large.ResampleMode = Enum.ResamplerMode.Pixelated end)
            end
            if entry.small then entry.small.Visible = false end
            if entry.hole then entry.hole.Transparency = 1 end
        else
            if entry.large then
                entry.large.Image = entry.origLargeImage
                entry.large.ImageColor3 = entry.origLargeColor
                entry.large.ImageTransparency = entry.origLargeTrans
            end
            if entry.small then entry.small.Visible = entry.origSmallVisible end
            if entry.hole then entry.hole.Transparency = entry.origHoleTrans end
        end
    end

    local function updateAll()
        for _, entry in pairs(tracked) do applyToBlackhole(entry) end
    end

    local function processInstance(inst)
        if tracked[inst] then return end
        if inst:IsA("Model") and string.find(string.lower(inst.Name), "blackhole") then
            local entry = {
                large = nil, small = nil, hole = nil,
                origLargeImage = '', origLargeColor = Color3.new(1, 1, 1), origLargeTrans = 0,
                origSmallVisible = true, origHoleTrans = 0,
            }
            tracked[inst] = entry

            local function applyChild(child)
                if child.Name == 'Large' and (child:IsA("ImageLabel") or child:IsA("ImageButton")) then
                    if not entry.large then
                        entry.large = child
                        entry.origLargeImage = child.Image
                        entry.origLargeColor = child.ImageColor3
                        entry.origLargeTrans = child.ImageTransparency
                    end
                    if blackholeEnabled and blackholeImage ~= '' then
                        child.Image = blackholeImage
                        child.ImageColor3 = Color3.new(1, 1, 1)
                        child.ImageTransparency = 0
                        child.Visible = true
                        pcall(function() child.ResampleMode = Enum.ResamplerMode.Pixelated end)
                    end
                elseif child.Name == 'Small' and (child:IsA("ImageLabel") or child:IsA("ImageButton")) then
                    if not entry.small then
                        entry.small = child
                        entry.origSmallVisible = child.Visible
                    end
                    if blackholeEnabled then child.Visible = false end
                elseif child.Name == 'Hole' and child:IsA("BasePart") then
                    if not entry.hole then
                        entry.hole = child
                        entry.origHoleTrans = child.Transparency
                    end
                    if blackholeEnabled then child.Transparency = 1 end
                end
            end

            for _, d in ipairs(inst:GetDescendants()) do applyChild(d) end
            local c1 = inst.DescendantAdded:Connect(applyChild)
            local c2
            c2 = inst.AncestryChanged:Connect(function(_, parent)
                if not parent then
                    tracked[inst] = nil
                    c1:Disconnect()
                    c2:Disconnect()
                end
            end)
        end
    end

    for _, d in ipairs(Workspace:GetDescendants()) do processInstance(d) end
    Workspace.DescendantAdded:Connect(processInstance)

    local function applyImage(input)
        local trimmed = input:match("^%s*(.-)%s*$")
        if not trimmed or trimmed == '' then return end

        if string.find(trimmed, "rbxassetid://") then
            blackholeImage = trimmed
            updateAll()
        elseif string.find(trimmed, "http") then
            task.spawn(function()
                local ok, result = pcall(function() return game:HttpGet(trimmed) end)
                if ok and result and #result > 0 then
                    local isImg = result:sub(1, 4) == "\137PNG" or result:sub(1, 2) == "\255\216" or result:sub(1, 3) == "GIF"
                    if not isImg then
                        Library:Notify('Invalid image! URL must point directly to an image file.', 4)
                        return
                    end
                    pcall(function()
                        local key = trimmed:gsub("[^%w]", "")
                        if #key > 40 then key = key:sub(#key - 40) end
                        local path = "OrynHUB/custom_blackhole_" .. key .. "_" .. tostring(math.random(10000, 99999)) .. ".png"
                        writefile(path, result)
                        local ok2, asset = pcall(function() return getcustomasset(path) end)
                        if ok2 and asset then
                            blackholeImage = asset
                        else
                            blackholeImage = FALLBACK
                        end
                        updateAll()
                        Library:Notify('Blackhole Image Applied!', 3)
                    end)
                else
                    Library:Notify('Failed to download image from URL', 3)
                end
            end)
        end
    end

    BHGroup:AddToggle('CustomBlackholeToggle', {
        Text = 'Enable Custom Image',
        Default = false,
        Callback = function(v)
            blackholeEnabled = v
            updateAll()
        end,
    })

    BHGroup:AddInput('CustomBlackholeImageInput', {
        Default = "https://raw.githubusercontent.com/dcus-official/PoopHub.Free/refs/heads/main/Assets/Logo/Ultimate%20Rainbow%20Poop.png",
        Numeric = false,
        Finished = false,
        Text = 'Custom Image URL/ID',
        Tooltip = 'rbxassetid://... or https://...',
        Placeholder = 'Enter image asset ID or URL',
        Callback = function(input)
            applyImage(input)
        end,
    })

    applyImage("https://raw.githubusercontent.com/dcus-official/PoopHub.Free/refs/heads/main/Assets/Logo/Ultimate%20Rainbow%20Poop.png")
end

-- ウォーターマーク
Library:SetWatermark('Oryn HUB | Obsidian UI')

-- MC Textures 

do
    local MCGroup = Tabs.Misc:AddLeftGroupbox('MC Textures')

    local mcEnabled = false
    local mcTileSize = 4
    local mcDebug = false
    local originalTextures = {}

    -- マインクラフト風テクスチャID
    local TEX = {
        Rock        = "rbxassetid://5003953441",
        Grass       = "rbxassetid://9267183930",
        GrassCorner = "rbxassetid://151708391",
        Sand        = "rbxassetid://9277770677",
        Wood        = "rbxassetid://9359131807",
        Snow        = "rbxassetid://5612862976",
        Dirt        = "rbxassetid://152569532",
        Glass       = "rbxassetid://152239003",
        Ocean       = "rbxassetid://152572260",
        DarkRock    = "rbxassetid://152572250",
        Moss        = "rbxassetid://152239826",
        Barn        = "rbxassetid://151695075",
        Chain       = "rbxassetid://4722586771",
        PlotWood    = "rbxassetid://152572250",
        PlotSkin    = "rbxassetid://152240077",
        FenceWood   = "rbxassetid://151776506",
    }

    local function log(msg)
        if mcDebug then print("[MCTex] " .. tostring(msg)) end
    end

    local function shouldSkip(part)
        local path = part:GetFullName():lower()
        for _, kw in ipairs({ "sky", "skybox", "cloud", "sun", "moon", "star", "snowpart" }) do
            if path:find(kw, 1, true) then return true end
        end
        return false
    end

    local function getFullPath(obj)
        local parts = {}
        local current = obj
        while current do
            table.insert(parts, 1, current.Name)
            current = current.Parent
        end
        return table.concat(parts, ".")
    end

    local function pathContainsAll(obj, keywords)
        local p = getFullPath(obj):lower()
        for _, kw in ipairs(keywords) do
            if not p:find(kw:lower(), 1, true) then return false end
        end
        return true
    end

    local function colorMatch(c1, c2, tol)
        tol = tol or 0.04
        return math.abs(c1.R - c2.R) < tol and math.abs(c1.G - c2.G) < tol and math.abs(c1.B - c2.B) < tol
    end

    local function resolveTexture(part)
        -- 1. Path + Color ベース
        if pathContainsAll(part, { "Map", "FactoryIsland", "Chain" }) then
            return TEX.Chain, "Chain"
        end
        if pathContainsAll(part, { "Plots" }) then
            if colorMatch(part.Color, Color3.fromRGB(152, 118, 84)) and part.Material == Enum.Material.WoodPlanks then
                return TEX.PlotWood, "PlotWood"
            end
            if colorMatch(part.Color, Color3.fromRGB(255, 204, 153)) and part.Material == Enum.Material.Plastic then
                return TEX.PlotSkin, "PlotSkin"
            end
        end
        if pathContainsAll(part, { "Map", "BarnHillArea", "Barn" }) then
            if colorMatch(part.Color, Color3.fromRGB(148, 75, 75)) then
                return TEX.Barn, "Barn"
            end
        end
        if pathContainsAll(part, { "Map", "BarnHillArea", "Farm", "FencedWheatField" }) then
            return TEX.FenceWood, "FenceWood"
        end
        if pathContainsAll(part, { "Map", "CaveMountain", "House" }) then
            if part:IsA("WedgePart") and colorMatch(part.Color, Color3.fromRGB(39, 70, 45)) then
                return TEX.Moss, "Moss"
            end
        end

        -- 2. Global WoodPlanks系
        if part.Material == Enum.Material.WoodPlanks then
            if colorMatch(part.Color, Color3.fromRGB(202, 203, 209)) then return TEX.Rock, "Global: WP grey" end
            if colorMatch(part.Color, Color3.fromRGB(105, 102, 92)) then return TEX.DarkRock, "Global: WP brown" end
            if colorMatch(part.Color, Color3.fromRGB(90, 79, 71)) then return TEX.DarkRock, "Global: WP dark" end
            if colorMatch(part.Color, Color3.fromRGB(175, 148, 131)) then return TEX.PlotWood, "Global: WP beige" end
        end

        -- 3. Name ベース
        local name = part.Name:lower()
        if name:find("trunk") or name:find("tree") or name:find("branch") or name:find("log") then
            return TEX.Wood, "name:tree"
        end
        if name:find("rock") or name:find("stone") or name:find("cobble") then
            return TEX.Rock, "name:rock"
        end
        if name:find("grass") or name:find("lawn") then
            return TEX.Grass, "name:grass"
        end
        if name:find("sand") or name:find("desert") then
            return TEX.Sand, "name:sand"
        end
        if name:find("snow") or name:find("ice") then
            return TEX.Snow, "name:snow"
        end
        if name:find("dirt") or name:find("soil") then
            return TEX.Dirt, "name:dirt"
        end
        if name:find("glass") or name:find("window") then
            return TEX.Glass, "name:glass"
        end
        if name:find("ocean") or name:find("water") then
            return TEX.Ocean, "name:ocean"
        end

        return nil
    end

    local function pasteFace(parent, face, texture)
        local t = Instance.new("Texture")
        t.Texture = texture
        t.Face = face
        t.StudsPerTileU = mcTileSize
        t.StudsPerTileV = mcTileSize
        t.Parent = parent
    end

    local function applyAllFaces(part, texture)
        for _, face in ipairs({
            Enum.NormalId.Top, Enum.NormalId.Bottom,
            Enum.NormalId.Front, Enum.NormalId.Back,
            Enum.NormalId.Left, Enum.NormalId.Right
        }) do
            pasteFace(part, face, texture)
        end
    end

    local function applyMCTextures()
        local scanned, applied, skipped = 0, 0, 0

        for _, part in ipairs(Workspace:GetDescendants()) do
            if part:IsA("BasePart") and not part:IsA("Terrain") then
                scanned = scanned + 1
                if shouldSkip(part) then
                    skipped = skipped + 1
                else
                    local texId, note = resolveTexture(part)
                    if texId and texId ~= TEX.Snow then
                        if originalTextures[part] == nil then
                            local saved = {}
                            for _, child in ipairs(part:GetChildren()) do
                                if child:IsA("Texture") or child:IsA("Decal") then
                                    table.insert(saved, child:Clone())
                                    child:Destroy()
                                end
                            end
                            if #saved == 0 then saved = { "empty" } end
                            originalTextures[part] = saved
                        else
                            for _, child in ipairs(part:GetChildren()) do
                                if child:IsA("Texture") or child:IsA("Decal") then
                                    child:Destroy()
                                end
                            end
                        end

                        applyAllFaces(part, texId)
                        applied = applied + 1
                        log(string.format("HIT [%s] %s", note or "?", part:GetFullName()))
                    else
                        skipped = skipped + 1
                    end
                end
            end
        end

        log(string.format("Scanned:%d Applied:%d Skipped:%d", scanned, applied, skipped))
        return applied, skipped
    end

    local function restoreOriginalTextures()
        local restored = 0
        for part, saved in pairs(originalTextures) do
            if part and part.Parent then
                for _, child in ipairs(part:GetChildren()) do
                    if child:IsA("Texture") or child:IsA("Decal") then
                        child:Destroy()
                    end
                end
                for _, tex in ipairs(saved) do
                    if tex ~= "empty" then
                        tex:Clone().Parent = part
                    end
                end
                restored = restored + 1
            end
        end
        table.clear(originalTextures)
        log(string.format("Restored %d parts", restored))
    end

    -- Unload 
    _G.OrynState.flags.restoreMCTextures = restoreOriginalTextures

    MCGroup:AddToggle('MCTexEnabled', {
        Text = 'Enable MC Textures',
        Default = false,
        Tooltip = 'マップをマインクラフト風に変更',
        Callback = function(v)
            mcEnabled = v
            if v then
                local a, s = applyMCTextures()
                Library:Notify(string.format('MC Textures: Applied %d (Skipped %d)', a, s), 3)
            else
                restoreOriginalTextures()
                Library:Notify('MC Textures: Restored originals', 3)
            end
        end,
    })

    MCGroup:AddSlider('MCTileSize', {
        Text = 'Studs Per Tile',
        Default = 4, Min = 1, Max = 16, Rounding = 0,
        Callback = function(v)
            mcTileSize = v
            for _, desc in ipairs(Workspace:GetDescendants()) do
                if desc:IsA("BasePart") then
                    for _, child in ipairs(desc:GetChildren()) do
                        if child:IsA("Texture") then
                            child.StudsPerTileU = v
                            child.StudsPerTileV = v
                        end
                    end
                end
            end
        end,
    })

    MCGroup:AddToggle('MCTexDebug', {
        Text = 'Debug Log',
        Default = false,
        Callback = function(v) mcDebug = v end,
    })
end

-- Barrier Break - Misc タブ 

do
    local BarrierGroup = Tabs.Misc:AddLeftGroupbox('Barrier Break')

    local barrierAuto = false
    local barrierAutoThread = nil

    local function executeBarrierBreak()
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end

        local savedCF = hrp.CFrame
        local savedWS = hum.WalkSpeed
        hum.WalkSpeed = 0

        -- Ocarina を特定座標にスポーン
        pcall(function()
            RS.MenuToys.SpawnToyRemoteFunction:InvokeServer(
                "InstrumentWoodwindOcarina",
                CFrame.new(184.148834, -5.54824972, 498.136749),
                Vector3.new(0, 34, 0)
            )
        end)
        task.wait(0.4)

        local inv = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
        local ocarina = inv and inv:FindFirstChild("InstrumentWoodwindOcarina")
        if not ocarina then
            hum.WalkSpeed = savedWS
            Library:Notify('Barrier Break: Ocarina not found', 3)
            return
        end

        pcall(function()
            ocarina.HoldPart.HoldItemRemoteFunction:InvokeServer(ocarina, Workspace[LocalPlayer.Name])
        end)

        hrp.CFrame = CFrame.new(304.06, 25.77, 488.54)
        task.wait(0.2)

        pcall(function()
            RS.MenuToys.DestroyToy:FireServer(ocarina)
        end)

        hrp.CFrame = savedCF
        task.wait(0.7)

        -- Campfire を特定座標にスポーン
        pcall(function()
            RS.MenuToys.SpawnToyRemoteFunction:InvokeServer(
                "Campfire",
                CFrame.new(257.638672, -5.57392979, 450.103638),
                Vector3.new(0, 161.97, 0)
            )
        end)

        hum.WalkSpeed = savedWS
        Library:Notify('Barrier Break: Completed', 3)
    end

    BarrierGroup:AddButton({
        Text = 'Barrier Break',
        Tooltip = 'バリアを破壊する（プロット侵入用）',
        Func = function()
            task.spawn(executeBarrierBreak)
        end,
    })

    BarrierGroup:AddToggle('AutoBarrierBreak', {
        Text = 'Auto Barrier Break',
        Default = false,
        Tooltip = 'バリアを自動で破壊し続ける',
        Callback = function(v)
            barrierAuto = v
            if not v then
                if barrierAutoThread then
                    task.cancel(barrierAutoThread)
                    barrierAutoThread = nil
                end
                return
            end

            barrierAutoThread = task.spawn(function()
                while barrierAuto do
                    local char = LocalPlayer.Character
                    if not char then
                        task.wait(0.5)
                    else
                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        if hrp and hum then
                            local savedWS = hum.WalkSpeed
                            hum.WalkSpeed = 0

                            pcall(function()
                                RS.MenuToys.SpawnToyRemoteFunction:InvokeServer(
                                    "InstrumentWoodwindOcarina",
                                    CFrame.new(184.148834, -5.54824972, 498.136749),
                                    Vector3.new(0, 34, 0)
                                )
                            end)
                            task.wait(0.5)

                            local inv = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
                            local ocarina = inv and inv:FindFirstChild("InstrumentWoodwindOcarina")
                            if ocarina then
                                pcall(function()
                                    ocarina.HoldPart.HoldItemRemoteFunction:InvokeServer(ocarina, Workspace[LocalPlayer.Name])
                                end)
                                local savedCF = hrp.CFrame
                                hrp.CFrame = CFrame.new(304.06, 25.77, 488.54)
                                task.wait(0.185)
                                pcall(function()
                                    RS.MenuToys.DestroyToy:FireServer(ocarina)
                                end)
                                hrp.CFrame = savedCF
                                task.wait(0.7)

                                pcall(function()
                                    RS.MenuToys.SpawnToyRemoteFunction:InvokeServer(
                                        "Campfire",
                                        CFrame.new(257.638672, -5.57392979, 450.103638),
                                        Vector3.new(0, 161.97, 0)
                                    )
                                end)
                                task.wait(0.5)
                                hum.WalkSpeed = savedWS
                                Library:Notify('Barrier Break: Success!', 2)
                                barrierAuto = false
                                pcall(function()
                                    Toggles.AutoBarrierBreak:SetValue(false)
                                end)
                            else
                                hum.WalkSpeed = savedWS
                                task.wait(0.5)
                            end
                        else
                            task.wait(0.3)
                        end
                    end
                end
            end)
        end,
    })
end

-- Banana Ragdoll - Attack 相当（Target タブ）

do
    local BananaGroup = Tabs.Target:AddRightGroupbox('Banana Ragdoll')

    local bananaEnabled = false
    local bananaTargetName = ""
    local bananaThread = nil
    local bananaCurrentLoopId = 0
    local bananaBlob = nil
    local bananaPlayerMap = {}
    local BANANA_PLACEHOLDER = '-- Select Target --'

    local function getBananaPlayerNames()
        local names = { BANANA_PLACEHOLDER }
        bananaPlayerMap = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local display = p.DisplayName .. " (@" .. p.Name .. ")"
                table.insert(names, display)
                bananaPlayerMap[display] = p.Name
            end
        end
        return names
    end

    --  ユーティリティ 
    local function getLocalRoot()
        local c = LocalPlayer.Character
        return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso"))
    end
    local function getLocalHum()
        local c = LocalPlayer.Character
        return c and c:FindFirstChildOfClass("Humanoid")
    end
    local function getMyInv()
        return Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
    end
    local function findBlob(part)
        local m = part and part:FindFirstAncestorOfClass("Model")
        if m and m.Name == "CreatureBlobman" then return m end
        return nil
    end

    local function destroyBlob()
        if bananaBlob and bananaBlob.Parent then
            local mt = RS:FindFirstChild("MenuToys")
            local dt = mt and mt:FindFirstChild("DestroyToy")
            if dt then pcall(function() dt:FireServer(bananaBlob) end)
            else pcall(function() bananaBlob:Destroy() end) end
        end
        bananaBlob = nil
    end

    _G.OrynState.flags.destroyBananaBlob = destroyBlob

    local function getBlobman()
        local inv = getMyInv()
        if inv then
            local v = inv:FindFirstChild("CreatureBlobman")
            if v and v:FindFirstChild("VehicleSeat") then return v end
        end
        return nil
    end

    local function spawnBlobman()
        local root = getLocalRoot()
        if not root then return nil end
        pcall(function()
            RS.MenuToys.SpawnToyRemoteFunction:InvokeServer("CreatureBlobman", root.CFrame, Vector3.zero)
        end)
        task.wait(1.0)
        return getBlobman()
    end

    local function sitBlobman()
        local blob = bananaBlob or getBlobman()
        if not blob or not blob:FindFirstChild("VehicleSeat") then return false end
        local seat = blob.VehicleSeat
        local hum = getLocalHum()
        if hum and not hum.Sit then
            seat:Sit(hum)
            task.wait(0.6)
        end
        return hum and hum.Sit and hum.SeatPart == seat
    end

    local function createBanana()
        local root = getLocalRoot()
        if not root then return nil end
        local cf = root.CFrame * CFrame.new(0, 14, 20)
        local inv = getMyInv()
        if not inv then return nil end

        local result = nil
        local conn
        conn = inv.ChildAdded:Connect(function(child)
            if child.Name == "FoodBanana" then result = child end
        end)

        pcall(function()
            RS.MenuToys.SpawnToyRemoteFunction:InvokeServer("FoodBanana", cf, Vector3.zero)
        end)

        local t = tick()
        repeat task.wait(0.05) until result or tick() - t > 3

        if conn then conn:Disconnect() end
        return result
    end

    local function getTargetLeftLeg(target)
        local c = target and target.Character
        return c and c:FindFirstChild("Left Leg")
    end

    local function snatchOwnership(part)
        if part then
            pcall(function()
                RS.GrabEvents.SetNetworkOwner:FireServer(part, part.CFrame)
            end)
        end
    end

    local function dropLine(part)
        if part then
            pcall(function()
                RS.GrabEvents.DestroyGrabLine:FireServer(part)
            end)
        end
    end

    --  Banana を持ってターゲットに近づける 
    local function attachBanana(banana, targetHum)
        if not banana then return end
        local holdPart = banana:FindFirstChild("HoldPart")
        local holdItem = holdPart and holdPart:FindFirstChild("HoldItemRemoteFunction")
        local dropItem = holdPart and holdPart:FindFirstChild("DropItemRemoteFunction")
        if not holdItem or not dropItem then return end
        local char = LocalPlayer.Character
        if not char then return end

        -- hold
        for _ = 1, 5 do
            if not banana.Parent then return end
            local ok = pcall(function() holdItem:InvokeServer(banana, char) end)
            if ok then break end
            task.wait(0.05)
        end
        task.wait(0.05)
        pcall(function() holdItem:InvokeServer(banana, char) end)
        task.wait(0.05)
        task.wait(0.5)

        -- use (投げる)
        local use = RS:FindFirstChild("HoldEvents") and RS.HoldEvents:FindFirstChild("Use")
        if use then
            pcall(function() use:FireServer(banana) end)
        end
        task.wait(2.3)

        -- drop
        local root = getLocalRoot()
        if root then
            local dropCF = root.CFrame * CFrame.new(0, 15, 0)
            pcall(function() dropItem:InvokeServer(banana, dropCF, dropCF) end)
            task.wait(0.05)
            pcall(function() dropItem:InvokeServer(banana, dropCF, dropCF) end)
        end
        task.wait(0.3)
    end

    --  メインループ 
    local function bananaLoop(targetName)
        while bananaEnabled do
            local target = Players:FindFirstChild(targetName)
            if not target or not target.Character then
                task.wait(0.3)
            else
                local tHum = target.Character:FindFirstChildOfClass("Humanoid")
                if not tHum or tHum.Health <= 0 then
                    task.wait(0.5)
                else
                    local banana = createBanana()
                    if banana then
                        attachBanana(banana, tHum)
                    end
                    task.wait(0.5)
                end
            end
        end
    end

    --  UI 
    BananaGroup:AddDropdown('BananaTargetDropdown', {
        Text = 'Banana Target',
        Values = getBananaPlayerNames(),
        Default = BANANA_PLACEHOLDER,
        Multi = false,
        Callback = function(v)
            if type(v) == "table" then v = v[1] end
            if v == BANANA_PLACEHOLDER then
                bananaTargetName = ""
                return
            end
            bananaTargetName = bananaPlayerMap[v] or ""
            if bananaTargetName ~= "" then
                Library:Notify('Banana Target: ' .. bananaTargetName, 1.5)
            end
        end,
    })

    BananaGroup:AddButton({
        Text = 'Refresh Banana List',
        Func = function()
            pcall(function()
                Options.BananaTargetDropdown:Refresh(getBananaPlayerNames(), false)
            end)
            Library:Notify('Banana list refreshed', 1.5)
        end,
    })

    BananaGroup:AddToggle('BananaRagdollToggle', {
        Text = 'Banana Ragdoll',
        Default = false,
        Tooltip = 'ターゲットをバナナでラグドール化させる',
        Callback = function(v)
            bananaEnabled = v
            bananaCurrentLoopId = bananaCurrentLoopId + 1
            local myId = bananaCurrentLoopId

            if not v then
                if bananaThread then
                    task.cancel(bananaThread)
                    bananaThread = nil
                end
                return
            end

            if bananaTargetName == "" then
                Library:Notify('Banana Ragdoll: Select target first', 3)
                bananaEnabled = false
                pcall(function() Toggles.BananaRagdollToggle:SetValue(false) end)
                return
            end

            bananaThread = task.spawn(function()
                bananaLoop(bananaTargetName)
            end)
            Library:Notify('Banana Ragdoll: Started on ' .. bananaTargetName, 3)
        end,
    })

    Players.PlayerAdded:Connect(function()
        task.wait(0.5)
        pcall(function()
            Options.BananaTargetDropdown:Refresh(getBananaPlayerNames(), false)
        end)
    end)

    Players.PlayerRemoving:Connect(function(p)
        task.wait(0.3)
        pcall(function()
            Options.BananaTargetDropdown:Refresh(getBananaPlayerNames(), false)
        end)
        if bananaTargetName == p.Name then bananaTargetName = "" end
    end)
end

-- =====================================================
-- ★★★ ESP タブ：3D Box（小さめ + アウトライン付き） ★★★
-- =====================================================
do
    local BoxGroup = Tabs.ESP:AddLeftGroupbox('3D Box ESP')

    local boxEnabled = false
    local boxColor = Color3.fromRGB(255, 255, 255)
    local boxTransparency = 0.3
    local boxRange = 2000
    local boxScale = 0.85        -- ★ 箱の縮小率（0.85 = 少し小さめ）
    local showOutline = true
    local outlineColor = Color3.fromRGB(0, 0, 0)

    local playerBoxes = {}

    local function removeBox(player)
        local data = playerBoxes[player]
        if not data then return end
        for _, ad in ipairs(data) do
            pcall(function() ad:Destroy() end)
        end
        playerBoxes[player] = nil
    end

    local function applyBox(player)
        local char = player.Character
        if not char then return end

        removeBox(player)

        local _, size = char:GetBoundingBox()
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        -- ★ サイズを縮小
        local scaledSize = Vector3.new(size.X, size.Y, size.Z) * boxScale

        -- 透明な Part を作成
        local part = Instance.new("Part")
        part.Name = "OrynESPBox"
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.Transparency = 1
        part.Size = scaledSize
        part.CFrame = hrp.CFrame
        part.Parent = Workspace

        local adornments = {}

        -- ★ アウトライン（外側の黒枠）
        if showOutline then
            local outline = Instance.new("BoxHandleAdornment")
            outline.Name = "Oryn3DBoxOutline"
            outline.Adornee = part
            outline.AlwaysOnTop = true
            outline.ZIndex = 4
            outline.Size = scaledSize + Vector3.new(0.1, 0.1, 0.1)  -- 少し大きく
            outline.Transparency = 0.5
            outline.Color3 = outlineColor
            outline.Parent = part
            table.insert(adornments, outline)
        end

        -- ★ 本体（内側の色付き枠）
        local box = Instance.new("BoxHandleAdornment")
        box.Name = "Oryn3DBox"
        box.Adornee = part
        box.AlwaysOnTop = true
        box.ZIndex = 5
        box.Size = scaledSize
        box.Transparency = boxTransparency
        box.Color3 = boxColor
        box.Parent = part
        table.insert(adornments, box)

        adornments.part = part
        playerBoxes[player] = adornments
    end

    RunService.RenderStepped:Connect(function()
        if not boxEnabled then
            for player in pairs(playerBoxes) do
                removeBox(player)
            end
            return
        end

        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end

            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if not (hrp and hum) or hum.Health <= 0 then
                removeBox(player)
                continue
            end

            local dist = (hrp.Position - Camera.CFrame.Position).Magnitude
            if dist > boxRange then
                removeBox(player)
                continue
            end

            if not playerBoxes[player] then
                applyBox(player)
            else
                local data = playerBoxes[player]
                if not data.part or not data.part.Parent then
                    applyBox(player)
                else
                    -- 箱を HRP に追従
                    data.part.CFrame = hrp.CFrame

                    -- 色・透明度・サイズを更新
                    for _, ad in ipairs(data) do
                        if ad and ad.Parent then
                            if ad.Name == "Oryn3DBoxOutline" then
                                ad.Color3 = outlineColor
                                ad.Size = data.part.Size + Vector3.new(0.1, 0.1, 0.1)
                                ad.Enabled = showOutline
                            else
                                ad.Color3 = boxColor
                                ad.Transparency = boxTransparency
                                ad.Size = data.part.Size
                            end
                        end
                    end
                end
            end
        end

        for player in pairs(playerBoxes) do
            if not player.Parent then
                removeBox(player)
            end
        end
    end)

    BoxGroup:AddToggle('BoxESPEnabled', {
        Text = 'Enable 3D Box',
        Default = false,
        Callback = function(v) boxEnabled = v end,
    })

    BoxGroup:AddLabel('Box Color'):AddColorPicker('BoxESPColor', {
        Default = Color3.fromRGB(255, 255, 255),
        Title = 'Box Color',
        Callback = function(c) boxColor = c end,
    })

    BoxGroup:AddSlider('BoxESPTransparency', {
        Text = 'Transparency',
        Default = 30, Min = 0, Max = 100, Rounding = 0, Suffix = '%',
        Callback = function(v) boxTransparency = v / 100 end,
    })

    BoxGroup:AddSlider('BoxESPScale', {
        Text = 'Box Scale',
        Default = 85, Min = 50, Max = 150, Rounding = 0, Suffix = '%',
        Callback = function(v) boxScale = v / 100 end,
    })

    BoxGroup:AddSlider('BoxESPRange', {
        Text = 'Max Distance',
        Default = 2000, Min = 100, Max = 10000, Rounding = 0, Suffix = ' studs',
        Callback = function(v) boxRange = v end,
    })

    BoxGroup:AddDivider()

    BoxGroup:AddToggle('BoxESPOutline', {
        Text = 'Show Outline',
        Default = true,
        Callback = function(v) showOutline = v end,
    })

    BoxGroup:AddLabel('Outline Color'):AddColorPicker('BoxESPOutlineColor', {
        Default = Color3.fromRGB(0, 0, 0),
        Title = 'Outline Color',
        Callback = function(c) outlineColor = c end,
    })

    -- Unload 対応
    _G.OrynState.flags.cleanupBoxESP = function()
        for player in pairs(playerBoxes) do
            removeBox(player)
        end
    end
end
print('Oryn HUB Loaded')