local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")


local _PlayerGui : PlayerGui
local function getPlayerGui() -- Returns PlayerGui
    if not _PlayerGui then
        _PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    end
    return _PlayerGui
end

local _StatusUI : Frame
local function getStatusUI() -- Returns the Status UI
    if not _StatusUI then
        _StatusUI = getPlayerGui():WaitForChild("StatusBars") :: Frame
    end
    return _StatusUI
end


-- Create Controller
local RS = game:GetService("ReplicatedStorage")
local Framework = require(RS.Framework.Internal.Kuro)

local InputController = Framework.CreateController { Name = "InputController" }

-- Module References
local SkillController
local WeaponService

-- Controller Variables
local lightAttackCooldownEndTimestamp = 0
local heavyAttackCooldownEndTimestamp = 0




--[---------------------------]--
--[          METHODS          ]--
--[---------------------------]--

-- Callback for when a user input is detected
local function UISInputBeganCallback(inputObject : InputObject, gameProcessedEvent)
    if gameProcessedEvent then return end
    if inputObject.KeyCode == Enum.KeyCode.One then
        SkillController:UseSkill(1)
    elseif inputObject.KeyCode == Enum.KeyCode.Two then
        SkillController:UseSkill(2)
    elseif inputObject.KeyCode == Enum.KeyCode.Three then
        SkillController:UseSkill(3)
    elseif inputObject.KeyCode == Enum.KeyCode.Four then
        SkillController:UseSkill(4)
    elseif inputObject.KeyCode == Enum.KeyCode.Five then
        SkillController:UseSkill(5)
    elseif inputObject.KeyCode == Enum.KeyCode.Six then
        SkillController:UseSkill(6)
    elseif inputObject.KeyCode == Enum.KeyCode.R then
        SkillController:UseSkill(7)
    elseif inputObject.KeyCode == Enum.KeyCode.T then
        SkillController:UseSkill(8)
    elseif inputObject.KeyCode == Enum.KeyCode.Y then
        SkillController:UseSkill(9)
    elseif inputObject.KeyCode == Enum.KeyCode.G then
        SkillController:UseSkill(10)
    elseif inputObject.KeyCode == Enum.KeyCode.E then
        WeaponService:ToggleWeapon()
    elseif inputObject.UserInputType == Enum.UserInputType.MouseButton1 then -- M1 Attack
        local success, cooldownEndTimestamp = WeaponService:LightAttack():await()
        if not success then warn("Failed to perform light attack") end
        lightAttackCooldownEndTimestamp = cooldownEndTimestamp
    elseif inputObject.UserInputType == Enum.UserInputType.MouseButton2 then -- M2 Attack
        local success, cooldownEndTimestamp = WeaponService:HeavyAttack():await()
        if not success then warn("Failed to perform heavy attack") end
        heavyAttackCooldownEndTimestamp = cooldownEndTimestamp
    end
end

-- Returns the weapon currently equipped on the player
local function getWeaponOnPlayer() : Model
    if not Players.LocalPlayer.Character then return end
    return Players.LocalPlayer.Character:FindFirstChild("Messer")
end



--[---------------------------]--
--[        KNIT METHODS       ]--
--[---------------------------]--


-- Updates WeaponStatus UI
local function WeaponStatusUIUpdate(deltaTime)
    local statusUI : Frame = getStatusUI().WeaponStatus
    local weapon = getWeaponOnPlayer()

    -- Toggle UI based on weapon presence
    if not weapon then
        if statusUI.Visible then statusUI.Visible = false end
    else
        if not statusUI.Visible then statusUI.Visible = true end
    end

    -- Update light attack cooldown
    if lightAttackCooldownEndTimestamp then
        local cooldownValue = 0
        local cooldownDiff = lightAttackCooldownEndTimestamp - (DateTime.now().UnixTimestampMillis/1000)
        if cooldownDiff > 0 then cooldownValue = cooldownDiff/weapon:GetAttribute("LightAttackCooldown") end
        statusUI.WeaponLightCooldown.CooldownOverlay.Size = UDim2.fromScale(1,cooldownValue)
    end

    -- Update heavy attack cooldown
    if heavyAttackCooldownEndTimestamp then
        local cooldownValue = 0
        local cooldownDiff = heavyAttackCooldownEndTimestamp - (DateTime.now().UnixTimestampMillis/1000)
        if cooldownDiff > 0 then cooldownValue = cooldownDiff/weapon:GetAttribute("HeavyAttackCooldown") end
        statusUI.WeaponHeavyCooldown.CooldownOverlay.Size = UDim2.fromScale(1,cooldownValue)
    end
end


function InputController:FrameworkStart()
    game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false)
    UIS.InputBegan:Connect(UISInputBeganCallback)

    getStatusUI().Enabled = true
    local weaponStatusUIUpdateHandle = RunService.RenderStepped:Connect(WeaponStatusUIUpdate)
end

function InputController:FrameworkInit()
    SkillController = Framework.GetController("SkillController")
    WeaponService = Framework.GetService("WeaponService")
end

return InputController