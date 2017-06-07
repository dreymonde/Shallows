public protocol CacheDesign {
    
    var cacheName: String { get }
    
}

extension CacheDesign {
    
    @available(*, deprecated, renamed: "cacheName")
    public var name: String {
        return cacheName
    }
    
    public var cacheName: String {
        return String(describing: Self.self)
    }
    
}

public protocol CacheProtocol : ReadableCacheProtocol, WritableCacheProtocol { }

public struct Cache<Key, Value> : CacheProtocol {
    
    public let cacheName: String
    
    private let _retrieve: (Key, @escaping (Result<Value>) -> ()) -> ()
    private let _set: (Value, Key, @escaping (Result<Void>) -> ()) -> ()
    
    public init(cacheName: String,
                retrieve: @escaping (Key, @escaping (Result<Value>) -> ()) -> (),
                set: @escaping (Value, Key, @escaping (Result<Void>) -> ()) -> ()) {
        self._retrieve = retrieve
        self._set = set
        self.cacheName = cacheName
    }
    
    public init<CacheType : CacheProtocol>(_ cache: CacheType) where CacheType.Key == Key, CacheType.Value == Value {
        self._retrieve = cache.retrieve
        self._set = cache.set
        self.cacheName = cache.cacheName
    }
    
    public func retrieve(forKey key: Key, completion: @escaping (Result<Value>) -> ()) {
        _retrieve(key, completion)
    }
    
    public func set(_ value: Value, forKey key: Key, completion: @escaping (Result<Void>) -> () = { _ in }) {
        _set(value, key, completion)
    }
    
}

