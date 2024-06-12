local Debris = game:GetService("Debris")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer") -- For things like base walkspeed
local TS = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Framework = require(RS.Framework.Internal.Kuro)

local StorageFolder
local VFXFolder

local RagdollService


--? Prevent module from loading server-side features on the client
if game:GetService("RunService"):IsServer() then
    StorageFolder = Framework.ServerStorage:WaitForChild("Skills") :: Folder
    VFXFolder = StorageFolder._VFX :: Folder

    -- Get required services
    Framework.OnStart():andThen(function()
        RagdollService = Framework.GetService("RagdollService")
    end)
end



--[---------------------------]--
--[      HELPER FUNCTIONS     ]--
--[---------------------------]--


-- Create a part with the CollisionGroup set to "SkillGroup"
local function createPart() : Part
    local part = Instance.new("Part")
    part.CollisionGroup = "SkillGroup"

    return part
end

-- Create a VFX attachment on a parent object
local function CreateVFX(vfxName: string, offset: Vector3?)
    local vfx : Attachment = VFXFolder:FindFirstChild(vfxName).Attachment:Clone()
    if offset then
        vfx.Position = offset
    end
    return vfx
end

-- Hide a character
local function HideCharacter(character: Model, state : boolean)
    local value = (state and 1) or 0
    for _,part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") and not (part.Name == "HumanoidRootPart") then
            part.Transparency = value
        elseif part:IsA("Accessory") then
            part.Handle.Transparency = value
        elseif part:IsA("Decal") then
            part.Transparency = value
        end
    end
end

-- Create a shadow of a character that fades out
local function CreateCharacterShadow(character: Model)
    for _,part in pairs(character:GetChildren()) do
        if part:IsA("Part") and not (part.Name == "HumanoidRootPart") then
            local shadow = createPart()
            shadow.Size = part.Size
            shadow.Anchored = true
            shadow.CanCollide = false
            shadow.Transparency = .6
            shadow.CFrame = part.CFrame
            shadow.Color = Color3.fromRGB(0,0,0)
            shadow.Parent = part
            if part.Name == "Head" then
                local headMesh = part:FindFirstChildOfClass("SpecialMesh"):Clone()
                headMesh.Parent = shadow
                shadow.Size = Vector3.new(1,1,1)
            end

            task.spawn(function()
                local tweenInfo = TweenInfo.new(.4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true)
                local tween = TS:Create(shadow, tweenInfo, {Transparency = 1})
                tween:Play()
                task.wait(.4)
                shadow:Destroy()
            end)
        end
    end
    local shadowStepSound : Sound = StorageFolder.Sonido:FindFirstChild("ShadowStep"):Clone()
    shadowStepSound.Parent = character
    shadowStepSound:Play()
    Debris:AddItem(shadowStepSound, shadowStepSound.TimeLength)
end

-- Check if a character is moving
local function isCharacterMoving(character: Model) : boolean
    local hum = character:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    return hum.MoveDirection.Magnitude > 0
end

local function quickWeld(part0: Instance, part1: Instance)
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = part0
    weld.Part1 = part1
    weld.Parent = part0
    return weld
end

local function applyOverride(overridesTable : {[string]: any}, variableName : string, defaultValue : any)
    if overridesTable[variableName] ~= nil then
        return overridesTable[variableName]
    else
        return defaultValue
    end
end



--[---------------------------]--
--[           MODULE          ]--
--[---------------------------]--

local Types = require(script.Types)

local SkillsModule = {}

-- Skill categories
SkillsModule.SkillTypes = {
    Offensive = "Offensive",
    Defensive = "Defensive",
    Utility = "Utility"
}


-- A wrapper function that handles cooldowns
local function WrapUseFunction(skill: Types.SkillType, skillUseFunction: Types.SkillUseFunction) : Types.SkillUseFunction
    local wrapped: Types.SkillUseFunction = function(skill: Types.SkillType, inputData: Types.SkillInputData)
        -- Check if the skill is on cooldown
        if skill.CooldownEndTimestamp <= DateTime.now().UnixTimestampMillis/1000 then
            skill.Active = true
            local returnData = skillUseFunction(skill, inputData)
            skill.Active = false
            if returnData.startCooldown then skill.CooldownEndTimestamp = (DateTime.now().UnixTimestampMillis/1000) + skill.Cooldown end
            return returnData
        else
            print("Skill on cooldown")
        end
    end
    return wrapped
end

-- Create a skill object, given the name, category, cooldown time (seconds), and code when used.
function SkillsModule.CreateSkill(name: string, skillType: string, cooldown: number, useFunction: Types.SkillUseFunction)
    local skill: Types.SkillType = {
        Name = name,
        Type = skillType,
        Cooldown = cooldown,
        CooldownEndTimestamp = 0,
        Active = false
    }
    -- Wrap use function
    skill.Use = WrapUseFunction(skill, useFunction)
    return skill
end


--? Return early if this module is required from the client
if game:GetService("RunService"):IsClient() then
    return SkillsModule
end

