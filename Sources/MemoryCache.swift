import Dispatch

enum MemoryCacheError : Error {
    case noValue
}

public struct ThreadSafe<Value> {
    
    private var _value: Value
    private let queue = DispatchQueue(label: "thread-safety-queue", attributes: [.concurrent])
    
    public init(_ value: Value) {
        self._value = value
    }
    
    public func read() -> Value {
        return queue.sync { _value }
    }
    
    public mutating func write(_ modify: (inout Value) -> ()) {
        queue.sync(flags: .barrier) {
            modify(&_value)
        }
    }
    
    public mutating func write(_ newValue: Value) {
        queue.sync(flags: .barrier) {
            _value = newValue
        }
    }
    
}

public final class MemoryCache<Key : Hashable, Value> : CacheProtocol {
    
    public let cacheName: String
    
    private let queue = DispatchQueue(label: "com.shallows.memory-cache-queue")
    private var _storage: ThreadSafe<[Key : Value]>
    
    public var storage: [Key : Value] {
        get {
            return _storage.read()
        }
        set {
            _storage.write(newValue)
        }
    }
    
    public init(storage: [Key : Value] = [:], cacheName: String = "memory-cache-\(Key.self):\(Value.self)") {
        self._storage = ThreadSafe(storage)
        self.cacheName = cacheName
    }
    
    public func set(_ value: Value, forKey key: Key, completion: @escaping (Result<Void>) -> ()) {
        queue.sync {
            _storage.write({ (dict: inout [Key : Value]) in dict[key] = value })
        }
        completion(.success)
    }
    
    public func retrieve(forKey key: Key, completion: @escaping (Result<Value>) -> ()) {
        let result: Result<Value> = queue.sync {
            if let value = _storage.read()[key] {
                return .success(value)
            } else {
                return .failure(MemoryCacheError.noValue)
            }
        }
        completion(result)
    }
    
}
