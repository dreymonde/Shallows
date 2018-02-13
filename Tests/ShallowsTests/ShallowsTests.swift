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
    
    static func alwaysSucceeding(with value: Value) -> Storage<Key, Value> {
        return Storage(storageName: "", retrieve: { (_, completion) in
            completion(succeed(with: value))
        }, set: { (_, _, completion) in
            completion(.success)
        })
    }
    
}

extension ReadOnlyStorageProtocol {
    
    static func alwaysFailing(with error: Error) -> ReadOnlyStorage<Key, Value> {
        return ReadOnlyStorage(storageName: "", retrieve: { _, completion in completion(.failure(error)) })
    }
    
    static func alwaysSucceeding(with value: Value) -> ReadOnlyStorage<Key, Value> {
        return ReadOnlyStorage(storageName: "", retrieve: { _, completion in completion(.success(value)) })
    }
    
}

class ShallowsTests: XCTestCase {
    
    override func setUp() {
        ShallowsLog.isEnabled = true
    }
    
}
