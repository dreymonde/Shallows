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

extension FileSystemCache {
    
    static func test(number: Int) -> FileSystemCache {
        let cache = FileSystemCache.inDirectory(.cachesDirectory, appending: "shallows-tests-tmp-\(number)")
        cache.pruneOnDeinit = true
        return cache
    }
    
}

class ShallowsTests: XCTestCase {
    
    override func setUp() {
        ShallowsLog.isEnabled = true
    }
    
    func testSome() {
        let mmcch = MemoryCache<String, Int>(storage: [:], cacheName: "mmcch")
        mmcch.set(10, forKey: "AAA", completion: { _ in })
        mmcch.retrieve(forKey: "Something") { (result) in
            print(result)
        }
        
        print("City of stars")
        
        let memeMain = MemoryCache<String, Int>(storage: [:], cacheName: "Main")
        let meme1 = MemoryCache<String, Int>(storage: ["Some" : 15], cacheName: "First-Back")
        let meme2 = MemoryCache<String, Int>(storage: ["Other" : 20], cacheName: "Second-Back")//.makeReadOnly()
        
        let combined1 = meme1.combined(with: meme2)
        let full = memeMain.backed(by: combined1)
        //combined1.retrieve(forKey: "Other", completion: { print($0) })
        //meme1.retrieve(forKey: "Other", completion: { print($0) })
        full.retrieve(forKey: "Some", completion: { print($0) })
        full.retrieve(forKey: "Other", completion: { print($0) })
        combined1.set(35, forKey: "Inter")
        meme2.retrieve(forKey: "Inter", completion: { print($0) })
        full.retrieve(forKey: "Nothing", completion: { print($0) })
    }
    
    func testFileSystemCache() {
        let diskCache_raw = FileSystemCache.inDirectory(.cachesDirectory, appending: "shallows-tests-tmp-1")
        diskCache_raw.pruneOnDeinit = true
        let expectation = self.expectation(description: "On retrieve")
        let diskCache = diskCache_raw
            .mapString(withEncoding: .utf8)
        let memCache = MemoryCache<String, String>(storage: [:], cacheName: "mem")
        let nscache = NSCacheCache<NSString, NSString>(cache: .init(), cacheName: "nscache")
            .toNonObjCKeys()
            .toNonObjCValues()
        let main = memCache.combined(with: nscache.combined(with: diskCache))
        diskCache.set("I was just a little boy", forKey: "my-life", completion: { print($0) })
        main.retrieve(forKey: "my-life", completion: {
            XCTAssertEqual($0.asOptional, "I was just a little boy")
            expectation.fulfill()
        })
        waitForExpectations(timeout: 5.0)
    }
    
    func testRawRepresentable() {
        enum Keys : String {
            case a, b, c
        }
        let memCache = MemoryCache<String, Int>(storage: [:]).mapKeys() as Cache<Keys, Int>
        memCache.set(10, forKey: .a)
        memCache.retrieve(forKey: .a, completion: { XCTAssertEqual($0.asOptional, 10) })
        memCache.retrieve(forKey: .b, completion: { XCTAssertNil($0.asOptional) })
    }
    
    func testJSONMapping() {
        let dict: [String : Any] = ["json": 15]
        let memCache = MemoryCache<Int, Data>(storage: [:]).mapJSONDictionary()
        memCache.set(dict, forKey: 10)
        memCache.retrieve(forKey: 10) { (result) in
            print(result)
            XCTAssertEqual(result.asOptional! as NSDictionary, dict as NSDictionary)
        }
    }
    
    func testPlistMapping() {
        let dict: [String : Any] = ["plist": 15]
        let memCache = MemoryCache<Int, Data>(storage: [:]).mapPlistDictionary(format: .binary)
        memCache.set(dict, forKey: 10)
        memCache.retrieve(forKey: 10) { (result) in
            print(result)
            XCTAssertEqual(result.asOptional! as NSDictionary, dict as NSDictionary)
        }
    }
    
