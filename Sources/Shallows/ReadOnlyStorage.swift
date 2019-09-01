
public protocol ReadableStorageProtocol : StorageDesign {
    
    associatedtype Key
    associatedtype Value
    
    func retrieve(forKey key: Key) -> ShallowsFuture<Value>
    func asReadOnlyStorage() -> ReadOnlyStorage<Key, Value>
    
}

extension ReadableStorageProtocol {
    
    public func retrieve(forKey key: Key, completion: @escaping (ShallowsResult<Value>) -> Void) {
        retrieve(forKey: key).on(success: { (value) in
            completion(.success(value))
        }, failure: { (error) in
            completion(.failure(error))
        })
    }
    
    public func asReadOnlyStorage() -> ReadOnlyStorage<Key, Value> {
        if let alreadyNormalized = self as? ReadOnlyStorage<Key, Value> {
            return alreadyNormalized
        }
        return ReadOnlyStorage(self)
    }
    
}

public protocol ReadOnlyStorageProtocol : ReadableStorageProtocol {  }

public struct ReadOnlyStorage<Key, Value> : ReadOnlyStorageProtocol {
    
    public let storageName: String
    
    private let _retrieve: (Key) -> (ShallowsFuture<Value>)
    
    public init(storageName: String, retrieve: @escaping (Key) -> (ShallowsFuture<Value>)) {
        self._retrieve = retrieve
        self.storageName = storageName
    }
    
    public init<StorageType : ReadableStorageProtocol>(_ storage: StorageType) where StorageType.Key == Key, StorageType.Value == Value {
        self._retrieve = storage.retrieve
        self.storageName = storage.storageName
    }
    
    public func retrieve(forKey key: Key) -> ShallowsFuture<Value> {
        _retrieve(key)
    }
    
}

extension ReadOnlyStorageProtocol {
    
    public func mapKeys<OtherKey>(to type: OtherKey.Type = OtherKey.self,
                                  _ transform: @escaping (OtherKey) throws -> Key) -> ReadOnlyStorage<OtherKey, Value> {
        return ReadOnlyStorage<OtherKey, Value>(storageName: storageName, retrieve: { key in
            do {
                let newKey = try transform(key)
                return self.retrieve(forKey: newKey)
            } catch {
                return Future(error: error)
            }
        })
    }
    
    public func mapValues<OtherValue>(to type: OtherValue.Type = OtherValue.self,
                                      _ transform: @escaping (Value) throws -> OtherValue) -> ReadOnlyStorage<Key, OtherValue> {
        return ReadOnlyStorage<Key, OtherValue>(storageName: storageName, retrieve: { (key) in
            return self.retrieve(forKey: key).tryMap(transform)
        })
    }
    
}

extension ReadOnlyStorageProtocol {
    
    public func mapValues<OtherValue : RawRepresentable>(toRawRepresentableType type: OtherValue.Type) -> ReadOnlyStorage<Key, OtherValue> where OtherValue.RawValue == Value {
        return mapValues(throwing(OtherValue.init(rawValue:)))
    }
    
    public func mapKeys<OtherKey : RawRepresentable>(toRawRepresentableType type: OtherKey.Type) -> ReadOnlyStorage<OtherKey, Value> where OtherKey.RawValue == Key {
        return mapKeys({ $0.rawValue })
    }
    
}

extension ReadOnlyStorageProtocol {
    
    public func singleKey(_ key: Key) -> ReadOnlyStorage<Void, Value> {
        return mapKeys({ key })
    }
    
}

extension ReadOnlyStorageProtocol {
    
    public func fallback(with produceValue: @escaping (Error) throws -> Value) -> ReadOnlyStorage<Key, Value> {
        return ReadOnlyStorage(storageName: self.storageName, retrieve: { (key) in
            return self.retrieve(forKey: key).flatMapError { (error) in
                do {
                    let fallbackValue = try produceValue(error)
                    return Future(value: fallbackValue)
                } catch let fallbackError {
                    return Future(error: fallbackError)
                }
            }
        })
    }
    
    public func defaulting(to defaultValue: @autoclosure @escaping () -> Value) -> ReadOnlyStorage<Key, Value> {
        return fallback(with: { _ in defaultValue() })
    }
    
}

public enum UnsupportedTransformationStorageError : Error {
    case storageIsReadOnly
    case storageIsWriteOnly
}

extension ReadOnlyStorageProtocol {
    
    public func usingUnsupportedTransformation<OtherKey, OtherValue>(_ transformation: (Storage<Key, Value>) -> Storage<OtherKey, OtherValue>) -> ReadOnlyStorage<OtherKey, OtherValue> {
        let fullStorage = Storage<Key, Value>(storageName: self.storageName, retrieve: self.retrieve) { (_, _) in
            return Future(error: UnsupportedTransformationStorageError.storageIsReadOnly)
        }
        return transformation(fullStorage).asReadOnlyStorage()
    }
    
}
