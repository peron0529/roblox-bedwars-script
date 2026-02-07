-- LocalScript 1本で完結するソードリーチ判定（BedWars風）
-- 例: StarterPlayerScripts に配置
-- 追加機能:
-- 1) NPCへの適用（ターゲットがNPCでも判定）
-- 2) リーチ増加量をスライダーで調整
-- 3) モバイル向けタップON/OFF

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local mouse = localPlayer:GetMouse()

local SwordReach = {
    -- BedWars系の剣ティア
    BaseValues = {
        Wood = 14,
        Stone = 15,
        Iron = 16,
        Diamond = 17,
        Emerald = 18,
    },
    Default = 14,
    BonusMin = 0,
    BonusMax = 10,
    GlobalBonus = 4,
    Enabled = true,
}

function SwordReach.getReach(swordName)
    local base = SwordReach.BaseValues[swordName] or SwordReach.Default
    local bonus = math.clamp(SwordReach.GlobalBonus, SwordReach.BonusMin, SwordReach.BonusMax)
    return base + bonus
end

function SwordReach.canHitFromParts(attackerPart, targetPart, swordName)
    if attackerPart == nil or targetPart == nil then
        return false
    end

    local distance = (attackerPart.Position - targetPart.Position).Magnitude
    return distance <= SwordReach.getReach(swordName)
end

function SwordReach.canHit(attackerCharacter, targetCharacter, swordName)
    if not SwordReach.Enabled then
        return false
    end

    if attackerCharacter == nil or targetCharacter == nil then
        return false
    end

    local attackerRoot = attackerCharacter:FindFirstChild("HumanoidRootPart")
    local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
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

local function createMobileUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "ReachControlGui"
    gui.ResetOnSpawn = false
    gui.Parent = localPlayer:WaitForChild("PlayerGui")

    local panel = Instance.new("Frame")
    panel.Size = UDim2.fromOffset(230, 120)
    panel.Position = UDim2.new(0, 12, 1, -132)
    panel.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    panel.BorderSizePixel = 0
    panel.Parent = gui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -12, 0, 24)
    title.Position = UDim2.fromOffset(6, 4)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "Sword Reach Control"
    title.Parent = panel

    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.fromOffset(90, 28)
    toggleButton.Position = UDim2.fromOffset(8, 34)
    toggleButton.BackgroundColor3 = Color3.fromRGB(70, 140, 70)
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.Text = "ON"
    toggleButton.Parent = panel

    local bonusText = Instance.new("TextLabel")
    bonusText.Size = UDim2.new(1, -12, 0, 20)
    bonusText.Position = UDim2.fromOffset(6, 66)
    bonusText.BackgroundTransparency = 1
    bonusText.TextXAlignment = Enum.TextXAlignment.Left
    bonusText.TextColor3 = Color3.fromRGB(230, 230, 230)
    bonusText.Text = "Bonus: +" .. tostring(SwordReach.GlobalBonus)
    bonusText.Parent = panel

    local sliderBar = Instance.new("Frame")
    sliderBar.Size = UDim2.new(1, -16, 0, 10)
    sliderBar.Position = UDim2.fromOffset(8, 94)
    sliderBar.BackgroundColor3 = Color3.fromRGB(65, 65, 70)
    sliderBar.BorderSizePixel = 0
    sliderBar.Parent = panel

    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new(0, 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(60, 170, 255)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBar

    local function refreshToggleVisual()
        if SwordReach.Enabled then
            toggleButton.Text = "ON"
            toggleButton.BackgroundColor3 = Color3.fromRGB(70, 140, 70)
        else
            toggleButton.Text = "OFF"
            toggleButton.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
        end
    end

    local function setBonusFromX(x)
        local left = sliderBar.AbsolutePosition.X
        local width = math.max(sliderBar.AbsoluteSize.X, 1)
        local alpha = math.clamp((x - left) / width, 0, 1)
        local rawBonus = SwordReach.BonusMin + (SwordReach.BonusMax - SwordReach.BonusMin) * alpha
        SwordReach.GlobalBonus = math.floor(rawBonus + 0.5)

        local fillAlpha = (SwordReach.GlobalBonus - SwordReach.BonusMin) / (SwordReach.BonusMax - SwordReach.BonusMin)
        sliderFill.Size = UDim2.new(fillAlpha, 0, 1, 0)
        bonusText.Text = "Bonus: +" .. tostring(SwordReach.GlobalBonus)
    end

    toggleButton.Activated:Connect(function()
        SwordReach.Enabled = not SwordReach.Enabled
        refreshToggleVisual()
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

    setBonusFromX(sliderBar.AbsolutePosition.X + sliderBar.AbsoluteSize.X * ((SwordReach.GlobalBonus - SwordReach.BonusMin) / (SwordReach.BonusMax - SwordReach.BonusMin)))
    refreshToggleVisual()
end

createMobileUI()

local function getCharacterFromTargetPart(targetPart)
    local targetModel = targetPart:FindFirstAncestorOfClass("Model")
    if not targetModel then
        return nil
    end

    local humanoid = targetModel:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return nil
    end

    return targetModel
end

local function tryLocalHit()
    if not SwordReach.Enabled then
        return
    end

    local character = localPlayer.Character
    if not character then
        return
    end

    local targetPart = mouse.Target
    if not targetPart then
        return
    end

    local targetCharacter = getCharacterFromTargetPart(targetPart)
    if not targetCharacter then
        return
    end

    local swordTier = getEquippedSwordTier(character)

    -- プレイヤー・NPCどちらにも同じ判定を適用
    if SwordReach.canHit(character, targetCharacter, swordTier) then
        print("Hit! sword:", swordTier, "reach:", SwordReach.getReach(swordTier), "target:", targetCharacter.Name)
    else
        print("Out of range")
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        tryLocalHit()
    end

    -- モバイルの画面タップでも判定
    if input.UserInputType == Enum.UserInputType.Touch then
        tryLocalHit()
    end
end)
