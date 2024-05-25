-- RemoteSignal
-- Stephen Leitnick
-- December 20, 2021
--? Amended by TestyLike3 to drop middleware

local Players = game:GetService("Players")

--[=[
	@class RemoteSignal
	@server
	Created via `ServerComm:CreateSignal()`.
]=]
local RemoteSignalModule = {}
RemoteSignalModule.__index = RemoteSignalModule

export type RemoteSignal = {
	_remoteEvent : RemoteEvent | UnreliableRemoteEvent,
}
--[=[
	@within RemoteSignal
	@interface Connection
	.Disconnect () -> nil
	.Connected boolean

	Represents a connection.
]=]

function RemoteSignalModule.new(parent: Instance, name: string, unreliable: boolean?) : RemoteSignal
	local self = setmetatable({} :: RemoteSignal, RemoteSignalModule)
	self._remoteEvent = if unreliable == true then Instance.new("UnreliableRemoteEvent") else Instance.new("RemoteEvent")
	self._remoteEvent.Name = name
	self._remoteEvent.Parent = parent
	return self
end

--[=[
	@return boolean
	Returns `true` if the underlying RemoteSignal is bound to an
	UnreliableRemoteEvent object.
]=]
function RemoteSignalModule.IsUnreliable(self : RemoteSignal) : boolean
	return self._remoteEvent:IsA("UnreliableRemoteEvent")
end

--[=[
	@param fn (player: Player, ...: any) -> nil -- The function to connect
	@return Connection
	Connect a function to the signal. Anytime a matching ClientRemoteSignal
	on a client fires, the connected function will be invoked with the
	arguments passed by the client.
]=]
function RemoteSignalModule.Connect(self : RemoteSignal, fn) : RBXScriptConnection
	return self._remoteEvent.OnServerEvent:Connect(fn)
end

--[=[
	@param player Player -- The target client
	@param ... any -- Arguments passed to the client
	Fires the signal at the specified client with any arguments.
]=]
function RemoteSignalModule.Fire(self : RemoteSignal, player: Player, ...: any) : nil
	self._remoteEvent:FireClient(player, ...)
end

--[=[
	@param ... any
	Fires the signal at _all_ clients with any arguments.
]=]
function RemoteSignalModule.FireAll(self : RemoteSignal, ...: any)
	self._re:FireAllClients(...)
end

--[=[
	@param ignorePlayer Player -- The client to ignore
	@param ... any -- Arguments passed to the other clients
	Fires the signal to all clients _except_ the specified
	client.
]=]
function RemoteSignalModule.FireExcept(self : RemoteSignal, ignorePlayer: Player, ...: any)
	self:FireFilter(function(plr)
		return plr ~= ignorePlayer
	end, ...)
end

--[=[
	@param predicate (player: Player, argsFromFire: ...) -> boolean
	@param ... any -- Arguments to pass to the clients (and to the predicate)
	Fires the signal at any clients that pass the `predicate`
	function test. This can be used to fire signals with much
	more control logic.

	```lua
	-- Fire signal to players of the same team:
	remoteSignal:FireFilter(function(player)
		return player.Team.Name == "Best Team"
	end)
	```
]=]
function RemoteSignalModule.FireFilter(self : RemoteSignal, predicate: (Player, ...any) -> boolean, ...: any)
	for _, player in Players:GetPlayers() do
		if predicate(player, ...) then
			self._re:FireClient(player, ...)
		end
	end
end

--[=[
	Fires a signal at the clients within the `players` table. This is
	useful when signals need to fire for a specific set of players.

	For more complex firing, see `FireFilter`.
	```lua
	local players = {somePlayer1, somePlayer2, somePlayer3}
	remoteSignal:FireFor(players, "Hello, players!")
	```
]=]
function RemoteSignalModule.FireFor(self : RemoteSignal, players: { Player }, ...: any)
	for _, player in players do
		self._re:FireClient(player, ...)
	end
end

--[=[
	Destroys the RemoteSignal object.
]=]
function RemoteSignalModule.Destroy(self : RemoteSignal)
	self._re:Destroy()
end

return RemoteSignalModule
