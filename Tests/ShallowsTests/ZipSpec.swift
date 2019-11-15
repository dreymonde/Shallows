//
//  ZipSpec.swift
//  Shallows
//
//  Created by Олег on 13.02.2018.
//  Copyright © 2018 Shallows. All rights reserved.
//

import Foundation
import Shallows

func testZip() {
    
    describe("read-only zipping") {
        let readOnly1: ReadOnlyStorage<Void, Int> = ReadOnlyStorage.alwaysSucceeding(with: 10)
        let readOnly2: ReadOnlyStorage<Void, String> = ReadOnlyStorage.alwaysSucceeding(with: "hooray!")
        $0.it("succeeds with both values when present") {
            let zipped = zip(readOnly1, readOnly2).makeSyncStorage()
            let (int, str) = try zipped.retrieve()
            try expect(int) == 10
            try expect(str) == "hooray!"
        }
        $0.it("fails when one of the values is missing") {
            let failing: ReadOnlyStorage<Void, String> = .alwaysFailing(with: "test")
            let zipped = zip(readOnly1, failing).makeSyncStorage()
            try expect(zipped.retrieve()).toThrow()
            let zipped2 = zip(failing, readOnly1).makeSyncStorage()
            try expect(zipped2.retrieve()).toThrow()
        }
        $0.it("fails when both values are missing") {
            let failing1: ReadOnlyStorage<Void, Int> = .alwaysFailing(with: "test-1")
            let failing2: ReadOnlyStorage<Void, Int> = .alwaysFailing(with: "test-2")
            let zipped = zip(failing1, failing2).makeSyncStorage()
            try expect(zipped.retrieve()).toThrow()
        }
    }
    
    describe("write-only zipping") {
        var int = 0
        var str = ""
        let writeOnly1: WriteOnlyStorage<Void, Int> = wos { val, _ in
            int = val
        }
        let writeOnly2: WriteOnlyStorage<Void, String> = wos { val, _ in
            str = val
        }
        $0.after {
            int = 0
            str = ""
        }
        $0.it("succeeds with both values when present") {
            let zipped = zip(writeOnly1, writeOnly2).makeSyncStorage()
            try zipped.set((5, "5"))
            try expect(int) == 5
            try expect(str) == "5"
        }
        $0.it("fails when one of the storages fails") {
            let failing: WriteOnlyStorage<Void, String> = .alwaysFailing(with: "test")
            let zipped = zip(writeOnly1, failing).makeSyncStorage()
            try expect(zipped.set((6, "1"))).toThrow()
            try expect(int) == 6
            let zipped2 = zip(failing, writeOnly1).makeSyncStorage()
            try expect(zipped2.set(("10", 10))).toThrow()
        }
        $0.it("fails when both storages are missing") {
            let failing1: WriteOnlyStorage<Void, Int> = .alwaysFailing(with: "test-1")
            let failing2: WriteOnlyStorage<Void, Int> = .alwaysFailing(with: "test-2")
            let zipped = zip(failing1, failing2).makeSyncStorage()
            try expect(zipped.set((7, 7))).toThrow()
        }
    }
    
    describe("zipping") {
        $0.it("works") {
            let storage1 = Storage<Void, Int>.alwaysSucceeding(with: 10)
            let storage2 = Storage<Void, String>.alwaysSucceeding(with: "storage")
            let zipped = zip(storage1, storage2).makeSyncStorage()
            let (int, str) = try zipped.retrieve()
            try expect(int) == 10
            try expect(str) == "storage"
            try zipped.set((5, "100"))
        }
    }
    
}

internal func wos<Key, Value>(_ set: @escaping (Value, Key) throws -> ()) -> WriteOnlyStorage<Key, Value> {
    return WriteOnlyStorage<Key, Value>(storageName: "wos", set: { (value, key, completion) in
        do {
            try set(value, key)
            completion(succeed(with: ()))
        } catch {
            completion(fail(with: error))
        }
    })
}
