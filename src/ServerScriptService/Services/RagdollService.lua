
local DataStoreService = game:GetService("DataStoreService")
local RS = game:GetService("ReplicatedStorage")
local Knit = require(RS.Framework.Internal.Packages.Knit)

local RagdollService = Knit.CreateService {
    Name = "RagdollService",
}



--[---------------------------]--
--[      HELPER FUNCTIONS     ]--
--[---------------------------]--


-- Converts a given Motor6D to a BallSocketConstraint
local function ConvertMotorToBallSocketConstraint(motor : Motor6D) : BallSocketConstraint
    local socket = Instance.new("BallSocketConstraint")
    local attachment0 = Instance.new("Attachment")
    local attachment1 = Instance.new("Attachment")
    attachment0.Parent = motor.Part0
    attachment1.Parent = motor.Part1
    socket.Parent = motor.Parent
    socket.Attachment0 = attachment0
    socket.Attachment1 = attachment1
    attachment0.CFrame = motor.C0
    attachment1.CFrame = motor.C1
    socket.LimitsEnabled = true
    socket.TwistLimitsEnabled = true

    motor:Destroy()
    return socket
end

-- Converts a given BallSocketConstraint to a Motor6D
local function ConvertBallSocketConstraintToMotor(socket : BallSocketConstraint) : Motor6D
    socket.UpperAngle = 0
    socket.TwistUpperAngle = 0
    socket.TwistLowerAngle = 0
    local motor = Instance.new("Motor6D")
    motor.Part0 = socket.Attachment0.Parent
    motor.Part1 = socket.Attachment1.Parent
    motor.C0 = socket.Attachment0.CFrame
    motor.C1 = socket.Attachment1.CFrame
    motor.Parent = socket.Parent

    socket:Destroy()
    return motor
end




--[---------------------------]--
--[          METHODS          ]--
--[---------------------------]--


function RagdollService:RagdollRig(rig : Model, duration : number, impulseOrigin : Vector3, impulseMagnitude : number?)
    local humanoid = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
    if not humanoid then return end
    local humRootPart = rig:FindFirstChild("HumanoidRootPart") :: Part
    if not humRootPart then return end
    local torso = rig:FindFirstChild("Torso")
    if not torso then return end
    local rigMotor = humRootPart:FindFirstChildOfClass("Motor6D")
    if not rigMotor then return end
    if not impulseMagnitude then impulseMagnitude = 500 end
    local impulseVector = (humRootPart.Position - impulseOrigin).Unit * impulseMagnitude
    
    -- Spawn in a new thread to avoid yielding the calling thread
    task.spawn(function()
        -- Convert Motor6Ds to BallSocketConstraints
        local socket = ConvertMotorToBallSocketConstraint(rigMotor)
        local torsoSockets = {}
        for _,motor in torso:GetChildren() do
            if not motor:IsA("Motor6D") then continue end
            table.insert(torsoSockets, ConvertMotorToBallSocketConstraint(motor))
        end
    
        humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
        humanoid.RequiresNeck = false
        humanoid.Sit = true

        -- Allow limbs to collide with parts
        local partsCollisionGroups : {[Part] : {group: string, cancollide: boolean}} = {}
        for _,part : Part in rig:GetChildren() do
            if not part:IsA("BasePart") then continue end
            partsCollisionGroups[part] = {group = part.CollisionGroup, cancollide = part.CanCollide}
            part.CollisionGroup = "RagdollRigs"
            part.CanCollide = true
        end

        -- Apply impulse to the HumanoidRootPart
        humRootPart:ApplyImpulse(impulseVector)

        task.wait(duration)

        -- Revert parts back to their original collision groups
        for part,data in partsCollisionGroups do
            part.CanCollide = data.cancollide
            part.CollisionGroup = data.group
        end
    
        -- Convert BallSocketConstraints back to Motor6D
        ConvertBallSocketConstraintToMotor(socket)
        for _,torsoSocket in torsoSockets do
            ConvertBallSocketConstraintToMotor(torsoSocket)
        end
    
        humanoid:ChangeState(Enum.HumanoidStateType.None)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
        humanoid.RequiresNeck = true
        humanoid.Sit = false

    end)
end




--[---------------------------]--
--[        KNIT METHODS       ]--
--[---------------------------]--


function RagdollService:KnitStart()
    
end


function RagdollService:KnitInit()
    
end


return RagdollService
