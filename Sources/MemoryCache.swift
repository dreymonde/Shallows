import Dispatch

enum MemCacheError : Error {
    case noValue
}

public final class MemoryCache<Key : Hashable, Value> : CacheProtocol {
    
    public let name: String
    
    private let queue = DispatchQueue(label: "com.shallows.memory-cache-queue")
    private var _storage: [Key : Value]
    
    public var storage: [Key : Value] {
        get {
            return queue.sync { _storage }
        }
        set {
            queue.sync {
                _storage = newValue
            }
        }
    }
    
    public init(storage: [Key : Value] = [:], name: String = "memory-cache-\(Key.self):\(Value.self)") {
        self._storage = storage
        self.name = name
    }
    
    public func set(_ value: Value, forKey key: Key, completion: @escaping (Result<Void>) -> ()) {
        queue.sync {
            _storage[key] = value
        }
        completion(.success())
    }
    
    public func retrieve(forKey key: Key, completion: @escaping (Result<Value>) -> ()) {
        let result: Result<Value> = queue.sync {
            if let value = _storage[key] {
                return .success(value)
            } else {
                return .failure(MemCacheError.noValue)
            }
        }
        completion(result)
    }
    
}
