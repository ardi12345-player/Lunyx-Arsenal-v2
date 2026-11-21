--[[
    LUNYX ARSENAL — TRAINING BUILD
    Roblox Studio LocalScript for your own place / private test environment.

    Features:
      - Spawns three local moving training dummies.
      - NPC-only ESP: Highlight, name, distance, and health bar.
      - Aim trainer: camera smoothly tracks a training dummy while RMB is held.
      - FOV circle and adjustable FOV / smoothness.
      - RightShift toggles the panel.

    Place this file as a LocalScript in:
      StarterPlayer > StarterPlayerScripts

    This script only creates and targets its own local training dummies.
    It does not read, highlight, or aim at players in public Arsenal matches.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
if not localPlayer then
    warn("[LUNYX] LocalPlayer is unavailable. Run this as a LocalScript.")
    return
end

local playerGui = localPlayer:WaitForChild("PlayerGui")

local CONFIG = {
    ESPEnabled = true,
    ESPHead = true,
    ESPHealth = true,
    ESPWeapon = true,
    ESPDistance = true,
    AimEnabled = false,
    AimPart = "Head",
    FOV = 140,
    Smoothness = 8,
    TargetCount = 3,
    TargetFolderName = "LunyxTrainingTargets",
    GuiName = "LunyxArsenalTraining",
}

local connections = {}
local espObjects = {}
local targetModels = {}
local destroyed = false
local aimingHeld = false
local renderConnection
local renderBindName = "ArdiGitTraining_" .. tostring(localPlayer.UserId)
local updateClock = 0
local hitCount = 0
local shotCount = 0

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end

local function addCorner(instance, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = instance
    return corner
end

local function addStroke(instance, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0
    stroke.Parent = instance
    return stroke
end

local function makePart(model, name, size, cframe, color)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.CFrame = cframe
    part.Color = color
    part.Material = Enum.Material.SmoothPlastic
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = true
    part.CastShadow = true
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = model
    return part
end

local function getCharacterRoot()
    local character = localPlayer.Character
    if not character then
        return nil
    end
    return character:FindFirstChild("HumanoidRootPart")
end

-- Create a folder owned by this training script. It contains local-only dummy targets.
local previousFolder = Workspace:FindFirstChild(CONFIG.TargetFolderName)
if previousFolder then
    previousFolder:Destroy()
end

local targetFolder = Instance.new("Folder")
targetFolder.Name = CONFIG.TargetFolderName
targetFolder.Parent = Workspace

local function createTrainingDummy(index, basePosition, movementRight)
    local model = Instance.new("Model")
    model.Name = string.format("Lunyx Training Dummy %02d", index)
    model.Parent = targetFolder

    local rootCFrame = CFrame.new(basePosition)
    local bodyColor = (index % 2 == 0)
        and Color3.fromRGB(68, 126, 214)
        or Color3.fromRGB(190, 55, 66)
    local limbColor = Color3.fromRGB(32, 34, 43)

    local root = makePart(
        model,
        "HumanoidRootPart",
        Vector3.new(2, 2, 1),
        rootCFrame,
        bodyColor
    )
    root.Transparency = 1

    local torso = makePart(
        model,
        "Torso",
        Vector3.new(2, 2, 1),
        rootCFrame * CFrame.new(0, 0, 0),
        bodyColor
    )

    local head = makePart(
        model,
        "Head",
        Vector3.new(1.35, 1.35, 1.35),
        rootCFrame * CFrame.new(0, 1.75, 0),
        Color3.fromRGB(238, 202, 169)
    )
    head.Shape = Enum.PartType.Ball

    makePart(model, "LeftArm", Vector3.new(0.65, 1.8, 0.7), rootCFrame * CFrame.new(-1.3, 0, 0), limbColor)
    makePart(model, "RightArm", Vector3.new(0.65, 1.8, 0.7), rootCFrame * CFrame.new(1.3, 0, 0), limbColor)
    local leftLeg = makePart(model, "LeftLeg", Vector3.new(0.8, 1.8, 0.85), rootCFrame * CFrame.new(-0.48, -1.85, 0), limbColor)
    local rightLeg = makePart(model, "RightLeg", Vector3.new(0.8, 1.8, 0.85), rootCFrame * CFrame.new(0.48, -1.85, 0), limbColor)

    local weaponNames = {"Training Blaster", "Pulse Carbine", "Practice SMG"}
    local weaponPart = makePart(
        model,
        "TrainingWeapon",
        Vector3.new(0.28, 0.28, 1.25),
        rootCFrame * CFrame.new(1.45, -0.55, -0.5),
        Color3.fromRGB(35, 37, 44)
    )
    weaponPart.CanQuery = false
    weaponPart.Massless = true
    local weaponName = weaponNames[index] or "Training Blaster"

    local humanoid = Instance.new("Humanoid")
    humanoid.Name = "Humanoid"
    humanoid.MaxHealth = 100
    humanoid.Health = 100
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    humanoid.RequiresNeck = false
    humanoid.Parent = model

    model.PrimaryPart = root
    model:SetAttribute("LunyxTrainingTarget", true)

    table.insert(targetModels, {
        Model = model,
        Root = root,
        Head = head,
        Torso = torso,
        LeftLeg = leftLeg,
        RightLeg = rightLeg,
        WeaponPart = weaponPart,
        WeaponName = weaponName,
        Humanoid = humanoid,
        Origin = basePosition,
        Phase = index * 1.7,
        MoveDistance = 4 + index,
        MoveRight = movementRight or Vector3.new(1, 0, 0),
    })

    return model
end

local function spawnTrainingTargets()
    local root = getCharacterRoot()
    local camera = Workspace.CurrentCamera
    if not root or not camera then
        return false
    end

    local forward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
    if forward.Magnitude < 0.01 then
        forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
    end
    if forward.Magnitude < 0.01 then
        forward = Vector3.new(0, 0, -1)
    end
    forward = forward.Unit

    local right = Vector3.new(-forward.Z, 0, forward.X).Unit
    local offsets = {-12, 0, 12}

    -- Raycast down to the actual floor. Using HumanoidRootPart.Y directly
    -- can leave training dummies floating when the player spawns above ground.
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {localPlayer.Character, targetFolder}
    rayParams.IgnoreWater = true

    for index = 1, CONFIG.TargetCount do
        local horizontalOffset = offsets[index] or ((index - 2) * 12)
        local candidate = root.Position + forward * 32 + right * horizontalOffset
        local rayOrigin = Vector3.new(candidate.X, root.Position.Y + 100, candidate.Z)
        local groundHit = Workspace:Raycast(rayOrigin, Vector3.new(0, -600, 0), rayParams)

        -- The dummy root is its vertical center; this offset puts its feet on the hit surface.
        local groundY = groundHit and groundHit.Position.Y or root.Position.Y - 2.8
        local position = Vector3.new(candidate.X, groundY + 2.8, candidate.Z)
        createTrainingDummy(index, position, right)
    end

    return true
end

local oldGui = playerGui:FindFirstChild(CONFIG.GuiName)
if oldGui then
    oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = CONFIG.GuiName
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.Parent = playerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(430, 430)
main.Position = UDim2.new(1, -450, 0, 80)
main.BackgroundColor3 = Color3.fromRGB(14, 14, 19)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui
addCorner(main, 14)
addStroke(main, Color3.fromRGB(190, 42, 55), 1.5, 0.05)

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 68)
header.BackgroundColor3 = Color3.fromRGB(34, 15, 21)
header.BorderSizePixel = 0
header.Parent = main
addCorner(header, 14)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(18, 8)
title.Size = UDim2.new(1, -36, 0, 30)
title.Font = Enum.Font.GothamBold
title.Text = "ARDI GIT"
title.TextColor3 = Color3.fromRGB(247, 74, 88)
title.TextSize = 21
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(19, 39)
subtitle.Size = UDim2.new(1, -38, 0, 17)
subtitle.Font = Enum.Font.Gotham
subtitle.Text = "TRAINING CONTROL  /  NPC ONLY"
subtitle.TextColor3 = Color3.fromRGB(157, 157, 168)
subtitle.TextSize = 9
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = header

local function makeButton(parent, text, x, y, width, height)
    local button = Instance.new("TextButton")
    button.Position = UDim2.fromOffset(x, y)
    button.Size = UDim2.fromOffset(width, height)
    button.BackgroundColor3 = Color3.fromRGB(38, 38, 47)
    button.BorderSizePixel = 0
    button.AutoButtonColor = true
    button.Font = Enum.Font.GothamSemibold
    button.TextColor3 = Color3.fromRGB(238, 238, 243)
    button.TextSize = 11
    button.Text = text
    button.Parent = parent
    addCorner(button, 8)
    return button
end

local function makeLabel(parent, text, x, y, width, height)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(x, y)
    label.Size = UDim2.fromOffset(width, height)
    label.Font = Enum.Font.GothamSemibold
    label.TextColor3 = Color3.fromRGB(220, 220, 228)
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = text
    label.Parent = parent
    return label
end

local tabBar = Instance.new("Frame")
tabBar.BackgroundTransparency = 1
tabBar.Position = UDim2.fromOffset(16, 79)
tabBar.Size = UDim2.new(1, -32, 0, 38)
tabBar.Parent = main

local pageContainer = Instance.new("Frame")
pageContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
pageContainer.BorderSizePixel = 0
pageContainer.Position = UDim2.fromOffset(16, 126)
pageContainer.Size = UDim2.new(1, -32, 1, -142)
pageContainer.Parent = main
addCorner(pageContainer, 10)
addStroke(pageContainer, Color3.fromRGB(55, 55, 66), 1, 0.3)

local function createPage(name)
    local page = Instance.new("Frame")
    page.Name = name
    page.BackgroundTransparency = 1
    page.Size = UDim2.fromScale(1, 1)
    page.Visible = false
    page.Parent = pageContainer
    return page
end

local aimPage = createPage("AimPage")
local espPage = createPage("ESPPage")
local settingsPage = createPage("SettingsPage")

local aimTab = makeButton(tabBar, "AIM", 0, 0, 128, 36)
local espTab = makeButton(tabBar, "ESP", 134, 0, 128, 36)
local settingsTab = makeButton(tabBar, "SETTINGS", 268, 0, 130, 36)

local currentTab = "AIM"
local function showTab(name)
    currentTab = name
    aimPage.Visible = name == "AIM"
    espPage.Visible = name == "ESP"
    settingsPage.Visible = name == "SETTINGS"

    aimTab.BackgroundColor3 = name == "AIM" and Color3.fromRGB(132, 39, 52) or Color3.fromRGB(38, 38, 47)
    espTab.BackgroundColor3 = name == "ESP" and Color3.fromRGB(132, 39, 52) or Color3.fromRGB(38, 38, 47)
    settingsTab.BackgroundColor3 = name == "SETTINGS" and Color3.fromRGB(132, 39, 52) or Color3.fromRGB(38, 38, 47)
end

local espButton = makeButton(aimPage, "AIM TRAINER: OFF", 14, 34, 370, 38)
local aimPartHeading = makeLabel(aimPage, "LOCK TARGET PART", 16, 86, 350, 20)
aimPartHeading.TextColor3 = Color3.fromRGB(245, 105, 115)

local headPartButton = makeButton(aimPage, "HEAD", 14, 113, 114, 36)
local bodyPartButton = makeButton(aimPage, "BODY", 140, 113, 114, 36)
local legsPartButton = makeButton(aimPage, "LEGS", 266, 113, 118, 36)

local fovLabel = makeLabel(aimPage, "FOV: 140 PX", 16, 169, 190, 22)
local fovDown = makeButton(aimPage, "-", 270, 160, 48, 36)
local fovUp = makeButton(aimPage, "+", 328, 160, 48, 36)

local smoothLabel = makeLabel(aimPage, "SMOOTHNESS: 8", 16, 218, 205, 22)
local smoothDown = makeButton(aimPage, "-", 270, 209, 48, 36)
local smoothUp = makeButton(aimPage, "+", 328, 209, 48, 36)

local aimHint = makeLabel(aimPage, "HOLD RMB TO TRACK THE SELECTED DUMMY PART", 16, 270, 370, 18)
aimHint.TextColor3 = Color3.fromRGB(160, 160, 172)
aimHint.TextSize = 9

local espMasterButton = makeButton(espPage, "NPC ESP: ON", 14, 20, 370, 36)
local headESPButton = makeButton(espPage, "HEAD HIGHLIGHT: ON", 14, 70, 176, 36)
local healthESPButton = makeButton(espPage, "HP / HEALTH: ON", 208, 70, 176, 36)
local weaponESPButton = makeButton(espPage, "WEAPON NAME: ON", 14, 118, 176, 36)
local distanceESPButton = makeButton(espPage, "DISTANCE: ON", 208, 118, 176, 36)

local espHint = makeLabel(espPage, "ESP ONLY READS THE DUMMIES SPAWNED BY THIS TRAINER.", 16, 180, 370, 34)
espHint.TextColor3 = Color3.fromRGB(160, 160, 172)
espHint.TextSize = 9
espHint.TextWrapped = true

local respawnButton = makeButton(settingsPage, "RESPAWN TRAINING TARGETS", 14, 24, 370, 38)
local resetButton = makeButton(settingsPage, "RESET AIM SETTINGS", 14, 76, 370, 38)
local settingsHint = makeLabel(settingsPage, "RIGHTSHIFT  •  SHOW / HIDE MENU", 16, 140, 370, 20)
settingsHint.TextColor3 = Color3.fromRGB(160, 160, 172)
settingsHint.TextSize = 9
local settingsNote = makeLabel(settingsPage, "ARDI GIT  /  PRIVATE TRAINING BUILD", 16, 170, 370, 20)
settingsNote.TextColor3 = Color3.fromRGB(225, 91, 101)
settingsNote.TextSize = 9

local statsLabel = makeLabel(main, "HITS: 0  |  SHOTS: 0", 18, 408, 190, 14)
statsLabel.TextColor3 = Color3.fromRGB(190, 190, 200)
statsLabel.TextSize = 9

local status = makeLabel(main, "STATUS: TRAINING TARGETS INITIALIZING", 210, 408, 200, 14)
status.TextColor3 = Color3.fromRGB(224, 91, 101)
status.TextSize = 8
status.TextXAlignment = Enum.TextXAlignment.Right

local fovCircle = Instance.new("Frame")
fovCircle.Name = "TrainingFOV"
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.Position = UDim2.fromScale(0.5, 0.5)
fovCircle.Size = UDim2.fromOffset(CONFIG.FOV * 2, CONFIG.FOV * 2)
fovCircle.BackgroundTransparency = 1
fovCircle.Visible = false
fovCircle.ZIndex = 5
fovCircle.Parent = gui
addCorner(fovCircle, 999)
addStroke(fovCircle, Color3.fromRGB(239, 65, 78), 1.5, 0.1)

local function refreshUI()
    espButton.Text = "AIM TRAINER: " .. (CONFIG.AimEnabled and "ON" or "OFF")
    espButton.BackgroundColor3 = CONFIG.AimEnabled and Color3.fromRGB(115, 35, 47) or Color3.fromRGB(38, 38, 47)

    headPartButton.BackgroundColor3 = CONFIG.AimPart == "Head" and Color3.fromRGB(132, 39, 52) or Color3.fromRGB(38, 38, 47)
    bodyPartButton.BackgroundColor3 = CONFIG.AimPart == "Body" and Color3.fromRGB(132, 39, 52) or Color3.fromRGB(38, 38, 47)
    legsPartButton.BackgroundColor3 = CONFIG.AimPart == "Legs" and Color3.fromRGB(132, 39, 52) or Color3.fromRGB(38, 38, 47)

    fovLabel.Text = "FOV: " .. tostring(CONFIG.FOV) .. " PX"
    smoothLabel.Text = "SMOOTHNESS: " .. tostring(CONFIG.Smoothness)

    espMasterButton.Text = "NPC ESP: " .. (CONFIG.ESPEnabled and "ON" or "OFF")
    headESPButton.Text = "HEAD HIGHLIGHT: " .. (CONFIG.ESPHead and "ON" or "OFF")
    healthESPButton.Text = "HP / HEALTH: " .. (CONFIG.ESPHealth and "ON" or "OFF")
    weaponESPButton.Text = "WEAPON NAME: " .. (CONFIG.ESPWeapon and "ON" or "OFF")
    distanceESPButton.Text = "DISTANCE: " .. (CONFIG.ESPDistance and "ON" or "OFF")

    local activeColor = Color3.fromRGB(49, 75, 59)
    local inactiveColor = Color3.fromRGB(38, 38, 47)
    espMasterButton.BackgroundColor3 = CONFIG.ESPEnabled and Color3.fromRGB(115, 35, 47) or inactiveColor
    headESPButton.BackgroundColor3 = CONFIG.ESPHead and activeColor or inactiveColor
    healthESPButton.BackgroundColor3 = CONFIG.ESPHealth and activeColor or inactiveColor
    weaponESPButton.BackgroundColor3 = CONFIG.ESPWeapon and activeColor or inactiveColor
    distanceESPButton.BackgroundColor3 = CONFIG.ESPDistance and activeColor or inactiveColor

    fovCircle.Size = UDim2.fromOffset(CONFIG.FOV * 2, CONFIG.FOV * 2)
    fovCircle.Visible = CONFIG.AimEnabled
end

connect(aimTab.Activated, function() showTab("AIM") end)
connect(espTab.Activated, function() showTab("ESP") end)
connect(settingsTab.Activated, function() showTab("SETTINGS") end)

connect(espButton.Activated, function()
    CONFIG.AimEnabled = not CONFIG.AimEnabled
    refreshUI()
    status.Text = CONFIG.AimEnabled and "STATUS: HOLD RMB TO TRACK DUMMY" or "STATUS: AIM TRAINER OFF"
end)

connect(headPartButton.Activated, function()
    CONFIG.AimPart = "Head"
    refreshUI()
end)

connect(bodyPartButton.Activated, function()
    CONFIG.AimPart = "Body"
    refreshUI()
end)

connect(legsPartButton.Activated, function()
    CONFIG.AimPart = "Legs"
    refreshUI()
end)

connect(fovDown.Activated, function()
    CONFIG.FOV = math.max(40, CONFIG.FOV - 10)
    refreshUI()
end)

connect(fovUp.Activated, function()
    CONFIG.FOV = math.min(320, CONFIG.FOV + 10)
    refreshUI()
end)

connect(smoothDown.Activated, function()
    CONFIG.Smoothness = math.max(1, CONFIG.Smoothness - 1)
    refreshUI()
end)

connect(smoothUp.Activated, function()
    CONFIG.Smoothness = math.min(20, CONFIG.Smoothness + 1)
    refreshUI()
end)

local function setESPOption(option, value)
    CONFIG[option] = value
    refreshUI()
end

connect(espMasterButton.Activated, function()
    CONFIG.ESPEnabled = not CONFIG.ESPEnabled
    refreshUI()
    status.Text = CONFIG.ESPEnabled and "STATUS: NPC ESP ENABLED" or "STATUS: NPC ESP DISABLED"
end)

connect(headESPButton.Activated, function()
    setESPOption("ESPHead", not CONFIG.ESPHead)
end)

connect(healthESPButton.Activated, function()
    setESPOption("ESPHealth", not CONFIG.ESPHealth)
end)

connect(weaponESPButton.Activated, function()
    setESPOption("ESPWeapon", not CONFIG.ESPWeapon)
end)

connect(distanceESPButton.Activated, function()
    setESPOption("ESPDistance", not CONFIG.ESPDistance)
end)

connect(respawnButton.Activated, function()
    for _, target in ipairs(targetModels) do
        if target.Model and target.Model.Parent then
            target.Model:Destroy()
        end
    end
    table.clear(targetModels)
    clearESP()

    if spawnTrainingTargets() then
        hitCount = 0
        shotCount = 0
        statsLabel.Text = "HITS: 0  |  SHOTS: 0"
        status.Text = "STATUS: TRAINING TARGETS RESPAWNED"
    else
        status.Text = "STATUS: WAITING FOR CHARACTER"
    end
end)

connect(resetButton.Activated, function()
    CONFIG.FOV = 140
    CONFIG.Smoothness = 8
    CONFIG.AimPart = "Head"
    CONFIG.AimEnabled = false
    aimingHeld = false
    refreshUI()
    status.Text = "STATUS: AIM SETTINGS RESET"
end)

showTab("AIM")
refreshUI()

local function clearESP()
    for model, objects in pairs(espObjects) do
        for _, object in ipairs(objects) do
            if object and object.Parent then
                object:Destroy()
            end
        end
        espObjects[model] = nil
    end
end

local function createESP(target)
    local model = target.Model
    if not model or not model.Parent or espObjects[model] then
        return
    end

    local headHighlight = Instance.new("Highlight")
    headHighlight.Name = "ArdiGitHeadESP"
    headHighlight.Adornee = target.Head
    headHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    headHighlight.FillColor = Color3.fromRGB(235, 52, 69)
    headHighlight.FillTransparency = 0.72
    headHighlight.OutlineColor = Color3.fromRGB(255, 105, 115)
    headHighlight.OutlineTransparency = 0
    headHighlight.Enabled = true
    headHighlight.Parent = gui

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ArdiGitNPCInfo"
    billboard.Adornee = target.Root
    billboard.Size = UDim2.fromOffset(190, 65)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.65, 0)
    billboard.MaxDistance = 300
    billboard.LightInfluence = 0
    billboard.AlwaysOnTop = true
    billboard.Enabled = true
    billboard.Parent = gui

    local nameText = Instance.new("TextLabel")
    nameText.Name = "NameDistance"
    nameText.BackgroundTransparency = 1
    nameText.Size = UDim2.new(1, 0, 0, 18)
    nameText.Font = Enum.Font.GothamBold
    nameText.TextColor3 = Color3.fromRGB(255, 105, 115)
    nameText.TextStrokeTransparency = 0.35
    nameText.TextSize = 10
    nameText.Parent = billboard

    local weaponText = Instance.new("TextLabel")
    weaponText.Name = "Weapon"
    weaponText.BackgroundTransparency = 1
    weaponText.Position = UDim2.fromOffset(0, 18)
    weaponText.Size = UDim2.new(1, 0, 0, 16)
    weaponText.Font = Enum.Font.GothamSemibold
    weaponText.TextColor3 = Color3.fromRGB(225, 205, 155)
    weaponText.TextStrokeTransparency = 0.4
    weaponText.TextSize = 9
    weaponText.Parent = billboard

    local healthText = Instance.new("TextLabel")
    healthText.Name = "HealthText"
    healthText.BackgroundTransparency = 1
    healthText.Position = UDim2.fromOffset(0, 38)
    healthText.Size = UDim2.fromOffset(66, 14)
    healthText.Font = Enum.Font.GothamBold
    healthText.TextColor3 = Color3.fromRGB(225, 235, 225)
    healthText.TextStrokeTransparency = 0.45
    healthText.TextSize = 9
    healthText.TextXAlignment = Enum.TextXAlignment.Left
    healthText.Parent = billboard

    local healthBackground = Instance.new("Frame")
    healthBackground.Name = "HealthBackground"
    healthBackground.Position = UDim2.fromOffset(67, 41)
    healthBackground.Size = UDim2.fromOffset(112, 7)
    healthBackground.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    healthBackground.BorderSizePixel = 0
    healthBackground.Parent = billboard
    addCorner(healthBackground, 4)

    local healthFill = Instance.new("Frame")
    healthFill.Name = "HealthFill"
    healthFill.Size = UDim2.fromScale(1, 1)
    healthFill.BackgroundColor3 = Color3.fromRGB(75, 220, 120)
    healthFill.BorderSizePixel = 0
    healthFill.Parent = healthBackground
    addCorner(healthFill, 4)

    espObjects[model] = {headHighlight, billboard}
    target.HeadHighlight = headHighlight
    target.Billboard = billboard
    target.ESPInfo = nameText
    target.WeaponInfo = weaponText
    target.HealthText = healthText
    target.HealthFill = healthFill
end

local function updateESP(target)
    local model = target.Model
    if not model or not model.Parent then
        return
    end

    if not espObjects[model] then
        createESP(target)
    end

    local highlight = target.HeadHighlight
    local billboard = target.Billboard
    if not highlight or not billboard then
        return
    end

    highlight.Enabled = CONFIG.ESPEnabled and CONFIG.ESPHead
    billboard.Enabled = CONFIG.ESPEnabled and (CONFIG.ESPDistance or CONFIG.ESPWeapon or CONFIG.ESPHealth)

    local root = getCharacterRoot()
    local distance = (root and target.Root and (root.Position - target.Root.Position).Magnitude) or 0
    local health = target.Humanoid and target.Humanoid.Health or 0
    local maxHealth = target.Humanoid and target.Humanoid.MaxHealth or 100

    if target.ESPInfo then
        target.ESPInfo.Visible = CONFIG.ESPDistance
        target.ESPInfo.Text = string.format(
            "DUMMY %02d  |  %d STUDS",
            tonumber(model.Name:match("(%d+)$")) or 0,
            math.floor(distance + 0.5)
        )
    end

    if target.WeaponInfo then
        target.WeaponInfo.Visible = CONFIG.ESPWeapon
        target.WeaponInfo.Text = "WEAPON: " .. tostring(target.WeaponName or "Training Blaster")
    end

    if target.HealthText then
        target.HealthText.Visible = CONFIG.ESPHealth
        target.HealthText.Text = string.format("HP %d/%d", math.floor(health + 0.5), math.floor(maxHealth + 0.5))
    end

    local healthBackground = target.HealthFill and target.HealthFill.Parent
    if healthBackground then
        healthBackground.Visible = CONFIG.ESPHealth
    end

    if target.HealthFill then
        local ratio = math.clamp(health / math.max(maxHealth, 1), 0, 1)
        target.HealthFill.Size = UDim2.new(ratio, 0, 1, 0)
        target.HealthFill.BackgroundColor3 = Color3.fromRGB(
            math.floor(220 * (1 - ratio) + 50 * ratio),
            math.floor(80 * (1 - ratio) + 220 * ratio),
            85
        )
    end
end

local function performTrainingShot(camera)
    if not camera then
        return
    end

    shotCount += 1
    local mousePosition = UserInputService:GetMouseLocation()
    local shotRay = camera:ScreenPointToRay(mousePosition.X, mousePosition.Y)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Include
    raycastParams.FilterDescendantsInstances = {targetFolder}
    raycastParams.IgnoreWater = true

    local result = Workspace:Raycast(shotRay.Origin, shotRay.Direction * 500, raycastParams)
    if result then
        local hitModel = result.Instance:FindFirstAncestorWhichIsA("Model")
        for _, target in ipairs(targetModels) do
            if target.Model == hitModel and target.Humanoid and target.Humanoid.Health > 0 then
                hitCount += 1
                target.Humanoid.Health = math.max(0, target.Humanoid.Health - 25)
                status.Text = target.Humanoid.Health <= 0
                    and "STATUS: TRAINING DUMMY ELIMINATED"
                    or "STATUS: HIT  -25 HP"
                statsLabel.Text = string.format("HITS: %d  |  SHOTS: %d", hitCount, shotCount)
                return
            end
        end
    end

    status.Text = "STATUS: MISSED - ADJUST YOUR AIM"
    statsLabel.Text = string.format("HITS: %d  |  SHOTS: %d", hitCount, shotCount)
end

connect(UserInputService.InputBegan, function(input, processed)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aimingHeld = true
    elseif input.KeyCode == Enum.KeyCode.RightShift and not processed then
        main.Visible = not main.Visible
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
        performTrainingShot(Workspace.CurrentCamera)
    end
end)

connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aimingHeld = false
    end
end)

local function getAimPosition(target)
    if CONFIG.AimPart == "Body" and target.Torso then
        return target.Torso.Position
    elseif CONFIG.AimPart == "Legs" and target.LeftLeg and target.RightLeg then
        return (target.LeftLeg.Position + target.RightLeg.Position) * 0.5
    end
    return target.Head and target.Head.Position or nil
end

local function findBestTrainingTarget(camera)
    local viewport = camera.ViewportSize
    local screenCenter = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
    local bestTarget = nil
    local bestDistance = CONFIG.FOV

    for _, target in ipairs(targetModels) do
        local model = target.Model
        local humanoid = target.Humanoid
        local aimPosition = getAimPosition(target)

        if model and model.Parent and aimPosition and humanoid and humanoid.Health > 0 then
            local screenPosition, onScreen = camera:WorldToViewportPoint(aimPosition)
            if onScreen and screenPosition.Z > 0 then
                local delta = Vector2.new(screenPosition.X, screenPosition.Y) - screenCenter
                local distance = delta.Magnitude
                if distance <= bestDistance then
                    bestDistance = distance
                    bestTarget = target
                end
            end
        end
    end

    return bestTarget
end

local function updateMovingTargets(now)
    local playerRoot = getCharacterRoot()
    local lookAtPosition = playerRoot and playerRoot.Position or Vector3.zero

    for _, target in ipairs(targetModels) do
        if target.Model and target.Model.Parent and target.Root and target.Root.Parent then
            local horizontalOffset = math.sin(now * 1.2 + target.Phase) * target.MoveDistance
            local position = target.Origin + target.MoveRight * horizontalOffset

            -- Keep the target at its ground-snapped spawn height.
            position = Vector3.new(position.X, target.Origin.Y, position.Z)

            local facePosition = Vector3.new(lookAtPosition.X, position.Y, lookAtPosition.Z)
            if (facePosition - position).Magnitude < 0.1 then
                facePosition = position + Vector3.new(0, 0, -1)
            end
            target.Model:PivotTo(CFrame.lookAt(position, facePosition))
        end
    end
end

local function cleanup()
    if destroyed then
        return
    end
    destroyed = true

    pcall(function()
        RunService:UnbindFromRenderStep(renderBindName)
    end)

    if renderConnection then
        renderConnection:Disconnect()
    end

    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    clearESP()

    if gui and gui.Parent then
        gui:Destroy()
    end

    if targetFolder and targetFolder.Parent then
        targetFolder:Destroy()
    end
end

local initialCharacter = localPlayer.Character or localPlayer.CharacterAdded:Wait()
initialCharacter:WaitForChild("HumanoidRootPart")

spawnTrainingTargets()
refreshUI()

pcall(function()
    RunService:UnbindFromRenderStep(renderBindName)
end)

RunService:BindToRenderStep(renderBindName, Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
    if destroyed then
        return
    end

    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end

    updateMovingTargets(os.clock())

    updateClock += deltaTime
    if updateClock >= 0.08 then
        updateClock = 0
        for _, target in ipairs(targetModels) do
            updateESP(target)
        end
    end

    if CONFIG.AimEnabled and aimingHeld then
        local target = findBestTrainingTarget(camera)
        local aimPosition = target and getAimPosition(target)
        if aimPosition then
            local desired = CFrame.lookAt(camera.CFrame.Position, aimPosition)
            local alpha = math.clamp(deltaTime * (24 / CONFIG.Smoothness), 0, 1)
            camera.CFrame = camera.CFrame:Lerp(desired, alpha)
        end
    end
end)

connect(localPlayer.CharacterAdded, function()
    status.Text = "STATUS: CHARACTER RESPAWNED"
end)

print("[LUNYX] Training build loaded. RightShift = panel, hold RMB = aim trainer.")
