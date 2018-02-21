//
//  CompositionSpec.swift
//  Shallows
//
//  Created by Олег on 13.02.2018.
//  Copyright © 2018 Shallows. All rights reserved.
//

import Shallows
import Foundation

func testComposition() {
    
    describe("storage composition") {
        $0.describe("retrieve") {
            $0.it("returns front if existing") {
                let first = MemoryStorage<Int, Int>(storage: [1: 1])
                let second = MemoryStorage<Int, Int>(storage: [1: 2])
                let combined = first.combined(with: second)
                let sema = DispatchSemaphore(value: 0)
                var val: Int? = nil
                combined.retrieve(forKey: 1, completion: { (result) in
                    val = result.value
                    sema.signal()
                })
                sema.wait()
                try expect(val) == 1
            }
            $0.it("returns back if not existing, setting value back to front") {
                let first = MemoryStorage<Int, Int>()
                let second = MemoryStorage<Int, Int>(storage: [1: 2])
                let combined = first.combined(with: second)
                let sema = DispatchSemaphore(value: 0)
                var val: Int? = nil
                combined.retrieve(forKey: 1, completion: { (result) in
                    val = result.value
                    sema.signal()
                })
                sema.wait()
                try expect(val) == 2
                try expect(first.storage[1]) == 2
            }
            $0.it("fails if value is non existing in both storages") {
                let first = Storage<Int, Int>.empty()
                let second = Storage<Int, Int>.empty()
                let combined = first.combined(with: second)
                let sema = DispatchSemaphore(value: 0)
                var er: Error? = nil
                combined.retrieve(forKey: 0, completion: { (result) in
                    er = result.error
                    sema.signal()
                })
                sema.wait()
                try expect(er as? EmptyCacheError) == .cacheIsAlwaysEmpty
            }
        }
        $0.describe("set") {
            $0.it("sets to both storages") {
                let first = MemoryStorage<Int, Int>()
                let second = MemoryStorage<Int, Int>()
                let combined = first.combined(with: second)
                let sema = DispatchSemaphore(value: 0)
                combined.set(10, forKey: 1, completion: { (_) in
                    sema.signal()
                })
                sema.wait()
                try expect(first.storage[1]) == 10
                try expect(second.storage[1]) == 10
            }
            $0.it("doesnt set to back if front fails") {
                let first = Storage<Int, Int>.alwaysFailing(with: "first is failing")
                let second = MemoryStorage<Int, Int>()
                let combined = first.combined(with: second)
                let sema = DispatchSemaphore(value: 0)
                var er: Error?
                combined.set(10, forKey: 1, completion: { (res) in
                    er = res.error
                    sema.signal()
                })
                sema.wait()
                try expect(er != nil).to.beTrue()
                try expect(second.storage[1] == nil).to.beTrue()
            }
            $0.it("sets to front and fails if back fails") {
                let front = MemoryStorage<Int, Int>()
                let back = Storage<Int, Int>.alwaysFailing(with: "back fails")
                let combined = front.combined(with: back)
                let sema = DispatchSemaphore(value: 0)
                var er: Error?
                combined.set(10, forKey: 1, completion: { (res) in
                    er = res.error
                    sema.signal()
                })
                sema.wait()
                try expect(er != nil).to.beTrue()
                try expect(front.storage[1]) == 10
            }
        }
    }
    
}
