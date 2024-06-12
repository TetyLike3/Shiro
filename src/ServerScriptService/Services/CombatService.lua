local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local skillModule = require(RS.Framework.Modules.SkillsModule)
local skillModuleTypes = require(RS.Framework.Modules.SkillsModule.Types)


type CharacterStats = {
    
}
type PlayerData = {
    registeredSkills: {skillModuleTypes.SkillType},
    skillOverrides: {[string]: any},
    weaponData: {
        weaponName: string,
        state: string,
        lightAttackCooldownEndTimestamp: number,
        heavyAttackCooldownEndTimestamp: number,
        parryCooldownEndTimestamp: number,
        lightAttackAnimations: {{track: AnimationTrack} & weaponAnimationSounds},
        lightAttackAnimationIndex : number,
        lightAttackHitboxes : {Model},
        heavyAttackAnimation: ({track: AnimationTrack} & weaponAnimationSounds),
        heavyAttackHitbox : Model,
    },
    characterStats: {
        walkSpeed: number,
    }
}

-- Assigns a table of equipped skills to each player's userId
-- Also assigns a weapon name and state to each player's userId
local PlayerRegistry : {[number]: PlayerData} = {}


local Framework = require(RS.Framework.Internal.Kuro)

local CombatService = Framework.CreateService {
    Name = "CombatService",
    Client = {
        Signals = {},
        Properties = {
            CharacterStats = Framework.CreateProperty({
                walkSpeed = 16,
            } :: skillModuleTypes.CharacterStats),
        },
    },
}

local RagdollService


local PVPZones = workspace:WaitForChild("PVPZones"):GetChildren()

local PlayerWeaponStates = {
    Idle = "Idle",
    Attacking = "Attacking",
    Parrying = "Parrying",
    Blocking = "Blocking",
    Stunned = "Stunned",
}

type weaponAnimationSounds = {swingSound: Sound, hitSound: Sound, missSound: Sound}


--[---------------------------]--
--[      HELPER FUNCTIONS     ]--
--[---------------------------]--

-- Checks if a part is in a PVP zone
local function isInPVPZone(part : Part) : boolean
    for _,zone in PVPZones do
        if not zone:IsA("BasePart") then continue end
        if not CollectionService:HasTag(zone, "PVPZone_PVP") then continue end
        local overlapParams = OverlapParams.new()
        overlapParams.FilterType = Enum.RaycastFilterType.Include
        overlapParams.FilterDescendantsInstances = {zone}
        if #workspace:GetPartsInPart(part, overlapParams) > 0 then return true end
    end
    return false
end
local function getTimestamp() : number
    return DateTime.now().UnixTimestampMillis/1000
end
local function isCooldownEnded(timestamp : number) : boolean
    return getTimestamp() >= timestamp
end
local function getWeaponCopy(player : Player) : Model
    if not PlayerRegistry[player.UserId].weaponData then return end
    local weapon = Framework.ServerStorage.Weapons.Tools:FindFirstChild(PlayerRegistry[player.UserId].weaponData.weaponName)
    if not weapon then warn(string.format("CRITICAL: Weapon %s does not exist in storage for user %s (%s)",PlayerRegistry[player.UserId].weaponData.weaponName,player.Name,player.UserId)) return nil end
    return weapon
end
local function getWeaponOnPlayer(player : Player) : Model
    if not player.Character then return end
    return player.Character:FindFirstChild(PlayerRegistry[player.UserId].weaponData.weaponName)
end
local function getWeaponAnimations(weaponName : string) : {lightAttacks: {{track: Animation} & weaponAnimationSounds}, heavyAttack: {track: Animation} & weaponAnimationSounds}
    local weaponAnims = Framework.ServerStorage.Weapons.Animations:FindFirstChild(weaponName)

    local heavyAttackAnim = weaponAnims:FindFirstChild("HeavyAttack") :: Animation
    local entries = {
        lightAttacks = {},
        heavyAttack = {
            track = heavyAttackAnim,
            swingSound = heavyAttackAnim:FindFirstChild("Swing") :: Sound,
            hitSound = heavyAttackAnim:FindFirstChild("Hit") :: Sound,
            missSound = heavyAttackAnim:FindFirstChild("Miss") :: Sound,
        }
    }

    -- Get light attack animations and sounds
    for _, anim in weaponAnims:GetChildren() do
        if string.match(anim.Name, "LightAttack") then
            local index = #entries.lightAttacks+1
            entries.lightAttacks[index] = {
                track = anim,
                swingSound = anim:FindFirstChild("Swing") :: Sound,
                hitSound = anim:FindFirstChild("Hit") :: Sound,
                missSound = anim:FindFirstChild("Miss") :: Sound,
            }
        end
    end

    return entries