--[---------------------------]--
--[           SKILLS          ]--
--[---------------------------]--

--! Skill Use functions are always run server-side
local Skills : {[string]: Types.SkillType} = {}



--[         FLASH STEP        ]--

--#region

-- Variables
local FlashStepDuration = .8
local FlashStepSpeed = 70
local FlashStepShadowFrequency = .24
local FlashStepStandingMultiplier = 0.2

-- Skill code
Skills.FlashStepSkill = SkillsModule.CreateSkill("Sonido", SkillsModule.SkillTypes.Utility, 3.2, function(skill: Types.SkillType, inputData: Types.SkillInputData) : Types.SkillOutputData
    local skillDuration = applyOverride(inputData.playerOverrides, "FlashStepDuration", FlashStepDuration)
    local skillSpeed = applyOverride(inputData.playerOverrides, "FlashStepSpeed", FlashStepSpeed)
    local skillShadowFrequency = applyOverride(inputData.playerOverrides, "FlashStepShadowFrequency", FlashStepShadowFrequency)
    local skillStandingMultiplier = applyOverride(inputData.playerOverrides, "FlashStepStandingMultiplier", FlashStepStandingMultiplier)
    
    task.spawn(function()
        local char = skill.Caster.Character
        local hum = char.Humanoid
        hum.WalkSpeed = skillSpeed
        HideCharacter(char, true)
    
        char:FindFirstChild("Left Leg"):FindFirstChild("Footstep").Volume = 0
        char:FindFirstChild("Right Leg"):FindFirstChild("Footstep").Volume = 0
        task.spawn(function()
            repeat
                if not isCharacterMoving(char) then
                    task.wait(.1)
                else
                    CreateCharacterShadow(char)
                    task.wait(skillShadowFrequency)
                end
            until skill.Active == false
            char:FindFirstChild("Left Leg"):FindFirstChild("Footstep").Volume = .5
            char:FindFirstChild("Right Leg"):FindFirstChild("Footstep").Volume = .5
        end)
    
        local timeInFlashStep = 0
        repeat
            task.wait(0.1)
            if not isCharacterMoving(char) then
                timeInFlashStep += 0.1*skillStandingMultiplier
            else
                timeInFlashStep += 0.1
            end
        until timeInFlashStep >= skillDuration
        hum.WalkSpeed = StarterPlayer.CharacterWalkSpeed
        task.wait(.2)
        HideCharacter(char, false)
    end)

    return {startCooldown = true, newCharacterStats = {walkSpeed = skillSpeed}}
end)

--#endregion

--[            HOP           ]--

--#region

-- Skill code
Skills.HopSkill = SkillsModule.CreateSkill("Hop", SkillsModule.SkillTypes.Utility, 1, function(skill: Types.SkillType, inputData: Types.SkillInputData) : Types.SkillOutputData
    local humRootPart = skill.Caster.Character.HumanoidRootPart
    local newPos = humRootPart.Position + (Vector3.yAxis * 20)
    skill.Caster.Character:MoveTo(newPos)
    return {startCooldown = true}
end)

--#endregion

--[         FIREBALL         ]--

--#region

-- Variables
local FireballLifetime = 6
local FireballSpeed = 240
local FireballDamage = 40
local FireballSize = 2.4

-- Skill code
Skills.FireballSkill = SkillsModule.CreateSkill("Fireball", SkillsModule.SkillTypes.Offensive, .02, function(skill: Types.SkillType, inputData: Types.SkillInputData) : Types.SkillOutputData
    local humRootPart = skill.Caster.Character.HumanoidRootPart
    local humanoid = skill.Caster.Character.Humanoid

    -- Fireball part
    local fireball = createPart()
    fireball.Shape = Enum.PartType.Ball
    fireball.Material = Enum.Material.Rock
    fireball.Color = Color3.fromRGB(58, 58, 58)
    fireball.Size = Vector3.one * FireballSize

    -- Physics
    local fireballAttachment = Instance.new("Attachment")
    fireballAttachment.Parent = fireball
    local fireballVelocity = Instance.new("LinearVelocity")
    fireballVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    fireballVelocity.VectorVelocity = humRootPart.CFrame.LookVector * FireballSpeed
    fireballVelocity.ForceLimitsEnabled = false
    fireballVelocity.Attachment0 = fireballAttachment
    fireballVelocity.Parent = fireball

    -- Position fireball
    fireball.CFrame = humRootPart.CFrame + (humRootPart.CFrame.LookVector * ((humanoid.WalkSpeed/30 * humanoid.MoveDirection.Magnitude) + 2))
    fireball.Name = string.format("%s_Fireball_%s", skill.Caster.Name, HttpService:GenerateGUID(false))
    fireball.Parent = workspace

    -- Hitbox
    local hitbox = StorageFolder.Fireball:FindFirstChild("Hitbox"):Clone()
    hitbox.CFrame = fireball.CFrame
    hitbox.Parent = fireball
    local hitboxWeld = quickWeld(fireball, hitbox)

    hitbox.Touched:Connect(function(hit)
        if hit.Name ~= "HumanoidRootPart" then return end
        if hit.Parent == skill.Caster.Character then return end
        if hit.Parent:FindFirstChild("Humanoid") then
            hit.Parent.Humanoid.Health -= FireballDamage
            RagdollService:RagdollRig(hit.Parent, 1, fireball.CFrame.Position)
            fireball:Destroy()
        end
    end)
    Debris:AddItem(fireball, FireballLifetime)

    -- FX code
    task.spawn(function()
        local fireballLoop1 = StorageFolder.Fireball:FindFirstChild("FireballLoop1"):Clone() :: Sound
        fireballLoop1.Parent = Framework.TempStorage
        local fireballLoop2 = StorageFolder.Fireball:FindFirstChild("FireballLoop2"):Clone() :: Sound
        fireballLoop2.Parent = Framework.TempStorage
        local fireballFire = CreateVFX("Fire")
        fireballFire.Parent = Framework.TempStorage.AttachmentParent

        Framework.FXReplicator:FireSoundFXEvent(fireballLoop1, fireball)
        Framework.FXReplicator:FireSoundFXEvent(fireballLoop2, fireball)
        Framework.FXReplicator:FireParticleFXEvent(fireballFire, fireball, FireballLifetime)
    end)

    -- Set player to network owner of fireball (probably a vantage point for exploiters)
    fireball:SetNetworkOwner(skill.Caster)

    return {startCooldown = true}
end)

