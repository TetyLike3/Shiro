local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Framework = require(RS.Framework.Internal.Kuro)

local WeaponService = Framework.CreateService {
    Name = "WeaponService",
    Client = {},
}

local RagdollService


local PlayerWeaponStates = {
    Idle = "Idle",
    Attacking = "Attacking",
    Parrying = "Parrying",
    Blocking = "Blocking",
    Stunned = "Stunned",
}

type weaponAnimationSounds = {swingSound: Sound, hitSound: Sound, missSound: Sound}
-- Assigns a weapon name and state to each player's userId
local playerWeapons : {
    [number]: {
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
    }
} = {}



--[---------------------------]--
--[      HELPER FUNCTIONS     ]--
--[---------------------------]--

local function getTimestamp() : number
    return DateTime.now().UnixTimestampMillis/1000
end
local function isCooldownEnded(timestamp : number) : boolean
    return getTimestamp() >= timestamp
end

local function getWeaponCopy(player : Player) : Model
    if not playerWeapons[player.UserId] then return end
    local weapon = Framework.ServerStorage.Weapons.Tools:FindFirstChild(playerWeapons[player.UserId].weaponName)
    if not weapon then warn(string.format("CRITICAL: Weapon %s does not exist in storage for user %s (%s)",playerWeapons[player.UserId].weaponName,player.Name,player.UserId)) return nil end
    return weapon
end
local function getWeaponOnPlayer(player : Player) : Model
    if not player.Character then return end
    return player.Character:FindFirstChild(playerWeapons[player.UserId].weaponName)
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
local function createFXEvent(name)
    local fxEvent = Instance.new("RemoteEvent")
    fxEvent.Name = name
    fxEvent.Parent = Framework.SharedStorage.Events
    return fxEvent
end
local function fireFXEvent(fxEvent : RemoteEvent, player : Player, inst : Instance, parent : Instance)
    inst.Parent = Framework.SharedStorage.Temp
    fxEvent:FireClient(player, inst, parent)
end



--[---------------------------]--
--[          METHODS          ]--
--[---------------------------]--
local animWeight = .5

-- Toggles the weapon's presence on the player, and loads/unloads animations for the weapon
function WeaponService.Client:ToggleWeapon(player : Player)
    if not player.Character then return end
    if not playerWeapons[player.UserId] then return end
    if playerWeapons[player.UserId].state ~= PlayerWeaponStates.Idle then return end

    local weaponOnPlayer = getWeaponOnPlayer(player)
    if weaponOnPlayer then
        weaponOnPlayer:Destroy()

        -- Unload animations for weapon
        for _,anim in playerWeapons[player.UserId].lightAttackAnimations do
            anim.track:Destroy()
        end
        playerWeapons[player.UserId].heavyAttackAnimation.track:Destroy()
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
        local playerEntry = playerWeapons[player.UserId]
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
function WeaponService.Client:LightAttack(player : Player) : (number, RemoteEvent)
    -- Sanity checks
    local playerEntry = playerWeapons[player.UserId]
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

    -- Create client-side FX event
    local fxEvent = createFXEvent(string.format("%s_M1FX",player.Name))

    -- Start light attack
    local animationEntry = playerEntry.lightAttackAnimations[playerEntry.lightAttackAnimationIndex]
    playerEntry.state = PlayerWeaponStates.Attacking

    -- Swing sound
    fireFXEvent(fxEvent, player, animationEntry.swingSound:Clone(), weapon.Handle)
    -- Hit sound

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
                fireFXEvent(fxEvent, player, animationEntry.hitSound:Clone(), weapon.Handle)
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
                fireFXEvent(fxEvent, player, animationEntry.missSound:Clone(), weapon.Handle)
            end
        end

        fxEvent:Destroy()
    end)
    animationEntry.track:Play(0.01,animWeight)

    -- Return early to pass cooldown timestamp to client
    playerEntry.lightAttackCooldownEndTimestamp = getTimestamp() + animationEntry.track.Length
    return playerEntry.lightAttackCooldownEndTimestamp, fxEvent
end

-- Send an M2 input to the server
function WeaponService.Client:HeavyAttack(player : Player) : (number, RemoteEvent)
    -- Sanity checks
    local playerEntry = playerWeapons[player.UserId]
    if not playerEntry then return end
    local weapon = getWeaponOnPlayer(player)
    if not weapon then return end
    if not isCooldownEnded(playerEntry.heavyAttackCooldownEndTimestamp) then return playerEntry.heavyAttackCooldownEndTimestamp end

    -- Create client-side FX event
    local fxEvent = createFXEvent(string.format("%s_M2FX",player.Name))

    -- Start heavy attack
    local animationEntry = playerEntry.heavyAttackAnimation
    playerEntry.heavyAttackCooldownEndTimestamp = getTimestamp() + weapon:GetAttribute("HeavyAttackCooldown") + animationEntry.track.Length
    playerEntry.state = PlayerWeaponStates.Attacking

    -- Swing sound
    fireFXEvent(fxEvent, player, animationEntry.swingSound:Clone(), weapon.Handle)
    -- Hit sound

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
            RagdollService:RagdollRig(hit.Parent, 1, player.Character.HumanoidRootPart.CFrame.Position, 200)
            table.insert(hitRigs,hit.Parent)
            if not hitSoundPlayed then
                fireFXEvent(fxEvent, player, animationEntry.hitSound:Clone(), weapon.Handle)
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
                fireFXEvent(fxEvent, player, animationEntry.missSound:Clone(), weapon.Handle)
            end
        end
        fxEvent:Destroy()
    end)

    -- Return early to pass cooldown timestamp to client
    return playerEntry.heavyAttackCooldownEndTimestamp, fxEvent
end



--[---------------------------]--
--[        KNIT METHODS       ]--
--[---------------------------]--

-- Create entry for given player
local function playerAddedCallback(player : Player)
    playerWeapons[player.UserId] = {
        weaponName = "Messer",
        state = PlayerWeaponStates.Idle,
        lightAttackAnimationTracks = {},
        lightAttackCooldownEndTimestamp = 0,
        lightAttackAnimationIndex = 1,
        heavyAttackAnimationTrack = nil,
        heavyAttackCooldownEndTimestamp = 0,
        parryCooldownEndTimestamp = 0,
    }
end

function WeaponService:FrameworkStart()
    -- Create entry for each player that joins
    Players.PlayerAdded:Connect(playerAddedCallback)

    -- Create entry for existing players
    for _,player in Players:GetPlayers() do
        playerAddedCallback(player)
    end
end


function WeaponService:FrameworkInit()
    RagdollService = Framework.GetService("RagdollService")
end


return WeaponService
