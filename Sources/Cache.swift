public protocol CacheDesign {
    
    var cacheName: String { get }
    
}

extension CacheDesign {
    
    public var cacheName: String {
        return String(describing: Self.self)
    }
    
}

public protocol CacheProtocol : ReadableCacheProtocol, WritableCacheProtocol { }

public struct Cache<Key, Value> : CacheProtocol {
    
    public let cacheName: String
    
    private let _retrieve: (Key, @escaping (Result<Value>) -> ()) -> ()
    private let _set: (Value, Key, @escaping (Result<Void>) -> ()) -> ()
    
    public init(cacheName: String/* = "Unnamed cache \(Key.self) : \(Value.self)"*/,
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
    
    public func update(forKey key: Key,
                       _ modify: @escaping (inout Value) -> (),
                       creatingIfFail: @escaping (Error) throws -> Value,
                       completion: @escaping (Result<Value>) -> () = { _ in }) {
        retrieve(forKey: key) { (result) in
            do {
                var finalValue: Value = try {
                    switch result {
                    case .success(let value):
                        return value
                    case .failure(let error):
                        return try creatingIfFail(error)
                    }
                }()
                modify(&finalValue)
                self.set(finalValue, forKey: key, completion: { (setResult) in
                    switch setResult {
                    case .success:
                        completion(.success(finalValue))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                })
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    internal func set<CacheType : WritableCacheProtocol>(_ value: Value,
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
    
    internal func retrieve<CacheType : ReadableCacheProtocol>(forKey key: Key,
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
    
    public func combined<CacheType : CacheProtocol>(with cache: CacheType,
                         pullingFromBack: Bool = true,
                         pushingToBack: Bool = true) -> Cache<Key, Value> where CacheType.Key == Key, CacheType.Value == Value {
        return Cache<Key, Value>(cacheName: "(\(self.cacheName))\(cacheConnectionSignFromOptions(pullingFromBack: pullingFromBack, pushingToBack: pushingToBack))(\(cache.cacheName))", retrieve: { (key, completion) in
            self.retrieve(forKey: key, backedBy: cache, shouldPullFromBack: pullingFromBack, completion: completion)
        }, set: { (value, key, completion) in
            if pushingToBack {
                self.set(value, forKey: key, pushingTo: cache, completion: completion)
            } else {
                self.set(value, forKey: key, completion: completion)
            }
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
