public protocol WritableCacheProtocol : CacheDesign {
    
    associatedtype Key
    associatedtype Value
    
    func set(_ value: Value, forKey key: Key, completion: @escaping (Result<Void>) -> ())
    
}
