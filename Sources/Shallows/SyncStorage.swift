import Dispatch

extension StorageProtocol {
    
    public func synchronizedCalls() -> Storage<Key, Value> {
        let queue: DispatchQueue = DispatchQueue(label: "\(Self.self)-storage-thread-safety-queue")
        return Storage<Key, Value>(
            storageName: self.storageName,
            retrieve: { key in
                return queue.sync {
                    self.retrieve(forKey: key)
                }
            },
            set: { value, key in
                return queue.sync {
                    self.set(value, forKey: key).observe(on: queue)
                }
            }
        )
    }
    
}

public struct SyncStorage<Key, Value> {
    
    public let storageName: String
    
    private let _retrieve: (Key) throws -> Value
    private let _set: (Value, Key) throws -> Void
    
    public init(storageName: String, retrieve: @escaping (Key) throws -> Value, set: @escaping (Value, Key) throws -> Void) {
        self.storageName = storageName
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

    public init(storageName: String, retrieve: @escaping (Key) throws -> Value) {
        self.storageName = storageName
        self._retrieve = retrieve
    }
    
    public func retrieve(forKey key: Key) throws -> Value {
        return try _retrieve(key)
    }

}

public struct WriteOnlySyncStorage<Key, Value> {
    
    public let storageName: String
    
    private let _set: (Value, Key) throws -> Void
    
    public init(storageName: String, set: @escaping (Value, Key) throws -> Void) {
        self.storageName = storageName
        self._set = set
    }
    
    public func set(_ value: Value, forKey key: Key) throws {
        try _set(value, key)
    }
    
}

extension ReadOnlyStorageProtocol {
    
    public func makeSyncStorage() -> ReadOnlySyncStorage<Key, Value> {
        return ReadOnlySyncStorage(storageName: "\(self.storageName)-sync", retrieve: { (key) throws -> Value in
            return try self.retrieve(forKey: key).waitValue()
        })
    }
    
}

extension WriteOnlyStorageProtocol {
    
    public func makeSyncStorage() -> WriteOnlySyncStorage<Key, Value> {
        return WriteOnlySyncStorage(storageName: self.storageName + "-sync", set: { (value, key) in
            return try self.set(value, forKey: key).waitValue()
        })
    }
    
}

extension StorageProtocol {
    
    public func makeSyncStorage() -> SyncStorage<Key, Value> {
        let readOnly = asReadOnlyStorage().makeSyncStorage()
        let writeOnly = asWriteOnlyStorage().makeSyncStorage()
        return SyncStorage(storageName: readOnly.storageName, retrieve: readOnly.retrieve, set: writeOnly.set)
    }
    
}

extension Future {
    public func waitValue() throws -> Value {
        return try wait().get()
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
