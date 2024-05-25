local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Framework = require(RS.Framework.Internal.Kuro)

local frameworkOptions = {
    DebugMode = true
}

warn("--- SERVER FRAMEWORK INITIALIZING ---")

-- Only load modules in the services folder ending with "Service"
for _,module in ipairs(script.Parent.Services:GetDescendants()) do
    if module:IsA("ModuleScript") and module.Name:match("Service$") then
        print("SERVER: Loading service " .. module.Name)
        require(module)
    end
end

Framework.Start(frameworkOptions):andThen(function()
    print("SERVER: Kuro started")
end):catch(warn)