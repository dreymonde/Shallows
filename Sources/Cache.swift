public protocol CacheDesign {
    
    var name: String { get }
    
}

public protocol CacheProtocol : ReadableCacheProtocol, WritableCacheProtocol { }

public struct Cache<Key, Value> : CacheProtocol {
    
    public let name: String
    
    private let _retrieve: (Key, @escaping (Result<Value>) -> ()) -> ()
    private let _set: (Value, Key, @escaping (Result<Void>) -> ()) -> ()
    
    public init(name: String/* = "Unnamed cache \(Key.self) : \(Value.self)"*/,
        retrieve: @escaping (Key, @escaping (Result<Value>) -> ()) -> (),
        set: @escaping (Value, Key, @escaping (Result<Void>) -> ()) -> ()) {
        self._retrieve = retrieve
        self._set = set
        self.name = name
    }
    
    public init<CacheType : CacheProtocol>(_ cache: CacheType) where CacheType.Key == Key, CacheType.Value == Value {
        self._retrieve = cache.retrieve
        self._set = cache.set
        self.name = cache.name
    }
    
    public func retrieve(forKey key: Key, completion: @escaping (Result<Value>) -> ()) {
        _retrieve(key, completion)
    }
    
    public func set(_ value: Value, forKey key: Key, completion: @escaping (Result<Void>) -> () = { _ in }) {
        _set(value, key, completion)
    }
    
}

public struct CachePullFromBackStrategy<Value> {
    
    private let _shouldPull: (Value) -> Bool
    
    init(shouldPull: @escaping (Value) -> Bool) {
        self._shouldPull = shouldPull
    }
    
    public func shouldPull(_ value: Value) -> Bool {
        return _shouldPull(value)
    }
    
    public static var always: CachePullFromBackStrategy<Value> {
        return CachePullFromBackStrategy { _ in true }
    }
    
    public static var never: CachePullFromBackStrategy<Value> {
        return CachePullFromBackStrategy { _ in false }
    }
    
}

public struct CachePushToBackStrategy<Value> {
    
    private let _shouldPush: (Value) -> Bool
    
    init(shouldPush: @escaping (Value) -> Bool) {
        self._shouldPush = shouldPush
    }
    
    public func shouldPush(_ value: Value) -> Bool {
        return _shouldPush(value)
    }
    
    public static var always: CachePushToBackStrategy<Value> {
        return CachePushToBackStrategy { _ in true }
    }
    
    public static var never: CachePushToBackStrategy<Value> {
        return CachePushToBackStrategy { _ in false }
    }
    
}

extension CacheProtocol {
    
    public func makeCache() -> Cache<Key, Value> {
        return Cache(self)
    }
    
