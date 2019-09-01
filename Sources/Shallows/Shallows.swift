//
//  Shallows.swift
//  Shallows
//
//  Created by Oleg Dreyman on {TODAY}.
//  Copyright © 2017 Shallows. All rights reserved.
//

@_exported import Future

public enum EmptyCacheError : Error, Equatable {
    case cacheIsAlwaysEmpty
}

extension StorageProtocol {
    
    public func renaming(to newName: String) -> Storage<Key, Value> {
        return Storage<Key, Value>(storageName: newName, retrieve: self.retrieve, set: self.set)
    }
    
}

extension ReadOnlyStorageProtocol {
    
    public func renaming(to newName: String) -> ReadOnlyStorage<Key, Value> {
        return ReadOnlyStorage<Key, Value>(storageName: newName, retrieve: self.retrieve)
    }
    
}

extension WriteOnlyStorageProtocol {
    
    public func renaming(to newName: String) -> WriteOnlyStorage<Key, Value> {
        return WriteOnlyStorage<Key, Value>(storageName: newName, set: self.set)
    }
    
}

extension Storage {
 
    public static func empty() -> Storage<Key, Value> {
        return Storage(storageName: "empty", retrieve: { (_) in
            return Future(error: EmptyCacheError.cacheIsAlwaysEmpty)
        }, set: { (_, _) in
            return Future(error: EmptyCacheError.cacheIsAlwaysEmpty)
        })
    }
    
}

extension ReadOnlyStorage {
    
    public static func empty() -> ReadOnlyStorage<Key, Value> {
        return ReadOnlyStorage(storageName: "empty", retrieve: { (_) in
            return Future(error: EmptyCacheError.cacheIsAlwaysEmpty)
        })
    }
    
}

extension WriteOnlyStorage {
    
    public static func empty() -> WriteOnlyStorage<Key, Value> {
        return WriteOnlyStorage(storageName: "empty", set: { (_, _) in
            return Future(error: EmptyCacheError.cacheIsAlwaysEmpty)
        })
    }
    
}

public func throwing<In, Out>(_ block: @escaping (In) -> Out?) -> (In) throws -> Out {
    return { input in
        try block(input).unwrap()
    }
}

internal func shallows_print(_ item: Any) {
    if ShallowsLog.isEnabled {
        print(item)
    }
}

public enum ShallowsLog {
    public static var isEnabled = false
}

public typealias ShallowsFuture<Value> = Future<Value, Swift.Error>
public typealias ShallowsPromise<Value> = Promise<Value, Swift.Error>
