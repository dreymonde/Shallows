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
                retrieve: @escaping (Key) -> (ShallowsFuture<Value>),
                set: @escaping (Value, Key) -> (ShallowsFuture<Void>)) {
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
    
    public func retrieve(forKey key: Key) -> ShallowsFuture<Value> {
        return _retrieve.retrieve(forKey: key)
    }
    
    @discardableResult
    public func set(_ value: Value, forKey key: Key) -> ShallowsFuture<Void> {
        return _set.set(value, forKey: key)
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
    
    @discardableResult
    public func update(forKey key: Key,
                       _ modify: @escaping (inout Value) -> ()) -> ShallowsFuture<Value> {
        return retrieve(forKey: key)
            .flatMap({ (value) -> ShallowsFuture<Value> in
                var value = value
                modify(&value)
                return self.set(value, forKey: key).map({ value })
            })
    }
    
    public func update(forKey key: Key,
                       _ modify: @escaping (inout Value) -> (),
                       completion: @escaping (ShallowsResult<Value>) -> Void) {
        self.update(forKey: key, modify).on(success: { (value) in
            completion(.success(value))
        }, failure: { (error) in
            completion(.failure(error))
        })
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
    
    public func retrieve() -> ShallowsFuture<Value> {
        return retrieve(forKey: ())
    }
    
}

extension WritableStorageProtocol where Key == Void {
    
    @discardableResult
    public func set(_ value: Value) -> ShallowsFuture<Void> {
        return set(value, forKey: ())
    }
    
}

extension StorageProtocol where Key == Void {
    
    @discardableResult
    public func update(_ modify: @escaping (inout Value) -> ()) -> ShallowsFuture<Value> {
        return self.update(forKey: (), modify)
    }
    
    public func update(_ modify: @escaping (inout Value) -> (), completion: @escaping (ShallowsResult<Value>) -> Void) {
        self.update(forKey: (), modify, completion: completion)
    }
    
}
