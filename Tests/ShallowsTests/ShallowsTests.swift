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
        let diskCache_raw = FileSystemCache.inDirectory(.cachesDirectory, appending: "shallows-tests-tmp")
        do {
            try FileManager.default.removeItem(at: diskCache_raw.directoryURL)
        } catch { }
        let expectation = self.expectation(description: "On retrieve")
        let diskCache = diskCache_raw.makeCache()
            .mapValues(transformIn: { try String.init(data: $0, encoding: .utf8).tryUnwrap() },
                       transformOut: { try $0.data(using: .utf8).tryUnwrap() })
        let memCache = MemoryCache<String, String>(storage: [:], name: "mem")
        let nscache = NSCacheCache<NSString, NSString>(cache: .init(), name: "nscache")
            .makeCache()
            .mapKeys({ (str: String) in str as NSString })
            .mapValues(transformIn: { $0 as String },
                       transformOut: { $0 as NSString })
        let main = memCache.bothWayCombined(with: nscache.bothWayCombined(with: diskCache))
        diskCache.set("I was just a little boy", forKey: "my-life", completion: { print($0) })
        main.retrieve(forKey: "my-life", completion: {
            XCTAssertEqual($0.asOptional, "I was just a little boy")
            expectation.fulfill()
        })
        waitForExpectations(timeout: 5.0)
        do {
            try FileManager.default.removeItem(at: diskCache_raw.directoryURL)
        } catch { }
    }
    
    func testRawRepresentable() {
        enum Keys : String {
            case a, b, c
        }
        let memCache = MemoryCache<String, Int>(storage: [:]).makeCache().mapKeys() as Cache<Keys, Int>
        memCache.set(10, forKey: .a)
        memCache.retrieve(forKey: .a, completion: { XCTAssertEqual($0.asOptional, 10) })
        memCache.retrieve(forKey: .b, completion: { XCTAssertNil($0.asOptional) })
    }
    
    static var allTests = [
        ("testExample", testExample),
    ]
}
