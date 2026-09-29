local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local IMAGE_URL = "rbxassetid://138823883244540"
local TG_LINK = "t.me/neutron_client"

-- ============ АВТО-МАСШТАБ ПОД РАЗРЕШЕНИЕ ============
local SCALE = 1
local screenResText = "0x0"

local function getScale()
    local vp = Camera.ViewportSize
    local diag = math.sqrt(vp.X * vp.X + vp.Y * vp.Y)
    local scale = diag / (1920 * 1.4)
    if scale < 1 then scale = 1 end
    if scale > 3.5 then scale = 3.5 end
    screenResText = string.format("%dx%d", math.floor(vp.X), math.floor(vp.Y))
    return scale
end

SCALE = getScale()

Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    SCALE = getScale()
end)

local Config = {
    ESP = {
        Enabled     = false,
        Box         = true,
        Name        = false,
        Distance    = false,
        Health      = false,
        Tracer      = false,
        Skeleton    = false,
        Head        = false,
        MaxDistance = 500,
    },
    Aimbot = {
        Enabled     = false,
        Smoothness  = 8,
        FOV         = 60,
        VisibleOnly = true,
        TargetPart  = "Torso",
        ReactionDelay = 0.15,
        AimJitter   = 0.008,
    },
}

local ESPObjects = {}
local FOVCircle = nil
local Open = true
local CompletelyClosed = false
local aimStartTime = 0
local aiming = false

local function resolveTargetPart(char, targetName)
    if not char then return nil end
    if targetName == "Head" then
        return char:FindFirstChild("Head")
    elseif targetName == "Torso" then
        return char:FindFirstChild("UpperTorso")
            or char:FindFirstChild("Torso")
            or char:FindFirstChild("LowerTorso")
            or char:FindFirstChild("HumanoidRootPart")
    end
    return char:FindFirstChild(targetName)
end

-- ============ ESP ============
local SKELETON_BONES = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"},
}

local function isR15(char)
    return char:FindFirstChild("UpperTorso") ~= nil
end

local function makeLine()
    local l = Drawing.new("Line")
    l.Thickness = math.max(1, math.floor(1.5 * SCALE))
    l.Color = Color3.fromRGB(255, 255, 255)
    l.Transparency = 1
    l.Visible = false
    return l
end

local function createESP(player)
    if player == LocalPlayer then return end
    if ESPObjects[player] then return end

    local data = {}

    data.Box = Drawing.new("Square")
    data.Box.Thickness = math.max(1, 1.5 * SCALE)
    data.Box.Color = Color3.fromRGB(0, 255, 200)
    data.Box.Filled = false
    data.Box.Transparency = 1
    data.Box.Visible = false

    data.Name = Drawing.new("Text")
    data.Name.Size = math.floor(14 * SCALE)
    data.Name.Center = true
    data.Name.Outline = true
    data.Name.Color = Color3.fromRGB(255, 255, 255)
    data.Name.Visible = false

    data.Distance = Drawing.new("Text")
    data.Distance.Size = math.floor(13 * SCALE)
    data.Distance.Center = true
    data.Distance.Outline = true
    data.Distance.Color = Color3.fromRGB(200, 200, 200)
    data.Distance.Visible = false

    data.HealthBG = makeLine()
    data.HealthBG.Thickness = math.max(2, 3 * SCALE)
    data.HealthBG.Color = Color3.fromRGB(0, 0, 0)

    data.HealthBar = makeLine()
    data.HealthBar.Thickness = math.max(2, 3 * SCALE)
    data.HealthBar.Color = Color3.fromRGB(0, 255, 0)

    data.Tracer = makeLine()
    data.Tracer.Color = Color3.fromRGB(0, 255, 200)

    data.SkeletonLines = {}
    for i = 1, #SKELETON_BONES do
        data.SkeletonLines[i] = makeLine()
    end

    data.HeadCircle = Drawing.new("Circle")
    data.HeadCircle.Thickness = math.max(1, 1.5 * SCALE)
    data.HeadCircle.NumSides = 24
    data.HeadCircle.Radius = 10 * SCALE
    data.HeadCircle.Filled = false
    data.HeadCircle.Color = Color3.fromRGB(255, 255, 255)
    data.HeadCircle.Transparency = 1
    data.HeadCircle.Visible = false

    ESPObjects[player] = data
end

