//
//  AdditionalSpec.swift
//  Shallows
//
//  Created by Олег on 21.02.2018.
//  Copyright © 2018 Shallows. All rights reserved.
//

import Shallows

func testAdditional() {
    
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
