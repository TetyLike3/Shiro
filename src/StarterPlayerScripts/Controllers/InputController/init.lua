local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")


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
local CombatService

-- Controller Variables
local lightAttackCooldownEndTimestamp = 0
local heavyAttackCooldownEndTimestamp = 0

local isSprinting = false

local characterStatsPollRate = 60 -- in Heartbeat frames
local characterStatsCache : {
    walkSpeed : number
} = {
    walkSpeed = StarterPlayer.CharacterWalkSpeed
}


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
        CombatService:ToggleWeapon()
    elseif inputObject.UserInputType == Enum.UserInputType.MouseButton1 then -- M1 Attack
        local success, cooldownEndTimestamp = CombatService:LightAttack():await()
        if not success then warn("Failed to perform light attack") end
        lightAttackCooldownEndTimestamp = cooldownEndTimestamp
    elseif inputObject.UserInputType == Enum.UserInputType.MouseButton2 then -- M2 Attack
        local success, cooldownEndTimestamp = CombatService:HeavyAttack():await()
        if not success then warn("Failed to perform heavy attack") end
        heavyAttackCooldownEndTimestamp = cooldownEndTimestamp
    elseif inputObject.KeyCode == Enum.KeyCode.LeftShift then
        isSprinting = true
    end
end

-- Callback for when a user input is released
local function UISInputEndedCallback(inputObject : InputObject, gameProcessedEvent)
    if gameProcessedEvent then return end
    if inputObject.KeyCode == Enum.KeyCode.LeftShift then
        isSprinting = false
    end
end

-- Returns the weapon currently equipped on the player
local function getWeaponOnPlayer() : Model
    if not Players.LocalPlayer.Character then return end
    return Players.LocalPlayer.Character:FindFirstChild("Messer")
end



--[---------------------------]--
--[     FRAMEWORK METHODS     ]--
--[---------------------------]--


local debugPart = Instance.new("Part")
debugPart.Size = Vector3.new(1,1,1)
debugPart.Position = Vector3.zero
debugPart.Anchored = true
debugPart.Material = Enum.Material.Neon
debugPart.CanCollide = false
debugPart.Parent = workspace

-- Updates WeaponStatus UI
local function RenderSteppedCallback(deltaTime)
    local char = Players.LocalPlayer.Character
    if char then
        if isSprinting then
            char.Humanoid.WalkSpeed = StarterPlayer.CharacterWalkSpeed*4
        else
            char.Humanoid.WalkSpeed = StarterPlayer.CharacterWalkSpeed
        end

        -- Turn camera towards moving direction
        local camera = workspace.CurrentCamera
        local characterRotation = char.HumanoidRootPart.CFrame - char.HumanoidRootPart.Position
        local cameraRotX, cameraRotY, cameraRotZ = camera.CFrame:ToEulerAnglesXYZ()

        -- Tilt camera left/right based on if player is moving left/right
        --if char.Humanoid.MoveDirection

        -- Update camera rotation
        camera.CFrame = CFrame.new(camera.CFrame.Position) * CFrame.fromEulerAnglesXYZ(cameraRotX, cameraRotY, cameraRotZ)
    end

    -- Weapon status UI
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

local function HeartbeatCallback(deltaTime)
    local char = Players.LocalPlayer.Character
    if char then
        if characterStatsCache.walkSpeed == StarterPlayer.CharacterWalkSpeed then
            if isSprinting then
                char.Humanoid.WalkSpeed = StarterPlayer.CharacterWalkSpeed*4
            else
                char.Humanoid.WalkSpeed = StarterPlayer.CharacterWalkSpeed
            end
        else
            char.Humanoid.WalkSpeed = characterStatsCache.walkSpeed
        end
    end
end


local function characterAddedCallback(character)
    lightAttackCooldownEndTimestamp = 0
    heavyAttackCooldownEndTimestamp = 0

    local animateScript = script.Animate:Clone()
    local oldAnimateScript = character:FindFirstChild("Animate")
    if oldAnimateScript then oldAnimateScript:Destroy() end
    animateScript.Parent = character
    animateScript.Enabled = true
end

function InputController:FrameworkStart()
    game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false)
    UIS.InputBegan:Connect(UISInputBeganCallback)
    UIS.InputEnded:Connect(UISInputEndedCallback)

    getStatusUI().Enabled = true
    local RenderSteppedHandle = RunService.RenderStepped:Connect(RenderSteppedCallback)
    local HeartbeatHandle = RunService.Heartbeat:Connect(HeartbeatCallback)
    CombatService.CharacterStatsChanged:Connect(function(newStats) characterStatsCache = newStats end)

    Players.LocalPlayer.CharacterAdded:Connect(characterAddedCallback)
    local char = Players.LocalPlayer.Character
    if char then characterAddedCallback(char) end
end

function InputController:FrameworkInit()
    SkillController = Framework.GetController("SkillController")
    CombatService = Framework.GetService("CombatService")
end

return InputController