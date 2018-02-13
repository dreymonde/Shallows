//
//  ResultSpec.swift
//  Shallows
//
//  Created by Олег on 13.02.2018.
//  Copyright © 2018 Shallows. All rights reserved.
//

import Foundation
import Shallows

public func testResult() {
    
    describe("result") {
        $0.it("can be a failure") {
            let failure = Result<Int>.failure("Test")
            try expect(failure.isFailure) == true
            try expect(failure.isSuccess) == false
        }
        $0.it("can be a success") {
            let success = Result.success(10)
            try expect(success.isSuccess) == true
            try expect(success.isFailure) == false
        }
        $0.it("contains a value if it's a success") {
            let success = succeed(with: 15)
            try expect(success.value) == 15
            try expect(success.error).to.beNil()
        }
        $0.it("contains an error if it's a failure") {
            let failure: Result<Int> = fail(with: "Test")
            try expect(failure.error as? String) == "Test"
            try expect(failure.value).to.beNil()
        }
    }
    
}
