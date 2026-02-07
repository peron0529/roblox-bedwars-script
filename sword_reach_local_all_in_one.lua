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
        Stone = 15,
        Iron = 16,
        Diamond = 17,
        Emerald = 18,
    },
    Default = 14,
    BonusMin = 0,
    BonusMax = 200,
    GlobalBonus = 100,
    ReachScale = 3, -- 実効リーチを強く反映
    Enabled = true,
    ShowHitboxes = true,
}

local hitboxBoxes = {}
local currentTargetHighlight

local function getModelRootPart(model)
    if not model then return nil end
    return model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
        or model:FindFirstChild("UpperTorso")
        or model:FindFirstChild("Torso")
        or model:FindFirstChild("Head")
end

function SwordReach.getReach(swordName)
    local base = SwordReach.BaseValues[swordName] or SwordReach.Default
    local bonus = math.clamp(SwordReach.GlobalBonus, SwordReach.BonusMin, SwordReach.BonusMax)
    return base + (bonus * SwordReach.ReachScale)
end

function SwordReach.canHit(attackerCharacter, targetCharacter, swordName)
    if not SwordReach.Enabled then return false end

    local attackerRoot = getModelRootPart(attackerCharacter)
    local targetRoot = getModelRootPart(targetCharacter)
    if not attackerRoot or not targetRoot then return false end

    local distance = (attackerRoot.Position - targetRoot.Position).Magnitude
    local padding = (attackerRoot.Size.Magnitude + targetRoot.Size.Magnitude) * 0.35
    return distance <= (SwordReach.getReach(swordName) + padding), distance
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

local function flashTarget(model)
    local h = Instance.new("Highlight")
    h.FillColor = Color3.fromRGB(255, 70, 70)
    h.OutlineColor = Color3.fromRGB(255, 255, 255)
    h.FillTransparency = 0.3
    h.OutlineTransparency = 0
    h.Adornee = model
    h.Parent = Workspace
    Debris:AddItem(h, 0.2)
end

local function setCurrentTargetRed(model)
    if model == nil then
        if currentTargetHighlight then
            currentTargetHighlight:Destroy()
            currentTargetHighlight = nil
        end
        return
    end

    if not currentTargetHighlight then
        currentTargetHighlight = Instance.new("Highlight")
        currentTargetHighlight.Name = "CurrentTargetRed"
        currentTargetHighlight.FillColor = Color3.fromRGB(255, 40, 40)
        currentTargetHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        currentTargetHighlight.FillTransparency = 0.55
        currentTargetHighlight.OutlineTransparency = 0
        currentTargetHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        currentTargetHighlight.Parent = Workspace
    end

    currentTargetHighlight.Adornee = model
end

local function setHitboxVisible(model, visible)
    local root = getModelRootPart(model)
    if not root then return end

    local box = hitboxBoxes[model]
    if visible then
        if not box then
            box = Instance.new("BoxHandleAdornment")
            box.Name = "ReachHitbox"
            box.AlwaysOnTop = true
            box.ZIndex = 5
            box.Transparency = 0.72
            box.Color3 = Color3.fromRGB(80, 190, 255)
            box.Parent = Workspace
            hitboxBoxes[model] = box
        end

        box.Adornee = root
        box.Size = root.Size + Vector3.new(0.3, 0.3, 0.3)
    elseif box then
        box:Destroy()
        hitboxBoxes[model] = nil
    end
end

local function refreshHitboxes()
    local character = localPlayer.Character
    if not character then return end

    if not SwordReach.ShowHitboxes then
        for model, _ in pairs(hitboxBoxes) do
            setHitboxVisible(model, false)
        end
        return
    end

    local attackerRoot = getModelRootPart(character)
    if not attackerRoot then return end

    local swordTier = getEquippedSwordTier(character)
    local reach = SwordReach.getReach(swordTier) + 30

    local seen = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Humanoid") and obj.Health > 0 then
            local model = obj.Parent
            if model and model ~= character then
                local root = getModelRootPart(model)
                if root then
                    local dist = (root.Position - attackerRoot.Position).Magnitude
                    if dist <= reach then
                        seen[model] = true
                        setHitboxVisible(model, true)
                    end
                end
            end
        end
    end

    for model, _ in pairs(hitboxBoxes) do
        if not seen[model] then
            setHitboxVisible(model, false)
        end
    end