internal func cacheConnectionSignFromOptions(pullingFromBack: Bool, pushingToBack: Bool) -> String {
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

extension CacheProtocol {
    
    public var dev: Cache<Key, Value>.Dev {
        return Cache<Key, Value>.Dev(self.asCache())
    }
    
}

extension Cache {
    
    public struct Dev {
        
        fileprivate let frontCache: Cache
        
        fileprivate init(_ cache: Cache) {
            self.frontCache = cache
        }
        
        public func set<CacheType : WritableCacheProtocol>(_ value: Value,
                        forKey key: Key,
                        pushingTo backCache: CacheType,
                        completion: @escaping (Result<Void>) -> ()) where CacheType.Key == Key, CacheType.Value == Value {
            frontCache.set(value, forKey: key, pushingTo: backCache, completion: completion)
        }
        
        public func retrieve<CacheType : ReadableCacheProtocol>(forKey key: Key,
                             backedBy backCache: CacheType,
                             shouldPullFromBack: Bool,
                             completion: @escaping (Result<Value>) -> ()) where CacheType.Key == Key, CacheType.Value == Value{
            frontCache.retrieve(forKey: key, backedBy: backCache, shouldPullFromBack: shouldPullFromBack, completion: completion)
        }
        
        public func set<CacheType : CacheProtocol>(_ value: Value,
                        forKey key: Key,
                        pushingTo cache: CacheType,
                        strategy: CacheCombinationSetStrategy,
                        completion: @escaping (Result<Void>) -> ()) where CacheType.Key == Key, CacheType.Value == Value{
            frontCache.set(value, forKey: key, pushingTo: cache, strategy: strategy, completion: completion)
        }
        
    }
    
}

public enum CacheCombinationPullStrategy {
    case pullFromBack
    case neverPull
}

public enum CacheCombinationSetStrategy {
    case backFirst
    case frontFirst
    case frontOnly
    case backOnly
}

extension WritableCacheProtocol {
    
    fileprivate func set<CacheType : WritableCacheProtocol>(_ value: Value,
                         forKey key: Key,
                         pushingTo cache: CacheType,
                         completion: @escaping (Result<Void>) -> ()) where CacheType.Key == Key, CacheType.Value == Value {
        self.set(value, forKey: key, completion: { (result) in
            if result.isFailure {
                shallows_print("Failed setting \(key) to \(self.cacheName). Aborting")
                completion(result)
            } else {
                shallows_print("Succesfull set of \(key). Pushing to \(cache.cacheName)")
                cache.set(value, forKey: key, completion: completion)
            }
        })
    }
    
}

extension CacheProtocol {
    
    public func asCache() -> Cache<Key, Value> {
        return Cache(self)
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
    
    fileprivate func set<CacheType : CacheProtocol>(_ value: Value,
                         forKey key: Key,
                         pushingTo cache: CacheType,
                         strategy: CacheCombinationSetStrategy,
                         completion: @escaping (Result<Void>) -> ()) where CacheType.Key == Key, CacheType.Value == Value {
        switch strategy {
        case .frontFirst:
            self.set(value, forKey: key, pushingTo: cache, completion: completion)
        case .backFirst:
            cache.set(value, forKey: key, pushingTo: self, completion: completion)
        case .frontOnly:
            self.set(value, forKey: key, completion: completion)
        case .backOnly:
            cache.set(value, forKey: key, completion: completion)
        }
    }
    
    fileprivate func retrieve<CacheType : ReadableCacheProtocol>(forKey key: Key,
                              backedBy cache: CacheType,
                              shouldPullFromBack: Bool,
                              completion: @escaping (Result<Value>) -> ()) where CacheType.Key == Key, CacheType.Value == Value {
        self.retrieve(forKey: key, completion: { (firstResult) in
            if firstResult.isFailure {
                shallows_print("Cache (\(self.cacheName)) miss for key: \(key). Attempting to retrieve from \(cache.cacheName)")
                cache.retrieve(forKey: key, completion: { (secondResult) in
                    if case .success(let value) = secondResult {
                        if shouldPullFromBack {
                            shallows_print("Success retrieving \(key) from \(cache.cacheName). Setting value back to \(self.cacheName)")
                            self.set(value, forKey: key, completion: { _ in completion(secondResult) })
                        } else {
                            shallows_print("Success retrieving \(key) from \(cache.cacheName). Not pulling.")
                            completion(secondResult)
                        }
                    } else {
                        shallows_print("Cache miss for final destination (\(cache.cacheName)). Completing with failure result")
                        completion(secondResult)
                    }
                })
            } else {
                completion(firstResult)
            }
        })
    }
    
    @available(*, deprecated, message: "Use combined(with:retrieveStrategy:setStrategy:) instead")
    public func combined<CacheType : CacheProtocol>(with cache: CacheType,
                         pullingFromBack: Bool,
                         pushingToBack: Bool) -> Cache<Key, Value> where CacheType.Key == Key, CacheType.Value == Value {
        return self.combined(with: cache, pullStrategy: pullingFromBack ? .pullFromBack : .neverPull, setStrategy: pushingToBack ? .frontFirst : .frontOnly)
    }
    
    public func combined<CacheType : CacheProtocol>(with cache: CacheType,
                         pullStrategy: CacheCombinationPullStrategy = .pullFromBack,
                         setStrategy: CacheCombinationSetStrategy = .frontFirst) -> Cache<Key, Value> where CacheType.Key == Key, CacheType.Value == Value {
        return Cache<Key, Value>(cacheName: "(\(self.cacheName))\(cacheConnectionSignFromOptions(pullingFromBack: pullStrategy == .pullFromBack, pushingToBack: setStrategy != .frontOnly))(\(cache.cacheName))", retrieve: { (key, completion) in
            self.retrieve(forKey: key, backedBy: cache, shouldPullFromBack: pullStrategy == .pullFromBack, completion: completion)
        }, set: { (value, key, completion) in
            self.set(value, forKey: key, pushingTo: cache, strategy: setStrategy, completion: completion)
        })
    }
    
    public func backed<ReadableCacheType : ReadableCacheProtocol>(by cache: ReadableCacheType,
                       pullingFromBack: Bool = true) -> Cache<Key, Value> where ReadableCacheType.Key == Key, ReadableCacheType.Value == Value {
        return Cache<Key, Value>(cacheName: "\(self.cacheName)+\(cache.cacheName)", retrieve: { (key, completion) in
            self.retrieve(forKey: key, backedBy: cache, shouldPullFromBack: pullingFromBack, completion: completion)
        }, set: { value, key, completion in
            self.set(value, forKey: key, completion: completion)
        })
    }
    
}

extension CacheProtocol {
    
    public func mapKeys<OtherKey>(_ transform: @escaping (OtherKey) throws -> Key) -> Cache<OtherKey, Value> {
        return Cache<OtherKey, Value>(cacheName: cacheName, retrieve: { key, completion in
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
        return Cache<Key, OtherValue>(cacheName: cacheName, retrieve: { (key, completion) in
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

extension CacheProtocol {
    
    public func mapValues<OtherValue : RawRepresentable>() -> Cache<Key, OtherValue> where OtherValue.RawValue == Value {
        return mapValues(transformIn: throwing(OtherValue.init(rawValue:)),
                         transformOut: { $0.rawValue })
    }
    
    public func mapKeys<OtherKey : RawRepresentable>() -> Cache<OtherKey, Value> where OtherKey.RawValue == Key {
        return mapKeys({ $0.rawValue })
    }
    
}

extension CacheProtocol {
    
    public func fallback(with produceValue: @escaping (Error) throws -> Value) -> Cache<Key, Value> {
        return Cache(cacheName: self.cacheName, retrieve: { (key, completion) in
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
    
    public func defaulting(to defaultValue: @autoclosure @escaping () -> Value) -> Cache<Key, Value> {
        return fallback(with: { _ in defaultValue() })
    }
    
}

extension ReadOnlyCache {
    
    public func fallback(with produceValue: @escaping (Error) throws -> Value) -> ReadOnlyCache<Key, Value> {
        return ReadOnlyCache(cacheName: self.cacheName, retrieve: { (key, completion) in
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
    
    public func defaulting(to defaultValue: @autoclosure @escaping () -> Value) -> ReadOnlyCache<Key, Value> {
        return fallback(with: { _ in defaultValue() })
    }
    
}

extension CacheProtocol {
    
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

extension CacheProtocol where Key == Void {
    
    public func update(_ modify: @escaping (inout Value) -> (), completion: @escaping (Result<Value>) -> () = {_ in }) {
        self.update(forKey: (), modify, completion: completion)
    }
    
}
