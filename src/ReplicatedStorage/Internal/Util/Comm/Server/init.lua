local RemoteProperty = require(script.RemoteProperty)
local RemoteSignal = require(script.RemoteSignal)
local Util = require(script.Parent.Util)

local Server = {}

--[=[
	@within Comm
	@prop ServerComm ServerComm
]=]
--[=[
	@within Comm
	@prop ClientComm ClientComm
]=]

--[=[
	@within Comm
	@private
	@interface Server
	.BindFunction (parent: Instance, name: string, fn: FnBind): RemoteFunction
	.WrapMethod (parent: Instance, tbl: table, name: string): RemoteFunction
	.CreateSignal (parent: Instance, name: string): RemoteSignal
	.CreateProperty (parent: Instance, name: string, value: any): RemoteProperty
	Server Comm
]=]
--[=[
	@within Comm
	@private
	@interface Client
	.GetFunction (parent: Instance, name: string, usePromise: boolean): (...: any) -> any
	.GetSignal (parent: Instance, name: string): ClientRemoteSignal
	.GetProperty (parent: Instance, name: string): ClientRemoteProperty
	Client Comm
]=]

function Server.BindFunction(parent: Instance, name: string, func: (Instance, ...any) -> ...any): RemoteFunction
	assert(Util.IsServer, "BindFunction must be called from the server")
	local folder = Util.GetCommSubFolder(parent, "RF")
	assert(folder, "Failed to get Comm RF folder")
	local remoteFuntion = Instance.new("RemoteFunction")
	remoteFuntion.Name = name
	remoteFuntion.OnServerInvoke = func
	remoteFuntion.Parent = folder
	return remoteFuntion
end

function Server.WrapMethod(parent: Instance, tbl: {}, name: string): RemoteFunction
	assert(Util.IsServer, "WrapMethod must be called from the server")
	local func = tbl[name]
	assert(type(func) == "function", "Value at index " .. name .. " must be a function; got " .. type(func))
	return Server.BindFunction(parent, name, function(...) return func(tbl, ...) end)
end

function Server.CreateSignal(parent: Instance, name: string, reliable: boolean?)
	assert(Util.IsServer, "CreateSignal must be called from the server")
	local folder = Util.GetCommSubFolder(parent, "RE")
	assert(folder, "Failed to get Comm RE folder")
	local remoteSignal = RemoteSignal.new(folder, name, reliable)
	return remoteSignal
end

function Server.CreateProperty(parent: Instance, name: string, initialValue: any)
	assert(Util.IsServer, "CreateProperty must be called from the server")
	local folder = Util.GetCommSubFolder(parent, "RP")
	assert(folder, "Failed to get Comm RP folder")
	local remoteProperty = RemoteProperty.new(folder, name, initialValue)
	return remoteProperty
end

return Server