//
//  Shallows.swift
//  Shallows
//
//  Created by Oleg Dreyman on {TODAY}.
//  Copyright © 2017 Shallows. All rights reserved.
//

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
    
    @available(*, deprecated, renamed: "value")
    public var asOptional: Value? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }
    
}

extension Result where Value == Void {
    
    public static var success: Result<Void> {
        return .success(())
    }
    
}

extension Optional {
    
    public struct UnwrapError : ShallowsError {
        init() { }
        public var isTransient: Bool {
            return false
        }
    }
    
    public func unwrap() throws -> Wrapped {
        if let wrapped = self {
            return wrapped
        } else {
            throw UnwrapError()
        }
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
