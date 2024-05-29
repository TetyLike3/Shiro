if (not script:FindFirstAncestor("Workspace")) then return end

local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Character = script.Parent
local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
local Animator = Humanoid:FindFirstChildOfClass("Animator")

local leftFootstepSound = script.Parent:WaitForChild("Left Leg"):WaitForChild("Footstep") :: Sound
local rightFootstepSound = script.Parent:WaitForChild("Right Leg"):WaitForChild("Footstep") :: Sound

local animNames = {
    Idle = "Idle",
    Walk = "Walk",
    Run = "Run",
    Jump = "Jump",
    Climb = "Climb",
    Sit = "Sit",
    Fall = "Fall",
    Emotes = {
        Wave = "Wave",
        Point = "Point",
        Dance = "Dance",
    }
}
local animIDs = {
    [animNames.Idle] = "rbxassetid://17661521279",
    [animNames.Walk] = "rbxassetid://17661156982",
    [animNames.Run] = "rbxassetid://17623798726",
    [animNames.Jump] = "http://www.roblox.com/asset/?id=125750702",
    [animNames.Climb] = "http://www.roblox.com/asset/?id=180436334",
    [animNames.Sit] = "http://www.roblox.com/asset/?id=178130996",
    [animNames.Fall] = "http://www.roblox.com/asset/?id=180436148",

    [animNames.Emotes.Wave] = "http://www.roblox.com/asset/?id=128777973",
    [animNames.Emotes.Point] = "http://www.roblox.com/asset/?id=128853357",
    [animNames.Emotes.Dance] = {
        "http://www.roblox.com/asset/?id=182435998",
        "http://www.roblox.com/asset/?id=182491037",
        "http://www.roblox.com/asset/?id=182491065",
    }
}
local animInstances = {}

local humanoidState = animNames.Walk

local currentAnimSpeed = 1
local currentAnimation : Animation = nil
local currentAnimTrack : AnimationTrack = nil

local function setAnimSpeed(speed : number)
    if currentAnimSpeed == speed then return end
    currentAnimSpeed = speed
    if currentAnimTrack then currentAnimTrack:AdjustSpeed(speed) end
end

local activeKeyframeCallback = nil
function keyframeCallback(keyframeName)
    if (keyframeName == "End") then
        playAnimation(animInstances.Idle, 0.1)
    elseif (keyframeName == "FootstepL") then
        leftFootstepSound.PlaybackSpeed = currentAnimSpeed
        leftFootstepSound.Volume = currentAnimSpeed/2
		leftFootstepSound:Play()
    elseif (keyframeName == "FootstepR") then
        rightFootstepSound.PlaybackSpeed = currentAnimSpeed
        rightFootstepSound.Volume = currentAnimSpeed/2
        rightFootstepSound:Play()
    end
end

function playAnimation(animName : string, transitionTime : number)
    local anim = animInstances[animName]
    if (not anim) or (currentAnimation == anim) then return end

    if currentAnimTrack then
        currentAnimTrack:Stop(transitionTime)
        currentAnimTrack:Destroy()
    end

    currentAnimTrack = Animator:LoadAnimation(anim)
    currentAnimTrack:Play(transitionTime)
    currentAnimation = anim

    if activeKeyframeCallback then activeKeyframeCallback:Disconnect() end
    activeKeyframeCallback = currentAnimTrack.KeyframeReached:Connect(keyframeCallback)
end

local function createAnimations()
    for animName,animID in animIDs do
        if typeof(animID) == "table" then
            local anims = {}
            for name,id in animID do
                local anim = Instance.new("Animation")
                anim.Name = animName..tostring(name)
                anim.AnimationId = id
                anims[name] = anim
            end
            animInstances[animName] = anims
            continue
        end
        local anim = Instance.new("Animation")
        anim.Name = animName
        anim.AnimationId = animID
        anim.Parent = script

        animInstances[animName] = anim
    end
end


createAnimations()
playAnimation(animNames.Idle, 0.1)

local function updateAnimations()
    if (Humanoid.MoveDirection.Magnitude == 0) then
        humanoidState = animNames.Idle
        playAnimation(animNames.Idle, 0.1)
    elseif (Humanoid.MoveDirection.Magnitude > 0) then
        local animSpeed = Humanoid.WalkSpeed/StarterPlayer.CharacterWalkSpeed
        if animSpeed > 1 then
            playAnimation(animNames.Run, 0.1)
            animSpeed -= (StarterPlayer.CharacterWalkSpeed/2)
        else
            playAnimation(animNames.Walk, 0.1)
        end
        setAnimSpeed(animSpeed)
    elseif (Humanoid.FloorMaterial == Enum.Material.Air) then
        playAnimation(animNames.Fall, 0.1)
    end
end

local updateTimerMax = 0.02
local updateTimer = 0
local updateHandle = RunService.Heartbeat:Connect(function(deltaTime)
    updateTimer += deltaTime
    if updateTimer >= updateTimerMax then
        updateTimer = 0
        updateAnimations()
    end
end)

Humanoid.StateChanged:Connect(function(_, newState)
    if newState == Enum.HumanoidStateType.Jumping then
        humanoidState = animNames.Jump
    elseif newState == Enum.HumanoidStateType.Freefall then
        humanoidState = animNames.Fall
    elseif newState == Enum.HumanoidStateType.Running then
        humanoidState = animNames.Walk
    end
end)

Humanoid.Died:Once(function()
    updateHandle:Disconnect()
end)

print("Animate client script loaded")