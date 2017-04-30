public protocol ReadableCacheProtocol : CacheDesign {
    
    associatedtype Key
    associatedtype Value
    
    func retrieve(forKey key: Key, completion: @escaping (Result<Value>) -> ())
    
}

public final class ReadOnlyCache<Key, Value> : ReadableCacheProtocol {
    
    public let name: String
    
    private let _retrieve: (Key, @escaping (Result<Value>) -> ()) -> ()
    
    public init(name: String/* = "Unnamed read-only cache \(Key.self) : \(Value.self)"*/, retrieve: @escaping (Key, @escaping (Result<Value>) -> ()) -> ()) {
        self._retrieve = retrieve
        self.name = name
    }
    
    public init<CacheType : ReadableCacheProtocol>(_ cache: CacheType) where CacheType.Key == Key, CacheType.Value == Value {
        self._retrieve = cache.retrieve
        self.name = cache.name
    }
    
    public func retrieve(forKey key: Key, completion: @escaping (Result<Value>) -> ()) {
        _retrieve(key, completion)
    }
    
}

extension ReadableCacheProtocol {
    
    public func makeReadOnly() -> ReadOnlyCache<Key, Value> {
        return ReadOnlyCache(self)
    }
    
    public func backed<CacheType : ReadableCacheProtocol>(by cache: CacheType) -> ReadOnlyCache<Key, Value> where CacheType.Key == Key, CacheType.Value == Value {
        return ReadOnlyCache(name: "\(self.name) - \(cache.name)", retrieve: { (key, completion) in
            self.retrieve(forKey: key, completion: { (firstResult) in
                if firstResult.isFailure {
                    shallows_print("Cache (\(self.name)) miss for key: \(key). Attempting to retrieve from \(cache.name)")
                    cache.retrieve(forKey: key, completion: completion)
                } else {
                    completion(firstResult)
                }
            })
        })
    }
    
}

extension ReadOnlyCache {
    
    public func mapKeys<OtherKey>(_ transform: @escaping (OtherKey) throws -> Key) -> ReadOnlyCache<OtherKey, Value> {
        return ReadOnlyCache<OtherKey, Value>(name: name, retrieve: { key, completion in
            do {
                let newKey = try transform(key)
                self.retrieve(forKey: newKey, completion: completion)
            } catch {
                completion(.failure(error))
            }
        })
    }
    
    public func mapValues<OtherValue>(_ transform: @escaping (Value) throws -> OtherValue) -> ReadOnlyCache<Key, OtherValue> {
        return ReadOnlyCache<Key, OtherValue>(name: name, retrieve: { (key, completion) in
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

extension ReadOnlyCache {
    
    public func mapKeys<OtherKey : RawRepresentable>() -> ReadOnlyCache<OtherKey, Value> where OtherKey.RawValue == Key {
        return mapKeys({ $0.rawValue })
    }
    
}

extension ReadOnlyCache {
    
    public func singleKey(_ key: Key) -> ReadOnlyCache<Void, Value> {
        return mapKeys({ key })
    }
    
}
