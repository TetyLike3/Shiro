local RS = game:GetService("ReplicatedStorage")

local events = RS.Framework.Storage:WaitForChild("Events",5)
local Knit = require(RS.Framework.Internal.Packages.Knit)

events.Framework_Init.Event:Wait()
warn("--- CLIENT FRAMEWORK INITIALIZING ---")
-- Expose modules
Knit.SharedStorage = RS.Framework.Storage

-- Only load modules in the controllers folder ending with "Controller"
for _,module in ipairs(script.Parent.Controllers:GetDescendants()) do
    if module:IsA("ModuleScript") and module.Name:match("Controller$") then
        print("CLIENT: Loading controller " .. module.Name)
        events.Framework_ModuleLoading:Fire(module.Name)
        require(module)
    end
end
events.Framework_ModuleLoading:Fire("__EOF")

events.LoadingScreenClosing.Event:Wait()

Knit.Start():andThen(function()
    print("CLIENT: Knit started")
end):catch(warn)