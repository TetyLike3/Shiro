type FrameworkOptions = {
    DebugMode: boolean?,
}

local defaultOptions: FrameworkOptions = {
    DebugMode = false
}

local selectedOptions = defaultOptions

local function debugPrint(...)
    if selectedOptions.DebugMode then
        print(`KURO_DEBUG: {...}`)
    end
end


local ServerModule = {}
ServerModule.Util = script.Parent.Parent.Util
ServerModule.Common = require(ServerModule.Util.Common)
ServerModule.SharedStorage = game:GetService("ReplicatedStorage").Framework.Storage :: Folder
ServerModule.ServerStorage = game:GetService("ServerStorage").Framework :: Folder
ServerModule.TempStorage = ServerModule.SharedStorage:FindFirstChild("Temp") :: Folder

if not ServerModule.TempStorage then
    local tempFolder = Instance.new("Folder")
    tempFolder.Name = "Temp"
    tempFolder.Parent = ServerModule.SharedStorage
    ServerModule.TempStorage = tempFolder
end
if not ServerModule.TempStorage:FindFirstChild("AttachmentParent") then
    local attachmentParent = Instance.new("Part")
    attachmentParent.Name = "AttachmentParent"
    attachmentParent.Parent = ServerModule.TempStorage
end

local serviceStorage = Instance.new("Folder")
serviceStorage.Name = "Services"

local Promise = require(ServerModule.Util.Promise)
local Comm = require(ServerModule.Util.Comm)
local ServerComm = Comm.ServerComm
local Types = require(ServerModule.Util.Types)



local SIGNAL_MARKER : Types.RemoteSignal = newproxy(true)
getmetatable(SIGNAL_MARKER).__tostring = function()
	return "SIGNAL_MARKER"
end

local UNRELIABLE_SIGNAL_MARKER : Types.RemoteSignal = newproxy(true)
getmetatable(UNRELIABLE_SIGNAL_MARKER).__tostring = function()
	return "UNRELIABLE_SIGNAL_MARKER"
end

local PROPERTY_MARKER : Types.RemoteProperty<any> = newproxy(true)
getmetatable(PROPERTY_MARKER).__tostring = function()
	return "PROPERTY_MARKER"
end


function ServerModule:FireSoundFXEvent(fx : Instance, parent : Instance)
    fx.Parent = ServerModule.TempStorage

    local fxData : Types.FXSoundData = {
        fxType = Types.FXTypes.Sound,
        fxName = fx:GetFullName(),
        fxParentName = parent:GetFullName()
    }
    ServerModule.FXEvent:FireAllClients(fxData)
end
function ServerModule:FireParticleFXEvent(fx : Instance, parent : Instance, emitOnce : boolean)
    if fx:IsA("Attachment") then
        fx.Parent = ServerModule.TempStorage.AttachmentParent
    else
        fx.Parent = ServerModule.TempStorage
    end

    local fxData : Types.FXParticleData = {
        fxType = Types.FXTypes.Particle,
        fxName = fx:GetFullName(),
        fxParentName = parent:GetFullName(),
        emitOnce = emitOnce
    }
    ServerModule.FXEvent:FireAllClients(fxData)
end

-- FX event
local FXEvent = Instance.new("RemoteEvent")
FXEvent.Name = "FXEvent"
FXEvent.Parent = script.Parent
ServerModule.FXEvent = FXEvent


type ServiceDefinition = {
    Name: string,
	Client: {
        Signals: {[string]: Types.RemoteSignal},
        Properties: {[string]: Types.RemoteProperty<any>}
    }?,
}

type LoadedService = {
    Name: string,
    Client: ServiceClient,
	Comm: any,

    FrameworkInit: () -> nil?,
    FrameworkStart: () -> nil?
}

type ServiceClient = {
	Server: LoadedService,
    Signals: {[string]: Types.RemoteSignal},
    Properties: {[string]: Types.RemoteProperty<any>}
}


local loadedServices : {[string] : LoadedService} = {}
local isStarting = false
local hasStarted = false
local onStarted = Instance.new("BindableEvent")

local function DoesServiceExist(serviceName: string): boolean
    return loadedServices[serviceName] ~= nil
end

