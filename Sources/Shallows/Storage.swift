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
                read: ReadOnlyStorage<Key, Value>,
                write: WriteOnlyStorage<Key, Value>) {
        self.storageName = storageName
        self._retrieve = read.renaming(to: storageName)
        self._set = write.renaming(to: storageName)
    }
    
    public init(storageName: String,
                retrieve: @escaping (Key, @escaping (ShallowsResult<Value>) -> ()) -> (),
                set: @escaping (Value, Key, @escaping (ShallowsResult<Void>) -> ()) -> ()) {
        self.storageName = storageName
        self._retrieve = ReadOnlyStorage(storageName: storageName, retrieve: retrieve)
        self._set = WriteOnlyStorage(storageName: storageName, set: set)
    }
    
    public init<StorageType : StorageProtocol>(_ storage: StorageType) where StorageType.Key == Key, StorageType.Value == Value {
        self.storageName = storage.storageName
        self._retrieve = storage.asReadOnlyStorage()
        self._set = storage.asWriteOnlyStorage()
    }
    
    public init(read: ReadOnlyStorage<Key, Value>,
                write: WriteOnlyStorage<Key, Value>) {
        self.init(storageName: read.storageName,
                  read: read,
                  write: write)
    }
    
    public func retrieve(forKey key: Key, completion: @escaping (ShallowsResult<Value>) -> ()) {
        _retrieve.retrieve(forKey: key, completion: completion)
    }
    
    public func set(_ value: Value, forKey key: Key, completion: @escaping (ShallowsResult<Void>) -> ()) {
        _set.set(value, forKey: key, completion: completion)
    }

    @available(swift, deprecated: 5.5, message: "use async version or provide completion handler explicitly")
    public func set(_ value: Value, forKey key: Key) {
        _set.set(value, forKey: key, completion: { _ in })
    }
    
    public func asReadOnlyStorage() -> ReadOnlyStorage<Key, Value> {
        return _retrieve
    }
    
    public func asWriteOnlyStorage() -> WriteOnlyStorage<Key, Value> {
        return _set
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
    
    public func asStorage() -> Storage<Key, Value> {
        if let alreadyNormalized = self as? Storage<Key, Value> {
            return alreadyNormalized
        }
        return Storage(self)
    }

    @available(swift, deprecated: 5.5, message: "`update` is deprecated because it was creating potentially wrong assumptions regarding the serial nature of this function. `update` cannot guarantee that no concurrent calls to `retrieve` or `set` from other places will be made during the update")
    public func update(forKey key: Key,
                       _ modify: @escaping (inout Value) -> (),
                       completion: @escaping (ShallowsResult<Value>) -> () = { _ in }) {
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
    
    public func mapKeys<OtherKey>(to type: OtherKey.Type = OtherKey.self,
                                  _ transform: @escaping (OtherKey) throws -> Key) -> Storage<OtherKey, Value> {
        return Storage(read: asReadOnlyStorage().mapKeys(transform),
                       write: asWriteOnlyStorage().mapKeys(transform))
    }
    
    public func mapValues<OtherValue>(to type: OtherValue.Type = OtherValue.self,
                                      transformIn: @escaping (Value) throws -> OtherValue,
                                      transformOut: @escaping (OtherValue) throws -> Value) -> Storage<Key, OtherValue> {
        return Storage(read: asReadOnlyStorage().mapValues(transformIn),
                       write: asWriteOnlyStorage().mapValues(transformOut))
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
        return Storage(read: readOnly, write: asWriteOnlyStorage())
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
    
    public func retrieve(completion: @escaping (ShallowsResult<Value>) -> ()) {
        retrieve(forKey: (), completion: completion)
    }
    
}

extension WritableStorageProtocol where Key == Void {
    
    public func set(_ value: Value, completion: @escaping (ShallowsResult<Void>) -> ()) {
        set(value, forKey: (), completion: completion)
    }

    @available(swift, deprecated: 5.5, message: "use async version or provide completion handler explicitly")
    public func set(_ value: Value) {
        set(value, completion: { _ in })
    }
}

extension StorageProtocol where Key == Void {

    @available(swift, deprecated: 5.5, message: "`update` is deprecated because it was creating potentially wrong assumptions regarding the serial nature of this function. `update` cannot guarantee that no concurrent calls to `retrieve` or `set` from other places will be made during the update")
    public func update(_ modify: @escaping (inout Value) -> (), completion: @escaping (ShallowsResult<Value>) -> () = {_ in }) {
        self.update(forKey: (), modify, completion: completion)
    }
    
}
