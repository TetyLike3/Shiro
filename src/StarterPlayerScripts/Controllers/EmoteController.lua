local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Framework = require(RS.Framework.Internal.Kuro)

local EmoteController = Framework.CreateController { Name = "EmoteController" }
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

function EmoteController:FrameworkStart()
    Players.LocalPlayer.CharacterAdded:Connect(function()
        connectGUI()
    end)

    if Players.LocalPlayer.Character then
        connectGUI()
    end
end


function EmoteController:FrameworkInit()
    EmoteService = Framework.GetService("EmoteService")
end


return EmoteController
