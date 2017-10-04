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
    
    private static var counter = 0
    
    static func test() -> FileSystemCache {
        counter += 1
        let cache = FileSystemCache.inDirectory(.cachesDirectory, appending: "shallows-tests-tmp-\(counter)")
        cache.pruneOnDeinit = true
        return cache
    }
    
}


extension ReadOnlyCacheProtocol {
    
    static func alwaysFailing(with error: Error) -> ReadOnlyCache<Key, Value> {
        return ReadOnlyCache(cacheName: "", retrieve: { _, completion in completion(.failure(error)) })
    }
    
    static func alwaysSucceeding(with value: Value) -> ReadOnlyCache<Key, Value> {
        return ReadOnlyCache(cacheName: "", retrieve: { _, completion in completion(.success(value)) })
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
            .usingStringKeys()
        let memCache = MemoryCache<String, String>(storage: [:], cacheName: "mem")
        let nscache = NSCacheCache<NSString, NSString>(cache: .init(), cacheName: "nscache")
            .toNonObjCKeys()
            .toNonObjCValues()
        let main = memCache.combined(with: nscache.combined(with: diskCache))
        diskCache.set("I was just a little boy", forKey: "my-life", completion: { print($0) })
        main.retrieve(forKey: "my-life", completion: {
            XCTAssertEqual($0.value, "I was just a little boy")
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
        memCache.retrieve(forKey: .a, completion: { XCTAssertEqual($0.value, 10) })
        memCache.retrieve(forKey: .b, completion: { XCTAssertNil($0.value) })
    }
    
    func testJSONMapping() {
        let dict: [String : Any] = ["json": 15]
        let memCache = MemoryCache<Int, Data>(storage: [:]).mapJSONDictionary()
        memCache.set(dict, forKey: 10)
        memCache.retrieve(forKey: 10) { (result) in
            print(result)
            XCTAssertEqual(result.value! as NSDictionary, dict as NSDictionary)
        }
    }
    
    func testPlistMapping() {
        let dict: [String : Any] = ["plist": 15]
        let memCache = MemoryCache<Int, Data>(storage: [:]).mapPlistDictionary(format: .binary)
        memCache.set(dict, forKey: 10)
        memCache.retrieve(forKey: 10) { (result) in
            print(result)
            XCTAssertEqual(result.value! as NSDictionary, dict as NSDictionary)
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
            XCTAssertEqual(result.value, "Five-Four")
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
            XCTAssertEqual(result.value, 20)
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
        let combined = front.combined(with: back, pullStrategy: .pullThenComplete, setStrategy: .frontOnly).makeSyncCache()
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
        front.dev.retrieve(forKey: "A", backedBy: back, strategy: .neverPull, completion: { print($0) })
        print(front.storage["A"] as Any)
    }
    
    func testZipReadOnly() throws {
        let memory1 = MemoryCache<String, Int>(storage: ["avenues": 2], cacheName: "avenues").asReadOnlyCache()
        let file1 = FileSystemCache.test()
            .mapString()
            .usingStringKeys()
        try file1.makeSyncCache().set("Out To Sea", forKey: "avenues")
        let zipped = zip(memory1, file1.asReadOnlyCache()).makeSyncCache()
        let (number, firstSong) = try zipped.retrieve(forKey: "avenues")
        XCTAssertEqual(number, 2)
        XCTAssertEqual(firstSong, "Out To Sea")
    }
    
    func testZipReadOnlyFail() throws {
        enum Err : Error {
            case a, b
        }
        let failure1 = ReadOnlyCache<Int, Int>.alwaysFailing(with: Err.a)
        let failure2 = ReadOnlyCache<Int, String>.alwaysFailing(with: Err.b)
        let zipped = zip(failure1.asReadOnlyCache(), failure2.asReadOnlyCache()).makeSyncCache()
        XCTAssertThrowsError(try zipped.retrieve(forKey: 1)) { error in
            let zerror = error as! ZippedResultError
            switch (zerror.left!, zerror.right!) {
            case (Err.a, Err.b):
                break
            default:
                XCTFail("Not expected error")
            }
        }
    }
    
    func testZip() throws {
        let memory1 = MemoryCache<String, Int>(storage: [:], cacheName: "batman")
        let file1 = FileSystemCache.test().mapString().usingStringKeys()
        let zipped = zip(memory1, file1).singleKey("arkham-knight").makeSyncCache()
        try zipped.set((3, "Scarecrow"))
        let (number, mainVillain) = try zipped.retrieve()
        XCTAssertEqual(number, 3)
        XCTAssertEqual(mainVillain, "Scarecrow")
    }
    
    func testLatestStrategy() {
        let expectation10 = self.expectation(description: "On 10, true")
        let expectation15 = self.expectation(description: "On 15, true")
        var complete1: ((Result<Int>) -> ())?
        let cache1 = ReadOnlyCache<Void, Int>(cacheName: "", retrieve: { _, completion in complete1 = completion })
        let cache2 = ReadOnlyCache<Void, Bool>(cacheName: "", retrieve: { _, completion in completion(.success(true)) })
        let zipped = zip(cache1, cache2, withStrategy: .latest)
        zipped.retrieve { (res) in
            let (num, bool) = res.value!
            if num == 10, bool {
                expectation10.fulfill()
            }
            if num == 15, bool {
                expectation15.fulfill()
            }
        }
        DispatchQueue.global().async {
            complete1!(.success(10))
        }
        DispatchQueue.global().async {
            complete1!(.success(15))
        }
        waitForExpectations(timeout: 5.0)
    }
    
    func testZipALot() throws {
        let int = ReadOnlyCache<Void, Int>.alwaysSucceeding(with: 10)
        let bool = ReadOnlyCache<Void, Bool>.alwaysSucceeding(with: true)
        let string = ReadOnlyCache<Void, String>.alwaysSucceeding(with: "A lot")
        let zipped = flat(zip(int, zip(bool, string))).makeSyncCache()
        let (i, b, s) = try zipped.retrieve()
        XCTAssertEqual(i, 10)
        XCTAssertTrue(b)
        XCTAssertEqual(s, "A lot")
    }
    
    func testSetStrategyFrontFirst() {
        var frontSet: Bool = false
        let front = Cache<Void, Int>(cacheName: "front",
                                     retrieve: { _,_  in },
                                     set: { (_, _, completion) in frontSet = true; completion(.success) })
        let expectation = self.expectation(description: "On back called")
        let back = Cache<Void, Int>(cacheName: "back", retrieve: { _,_  in }) { (_, _, _) in
            XCTAssertTrue(frontSet)
            expectation.fulfill()
        }
        let combined = front.combined(with: back, pullStrategy: .pullThenComplete, setStrategy: .frontFirst)
        combined.set(10)
        waitForExpectations(timeout: 5.0)
    }
    
    func testStrategyFrontOnly() {
        let front = Cache<Void, Int>(cacheName: "front",
                                     retrieve: { _,_  in },
                                     set: { (_, _, completion) in completion(.success) })
        let expectation = self.expectation(description: "On back called")
        let back = Cache<Void, Int>(cacheName: "back", retrieve: { _,_  in }) { (_, _, _) in
            XCTFail()
        }
        let combined = front.combined(with: back, pullStrategy: .pullThenComplete, setStrategy: .frontOnly)
        combined.set(10) { _ in
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5.0)
    }
    
    func testUnsupportedTransformation() throws {
        let back = MemoryCache<String, Data>(storage: ["single-key": "Alba".data(using: .utf8)!]).singleKey("single-key").asReadOnlyCache()
        let stringCache = back.usingUnsupportedTransformation({ $0.mapString() }).makeSyncCache()
        let alba = try stringCache.retrieve()
        XCTAssertEqual(alba, "Alba")
    }
    
    static var allTests = [
        ("testFileSystemCache", testFileSystemCache),
    ]
    
}
