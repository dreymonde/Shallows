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

extension FileSystemStorage {
    
    private static var counter = 0
    
    static func test() -> FileSystemStorage {
        counter += 1
        let cache = FileSystemStorage.inDirectory(.cachesDirectory, appending: "shallows-tests-tmp-\(counter)")
        cache.pruneOnDeinit = true
        return cache
    }
    
}


extension ReadOnlyStorageProtocol {
    
    static func alwaysFailing(with error: Error) -> ReadOnlyStorage<Key, Value> {
        return ReadOnlyStorage(cacheName: "", retrieve: { _, completion in completion(.failure(error)) })
    }
    
    static func alwaysSucceeding(with value: Value) -> ReadOnlyStorage<Key, Value> {
        return ReadOnlyStorage(cacheName: "", retrieve: { _, completion in completion(.success(value)) })
    }
    
}

class ShallowsTests: XCTestCase {
    
    override func setUp() {
        ShallowsLog.isEnabled = true
    }
    
    func testSome() {
        let mmcch = MemoryStorage<String, Int>(storage: [:], cacheName: "mmcch")
        mmcch.set(10, forKey: "AAA", completion: { _ in })
        mmcch.retrieve(forKey: "Something") { (result) in
            print(result)
        }
        
        print("City of stars")
        
        let memeMain = MemoryStorage<String, Int>(storage: [:], cacheName: "Main")
        let meme1 = MemoryStorage<String, Int>(storage: ["Some" : 15], cacheName: "First-Back")
        let meme2 = MemoryStorage<String, Int>(storage: ["Other" : 20], cacheName: "Second-Back")//.makeReadOnly()
        
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
        let diskCache_raw = FileSystemStorage.inDirectory(.cachesDirectory, appending: "shallows-tests-tmp-1")
        diskCache_raw.pruneOnDeinit = true
        let expectation = self.expectation(description: "On retrieve")
        let diskCache = diskCache_raw
            .mapString(withEncoding: .utf8)
            .usingStringKeys()
        let memCache = MemoryStorage<String, String>(storage: [:], cacheName: "mem")
        let nscache = NSCacheStorage<NSString, NSString>(cache: .init(), cacheName: "nscache")
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
        let memCache = MemoryStorage<String, Int>(storage: [:]).mapKeys() as Storage<Keys, Int>
        memCache.set(10, forKey: .a)
        memCache.retrieve(forKey: .a, completion: { XCTAssertEqual($0.value, 10) })
        memCache.retrieve(forKey: .b, completion: { XCTAssertNil($0.value) })
    }
    
    func testJSONMapping() {
        let dict: [String : Any] = ["json": 15]
        let memCache = MemoryStorage<Int, Data>(storage: [:]).mapJSONDictionary()
        memCache.set(dict, forKey: 10)
        memCache.retrieve(forKey: 10) { (result) in
            print(result)
            XCTAssertEqual(result.value! as NSDictionary, dict as NSDictionary)
        }
    }
    
    func testPlistMapping() {
        let dict: [String : Any] = ["plist": 15]
        let memCache = MemoryStorage<Int, Data>(storage: [:]).mapPlistDictionary(format: .binary)
        memCache.set(dict, forKey: 10)
        memCache.retrieve(forKey: 10) { (result) in
            print(result)
            XCTAssertEqual(result.value! as NSDictionary, dict as NSDictionary)
        }
    }
    
    func testSingleElementCache() {
        let diskCache = FileSystemStorage.inDirectory(.cachesDirectory, appending: "shallows-tests-tmp-2")
        diskCache.pruneOnDeinit = true
        print(diskCache.directoryURL)
        let singleElementCache = MemoryStorage<String, String>().mapKeys({ "only_key" }) as Storage<Void, String>
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
        let diskCache = FileSystemStorage.inDirectory(.cachesDirectory, appending: "shallows-tests-tmp-3")
        diskCache.pruneOnDeinit = true
        let stringCache = diskCache.mapString().makeSyncStorage()
        try stringCache.set("Sofar", forKey: "kha")
        let back = try stringCache.retrieve(forKey: "kha")
        XCTAssertEqual(back, "Sofar")
    }
    
