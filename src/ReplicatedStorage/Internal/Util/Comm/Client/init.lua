local Util = require(script.Parent.Util)
local Promise = require(script.Parent.Parent.Promise)
local ClientRemoteSignal = require(script.ClientRemoteSignal)
local ClientRemoteProperty = require(script.ClientRemoteProperty)

local Client = {}

function Client.GetFunction(parent: Instance, name: string, usePromise: boolean)
	assert(not Util.IsServer, "GetFunction must be called from the client")
	local folder = Util.GetCommSubFolder(parent, "RF")
    assert(folder, "Failed to get Comm RF folder")
	local remoteFunction = folder:WaitForChild(name, Util.WaitForChildTimeout)
	assert(remoteFunction ~= nil, "Failed to find RemoteFunction: " .. name)
    if usePromise then
        return function(...)
            local args = table.pack(...)
            return Promise.new(function(resolve, reject)
                local success, res = pcall(function()
                    return table.pack(remoteFunction:InvokeServer(table.unpack(args, 1, args.n)))
                end)
                if success then
                    resolve(table.unpack(res, 1, res.n))
                else
                    reject(res)
                end
            end)
        end
    else
        return function(...)
            return remoteFunction:InvokeServer(...)
        end
    end
end

function Client.GetSignal(parent: Instance, name: string)
	assert(not Util.IsServer, "GetSignal must be called from the client")
	local folder = Util.GetCommSubFolder(parent, "RE")
    assert(folder, "Failed to get Comm RE folder")
	local remoteEvent = folder:WaitForChild(name, Util.WaitForChildTimeout)
	assert(remoteEvent ~= nil, "Failed to find RemoteEvent: " .. name)
	return ClientRemoteSignal.new(remoteEvent)
end

function Client.GetProperty(parent: Instance, name: string)
	assert(not Util.IsServer, "GetProperty must be called from the client")
	local folder = Util.GetCommSubFolder(parent, "RP")
    assert(folder, "Failed to get Comm RP folder")
	local remoteEvent = folder:WaitForChild(name, Util.WaitForChildTimeout)
	assert(remoteEvent ~= nil, "Failed to find RemoteEvent for RemoteProperty: " .. name)
	return ClientRemoteProperty.new(remoteEvent)
end

return Client