-- LocalScript 1本で完結するソードリーチ判定（BedWars風）
-- 例: StarterPlayerScripts に配置
-- NOTE: ローカル判定なので、実ダメージをサーバーで通す場合は別途Remote連携が必要です。

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
    BonusMax = 120,
    GlobalBonus = 60,
    Enabled = true,
}

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
    return base + math.clamp(SwordReach.GlobalBonus, SwordReach.BonusMin, SwordReach.BonusMax)
end

function SwordReach.canHit(attackerCharacter, targetCharacter, swordName)
    if not SwordReach.Enabled then return false end
    local attackerRoot = getModelRootPart(attackerCharacter)
    local targetRoot = getModelRootPart(targetCharacter)
    if not attackerRoot or not targetRoot then return false end

    local distance = (attackerRoot.Position - targetRoot.Position).Magnitude
    local padding = (attackerRoot.Size.Magnitude + targetRoot.Size.Magnitude) * 0.25
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

local function getNearestTargetInReach(attackerCharacter, swordTier)
    local attackerRoot = getModelRootPart(attackerCharacter)
    if not attackerRoot then return nil end

    local reach = SwordReach.getReach(swordTier)
    local nearest, nearestDist = nil, math.huge

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Humanoid") and obj.Health > 0 then
            local model = obj.Parent
            if model and model ~= attackerCharacter then
                local targetRoot = getModelRootPart(model)
                if targetRoot then
                    local dist = (targetRoot.Position - attackerRoot.Position).Magnitude
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

local function flashTarget(model)
    local h = Instance.new("Highlight")
    h.FillColor = Color3.fromRGB(255, 70, 70)
    h.OutlineColor = Color3.fromRGB(255, 255, 255)
    h.FillTransparency = 0.35
    h.OutlineTransparency = 0
    h.Adornee = model
    h.Parent = Workspace
    Debris:AddItem(h, 0.15)
end

local function createUI()
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

    local function refresh()
        toggleButton.Text = SwordReach.Enabled and "ON" or "OFF"
        toggleButton.BackgroundColor3 = SwordReach.Enabled and Color3.fromRGB(70, 140, 70) or Color3.fromRGB(150, 60, 60)
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
        refresh()
    end

    toggleButton.Activated:Connect(function()
        SwordReach.Enabled = not SwordReach.Enabled
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
end

createUI()

local function tryLocalHit()
    if not SwordReach.Enabled then return end
    local character = localPlayer.Character
    if not character then return end

    local swordTier = getEquippedSwordTier(character)
    local targetCharacter, dist = getNearestTargetInReach(character, swordTier)

    if not targetCharacter then
        print("No target in reach", "reach:", SwordReach.getReach(swordTier))
        return
    end

    local ok = SwordReach.canHit(character, targetCharacter, swordTier)
    if ok then
        flashTarget(targetCharacter)
        local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
        print("Hit!", targetPlayer and "Player" or "NPC", "reach:", SwordReach.getReach(swordTier), "distance:", math.floor((dist or 0) * 100) / 100, "target:", targetCharacter.Name)
    else
        print("Out of range", "reach:", SwordReach.getReach(swordTier), "distance:", math.floor((dist or 0) * 100) / 100)
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        tryLocalHit()
    end
end)
