public protocol WritableCacheProtocol : CacheDesign {
    
    associatedtype Key
    associatedtype Value
    
    func set(_ value: Value, forKey key: Key, completion: @escaping (Result<Void>) -> ())
    
}

public protocol WriteOnlyCacheProtocol : WritableCacheProtocol {  }

public struct WriteOnlyCache<Key, Value> : WriteOnlyCacheProtocol {
    
    public let cacheName: String
    
    private let _set: (Value, Key, @escaping (Result<Void>) -> ()) -> ()
    
    public init(cacheName: String, set: @escaping (Value, Key, @escaping (Result<Void>) -> ()) -> ()) {
        self._set = set
        self.cacheName = cacheName
    }
    
    public init<CacheType : WritableCacheProtocol>(_ cache: CacheType) where CacheType.Key == Key, CacheType.Value == Value {
        self._set = cache.set
        self.cacheName = cache.cacheName
    }
    
    public func set(_ value: Value, forKey key: Key, completion: @escaping (Result<Void>) -> ()) {
        self._set(value, key, completion)
    }
    
}

extension WritableCacheProtocol {
    
    public func asWriteOnlyCache() -> WriteOnlyCache<Key, Value> {
        return WriteOnlyCache(self)
    }
    
}

extension WriteOnlyCacheProtocol {
    
    public func mapKeys<OtherKey>(_ transform: @escaping (OtherKey) throws -> Key) -> WriteOnlyCache<OtherKey, Value> {
        return WriteOnlyCache<OtherKey, Value>(cacheName: cacheName, set: { (value, key, completion) in
            do {
                let newKey = try transform(key)
                self.set(value, forKey: newKey, completion: completion)
            } catch {
                completion(.failure(error))
            }
        })
    }
    
    public func mapValues<OtherValue>(_ transform: @escaping (OtherValue) throws -> Value) -> WriteOnlyCache<Key, OtherValue> {
        return WriteOnlyCache<Key, OtherValue>(cacheName: cacheName, set: { (value, key, completion) in
            do {
                let newValue = try transform(value)
                self.set(newValue, forKey: key, completion: completion)
            } catch {
                completion(.failure(error))
            }
        })
    }
    
}

extension WriteOnlyCacheProtocol {
    
    public func singleKey(_ key: Key) -> WriteOnlyCache<Void, Value> {
        return mapKeys({ key })
    }
    
}
