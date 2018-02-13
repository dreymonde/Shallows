public protocol StorageDesign {
    
    var storageName: String { get }
    
}

extension StorageDesign {
    
    public var storageName: String {
        return String(describing: Self.self)
    }
    
}

public protocol StorageProtocol : ReadableStorageProtocol, WritableStorageProtocol { }

public struct Storage<Key, Value> : StorageProtocol {
    
    public let storageName: String
    
    private let _retrieve: ReadOnlyStorage<Key, Value>
    private let _set: WriteOnlyStorage<Key, Value>

    public init(storageName: String,
                retrieve: @escaping (Key, @escaping (Result<Value>) -> ()) -> (),
                set: @escaping (Value, Key, @escaping (Result<Void>) -> ()) -> ()) {
        self._retrieve = ReadOnlyStorage(storageName: storageName, retrieve: retrieve)
        self._set = WriteOnlyStorage(storageName: storageName, set: set)
        self.storageName = storageName
    }
    
    public init<StorageType : StorageProtocol>(_ storage: StorageType) where StorageType.Key == Key, StorageType.Value == Value {
        self._retrieve = storage.asReadOnlyStorage()
        self._set = storage.asWriteOnlyStorage()
        self.storageName = storage.storageName
    }
    
    public init(readStorage: ReadOnlyStorage<Key, Value>,
                writeStorage: WriteOnlyStorage<Key, Value>) {
        self._retrieve = readStorage
        self._set = writeStorage
        self.storageName = readStorage.storageName
    }
    
    public func retrieve(forKey key: Key, completion: @escaping (Result<Value>) -> ()) {
        _retrieve.retrieve(forKey: key, completion: completion)
    }
    
    public func set(_ value: Value, forKey key: Key, completion: @escaping (Result<Void>) -> () = { _ in }) {
        _set.set(value, forKey: key, completion: completion)
    }
    
    public func asReadOnlyStorage() -> ReadOnlyStorage<Key, Value> {
        return _retrieve.renaming(to: storageName)
    }
    
    public func asWriteOnlyStorage() -> WriteOnlyStorage<Key, Value> {
        return _set.renaming(to: storageName)
    }
    
}

internal func storageName(left: String, right: String, pullingFromBack: Bool, pushingToBack: Bool) -> String {
    switch (pullingFromBack, pushingToBack) {
    case (true, true):
        return left + "<->" + right
    case (true, false):
        return left + "<-" + right
    case (false, true):
        return left + "->" + right
    case (false, false):
        return left + "-" + right
    }
}

extension StorageProtocol {
    
    public var dev: Storage<Key, Value>.Dev {
        return Storage<Key, Value>.Dev(self.asStorage())
    }
    
}

extension Storage {
    
    public struct Dev {
        
        fileprivate let frontStorage: Storage
        
        fileprivate init(_ storage: Storage) {
            self.frontStorage = storage
        }
        
        public func set<StorageType : WritableStorageProtocol>(_ value: Value,
                        forKey key: Key,
                        pushingTo backStorage: StorageType,
                        completion: @escaping (Result<Void>) -> ()) where StorageType.Key == Key, StorageType.Value == Value {
            frontStorage.set(value, forKey: key, pushingTo: backStorage, completion: completion)
        }
        
        public func retrieve<StorageType : ReadableStorageProtocol>(forKey key: Key,
                             backedBy backStorage: StorageType,
                             completion: @escaping (Result<Value>) -> ()) where StorageType.Key == Key, StorageType.Value == Value{
            frontStorage.retrieve(forKey: key, backedBy: backStorage, completion: completion)
        }
        
    }
    
}

public enum StorageCombinationPullStrategy {
    case pullThenComplete
    case completeThenPull
    case neverPull
}

public enum StorageCombinationSetStrategy {
    case backFirst
    case frontFirst
    case frontOnly
    case backOnly
}

extension WritableStorageProtocol {
    
