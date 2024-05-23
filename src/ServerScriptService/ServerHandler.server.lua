local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local Knit = require(RS.Framework.Internal.Packages.Knit)


warn("--- SERVER FRAMEWORK INITIALIZING ---")
-- Expose modules
Knit.SharedStorage = RS.Framework.Storage
Knit.ServerStorage = SS.Framework

-- Only load modules in the services folder ending with "Service"
for _,module in ipairs(script.Parent.Services:GetDescendants()) do
    if module:IsA("ModuleScript") and module.Name:match("Service$") then
        print("SERVER: Loading service " .. module.Name)
        require(module)
    end
end


Knit.Start():andThen(function()
    print("SERVER: Knit started")
end):catch(warn)