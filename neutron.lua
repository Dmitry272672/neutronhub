-- NEUTRON HUB | Mobile Script
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
Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function() SCALE = getScale() end)

local Config = {
    ESP = {
        Enabled = false, Box = true, Name = false, Distance = false,
        Health = false, Tracer = false, Skeleton = false, Head = false,
        MaxDistance = 500,
    },
    Aimbot = {
        Enabled = false, Smoothness = 8, FOV = 60,
        VisibleOnly = true, TargetPart = "Torso",
    },
}

local ESPObjects = {}
local FOVCircle = nil
local Open = true
local CompletelyClosed = false

local function resolveTargetPart(char, targetName)
    if not char then return nil end
    if targetName == "Head" then return char:FindFirstChild("Head") end
    if targetName == "Torso" then
        return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
            or char:FindFirstChild("LowerTorso") or char:FindFirstChild("HumanoidRootPart")
    end
    return char:FindFirstChild(targetName)
end

local SKELETON_BONES = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"UpperTorso","LeftUpperArm"},
    {"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},{"UpperTorso","RightUpperArm"},
    {"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},{"LowerTorso","LeftUpperLeg"},
    {"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},{"LowerTorso","RightUpperLeg"},
    {"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}

local function isR15(c) return c:FindFirstChild("UpperTorso") ~= nil end

local function makeLine()
    local l = Drawing.new("Line")
    l.Thickness = math.max(1, math.floor(1.5 * SCALE))
    l.Color = Color3.fromRGB(255,255,255)
    l.Transparency = 1
    l.Visible = false
    return l
end

local function createESP(player)
    if player == LocalPlayer then return end
    if ESPObjects[player] then return end
    local d = {}
    d.Box = Drawing.new("Square")
    d.Box.Thickness = math.max(1, 1.5*SCALE)
    d.Box.Color = Color3.fromRGB(0,255,200)
    d.Box.Filled = false
    d.Box.Transparency = 1
    d.Box.Visible = false
    d.Name = Drawing.new("Text")
    d.Name.Size = math.floor(14*SCALE)
    d.Name.Center = true
    d.Name.Outline = true
    d.Name.Color = Color3.fromRGB(255,255,255)
    d.Name.Visible = false
    d.Distance = Drawing.new("Text")
    d.Distance.Size = math.floor(13*SCALE)
    d.Distance.Center = true
    d.Distance.Outline = true
    d.Distance.Color = Color3.fromRGB(200,200,200)
    d.Distance.Visible = false
    d.HealthBG = makeLine()
    d.HealthBG.Thickness = math.max(2, 3*SCALE)
    d.HealthBG.Color = Color3.fromRGB(0,0,0)
    d.HealthBar = makeLine()
    d.HealthBar.Thickness = math.max(2, 3*SCALE)
    d.HealthBar.Color = Color3.fromRGB(0,255,0)
    d.Tracer = makeLine()
    d.Tracer.Color = Color3.fromRGB(0,255,200)
    d.SkeletonLines = {}
    for i = 1, #SKELETON_BONES do d.SkeletonLines[i] = makeLine() end
    d.HeadCircle = Drawing.new("Circle")
    d.HeadCircle.Thickness = math.max(1, 1.5*SCALE)
    d.HeadCircle.NumSides = 24
    d.HeadCircle.Radius = 10*SCALE
    d.HeadCircle.Filled = false
    d.HeadCircle.Color = Color3.fromRGB(255,255,255)
    d.HeadCircle.Transparency = 1
    d.HeadCircle.Visible = false
    ESPObjects[player] = d
end

local function removeESP(player)
    local o = ESPObjects[player]
    if not o then return end
    for k, v in pairs(o) do
        if typeof(v) == "table" then
            for _, x in pairs(v) do pcall(function() x:Remove() end) end
        else
            pcall(function() v:Remove() end)
        end
    end
    ESPObjects[player] = nil
end

local function hideAll(o)
    o.Box.Visible = false
    o.Name.Visible = false
    o.Distance.Visible = false
    o.HealthBG.Visible = false
    o.HealthBar.Visible = false
    o.Tracer.Visible = false
    o.HeadCircle.Visible = false
    for _, l in pairs(o.SkeletonLines) do l.Visible = false end
end

local function makeBaseIgnore()
    local t = {}
    if LocalPlayer.Character then table.insert(t, LocalPlayer.Character) end
    if Camera then table.insert(t, Camera) end
    return t
end

local function isVisible(tc)
    if not tc or not LocalPlayer.Character then return false end
    local mc = LocalPlayer.Character
    local mh = mc:FindFirstChild("Head") or mc:FindFirstChild("HumanoidRootPart")
    if not mh then return false end
    local origin = mh.Position
    local pts = {}
    for _, n in ipairs({"Head","UpperTorso","Torso","LowerTorso","HumanoidRootPart"}) do
        local p = tc:FindFirstChild(n)
        if p then table.insert(pts, p.Position) end
    end
    if #pts == 0 then return false end
    local il = makeBaseIgnore()
    table.insert(il, tc)
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = il
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.IgnoreWater = true
    for _, tp in ipairs(pts) do
        if Workspace:Raycast(origin, tp - origin, rp) == nil then return true end
    end
    return false
end

local function w2s(p)
    local sp, on = Camera:WorldToViewportPoint(p)
    if on then return Vector2.new(sp.X, sp.Y) end
    return nil
end

local function getBodyFrame(char)
    local h = char:FindFirstChild("Head")
    local r = char:FindFirstChild("HumanoidRootPart")
    if not h or not r then return nil end
    local hp, hon = Camera:WorldToViewportPoint(h.Position)
    if not hon then return nil end
    local lowY = nil
    for _, n in ipairs({"LeftFoot","RightFoot","LeftLowerLeg","RightLowerLeg","LeftLeg","RightLeg","LowerTorso","Torso","HumanoidRootPart"}) do
        local p = char:FindFirstChild(n)
        if p then
            local sp, on = Camera:WorldToViewportPoint(p.Position)
            if on and (lowY == nil or sp.Y > lowY) then lowY = sp.Y end
        end
    end
    if not lowY then
        local sp, on = Camera:WorldToViewportPoint(r.Position)
        if on then lowY = sp.Y else return nil end
    end
    local hgt = math.abs(lowY - hp.Y)
    if hgt < 4 then hgt = 6*SCALE end
    local w = hgt * 0.55
    local cx = hp.X
    return {
        top = Vector2.new(cx - w/2, hp.Y),
        bottom = Vector2.new(cx + w/2, hp.Y + hgt),
        centerX = cx, height = hgt,
    }
end

local function updateESP()
    for p, o in pairs(ESPObjects) do
        if not Config.ESP.Enabled then hideAll(o); continue end
        local c = p.Character
        if not c then hideAll(o); continue end
        local r = c:FindFirstChild("HumanoidRootPart")
        local hum = c:FindFirstChildOfClass("Humanoid")
        if not r or not hum or hum.Health <= 0 then hideAll(o); continue end
        local dist = (Camera.CFrame.Position - r.Position).Magnitude
        if dist > Config.ESP.MaxDistance then hideAll(o); continue end
        local f = getBodyFrame(c)
        if f then
            local t = f.top
            local b = f.bottom
            if Config.ESP.Box then
                o.Box.Size = Vector2.new(b.X - t.X, b.Y - t.Y)
                o.Box.Position = t
                o.Box.Visible = true
            else o.Box.Visible = false end
            if Config.ESP.Name then
                o.Name.Text = p.Name
                o.Name.Position = Vector2.new(f.centerX, t.Y - 20*SCALE)
                o.Name.Visible = true
            else o.Name.Visible = false end
            if Config.ESP.Distance then
                o.Distance.Text = string.format("[%d m]", math.floor(dist))
                o.Distance.Position = Vector2.new(f.centerX, b.Y + 2*SCALE)
                o.Distance.Visible = true
            else o.Distance.Visible = false end
            if Config.ESP.Health then
                local pc = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                local bh = b.Y - t.Y
                local off = 6*SCALE
                o.HealthBG.From = Vector2.new(t.X - off, t.Y)
                o.HealthBG.To = Vector2.new(t.X - off, b.Y)
                o.HealthBG.Visible = true
                o.HealthBar.From = Vector2.new(t.X - off, b.Y - bh * pc)
                o.HealthBar.To = Vector2.new(t.X - off, b.Y)
                o.HealthBar.Color = Color3.fromRGB(math.floor(255*(1-pc)), math.floor(255*pc), 0)
                o.HealthBar.Visible = true
            else
                o.HealthBar.Visible = false
                o.HealthBG.Visible = false
            end
            if Config.ESP.Tracer then
                o.Tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                o.Tracer.To = Vector2.new(f.centerX, b.Y)
                o.Tracer.Visible = true
            else o.Tracer.Visible = false end
        else
            o.Box.Visible = false
            o.Name.Visible = false
            o.Distance.Visible = false
            o.HealthBar.Visible = false
            o.HealthBG.Visible = false
            o.Tracer.Visible = false
        end
        if Config.ESP.Skeleton and isR15(c) then
            for i, bone in ipairs(SKELETON_BONES) do
                local a = c:FindFirstChild(bone[1])
                local b = c:FindFirstChild(bone[2])
                local line = o.SkeletonLines[i]
                if a and b then
                    local pa = w2s(a.Position)
                    local pb = w2s(b.Position)
                    if pa and pb then
                        line.From = pa
                        line.To = pb
                        line.Visible = true
                    else line.Visible = false end
                else line.Visible = false end
            end
        else
            for _, l in pairs(o.SkeletonLines) do l.Visible = false end
        end
        if Config.ESP.Head then
            local hd = c:FindFirstChild("Head")
            if hd then
                local pt = w2s(hd.Position)
                if pt and f then
                    o.HeadCircle.Position = pt
                    o.HeadCircle.Radius = math.max(f.height * 0.16, 8*SCALE)
                    o.HeadCircle.Visible = true
                else o.HeadCircle.Visible = false end
            else o.HeadCircle.Visible = false end
        else o.HeadCircle.Visible = false end
    end
end

local function getClosestTarget()
    local closest, sDist = nil, math.huge
    local cn = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    for _, p in pairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        local c = p.Character
        if not c then continue end
        local hum = c:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local part = resolveTargetPart(c, Config.Aimbot.TargetPart)
        if not part then continue end
        if Config.Aimbot.VisibleOnly and not isVisible(c) then continue end
        local sp, on = Camera:WorldToViewportPoint(part.Position)
        if not on then continue end
        local d = (Vector2.new(sp.X, sp.Y) - cn).Magnitude
        if d < sDist and d <= Config.Aimbot.FOV then sDist = d; closest = part end
    end
    return closest
end

local function doAimbot()
    if not Config.Aimbot.Enabled then return end
    local t = getClosestTarget()
    if not t then return end
    local la = math.clamp(0.825 - (Config.Aimbot.Smoothness * 0.075), 0.05, 1)
    local jit = 0.008
    local tp = t.Position + Vector3.new((math.random()-0.5)*jit, (math.random()-0.5)*jit, (math.random()-0.5)*jit)
    Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, tp), la)
end

local function createFOVCircle()
    if FOVCircle then FOVCircle:Remove() end
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Thickness = math.max(1, 1.5*SCALE)
    FOVCircle.NumSides = 60
    FOVCircle.Radius = Config.Aimbot.FOV
    FOVCircle.Filled = false
    FOVCircle.Color = Color3.fromRGB(0,255,200)
    FOVCircle.Transparency = 0.7
    FOVCircle.Visible = false
end
createFOVCircle()

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Neutron"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")

local ToggleBtn = Instance.new("ImageButton")
ToggleBtn.Size = UDim2.new(0, 46, 0, 46)
ToggleBtn.Position = UDim2.new(0, 12, 0.4, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(15,15,20)
ToggleBtn.BorderSizePixel = 0
ToggleBtn.Image = IMAGE_URL
ToggleBtn.ScaleType = Enum.ScaleType.Fit
ToggleBtn.AutoButtonColor = false
ToggleBtn.Active = true
ToggleBtn.Parent = ScreenGui

local tbCorner = Instance.new("UICorner")
tbCorner.CornerRadius = UDim.new(1,0)
tbCorner.Parent = ToggleBtn
local tbStroke = Instance.new("UIStroke")
tbStroke.Color = Color3.fromRGB(0,255,200)
tbStroke.Thickness = 1.5
tbStroke.Transparency = 0.3
tbStroke.Parent = ToggleBtn

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 260, 0, 330)
Main.Position = UDim2.new(0.5, -130, 0.5, -165)
Main.BackgroundColor3 = Color3.fromRGB(15,15,20)
Main.BorderSizePixel = 0
Main.Active = true
Main.ClipsDescendants = true
Main.Parent = ScreenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0,14)
mainCorner.Parent = Main
local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(0,255,200)
mainStroke.Thickness = 1.5
mainStroke.Transparency = 0.4
mainStroke.Parent = Main

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 42)
TopBar.BackgroundColor3 = Color3.fromRGB(22,22,30)
TopBar.BorderSizePixel = 0
TopBar.Active = true
TopBar.Parent = Main

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0,14)
topCorner.Parent = TopBar
local topFix = Instance.new("Frame")
topFix.Size = UDim2.new(1, 0, 0, 14)
topFix.Position = UDim2.new(0, 0, 1, -14)
topFix.BackgroundColor3 = Color3.fromRGB(22,22,30)
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
Title.Text = "NEUTRON"
Title.TextColor3 = Color3.fromRGB(0,255,200)
Title.TextSize = 15
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -36, 0.5, -15)
CloseBtn.BackgroundTransparency = 1
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255,90,90)
CloseBtn.TextSize = 24
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = TopBar

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 30, 0, 30)
MinimizeBtn.Position = UDim2.new(1, -84, 0.5, -15)
MinimizeBtn.BackgroundTransparency = 1
MinimizeBtn.BorderSizePixel = 0
MinimizeBtn.Text = "-"
MinimizeBtn.TextColor3 = Color3.fromRGB(200,200,200)
MinimizeBtn.TextSize = 24
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.AutoButtonColor = false
MinimizeBtn.Parent = TopBar