end

local function getNearestTargetInReach(attackerCharacter, swordTier)
    local attackerRoot = getModelRootPart(attackerCharacter)
    if not attackerRoot then return nil, math.huge end

    local reach = SwordReach.getReach(swordTier)
    local nearest, nearestDist = nil, math.huge

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Humanoid") and obj.Health > 0 then
            local model = obj.Parent
            if model and model ~= attackerCharacter then
                local root = getModelRootPart(model)
                if root then
                    local dist = (root.Position - attackerRoot.Position).Magnitude
                    if dist <= reach and dist < nearestDist then
                        nearest = model
                        nearestDist = dist
                    end
                end
            end
        end
    end

    return nearest, nearestDist
end

local function createUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "ReachControlGui"
    gui.ResetOnSpawn = false
    gui.Parent = localPlayer:WaitForChild("PlayerGui")

    local panel = Instance.new("Frame")
    panel.Size = UDim2.fromOffset(260, 170)
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
    bonusText.Position = UDim2.fromOffset(6, 70)
    bonusText.BackgroundTransparency = 1
    bonusText.TextXAlignment = Enum.TextXAlignment.Left
    bonusText.TextColor3 = Color3.fromRGB(230, 230, 230)
    bonusText.Parent = panel

    local effectiveText = Instance.new("TextLabel")
    effectiveText.Size = UDim2.new(1, -12, 0, 20)
    effectiveText.Position = UDim2.fromOffset(6, 88)
    effectiveText.BackgroundTransparency = 1
    effectiveText.TextXAlignment = Enum.TextXAlignment.Left
    effectiveText.TextColor3 = Color3.fromRGB(255, 180, 90)
    effectiveText.Parent = panel

    local sliderBar = Instance.new("Frame")
    sliderBar.Size = UDim2.new(1, -16, 0, 10)
    sliderBar.Position = UDim2.fromOffset(8, 112)
    sliderBar.BackgroundColor3 = Color3.fromRGB(65, 65, 70)
    sliderBar.BorderSizePixel = 0
    sliderBar.Parent = panel

    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new(0, 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(60, 170, 255)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBar

    local infoText = Instance.new("TextLabel")
    infoText.Size = UDim2.new(1, -12, 0, 38)
    infoText.Position = UDim2.fromOffset(6, 126)
    infoText.BackgroundTransparency = 1
    infoText.TextXAlignment = Enum.TextXAlignment.Left
    infoText.TextYAlignment = Enum.TextYAlignment.Top
    infoText.TextColor3 = Color3.fromRGB(180, 180, 190)
    infoText.TextSize = 12
    infoText.TextWrapped = true
    infoText.Text = "対象は赤色ハイライト。Hitbox表示も切替可能"
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
    local targetCharacter, dist = getNearestTargetInReach(character, swordTier)

    if not targetCharacter then
        setCurrentTargetRed(nil)
        print("No target in reach", "reach:", SwordReach.getReach(swordTier))
        return
    end

    setCurrentTargetRed(targetCharacter)

    local ok, calcDist = SwordReach.canHit(character, targetCharacter, swordTier)
    if ok then
        flashTarget(targetCharacter)
        local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
        print("Hit!", targetPlayer and "Player" or "NPC", "reach:", SwordReach.getReach(swordTier), "distance:", math.floor(((calcDist or dist or 0) * 100)) / 100, "target:", targetCharacter.Name)
    else
        print("Out of range", "reach:", SwordReach.getReach(swordTier), "distance:", math.floor(((calcDist or dist or 0) * 100)) / 100)
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        tryLocalHit()
    end
end)
