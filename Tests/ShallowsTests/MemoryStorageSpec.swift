//
//  MemoryStorageSpec.swift
//  Shallows
//
//  Created by Олег on 18.01.2018.
//  Copyright © 2018 Shallows. All rights reserved.
//

import Foundation
@testable import Shallows

func testMemoryStorage() {
    
    describe("ThreadSafe<T>") {
        $0.it("can read the value") {
            let threadSafe = ThreadSafe<Int>(15)
            try expect(threadSafe.read()) == 15
        }
        $0.it("can write to the value") {
            var threadSafe = ThreadSafe<Int>(15)
            threadSafe.write(20)
            try expect(threadSafe.read()) == 20
        }
        $0.it("can modify the value") {
            var threadSafe = ThreadSafe<Int>(15)
            threadSafe.write(with: { $0 -= 5 })
            try expect(threadSafe.read()) == 10
        }
    }
    
    describe("memory storage") {
        $0.it("always writes the value") {
            let memoryStorage = MemoryStorage<Int, Int>().makeSyncStorage()
            try memoryStorage.set(10, forKey: 10)
        }
        $0.it("reads the value") {
            let memoryStorage = MemoryStorage<Int, Int>(storage: [1 : 5]).makeSyncStorage()
            let value = try memoryStorage.retrieve(forKey: 1)
            try expect(value) == 5
        }
        $0.it("always writes and reads the value") {
            let mem = MemoryStorage<Int, Int>().singleKey(0).makeSyncStorage()
            try mem.set(10)
            let value = try mem.retrieve()
            try expect(value) == 10
        }
        $0.it("fails if there is no value") {
            let mem = MemoryStorage<Int, Int>().makeSyncStorage()
            try expect(try mem.retrieve(forKey: 10)).toThrow()
        }
        $0.it("can be modified directly") {
            let dict: [Int : Int] = [1: 5, 2: 6]
            let mem = MemoryStorage<Int, Int>(storage: dict)
            try expect(mem.storage) == dict
            mem.storage[3] = 7
            try expect(try mem.makeSyncStorage().retrieve(forKey: 3)) == 7
            var copy = dict
            copy[3] = 7
            try expect(mem.storage) == copy
        }
    }
    
}
