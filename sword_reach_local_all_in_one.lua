-- LocalScript 1本で完結するソードリーチ判定（BedWars風）
-- 例: StarterPlayerScripts に配置

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera

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
    BonusMax = 40,
    GlobalBonus = 16,
    Enabled = true,
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

    local centerDistance = (attackerPart.Position - targetPart.Position).Magnitude
    local reach = SwordReach.getReach(swordName)
    local partPadding = (attackerPart.Size.Magnitude + targetPart.Size.Magnitude) * 0.2
    return centerDistance <= (reach + partPadding)
end

function SwordReach.canHit(attackerCharacter, targetCharacter, swordName)
    if not SwordReach.Enabled then
        return false
    end

    if not attackerCharacter or not targetCharacter then
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
    else
        return "Wood"
    end
end

local function getEquippedSwordTier(character)
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") then
            return resolveSwordTier(child.Name)
        end
    end
    return "Wood"
end

local function getValidTargetModelFromHumanoid(humanoid, attackerCharacter)
    if not humanoid or humanoid.Health <= 0 then
        return nil
    end

    local model = humanoid.Parent
    if not model or model == attackerCharacter then
        return nil
    end

    local root = getModelRootPart(model)
    if not root then
        return nil
    end

    return model
end

local function getPointerPosition(screenPos)
    if screenPos then
        return Vector2.new(screenPos.X, screenPos.Y)
    end
    local mouseLocation = UserInputService:GetMouseLocation()
    return Vector2.new(mouseLocation.X, mouseLocation.Y)
end

local function getBestTargetCharacter(attackerCharacter, swordTier, screenPos)
    local attackerRoot = getModelRootPart(attackerCharacter)
    if not attackerRoot then
        return nil
    end

    if not camera then
        camera = Workspace.CurrentCamera
    end

    local pointerPos = getPointerPosition(screenPos)
    local reach = SwordReach.getReach(swordTier)
    local bestTarget = nil
    local bestScore = math.huge

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Humanoid") then
            local model = getValidTargetModelFromHumanoid(obj, attackerCharacter)
            if model then
                local targetRoot = getModelRootPart(model)
                local worldDistance = (targetRoot.Position - attackerRoot.Position).Magnitude

                if worldDistance <= (reach + 6) then
                    local forward = attackerRoot.CFrame.LookVector
                    local dir = (targetRoot.Position - attackerRoot.Position).Unit
                    local forwardDot = forward:Dot(dir)

                    if forwardDot > -0.2 then
                        local screenPenalty = 0

                        if camera then
                            local viewportPos, onScreen = camera:WorldToViewportPoint(targetRoot.Position)
                            if onScreen then
                                local delta = Vector2.new(viewportPos.X, viewportPos.Y) - pointerPos
                                screenPenalty = delta.Magnitude * 0.03
                            else
                                screenPenalty = 12
                            end
                        end

                        local score = worldDistance + screenPenalty
                        if score < bestScore then
                            bestScore = score
                            bestTarget = model
                        end
                    end
                end
            end
        end
    end

    return bestTarget
end

local function createMobileUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "ReachControlGui"
    gui.ResetOnSpawn = false
    gui.Parent = localPlayer:WaitForChild("PlayerGui")

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
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
    bonusText.Text = "Bonus: +" .. tostring(SwordReach.GlobalBonus)
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

    local function refreshToggleVisual()
        if SwordReach.Enabled then
            toggleButton.Text = "ON"
            toggleButton.BackgroundColor3 = Color3.fromRGB(70, 140, 70)
        else
            toggleButton.Text = "OFF"
            toggleButton.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
        end
    end

    local function refreshSliderVisual()
        local range = math.max(SwordReach.BonusMax - SwordReach.BonusMin, 1)
        local fillAlpha = (SwordReach.GlobalBonus - SwordReach.BonusMin) / range
        sliderFill.Size = UDim2.new(math.clamp(fillAlpha, 0, 1), 0, 1, 0)
        bonusText.Text = "Bonus: +" .. tostring(SwordReach.GlobalBonus)
    end

    local function setBonusFromX(x)
        local left = sliderBar.AbsolutePosition.X
        local width = math.max(sliderBar.AbsoluteSize.X, 1)
        local alpha = math.clamp((x - left) / width, 0, 1)

        local rawBonus = SwordReach.BonusMin + (SwordReach.BonusMax - SwordReach.BonusMin) * alpha
        SwordReach.GlobalBonus = math.floor(rawBonus + 0.5)
        refreshSliderVisual()
    end

    toggleButton.Activated:Connect(function()
        SwordReach.Enabled = not SwordReach.Enabled
        refreshToggleVisual()
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

    refreshToggleVisual()
    refreshSliderVisual()
end

createMobileUI()

local function tryLocalHit(screenPos)
    if not SwordReach.Enabled then
        return
    end

    local character = localPlayer.Character
    if not character then
        return
    end

    local swordTier = getEquippedSwordTier(character)
    local targetCharacter = getBestTargetCharacter(character, swordTier, screenPos)
    if not targetCharacter then
        return
    end

    if SwordReach.canHit(character, targetCharacter, swordTier) then
        local aRoot = getModelRootPart(character)
        local tRoot = getModelRootPart(targetCharacter)
        local d = 0
        if aRoot and tRoot then
            d = (aRoot.Position - tRoot.Position).Magnitude
        end

        local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
        local targetType = targetPlayer and "Player" or "NPC"

        print("Hit!", "type:", targetType, "sword:", swordTier, "reach:", SwordReach.getReach(swordTier), "distance:", math.floor(d * 100) / 100, "target:", targetCharacter.Name)
    else
        print("Out of range")
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        tryLocalHit(nil)
    elseif input.UserInputType == Enum.UserInputType.Touch then
        tryLocalHit(input.Position)
    end
end)