local TabsFrame = Instance.new("Frame")
TabsFrame.Size = UDim2.new(0, 72, 1, -50)
TabsFrame.Position = UDim2.new(0, 6, 0, 46)
TabsFrame.BackgroundColor3 = Color3.fromRGB(18,18,24)
TabsFrame.BorderSizePixel = 0
TabsFrame.Parent = Main

local tabsCorner = Instance.new("UICorner")
tabsCorner.CornerRadius = UDim.new(0,10)
tabsCorner.Parent = TabsFrame
local TabsList = Instance.new("UIListLayout")
TabsList.Padding = UDim.new(0, 4)
TabsList.SortOrder = Enum.SortOrder.LayoutOrder
TabsList.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabsList.Parent = TabsFrame
local TabsPad = Instance.new("UIPadding")
TabsPad.PaddingTop = UDim.new(0, 8)
TabsPad.Parent = TabsFrame

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -88, 1, -50)
Content.Position = UDim2.new(0, 82, 0, 46)
Content.BackgroundTransparency = 1
Content.ClipsDescendants = true
Content.Parent = Main

local btnDragging = false
local btnDragStart = nil
local btnStartPos = nil
local btnMoved = false

local function btnUpdateDrag(input)
    local delta = input.Position - btnDragStart
    if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then btnMoved = true end
    ToggleBtn.Position = UDim2.new(
        btnStartPos.X.Scale, btnStartPos.X.Offset + delta.X,
        btnStartPos.Y.Scale, btnStartPos.Y.Offset + delta.Y
    )
