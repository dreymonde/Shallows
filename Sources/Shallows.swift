//
//  Shallows.swift
//  Shallows
//
//  Created by Oleg Dreyman on {TODAY}.
//  Copyright © 2017 Shallows. All rights reserved.
//

public enum Result<Value> {
    
    case success(Value)
    case failure(Error)
    
    public var isFailure: Bool {
        if case .failure = self {
            return true
        }
        return false
    }
    
    public var asOptional: Value? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }
    
}

extension Optional {
    
    public struct UnwrapError : Error {
        init() { }
    }
    
    public func tryUnwrap() throws -> Wrapped {
        if let wrapped = self {
            return wrapped
        } else {
            throw UnwrapError()
        }
    }
    
}

internal func throwing<In, Out>(_ block: @escaping (In) -> Out?) -> (In) throws -> Out {
    return { input in
        try block(input).tryUnwrap()
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
