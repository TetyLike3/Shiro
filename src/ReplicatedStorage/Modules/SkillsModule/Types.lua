export type CharacterStats = {
    walkSpeed: number
}

-- Data that is passed to a skill when it is used
export type SkillInputData = {
    mouseHitPosition: Vector3,
    playerOverrides: {[string]: any},
    changeCharacterStats: (newStats: CharacterStats) -> (),
}
export type SkillOutputData = {
    startCooldown: boolean
}

export type SkillUseFunction = (skill: SkillType, inputData: SkillInputData) -> SkillOutputData

-- Skill object type
export type SkillType = {
    Name: string,
    Type: string,
    Cooldown: number,
    CooldownEndTimestamp: number,
    Active: boolean,
    Caster: Player,
    Use: SkillUseFunction
}

return {}