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
    
    describe("read-only storage composition") {
        $0.describe("backed") {
            $0.it("returns front if existing") {
                let front = MemoryStorage<Int, Int>(storage: [1: 1]).asReadOnlyStorage()
                let back = MemoryStorage<Int, Int>(storage: [1: 2]).asReadOnlyStorage()
                let backed = front.backed(by: back)
                let sema = DispatchSemaphore(value: 0)
                var val: Int?
                backed.retrieve(forKey: 1, completion: { (result) in
                    val = result.value
                    sema.signal()
                })
                sema.wait()
                try expect(val) == 1
            }
            $0.it("returns back if front is missing") {
                let front = ReadOnlyStorage<Int, Int>.empty()
                let back = MemoryStorage<Int, Int>(storage: [1: 2])
                let backed = front.backed(by: back)
                let sema = DispatchSemaphore(value: 0)
                var val: Int?
                backed.retrieve(forKey: 1, completion: { (result) in
                    val = result.value
                    sema.signal()
                })
                sema.wait()
                try expect(val) == 2
            }
            $0.it("fails if both fail") {
                let front = ReadOnlyStorage<Int, Int>.empty()
                let back = ReadOnlyStorage<Int, Int>.alwaysFailing(with: "back fails")
                let backed = front.backed(by: back)
                let sema = DispatchSemaphore(value: 0)
                var er: Error?
                backed.retrieve(forKey: 1, completion: { (result) in
                    er = result.error
                    sema.signal()
                })
                sema.wait()
                try expect(er as? String) == "back fails"
            }
        }
    }
    
    describe("writable storage composition") {
        $0.describe("pushingto") {
            $0.it("pushes to front and back") {
                let front = MemoryStorage<Int, Int>()
                let back = MemoryStorage<Int, Int>()
                let pushing = front.asWriteOnlyStorage().pushing(to: back.asWriteOnlyStorage())
                let sema = DispatchSemaphore(value: 0)
                var er: Error?
                pushing.set(10, forKey: 1, completion: { (result) in
                    er = result.error
                    sema.signal()
                })
                sema.wait()
                try expect(er).to.beNil()
                try expect(front.storage[1]) == 10
                try expect(back.storage[1]) == 10
            }
            $0.it("doesnt set to back if front fails") {
                let front = Storage<Int, Int>.alwaysFailing(with: "front is failing")
                let back = MemoryStorage<Int, Int>()
                let pushing = front.asWriteOnlyStorage().pushing(to: back.asWriteOnlyStorage())
                let sema = DispatchSemaphore(value: 0)
                var er: Error?
                pushing.set(10, forKey: 1, completion: { (res) in
                    er = res.error
                    sema.signal()
                })
                sema.wait()
                try expect(er as? String) == "front is failing"
                try expect(back.storage[1] == nil).to.beTrue()
            }
            $0.it("sets to front and fails if back fails") {
                let front = MemoryStorage<Int, Int>()
                let back = Storage<Int, Int>.alwaysFailing(with: "back fails")
                let pushing = front.asWriteOnlyStorage().pushing(to: back.asWriteOnlyStorage())
                let sema = DispatchSemaphore(value: 0)
                var er: Error?
                pushing.set(10, forKey: 1, completion: { (res) in
                    er = res.error
                    sema.signal()
                })
                sema.wait()
                try expect(er as? String) == "back fails"
                try expect(front.storage[1]) == 10
            }
        }
    }
    
    describe("storage composition") {
        
        $0.describe("backed") {
            $0.it("returns front if existing") {
                let front = MemoryStorage<Int, Int>(storage: [1: 1])
                let back = MemoryStorage<Int, Int>(storage: [1: 2]).asReadOnlyStorage()
                let backed = front.backed(by: back)
                let sema = DispatchSemaphore(value: 0)
                var val: Int? = nil
                backed.retrieve(forKey: 1, completion: { (result) in
                    val = result.value
                    sema.signal()
                })
                sema.wait()
                try expect(val) == 1
            }
            $0.it("returns back if not existing, setting value back to front") {
                let front = MemoryStorage<Int, Int>()
                let back = MemoryStorage<Int, Int>(storage: [1: 2]).asReadOnlyStorage()
                let combined = front.backed(by: back)
                let sema = DispatchSemaphore(value: 0)
                var val: Int? = nil
                combined.retrieve(forKey: 1, completion: { (result) in
                    val = result.value
                    sema.signal()
                })
                sema.wait()
                try expect(val) == 2
                try expect(front.storage[1]) == 2
            }
            $0.it("fails if value is non existing in both storages") {
                let front = Storage<Int, Int>.empty()
                let back = Storage<Int, Int>.empty().asReadOnlyStorage()
                let backed = front.backed(by: back)
                let sema = DispatchSemaphore(value: 0)
                var er: Error? = nil
                backed.retrieve(forKey: 0, completion: { (result) in
                    er = result.error
                    sema.signal()
                })
                sema.wait()
                try expect(er as? EmptyCacheError) == .cacheIsAlwaysEmpty
            }
            $0.it("sets to front") {
                let front = MemoryStorage<Int, Int>()
                let back = MemoryStorage<Int, Int>().asReadOnlyStorage()
                let backed = front.backed(by: back)
                let sema = DispatchSemaphore(value: 0)
                backed.set(10, forKey: 1, completion: { (_) in
                    sema.signal()
                })
                sema.wait()
                try expect(front.storage[1]) == 10
            }
            $0.it("fails if front set fails") {
                let front = Storage<Int, Int>.alwaysFailing(with: "front fails")
                let back = MemoryStorage<Int, Int>().asReadOnlyStorage()
                let backed = front.backed(by: back)
                var er: Error?
                let sema = DispatchSemaphore(value: 0)
                backed.set(10, forKey: 1, completion: { (result) in
                    er = result.error
                    sema.signal()
                })
                sema.wait()
                try expect(er as? String) == "front fails"
            }
        }
        
        $0.describe("combined") {
            $0.describe("retrieve") {
                $0.it("returns front if existing") {
                    let front = MemoryStorage<Int, Int>(storage: [1: 1])
                    let back = MemoryStorage<Int, Int>(storage: [1: 2])
                    let combined = front.combined(with: back)
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
                    let front = MemoryStorage<Int, Int>()
                    let back = MemoryStorage<Int, Int>(storage: [1: 2])
                    let combined = front.combined(with: back)
                    let sema = DispatchSemaphore(value: 0)
                    var val: Int? = nil
                    combined.retrieve(forKey: 1, completion: { (result) in
                        val = result.value
                        sema.signal()
                    })
                    sema.wait()
                    try expect(val) == 2
                    try expect(front.storage[1]) == 2
                }
                $0.it("fails if value is non existing in both storages") {
                    let front = Storage<Int, Int>.empty()
                    let back = Storage<Int, Int>.empty()
                    let combined = front.combined(with: back)
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
                    let front = MemoryStorage<Int, Int>()
                    let back = MemoryStorage<Int, Int>()
                    let combined = front.combined(with: back)
                    let sema = DispatchSemaphore(value: 0)
                    combined.set(10, forKey: 1, completion: { (_) in
                        sema.signal()
                    })
                    sema.wait()
                    try expect(front.storage[1]) == 10
                    try expect(back.storage[1]) == 10
                }
                $0.it("doesnt set to back if front fails") {
                    let front = Storage<Int, Int>.alwaysFailing(with: "front is failing")
                    let back = MemoryStorage<Int, Int>()
                    let combined = front.combined(with: back)
                    let sema = DispatchSemaphore(value: 0)
                    var er: Error?
                    combined.set(10, forKey: 1, completion: { (res) in
                        er = res.error
                        sema.signal()
                    })
                    sema.wait()
                    try expect(er as? String) == "front is failing"
                    try expect(back.storage[1] == nil).to.beTrue()
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
                    try expect(er as? String) == "back fails"
                    try expect(front.storage[1]) == 10
                }
            }
            
        }
        
    }
    
}
