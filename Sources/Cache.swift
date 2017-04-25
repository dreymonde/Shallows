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

extension CacheProtocol {
    
    public func makeCache() -> Cache<Key, Value> {
        return Cache(self)
    }
    
    public func retrieve<CacheType : ReadableCacheProtocol>(forKey key: Key,
                                backedBy cache: CacheType,
                                pushToFront: Bool,
                                completion: @escaping (Result<Value>) -> ()) where CacheType.Key == Key, CacheType.Value == Value {
        self.retrieve(forKey: key, completion: { (firstResult) in
            if firstResult.isFailure {
                shallows_print("Cache (\(self.name)) miss for key: \(key). Attempting to retrieve from \(cache.name)")
                cache.retrieve(forKey: key, completion: { (secondResult) in
                    if !pushToFront {
                        completion(secondResult)
                        return
                    }
                    if case .success(let value) = secondResult {
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
    
    public func set<CacheType : WritableCacheProtocol>(_ value: Value, forKey key: Key, pushingTo cache: CacheType, completion: @escaping (Result<Void>) -> ()) where CacheType.Key == Key, CacheType.Value == Value {
        self.set(value, forKey: key, completion: { (result) in
            if result.isFailure {
                shallows_print("Failed setting \(key) to \(self.name). Aborting")
                completion(result)
            } else {
                shallows_print("Succesfull set of \(key). Pushing to \(cache.name)")
                cache.set(value, forKey: key, completion: completion)
            }
        })
    }
    
    public func combinedSetBoth<CacheType : CacheProtocol>(with cache: CacheType) -> Cache<Key, Value> where CacheType.Key == Key, CacheType.Value == Value {
        return Cache<Key, Value>(name: "\(self.name) <-> \(cache.name)", retrieve: { (key, completion) in
            self.retrieve(forKey: key, backedBy: cache, pushToFront: true, completion: completion)
        }, set: { (value, key, completion) in
            self.set(value, forKey: key, pushingTo: cache, completion: completion)
        })
    }
    
    public func combinedSetFront<CacheType : ReadableCacheProtocol>(with cache: CacheType) -> Cache<Key, Value> where CacheType.Key == Key, CacheType.Value == Value {
        return Cache<Key, Value>(name: "\(self.name) <- \(cache.name)", retrieve: { (key, completion) in
            self.retrieve(forKey: key, backedBy: cache, pushToFront: true, completion: completion)
        }, set: { (value, key, completion) in
            self.set(value, forKey: key, completion: completion)
        })
    }
    
    public func combinedSetBack<CacheType : CacheProtocol>(with cache: CacheType) -> Cache<Key, Value> where CacheType.Key == Key, CacheType.Value == Value {
        return Cache<Key, Value>(name: "\(self.name) -> \(cache.name)", retrieve: { (key, completion) in
            self.retrieve(forKey: key, backedBy: cache, pushToFront: false, completion: completion)
        }, set: { (value, key, completion) in
            self.set(value, forKey: key, pushingTo: cache, completion: completion)
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
