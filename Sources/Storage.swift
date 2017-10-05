public protocol StorageDesign {
    
    var storageName: String { get }
    
}

extension StorageDesign {
    
    @available(*, deprecated, renamed: "storageName")
    public var name: String {
        return storageName
    }
    
    public var storageName: String {
        return String(describing: Self.self)
    }
    
}

public protocol StorageProtocol : ReadableStorageProtocol, WritableStorageProtocol { }

public struct Storage<Key, Value> : StorageProtocol {
    
    public let storageName: String
    
    private let _retrieve: (Key, @escaping (Result<Value>) -> ()) -> ()
    private let _set: (Value, Key, @escaping (Result<Void>) -> ()) -> ()
    
    public init(storageName: String,
                retrieve: @escaping (Key, @escaping (Result<Value>) -> ()) -> (),
                set: @escaping (Value, Key, @escaping (Result<Void>) -> ()) -> ()) {
        self._retrieve = retrieve
        self._set = set
        self.storageName = storageName
    }
    
    public init<StorageType : StorageProtocol>(_ storage: StorageType) where StorageType.Key == Key, StorageType.Value == Value {
        self._retrieve = storage.retrieve
        self._set = storage.set
        self.storageName = storage.storageName
    }
    
    public func retrieve(forKey key: Key, completion: @escaping (Result<Value>) -> ()) {
        _retrieve(key, completion)
    }
    
    public func set(_ value: Value, forKey key: Key, completion: @escaping (Result<Void>) -> () = { _ in }) {
        _set(value, key, completion)
    }
    
}

