local Debris = game:GetService("Debris")
local Types = require(script.Parent.Parent.Parent.Util.Types)

local FXReplicator = {}

FXReplicator.TempStorage = nil :: Folder -- Set by ServerModule
FXReplicator.ReplicationTimeout = 5 -- Seconds until the FX being replicated is destroyed

function FXReplicator:FireSoundFXEvent(fx : Instance, parent : Instance)
    fx.Parent = FXReplicator.TempStorage

    local fxData : Types.FXSoundData = {
        fxType = Types.FXTypes.Sound,
        fxName = fx:GetFullName(),
        fxParentName = parent:GetFullName()
    }
    FXReplicator.FXEvent:FireAllClients(fxData)
    Debris:AddItem(fx, FXReplicator.ReplicationTimeout)
end
function FXReplicator:FireParticleFXEvent(fx : Instance, parent : Instance, emitFor : number)
    if fx:IsA("Attachment") then
        fx.Parent = FXReplicator.TempStorage.AttachmentParent
    else
        fx.Parent = FXReplicator.TempStorage
    end

    local fxData : Types.FXParticleData = {
        fxType = Types.FXTypes.Particle,
        fxName = fx:GetFullName(),
        fxParentName = parent:GetFullName(),
        emitFor = emitFor
    }
    FXReplicator.FXEvent:FireAllClients(fxData)
    Debris:AddItem(fx, FXReplicator.ReplicationTimeout)
end

-- FX event
local FXEvent = Instance.new("RemoteEvent")
FXEvent.Name = "FXEvent"
FXEvent.Parent = script.Parent.Parent
FXReplicator.FXEvent = FXEvent

return FXReplicator