end

ToggleBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        btnDragging = true
        btnMoved = false
        btnDragStart = input.Position
        btnStartPos = ToggleBtn.Position
    end
end)
ToggleBtn.InputChanged:Connect(function(input)
    if btnDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch) then btnUpdateDrag(input) end
end)
ToggleBtn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then btnDragging = false end
end)
UserInputService.InputChanged:Connect(function(input)
    if btnDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch) then btnUpdateDrag(input) end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then btnDragging = false end
end)

local menuDragging = false
local menuDragStart = nil
local menuStartPos = nil

TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        menuDragging = true
        menuDragStart = input.Position
        menuStartPos = Main.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if menuDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - menuDragStart
        Main.Position = UDim2.new(
            menuStartPos.X.Scale, menuStartPos.X.Offset + delta.X,
            menuStartPos.Y.Scale, menuStartPos.Y.Offset + delta.Y
        )
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then menuDragging = false end
end)

local function makeTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 34)
    btn.BackgroundColor3 = Color3.fromRGB(25,25,33)
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(200,200,200)
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamBold
    btn.AutoButtonColor = false
    btn.Parent = TabsFrame
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0,8)
    c.Parent = btn
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Color3.fromRGB(0,255,200)
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = Content
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, 5)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = page
    local pd = Instance.new("UIPadding")
    pd.PaddingTop = UDim.new(0, 4)
    pd.PaddingRight = UDim.new(0, 6)
    pd.PaddingBottom = UDim.new(0, 4)
    pd.Parent = page
    return {Button = btn, Page = page}
