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

extension Optional {
    
    struct UnwrapError : Error {
        init() { }
    }
    
    func tryUnwrap() throws -> Wrapped {
        if let wrapped = self {
            return wrapped
        } else {
            throw UnwrapError()
        }
    }
    
}

class ShallowsTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        //// XCTAssertEqual(Shallows().text, "Hello, World!")
    }
    
    override func setUp() {
        ShallowsLog.isEnabled = true
    }
    
    func testSome() {
        let mmcch = MemoryCache<String, Int>(storage: [:], name: "mmcch")
        mmcch.set(10, forKey: "AAA", completion: { _ in })
        mmcch.retrieve(forKey: "Something") { (result) in
            print(result)
        }
        
        print("City of stars")
        
        let memeMain = MemoryCache<String, Int>(storage: [:], name: "Main")
        let meme1 = MemoryCache<String, Int>(storage: ["Some" : 15], name: "First-Back")
        let meme2 = MemoryCache<String, Int>(storage: ["Other" : 20], name: "Second-Back")//.makeReadOnly()
        
        let combined1 = meme1.bothWayCombined(with: meme2)
        let full = memeMain.combined(with: combined1)
        //combined1.retrieve(forKey: "Other", completion: { print($0) })
        //meme1.retrieve(forKey: "Other", completion: { print($0) })
        full.retrieve(forKey: "Some", completion: { print($0) })
        full.retrieve(forKey: "Other", completion: { print($0) })
        combined1.set(35, forKey: "Inter")
        meme2.retrieve(forKey: "Inter", completion: { print($0) })
        full.retrieve(forKey: "Nothing", completion: { print($0) })
    }
    
    func testFileSystemCache() {
        let url = URL.init(fileURLWithPath: "/Users/oleg/Desktop/CacheTest")
        do {
            try FileManager.default.removeItem(at: url)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        } catch { }
        let diskCache = FileSystemCache(directoryURL: url, name: "desktop-disk")
            .makeCache()
            .mapValues(transformIn: { try String.init(data: $0, encoding: .utf8).tryUnwrap() },
                       transformOut: { try $0.data(using: .utf8).tryUnwrap() })
        diskCache.set("I was just a little boy", forKey: "my-life", completion: { print($0) })
        diskCache.retrieve(forKey: "my-life", completion: { print($0) })
    }
    
    static var allTests = [
        ("testExample", testExample),
    ]
}
