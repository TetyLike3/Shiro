local Types = {}

Types.FXTypes = {
    Sound = "SOUND",
    Particle = "PARTICLE",
}

export type FXDefaultData = {
    fxType: string,
    fxName: string,
    fxParentName: string,
}

export type FXSoundData = FXDefaultData & {}

export type FXParticleData = FXDefaultData & {
    emitOnce: boolean,
}

return Types