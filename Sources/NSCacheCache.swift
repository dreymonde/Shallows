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
