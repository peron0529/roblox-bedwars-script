-- LocalScript 1本で完結するソードリーチ判定（BedWars風）
-- 例: StarterPlayerScripts に配置

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

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
    BonusMax = 60,
    GlobalBonus = 25,
    Enabled = true,
    TargetingAngleMinDot = -1, -- -1で全方向許可（確実にリーチ効果を感じる設定）
    ExtraAcquireRange = 8,
}

local function getModelRootPart(model)
    if not model then
        return nil
    end

    return model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
        or model:FindFirstChild("UpperTorso")
        or model:FindFirstChild("Torso")
        or model:FindFirstChild("Head")
end

function SwordReach.getReach(swordName)
    local base = SwordReach.BaseValues[swordName] or SwordReach.Default
    local bonus = math.clamp(SwordReach.GlobalBonus, SwordReach.BonusMin, SwordReach.BonusMax)
    return base + bonus
end

function SwordReach.canHitFromParts(attackerPart, targetPart, swordName)
    if not attackerPart or not targetPart then
        return false
    end

    local distance = (attackerPart.Position - targetPart.Position).Magnitude
    local reach = SwordReach.getReach(swordName)
    local partPadding = (attackerPart.Size.Magnitude + targetPart.Size.Magnitude) * 0.25
    return distance <= (reach + partPadding)
end

function SwordReach.canHit(attackerCharacter, targetCharacter, swordName)
    if not SwordReach.Enabled then
        return false
    end

    local attackerRoot = getModelRootPart(attackerCharacter)
    local targetRoot = getModelRootPart(targetCharacter)
    return SwordReach.canHitFromParts(attackerRoot, targetRoot, swordName)
end

local function resolveSwordTier(toolName)
    if not toolName then
        return "Wood"
    end

    local n = string.lower(toolName)
    if string.find(n, "emerald") then
        return "Emerald"
    elseif string.find(n, "diamond") then
        return "Diamond"
    elseif string.find(n, "iron") then
        return "Iron"
    elseif string.find(n, "stone") then
        return "Stone"
    end
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

local function getNearestReachableTarget(attackerCharacter, swordTier)
    local attackerRoot = getModelRootPart(attackerCharacter)
    if not attackerRoot then
        return nil, math.huge
    end

    local reach = SwordReach.getReach(swordTier) + SwordReach.ExtraAcquireRange
    local nearestModel = nil
    local nearestDistance = math.huge
    local forward = attackerRoot.CFrame.LookVector

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Humanoid") and obj.Health > 0 then
            local model = obj.Parent
            if model and model ~= attackerCharacter then
                local root = getModelRootPart(model)
                if root then
                    local offset = root.Position - attackerRoot.Position
                    local distance = offset.Magnitude
                    if distance <= reach then
                        local dir = (distance > 0) and offset.Unit or forward
                        local dot = forward:Dot(dir)
                        if dot >= SwordReach.TargetingAngleMinDot and distance < nearestDistance then
                            nearestDistance = distance
                            nearestModel = model
                        end
                    end
                end
            end
        end
    end

    return nearestModel, nearestDistance
end

local function createMobileUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "ReachControlGui"
    gui.ResetOnSpawn = false
    gui.Parent = localPlayer:WaitForChild("PlayerGui")

    local panel = Instance.new("Frame")
    panel.Size = UDim2.fromOffset(230, 128)
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

    local bonusText = Instance.new("TextLabel")
    bonusText.Size = UDim2.new(1, -12, 0, 20)
    bonusText.Position = UDim2.fromOffset(6, 70)
    bonusText.BackgroundTransparency = 1
    bonusText.TextXAlignment = Enum.TextXAlignment.Left
    bonusText.TextColor3 = Color3.fromRGB(230, 230, 230)
    bonusText.Parent = panel

    local sliderBar = Instance.new("Frame")
    sliderBar.Size = UDim2.new(1, -16, 0, 10)
    sliderBar.Position = UDim2.fromOffset(8, 100)
    sliderBar.BackgroundColor3 = Color3.fromRGB(65, 65, 70)
    sliderBar.BorderSizePixel = 0
    sliderBar.Parent = panel

    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new(0, 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(60, 170, 255)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBar

    local showUIButton = Instance.new("TextButton")
    showUIButton.Size = UDim2.fromOffset(52, 28)
    showUIButton.AnchorPoint = Vector2.new(1, 1)
    showUIButton.Position = UDim2.new(1, -12, 1, -12)
    showUIButton.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    showUIButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    showUIButton.Text = "UI"
    showUIButton.Visible = false
    showUIButton.Parent = gui

    local function refreshToggle()
        if SwordReach.Enabled then
            toggleButton.Text = "ON"
            toggleButton.BackgroundColor3 = Color3.fromRGB(70, 140, 70)
        else
            toggleButton.Text = "OFF"
            toggleButton.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
        end
    end

    local function refreshSlider()
        local range = math.max(SwordReach.BonusMax - SwordReach.BonusMin, 1)
        local fill = (SwordReach.GlobalBonus - SwordReach.BonusMin) / range
        sliderFill.Size = UDim2.new(math.clamp(fill, 0, 1), 0, 1, 0)
        bonusText.Text = "Bonus: +" .. tostring(SwordReach.GlobalBonus)
    end

    local function setBonusFromX(x)
        local left = sliderBar.AbsolutePosition.X
        local width = math.max(sliderBar.AbsoluteSize.X, 1)
        local alpha = math.clamp((x - left) / width, 0, 1)
        local raw = SwordReach.BonusMin + (SwordReach.BonusMax - SwordReach.BonusMin) * alpha
        SwordReach.GlobalBonus = math.floor(raw + 0.5)
        refreshSlider()
    end

    toggleButton.Activated:Connect(function()
        SwordReach.Enabled = not SwordReach.Enabled
        refreshToggle()
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

    refreshToggle()
    refreshSlider()
end

createMobileUI()

local function tryLocalHit()
    if not SwordReach.Enabled then
        return
    end

    local character = localPlayer.Character
    if not character then
        return
    end

    local swordTier = getEquippedSwordTier(character)
    local targetCharacter, nearestDistance = getNearestReachableTarget(character, swordTier)
    if not targetCharacter then
        print("No target in reach", "reach:", SwordReach.getReach(swordTier))
        return
    end

    if SwordReach.canHit(character, targetCharacter, swordTier) then
        local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
        local targetType = targetPlayer and "Player" or "NPC"
        print("Hit!", "type:", targetType, "sword:", swordTier, "reach:", SwordReach.getReach(swordTier), "distance:", math.floor(nearestDistance * 100) / 100, "target:", targetCharacter.Name)
    else
        print("Out of range", "reach:", SwordReach.getReach(swordTier), "distance:", math.floor(nearestDistance * 100) / 100)
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        tryLocalHit()
    end
end)
