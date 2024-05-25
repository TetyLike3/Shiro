type FrameworkOptions = {
    DebugMode: boolean?,
	ServicePromises: boolean
}

local defaultOptions: FrameworkOptions = {
    DebugMode = false,
	ServicePromises = true
}

local selectedOptions = defaultOptions

local function debugPrint(...)
    if selectedOptions.DebugMode then
        print(`KURO_DEBUG: {...}`)
    end
end

local ClientModule = {}
ClientModule.Player = game:GetService("Players").LocalPlayer
ClientModule.Util = script.Parent.Parent.Util :: Folder
ClientModule.SharedStorage = game:GetService("ReplicatedStorage").Framework.Storage :: Folder

local Promise = require(ClientModule.Util.Promise)
local Comm = require(ClientModule.Util.Comm)
local ClientComm = Comm.ClientComm


type ControllerDefinition = {
	Name: string,
	[any]: any,
}

type LoadedController = {
	Name: string,
	[any]: any,

	FrameworkInit: () -> nil?,
	FrameworkStart: () -> nil?
}

type ServiceReference = {
	[any]: any,
}


local loadedControllers: { [string]: LoadedController } = {}
local serviceReferences: { [string]: ServiceReference } = {}
local servicesFolder = nil

local isStarting = false
local hasStarted = false
local onStarted = Instance.new("BindableEvent")

local function DoesControllerExist(controllerName: string): boolean
	return loadedControllers[controllerName] ~= nil
end

local function GetServicesFolder()
	if not servicesFolder then
		servicesFolder = script.Parent:WaitForChild("Services")
	end

	return servicesFolder
end

local function BuildService(serviceName: string)
	local folder = GetServicesFolder()
	local clientComm = ClientComm.new(folder, selectedOptions.ServicePromises, serviceName)
	local service = clientComm:BuildObject()

	serviceReferences[serviceName] = service

	return service
end

function ClientModule.CreateController(definition: ControllerDefinition): LoadedController
	assert(type(definition) == "table", `Controller must be a table; got {type(definition)}`)
	assert(type(definition.Name) == "string", `Controller.Name must be a string; got {type(definition.Name)}`)
	assert(#definition.Name > 0, "Controller.Name must be a non-empty string")
	assert(not DoesControllerExist(definition.Name), `Controller {definition.Name} already exists`)
	assert(not isStarting, `Controllers cannot be created after calling "Knit.Start()"`)

	local controller = definition :: LoadedController

    
    debugPrint(`Created controller {controller.Name}`)
	loadedControllers[controller.Name] = controller
	return controller
end

function ClientModule.GetService(serviceName: string): ServiceReference
	local service = serviceReferences[serviceName]
	if service then
		return service
	end

	assert(isStarting, "Cannot call GetService until Knit has been started")
	assert(type(serviceName) == "string", `ServiceName must be a string; got {type(serviceName)}`)

	return BuildService(serviceName)
end

function ClientModule.GetController(controllerName: string): LoadedController
	assert(isStarting, "Cannot call GetController until Knit has been started")
	assert(type(controllerName) == "string", `ControllerName must be a string; got {type(controllerName)}`)
    debugPrint(`Getting service {controllerName}`)

	return assert(loadedControllers[controllerName], `Could not find controller "{controllerName}"`)
end

function ClientModule.Start(options: FrameworkOptions?)
    if isStarting then return Promise.reject("Kuro already started") end
    isStarting = true

	table.freeze(loadedControllers)

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

	return Promise.new(function(resolve)
		-- Init:
		local promisesStartControllers = {}

		for _, controller in loadedControllers do
			if type(controller.FrameworkInit) == "function" then
				table.insert(
					promisesStartControllers,
					Promise.new(function(rslve)
						debug.setmemorycategory(controller.Name)
                        debugPrint(`Calling :FrameworkInit() on {controller.Name}`)
						controller:FrameworkInit()
						rslve()
					end)
				)
			end
		end

		resolve(Promise.all(promisesStartControllers))
	end):andThen(function()
		-- Start:
		for _, controller in loadedControllers do
			if type(controller.FrameworkStart) == "function" then
				task.spawn(function()
					debug.setmemorycategory(controller.Name)
                    debugPrint(`Calling :FrameworkStart() on {controller.Name}`)
					controller:FrameworkStart()
				end)
			end
		end

		hasStarted = true
		onStarted:Fire()

		task.defer(function()
			onStarted:Destroy()
		end)
	end)
end

function ClientModule.OnStart()
	if hasStarted then
		return Promise.resolve()
	else
		return Promise.fromEvent(onStarted.Event)
	end
end

return ClientModule