local RunService = game:GetService("RunService")

if RunService:IsServer() then
	return require(script.ServerModule)
else
	local serverModule = script:FindFirstChild("ServerModule")
	if serverModule and RunService:IsRunning() then
		serverModule:Destroy()
	end

	return require(script.ClientModule)
end