    func testUpdate() {
        let cache = MemoryStorage<Int, Int>(cacheName: "mem")
        cache.storage[10] = 15
        let expectation = self.expectation(description: "On update")
        cache.update(forKey: 10, { $0 += 5 }) { (result) in
            XCTAssertEqual(result.value, 20)
            let check = try! cache.makeSyncStorage().retrieve(forKey: 10)
            XCTAssertEqual(check, 20)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5.0)
    }
        
    func testMapKeysFailing() {
        let cache = MemoryStorage<Int, Int>()
        let mapped: Storage<Int, Int> = cache.mapKeys({ _ in throw "Test failable keys mappings" })
        let sync = mapped.makeSyncStorage()
        XCTAssertThrowsError(try sync.retrieve(forKey: 10))
        XCTAssertThrowsError(try sync.set(-20, forKey: 5))
    }
    
    func testRawRepresentableValues() throws {
        
        enum Values : String {
            case some, other, another
        }
        
        let fileCache = FileSystemStorage.inDirectory(.cachesDirectory, appending: "shallows-tests-tmp-3")
        fileCache.pruneOnDeinit = true
        
        let finalCache = fileCache
            .mapString(withEncoding: .utf8)
            .singleKey("single")
            .mapValues() as Storage<Void, Values>
        let sync = finalCache.makeSyncStorage()
        try sync.set(.some)
        XCTAssertEqual(try sync.retrieve(), .some)
        try sync.set(.another)
        XCTAssertEqual(try sync.retrieve(), .another)
    }
    
    func testCombinedSetFront() throws {
        let front = MemoryStorage<Int, Int>()
        let back = MemoryStorage<Int, Int>()
        let combined = front.combined(with: back, pullStrategy: .pullThenComplete, setStrategy: .frontOnly).makeSyncStorage()
        print(combined.storageName)
        back.storage[1] = 1
        let firstCombined = try combined.retrieve(forKey: 1)
        XCTAssertEqual(firstCombined, 1)
        let firstFront = try front.makeSyncStorage().retrieve(forKey: 1)
        XCTAssertEqual(firstFront, 1)
        try combined.set(10, forKey: 1)
        let secondFront = try front.makeSyncStorage().retrieve(forKey: 1)
        XCTAssertEqual(secondFront, 10)
        let secondBack = try back.makeSyncStorage().retrieve(forKey: 1)
        XCTAssertEqual(secondBack, 1)
    }
    
    func testRetrievePullStrategy() {
        let front = MemoryStorage<String, String>(cacheName: "Front")
        let back = MemoryStorage<String, String>(storage: ["A": "Alba"], cacheName: "Back")
        front.dev.retrieve(forKey: "A", backedBy: back, strategy: .neverPull, completion: { print($0) })
        print(front.storage["A"] as Any)
    }
    
    func testZipReadOnly() throws {
        let memory1 = MemoryStorage<String, Int>(storage: ["avenues": 2], cacheName: "avenues").asReadOnlyStorage()
        let file1 = FileSystemStorage.test()
            .mapString()
            .usingStringKeys()
        try file1.makeSyncStorage().set("Out To Sea", forKey: "avenues")
        let zipped = zip(memory1, file1.asReadOnlyStorage()).makeSyncStorage()
        let (number, firstSong) = try zipped.retrieve(forKey: "avenues")
        XCTAssertEqual(number, 2)
        XCTAssertEqual(firstSong, "Out To Sea")
    }
    