local function removeESP(player)
    local obj = ESPObjects[player]
    if not obj then return end
    for key, draw in pairs(obj) do
        if typeof(draw) == "table" then
            for _, d in pairs(draw) do
                pcall(function() d:Remove() end)
            end
        else
            pcall(function() draw:Remove() end)
        end
    end
    ESPObjects[player] = nil
end

local function hideAll(obj)
    obj.Box.Visible = false
    obj.Name.Visible = false
    obj.Distance.Visible = false
    obj.HealthBG.Visible = false
    obj.HealthBar.Visible = false
    obj.Tracer.Visible = false
    obj.HeadCircle.Visible = false
    for _, line in pairs(obj.SkeletonLines) do
        line.Visible = false
    end
end

local function makeBaseIgnore()
    local list = {}
    if LocalPlayer.Character then table.insert(list, LocalPlayer.Character) end
    if Camera then table.insert(list, Camera) end
    return list
end

local function isVisible(targetChar)
    if not targetChar then return false end
    if not LocalPlayer.Character then return false end

    local myChar = LocalPlayer.Character
    local myHead = myChar:FindFirstChild("Head")
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")

    local origin
    if myHead then
        origin = myHead.Position
    elseif myRoot then
        origin = myRoot.Position
    else
        origin = Camera.CFrame.Position
    end

    local targetPoints = {}
    local h  = targetChar:FindFirstChild("Head")
    local ut = targetChar:FindFirstChild("UpperTorso")
    local lt = targetChar:FindFirstChild("LowerTorso")
    local t  = targetChar:FindFirstChild("Torso")
    local r  = targetChar:FindFirstChild("HumanoidRootPart")

    if h  then table.insert(targetPoints, h.Position)  end
    if ut then table.insert(targetPoints, ut.Position) end
    if t  then table.insert(targetPoints, t.Position)  end
    if lt then table.insert(targetPoints, lt.Position) end
    if r  then table.insert(targetPoints, r.Position)  end

    if #targetPoints == 0 then return false end

    local ignoreList = makeBaseIgnore()
    table.insert(ignoreList, targetChar)

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = ignoreList
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true

    for _, tp in ipairs(targetPoints) do
        local result = Workspace:Raycast(origin, tp - origin, params)
        if result == nil then
            return true
        end
    end
    return false
end

local function worldToScreen(pos)
    local sp, onScreen = Camera:WorldToViewportPoint(pos)
    if onScreen then
        return Vector2.new(sp.X, sp.Y)
    end
    return nil
end

local function getBodyFrame(char)
    local head = char:FindFirstChild("Head")
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    if not head or not hrp then return nil end

    local headPos, headOnScreen = Camera:WorldToViewportPoint(head.Position)
    if not headOnScreen then return nil end

    local lowestY = nil
    local lowestPos = nil

    local lowerCandidates = {
        "LeftFoot", "RightFoot",
        "LeftLowerLeg", "RightLowerLeg",
        "LeftLeg", "RightLeg",
        "LowerTorso", "Torso",
        "HumanoidRootPart",
    }

    for _, name in ipairs(lowerCandidates) do
        local part = char:FindFirstChild(name)
        if part then
            local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen then
                if lowestY == nil or sp.Y > lowestY then
                    lowestY = sp.Y
                    lowestPos = sp
                end
            end
        end
    end

    if not lowestPos then
        local sp, onScreen = Camera:WorldToViewportPoint(hrp.Position)
        if onScreen then
            lowestPos = sp
            lowestY = sp.Y
        else
            return nil
        end
    end

    local height = math.abs(lowestY - headPos.Y)
    if height < 4 then
        height = 6 * SCALE
    end

    local width = height * 0.55
    local centerX = headPos.X

    local top = Vector2.new(centerX - width / 2, headPos.Y)
    local bottom = Vector2.new(centerX + width / 2, headPos.Y + height)

    return {
        top = top,
        bottom = bottom,
        centerX = centerX,
        height = height,
        width = width,
    }
end

