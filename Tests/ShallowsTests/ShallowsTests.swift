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
        let storage = FileSystemStorage.inDirectory(.cachesDirectory, appending: "shallows-tests-tmp-\(counter)")
        storage.pruneOnDeinit = true
        return storage
    }
    
}

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
    
    func testSome() {
        let mmcch = MemoryStorage<String, Int>(storage: [:], storageName: "mmcch")
        mmcch.set(10, forKey: "AAA", completion: { _ in })
        mmcch.retrieve(forKey: "Something") { (result) in
            print(result)
        }
        
        print("City of stars")
        
        let memeMain = MemoryStorage<String, Int>(storage: [:], storageName: "Main")
        let meme1 = MemoryStorage<String, Int>(storage: ["Some" : 15], storageName: "First-Back")
        let meme2 = MemoryStorage<String, Int>(storage: ["Other" : 20], storageName: "Second-Back")//.makeReadOnly()
        
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
    
    func testFileSystemStorage() {
        let diskStorage_raw = FileSystemStorage.inDirectory(.cachesDirectory, appending: "shallows-tests-tmp-1")
        diskStorage_raw.pruneOnDeinit = true
        let expectation = self.expectation(description: "On retrieve")
        let diskStorage = diskStorage_raw
            .mapString(withEncoding: .utf8)
            .usingStringKeys()
        let memStorage = MemoryStorage<String, String>(storage: [:], storageName: "mem")
        let nsstorage = NSCacheStorage<NSString, NSString>(storage: .init(), storageName: "nsstorage")
            .toNonObjCKeys()
            .toNonObjCValues()
        let main = memStorage.combined(with: nsstorage.combined(with: diskStorage))
        diskStorage.set("I was just a little boy", forKey: "my-life", completion: { print($0) })
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
        let memStorage = MemoryStorage<String, Int>(storage: [:]).mapKeys(toRawRepresentableType: Keys.self)
        memStorage.set(10, forKey: .a)
        memStorage.retrieve(forKey: .a, completion: { XCTAssertEqual($0.value, 10) })
        memStorage.retrieve(forKey: .b, completion: { XCTAssertNil($0.value) })
    }
    
    func testJSONMapping() {
        let dict: [String : Any] = ["json": 15]
        let memStorage = MemoryStorage<Int, Data>(storage: [:]).mapJSONDictionary()
        memStorage.set(dict, forKey: 10)
        memStorage.retrieve(forKey: 10) { (result) in
            print(result)
            XCTAssertEqual(result.value! as NSDictionary, dict as NSDictionary)
        }
    }
    
    func testPlistMapping() {
        let dict: [String : Any] = ["plist": 15]
        let memStorage = MemoryStorage<Int, Data>(storage: [:]).mapPlistDictionary(format: .binary)
        memStorage.set(dict, forKey: 10)
        memStorage.retrieve(forKey: 10) { (result) in
            print(result)
            XCTAssertEqual(result.value! as NSDictionary, dict as NSDictionary)
        }
    }
    
    func testSingleElementStorage() {
        let diskStorage = FileSystemStorage.inDirectory(.cachesDirectory, appending: "shallows-tests-tmp-2")
        diskStorage.pruneOnDeinit = true
        print(diskStorage.directoryURL)
        let singleElementStorage = MemoryStorage<String, String>().mapKeys({ "only_key" }) as Storage<Void, String>
        let finalStorage = singleElementStorage.combined(with: diskStorage
            .singleKey("only_key")
            .mapString(withEncoding: .utf8)
        )
        finalStorage.set("Five-Four")
        finalStorage.retrieve { (result) in
            XCTAssertEqual(result.value, "Five-Four")
        }
    }
    
    func testSync() throws {
        let diskStorage = FileSystemStorage.inDirectory(.cachesDirectory, appending: "shallows-tests-tmp-3")
        diskStorage.pruneOnDeinit = true
        let stringStorage = diskStorage.mapString().makeSyncStorage()
        try stringStorage.set("Sofar", forKey: "kha")
        let back = try stringStorage.retrieve(forKey: "kha")
        XCTAssertEqual(back, "Sofar")
    }
    
    func testUpdate() {
        let storage = MemoryStorage<Int, Int>(storageName: "mem")
        storage.storage[10] = 15
        let expectation = self.expectation(description: "On update")
        storage.update(forKey: 10, { $0 += 5 }) { (result) in
            XCTAssertEqual(result.value, 20)
            let check = try! storage.makeSyncStorage().retrieve(forKey: 10)
            XCTAssertEqual(check, 20)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5.0)
    }
        
    func testMapKeysFailing() {
        let storage = MemoryStorage<Int, Int>()
        let mapped: Storage<Int, Int> = storage.mapKeys({ _ in throw "Test failable keys mappings" })
        let sync = mapped.makeSyncStorage()
        XCTAssertThrowsError(try sync.retrieve(forKey: 10))
        XCTAssertThrowsError(try sync.set(-20, forKey: 5))
    }
    
    func testRawRepresentableValues() throws {
        
        enum Values : String {
            case some, other, another
        }
        
        let fileStorage = FileSystemStorage.inDirectory(.cachesDirectory, appending: "shallows-tests-tmp-3")
        fileStorage.pruneOnDeinit = true
        
        let finalStorage = fileStorage
            .mapString(withEncoding: .utf8)
            .singleKey("single")
            .mapValues(toRawRepresentableType: Values.self)
        let sync = finalStorage.makeSyncStorage()
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
        let front = MemoryStorage<String, String>(storageName: "Front")
        let back = MemoryStorage<String, String>(storage: ["A": "Alba"], storageName: "Back")
        front.dev.retrieve(forKey: "A", backedBy: back, strategy: .neverPull, completion: { print($0) })
        print(front.storage["A"] as Any)
    }
    
    func testZipReadOnly() throws {
        let memory1 = MemoryStorage<String, Int>(storage: ["avenues": 2], storageName: "avenues").asReadOnlyStorage()
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
        let memory1 = MemoryStorage<String, Int>(storage: [:], storageName: "batman")
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
        let storage1 = ReadOnlyStorage<Void, Int>(storageName: "", retrieve: { _, completion in complete1 = completion })
        let storage2 = ReadOnlyStorage<Void, Bool>(storageName: "", retrieve: { _, completion in completion(.success(true)) })
        let zipped = zip(storage1, storage2, withStrategy: .latest)
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
        let front = Storage<Void, Int>(storageName: "front",
                                     retrieve: { _,_  in },
                                     set: { (_, _, completion) in frontSet = true; completion(.success) })
        let expectation = self.expectation(description: "On back called")
        let back = Storage<Void, Int>(storageName: "back", retrieve: { _,_  in }) { (_, _, _) in
            XCTAssertTrue(frontSet)
            expectation.fulfill()
        }
        let combined = front.combined(with: back, pullStrategy: .pullThenComplete, setStrategy: .frontFirst)
        combined.set(10)
        waitForExpectations(timeout: 5.0)
    }
    
    func testStrategyFrontOnly() {
        let front = Storage<Void, Int>(storageName: "front",
                                     retrieve: { _,_  in },
                                     set: { (_, _, completion) in completion(.success) })
        let expectation = self.expectation(description: "On back called")
        let back = Storage<Void, Int>(storageName: "back", retrieve: { _,_  in }) { (_, _, _) in
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
        let stringStorage = back.usingUnsupportedTransformation({ $0.mapString() }).makeSyncStorage()
        let alba = try stringStorage.retrieve()
        XCTAssertEqual(alba, "Alba")
    }
    
    func readme() {
        
        struct Player : Codable {
            let name: String
            let rating: Int
        }
        
        let memoryStorage = MemoryStorage<String, Player>()
        let diskStorage = FileSystemStorage.inDirectory(.cachesDirectory, appending: "storage")
            .mapJSONObject(Player.self)
            .usingStringKeys()
        let combinedStorage = memoryStorage.combined(with: diskStorage)
        combinedStorage.retrieve(forKey: "Higgins") { (result) in
            if let player = result.value {
                print(player.name)
            }
        }
        combinedStorage.set(Player(name: "Mark", rating: 1), forKey: "Selby") { (result) in
            if result.isSuccess {
                print("Success!")
            }
        }
        
    }
        
    static var allTests = [
        ("testFileSystemStorage", testFileSystemStorage),
    ]
    
}
