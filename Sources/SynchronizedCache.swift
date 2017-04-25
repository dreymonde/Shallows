import Dispatch

internal func dispatched<In>(to queue: DispatchQueue, _ function: @escaping (In) -> ()) -> (In) -> () {
    return { input in
        queue.async(execute: { function(input) })
    }
}

extension CacheProtocol {
    
    public func synchronizedCalls(on queue: DispatchQueue = DispatchQueue(label: "\(Self.self)-cache-thread-safety-queue")) -> Cache<Key, Value> {
        return Cache<Key, Value>(name: self.name,
                                 retrieve: dispatched(to: queue, self.retrieve(forKey:completion:)),
                                 set: dispatched(to: queue, self.set(_:forKey:completion:)))
    }
    
}
