public protocol WritableStorageProtocol : StorageDesign {
    
    associatedtype Key
    associatedtype Value
    
    func set(_ value: Value, forKey key: Key, completion: @escaping (Result<Void>) -> ())
    
}

public protocol WriteOnlyStorageProtocol : WritableStorageProtocol {  }

public struct WriteOnlyStorage<Key, Value> : WriteOnlyStorageProtocol {
    
    public let storageName: String
    
    private let _set: (Value, Key, @escaping (Result<Void>) -> ()) -> ()
    
    public init(storageName: String, set: @escaping (Value, Key, @escaping (Result<Void>) -> ()) -> ()) {
        self._set = set
        self.storageName = storageName
    }
    
    public init<StorageType : WritableStorageProtocol>(_ storage: StorageType) where StorageType.Key == Key, StorageType.Value == Value {
        self._set = storage.set
        self.storageName = storage.storageName
    }
    
    public func set(_ value: Value, forKey key: Key, completion: @escaping (Result<Void>) -> ()) {
        self._set(value, key, completion)
    }
    
}

extension WritableStorageProtocol {
    
    public func asWriteOnlyStorage() -> WriteOnlyStorage<Key, Value> {
        return WriteOnlyStorage(self)
    }
    
}

extension WriteOnlyStorageProtocol {
    
    public func mapKeys<OtherKey>(_ transform: @escaping (OtherKey) throws -> Key) -> WriteOnlyStorage<OtherKey, Value> {
        return WriteOnlyStorage<OtherKey, Value>(storageName: storageName, set: { (value, key, completion) in
            do {
                let newKey = try transform(key)
                self.set(value, forKey: newKey, completion: completion)
            } catch {
                completion(.failure(error))
            }
        })
    }
    
    public func mapValues<OtherValue>(_ transform: @escaping (OtherValue) throws -> Value) -> WriteOnlyStorage<Key, OtherValue> {
        return WriteOnlyStorage<Key, OtherValue>(storageName: storageName, set: { (value, key, completion) in
            do {
                let newValue = try transform(value)
                self.set(newValue, forKey: key, completion: completion)
            } catch {
                completion(.failure(error))
            }
        })
    }
    
}

extension WriteOnlyStorageProtocol {
    
    public func singleKey(_ key: Key) -> WriteOnlyStorage<Void, Value> {
        return mapKeys({ key })
    }
    
}
