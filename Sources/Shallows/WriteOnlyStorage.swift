public protocol WritableStorageProtocol : StorageDesign {
    
    associatedtype Key
    associatedtype Value
    
    func set(_ value: Value, forKey key: Key, completion: @escaping (ShallowsResult<Void>) -> ())
    func asWriteOnlyStorage() -> WriteOnlyStorage<Key, Value>
    
}

extension WritableStorageProtocol {
    
    public func asWriteOnlyStorage() -> WriteOnlyStorage<Key, Value> {
        if let alreadyNormalized = self as? WriteOnlyStorage<Key, Value> {
            return alreadyNormalized
        }
        return WriteOnlyStorage(self)
    }
    
}

public protocol WriteOnlyStorageProtocol : WritableStorageProtocol {  }

public struct WriteOnlyStorage<Key, Value> : WriteOnlyStorageProtocol {
    
    public let storageName: String
    
    private let _set: (Value, Key, @escaping (ShallowsResult<Void>) -> ()) -> ()
    
    public init(storageName: String, set: @escaping (Value, Key, @escaping (ShallowsResult<Void>) -> ()) -> ()) {
        self._set = set
        self.storageName = storageName
    }
    
    public init<StorageType : WritableStorageProtocol>(_ storage: StorageType) where StorageType.Key == Key, StorageType.Value == Value {
        self._set = storage.set
        self.storageName = storage.storageName
    }
    
    public func set(_ value: Value, forKey key: Key, completion: @escaping (ShallowsResult<Void>) -> ()) {
        self._set(value, key, completion)
    }
    
}

extension WriteOnlyStorageProtocol {
    
    public func mapKeys<OtherKey>(to type: OtherKey.Type = OtherKey.self,
                                  _ transform: @escaping (OtherKey) throws -> Key) -> WriteOnlyStorage<OtherKey, Value> {
        return WriteOnlyStorage<OtherKey, Value>(storageName: storageName, set: { (value, key, completion) in
            do {
                let newKey = try transform(key)
                self.set(value, forKey: newKey, completion: completion)
            } catch {
                completion(.failure(error))
            }
        })
    }
    
    public func mapValues<OtherValue>(to type: OtherValue.Type = OtherValue.self,
                                      _ transform: @escaping (OtherValue) throws -> Value) -> WriteOnlyStorage<Key, OtherValue> {
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

extension WriteOnlyStorageProtocol {
    
    public func mapValues<OtherValue : RawRepresentable>(toRawRepresentableType type: OtherValue.Type) -> WriteOnlyStorage<Key, OtherValue> where OtherValue.RawValue == Value {
        return mapValues({ $0.rawValue })
    }
    
    public func mapKeys<OtherKey : RawRepresentable>(toRawRepresentableType type: OtherKey.Type) -> WriteOnlyStorage<OtherKey, Value> where OtherKey.RawValue == Key {
        return mapKeys({ $0.rawValue })
    }
    
}

extension WriteOnlyStorageProtocol {
    
    public func usingUnsupportedTransformation<OtherKey, OtherValue>(_ transformation: (Storage<Key, Value>) -> Storage<OtherKey, OtherValue>) -> WriteOnlyStorage<OtherKey, OtherValue> {
        let fullStorage = Storage<Key, Value>(storageName: self.storageName, retrieve: { (_, completion) in
            completion(fail(with: UnsupportedTransformationStorageError.storageIsWriteOnly))
        }, set: self.set)
        return transformation(fullStorage).asWriteOnlyStorage()
    }
    
}
