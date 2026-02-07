-- LocalScript 1本で完結するソードリーチ判定（BedWars風）
-- 例: StarterPlayerScripts に配置

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local localPlayer = Players.LocalPlayer

local SwordReach = {
    BaseValues = {
        Wood = 14,
        Stone = 14,
        Iron = 14,
        Diamond = 14,
        Emerald = 14,
    },
    Default = 14,
    BonusMin = 0,
    BonusMax = 200,
    GlobalBonus = 100,
    ReachScale = 3,
    HitboxExpandScale = 1.2, -- GlobalBonus依存で仮想ヒットボックス拡張
    Enabled = true,
    ShowHitboxes = true,
}

local previewBoxes = {}
local currentTargetHighlight

local function getCharacterModelFromInstance(instance)
    local current = instance
    while current and current ~= Workspace do
        if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") then
            return current
        end
        current = current.Parent
    end
    return nil
end

local function getModelRootPart(model)
    if not model then return nil end
    return model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
        or model:FindFirstChild("UpperTorso")
        or model:FindFirstChild("Torso")
        or model:FindFirstChild("Head")
end

local function isOwnCharacter(model)
    if not model then return false end
    if model == localPlayer.Character then return true end
    return Players:GetPlayerFromCharacter(model) == localPlayer
end

function SwordReach.getReach(swordName)
    local base = SwordReach.BaseValues[swordName] or SwordReach.Default
    local bonus = math.clamp(SwordReach.GlobalBonus, SwordReach.BonusMin, SwordReach.BonusMax)
    return base + (bonus * SwordReach.ReachScale)
end

local function getVirtualTargetRadius(attackerRoot, targetRoot)
    local rawBonus = math.clamp(SwordReach.GlobalBonus, SwordReach.BonusMin, SwordReach.BonusMax)
    local basePadding = (attackerRoot.Size.Magnitude + targetRoot.Size.Magnitude) * 0.15
    local expanded = rawBonus * SwordReach.HitboxExpandScale * 0.5
    return basePadding + expanded
end

local function getForwardSearchBox(attackerRoot, swordTier)
    local reach = SwordReach.getReach(swordTier)
    local bonus = math.clamp(SwordReach.GlobalBonus, SwordReach.BonusMin, SwordReach.BonusMax)
    local depth = reach + (bonus * SwordReach.HitboxExpandScale)

    local width = 8 + (bonus * 0.05)
    local height = 10 + (bonus * 0.04)

    local center = attackerRoot.Position + attackerRoot.CFrame.LookVector * (depth * 0.5)
    local boxCf = CFrame.lookAt(center, center + attackerRoot.CFrame.LookVector)
    local boxSize = Vector3.new(width, height, depth)
    return boxCf, boxSize
end

function SwordReach.canHit(attackerCharacter, targetCharacter, swordName)
    if not SwordReach.Enabled then return false end

    local attackerRoot = getModelRootPart(attackerCharacter)
    local targetRoot = getModelRootPart(targetCharacter)
    if not attackerRoot or not targetRoot then return false end

    local centerDist = (attackerRoot.Position - targetRoot.Position).Magnitude
    local edgePadding = (attackerRoot.Size.Magnitude + targetRoot.Size.Magnitude) * 0.5
    local edgeDist = math.max(centerDist - edgePadding, 0)
    local threshold = SwordReach.getReach(swordName) + getVirtualTargetRadius(attackerRoot, targetRoot)
    return edgeDist <= threshold, edgeDist, threshold
end

local function resolveSwordTier(toolName)
    local n = string.lower(toolName or "")
    if string.find(n, "emerald") then return "Emerald" end
    if string.find(n, "diamond") then return "Diamond" end
    if string.find(n, "iron") then return "Iron" end
    if string.find(n, "stone") then return "Stone" end
    return "Wood"
end

local function getEquippedSwordTier(character)
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") then
            return resolveSwordTier(child.Name)
        end
    end
    return "Wood"
end