end

local Visual = makeTab("ESP")
local Combat = makeTab("AIM")
local Misc = makeTab("MISC")
local allTabs = {Visual, Combat, Misc}

local function selectTab(tab)
    for _, t in pairs(allTabs) do
        t.Page.Visible = false
        TweenService:Create(t.Button, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(25,25,33),
            TextColor3 = Color3.fromRGB(200,200,200),
        }):Play()
    end
    tab.Page.Visible = true
    TweenService:Create(tab.Button, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(0,255,200),
        TextColor3 = Color3.fromRGB(15,15,20),
    }):Play()
end

Visual.Button.MouseButton1Click:Connect(function() selectTab(Visual) end)
Combat.Button.MouseButton1Click:Connect(function() selectTab(Combat) end)
Misc.Button.MouseButton1Click:Connect(function() selectTab(Misc) end)
selectTab(Visual)

local function addToggle(parent, text, default, callback)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 34)
    holder.BackgroundColor3 = Color3.fromRGB(22,22,30)
    holder.BorderSizePixel = 0
    holder.Parent = parent.Page
    local hc = Instance.new("UICorner")
    hc.CornerRadius = UDim.new(0,8)
    hc.Parent = holder
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(220,220,220)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = holder
    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 40, 0, 20)
    toggle.Position = UDim2.new(1, -50, 0.5, -10)
    toggle.BackgroundColor3 = Color3.fromRGB(40,40,50)
    toggle.BorderSizePixel = 0
    toggle.Text = ""
    toggle.AutoButtonColor = false
    toggle.Parent = holder
    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(1,0)
    tc.Parent = toggle
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(200,200,200)
    knob.BorderSizePixel = 0
    knob.Parent = toggle
    local kc = Instance.new("UICorner")
    kc.CornerRadius = UDim.new(1,0)
    kc.Parent = knob
    local state = default or false
    local function refresh()
        if state then
            TweenService:Create(toggle, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(0,255,200) }):Play()
            TweenService:Create(knob, TweenInfo.new(0.15), {
                Position = UDim2.new(1, -18, 0.5, -8),
                BackgroundColor3 = Color3.fromRGB(15,15,20),
            }):Play()
        else
            TweenService:Create(toggle, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(40,40,50) }):Play()
            TweenService:Create(knob, TweenInfo.new(0.15), {
                Position = UDim2.new(0, 2, 0.5, -8),
                BackgroundColor3 = Color3.fromRGB(200,200,200),
            }):Play()
        end
    end
    refresh()
    toggle.MouseButton1Click:Connect(function()
        state = not state
        refresh()
        if callback then callback(state) end
    end)
