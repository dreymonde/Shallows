//
//  DiskStorageTests.swift
//  Shallows
//
//  Created by Олег on 18.01.2018.
//  Copyright © 2018 Shallows. All rights reserved.
//

import Foundation
@testable import Shallows

func testDiskStorage() {
    
    let currentDir = FileManager.default.currentDirectoryPath
    print("CURRENT DIR", currentDir)
    let currentDirURL = URL.init(fileURLWithPath: currentDir)
    
    describe("filename type") {
        let example = "spectre.cool"
        let filename = Filename(rawValue: example)
        $0.it("has a raw value") {
            try expect(filename.rawValue) == example
        }
        $0.it("is hashable") {
            let anotherValue = Filename(rawValue: example)
            try expect(anotherValue.hashValue) == filename.hashValue
        }
        $0.it("encodes to base64") {
            let data = example.data(using: .utf8)!
            let base64 = data.base64EncodedString()
            try expect(filename.base64Encoded()) == base64
        }
        $0.describe("encodes") {
            $0.it("to base64") {
                let data = example.data(using: .utf8)!
                let base64 = data.base64EncodedString()
                try expect(Filename.Encoder.base64.encodedString(representing: filename)) == base64
            }
            $0.it("to base64url") {
                let data = example.data(using: .utf8)!
                let base64 = data.base64EncodedString()
                    .replacingOccurrences(of: "+", with: "-")
                    .replacingOccurrences(of: "/", with: "_")
                try expect(Filename.Encoder.base64URL.encodedString(representing: filename)) == base64
//                try expect(base64.contains("+")) == false
//                try expect(base64.contains("/")) == false
            }
            $0.it("without encoding") {
                try expect(Filename.Encoder.noEncoding.encodedString(representing: filename)) == example
            }
            $0.it("with custom encoding") {
                let custom = Filename.Encoder.custom({ $0.rawValue.uppercased() })
                try expect(custom.encodedString(representing: filename)) == example.uppercased()
            }
        }
    }
    
    describe("disk storage") {
        $0.describe("helper methods") {
            $0.it("retrieve directory URL from file URL") {
                let fileURL = currentDirURL.appendingPathComponent("cool.json")
                let directoryURL = DiskStorage.directoryURL(of: fileURL)
                try expect(directoryURL) == currentDirURL
            }
        }
        $0.describe("when !creatingDirectories") {
            let unknownDirectoryURL = currentDirURL.appendingPathComponent("_unknown", isDirectory: true)
            let clear = { deleteEverything(at: unknownDirectoryURL) }
            $0.before(clear)
            $0.it("fails if directory doesn't exist") {
                let diskStorage = DiskStorage(creatingDirectories: false).mapString().makeSyncStorage()
                let fileURL = unknownDirectoryURL.appendingPathComponent("nope.json")
                try expect(try diskStorage.set("none", forKey: fileURL)).toThrow()
            }
            $0.after(clear)
        }
        $0.describe("performs") {
            let filename = "_ronaldo.json"
            let dirURL = currentDirURL.appendingPathComponent("_tmp_test", isDirectory: true)
            let tempFileURL = dirURL.appendingPathComponent(filename)
            let disk = DiskStorage.main
                .mapString()
                .makeSyncStorage()
            let clear = { deleteEverything(at: dirURL) }
            $0.before(clear)
            $0.it("writes") {
                try disk.set("25:12", forKey: tempFileURL)
            }
            $0.it("reads") {
                let data = "25:12".data(using: .utf8)
                try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: false, attributes: nil)
                FileManager.default.createFile(atPath: tempFileURL.path, contents: data, attributes: nil)
                let back = try disk.retrieve(forKey: tempFileURL)
                try expect(back) == "25:12"
            }
            $0.it("writes and reads") {
                let string = "penalty"
                try disk.set(string, forKey: tempFileURL)
                let back = try disk.retrieve(forKey: tempFileURL)
                try expect(back) == string
            }
            $0.it("fails when there is no file") {
                try expect(try disk.retrieve(forKey: tempFileURL)).toThrow()
            }
            $0.after(clear)
        }
    }
    
    describe("folder storage") {
        $0.describe("helper methods") {
            $0.it("creates URL for search path directory") {
                let directoryURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                let createdURL = DiskFolderStorage.url(forFolder: "Wigan", in: .cachesDirectory)
                try expect(createdURL) == directoryURL.appendingPathComponent("Wigan", isDirectory: true)
            }
        }
        $0.it("can be created in one of a FileManager.SearchPathDirectory") {
            let folderURL = DiskFolderStorage.url(forFolder: "ManUTD", in: .cachesDirectory)
            let folderStorage = DiskFolderStorage.inDirectory(.cachesDirectory, folderName: "ManUTD", diskStorage: .empty(), filenameEncoder: .noEncoding)
            try expect(folderStorage.folderURL) == folderURL
        }
        $0.it("can be created by disk storage") {
            let folderURL = DiskFolderStorage.url(forFolder: "Scholes", in: .cachesDirectory)
            let folder = DiskStorage.main.folder("Scholes", in: .cachesDirectory)
            try expect(folder.folderURL) == folderURL
            
            let folderURL2 = DiskFolderStorage.url(forFolder: "Rooney", in: .cachesDirectory)
            let folder2 = DiskStorage.folder("Rooney", in: .cachesDirectory)
            try expect(folder2.folderURL) == folderURL2
        }
        $0.it("encodes filename") {
            func storage(encoder: Filename.Encoder) -> DiskFolderStorage {
                return DiskFolderStorage.inDirectory(.cachesDirectory, folderName: "aaa", diskStorage: .empty(), filenameEncoder: encoder)
            }
            func checkStorage(for encoder: Filename.Encoder) throws {
                let example: Filename = "Nineties"
                let str = storage(encoder: encoder)
                try expect(str.fileURL(forFilename: example)) == str.folderURL.appendingPathComponent(encoder.encodedString(representing: example))
            }
            try checkStorage(for: .base64)
            try checkStorage(for: .noEncoding)
            try checkStorage(for: .custom({ $0.rawValue.uppercased() }))
        }
        $0.it("really encodes filename") {
            var isFilenameCorrect = true
            let customStorage = MemoryStorage<URL, Data>()
                .mapKeys({ (url: URL) -> URL in
                    if url.lastPathComponent != "modified-filename" {
                        isFilenameCorrect = false
                    }
                    return url
                })
            let storage = DiskFolderStorage(folderURL: currentDirURL, diskStorage: customStorage, filenameEncoder: .custom({ _ in "modified-filename" }))
                .mapString()
                .makeSyncStorage()
            try storage.set("doesn't matter", forKey: "key-to-be-modified")
            _ = try storage.retrieve(forKey: "another-to-be-modified-key")
            try expect(isFilenameCorrect).to.beTrue()
        }
        $0.it("uses injected storage") {
            let folder = DiskFolderStorage(folderURL: currentDirURL, diskStorage: .alwaysSucceeding(with: "great".data(using: .utf8)!))
                .mapString(withEncoding: .utf8)
                .makeSyncStorage()
            let value = try folder.retrieve(forKey: "any-key")
            try expect(value) == "great"
        }
        $0.it("writes and reads") {
            let folder = DiskFolderStorage(folderURL: currentDirURL, diskStorage: MemoryStorage().asStorage())
                .mapString()
                .singleKey("Oh my god")
                .makeSyncStorage()
            try folder.set("Wigan-ManUTD")
            let back = try folder.retrieve()
            try expect(back) == "Wigan-ManUTD"
        }
        $0.it("can clear its folder") {
            let folder = DiskFolderStorage(folderURL: currentDirURL.appendingPathComponent("_should_be_cleared", isDirectory: true))
            let folderURL = folder.folderURL
            try folder
                .mapString()
                .makeSyncStorage()
                .set("Scholes", forKey: "some-key")
            let exists: () -> Bool = {
                return FileManager.default.fileExists(atPath: folderURL.path)
            }
            try expect(exists()).to.beTrue()
            folder.clear()
            try expect(exists()).to.beFalse()
        }
    }
    
}

fileprivate func deleteEverything(at url: URL) {
    do {
        try FileManager.default.removeItem(at: url)
    } catch { }
}
