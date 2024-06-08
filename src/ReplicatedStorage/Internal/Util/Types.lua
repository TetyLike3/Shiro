local Types = {}

Types.FXTypes = {
    Sound = "SOUND",
    Particle = "PARTICLE",
}

export type FXDefaultData = {
    fxType: string,
    fxName: string,
    fxParentName: string,
}

export type FXSoundData = FXDefaultData & {}

export type FXParticleData = FXDefaultData & {
    emitOnce: boolean,
}

-- Comm
type PromiseStatus = {
    Started: "Started",
    Resolved: "Resolved",
    Rejected: "Rejected",
    Cancelled: "Cancelled",
}
export type Promise<T> = {
    andThen: (self: Promise<T>, successHandler: (any) -> any, failureHandler: ((any) -> any)?) -> Promise<any>,
    andThenCall: (self: Promise<T>, callback: (...T) -> any, ...any?) -> Promise<any>,
    andThenReturn: (self: Promise<T>, ...T) -> Promise<any>,
    await: (self: Promise<T>) -> (boolean, ...any),
    awaitStatus: (self: Promise<T>) -> (PromiseStatus, ...any),
    cancel: (self: Promise<T>) -> nil,
    catch: (self: Promise<T>, failureHandler: (...any) -> ...any) -> Promise<...any>,
    expect: (self: Promise<T>) -> ...any,
    finally: (self: Promise<T>, finallyHandler: (PromiseStatus) -> ...any) -> Promise<...any>,
    finallyCall: (self: Promise<T>, callback: (...any) -> any, ...any?) -> Promise<T>,
    finallyReturn: (self: Promise<T>, ...any) -> Promise<T>,
    getStatus: (self: Promise<T>) -> PromiseStatus,
    now: (self: Promise<T>, rejectionValue: any?) -> Promise<T>,
    tap: (self: Promise<T>, tapHandler: (...any) -> ...any) -> Promise<...any>,
    timeout: (self: Promise<T>, seconds: number, rejectionValue: any?) -> Promise<T>,

    all: (promises: {Promise<any>}) -> Promise<any>,
    allSettled: (promises: {Promise<any>}) -> Promise<{PromiseStatus}>,
    any: (promises: {Promise<any>}) -> Promise<any>,
    defer: (executor: (resolve: (...any) -> (), reject: (...any) -> (), onCancel: ((abortHandler: () -> ()) -> boolean)?) -> ()) -> Promise<any>,
    delay: (seconds: number) -> Promise<number>,
    each: (list: {any | Promise<any>}, predicate: (value: any, index: number) -> any | Promise<any>) -> Promise<{any}>,
    fold: (list: {any | Promise<any>}, reducer: (accumulator: any, value: any, index: number) -> any | Promise<any>, initialValue: any) -> (),
    fromEvent: (event: RBXScriptSignal, predicate: (any) -> boolean) -> Promise<any>,
    is: (object: any) -> boolean,
    new: (executor: (resolve: (...any) -> (), reject: (...any) -> (), onCancel: ((abortHandler: () -> ()) -> boolean)?) -> ()) -> Promise<any>,
    onUnhandledRejection: (callback: (promise: Promise<any>, ...any) -> ()) -> (),
    promisify: (fn: (...any) -> ...any) -> (...any) -> Promise<any>,
    race: (promises: {Promise<any>}) -> Promise<any>,
    reject: (...any) -> Promise<...any>,
    resolve: (...any) -> Promise<...any>,
    retry: (callback: (...any) -> Promise<any>, times: number, ...any?) -> Promise<any>,
    retryWithDelay: (callback: (...any) -> Promise<any>, times: number, seconds: number, ...any?) -> Promise<any>,
    some: (promises: {Promise<any>}, count: number) -> Promise<any>,
    try: (callback: (...any) -> ...any, ...any) -> Promise<any>
}

export type RemoteSignal = {
    _remoteEvent : RemoteEvent | UnreliableRemoteEvent,

    IsUnreliable: (self: RemoteSignal) -> boolean,
    Connect: (self: RemoteSignal, fn: (any) -> any) -> RBXScriptConnection,
    Fire: (self: RemoteSignal, player: Player, any) -> nil,
    FireAll: (self: RemoteSignal, any) -> nil,
    FireExcept: (self: RemoteSignal, ignorePlayer: Player, any) -> nil,
    FireFilter: (self: RemoteSignal, fn: (any) -> boolean) -> nil,
    FireFor: (self: RemoteSignal, players: {Player}, any) -> nil,
    Destroy: (self: RemoteSignal) -> nil
}

export type RemoteProperty<T> = {
    _remoteEvent: RemoteEvent | UnreliableRemoteEvent,

    Set: (self: RemoteProperty<T>, value: T) -> nil,
    SetTop: (self: RemoteProperty<T>, value: T) -> nil,
    SetFilter: (self: RemoteProperty<T>, predicate: (Player, any) -> boolean, value: T) -> nil,
    SetFor: (self: RemoteProperty<T>, player: Player, value: T) -> nil,
    SetForList: (self: RemoteProperty<T>, players: {Player}, T) -> nil,
    ClearFor: (self: RemoteProperty<T>, player: Player) -> nil,
    ClearForList: (self: RemoteProperty<T>, players: {Player}) -> nil,
    ClearFilter: (self: RemoteProperty<T>, predicate: (Player) -> boolean) -> nil,
    Get: (self: RemoteProperty<T>) -> T,
    GetFor: (self: RemoteProperty<T>, player: Player) -> T,
    Destroy: (self: RemoteProperty<T>) -> nil
}

export type ClientRemoteSignal = {
	_remoteEvent : RemoteEvent | UnreliableRemoteEvent,

    Connect: (self: ClientRemoteSignal, fn: (any) -> any) -> RBXScriptConnection,
    Fire: (self: ClientRemoteSignal, player: Player, any) -> nil,
}

export type ClientRemoteProperty = {
    _remoteEvent: RemoteEvent | UnreliableRemoteEvent,

    Get: (self: ClientRemoteProperty) -> any,
    OnReady: (self: ClientRemoteProperty) -> Promise<any>,
    IsReady: (self: ClientRemoteProperty) -> boolean,
    Observe: (self: ClientRemoteProperty, callback: (any) -> ()) -> ()
}

return Types