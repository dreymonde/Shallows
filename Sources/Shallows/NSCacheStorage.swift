import Foundation

public final class NSCacheStorage<Key : NSObject, Value : AnyObject> : StorageProtocol {
    
    public enum Error : Swift.Error {
        case noValue(Key)
    }
    
    public let cache: NSCache<Key, Value>
    public let storageName: String = "nscache"
    
    public init(storage: NSCache<Key, Value> = NSCache()) {
        self.cache = storage
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

extension StorageProtocol where Key == NSString {
    
    public func toNonObjCKeys() -> Storage<String, Value> {
        return mapKeys({ $0 as NSString })
    }
    
}

extension StorageProtocol where Value == NSString {
    
    public func toNonObjCValues() -> Storage<Key, String> {
        return mapValues(transformIn: { $0 as String },
                         transformOut: { $0 as NSString })
    }
    
}

extension ReadOnlyStorageProtocol where Key == NSString {
    
    public func toNonObjCKeys() -> ReadOnlyStorage<String, Value> {
        return mapKeys({ $0 as NSString })
    }
    
}

extension ReadOnlyStorageProtocol where Value == NSString {
    
    public func toNonObjCValues() -> ReadOnlyStorage<Key, String> {
        return mapValues({ $0 as String })
    }
    
}

extension WriteOnlyStorageProtocol where Key == NSString {
    
    public func toNonObjCKeys() -> WriteOnlyStorage<String, Value> {
        return mapKeys({ $0 as NSString })
    }
    
}

extension WriteOnlyStorageProtocol where Value == NSString {
    
    public func toNonObjCValues() -> WriteOnlyStorage<Key, String> {
        return mapValues({ $0 as NSString })
    }
    
}

// TODO: Other WriteOnlyStorage extensions

extension StorageProtocol where Key == NSURL {
    
    public func toNonObjCKeys() -> Storage<URL, Value> {
        return mapKeys({ $0 as NSURL })
    }
    
}

extension StorageProtocol where Value == NSURL {
    
    public func toNonObjCValues() -> Storage<Key, URL> {
        return mapValues(transformIn: { $0 as URL },
                         transformOut: { $0 as NSURL })
    }
    
}

extension ReadOnlyStorageProtocol where Key == NSURL {
    
    public func toNonObjCKeys() -> ReadOnlyStorage<URL, Value> {
        return mapKeys({ $0 as NSURL })
    }
    
}

extension ReadOnlyStorageProtocol where Value == NSURL {
    
    public func toNonObjCValues() -> ReadOnlyStorage<Key, URL> {
        return mapValues({ $0 as URL })
    }
    
}

extension StorageProtocol where Key == NSIndexPath {
    
    public func toNonObjCKeys() -> Storage<IndexPath, Value> {
        return mapKeys({ $0 as NSIndexPath })
    }
    
}

extension StorageProtocol where Value == NSIndexPath {
    
    public func toNonObjCValues() -> Storage<Key, IndexPath> {
        return mapValues(transformIn: { $0 as IndexPath },
                         transformOut: { $0 as NSIndexPath })
    }
    
}

extension ReadOnlyStorageProtocol where Key == NSIndexPath {
    
    public func toNonObjCKeys() -> ReadOnlyStorage<IndexPath, Value> {
        return mapKeys({ $0 as NSIndexPath })
    }
    
}

extension ReadOnlyStorageProtocol where Value == NSIndexPath {
    
    public func toNonObjCValues() -> ReadOnlyStorage<Key, IndexPath> {
        return mapValues({ $0 as IndexPath })
    }
    
}

extension StorageProtocol where Value == NSData {
    
    public func toNonObjCValues() -> Storage<Key, Data> {
        return mapValues(transformIn: { $0 as Data },
                         transformOut: { $0 as NSData })
    }
    
}

extension ReadOnlyStorageProtocol where Value == NSData {
    
    public func toNonObjCValues() -> ReadOnlyStorage<Key, Data> {
        return mapValues({ $0 as Data })
    }
    
}

extension StorageProtocol where Value == NSDate {
    
    public func toNonObjCValues() -> Storage<Key, Date> {
        return mapValues(transformIn: { $0 as Date },
                         transformOut: { $0 as NSDate })
    }
    
}

extension ReadOnlyStorageProtocol where Value == NSDate {
    
    public func toNonObjCValues() -> ReadOnlyStorage<Key, Date> {
        return mapValues({ $0 as Date })
    }
    
}
