local RS = game:GetService("ReplicatedStorage")

local events = RS.Framework.Storage:WaitForChild("Events",5)
local Framework = require(RS.Framework.Internal.Kuro)

local frameworkOptions = {
    DebugMode = false
}

events.Framework_Init.Event:Wait()
warn("--- CLIENT FRAMEWORK INITIALIZING ---")

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

Framework.Start(frameworkOptions):andThen(function()
    print("CLIENT: Kuro started")
end):catch(warn)