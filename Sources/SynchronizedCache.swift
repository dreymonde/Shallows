import Dispatch

internal func dispatched<In>(to queue: DispatchQueue, _ function: @escaping (In) -> ()) -> (In) -> () {
    return { input in
        queue.async(execute: { function(input) })
    }
}

extension CacheProtocol {
    
    public func synchronizedCalls(on queue: DispatchQueue = DispatchQueue(label: "\(Self.self)-cache-thread-safety-queue")) -> Cache<Key, Value> {
        return Cache<Key, Value>(name: self.name,
                                 retrieve: dispatched(to: queue, self.retrieve(forKey:completion:)),
                                 set: dispatched(to: queue, self.set(_:forKey:completion:)))
    }
    
}

public struct SyncCache<Key, Value> {
    
    public let name: String
    
    private let _retrieve: (Key) throws -> Value
    private let _set: (Value, Key) throws -> ()
    
    public init(name: String, retrieve: @escaping (Key) throws -> Value, set: @escaping (Value, Key) throws -> ()) {
        self.name = name
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

fileprivate extension Result {
    
    func value() throws -> Value {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
    
}

extension CacheProtocol {
    
    public func makeSyncCache() -> SyncCache<Key, Value> {
        return SyncCache.init(name: self.name + "-sync", retrieve: { (key) throws -> Value in
            let semaphore = DispatchSemaphore(value: 0)
            var r_result: Result<Value>?
            self.retrieve(forKey: key, completion: { (result) in
                r_result = result
                semaphore.signal()
            })
            semaphore.wait()
            return try r_result!.value()
        }, set: { (value, key) in
            let semaphore = DispatchSemaphore(value: 0)
            var r_result: Result<Void>?
            self.set(value, forKey: key, completion: { (result) in
                r_result = result
                semaphore.signal()
            })
            semaphore.wait()
            return try r_result!.value()
        })
    }
    
}
