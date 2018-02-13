//
//  Shallows.swift
//  Shallows
//
//  Created by Oleg Dreyman on {TODAY}.
//  Copyright © 2017 Shallows. All rights reserved.
//

@available(*, unavailable)
public protocol ShallowsError : Swift.Error {
    
    var isTransient: Bool { get }
    
}

public enum Result<Value> {
    
    case success(Value)
    case failure(Error)
    
    public var isFailure: Bool {
        if case .failure = self {
            return true
        }
        return false
    }
    
    public var isSuccess: Bool {
        return !isFailure
    }
    
    public var value: Value? {
        if case .success(let value) = self {
            return value
        }
        return nil
    }
    
    public var error: Error? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
        
}

public func fail<Value>(with error: Error) -> Result<Value> {
    return .failure(error)
}

public func succeed<Value>(with value: Value) -> Result<Value> {
    return .success(value)
}

extension Result where Value == Void {
    
    public static var success: Result<Void> {
        return .success(())
    }
    
}

extension Optional {
    
    public struct UnwrapError : Error {
        public init() { }
    }
    
    public func unwrap() throws -> Wrapped {
        if let wrapped = self {
            return wrapped
        } else {
            throw UnwrapError()
        }
    }
    
}

public enum EmptyCacheError : Error {
    case cacheIsAlwaysEmpty
}

extension Storage {
 
    public static func empty() -> Storage<Key, Value> {
        return Storage(storageName: "empty", retrieve: { (_, completion) in
            completion(.failure(EmptyCacheError.cacheIsAlwaysEmpty))
        }, set: { (_, _, completion) in
            completion(.failure(EmptyCacheError.cacheIsAlwaysEmpty))
        })
    }
    
}

extension ReadOnlyStorage {
    
    public static func empty() -> ReadOnlyStorage<Key, Value> {
        return ReadOnlyStorage(storageName: "empty", retrieve: { (_, completion) in
            completion(.failure(EmptyCacheError.cacheIsAlwaysEmpty))
        })
    }
    
}

extension WriteOnlyStorage {
    
    public static func empty() -> WriteOnlyStorage<Key, Value> {
        return WriteOnlyStorage(storageName: "empty", set: { (_, _, completion) in
            completion(.failure(EmptyCacheError.cacheIsAlwaysEmpty))
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
