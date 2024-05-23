local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Knit = require(RS.Framework.Internal.Packages.Knit)

local EmoteController = Knit.CreateController { Name = "EmoteController" }
local EmoteService



local emoteButtonClickHandle = nil
local function connectGUI()
    local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("EmoteGUI") :: ScreenGui

    emoteButtonClickHandle = gui:WaitForChild("EmoteButton").MouseButton1Click:Connect(function()
        EmoteService:PlayEmote("Coco")
    end)

    print("Connected GUI")

    gui.Enabled = true
end

function EmoteController:KnitStart()
    Players.LocalPlayer.CharacterAdded:Connect(function()
        connectGUI()
    end)

    if Players.LocalPlayer.Character then
        connectGUI()
    end
end


function EmoteController:KnitInit()
    EmoteService = Knit.GetService("EmoteService")
end


return EmoteController
