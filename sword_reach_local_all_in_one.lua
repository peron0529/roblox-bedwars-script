-- LocalScript 1本で完結するソードリーチ判定（BedWars風）
-- 例: StarterPlayerScripts に配置

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
    -- 「全部の剣のリーチを伸ばす」ための共通ボーナス
    GlobalBonus = 4,
    Default = 14,
}

function SwordReach.getReach(swordName)
    local base = SwordReach.BaseValues[swordName] or SwordReach.Default
    return base + SwordReach.GlobalBonus
end

function SwordReach.canHitFromParts(attackerPart, targetPart, swordName)
    if attackerPart == nil or targetPart == nil then
        return false
    end

    local distance = (attackerPart.Position - targetPart.Position).Magnitude
    return distance <= SwordReach.getReach(swordName)
end

function SwordReach.canHit(attackerCharacter, targetCharacter, swordName)
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

local function tryLocalHit()
    local character = localPlayer.Character
    if not character then
        return
    end

    local targetPart = mouse.Target
    if not targetPart then
        return
    end

    local targetModel = targetPart:FindFirstAncestorOfClass("Model")
    if not targetModel then
        return
    end

    local targetHumanoid = targetModel:FindFirstChildOfClass("Humanoid")
    if not targetHumanoid then
        return
    end

    local swordTier = getEquippedSwordTier(character)
    if SwordReach.canHit(character, targetModel, swordTier) then
        print("Hit! sword:", swordTier, "reach:", SwordReach.getReach(swordTier), "target:", targetModel.Name)
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
end)