end

local function addSlider(parent, text, max, min, default, callback)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 48)
    holder.BackgroundColor3 = Color3.fromRGB(22,22,30)
    holder.BorderSizePixel = 0
    holder.Parent = parent.Page
    local hc = Instance.new("UICorner")
    hc.CornerRadius = UDim.new(0,8)
    hc.Parent = holder
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 0, 20)
    lbl.Position = UDim2.new(0, 10, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(220,220,220)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = holder
    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0, 50, 0, 20)
    valLbl.Position = UDim2.new(1, -56, 0, 4)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(default)
    valLbl.TextColor3 = Color3.fromRGB(0,255,200)
    valLbl.TextSize = 12
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = holder
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -20, 0, 6)
    bar.Position = UDim2.new(0, 10, 0, 30)
    bar.BackgroundColor3 = Color3.fromRGB(40,40,50)
    bar.BorderSizePixel = 0
    bar.Parent = holder
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(1,0)
    bc.Parent = bar
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0,255,200)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(1,0)
    fc.Parent = fill
    local drag = false
    local function upd(input)
        local rel = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local cur = math.floor(min + (max - min) * rel + 0.5)
        valLbl.Text = tostring(cur)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        if callback then callback(cur) end
    end
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            drag = true
            upd(input)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if drag and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then upd(input) end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then drag = false end
    end)
end
