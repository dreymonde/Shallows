//
//  Result.swift
//  Shallows
//
//  Created by Олег on 13.02.2018.
//  Copyright © 2018 Shallows. All rights reserved.
//

import Foundation

public typealias ShallowsResult<Value> = Swift.Result<Value, Swift.Error>

extension Swift.Result {
    
    internal var isFailure: Bool {
        if case .failure = self {
            return true
        }
        return false
    }

    internal var isSuccess: Bool {
        return !isFailure
    }

    internal var value: Success? {
        if case .success(let value) = self {
            return value
        }
        return nil
    }

    internal var error: Error? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }

}

public func fail<Value>(with error: Error) -> ShallowsResult<Value> {
    return .failure(error)
}

public func succeed<Value>(with value: Value) -> ShallowsResult<Value> {
    return .success(value)
}

extension Swift.Result where Success == Void {

    internal static var success: ShallowsResult<Void> {
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
