public protocol ReadableStorageProtocol : StorageDesign {
    
    associatedtype Key
    associatedtype Value
    
    func retrieve(forKey key: Key, completion: @escaping (Result<Value>) -> ())
    
}

public protocol ReadOnlyStorageProtocol : ReadableStorageProtocol {  }

public struct ReadOnlyStorage<Key, Value> : ReadOnlyStorageProtocol {
    
    public let storageName: String
    
    private let _retrieve: (Key, @escaping (Result<Value>) -> ()) -> ()
    
    public init(storageName: String, retrieve: @escaping (Key, @escaping (Result<Value>) -> ()) -> ()) {
        self._retrieve = retrieve
        self.storageName = storageName
    }
    
    public init<StorageType : ReadableStorageProtocol>(_ storage: StorageType) where StorageType.Key == Key, StorageType.Value == Value {
        self._retrieve = storage.retrieve
        self.storageName = storage.storageName
    }
    
    public func retrieve(forKey key: Key, completion: @escaping (Result<Value>) -> ()) {
        _retrieve(key, completion)
    }
    
}

extension ReadableStorageProtocol {
    
    public func asReadOnlyStorage() -> ReadOnlyStorage<Key, Value> {
        return ReadOnlyStorage(self)
    }
    
}

extension ReadOnlyStorageProtocol {
    
    public func backed<StorageType : ReadableStorageProtocol>(by storage: StorageType) -> ReadOnlyStorage<Key, Value> where StorageType.Key == Key, StorageType.Value == Value {
        return ReadOnlyStorage(storageName: "\(self.storageName)-\(storage.storageName)", retrieve: { (key, completion) in
            self.retrieve(forKey: key, completion: { (firstResult) in
                if firstResult.isFailure {
                    shallows_print("Storage (\(self.storageName)) miss for key: \(key). Attempting to retrieve from \(storage.storageName)")
                    storage.retrieve(forKey: key, completion: completion)
                } else {
                    completion(firstResult)
                }
            })
        })
    }
    
    public func mapKeys<OtherKey>(to type: OtherKey.Type = OtherKey.self,
                                  _ transform: @escaping (OtherKey) throws -> Key) -> ReadOnlyStorage<OtherKey, Value> {
        return ReadOnlyStorage<OtherKey, Value>(storageName: storageName, retrieve: { key, completion in
            do {
                let newKey = try transform(key)
                self.retrieve(forKey: newKey, completion: completion)
            } catch {
                completion(.failure(error))
            }
        })
    }
    
    public func mapValues<OtherValue>(to type: OtherValue.Type = OtherValue.self,
                                      _ transform: @escaping (Value) throws -> OtherValue) -> ReadOnlyStorage<Key, OtherValue> {
        return ReadOnlyStorage<Key, OtherValue>(storageName: storageName, retrieve: { (key, completion) in
            self.retrieve(forKey: key, completion: { (result) in
                switch result {
                case .success(let value):
                    do {
                        let newValue = try transform(value)
                        completion(.success(newValue))
                    } catch {
                        completion(.failure(error))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            })
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
        return ReadOnlyStorage(storageName: self.storageName, retrieve: { (key, completion) in
            self.retrieve(forKey: key, completion: { (result) in
                switch result {
                case .failure(let error):
                    do {
                        let fallbackValue = try produceValue(error)
                        completion(.success(fallbackValue))
                    } catch let fallbackError {
                        completion(.failure(fallbackError))
                    }
                case .success(let value):
                    completion(.success(value))
                }
            })
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
        let fullStorage = Storage<Key, Value>(storageName: self.storageName, retrieve: self.retrieve) { (_, _, completion) in
            completion(fail(with: UnsupportedTransformationStorageError.storageIsReadOnly))
        }
        return transformation(fullStorage).asReadOnlyStorage()
    }
    
}