    fileprivate func set<StorageType : WritableStorageProtocol>(_ value: Value,
                         forKey key: Key,
                         pushingTo storage: StorageType,
                         completion: @escaping (Result<Void>) -> ()) where StorageType.Key == Key, StorageType.Value == Value {
        self.set(value, forKey: key, completion: { (result) in
            if result.isFailure {
                shallows_print("Failed setting \(key) to \(self.storageName). Aborting")
                completion(result)
            } else {
                shallows_print("Succesfull set of \(key). Pushing to \(storage.storageName)")
                storage.set(value, forKey: key, completion: completion)
            }
        })
    }
    
    fileprivate func set<StorageType : WritableStorageProtocol>(_ value: Value,
                         forKey key: Key,
                         pushingTo storage: StorageType,
                         strategy: StorageCombinationSetStrategy,
                         completion: @escaping (Result<Void>) -> ()) where StorageType.Key == Key, StorageType.Value == Value {
        switch strategy {
        case .frontFirst:
            self.set(value, forKey: key, pushingTo: storage, completion: completion)
        case .backFirst:
            storage.set(value, forKey: key, pushingTo: self, completion: completion)
        case .frontOnly:
            self.set(value, forKey: key, completion: completion)
        case .backOnly:
            storage.set(value, forKey: key, completion: completion)
        }
    }
    
}

extension StorageProtocol {
    
    public func asStorage() -> Storage<Key, Value> {
        return Storage(self)
    }
    