end
local function getWeaponHitboxes(weaponName : string) : {lightAttackHitboxes: {Model}, heavyAttackHitbox: Model}
    local weaponHitboxes = Framework.ServerStorage.Weapons.Hitboxes:FindFirstChild(weaponName)

    local heavyAttackHitbox = weaponHitboxes:FindFirstChild("HeavyAttack") :: Model
    local entries = {
        lightAttackHitboxes = {},
        heavyAttackHitbox = heavyAttackHitbox,
    }

    -- Get light attack hitboxes
    for _, hitbox in weaponHitboxes:GetChildren() do
        if string.match(hitbox.Name, "LightAttack") then
            local index = #entries.lightAttackHitboxes+1
            entries.lightAttackHitboxes[index] = hitbox
        end
    end

    return entries
end
local function quickWeld(part0 : BasePart, part1 : BasePart, animatable : boolean) : Motor6D | WeldConstraint
    animatable = animatable or false
    local weld
    if animatable then
        weld = Instance.new("Motor6D")
        weld.Part0 = part0
        weld.Part1 = part1
        weld.Parent = part0
    else
        weld = Instance.new("WeldConstraint")
        weld.Part0 = part0
        weld.Part1 = part1
        weld.Parent = part0
    end
    return weld
end
local function spawnHitbox(hitbox : Model, player : Player) : Model
    local hitboxClone = hitbox:Clone()
    quickWeld(hitboxClone.RootPos,player.Character.HumanoidRootPart)
    hitboxClone.RootPos.CFrame = player.Character.HumanoidRootPart.CFrame
    hitboxClone.Parent = player.Character
    return hitboxClone
end

--[---------------------------]--
--[          METHODS          ]--
--[---------------------------]--


-- Registers a skill to the player's toolbar.
-- Returns the updated toolbar data.
function CombatService.Client:RegisterSkill(player : Player, skillName: string) : {skillModuleTypes.SkillType}
    -- Get the skill object from the module
    local skill = skillModule.GetSkill(skillName)
    if not skill then return end
    skill.Caster = player

    -- Assign skill to an empty slot in the toolbar
    local registeredSkills = PlayerRegistry[player.UserId].registeredSkills
    for i,v in registeredSkills do
        if v == -1 then
            registeredSkills[i] = skill
            break
        end
    end
    return registeredSkills
end

