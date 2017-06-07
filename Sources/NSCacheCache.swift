import Foundation

public final class NSCacheCache<Key : NSObject, Value : AnyObject> : CacheProtocol {
    
    public enum Error : Swift.Error {
        case noValue(Key)
    }
    
    public let cache: NSCache<Key, Value>
    public let cacheName: String
    
    public init(cache: NSCache<Key, Value> = NSCache(), cacheName: String = "\(NSCache<Key, Value>.self)") {
        self.cache = cache
        self.cacheName = cacheName
    }
    
    public func set(_ value: Value, forKey key: Key, completion: @escaping (Result<Void>) -> ()) {
        cache.setObject(value, forKey: key)
        completion(.success)
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

extension ReadOnlyCache where Key == NSString {
    
    public func toNonObjCKeys() -> ReadOnlyCache<String, Value> {
        return mapKeys({ $0 as NSString })
    }
    
}

extension ReadOnlyCache where Value == NSString {
    
    public func toNonObjCValues() -> ReadOnlyCache<Key, String> {
        return mapValues({ $0 as String })
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

extension ReadOnlyCache where Key == NSURL {
    
    public func toNonObjCKeys() -> ReadOnlyCache<URL, Value> {
        return mapKeys({ $0 as NSURL })
    }
    
}

extension ReadOnlyCache where Value == NSURL {
    
    public func toNonObjCValues() -> ReadOnlyCache<Key, URL> {
        return mapValues({ $0 as URL })
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

extension ReadOnlyCache where Key == NSIndexPath {
    
    public func toNonObjCKeys() -> ReadOnlyCache<IndexPath, Value> {
        return mapKeys({ $0 as NSIndexPath })
    }
    
}

extension ReadOnlyCache where Value == NSIndexPath {
    
    public func toNonObjCValues() -> ReadOnlyCache<Key, IndexPath> {
        return mapValues({ $0 as IndexPath })
    }
    
}

extension CacheProtocol where Value == NSData {
    
    public func toNonObjCValues() -> Cache<Key, Data> {
        return mapValues(transformIn: { $0 as Data },
                         transformOut: { $0 as NSData })
    }
    
}

extension ReadOnlyCache where Value == NSData {
    
    public func toNonObjCValues() -> ReadOnlyCache<Key, Data> {
        return mapValues({ $0 as Data })
    }
    
}

extension CacheProtocol where Value == NSDate {
    
    public func toNonObjCValues() -> Cache<Key, Date> {
        return mapValues(transformIn: { $0 as Date },
                         transformOut: { $0 as NSDate })
    }
    
}

extension ReadOnlyCache where Value == NSDate {
    
    public func toNonObjCValues() -> ReadOnlyCache<Key, Date> {
        return mapValues({ $0 as Date })
    }
    
}

func readme() {
let nscache = NSCacheCache<NSURL, NSData>()
    .toNonObjCKeys()
    .toNonObjCValues() // Cache<URL, Data>
}