    public func update(forKey key: Key, _ modify: @escaping (inout Value) -> (), completion: @escaping (Result<Value>) -> () = {_ in }) {
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
    
    internal func set<CacheType : WritableCacheProtocol>(_ value: Value,
                      forKey key: Key,
                      pushingTo cache: CacheType,
                      shouldPush strategy: CachePushToBackStrategy<Value>,
                      completion: @escaping (Result<Void>) -> ()) where CacheType.Key == Key, CacheType.Value == Value {
        self.set(value, forKey: key, completion: { (result) in
            if result.isFailure {
                shallows_print("Failed setting \(key) to \(self.name). Aborting")
                completion(result)
            } else {
                if strategy.shouldPush(value) {
                    shallows_print("Succesfull set of \(key). Pushing to \(cache.name)")
                    cache.set(value, forKey: key, completion: completion)
                }
            }
        })
    }
    
    internal func retrieve<CacheType : ReadableCacheProtocol>(forKey key: Key,
                           backedBy cache: CacheType,
                           pullFromBack strategy: CachePullFromBackStrategy<Value>,
                           completion: @escaping (Result<Value>) -> ()) where CacheType.Key == Key, CacheType.Value == Value {
        self.retrieve(forKey: key, completion: { (firstResult) in
            if firstResult.isFailure {
                shallows_print("Cache (\(self.name)) miss for key: \(key). Attempting to retrieve from \(cache.name)")
                cache.retrieve(forKey: key, completion: { (secondResult) in
                    if case .success(let value) = secondResult, strategy.shouldPull(value) {
                        shallows_print("Success retrieving \(key) from \(cache.name). Setting value back to \(self.name)")
                        self.set(value, forKey: key, completion: { _ in completion(secondResult) })
                    } else {
                        shallows_print("Cache miss for final destination (\(cache.name)). Completing with failure result")
                        completion(secondResult)
                    }
                })
            } else {
                completion(firstResult)
            }
        })
    }
    
    public func combinedSetBoth<CacheType : CacheProtocol>(with cache: CacheType) -> Cache<Key, Value> where CacheType.Key == Key, CacheType.Value == Value {
        return combined(with: cache, pullFromBack: .always, pushToBack: .always)
    }
    
    public func combinedSetFront<CacheType : ReadableCacheProtocol>(with cache: CacheType) -> Cache<Key, Value> where CacheType.Key == Key, CacheType.Value == Value {
        return Cache<Key, Value>(name: "\(self.name) <- \(cache.name)", retrieve: { (key, completion) in
            self.retrieve(forKey: key, backedBy: cache, pullFromBack: .always, completion: completion)
        }, set: { (value, key, completion) in
            self.set(value, forKey: key, completion: completion)
        })
    }
    
    public func combinedSetBack<CacheType : CacheProtocol>(with cache: CacheType) -> Cache<Key, Value> where CacheType.Key == Key, CacheType.Value == Value {
        return Cache<Key, Value>(name: "\(self.name) -> \(cache.name)", retrieve: { (key, completion) in
            self.retrieve(forKey: key, backedBy: cache, pullFromBack: .never, completion: completion)
        }, set: { (value, key, completion) in
            self.set(value, forKey: key, pushingTo: cache, shouldPush: .always, completion: completion)
        })
    }
    
    public func combined<CacheType : CacheProtocol>(with cache: CacheType,
                         pullFromBack pullStrategy: CachePullFromBackStrategy<Value> = .always,
                         pushToBack pushStrategy: CachePushToBackStrategy<Value> = .always) -> Cache<Key, Value> where CacheType.Key == Key, CacheType.Value == Value {
        return Cache<Key, Value>(name: "\(self.name)+\(cache.name)", retrieve: { (key, completion) in
            self.retrieve(forKey: key, backedBy: cache, pullFromBack: pullStrategy, completion: completion)
        }, set: { (value, key, completion) in
            self.set(value, forKey: key, pushingTo: cache, shouldPush: pushStrategy, completion: completion)
        })
    }
    
    public func combined<ReadableCacheType : ReadableCacheProtocol>(with cache: ReadableCacheType,
                         pullFromBack pullStrategy: CachePullFromBackStrategy<Value> = .always) -> Cache<Key, Value> where ReadableCacheType.Key == Key, ReadableCacheType.Value == Value {
        return Cache<Key, Value>(name: "\(self.name)+\(cache.name)", retrieve: { (key, completion) in
            self.retrieve(forKey: key, backedBy: cache, pullFromBack: pullStrategy, completion: completion)
        }, set: { (value, key, completion) in
            self.set(value, forKey: key, completion: completion)
        })
    }
    
}

extension Cache {
    
    public func mapKeys<OtherKey>(_ transform: @escaping (OtherKey) throws -> Key) -> Cache<OtherKey, Value> {
        return Cache<OtherKey, Value>(name: name, retrieve: { key, completion in
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
                          transformOut: @escaping (OtherValue) throws -> Value) -> Cache<Key, OtherValue> {
        return Cache<Key, OtherValue>(name: name, retrieve: { (key, completion) in
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

extension Cache {
    
    public func mapValues<OtherValue : RawRepresentable>() -> Cache<Key, OtherValue> where OtherValue.RawValue == Value {
        return mapValues(transformIn: throwing(OtherValue.init(rawValue:)),
                         transformOut: { $0.rawValue })
    }
    
    public func mapKeys<OtherKey : RawRepresentable>() -> Cache<OtherKey, Value> where OtherKey.RawValue == Key {
        return mapKeys({ $0.rawValue })
    }
    
}

extension Cache {
    
    public func singleKey(_ key: Key) -> Cache<Void, Value> {
        return mapKeys({ key })
    }
    
}

extension ReadableCacheProtocol where Key == Void {
    
    public func retrieve(completion: @escaping (Result<Value>) -> ()) {
        retrieve(forKey: (), completion: completion)
    }
    
}

extension WritableCacheProtocol where Key == Void {
    
    public func set(_ value: Value, completion: @escaping (Result<Void>) -> () = { _ in }) {
        set(value, forKey: (), completion: completion)
    }
    
}
