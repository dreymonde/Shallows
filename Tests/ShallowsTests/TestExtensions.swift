//
//  ShallowsTests.swift
//  Shallows
//
//  Created by Oleg Dreyman on {TODAY}.
//  Copyright © 2017 Shallows. All rights reserved.
//

import Foundation
import XCTest
@testable import Shallows

extension String : Error { }

extension Storage {
    
    static func alwaysFailing(with error: Error) -> Storage<Key, Value> {
        return Storage(read: .alwaysFailing(with: error),
                       write: .alwaysFailing(with: error))
    }
    
    static func alwaysSucceeding(with value: Value) -> Storage<Key, Value> {
        return Storage(read: .alwaysSucceeding(with: value),
                       write: .alwaysSucceeding())
    }
    
}

extension ReadOnlyStorage {
    
    static func alwaysFailing(with error: Error) -> ReadOnlyStorage<Key, Value> {
        return ReadOnlyStorage(storageName: "", retrieve: { _, completion in completion(.failure(error)) })
    }
    
    static func alwaysSucceeding(with value: Value) -> ReadOnlyStorage<Key, Value> {
        return ReadOnlyStorage(storageName: "", retrieve: { _, completion in completion(.success(value)) })
    }
    
}

extension WriteOnlyStorage {
    
    static func alwaysFailing(with error: Error) -> WriteOnlyStorage<Key, Value> {
        return WriteOnlyStorage.init(storageName: "", set: { _, _, completion in completion(fail(with: error)) })
    }
    
    static func alwaysSucceeding() -> WriteOnlyStorage<Key, Value> {
        return WriteOnlyStorage(storageName: "", set: { _, _, completion in completion(succeed(with: ())) })
    }
    
}

class ShallowsTests: XCTestCase {
    
    override func setUp() {
        ShallowsLog.isEnabled = true
    }
    
}