local function flashHit(model)
    local h = Instance.new("Highlight")
    h.FillColor = Color3.fromRGB(255, 70, 70)
    h.OutlineColor = Color3.fromRGB(255, 255, 255)
    h.FillTransparency = 0.30
    h.OutlineTransparency = 0
    h.Adornee = model
    h.Parent = Workspace
    Debris:AddItem(h, 0.2)
end

local function setCurrentTargetRed(model)
    if not model then
        if currentTargetHighlight then
            currentTargetHighlight:Destroy()
            currentTargetHighlight = nil
        end
        return
    end

    local root = getModelRootPart(model)
    if not root then return end

    if not currentTargetHighlight then
        currentTargetHighlight = Instance.new("Highlight")
        currentTargetHighlight.Name = "CurrentTargetRed"
        currentTargetHighlight.FillColor = Color3.fromRGB(255, 30, 30)
        currentTargetHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        currentTargetHighlight.FillTransparency = 0.5
        currentTargetHighlight.OutlineTransparency = 0
        currentTargetHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        currentTargetHighlight.Parent = Workspace
    end

    -- 自キャラ除外済みなので、相手モデル全体を赤く表示
    currentTargetHighlight.Adornee = model
end

local function setPreviewHitboxVisible(model, visible)
    local root = getModelRootPart(model)
    if not root then return end

    local box = previewBoxes[model]
    if visible then
        if not box then
            box = Instance.new("BoxHandleAdornment")
            box.Name = "ReachHitboxPreview"
            box.AlwaysOnTop = true
            box.ZIndex = 5
            box.Transparency = 0.72
            box.Color3 = Color3.fromRGB(80, 190, 255)
            box.Parent = Workspace
            previewBoxes[model] = box
        end

        local virtualGrow = math.clamp(SwordReach.GlobalBonus, SwordReach.BonusMin, SwordReach.BonusMax) * 0.12
        box.Adornee = root
        box.Size = root.Size + Vector3.new(virtualGrow, virtualGrow, virtualGrow)
    elseif box then
        box:Destroy()
        previewBoxes[model] = nil
    end
end

local function getNearestTargetInReach(attackerCharacter, swordTier)
    local attackerRoot = getModelRootPart(attackerCharacter)
    if not attackerRoot then return nil, math.huge, math.huge end

    local bonus = math.clamp(SwordReach.GlobalBonus, SwordReach.BonusMin, SwordReach.BonusMax)
    local radius = SwordReach.getReach(swordTier) + (bonus * SwordReach.HitboxExpandScale) + 12
    local boxCf, boxSize = getForwardSearchBox(attackerRoot, swordTier)

    local overlap = OverlapParams.new()
    overlap.FilterType = Enum.RaycastFilterType.Exclude
    overlap.FilterDescendantsInstances = { attackerCharacter }

    local nearbyParts = Workspace:GetPartBoundsInRadius(attackerRoot.Position, radius, overlap)
    local forwardParts = Workspace:GetPartBoundsInBox(boxCf, boxSize, overlap)

    local nearestModel, nearestDist, nearestThreshold = nil, math.huge, 0
    local seenModels = {}

    local function considerPart(part)
        local model = getCharacterModelFromInstance(part)
        if model and not seenModels[model] and not isOwnCharacter(model) then
            seenModels[model] = true
            local humanoid = model:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local ok, dist, threshold = SwordReach.canHit(attackerCharacter, model, swordTier)
                if ok and dist < nearestDist then
                    nearestModel = model
                    nearestDist = dist
                    nearestThreshold = threshold
                end
            end
        end
    end

    for _, part in ipairs(forwardParts) do
        considerPart(part)
    end

    for _, part in ipairs(nearbyParts) do
        considerPart(part)
    end

    return nearestModel, nearestDist, nearestThreshold
end

