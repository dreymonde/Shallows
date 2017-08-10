import Dispatch

internal func dispatched<In>(to queue: DispatchQueue, _ function: @escaping (In) -> ()) -> (In) -> () {
    return { input in
        queue.async(execute: { function(input) })
    }
}

extension CacheProtocol {
    
    public func synchronizedCalls(on queue: DispatchQueue = DispatchQueue(label: "\(Self.self)-cache-thread-safety-queue")) -> Cache<Key, Value> {
        return Cache<Key, Value>(cacheName: self.cacheName,
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

public struct SyncCache<Key, Value> {
    
    public let cacheName: String
    
    private let _retrieve: (Key) throws -> Value
    private let _set: (Value, Key) throws -> Void
    
    public init(cacheName: String, retrieve: @escaping (Key) throws -> Value, set: @escaping (Value, Key) throws -> Void) {
        self.cacheName = cacheName
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

public struct ReadOnlySyncCache<Key, Value> {
    
    public let cacheName: String
    
    private let _retrieve: (Key) throws -> Value

    public init(cacheName: String, retrieve: @escaping (Key) throws -> Value) {
        self.cacheName = cacheName
        self._retrieve = retrieve
    }
    
    public func retrieve(forKey key: Key) throws -> Value {
        return try _retrieve(key)
    }

}

public struct WriteOnlySyncCache<Key, Value> {
    
    public let cacheName: String
    
    private let _set: (Value, Key) throws -> Void
    
    public init(cacheName: String, set: @escaping (Value, Key) throws -> Void) {
        self.cacheName = cacheName
        self._set = set
    }
    
    public func set(_ value: Value, forKey key: Key) throws {
        try _set(value, key)
    }
    
}

extension ReadOnlyCache {
    
    public func makeSyncCache() -> ReadOnlySyncCache<Key, Value> {
        return ReadOnlySyncCache(cacheName: "\(self.cacheName)-sync", retrieve: { (key) throws -> Value in
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

extension WriteOnlyCache {
    
    public func makeSyncCache() -> WriteOnlySyncCache<Key, Value> {
        return WriteOnlySyncCache(cacheName: self.cacheName + "-sync", set: { (value, key) in
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

extension CacheProtocol {
    
    public func makeSyncCache() -> SyncCache<Key, Value> {
        return SyncCache(cacheName: "\(self.cacheName)-sync", retrieve: { (key) throws -> Value in
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

extension SyncCache where Key == Void {
    
    public func retrieve() throws -> Value {
        return try retrieve(forKey: ())
    }
    
    public func set(_ value: Value) throws {
        try set(value, forKey: ())
    }
    
}

extension ReadOnlySyncCache where Key == Void {
    
    public func retrieve() throws -> Value {
        return try retrieve(forKey: ())
    }
    
}

extension WriteOnlySyncCache where Key == Void {
    
    public func set(_ value: Value) throws {
        try set(value, forKey: ())
    }
    
}
