enum MemCacheError : Error {
    case noValue
}

public final class MemoryCache<Key : Hashable, Value> : CacheProtocol {
    
    public let name: String
    
    public var storage: [Key : Value]
    
    public init(storage: [Key : Value], name: String = "MemoryCache\(Key.self):\(Value.self)") {
        self.storage = storage
        self.name = name
    }
    
    public func set(_ value: Value, forKey key: Key, completion: @escaping (Result<Void>) -> ()) {
        storage[key] = value
        completion(.success())
    }
    
    public func retrieve(forKey key: Key, completion: @escaping (Result<Value>) -> ()) {
        if let value = storage[key] {
            completion(.success(value))
        } else {
            completion(.failure(MemCacheError.noValue))
        }
    }
    
}
