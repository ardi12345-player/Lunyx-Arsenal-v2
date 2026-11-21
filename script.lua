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
    AimEnabled = false,
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

local function createTrainingDummy(index, basePosition)
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

    makePart(
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
    makePart(model, "LeftLeg", Vector3.new(0.8, 1.8, 0.85), rootCFrame * CFrame.new(-0.48, -1.85, 0), limbColor)
    makePart(model, "RightLeg", Vector3.new(0.8, 1.8, 0.85), rootCFrame * CFrame.new(0.48, -1.85, 0), limbColor)

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
        Humanoid = humanoid,
        Origin = basePosition,
        Phase = index * 1.7,
        MoveDistance = 4 + index,
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
    forward = forward.Unit

    local right = Vector3.new(-forward.Z, 0, forward.X)
    local offsets = {-12, 0, 12}

    for index = 1, CONFIG.TargetCount do
        local horizontalOffset = offsets[index] or ((index - 2) * 12)
        local position = root.Position + forward * 32 + right * horizontalOffset
        position = Vector3.new(position.X, root.Position.Y, position.Z)
        createTrainingDummy(index, position)
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
main.Size = UDim2.fromOffset(390, 370)
main.Position = UDim2.new(1, -415, 0, 90)
main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui
addCorner(main, 14)
addStroke(main, Color3.fromRGB(190, 42, 55), 1.5, 0.05)

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 72)
header.BackgroundColor3 = Color3.fromRGB(34, 17, 22)
header.BorderSizePixel = 0
header.Parent = main
addCorner(header, 14)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(18, 9)
title.Size = UDim2.new(1, -36, 0, 30)
title.Font = Enum.Font.GothamBold
title.Text = "LUNYX  /  TRAINING"
title.TextColor3 = Color3.fromRGB(245, 75, 87)
title.TextSize = 19
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(19, 40)
subtitle.Size = UDim2.new(1, -38, 0, 18)
subtitle.Font = Enum.Font.Gotham
subtitle.Text = "NPC ESP  •  AIM TRAINER  •  PRIVATE TEST"
subtitle.TextColor3 = Color3.fromRGB(157, 157, 168)
subtitle.TextSize = 9
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = header

local function makeButton(text, x, y, width, height)
    local button = Instance.new("TextButton")
    button.Position = UDim2.fromOffset(x, y)
    button.Size = UDim2.fromOffset(width, height)
    button.BackgroundColor3 = Color3.fromRGB(39, 39, 48)
    button.BorderSizePixel = 0
    button.AutoButtonColor = true
    button.Font = Enum.Font.GothamSemibold
    button.TextColor3 = Color3.fromRGB(238, 238, 243)
    button.TextSize = 11
    button.Text = text
    button.Parent = main
    addCorner(button, 8)
    return button
end

local function makeLabel(text, x, y, width, height)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(x, y)
    label.Size = UDim2.fromOffset(width, height)
    label.Font = Enum.Font.GothamSemibold
    label.TextColor3 = Color3.fromRGB(220, 220, 228)
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = text
    label.Parent = main
    return label
end

local espButton = makeButton("NPC ESP: ON", 18, 90, 170, 40)
local aimButton = makeButton("AIM TRAINER: OFF", 202, 90, 170, 40)
local spawnButton = makeButton("RESPAWN TRAINING TARGETS", 18, 142, 354, 36)

local fovLabel = makeLabel("FOV: 140 PX", 18, 198, 190, 22)
local fovDown = makeButton("-", 250, 190, 48, 36)
local fovUp = makeButton("+", 310, 190, 48, 36)

local smoothLabel = makeLabel("SMOOTHNESS: 8", 18, 244, 205, 22)
local smoothDown = makeButton("-", 250, 236, 48, 36)
local smoothUp = makeButton("+", 310, 236, 48, 36)

local instruction = makeLabel("HOLD RMB: AIM  •  LEFT CLICK: SHOOT DUMMY", 18, 286, 354, 18)
instruction.TextColor3 = Color3.fromRGB(170, 170, 180)
instruction.TextSize = 9

local statsLabel = makeLabel("HITS: 0  |  SHOTS: 0", 18, 308, 354, 18)
statsLabel.TextColor3 = Color3.fromRGB(220, 220, 228)
statsLabel.TextSize = 9