local function refreshHitboxes()
    local character = localPlayer.Character
    if not character then return end

    if not SwordReach.ShowHitboxes then
        for model, _ in pairs(previewBoxes) do
            setPreviewHitboxVisible(model, false)
        end
        return
    end

    local swordTier = getEquippedSwordTier(character)
    local seen = {}

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Humanoid") and obj.Health > 0 then
            local model = obj.Parent
            if model and not isOwnCharacter(model) then
                local ok = SwordReach.canHit(character, model, swordTier)
                if ok then
                    seen[model] = true
                    setPreviewHitboxVisible(model, true)
                end
            end
        end
    end

    for model, _ in pairs(previewBoxes) do
        if not seen[model] then
            setPreviewHitboxVisible(model, false)
        end
    end
end

local function createUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "ReachControlGui"
    gui.ResetOnSpawn = false
    gui.Parent = localPlayer:WaitForChild("PlayerGui")

    local panel = Instance.new("Frame")
    panel.Size = UDim2.fromOffset(265, 172)
    panel.AnchorPoint = Vector2.new(1, 1)
    panel.Position = UDim2.new(1, -12, 1, -12)
    panel.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    panel.BorderSizePixel = 0
    panel.Parent = gui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 0, 24)
    title.Position = UDim2.fromOffset(6, 4)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "Sword Reach"
    title.Parent = panel

    local hideButton = Instance.new("TextButton")
    hideButton.Size = UDim2.fromOffset(46, 22)
    hideButton.Position = UDim2.new(1, -52, 0, 5)
    hideButton.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
    hideButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    hideButton.Text = "Hide"
    hideButton.Parent = panel

    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.fromOffset(90, 28)
    toggleButton.Position = UDim2.fromOffset(8, 34)
    toggleButton.BackgroundColor3 = Color3.fromRGB(70, 140, 70)
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.Text = "ON"
    toggleButton.Parent = panel

    local hitboxButton = Instance.new("TextButton")
    hitboxButton.Size = UDim2.fromOffset(120, 28)
    hitboxButton.Position = UDim2.fromOffset(106, 34)
    hitboxButton.BackgroundColor3 = Color3.fromRGB(60, 90, 140)
    hitboxButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    hitboxButton.Text = "Hitbox: ON"
    hitboxButton.Parent = panel

    local bonusText = Instance.new("TextLabel")
    bonusText.Size = UDim2.new(1, -12, 0, 20)
    bonusText.Position = UDim2.fromOffset(6, 68)
    bonusText.BackgroundTransparency = 1
    bonusText.TextXAlignment = Enum.TextXAlignment.Left
    bonusText.TextColor3 = Color3.fromRGB(230, 230, 230)
    bonusText.Parent = panel

    local effectiveText = Instance.new("TextLabel")
    effectiveText.Size = UDim2.new(1, -12, 0, 20)
    effectiveText.Position = UDim2.fromOffset(6, 86)
    effectiveText.BackgroundTransparency = 1
    effectiveText.TextXAlignment = Enum.TextXAlignment.Left
    effectiveText.TextColor3 = Color3.fromRGB(255, 180, 90)
    effectiveText.Parent = panel

    local sliderBar = Instance.new("Frame")
    sliderBar.Size = UDim2.new(1, -16, 0, 10)
    sliderBar.Position = UDim2.fromOffset(8, 110)
    sliderBar.BackgroundColor3 = Color3.fromRGB(65, 65, 70)
    sliderBar.BorderSizePixel = 0
    sliderBar.Parent = panel

    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new(0, 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(60, 170, 255)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBar

    local infoText = Instance.new("TextLabel")
    infoText.Size = UDim2.new(1, -12, 0, 48)
    infoText.Position = UDim2.fromOffset(6, 122)
    infoText.BackgroundTransparency = 1
    infoText.TextXAlignment = Enum.TextXAlignment.Left
    infoText.TextYAlignment = Enum.TextYAlignment.Top
    infoText.TextColor3 = Color3.fromRGB(180, 180, 190)
    infoText.TextSize = 12
    infoText.TextWrapped = true
    infoText.Text = "赤ハイライト=現在対象。\nHitboxは青枠。Bonusで当たり距離と仮想ヒットボックス拡張"
    infoText.Parent = panel

    local showUIButton = Instance.new("TextButton")
    showUIButton.Size = UDim2.fromOffset(52, 28)
    showUIButton.AnchorPoint = Vector2.new(1, 1)
    showUIButton.Position = UDim2.new(1, -12, 1, -12)
    showUIButton.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    showUIButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    showUIButton.Text = "UI"
    showUIButton.Visible = false
    showUIButton.Parent = gui

    local function refresh()
        local character = localPlayer.Character
        local tier = character and getEquippedSwordTier(character) or "Wood"

        toggleButton.Text = SwordReach.Enabled and "ON" or "OFF"
        toggleButton.BackgroundColor3 = SwordReach.Enabled and Color3.fromRGB(70, 140, 70) or Color3.fromRGB(150, 60, 60)

        hitboxButton.Text = SwordReach.ShowHitboxes and "Hitbox: ON" or "Hitbox: OFF"
        hitboxButton.BackgroundColor3 = SwordReach.ShowHitboxes and Color3.fromRGB(60, 90, 140) or Color3.fromRGB(100, 70, 70)

        local range = math.max(SwordReach.BonusMax - SwordReach.BonusMin, 1)
        local fill = (SwordReach.GlobalBonus - SwordReach.BonusMin) / range
        sliderFill.Size = UDim2.new(math.clamp(fill, 0, 1), 0, 1, 0)

        bonusText.Text = "Bonus: +" .. tostring(SwordReach.GlobalBonus)
        effectiveText.Text = "Effective Reach(" .. tier .. "): " .. tostring(SwordReach.getReach(tier))
    end

    local function setBonusFromX(x)
        local left = sliderBar.AbsolutePosition.X
        local width = math.max(sliderBar.AbsoluteSize.X, 1)
        local alpha = math.clamp((x - left) / width, 0, 1)
        local raw = SwordReach.BonusMin + (SwordReach.BonusMax - SwordReach.BonusMin) * alpha
        SwordReach.GlobalBonus = math.floor(raw + 0.5)
        refresh()
    end

    toggleButton.Activated:Connect(function()
        SwordReach.Enabled = not SwordReach.Enabled
        refresh()
    end)

    hitboxButton.Activated:Connect(function()
        SwordReach.ShowHitboxes = not SwordReach.ShowHitboxes
        refresh()
    end)

    hideButton.Activated:Connect(function()
        panel.Visible = false
        showUIButton.Visible = true
    end)

    showUIButton.Activated:Connect(function()
        panel.Visible = true
        showUIButton.Visible = false
    end)

    sliderBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            setBonusFromX(input.Position.X)
        end
    end)

    sliderBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) or input.UserInputState == Enum.UserInputState.Change then
                setBonusFromX(input.Position.X)
            end
        end
    end)

    refresh()

    task.spawn(function()
        while gui.Parent do
            refresh()
            task.wait(0.25)
        end
    end)