    func testSingleElementCache() {
        let diskCache = FileSystemCache.inDirectory(.cachesDirectory, appending: "shallows-tests-tmp-2")
        diskCache.pruneOnDeinit = true
        print(diskCache.directoryURL)
        let singleElementCache = MemoryCache<String, String>().mapKeys({ "only_key" }) as Cache<Void, String>
        let finalCache = singleElementCache.combined(with: diskCache
            .singleKey("only_key")
            .mapString(withEncoding: .utf8)
        )
        finalCache.set("Five-Four")
        finalCache.retrieve { (result) in
            XCTAssertEqual(result.asOptional, "Five-Four")
        }
    }
    
    func testSync() throws {
        let diskCache = FileSystemCache.inDirectory(.cachesDirectory, appending: "shallows-tests-tmp-3")
        diskCache.pruneOnDeinit = true
        let stringCache = diskCache.mapString().makeSyncCache()
        try stringCache.set("Sofar", forKey: "kha")
        let back = try stringCache.retrieve(forKey: "kha")
        XCTAssertEqual(back, "Sofar")
    }
    
    func testUpdate() {
        let cache = MemoryCache<Int, Int>(cacheName: "mem")
        cache.storage[10] = 15
        let expectation = self.expectation(description: "On update")
        cache.update(forKey: 10, { $0 += 5 }) { (result) in
            XCTAssertEqual(result.asOptional, 20)
            let check = try! cache.makeSyncCache().retrieve(forKey: 10)
            XCTAssertEqual(check, 20)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5.0)
    }
    
    func testMapKeysFailing() {
        let cache = MemoryCache<Int, Int>()
        let mapped: Cache<Int, Int> = cache.mapKeys({ _ in throw "Test failable keys mappings" })
        let sync = mapped.makeSyncCache()
        XCTAssertThrowsError(try sync.retrieve(forKey: 10))
        XCTAssertThrowsError(try sync.set(-20, forKey: 5))
    }
    
    func testRawRepresentableValues() throws {
        
        enum Values : String {
            case some, other, another
        }
        
        let fileCache = FileSystemCache.inDirectory(.cachesDirectory, appending: "shallows-tests-tmp-3")
        fileCache.pruneOnDeinit = true
        
        let finalCache = fileCache
            .mapString(withEncoding: .utf8)
            .singleKey("single")
            .mapValues() as Cache<Void, Values>
        let sync = finalCache.makeSyncCache()
        try sync.set(.some)
        XCTAssertEqual(try sync.retrieve(), .some)
        try sync.set(.another)
        XCTAssertEqual(try sync.retrieve(), .another)
    }
    
    func testCombinedSetFront() throws {
        let front = MemoryCache<Int, Int>()
        let back = MemoryCache<Int, Int>()
        let combined = front.combined(with: back, pullingFromBack: true, pushingToBack: false).makeSyncCache()
        print(combined.cacheName)
        back.storage[1] = 1
        let firstCombined = try combined.retrieve(forKey: 1)
        XCTAssertEqual(firstCombined, 1)
        let firstFront = try front.makeSyncCache().retrieve(forKey: 1)
        XCTAssertEqual(firstFront, 1)
        try combined.set(10, forKey: 1)
        let secondFront = try front.makeSyncCache().retrieve(forKey: 1)
        XCTAssertEqual(secondFront, 10)
        let secondBack = try back.makeSyncCache().retrieve(forKey: 1)
        XCTAssertEqual(secondBack, 1)
    }
    
    func testRetrievePullStrategy() {
        let front = MemoryCache<String, String>(cacheName: "Front")
        let back = MemoryCache<String, String>(storage: ["A": "Alba"], cacheName: "Back")
        front.retrieve(forKey: "A", backedBy: back, shouldPullFromBack: false, completion: { print($0) })
        print(front.storage["A"] as Any)
    }
    
    static var allTests = [
        ("testFileSystemCache", testFileSystemCache),
    ]
    
}
