local DSS = game:GetService("DataStoreService")
local MPS = game:GetService("MarketplaceService")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local emoteAnimFolder = game:GetService("ServerStorage").EmoteAnims :: Folder
local emoteSoundFolder = SoundService:FindFirstChild("Emotes") :: SoundGroup

local Knit = require(RS.Framework.Internal.Packages.Knit)

local EmoteService = Knit.CreateService {
    Name = "EmoteService",
    Client = {},
}


local emoteProductIDs = {
    Coco = 1829113138
}

local DSCache = {} :: {
    [number]: {
        [string]: boolean
    }
}

function EmoteService.Client:PlayEmote(player : Player, emoteName : string)
    local emoteAnim = emoteAnimFolder:FindFirstChild(emoteName) :: Animation
    if not emoteAnim then return end

    local emoteProductID = emoteProductIDs[emoteName]
    if not DSCache[player.UserId][emoteAnim.Name] and emoteProductID then -- Prompt player to buy the emote
        MPS:PromptProductPurchase(player, emoteProductID)
        local purchaseFinished
        purchaseFinished = MPS.PromptProductPurchaseFinished:Connect(function(_, productID, wasPurchased)
            if productID ~= emoteProductID then return end
            if wasPurchased then DSCache[player.UserId][emoteAnim.Name] = true end
            purchaseFinished:Disconnect()
        end)

        repeat task.wait(.1) until purchaseFinished == nil
    end
    if not DSCache[player.UserId][emoteAnim.Name] then return end -- Return if player still doesn't own the emote

    local animator = player.Character:FindFirstChildOfClass("Humanoid"):FindFirstChild("Animator") :: Animator
    if not animator then return end

    local emoteSound = emoteSoundFolder:FindFirstChild(emoteName) :: Sound

    print("Playing emote", emoteName, "for", player.Name)
    print("Emote sound:", emoteSound and emoteSound.Name or "None")
    print("Emote anim:", emoteAnim.Name)
    print("Emote product ID:", emoteProductID)
    animator:LoadAnimation(emoteAnim):Play()
    if emoteSound then
        local newSound = emoteSound:Clone()
        newSound.Parent = player.Character.HumanoidRootPart
        newSound:Play()
        newSound.Ended:Connect(function()
            newSound:Destroy()
        end)
    end
end

function EmoteService:KnitStart()
    
end


function EmoteService:KnitInit()
    Players.PlayerAdded:Connect(function(player)
        DSCache[player.UserId] = {Coco = true}
    end)

    Players.PlayerRemoving:Connect(function(player)
        DSCache[player.UserId] = nil
    end)
end


return EmoteService