end

createUI()

task.spawn(function()
    while true do
        refreshHitboxes()

        local character = localPlayer.Character
        if SwordReach.Enabled and character then
            local swordTier = getEquippedSwordTier(character)
            local target = getNearestTargetInReach(character, swordTier)
            setCurrentTargetRed(target)
        else
            setCurrentTargetRed(nil)
        end

        task.wait(0.2)
    end
end)

local function tryLocalHit()
    if not SwordReach.Enabled then
        setCurrentTargetRed(nil)
        return
    end

    local character = localPlayer.Character
    if not character then
        setCurrentTargetRed(nil)
        return
    end

    local swordTier = getEquippedSwordTier(character)
    local targetCharacter, distance, threshold = getNearestTargetInReach(character, swordTier)

    if not targetCharacter then
        setCurrentTargetRed(nil)
        print("No target in reach", "reach:", SwordReach.getReach(swordTier))
        return
    end

    setCurrentTargetRed(targetCharacter)
    flashHit(targetCharacter)

    local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
    print("Hit!", targetPlayer and "Player" or "NPC", "reach:", SwordReach.getReach(swordTier), "distance:", math.floor((distance or 0) * 100) / 100, "threshold:", math.floor((threshold or 0) * 100) / 100, "target:", targetCharacter.Name)
end

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        tryLocalHit()
    end
end)
