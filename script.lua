--[[
    LUNYX ARSENAL V2
    Premium UI preview only.
    This file does not implement ESP, aimbot, player tracking, or target manipulation.
    RightShift = show/hide
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

if not Players.LocalPlayer then
    warn("[LUNYX] LocalPlayer is unavailable.")
    return
end

local Config = {
    ESPPreview = false,
    AimPreview = false,
    TeamCheck = true,
    FOV = 120,
    Smoothness = 8,
}

local GUI_NAME = "LunyxArsenalV2"
local parent = CoreGui

if typeof(gethui) == "function" then
    local ok, hui = pcall(gethui)
    if ok and hui then parent = hui end
end

local oldGui = parent:FindFirstChild(GUI_NAME)
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.Parent = parent

local connections = {}
local destroyed = false

local function connect(signal, callback)
    local c = signal:Connect(callback)
    table.insert(connections, c)
    return c
end

local function corner(instance, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = instance
end

local function stroke(instance, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness or 1
    s.Parent = instance
end

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(390, 340)
main.Position = UDim2.new(0.5, -195, 0.5, -170)
main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui
corner(main, 14)
stroke(main, Color3.fromRGB(190, 42, 55), 1.5)

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 74)
header.BackgroundColor3 = Color3.fromRGB(34, 17, 22)
header.BorderSizePixel = 0
header.Parent = main
corner(header, 14)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(18, 10)
title.Size = UDim2.new(1, -36, 0, 30)
title.Font = Enum.Font.GothamBold
title.Text = "LUNYX  /  ARSENAL"
title.TextColor3 = Color3.fromRGB(245, 75, 87)
title.TextSize = 19
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(19, 42)
subtitle.Size = UDim2.new(1, -38, 0, 18)
subtitle.Font = Enum.Font.Gotham
subtitle.Text = "PREMIUM CONTROL PANEL  •  V2.0"
subtitle.TextColor3 = Color3.fromRGB(157, 157, 168)
subtitle.TextSize = 9
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = header

local function button(text, position, size)
    local b = Instance.new("TextButton")
    b.Position = position
    b.Size = size
    b.BackgroundColor3 = Color3.fromRGB(39, 39, 48)
    b.BorderSizePixel = 0
    b.AutoButtonColor = true
    b.Font = Enum.Font.GothamSemibold
    b.TextColor3 = Color3.fromRGB(238, 238, 243)
    b.TextSize = 11
    b.Text = text
    b.Parent = main
    corner(b, 8)
    return b
end

local function label(text, position, size)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Position = position
    l.Size = size
    l.Font = Enum.Font.GothamSemibold
    l.TextColor3 = Color3.fromRGB(220, 220, 228)
    l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = text
    l.Parent = main
    return l
end

local espButton = button("ESP PREVIEW: OFF", UDim2.fromOffset(18, 92), UDim2.fromOffset(170, 40))
local aimButton = button("AIM PREVIEW: OFF", UDim2.fromOffset(202, 92), UDim2.fromOffset(170, 40))
local teamButton = button("TEAM CHECK: ON", UDim2.fromOffset(18, 143), UDim2.fromOffset(354, 38))

local fovLabel = label("FOV SETTING: 120", UDim2.fromOffset(18, 198), UDim2.fromOffset(190, 22))
local fovDown = button("-", UDim2.fromOffset(250, 190), UDim2.fromOffset(48, 36))
local fovUp = button("+", UDim2.fromOffset(310, 190), UDim2.fromOffset(48, 36))

local smoothLabel = label("SMOOTHNESS SETTING: 8", UDim2.fromOffset(18, 244), UDim2.fromOffset(205, 22))
local smoothDown = button("-", UDim2.fromOffset(250, 236), UDim2.fromOffset(48, 36))
local smoothUp = button("+", UDim2.fromOffset(310, 236), UDim2.fromOffset(48, 36))

local status = label("STATUS: READY  •  UI PREVIEW ONLY", UDim2.fromOffset(18, 294), UDim2.new(1, -36, 0, 18))
status.TextColor3 = Color3.fromRGB(224, 91, 101)
status.TextSize = 9

local function refresh()
    espButton.Text = "ESP PREVIEW: " .. (Config.ESPPreview and "ON" or "OFF")
    aimButton.Text = "AIM PREVIEW: " .. (Config.AimPreview and "ON" or "OFF")
    teamButton.Text = "TEAM CHECK: " .. (Config.TeamCheck and "ON" or "OFF")
    fovLabel.Text = "FOV SETTING: " .. tostring(Config.FOV)
    smoothLabel.Text = "SMOOTHNESS SETTING: " .. tostring(Config.Smoothness)

    espButton.BackgroundColor3 = Config.ESPPreview and Color3.fromRGB(115, 35, 47) or Color3.fromRGB(39, 39, 48)
    aimButton.BackgroundColor3 = Config.AimPreview and Color3.fromRGB(115, 35, 47) or Color3.fromRGB(39, 39, 48)
    teamButton.BackgroundColor3 = Config.TeamCheck and Color3.fromRGB(49, 65, 55) or Color3.fromRGB(39, 39, 48)
    status.Text = "STATUS: READY  •  UI PREVIEW ONLY"
end

connect(espButton.Activated, function()
    Config.ESPPreview = not Config.ESPPreview
    refresh()
end)

connect(aimButton.Activated, function()
    Config.AimPreview = not Config.AimPreview
    refresh()
end)

connect(teamButton.Activated, function()
    Config.TeamCheck = not Config.TeamCheck
    refresh()
end)

connect(fovDown.Activated, function()
    Config.FOV = math.max(30, Config.FOV - 10)
    refresh()
end)

connect(fovUp.Activated, function()
    Config.FOV = math.min(300, Config.FOV + 10)
    refresh()
end)

connect(smoothDown.Activated, function()
    Config.Smoothness = math.max(1, Config.Smoothness - 1)
    refresh()
end)

connect(smoothUp.Activated, function()
    Config.Smoothness = math.min(20, Config.Smoothness + 1)
    refresh()
end)

connect(UserInputService.InputBegan, function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
    end
end)

local function cleanup()
    if destroyed then return end
    destroyed = true
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    if gui then gui:Destroy() end
end

local environment = _G
if type(getgenv) == "function" then
    local ok, env = pcall(getgenv)
    if ok and type(env) == "table" then environment = env end
end
environment.LUNYX_UNLOAD = cleanup

refresh()
print("[LUNYX] Premium UI V2 loaded. RightShift toggles the panel.")
