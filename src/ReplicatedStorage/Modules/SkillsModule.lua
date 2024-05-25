local Debris = game:GetService("Debris")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer") -- For things like base walkspeed
local TS = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")

local Framework = require(RS.Framework.Internal.Kuro)

local StorageFolder
local VFXFolder

local RagdollService


-- Prevent module from loading server-side features on the client
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

local function createFXEvent(skill : SkillType) : RemoteEvent
    local fxEvent = Instance.new("RemoteEvent")
    fxEvent.Name = string.format("%s_%sFX", skill.Caster.Name, skill.Name)
    return fxEvent
end
local function fireFXEvent(fxEvent : RemoteEvent, player : Player, inst : Instance, parent : Instance)
    if inst:IsA("Attachment") then
        inst.Parent = Framework.SharedStorage.Temp.AttachmentParent
    else
        inst.Parent = Framework.SharedStorage.Temp
    end
    fxEvent:FireClient(player, inst, parent)
end




--[---------------------------]--
--[           MODULE          ]--
--[---------------------------]--


local SkillsModule = {}

-- Skill categories
SkillsModule.SkillTypes = {
    Offensive = "Offensive",
    Defensive = "Defensive",
    Utility = "Utility"
}


-- Data that is passed to a skill when it is used
export type skillInputData = {
    mouseHitPosition: Vector3
}
export type skillOutputData = {
    startCooldown: boolean,
    fxEvent: RemoteEvent?
}

type SkillUseFunction = (skill: SkillType, inputData: skillInputData) -> skillOutputData
-- Skill object type
export type SkillType = {
    Name: string,
    Type: string,
    Cooldown: number,
    CooldownEndTimestamp: number,
    Active: boolean,
    FXEvent: RemoteEvent?,
    Caster: Player,
    Use: SkillUseFunction
}


-- A wrapper function that handles cooldowns
local function WrapUseFunction(skill: SkillType, skillUseFunction: SkillUseFunction) : SkillUseFunction
    local wrapped: SkillUseFunction = function(skill: SkillType, inputData: skillInputData)
        -- Check if the skill is on cooldown
        if skill.CooldownEndTimestamp <= DateTime.now().UnixTimestampMillis/1000 then
            skill.Active = true
            local returnData = skillUseFunction(skill, inputData)
            skill.Active = false
            if returnData.startCooldown then skill.CooldownEndTimestamp = (DateTime.now().UnixTimestampMillis/1000) + skill.Cooldown end
            if returnData.fxEvent then skill.FXEvent = returnData.fxEvent end
        else
            print("Skill on cooldown")
        end
    end
    return wrapped
end