internal func storageConnectionSignFromOptions(pullingFromBack: Bool, pushingToBack: Bool) -> String {
    switch (pullingFromBack, pushingToBack) {
    case (true, true):
        return "<->"
    case (true, false):
        return "<-"
    case (false, true):
        return "->"
    case (false, false):
        return "-"
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
                             strategy: StorageCombinationPullStrategy,
                             completion: @escaping (Result<Value>) -> ()) where StorageType.Key == Key, StorageType.Value == Value{
            frontStorage.retrieve(forKey: key, backedBy: backStorage, strategy: strategy, completion: completion)
        }
        
        public func set<StorageType : StorageProtocol>(_ value: Value,
                        forKey key: Key,
                        pushingTo storage: StorageType,
                        strategy: StorageCombinationSetStrategy,
                        completion: @escaping (Result<Void>) -> ()) where StorageType.Key == Key, StorageType.Value == Value{
            frontStorage.set(value, forKey: key, pushingTo: storage, strategy: strategy, completion: completion)
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
    
    fileprivate func retrieve<StorageType : ReadableStorageProtocol>(forKey key: Key,
                              backedBy storage: StorageType,
                              strategy: StorageCombinationPullStrategy,
                              completion: @escaping (Result<Value>) -> ()) where StorageType.Key == Key, StorageType.Value == Value {
        self.retrieve(forKey: key, completion: { (firstResult) in
            if firstResult.isFailure {
                shallows_print("Storage (\(self.storageName)) miss for key: \(key). Attempting to retrieve from \(storage.storageName)")
                storage.retrieve(forKey: key, completion: { (secondResult) in
                    if case .success(let value) = secondResult {
                        switch strategy {
                        case .pullThenComplete:
                            shallows_print("Success retrieving \(key) from \(storage.storageName). Setting value back to \(self.storageName)")
                            self.set(value, forKey: key, completion: { _ in completion(secondResult) })
                        case .completeThenPull:
                            shallows_print("Success retrieving \(key) from \(storage.storageName). Completing, then value back to \(self.storageName)")
                            completion(secondResult)
                            self.set(value, forKey: key, completion: { _ in })
                        case .neverPull:
                            shallows_print("Success retrieving \(key) from \(storage.storageName). Not pulling.")
                            completion(secondResult)
                        }
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
    
    @available(*, deprecated, message: "Use combined(with:retrieveStrategy:setStrategy:) instead")
    public func combined<StorageType : StorageProtocol>(with storage: StorageType,
                         pullingFromBack: Bool,
                         pushingToBack: Bool) -> Storage<Key, Value> where StorageType.Key == Key, StorageType.Value == Value {
        return self.combined(with: storage, pullStrategy: pullingFromBack ? .pullThenComplete : .neverPull, setStrategy: pushingToBack ? .frontFirst : .frontOnly)
    }
    
    public func combined<StorageType : StorageProtocol>(with storage: StorageType,
                         pullStrategy: StorageCombinationPullStrategy = .pullThenComplete,
                         setStrategy: StorageCombinationSetStrategy = .frontFirst) -> Storage<Key, Value> where StorageType.Key == Key, StorageType.Value == Value {
        return Storage<Key, Value>(storageName: "(\(self.storageName))\(storageConnectionSignFromOptions(pullingFromBack: pullStrategy != .neverPull, pushingToBack: setStrategy != .frontOnly))(\(storage.storageName))", retrieve: { (key, completion) in
            self.retrieve(forKey: key, backedBy: storage, strategy: pullStrategy, completion: completion)
        }, set: { (value, key, completion) in
            self.set(value, forKey: key, pushingTo: storage, strategy: setStrategy, completion: completion)
        })
    }
    
    public func pushing<WritableStorageType : WritableStorageProtocol>(to backStorage: WritableStorageType,
                        strategy: StorageCombinationSetStrategy = .frontFirst) -> Storage<Key, Value> where WritableStorageType.Key == Key, WritableStorageType.Value == Value {
        return Storage<Key, Value>(storageName: "\(self.storageName)>\(backStorage.storageName)", retrieve: { (key, completion) in
            self.retrieve(forKey: key, completion: completion)
        }, set: { (value, key, completion) in
            self.set(value, forKey: key, pushingTo: backStorage, strategy: strategy, completion: completion)
        })
    }
    
    public func backed<ReadableStorageType : ReadableStorageProtocol>(by storage: ReadableStorageType,
                       strategy: StorageCombinationPullStrategy = .pullThenComplete) -> Storage<Key, Value> where ReadableStorageType.Key == Key, ReadableStorageType.Value == Value {
        return Storage<Key, Value>(storageName: "\(self.storageName)+\(storage.storageName)", retrieve: { (key, completion) in
            self.retrieve(forKey: key, backedBy: storage, strategy: strategy, completion: completion)
        }, set: { value, key, completion in
            self.set(value, forKey: key, completion: completion)
        })
    }
    
}

extension StorageProtocol {
    
    public func mapKeys<OtherKey>(_ transform: @escaping (OtherKey) throws -> Key) -> Storage<OtherKey, Value> {
        return Storage<OtherKey, Value>(storageName: storageName, retrieve: { key, completion in
            do {
                let newKey = try transform(key)
                self.retrieve(forKey: newKey, completion: completion)
            } catch {
                completion(.failure(error))
            }
        }, set: { value, key, completion in
            do {
                let newKey = try transform(key)
                self.set(value, forKey: newKey, completion: completion)
            } catch {
                completion(.failure(error))
            }
        })
    }
    
    public func mapValues<OtherValue>(transformIn: @escaping (Value) throws -> OtherValue,
                          transformOut: @escaping (OtherValue) throws -> Value) -> Storage<Key, OtherValue> {
        return Storage<Key, OtherValue>(storageName: storageName, retrieve: { (key, completion) in
            self.retrieve(forKey: key, completion: { (result) in
                switch result {
                case .success(let value):
                    do {
                        let newValue = try transformIn(value)
                        completion(.success(newValue))
                    } catch {
                        completion(.failure(error))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            })
        }, set: { (value, key, completion) in
            do {
                let newValue = try transformOut(value)
                self.set(newValue, forKey: key, completion: completion)
            } catch {
                completion(.failure(error))
            }
        })
    }
    
}

extension StorageProtocol {
    
    public func mapValues<OtherValue : RawRepresentable>() -> Storage<Key, OtherValue> where OtherValue.RawValue == Value {
        return mapValues(transformIn: throwing(OtherValue.init(rawValue:)),
                         transformOut: { $0.rawValue })
    }
    
    public func mapKeys<OtherKey : RawRepresentable>() -> Storage<OtherKey, Value> where OtherKey.RawValue == Key {
        return mapKeys({ $0.rawValue })
    }
    
}

extension StorageProtocol {
    
    public func fallback(with produceValue: @escaping (Error) throws -> Value) -> Storage<Key, Value> {
        return Storage(storageName: self.storageName, retrieve: { (key, completion) in
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
        }, set: self.set)
    }
    
    public func defaulting(to defaultValue: @autoclosure @escaping () -> Value) -> Storage<Key, Value> {
        return fallback(with: { _ in defaultValue() })
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
