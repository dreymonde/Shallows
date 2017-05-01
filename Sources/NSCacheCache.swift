import Foundation

public final class NSCacheCache<Key : NSObject, Value : AnyObject> : CacheProtocol {
    
    public enum Error : Swift.Error {
        case noValue(Key)
    }
    
    public let cache: NSCache<Key, Value>
    public let name: String
    
    public init(cache: NSCache<Key, Value> = NSCache(), name: String = "\(NSCache<Key, Value>.self)") {
        self.cache = cache
        self.name = name
    }
    
    public func set(_ value: Value, forKey key: Key, completion: @escaping (Result<Void>) -> ()) {
        cache.setObject(value, forKey: key)
        completion(.success())
    }
    
    public func retrieve(forKey key: Key, completion: @escaping (Result<Value>) -> ()) {
        if let object = cache.object(forKey: key) {
            completion(.success(object))
        } else {
            completion(.failure(Error.noValue(key)))
        }
    }
    
}

extension CacheProtocol where Key == NSString {
    
    public func toNonObjCKeys() -> Cache<String, Value> {
        return mapKeys({ $0 as NSString })
    }
    
}

extension CacheProtocol where Value == NSString {
    
    public func toNonObjCValues() -> Cache<Key, String> {
        return mapValues(transformIn: { $0 as String },
                         transformOut: { $0 as NSString })
    }
    
}

extension CacheProtocol where Key == NSURL {
    
    public func toNonObjCKeys() -> Cache<URL, Value> {
        return mapKeys({ $0 as NSURL })
    }
    
}

extension CacheProtocol where Value == NSURL {
    
    public func toNonObjCValues() -> Cache<Key, URL> {
        return mapValues(transformIn: { $0 as URL },
                         transformOut: { $0 as NSURL })
    }
    
}

extension CacheProtocol where Key == NSIndexPath {
    
    public func toNonObjCKeys() -> Cache<IndexPath, Value> {
        return mapKeys({ $0 as NSIndexPath })
    }
    
}

extension CacheProtocol where Value == NSIndexPath {
    
    public func toNonObjCValues() -> Cache<Key, IndexPath> {
        return mapValues(transformIn: { $0 as IndexPath },
                         transformOut: { $0 as NSIndexPath })
    }
    
}

