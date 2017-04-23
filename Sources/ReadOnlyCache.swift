public protocol ReadOnlyCacheProtocol : CacheDesign {
    
    associatedtype Key
    associatedtype Value
    
    func retrieve(forKey key: Key, completion: @escaping (Result<Value>) -> ())
    
}

public final class ReadOnlyCache<Key, Value> : ReadOnlyCacheProtocol {
    
    public let name: String
    
    private let _retrieve: (Key, @escaping (Result<Value>) -> ()) -> ()
    
    public init(name: String/* = "Unnamed read-only cache \(Key.self) : \(Value.self)"*/, retrieve: @escaping (Key, @escaping (Result<Value>) -> ()) -> ()) {
        self._retrieve = retrieve
        self.name = name
    }
    
    public init<CacheType : ReadOnlyCacheProtocol>(_ cache: CacheType) where CacheType.Key == Key, CacheType.Value == Value {
        self._retrieve = cache.retrieve
        self.name = cache.name
    }
    
    public func retrieve(forKey key: Key, completion: @escaping (Result<Value>) -> ()) {
        _retrieve(key, completion)
    }
    
}

extension ReadOnlyCacheProtocol {
    
    public func makeReadOnly() -> ReadOnlyCache<Key, Value> {
        return ReadOnlyCache(self)
    }
    
    public func combined<CacheType : ReadOnlyCacheProtocol>(with cache: CacheType) -> ReadOnlyCache<Key, Value> where CacheType.Key == Key, CacheType.Value == Value {
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
