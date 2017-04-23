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

class ShallowsTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        //// XCTAssertEqual(Shallows().text, "Hello, World!")
    }
    
    override func setUp() {
        ShallowsLog.isEnabled = true
    }
    
    func testSome() {
        let mmcch = MemoryCache<String, Int>(storage: [:], name: "mmcch")
        mmcch.set(10, forKey: "AAA", completion: { _ in })
        mmcch.retrieve(forKey: "Something") { (result) in
            print(result)
        }
        
        print("City of stars")
        
        let memeMain = MemoryCache<String, Int>(storage: [:], name: "Main")
        let meme1 = MemoryCache<String, Int>(storage: ["Some" : 15], name: "First-Back")
        let meme2 = MemoryCache<String, Int>(storage: ["Other" : 20], name: "Second-Back")//.makeReadOnly()
        
        let combined1 = meme1.bothWayCombined(with: meme2)
        let full = memeMain.combined(with: combined1)
        //combined1.retrieve(forKey: "Other", completion: { print($0) })
        //meme1.retrieve(forKey: "Other", completion: { print($0) })
        full.retrieve(forKey: "Some", completion: { print($0) })
        full.retrieve(forKey: "Other", completion: { print($0) })
        combined1.set(35, forKey: "Inter")
        meme2.retrieve(forKey: "Inter", completion: { print($0) })
        full.retrieve(forKey: "Nothing", completion: { print($0) })
    }
    
    static var allTests = [
        ("testExample", testExample),
    ]
}
