local RunService = game:GetService("RunService")
local Players = game:GetService("Players")


local _PlayerGui : PlayerGui
local function getPlayerGui() -- Returns PlayerGui
    if not _PlayerGui then
        _PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    end
    return _PlayerGui
end

local _SlotsUI : Frame
local function getSlotsUI() -- Returns the Slots UI
    if not _SlotsUI then
        _SlotsUI = getPlayerGui():WaitForChild("Toolbar"):WaitForChild("Slots")
    end
    return _SlotsUI
end


-- Create Controller
local RS = game:GetService("ReplicatedStorage")
local Framework = require(RS.Framework.Internal.Kuro)

local SkillController = Framework.CreateController { Name = "SkillController" }

-- Module References
local skillModuleTypes = require(RS.Framework.Modules.SkillsModule.Types)
local CombatService

-- Controller Variables
local RegisteredSkills : {skillModuleTypes.SkillType} = table.create(10,-1)




--[---------------------------]--
--[          METHODS          ]--
--[---------------------------]--



-- Registers a skill to the player's toolbar
function SkillController:RegisterSkill(skillName: string)
    -- Send register request to server
    local success, registeredSkills = CombatService:RegisterSkill(skillName):await()
    if not success then warn("Promise to register skill failed") return end
    RegisteredSkills = registeredSkills -- Update toolbar data

    -- Update all slots in UI
    local slotsUI = getSlotsUI()
    for _,slot in slotsUI:GetChildren() do
        if not slot:IsA("Frame") then continue end
        local skill = RegisteredSkills[slot.LayoutOrder]
        if skill == -1 then continue end
        slot.SkillName.Text = skill.Name
    end
end

-- Uses a skill from the toolbar
function SkillController:UseSkill(skillIndex)
    -- Sanity checks
    if (skillIndex < 0) or (skillIndex > #RegisteredSkills) then return end
    local skill = RegisteredSkills[skillIndex]
    if skill == -1 then return end
    if skill.Active then return end
    skill.Active = true

    -- Create skill input data
    local skillInputData : skillModuleTypes.SkillInputData = {
        mouseHitPosition = Players.LocalPlayer:GetMouse().Hit.Position
    }

    -- Send use request to server
    local success, registeredSkills = CombatService:UseSkillSlot(skillIndex, skillInputData):await()
    if not success then warn("Promise to use skill failed") return end
    RegisteredSkills = registeredSkills -- Update toolbar data
end



--[---------------------------]--
--[     FRAMEWORK METHODS     ]--
--[---------------------------]--

-- Updates SlotUI
local function SlotUIUpdate(deltaTime)
    local slotsUI = getSlotsUI()
    for _,slot in slotsUI:GetChildren() do
        -- Sanity checks
        if not slot:IsA("Frame") then continue end
        local skill = RegisteredSkills[slot.LayoutOrder]
        if skill == -1 then continue end

        -- Update cooldowns
        local cooldownValue = 0
        local cooldownDiff = skill.CooldownEndTimestamp - (DateTime.now().UnixTimestampMillis/1000)
        if cooldownDiff > 0 then cooldownValue = cooldownDiff/skill.Cooldown end
        slot.CooldownOverlay.Size = UDim2.fromScale(cooldownValue,1)
    end
end


function SkillController:FrameworkStart()
    -- Register skills (for debugging)
    self:RegisterSkill("Sonido")
    self:RegisterSkill("Hop")
    self:RegisterSkill("Fireball")
    self:RegisterSkill("Godray")

    getSlotsUI().Parent.Enabled = true
    local slotUIUpdateHandle = RunService.RenderStepped:Connect(SlotUIUpdate)
end

function SkillController:FrameworkInit()
    CombatService = Framework.GetService("CombatService")
end

return SkillController