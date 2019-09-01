//
//  AdditionalSpec.swift
//  Shallows
//
//  Created by Олег on 21.02.2018.
//  Copyright © 2018 Shallows. All rights reserved.
//

@testable import Shallows
import Dispatch

func testAdditional() {
    
    describe("update") {
        $0.it("retrieves, updates and sets value") {
            let storage = MemoryStorage<Int, Int>(storage: [1: 10])
            let sema = DispatchSemaphore(value: 0)
            var val: Int?
            storage.update(forKey: 1, { $0 += 1 }).on { (value) in
                val = value
                sema.signal()
            }
            sema.wait()
            try expect(val) == 11
            try expect(storage.storage[1]) == 11
        }
        $0.it("fails if retrieve fails") {
            let read = ReadOnlyStorage<Int, Int>.alwaysFailing(with: "read fails")
            let write = MemoryStorage<Int, Int>(storage: [1: 10])
            let storage = Storage(read: read, write: write.asWriteOnlyStorage())
            let sema = DispatchSemaphore(value: 0)
            var er: Error?
            storage.update(forKey: 1, { $0 += 1 }).on(failure: { (error) in
                er = error
                sema.signal()
            })
            sema.wait()
            try expect(er as? String) == "read fails"
            try expect(write.storage[1]) == 10
        }
        $0.it("fails if set fails") {
            let read = ReadOnlyStorage<Int, Int>.alwaysSucceeding(with: 10)
            let write = WriteOnlyStorage<Int, Int>.alwaysFailing(with: "write fails")
            let storage = Storage(read: read, write: write)
            let sema = DispatchSemaphore(value: 0)
            var er: Error?
            storage.update(forKey: 1, { $0 += 1 }).on(failure: { (error) in
                er = error
                sema.signal()
            })
            sema.wait()
            try expect(er as? String) == "write fails"
        }
    }
    
    describe("renaming") {
        $0.it("renames read-only storage") {
            let r1 = ReadOnlyStorage<Int, Int>.empty()
            let r2 = r1.renaming(to: "r2")
            try expect(r2.storageName) == "r2"
        }
        $0.it("renames write-only storage") {
            let w1 = WriteOnlyStorage<Int, Int>.empty()
            let w2 = w1.renaming(to: "w2")
            try expect(w2.storageName) == "w2"
        }
        $0.describe("storage") {
            let s1 = Storage<Int, Int>.empty()
            let s2 = s1.renaming(to: "s2")
            $0.it("renames it") {
                try expect(s2.storageName) == "s2"
            }
            $0.it("renames asReadOnlyStorage") {
                try expect(s2.asReadOnlyStorage().storageName) == "s2"
            }
            $0.it("renames asWriteOnlyStorage") {
                try expect(s2.asWriteOnlyStorage().storageName) == "s2"
            }
        }
    }

}