local function updateESP()
    for player, obj in pairs(ESPObjects) do
        if not Config.ESP.Enabled then hideAll(obj); continue end

        local char = player.Character
        if not char then hideAll(obj); continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then hideAll(obj); continue end

        local distance = (Camera.CFrame.Position - hrp.Position).Magnitude
        if distance > Config.ESP.MaxDistance then hideAll(obj); continue end

        local frame = getBodyFrame(char)

        if frame then
            local top = frame.top
            local bottom = frame.bottom

            if Config.ESP.Box then
                obj.Box.Size = Vector2.new(bottom.X - top.X, bottom.Y - top.Y)
                obj.Box.Position = top
                obj.Box.Thickness = math.max(1, 1.5 * SCALE)
                obj.Box.Visible = true
            else
                obj.Box.Visible = false
            end

            if Config.ESP.Name then
                obj.Name.Text = player.Name
                obj.Name.Size = math.floor(14 * SCALE)
                obj.Name.Position = Vector2.new(frame.centerX, top.Y - 20 * SCALE)
                obj.Name.Visible = true
            else
                obj.Name.Visible = false
            end

            if Config.ESP.Distance then
                obj.Distance.Text = string.format("[%d m]", math.floor(distance))
                obj.Distance.Size = math.floor(13 * SCALE)
                obj.Distance.Position = Vector2.new(frame.centerX, bottom.Y + 2 * SCALE)
                obj.Distance.Visible = true
            else
                obj.Distance.Visible = false
            end

            if Config.ESP.Health then
                local pct = hum.Health / math.max(hum.MaxHealth, 1)
                if pct < 0 then pct = 0 end
                if pct > 1 then pct = 1 end

                local barHeight = bottom.Y - top.Y
                local offset = 6 * SCALE

                obj.HealthBG.Thickness = math.max(2, 3 * SCALE)
                obj.HealthBG.From = Vector2.new(top.X - offset, top.Y)
                obj.HealthBG.To   = Vector2.new(top.X - offset, bottom.Y)
                obj.HealthBG.Visible = true

                obj.HealthBar.Thickness = math.max(2, 3 * SCALE)
                obj.HealthBar.From = Vector2.new(top.X - offset, bottom.Y - barHeight * pct)
                obj.HealthBar.To   = Vector2.new(top.X - offset, bottom.Y)
                obj.HealthBar.Color = Color3.fromRGB(
                    math.floor(255 * (1 - pct)),
                    math.floor(255 * pct),
                    0
                )
                obj.HealthBar.Visible = true
            else
                obj.HealthBar.Visible = false
                obj.HealthBG.Visible = false
            end

            if Config.ESP.Tracer then
                obj.Tracer.Thickness = math.max(1, 1.5 * SCALE)
                obj.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                obj.Tracer.To   = Vector2.new(frame.centerX, bottom.Y)
                obj.Tracer.Visible = true
            else
                obj.Tracer.Visible = false
            end
        else
            obj.Box.Visible = false
            obj.Name.Visible = false
            obj.Distance.Visible = false
            obj.HealthBar.Visible = false
            obj.HealthBG.Visible = false
            obj.Tracer.Visible = false
        end

        if Config.ESP.Skeleton and isR15(char) then
            for i, bone in ipairs(SKELETON_BONES) do
                local a = char:FindFirstChild(bone[1])
                local b = char:FindFirstChild(bone[2])
                local line = obj.SkeletonLines[i]
                if a and b then
                    local pa = worldToScreen(a.Position)
                    local pb = worldToScreen(b.Position)
                    if pa and pb then
                        line.From = pa
                        line.To = pb
                        line.Thickness = math.max(1, 1.5 * SCALE)
                        line.Visible = true
                    else
                        line.Visible = false
                    end
                else
                    line.Visible = false
                end
            end
        else
            for _, line in pairs(obj.SkeletonLines) do
                line.Visible = false
            end
        end

        if Config.ESP.Head then
            local head = char:FindFirstChild("Head")
            if head then
                local p = worldToScreen(head.Position)
                if p and frame then
                    local headSize = frame.height * 0.16
                    obj.HeadCircle.Position = p
                    obj.HeadCircle.Radius = math.max(headSize, 8 * SCALE)
                    obj.HeadCircle.Thickness = math.max(1, 1.5 * SCALE)
                    obj.HeadCircle.Visible = true
                else
                    obj.HeadCircle.Visible = false
                end
            else
                obj.HeadCircle.Visible = false
            end
        else
            obj.HeadCircle.Visible = false
        end
    end
end

-- ============ AIMBOT ============
local function getClosestTarget()
    local closest, shortestDist = nil, math.huge
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end

        local char = player.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end

        local part = resolveTargetPart(char, Config.Aimbot.TargetPart)
        if not part then continue end

        if Config.Aimbot.VisibleOnly then
            if not isVisible(char) then continue end
        end

        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end

        local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        if dist < shortestDist and dist <= Config.Aimbot.FOV then
            shortestDist = dist
            closest = part
        end
    end
    return closest
