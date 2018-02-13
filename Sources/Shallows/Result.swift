//
//  Result.swift
//  Shallows
//
//  Created by Олег on 13.02.2018.
//  Copyright © 2018 Shallows. All rights reserved.
//

import Foundation

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