-- Uses a skill from the player's toolbar.
-- Returns the updated toolbar data.
function CombatService.Client:UseSkillSlot(player : Player, skillIndex: number, skillInputData: skillModuleTypes.SkillInputData) : {skillModuleTypes.SkillType}
    local playerData = PlayerRegistry[player.UserId]
    local registeredSkills = playerData.registeredSkills
    -- Sanity checks
    if (skillIndex < 0) or (skillIndex > #registeredSkills) then return end
    if player.Character.Humanoid.Health <= 0 then return registeredSkills end

    -- Check if the skill is registered and inactive
    local skill = registeredSkills[skillIndex]
    if not skill then return end
    if skill.Active then return end

    -- Check if the skill can be used in the current context
    if (skill.Type == skillModule.SkillTypes.Offensive) and (not isInPVPZone(player.Character.HumanoidRootPart)) then
        skill.Active = false
        return registeredSkills
    end


    skillInputData.playerOverrides = playerData.skillOverrides

    local function changeCharacterStats(newStats)
        for stat, value in newStats do
            if not playerData.characterStats[stat] then continue end
            playerData.characterStats[stat] = value
        end
        CombatService.Client.Properties.CharacterStats:SetFor(player, playerData.characterStats)
    end
    skillInputData.changeCharacterStats = changeCharacterStats
    
    local result = skill:Use(skillInputData)

    return registeredSkills
end


--#region WEAPONS
local animWeight = 1
-- Toggles the weapon's presence on the player, and loads/unloads animations for the weapon
function CombatService.Client:ToggleWeapon(player : Player)
    if not player.Character then return end
    if not PlayerRegistry[player.UserId].weaponData then return end
    if PlayerRegistry[player.UserId].weaponData.state ~= PlayerWeaponStates.Idle then return end

    local weaponOnPlayer = getWeaponOnPlayer(player)
    if weaponOnPlayer then
        weaponOnPlayer:Destroy()

        -- Unload animations for weapon
        for _,anim in PlayerRegistry[player.UserId].weaponData.lightAttackAnimations do
            anim.track:Destroy()
        end
        PlayerRegistry[player.UserId].weaponData.heavyAttackAnimation.track:Destroy()
        return
    else
        -- Load weapon onto player
        local weaponClone = getWeaponCopy(player):Clone()
        weaponClone.Parent = player.Character

        -- Weld weapon to player
        local weld = quickWeld(player.Character:FindFirstChild("Left Arm"),weaponClone.Handle,true)
        weld.Name = "Handle"
        weld.C1 = weaponClone:GetAttribute("GripOffset")
        

        -- Load animations and sounds for weapon
        local animator : Animator = player.Character.Humanoid.Animator
        local playerEntry = PlayerRegistry[player.UserId].weaponData
        local entries = getWeaponAnimations(playerEntry.weaponName)

        for ind,entry in entries.lightAttacks do
            entries.lightAttacks[ind].track = animator:LoadAnimation(entry.track)
        end
        entries.heavyAttack.track = animator:LoadAnimation(entries.heavyAttack.track)

        playerEntry.lightAttackAnimations = entries.lightAttacks
        playerEntry.heavyAttackAnimation = entries.heavyAttack

        -- Load hitboxes for weapon
        local hitboxes = getWeaponHitboxes(playerEntry.weaponName)
        playerEntry.lightAttackHitboxes = hitboxes.lightAttackHitboxes
        playerEntry.heavyAttackHitbox = hitboxes.heavyAttackHitbox

        weaponClone.Destroying:Once(function()
            weld:Destroy()
        end)
        return
    end
end

local lightAttackComboTimeLimit = 0.1
-- Send an M1 input to the server
function CombatService.Client:LightAttack(player : Player) : (number, RemoteEvent)
    -- Sanity checks
    local playerEntry = PlayerRegistry[player.UserId].weaponData
    if not playerEntry then return end
    if playerEntry.state ~= PlayerWeaponStates.Idle then return end
    local weapon = getWeaponOnPlayer(player)
    if not weapon then return end
    if not isCooldownEnded(playerEntry.lightAttackCooldownEndTimestamp) then return playerEntry.lightAttackCooldownEndTimestamp end

    -- Combo logic
    local timeSinceLastSwing = getTimestamp() - playerEntry.lightAttackCooldownEndTimestamp
    if timeSinceLastSwing > (lightAttackComboTimeLimit + playerEntry.lightAttackAnimations[playerEntry.lightAttackAnimationIndex].track.Length) then
        playerEntry.lightAttackAnimationIndex = 1
        playerEntry.lightAttackCooldownEndTimestamp += weapon:GetAttribute("LightAttackCooldown")
    end
    playerEntry.lightAttackAnimationIndex += 1
    if playerEntry.lightAttackAnimationIndex > #playerEntry.lightAttackAnimations then playerEntry.lightAttackAnimationIndex = 1 end

    -- Start light attack
    local animationEntry = playerEntry.lightAttackAnimations[playerEntry.lightAttackAnimationIndex]
    playerEntry.state = PlayerWeaponStates.Attacking

    -- Swing sound
    Framework.FXReplicator:FireSoundFXEvent(animationEntry.swingSound:Clone(), weapon.Handle)

    -- Hitbox
    local hitRigs = {}
    local hitbox : Model
    local touchEventConnection = nil
    local hitSoundPlayed = false
    animationEntry.track:GetMarkerReachedSignal("SpawnHitbox"):Once(function()
        -- Spawn hitbox
        hitbox = spawnHitbox(playerEntry.lightAttackHitboxes[playerEntry.lightAttackAnimationIndex],player)

        -- Hit event
        touchEventConnection = hitbox.Hitbox.Touched:Connect(function(hit)
            if hit.Name ~= "HumanoidRootPart" then return end
            if not hit.Parent:FindFirstChild("Humanoid") then return end
            if table.find(hitRigs,hit.Parent) then return end
            hit.Parent:FindFirstChild("Humanoid"):TakeDamage(weapon:GetAttribute("LightAttackDamage"))
            table.insert(hitRigs,hit.Parent)
            if not hitSoundPlayed then
                Framework.FXReplicator:FireSoundFXEvent(animationEntry.hitSound:Clone(), weapon.Handle)
            end
        end)
    end)

    -- Post-animation code
    task.spawn(function()
        animationEntry.track:GetMarkerReachedSignal("SwingEnd"):Wait()
        playerEntry.state = PlayerWeaponStates.Idle
        touchEventConnection:Disconnect()
        hitbox:Destroy()

        -- Play miss sound if no hit sound was played
        if weapon and weapon.Handle then
            if not hitSoundPlayed then
                Framework:FireSoundFXEvent(animationEntry.missSound:Clone(), weapon.Handle)
            end
        end
    end)
    animationEntry.track:Play(0.001,animWeight)

    -- Return early to pass cooldown timestamp to client
    playerEntry.lightAttackCooldownEndTimestamp = getTimestamp() + animationEntry.track.Length
    return playerEntry.lightAttackCooldownEndTimestamp
end

-- Send an M2 input to the server
function CombatService.Client:HeavyAttack(player : Player) : (number, RemoteEvent)
    -- Sanity checks
    local playerEntry = PlayerRegistry[player.UserId].weaponData
    if not playerEntry then return end
    local weapon = getWeaponOnPlayer(player)
    if not weapon then return end
    if not isCooldownEnded(playerEntry.heavyAttackCooldownEndTimestamp) then return playerEntry.heavyAttackCooldownEndTimestamp end

    -- Start heavy attack
    local animationEntry = playerEntry.heavyAttackAnimation
    playerEntry.heavyAttackCooldownEndTimestamp = getTimestamp() + weapon:GetAttribute("HeavyAttackCooldown") + animationEntry.track.Length
    playerEntry.state = PlayerWeaponStates.Attacking

    -- Swing sound
    Framework.FXReplicator:FireSoundFXEvent(animationEntry.swingSound:Clone(), weapon.Handle)

    -- Hitbox
    local hitRigs = {}
    local hitbox : Model
    local touchEventConnection = nil
    local hitSoundPlayed = false
    animationEntry.track:GetMarkerReachedSignal("SpawnHitbox"):Once(function()
        -- Spawn hitbox
        hitbox = spawnHitbox(playerEntry.heavyAttackHitbox,player)

        -- Hit event
        touchEventConnection = hitbox.Hitbox.Touched:Connect(function(hit)
            if hit.Name ~= "HumanoidRootPart" then return end
            if not hit.Parent:FindFirstChild("Humanoid") then return end
            if table.find(hitRigs,hit.Parent) then return end
            hit.Parent:FindFirstChild("Humanoid"):TakeDamage(weapon:GetAttribute("HeavyAttackDamage"))
            RagdollService:RagdollRig(hit.Parent, player, 1, player.Character.HumanoidRootPart.CFrame.Position, 200)
            table.insert(hitRigs,hit.Parent)
            if not hitSoundPlayed then
                Framework.FXReplicator:FireSoundFXEvent(animationEntry.hitSound:Clone(), weapon.Handle)
                hitSoundPlayed = true
            end
        end)
    end)
    animationEntry.track:Play(0.01,animWeight)

    -- Post-animation code
    task.spawn(function()
        animationEntry.track:GetMarkerReachedSignal("SwingEnd"):Wait()
        playerEntry.state = PlayerWeaponStates.Idle
        touchEventConnection:Disconnect()
        hitbox:Destroy()

        -- Play miss sound if no hit sound was played
        if weapon and weapon.Handle then
            if not hitSoundPlayed then
                Framework:FireSoundFXEvent(animationEntry.missSound:Clone(), weapon.Handle)
            end
        end
    end)

    -- Return early to pass cooldown timestamp to client
    return playerEntry.heavyAttackCooldownEndTimestamp
end
--#endregion



--[---------------------------]--
--[     FRAMEWORK METHODS     ]--
--[---------------------------]--

-- Creates a skill toolbar for a given player
local function playerAddedCallback(player : Player)
    PlayerRegistry[player.UserId] = {registeredSkills = table.create(10,-1)}
    player.CharacterAdded:Connect(function(character)
        -- Ragdoll on death :3
        character.Humanoid.BreakJointsOnDeath = false
        character.Humanoid.Died:Once(function()
            RagdollService:RagdollRig(character, player, 60, character.HumanoidRootPart.CFrame.Position, 0)
        end)
    end)

    PlayerRegistry[player.UserId].skillOverrides = {}

    PlayerRegistry[player.UserId].weaponData = {
        weaponName = "Messer",
        state = PlayerWeaponStates.Idle,
        lightAttackAnimationTracks = {},
        lightAttackCooldownEndTimestamp = 0,
        lightAttackAnimationIndex = 1,
        heavyAttackAnimationTrack = nil,
        heavyAttackCooldownEndTimestamp = 0,
        parryCooldownEndTimestamp = 0,
    }

    PlayerRegistry[player.UserId].characterStats = {
        walkSpeed = game:GetService("StarterPlayer").CharacterWalkSpeed
    }
    CombatService.Client.Properties.CharacterStats:SetFor(player, PlayerRegistry[player.UserId].characterStats)
end

function CombatService:FrameworkStart()
    Players.PlayerAdded:Connect(playerAddedCallback)
    for _,player in game.Players:GetPlayers() do
        playerAddedCallback(player)
    end

    -- Set up dummies
    for _,dummy in workspace.Dummies.Damageable:GetChildren() do
        for _,part:BasePart in dummy:GetChildren() do
            if part:IsA("BasePart") then part.CollisionGroup = "DummyRigs" end
        end
    end
end

function CombatService:FrameworkInit()
    RagdollService = Framework.GetService("RagdollService")
end

return CombatService