    func testZipReadOnlyFail() throws {
        enum Err : Error {
            case a, b
        }
        let failure1 = ReadOnlyStorage<Int, Int>.alwaysFailing(with: Err.a)
        let failure2 = ReadOnlyStorage<Int, String>.alwaysFailing(with: Err.b)
        let zipped = zip(failure1.asReadOnlyStorage(), failure2.asReadOnlyStorage()).makeSyncStorage()
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
        let memory1 = MemoryStorage<String, Int>(storage: [:], cacheName: "batman")
        let file1 = FileSystemStorage.test().mapString().usingStringKeys()
        let zipped = zip(memory1, file1).singleKey("arkham-knight").makeSyncStorage()
        try zipped.set((3, "Scarecrow"))
        let (number, mainVillain) = try zipped.retrieve()
        XCTAssertEqual(number, 3)
        XCTAssertEqual(mainVillain, "Scarecrow")
    }
    
    func testLatestStrategy() {
        let expectation10 = self.expectation(description: "On 10, true")
        let expectation15 = self.expectation(description: "On 15, true")
        var complete1: ((Result<Int>) -> ())?
        let cache1 = ReadOnlyStorage<Void, Int>(cacheName: "", retrieve: { _, completion in complete1 = completion })
        let cache2 = ReadOnlyStorage<Void, Bool>(cacheName: "", retrieve: { _, completion in completion(.success(true)) })
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
        let int = ReadOnlyStorage<Void, Int>.alwaysSucceeding(with: 10)
        let bool = ReadOnlyStorage<Void, Bool>.alwaysSucceeding(with: true)
        let string = ReadOnlyStorage<Void, String>.alwaysSucceeding(with: "A lot")
        let zipped = zip(int, zip(bool, string)).makeSyncStorage()
        let (i, (b, s)) = try zipped.retrieve()
        XCTAssertEqual(i, 10)
        XCTAssertTrue(b)
        XCTAssertEqual(s, "A lot")
    }
    
    func testSetStrategyFrontFirst() {
        var frontSet: Bool = false
        let front = Storage<Void, Int>(cacheName: "front",
                                     retrieve: { _,_  in },
                                     set: { (_, _, completion) in frontSet = true; completion(.success) })
        let expectation = self.expectation(description: "On back called")
        let back = Storage<Void, Int>(cacheName: "back", retrieve: { _,_  in }) { (_, _, _) in
            XCTAssertTrue(frontSet)
            expectation.fulfill()
        }
        let combined = front.combined(with: back, pullStrategy: .pullThenComplete, setStrategy: .frontFirst)
        combined.set(10)
        waitForExpectations(timeout: 5.0)
    }
    
    func testStrategyFrontOnly() {
        let front = Storage<Void, Int>(cacheName: "front",
                                     retrieve: { _,_  in },
                                     set: { (_, _, completion) in completion(.success) })
        let expectation = self.expectation(description: "On back called")
        let back = Storage<Void, Int>(cacheName: "back", retrieve: { _,_  in }) { (_, _, _) in
            XCTFail()
        }
        let combined = front.combined(with: back, pullStrategy: .pullThenComplete, setStrategy: .frontOnly)
        combined.set(10) { _ in
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5.0)
    }
    
    func testUnsupportedTransformation() throws {
        let back = MemoryStorage<String, Data>(storage: ["single-key": "Alba".data(using: .utf8)!]).singleKey("single-key").asReadOnlyStorage()
        let stringCache = back.usingUnsupportedTransformation({ $0.mapString() }).makeSyncStorage()
        let alba = try stringCache.retrieve()
        XCTAssertEqual(alba, "Alba")
    }
    
    func readme() {
        
        struct Player : Codable {
            let name: String
            let rating: Int
        }
        
        let memoryCache = MemoryStorage<String, Player>()
        let diskCache = FileSystemStorage.inDirectory(.cachesDirectory, appending: "cache")
            .mapJSONObject(Player.self)
            .usingStringKeys()
        let combinedCache = memoryCache.combined(with: diskCache)
        combinedCache.retrieve(forKey: "Higgins") { (result) in
            if let player = result.value {
                print(player.name)
            }
        }
        combinedCache.set(Player(name: "Mark", rating: 1), forKey: "Selby") { (result) in
            if result.isSuccess {
                print("Success!")
            }
        }
        
//
    }
    
    static var allTests = [
        ("testFileSystemCache", testFileSystemCache),
    ]
    
}
