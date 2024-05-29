local Players = game:GetService("Players")
local DSS = game:GetService("DataStoreService")
local RS = game:GetService("ReplicatedStorage")

local Framework = require(RS.Framework.Internal.Kuro)

local PlayerSlotService = Framework.CreateService {
    Name = "PlayerSlotService",
    Client = {},
}


type SkillData = {
    Name: string,
    Cooldown: number,
    Properties: {string: any}
}
type PlayerSlot = {
    SlotNumber: number,
    Rank: number,
    Skills: {SkillData}
}

local LoadedPlayerSlots : {number: PlayerSlot} = {}


return PlayerSlotService