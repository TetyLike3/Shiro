-- ClientRemoteSignal
-- Stephen Leitnick
-- December 20, 2021

--[=[
	@class ClientRemoteSignal
	@client
	Created via `ClientComm:GetSignal()`.
]=]
local ClientRemoteSignal = {}
ClientRemoteSignal.__index = ClientRemoteSignal

--[=[
	@within ClientRemoteSignal
	@interface Connection
	.Disconnect () -> ()

	Represents a connection.
]=]

function ClientRemoteSignal.new(remoteEvent: RemoteEvent | UnreliableRemoteEvent)
	local self = setmetatable({}, ClientRemoteSignal)
	self._remoteEvent = remoteEvent
	return self
end

--[=[
	@param fn (...: any) -> ()
	@return Connection
	Connects a function to the remote signal. The function will be
	called anytime the equivalent server-side RemoteSignal is
	fired at this specific client that created this client signal.
]=]
function ClientRemoteSignal:Connect(fn: (...any) -> ())
	return self._signal:Connect(fn)
end

--[=[
	Fires the equivalent server-side signal with the given arguments.
]=]
function ClientRemoteSignal:Fire(...: any)
	self._re:FireServer(...)
end

--[=[
	Destroys the ClientRemoteSignal object.
]=]
function ClientRemoteSignal:Destroy()
	if self._signal then
		self._signal:Destroy()
	end
end

return ClientRemoteSignal