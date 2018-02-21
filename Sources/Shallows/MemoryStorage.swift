import Dispatch

public final class MemoryStorage<Key : Hashable, Value> : StorageProtocol {
    
    public let storageName: String
    
    private var _storage: ThreadSafe<[Key : Value]>
    
    public var storage: [Key : Value] {
        get {
            return _storage.read()
        }
        set {
            _storage.write(newValue)
        }
    }
    
    public init(storage: [Key : Value] = [:]) {
        self._storage = ThreadSafe(storage)
        self.storageName = "memory-storage-\(Key.self):\(Value.self)"
    }
    
    public func set(_ value: Value, forKey key: Key, completion: @escaping (Result<Void>) -> ()) {
        _storage.write(with: { $0[key] = value })
        completion(.success)
    }
    
    public func retrieve(forKey key: Key, completion: @escaping (Result<Value>) -> ()) {
        let result: Result<Value> = {
            if let value = _storage.read()[key] {
                return .success(value)
            } else {
                return .failure(MemoryStorageError.noValue)
            }
        }()
        completion(result)
    }
    
}

enum MemoryStorageError : Error {
    case noValue
}

public struct ThreadSafe<Value> {
    
    private var value: Value
    private let queue = DispatchQueue(label: "thread-safety-queue", attributes: [.concurrent])
    
    public init(_ value: Value) {
        self.value = value
    }
    
    public func read() -> Value {
        return queue.sync { value }
    }
    
    public mutating func write(with modify: (inout Value) -> ()) {
        queue.sync(flags: .barrier) {
            modify(&value)
        }
    }
    
    public mutating func write(_ newValue: Value) {
        queue.sync(flags: .barrier) {
            value = newValue
        }
    }
    
}