    public func update(forKey key: Key,
                       _ modify: @escaping (inout Value) -> (),
                       completion: @escaping (Result<Value>) -> () = { _ in }) {
        retrieve(forKey: key) { (result) in
            switch result {
            case .success(var value):
                modify(&value)
                self.set(value, forKey: key, completion: { (setResult) in
                    switch setResult {
                    case .success:
                        completion(.success(value))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                })
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
}

extension StorageProtocol {
    
    fileprivate func retrieve<StorageType : ReadableStorageProtocol>(forKey key: Key,
                              backedBy storage: StorageType,
                              completion: @escaping (Result<Value>) -> ()) where StorageType.Key == Key, StorageType.Value == Value {
        self.retrieve(forKey: key, completion: { (firstResult) in
            if firstResult.isFailure {
                shallows_print("Storage (\(self.storageName)) miss for key: \(key). Attempting to retrieve from \(storage.storageName)")
                storage.retrieve(forKey: key, completion: { (secondResult) in
                    if let value = secondResult.value {
                        shallows_print("Success retrieving \(key) from \(storage.storageName). Setting value back to \(self.storageName)")
                        self.set(value, forKey: key, completion: { _ in completion(secondResult) })
                    } else {
                        shallows_print("Storage miss for final destination (\(storage.storageName)). Completing with failure result")
                        completion(secondResult)
                    }
                })
            } else {
                completion(firstResult)
            }
        })
    }
    
}

extension StorageProtocol {
    
    @available(*, unavailable, message: "strategies are no longer supported")
    public func combined<StorageType : StorageProtocol>(with storage: StorageType,
                         pullStrategy: StorageCombinationPullStrategy = .pullThenComplete,
                         setStrategy: StorageCombinationSetStrategy = .frontFirst) -> Storage<Key, Value> where StorageType.Key == Key, StorageType.Value == Value {
        fatalError()
    }
    
    public func combined<StorageType : StorageProtocol>(with backStorage: StorageType) -> Storage<Key, Value> where StorageType.Key == Key, StorageType.Value == Value {
        let name = Shallows.storageName(left: self.storageName, right: backStorage.storageName, pullingFromBack: true, pushingToBack: true)
        return Storage(storageName: name, retrieve: { (key, completion) in
            self.retrieve(forKey: key, backedBy: backStorage, completion: completion)
        }, set: { (value, key, completion) in
            self.set(value, forKey: key, pushingTo: backStorage, completion: completion)
        })
    }
    
    @available(*, deprecated, message: "Strategy no longer works")
    public func pushing<WritableStorageType : WritableStorageProtocol>(to backStorage: WritableStorageType,
                        strategy: StorageCombinationSetStrategy = .frontFirst) -> Storage<Key, Value> where WritableStorageType.Key == Key, WritableStorageType.Value == Value {
        return Storage<Key, Value>(storageName: "\(self.storageName)>\(backStorage.storageName)", retrieve: { (key, completion) in
            self.retrieve(forKey: key, completion: completion)
        }, set: { (value, key, completion) in
            self.set(value, forKey: key, pushingTo: backStorage, strategy: strategy, completion: completion)
        })
    }
    
    public func backed<ReadableStorageType : ReadableStorageProtocol>(by readableStorage: ReadableStorageType) -> Storage<Key, Value> where ReadableStorageType.Key == Key, ReadableStorageType.Value == Value {
        let name = Shallows.storageName(left: storageName, right: readableStorage.storageName, pullingFromBack: true, pushingToBack: false)
        return Storage<Key, Value>(storageName: name, retrieve: { (key, completion) in
            self.retrieve(forKey: key, backedBy: readableStorage, completion: completion)
        }, set: { (value, key, completion) in
            self.set(value, forKey: key, completion: completion)
        })
    }
    
    @available(*, deprecated, message: "Strategy no longer works")
    public func backed<ReadableStorageType : ReadableStorageProtocol>(by storage: ReadableStorageType,
                       strategy: StorageCombinationPullStrategy) -> Storage<Key, Value> where ReadableStorageType.Key == Key, ReadableStorageType.Value == Value {
        return Storage<Key, Value>(storageName: "\(self.storageName)+\(storage.storageName)", retrieve: { (key, completion) in
            self.retrieve(forKey: key, backedBy: storage, completion: completion)
        }, set: { value, key, completion in
            self.set(value, forKey: key, completion: completion)
        })
    }
    
}

extension StorageProtocol {
    
    public func mapKeys<OtherKey>(to type: OtherKey.Type = OtherKey.self,
                                  _ transform: @escaping (OtherKey) throws -> Key) -> Storage<OtherKey, Value> {
        return Storage(readStorage: asReadOnlyStorage().mapKeys(transform),
                       writeStorage: asWriteOnlyStorage().mapKeys(transform))
    }
    
    public func mapValues<OtherValue>(to type: OtherValue.Type = OtherValue.self,
                                      transformIn: @escaping (Value) throws -> OtherValue,
                                      transformOut: @escaping (OtherValue) throws -> Value) -> Storage<Key, OtherValue> {
        return Storage(readStorage: asReadOnlyStorage().mapValues(transformIn),
                       writeStorage: asWriteOnlyStorage().mapValues(transformOut))
    }
    
}

extension StorageProtocol {
    
    public func mapValues<OtherValue : RawRepresentable>(toRawRepresentableType type: OtherValue.Type) -> Storage<Key, OtherValue> where OtherValue.RawValue == Value {
        return mapValues(transformIn: throwing(OtherValue.init(rawValue:)),
                         transformOut: { $0.rawValue })
    }
    
    public func mapKeys<OtherKey : RawRepresentable>(toRawRepresentableType type: OtherKey.Type) -> Storage<OtherKey, Value> where OtherKey.RawValue == Key {
        return mapKeys({ $0.rawValue })
    }
    
}

extension StorageProtocol {
    
    public func fallback(with produceValue: @escaping (Error) throws -> Value) -> Storage<Key, Value> {
        let readOnly = asReadOnlyStorage().fallback(with: produceValue)
        return Storage(readStorage: readOnly, writeStorage: asWriteOnlyStorage())
    }
    
    public func defaulting(to defaultValue: @autoclosure @escaping () -> Value) -> Storage<Key, Value> {
        return fallback(with: { _ in defaultValue() })
    }
    
}

extension StorageProtocol {
    
    public func singleKey(_ key: Key) -> Storage<Void, Value> {
        return mapKeys({ key })
    }
    
}

extension ReadableStorageProtocol where Key == Void {
    
    public func retrieve(completion: @escaping (Result<Value>) -> ()) {
        retrieve(forKey: (), completion: completion)
    }
    
}

extension WritableStorageProtocol where Key == Void {
    
    public func set(_ value: Value, completion: @escaping (Result<Void>) -> () = { _ in }) {
        set(value, forKey: (), completion: completion)
    }
    
}

extension StorageProtocol where Key == Void {
    
    public func update(_ modify: @escaping (inout Value) -> (), completion: @escaping (Result<Value>) -> () = {_ in }) {
        self.update(forKey: (), modify, completion: completion)
    }
    
}