--#endregion

--[          GODRAY          ]--

--#region

-- Variables
local GodrayHitTime = 1.5
local GodrayDamage = 90
local GodrayRadius = 52
local GodrayMaxDistance = 192

-- Skill code
Skills.GodraySkill = SkillsModule.CreateSkill("Godray", SkillsModule.SkillTypes.Offensive, 3, function(skill : Types.SkillType, inputData: Types.SkillInputData) : Types.SkillOutputData
    local godrayTargetPoint = inputData.mouseHitPosition
    if (godrayTargetPoint - skill.Caster.Character.HumanoidRootPart.Position).Magnitude > GodrayMaxDistance then return {startCooldown = false} end

    local godrayPart = createPart()
    godrayPart.Name = "Godray"
    godrayPart.Shape = Enum.PartType.Cylinder
    godrayPart.Size = Vector3.new(512,GodrayRadius*1.75,GodrayRadius*1.75)
    godrayPart.Anchored = true
    godrayPart.CanCollide = false
    godrayPart.Transparency = 1
    godrayPart.Material = Enum.Material.Neon
    godrayPart.Color = Color3.fromRGB(255, 245, 158)
    godrayPart.Parent = workspace
    godrayPart.CFrame = CFrame.Angles(0,0,math.rad(90)) + (godrayTargetPoint + (Vector3.yAxis*256))
    local godrayGroundPos = godrayPart.CFrame.Position-(Vector3.yAxis*256)

    local godrayTween = TS:Create(godrayPart, TweenInfo.new(GodrayHitTime, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {Size = Vector3.new(512,1,1), Transparency = 0})
    godrayTween:Play()

    local godraySound : Sound = StorageFolder.Godray:FindFirstChild("GodrayCharge"):Clone()
    godraySound.Parent = godrayPart
    godraySound:Play()

    godrayTween.Completed:Wait()
    godrayTween = TS:Create(godrayPart, TweenInfo.new(GodrayHitTime*.25, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = Vector3.new(512,GodrayRadius*2,GodrayRadius*2), Transparency = 1})
    godrayTween:Play()

    godraySound = StorageFolder.Godray:FindFirstChild("GodrayFire"):Clone()
    godraySound.PlayOnRemove = true
    Framework.FXReplicator:FireSoundFXEvent(godraySound, godrayPart)

    godrayTween.Completed:Once(function()
        godrayPart:Destroy()
    end)

    local hitPlayers = {}
    local overlapParams = OverlapParams.new()
    overlapParams.CollisionGroup = "SkillGroup"
    local hits = workspace:GetPartBoundsInRadius(godrayGroundPos, GodrayRadius, overlapParams)
    for _,hit : Part in hits do
        if hit.Name ~= "HumanoidRootPart" then continue end
        if hit.Parent == skill.Caster.Character then continue end
        if hit.Parent:FindFirstChild("Humanoid") then
            if hitPlayers[hit.Parent] then continue end
            hit.Parent.Humanoid.Health -= GodrayDamage
            local distance = (godrayGroundPos - hit.CFrame.Position).Magnitude
            RagdollService:RagdollRig(hit.Parent, 3, godrayGroundPos, 1600*(1-(distance/GodrayRadius)))
            hitPlayers[hit.Parent] = true
        end
    end

    return {startCooldown = true}
end)

--#endregion

-- Returns a skill given the name
function SkillsModule.GetSkill(name: string) : Types.SkillType
    local copy = nil
    for _,skill in pairs(Skills) do
        if skill.Name == name then
            copy = {}
            for k,v in pairs(skill) do
                copy[k] = v
            end
            break
        end
    end
    return copy
end

return SkillsModule