local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Knit = require(RS.Framework.Internal.Packages.Knit)

local skillModule = require(RS.Framework.Modules.SkillsModule)

local SkillService = Knit.CreateService {
    Name = "SkillService";
    Client = {}
}

-- Assigns a table of equipped skills to each player's userId
local PlayerRegistry : {[number]: {registeredSkills: {skillModule.SkillType}}} = {}

local PVPZones = workspace:WaitForChild("PVPZones"):GetChildren()


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


--[---------------------------]--
--[          METHODS          ]--
--[---------------------------]--


-- Registers a skill to the player's toolbar.
-- Returns the updated toolbar data.
function SkillService.Client:RegisterSkill(player : Player, skillName: string) : {skillModule.SkillType}
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
function SkillService.Client:UseSkillSlot(player : Player, skillIndex: number, skillInputData: skillModule.skillInputData) : {skillModule.SkillType}
    local registeredSkills = PlayerRegistry[player.UserId].registeredSkills
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

    skill:Use(skillInputData)
    return registeredSkills
end




--[---------------------------]--
--[        KNIT METHODS       ]--
--[---------------------------]--


local footstepSound = Instance.new("Sound")
footstepSound.Name = "Footstep"
footstepSound.SoundId = "rbxassetid://7534137531"
footstepSound.Volume = 0.5
-- Creates a skill toolbar for a given player
local function playerAddedCallback(player : Player)
    PlayerRegistry[player.UserId] = {registeredSkills = table.create(10,-1)}
    player.CharacterAdded:Connect(function(character)
        for _,part:BasePart in character:GetChildren() do
            if part:IsA("BasePart") then part.CollisionGroup = "PlayerRigs" end
        end
        local leftStepSound = footstepSound:Clone()
        leftStepSound.Parent = character:FindFirstChild("Left Leg")
        local rightStepSound = footstepSound:Clone()
        rightStepSound.Parent = character:FindFirstChild("Right Leg")
    end)
end

function SkillService:KnitStart()
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

function SkillService:KnitInit()
end

return SkillService