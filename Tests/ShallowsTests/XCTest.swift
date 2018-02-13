//
//  XCTest.swift
//  Shallows
//
//  Created by Олег on 18.01.2018.
//  Copyright © 2018 Shallows. All rights reserved.
//

import XCTest
import Shallows
#if os(iOS)
    import UIKit
#endif

class ShallowsXCTests : XCTestCase {
    
    func testShallows() {
        testMemoryStorage()
        testDiskStorage()
        testResult()
        testZip()
        testComposition()
    }
    
}



func readme() {
    struct City : Codable {
        let name: String
        let foundationYear: Int
    }

    let diskStorage = DiskStorage.main.folder("cities", in: .cachesDirectory)
        .mapJSONObject(City.self)

    diskStorage.retrieve(forKey: "Beijing") { (result) in
        if let city = result.value { print(city) }
    }

    let kharkiv = City(name: "Kharkiv", foundationYear: 1654)
    diskStorage.set(kharkiv, forKey: "Kharkiv")
}

func readme2() {
    #if os(iOS)
        let storage = DiskStorage.main.folder("images", in: .cachesDirectory)
        let images = storage
            .mapValues(to: UIImage.self,
                       transformIn: { data in try UIImage.init(data: data).getValue() },
                       transformOut: { image in try UIImagePNGRepresentation(image).getValue() })
        
        enum ImageKeys : String {
            case kitten, puppy, fish
        }
        
        let keyedImages = images
            .usingStringKeys()
            .mapKeys(toRawRepresentableType: ImageKeys.self)
        
        keyedImages.retrieve(forKey: .kitten, completion: { result in /* .. */ })
    #endif
}

func readme3() {
    let immutableFileStorage = DiskStorage.main.folder("immutable", in: .applicationSupportDirectory)
        .mapString(withEncoding: .utf8)
        .asReadOnlyStorage()
    let storage = MemoryStorage<Filename, String>()
        .backed(by: immutableFileStorage)
        .asReadOnlyStorage() // ReadOnlyStorage<Filename, String>
    print(storage)
}

func readme4() {
//    let settingsStorage = FileSystemStorage.inDirectory(.documentDirectory, appending: "settings")
//        .mapJSONDictionary()
//        .singleKey("settings") // Storage<Void, [String : Any]>
//    settingsStorage.retrieve { (result) in
//        // ...
//    }
    let settings = DiskStorage.main.folder("settings", in: .applicationSupportDirectory)
        .mapJSONDictionary()
        .singleKey("settings") // Storage<Void, [String : Any]>
    settings.retrieve { (result) in
        // ...
    }
}

func readme5() throws {
    let strings = DiskStorage.main.folder("strings", in: .cachesDirectory)
        .mapString(withEncoding: .utf8)
        .makeSyncStorage() // SyncStorage<String, String>
    let existing = try strings.retrieve(forKey: "hello")
    try strings.set(existing.uppercased(), forKey: "hello")
}

func readme6() {
    let arrays = MemoryStorage<String, [Int]>()
    arrays.update(forKey: "some-key", { $0.append(10) })
}

func readme7() {
    let strings = MemoryStorage<String, String>()
    let numbers = MemoryStorage<String, Int>()
    let zipped = zip(strings, numbers) // Storage<String, (String, Int)>
    zipped.retrieve(forKey: "some-key") { (result) in
        if let (string, number) = result.value {
            print(string)
            print(number)
        }
    }
    zipped.set(("shallows", 3), forKey: "another-key")
}