end

local function doAimbot()
    if not Config.Aimbot.Enabled then return end

    if aiming then
        if os.clock() - aimStartTime < Config.Aimbot.ReactionDelay then
            return
        end
    end

    local target = getClosestTarget()
    if not target then return end

    local lerpAmount = 0.825 - (Config.Aimbot.Smoothness * 0.075)
    if lerpAmount < 0.05 then lerpAmount = 0.05 end
    if lerpAmount > 1 then lerpAmount = 1 end

    local jitter = Config.Aimbot.AimJitter
    local targetPos = target.Position + Vector3.new(
        (math.random() - 0.5) * jitter,
        (math.random() - 0.5) * jitter,
        (math.random() - 0.5) * jitter
    )

    local aimCFrame = CFrame.new(Camera.CFrame.Position, targetPos)
    Camera.CFrame = Camera.CFrame:Lerp(aimCFrame, lerpAmount)
end

local function createFOVCircle()
    if FOVCircle then FOVCircle:Remove() end
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Thickness = math.max(1, 1.5 * SCALE)
    FOVCircle.NumSides = 60
    FOVCircle.Radius = Config.Aimbot.FOV
    FOVCircle.Filled = false
    FOVCircle.Color = Color3.fromRGB(0, 255, 200)
    FOVCircle.Transparency = 0.7
    FOVCircle.Visible = false
end
createFOVCircle()

-- ============ UI ============
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NeutronHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")

local ToggleBtn = Instance.new("ImageButton")
ToggleBtn.Size = UDim2.new(0, 46, 0, 46)
ToggleBtn.Position = UDim2.new(0, 12, 0.4, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
ToggleBtn.BorderSizePixel = 0
ToggleBtn.Image = IMAGE_URL
ToggleBtn.ScaleType = Enum.ScaleType.Fit
ToggleBtn.AutoButtonColor = false
ToggleBtn.Active = true
ToggleBtn.Parent = ScreenGui

local tbCorner = Instance.new("UICorner")
tbCorner.CornerRadius = UDim.new(1, 0)
tbCorner.Parent = ToggleBtn

local tbStroke = Instance.new("UIStroke")
tbStroke.Color = Color3.fromRGB(0, 255, 200)
tbStroke.Thickness = 1.5
tbStroke.Transparency = 0.3
tbStroke.Parent = ToggleBtn

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 260, 0, 330)
Main.Position = UDim2.new(0.5, -130, 0.5, -165)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Main.BorderSizePixel = 0
Main.Active = true
Main.ClipsDescendants = true
Main.Parent = ScreenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 14)
mainCorner.Parent = Main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(0, 255, 200)
mainStroke.Thickness = 1.5
mainStroke.Transparency = 0.4
mainStroke.Parent = Main

local TopBar = Instance.new("Frame")
TopBar.Name = "DragBar"
TopBar.Size = UDim2.new(1, 0, 0, 42)
TopBar.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
TopBar.BorderSizePixel = 0
TopBar.Active = true
TopBar.Parent = Main

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 14)
topCorner.Parent = TopBar

local topFix = Instance.new("Frame")
topFix.Size = UDim2.new(1, 0, 0, 14)
topFix.Position = UDim2.new(0, 0, 1, -14)
topFix.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
topFix.BorderSizePixel = 0
topFix.Parent = TopBar

local TopIcon = Instance.new("ImageLabel")
TopIcon.Size = UDim2.new(0, 26, 0, 26)
TopIcon.Position = UDim2.new(0, 10, 0.5, -13)
TopIcon.BackgroundTransparency = 1
TopIcon.Image = IMAGE_URL
TopIcon.ScaleType = Enum.ScaleType.Fit
TopIcon.Parent = TopBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -160, 1, 0)
Title.Position = UDim2.new(0, 42, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "NEUTRON HUB"
Title.TextColor3 = Color3.fromRGB(0, 255, 200)
Title.TextSize = 15
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -36, 0.5, -15)
CloseBtn.BackgroundTransparency = 1
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 90, 90)
CloseBtn.TextSize = 24
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = TopBar

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 30, 0, 30)
MinimizeBtn.Position = UDim2.new(1, -84, 0.5, -15)
MinimizeBtn.BackgroundTransparency = 1
MinimizeBtn.BorderSizePixel = 0
MinimizeBtn.Text = "—"
MinimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
MinimizeBtn.TextSize = 24
MinimizeBtn.Font = Enum.Font.