local status = makeLabel("STATUS: INITIALIZING TRAINING TARGETS", 18, 337, 354, 18)
status.TextColor3 = Color3.fromRGB(224, 91, 101)
status.TextSize = 9

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

    local highlight = Instance.new("Highlight")
    highlight.Name = "LunyxNPCESP"
    highlight.Adornee = model
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = Color3.fromRGB(225, 48, 64)
    highlight.FillTransparency = 0.78
    highlight.OutlineColor = Color3.fromRGB(255, 105, 115)
    highlight.OutlineTransparency = 0
    highlight.Enabled = true
    highlight.Parent = gui

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "LunyxNPCInfo"
    billboard.Adornee = target.Head
    billboard.Size = UDim2.fromOffset(150, 48)
    billboard.StudsOffset = Vector3.new(0, 2.4, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = true
    billboard.Parent = gui

    local info = Instance.new("TextLabel")
    info.Name = "Info"
    info.BackgroundTransparency = 1
    info.Size = UDim2.new(1, 0, 0, 22)
    info.Font = Enum.Font.GothamBold
    info.TextColor3 = Color3.fromRGB(255, 105, 115)
    info.TextStrokeTransparency = 0.35
    info.TextSize = 11
    info.Text = model.Name
    info.Parent = billboard

    local healthBackground = Instance.new("Frame")
    healthBackground.Name = "HealthBackground"
    healthBackground.Position = UDim2.fromOffset(20, 25)
    healthBackground.Size = UDim2.fromOffset(110, 7)
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

    espObjects[model] = {highlight, billboard}
    target.ESPInfo = info
    target.HealthFill = healthFill
end

local function updateESP(target)
    local model = target.Model
    if not model or not model.Parent then
        return
    end

    if not CONFIG.ESPEnabled then
        local objects = espObjects[model]
        if objects then
            for _, object in ipairs(objects) do
                if object then object.Enabled = false end
            end
        end
        return
    end

    if not espObjects[model] then
        createESP(target)
    end

    local objects = espObjects[model]
    if objects then
        for _, object in ipairs(objects) do
            if object then object.Enabled = true end
        end
    end

    local root = getCharacterRoot()
    local distance = (root and target.Root and (root.Position - target.Root.Position).Magnitude) or 0
    local health = target.Humanoid and target.Humanoid.Health or 0
    local maxHealth = target.Humanoid and target.Humanoid.MaxHealth or 100

    if target.ESPInfo then
        target.ESPInfo.Text = string.format(
            "DUMMY %02d  |  %d STUDS",
            tonumber(model.Name:match("(%d+)$")) or 0,
            math.floor(distance + 0.5)
        )
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

local function refreshUI()
    espButton.Text = "NPC ESP: " .. (CONFIG.ESPEnabled and "ON" or "OFF")
    aimButton.Text = "AIM TRAINER: " .. (CONFIG.AimEnabled and "ON" or "OFF")
    fovLabel.Text = "FOV: " .. tostring(CONFIG.FOV) .. " PX"
    smoothLabel.Text = "SMOOTHNESS: " .. tostring(CONFIG.Smoothness)
    espButton.BackgroundColor3 = CONFIG.ESPEnabled and Color3.fromRGB(115, 35, 47) or Color3.fromRGB(39, 39, 48)
    aimButton.BackgroundColor3 = CONFIG.AimEnabled and Color3.fromRGB(115, 35, 47) or Color3.fromRGB(39, 39, 48)
    fovCircle.Size = UDim2.fromOffset(CONFIG.FOV * 2, CONFIG.FOV * 2)
    fovCircle.Visible = CONFIG.AimEnabled
end

connect(espButton.Activated, function()
    CONFIG.ESPEnabled = not CONFIG.ESPEnabled
    refreshUI()
    for _, target in ipairs(targetModels) do
        updateESP(target)
    end
end)

connect(aimButton.Activated, function()
    CONFIG.AimEnabled = not CONFIG.AimEnabled
    refreshUI()
    status.Text = CONFIG.AimEnabled and "STATUS: HOLD RMB TO TRACK DUMMY" or "STATUS: AIM TRAINER DISABLED"
end)

connect(spawnButton.Activated, function()
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
    if input.KeyCode == Enum.KeyCode.RightShift and not processed then
        main.Visible = not main.Visible
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 and not processed then
        aimingHeld = true
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
        performTrainingShot(Workspace.CurrentCamera)
    end
end)

connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aimingHeld = false
    end
end)

local function findBestTrainingTarget(camera)
    local viewport = camera.ViewportSize
    local screenCenter = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
    local bestTarget = nil
    local bestDistance = CONFIG.FOV

    for _, target in ipairs(targetModels) do
        local model = target.Model
        local head = target.Head
        local humanoid = target.Humanoid

        if model and model.Parent and head and head.Parent and humanoid and humanoid.Health > 0 then
            local screenPosition, onScreen = camera:WorldToViewportPoint(head.Position)
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
            local right = Vector3.new(1, 0, 0)
            if playerRoot then
                local look = playerRoot.CFrame.LookVector
                right = Vector3.new(-look.Z, 0, look.X)
                if right.Magnitude > 0.01 then right = right.Unit end
            end

            local position = target.Origin + right * horizontalOffset
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

renderConnection = RunService.RenderStepped:Connect(function(deltaTime)
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
        if target and target.Head and target.Head.Parent then
            local desired = CFrame.lookAt(camera.CFrame.Position, target.Head.Position)
            local alpha = math.clamp(deltaTime * (24 / CONFIG.Smoothness), 0, 1)
            camera.CFrame = camera.CFrame:Lerp(desired, alpha)
        end
    end
end)

connect(localPlayer.CharacterAdded, function()
    status.Text = "STATUS: CHARACTER RESPAWNED"
end)

print("[LUNYX] Training build loaded. RightShift = panel, hold RMB = aim trainer.")