function ServerModule.CreateService(definition : ServiceDefinition) : LoadedService
	assert(type(definition) == "table", `Service must be a table; got {type(definition)}`)
	assert(type(definition.Name) == "string", `Service.Name must be a string; got {type(definition.Name)}`)
	assert(#definition.Name > 0, "Service.Name must be a non-empty string")
	assert(not DoesServiceExist(definition.Name), `Service "{definition.Name}" already exists`)
	assert(not isStarting, `Services cannot be created after calling "Knit.Start()"`)

    local service = definition :: LoadedService
    service.Comm = ServerComm.new(serviceStorage, definition.Name)

    if type(service.Client) ~= "table" then
        service.Client = { Server = service, Signals = {}, Properties = {} }
    else
        service.Client.Server = service

        if type(service.Client.Signals) ~= "table" then
            service.Client.Signals = {}
        end
        if type(service.Client.Properties) ~= "table" then
            service.Client.Properties = {}
        end
    end

    debugPrint(`Created service {service.Name}`)
    loadedServices[service.Name] = service
    return service
end

function ServerModule.GetService(serviceName: string): LoadedService
	assert(isStarting, "Cannot call GetService until Knit has been started")
	assert(type(serviceName) == "string", `ServiceName must be a string; got {type(serviceName)}`)
    debugPrint(`Getting service {serviceName}`)

	return assert(loadedServices[serviceName], `Could not find service "{serviceName}"`)
end

function ServerModule.CreateSignal()
    return SIGNAL_MARKER
end

function ServerModule.CreateUnreliableSignal()
    return UNRELIABLE_SIGNAL_MARKER
end

function ServerModule.CreateProperty(value: any)
    return PROPERTY_MARKER
end


function ServerModule.Start(options: FrameworkOptions?)
    if isStarting then return Promise.reject("Kuro already started") end
    isStarting = true

    -- Prevent new services from loading
    table.freeze(loadedServices)

    -- Load options
    if not options then
        selectedOptions = defaultOptions
        debugPrint("No FrameworkOptions provided; using defaults")
    else
        assert(type(options) == "table", `FrameworkOptions must be a table; got {type(options)}`)
        selectedOptions = options
        for k,v in defaultOptions do
            if options[k] == nil then
                options[k] = v
            end
        end
        debugPrint("Using FrameworkOptions:")
		if selectedOptions.DebugMode then print(selectedOptions) end
    end

    -- Init and start services
    return Promise.new(function(resolve)
        for _,service in loadedServices do
            for k,v in service.Client do
                if k == "Signals" or k == "Properties" then continue end

                if (type(v) == "function") then
                    service.Comm:WrapMethod(service.Client, k)
                    debugPrint(`Wrapped method {k} in {service.Name}`)
                end
            end

            for k,v in service.Client.Signals do
                if (v == SIGNAL_MARKER) then
                    service.Client.Signals[k] = service.Comm:CreateSignal(k,false)
                    debugPrint(`Created signal {k} in {service.Name}`)
                elseif (v == UNRELIABLE_SIGNAL_MARKER) then
                    service.Client.Signals[k] = service.Comm:CreateSignal(k,true)
                    debugPrint(`Created unreliable signal {k} in {service.Name}`)
                end
            end

            for k,v in service.Client.Properties do
                if not (v == PROPERTY_MARKER) then continue end
                service.Client.Properties[k] = service.Comm:CreateProperty(k, v)
                debugPrint(`Created property {k} with value {service.Client.Properties[k]} in {service.Name}`)
            end
        end

        local promises = {}
        for _,service in loadedServices do
            if type(service.FrameworkInit) == "function" then
                table.insert(
                    promises,
                    Promise.new(function(rslve)
                        debug.setmemorycategory(service.Name)
                        debugPrint(`Calling :FrameworkInit() on {service.Name}`)
                        service:FrameworkInit()
                        rslve()
                    end)
                )
            end
        end

        resolve(Promise.all(promises))
    end):andThen(function()
        for _,service in loadedServices do
            if type(service.FrameworkStart) == "function" then
                task.spawn(function()
					debug.setmemorycategory(service.Name)
                    debugPrint(`Calling :FrameworkStart() on {service.Name}`)
					service:FrameworkStart()
				end)
            end
        end

        hasStarted = true
        onStarted:Fire()

        task.defer(function()
            onStarted:Destroy()
        end)

        serviceStorage.Parent = script.Parent
    end)
end

function ServerModule.OnStart()
    if hasStarted then
        return Promise.resolve()
    else
        return Promise.fromEvent(onStarted.Event)
    end
end

return ServerModule