import Dispatch

internal func dispatched<In>(to queue: DispatchQueue, _ function: @escaping (In) -> ()) -> (In) -> () {
    return { input in
        queue.async(execute: { function(input) })
    }
}

internal func dispatched<In1, In2>(to queue: DispatchQueue, _ function: @escaping (In1, In2) -> ()) -> (In1, In2) -> () {
    return { in1, in2 in
        queue.async(execute: { function(in1, in2) })
    }
}

internal func dispatched<In1, In2, In3>(to queue: DispatchQueue, _ function: @escaping (In1, In2, In3) -> ()) -> (In1, In2, In3) -> () {
    return { in1, in2, in3 in
        queue.async(execute: { function(in1, in2, in3) })
    }
}

extension StorageProtocol {
    
    public func synchronizedCalls(on queue: DispatchQueue = DispatchQueue(label: "\(Self.self)-cache-thread-safety-queue")) -> Storage<Key, Value> {
        return Storage<Key, Value>(cacheName: self.storageName,
                                 retrieve: dispatched(to: queue, self.retrieve(forKey:completion:)),
                                 set: dispatched(to: queue, self.set(_:forKey:completion:)))
    }
    
}

extension Result {
    
    func getValue() throws -> Value {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
    
}

public struct SyncStorage<Key, Value> {
    
    public let storageName: String
    
    private let _retrieve: (Key) throws -> Value
    private let _set: (Value, Key) throws -> Void
    
    public init(cacheName: String, retrieve: @escaping (Key) throws -> Value, set: @escaping (Value, Key) throws -> Void) {
        self.storageName = cacheName
        self._retrieve = retrieve
        self._set = set
    }
    
    public func retrieve(forKey key: Key) throws -> Value {
        return try _retrieve(key)
    }
    
    public func set(_ value: Value, forKey key: Key) throws {
        try _set(value, key)
    }
    
}

public struct ReadOnlySyncStorage<Key, Value> {
    
    public let storageName: String
    
    private let _retrieve: (Key) throws -> Value

    public init(cacheName: String, retrieve: @escaping (Key) throws -> Value) {
        self.storageName = cacheName
        self._retrieve = retrieve
    }
    
    public func retrieve(forKey key: Key) throws -> Value {
        return try _retrieve(key)
    }

}

public struct WriteOnlySyncStorage<Key, Value> {
    
    public let storageName: String
    
    private let _set: (Value, Key) throws -> Void
    
    public init(cacheName: String, set: @escaping (Value, Key) throws -> Void) {
        self.storageName = cacheName
        self._set = set
    }
    
    public func set(_ value: Value, forKey key: Key) throws {
        try _set(value, key)
    }
    
}

extension ReadOnlyStorageProtocol {
    
    public func makeSyncStorage() -> ReadOnlySyncStorage<Key, Value> {
        return ReadOnlySyncStorage(cacheName: "\(self.storageName)-sync", retrieve: { (key) throws -> Value in
            let semaphore = DispatchSemaphore(value: 0)
            var r_result: Result<Value>?
            self.retrieve(forKey: key, completion: { (result) in
                r_result = result
                semaphore.signal()
            })
            semaphore.wait()
            return try r_result!.getValue()
        })
    }
    
}

extension WriteOnlyStorageProtocol {
    
    public func makeSyncStorage() -> WriteOnlySyncStorage<Key, Value> {
        return WriteOnlySyncStorage(cacheName: self.storageName + "-sync", set: { (value, key) in
            let semaphore = DispatchSemaphore(value: 0)
            var r_result: Result<Void>?
            self.set(value, forKey: key, completion: { (result) in
                r_result = result
                semaphore.signal()
            })
            semaphore.wait()
            return try r_result!.getValue()
        })
    }
    
}

extension StorageProtocol {
    
    public func makeSyncStorage() -> SyncStorage<Key, Value> {
        return SyncStorage(cacheName: "\(self.storageName)-sync", retrieve: { (key) throws -> Value in
            let semaphore = DispatchSemaphore(value: 0)
            var r_result: Result<Value>?
            self.retrieve(forKey: key, completion: { (result) in
                r_result = result
                semaphore.signal()
            })
            semaphore.wait()
            return try r_result!.getValue()
        }, set: { (value, key) in
            let semaphore = DispatchSemaphore(value: 0)
            var r_result: Result<Void>?
            self.set(value, forKey: key, completion: { (result) in
                r_result = result
                semaphore.signal()
            })
            semaphore.wait()
            return try r_result!.getValue()
        })
    }
    
}

extension SyncStorage where Key == Void {
    
    public func retrieve() throws -> Value {
        return try retrieve(forKey: ())
    }
    
    public func set(_ value: Value) throws {
        try set(value, forKey: ())
    }
    
}

extension ReadOnlySyncStorage where Key == Void {
    
    public func retrieve() throws -> Value {
        return try retrieve(forKey: ())
    }
    
}

extension WriteOnlySyncStorage where Key == Void {
    
    public func set(_ value: Value) throws {
        try set(value, forKey: ())
    }
    
}