-- Create a skill object, given the name, category, cooldown time (seconds), and code when used.
function SkillsModule.CreateSkill(name: string, skillType: string, cooldown: number, useFunction: SkillUseFunction)
    local skill: SkillType = {
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


-- Return early if this module is required from the client
if game:GetService("RunService"):IsClient() then
    return SkillsModule
end

--[---------------------------]--
--[           SKILLS          ]--
--[---------------------------]--

--! Skill Use functions are always run server-side
local Skills : {[string]: SkillType} = {}



--[         FLASH STEP        ]--

-- Variables
local FlashStepDuration = .8
local FlashStepSpeed = 70
local FlashStepShadowFrequency = .24
local FlashStepStandingMultiplier = 0.2

-- Skill code
Skills.FlashStepSkill = SkillsModule.CreateSkill("Sonido", SkillsModule.SkillTypes.Utility, 3.2, function(skill: SkillType, inputData: skillInputData) : skillOutputData
    local hum = skill.Caster.Character.Humanoid
    hum.WalkSpeed = FlashStepSpeed
    HideCharacter(skill.Caster.Character, true)

    local flashStepDuration = FlashStepDuration
    if skill.Caster.Name == "TestyLike3" then flashStepDuration = 2.4 end

    skill.Caster.Character:FindFirstChild("Left Leg"):FindFirstChild("Footstep").Volume = 0
    skill.Caster.Character:FindFirstChild("Right Leg"):FindFirstChild("Footstep").Volume = 0
    task.spawn(function()
        repeat
            if not isCharacterMoving(skill.Caster.Character) then
                task.wait(.1)
            else
                CreateCharacterShadow(skill.Caster.Character)
                task.wait(FlashStepShadowFrequency)
            end
        until skill.Active == false
        skill.Caster.Character:FindFirstChild("Left Leg"):FindFirstChild("Footstep").Volume = .5
        skill.Caster.Character:FindFirstChild("Right Leg"):FindFirstChild("Footstep").Volume = .5
    end)

    local timeInFlashStep = 0
    repeat
        task.wait(0.1)
        if not isCharacterMoving(skill.Caster.Character) then
            timeInFlashStep += 0.1*FlashStepStandingMultiplier
        else
            timeInFlashStep += 0.1
        end
    until timeInFlashStep >= flashStepDuration
    hum.WalkSpeed = StarterPlayer.CharacterWalkSpeed
    task.wait(.2)
    HideCharacter(skill.Caster.Character, false)

    return {startCooldown = true}
end)



--[            HOP           ]--

-- Skill code
Skills.HopSkill = SkillsModule.CreateSkill("Hop", SkillsModule.SkillTypes.Utility, 1, function(skill: SkillType, inputData: skillInputData) : skillOutputData
    local humRootPart = skill.Caster.Character.HumanoidRootPart
    local newPos = humRootPart.Position + (Vector3.yAxis * 20)
    skill.Caster.Character:MoveTo(newPos)
    return {startCooldown = true}
end)



--[         FIREBALL         ]--

-- Variables
local FireballLifetime = 6
local FireballSpeed = 240
local FireballDamage = 40
local FireballSize = 2.4

-- Skill code
Skills.FireballSkill = SkillsModule.CreateSkill("Fireball", SkillsModule.SkillTypes.Offensive, .02, function(skill: SkillType, inputData: skillInputData) : skillOutputData
    local humRootPart = skill.Caster.Character.HumanoidRootPart
    local humanoid = skill.Caster.Character.Humanoid

    -- Fireball part
    local fireball = createPart()
    fireball.Shape = Enum.PartType.Ball
    fireball.Material = Enum.Material.Rock
    fireball.Color = Color3.fromRGB(58, 58, 58)
    fireball.Size = Vector3.one * FireballSize

    local fxEvent = createFXEvent(skill)

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
    --[[
    task.spawn(function()
        task.wait(.5)
        fireFXEvent(fxEvent, skill.Caster, StorageFolder.Fireball:FindFirstChild("FireballLoop1"):Clone(), fireball)
        fireFXEvent(fxEvent, skill.Caster, StorageFolder.Fireball:FindFirstChild("FireballLoop2"):Clone(), fireball)
        fireFXEvent(fxEvent, skill.Caster, CreateVFX("Fire"), fireball)
    end)
    ]]
    local loop1 = StorageFolder.Fireball:FindFirstChild("FireballLoop1"):Clone()
    local loop2 = StorageFolder.Fireball:FindFirstChild("FireballLoop2"):Clone()
    loop1.Parent = fireball
    loop2.Parent = fireball
    loop1:Play()
    loop2:Play()
    local fireVFX = CreateVFX("Fire")
    fireVFX.Parent = fireball

    -- Set player to network owner of fireball (probably a vantage point for exploiters)
    fireball:SetNetworkOwner(skill.Caster)

    return {startCooldown = true, fxEvent = fxEvent}
end)



--[          GODRAY          ]--

-- Variables
local GodrayHitTime = 1.5
local GodrayDamage = 90
local GodrayRadius = 52
local GodrayMaxDistance = 192

-- Skill code
Skills.GodraySkill = SkillsModule.CreateSkill("Godray", SkillsModule.SkillTypes.Offensive, 3, function(skill : SkillType, inputData: skillInputData) : skillOutputData
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
    godraySound.Parent = godrayPart
    godraySound:Destroy()

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


-- Returns a skill given the name
function SkillsModule.GetSkill(name: string) : SkillType
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