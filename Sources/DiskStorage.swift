//
//  DiskStorage.swift
//  Shallows
//
//  Created by Олег on 18.01.2018.
//  Copyright © 2018 Shallows. All rights reserved.
//

import Foundation

public struct FileURL {
    
    public let url: URL
    
    public init(_ url: URL) {
        self.url = url
    }
    
    public init(_ path: String) {
        self.init(URL.init(fileURLWithPath: path))
    }
    
}

public struct Filename : RawRepresentable, Hashable, ExpressibleByStringLiteral {
    
    public var hashValue: Int {
        return rawValue.hashValue
    }
    
    public var rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
    
    public init(unicodeScalarLiteral value: String) {
        self.init(rawValue: value)
    }
    
    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(rawValue: value)
    }
    
    public func base64Encoded() -> String {
        guard let data = rawValue.data(using: .utf8) else {
            return rawValue
        }
        return data.base64EncodedString()
    }
    
    public struct Transform {
        
        private let transform: (Filename) -> String
        
        private init(transform: @escaping (Filename) -> String) {
            self.transform = transform
        }
        
        public static let base64: Transform = Transform(transform: { $0.base64Encoded() })
        public static let notTransformed: Transform = Transform(transform: { $0.rawValue })
        public static func custom(_ transform: @escaping (Filename) -> String) -> Transform {
            return Transform(transform: transform)
        }
        
        public func finalForm(of filename: Filename) -> String {
            return transform(filename)
        }
        
    }
    
}

public final class DiskFolderStorage : StorageProtocol {
    
    public typealias Key = Filename
    public typealias Value = Data
    
    public let storageName: String
    public let folderURL: URL
    
    private let diskStorage: Storage<FileURL, Data>
    
    public let transformFilename: Filename.Transform
    
    public init(folderURL: URL,
                diskStorage: Storage<FileURL, Data> = DiskStorage.main.asStorage(),
                transformFilename: Filename.Transform = .base64) {
        self.diskStorage = diskStorage
        self.folderURL = folderURL
        self.transformFilename = transformFilename
        self.storageName = "disk-\(folderURL.lastPathComponent)"
    }
    
    public func fileURL(forFilename filename: Filename) -> FileURL {
        let finalForm = transformFilename.finalForm(of: filename)
        return FileURL(folderURL.appendingPathComponent(finalForm))
    }
    
    public func retrieve(forKey filename: Filename, completion: @escaping (Result<Data>) -> ()) {
        let fileURL = self.fileURL(forFilename: filename)
        diskStorage.retrieve(forKey: fileURL, completion: completion)
    }
    
    public func set(_ data: Data, forKey filename: Filename, completion: @escaping (Result<Void>) -> ()) {
        let fileURL = self.fileURL(forFilename: filename)
        diskStorage.set(data, forKey: fileURL, completion: completion)
    }
    
}

extension URL {
    
    public init(directory: FileManager.SearchPathDirectory, domainMask: FileManager.SearchPathDomainMask = .userDomainMask) {
        let urls = FileManager.default.urls(for: directory, in: domainMask)
        self = urls.first!
    }
    
}

extension DiskFolderStorage {
    
    public static func inDirectory(_ directory: FileManager.SearchPathDirectory,
                                   appending pathComponent: String,
                                   domainMask: FileManager.SearchPathDomainMask = .userDomainMask,
                                   diskStorage: Storage<FileURL, Data>,
                                   transformFilename: Filename.Transform) -> DiskFolderStorage {
        let directoryURL = URL(directory: directory, domainMask: domainMask).appendingPathComponent(pathComponent)
        return DiskFolderStorage(folderURL: directoryURL,
                                 diskStorage: diskStorage,
                                 transformFilename: transformFilename)
    }
    
}

public final class DiskStorage : StorageProtocol {
    
    public typealias Key = FileURL
    public typealias Value = Data
    
    public var storageName: String {
        return "disk"
    }
    
    private let queue: DispatchQueue = DispatchQueue(label: "disk-storage-queue", qos: .userInitiated)
    private let fileManager = FileManager.default
    
    fileprivate let creatingDirectories: Bool
    
    public init(creatingDirectories: Bool = true) {
        self.creatingDirectories = creatingDirectories
    }
    
    public func retrieve(forKey key: FileURL, completion: @escaping (Result<Data>) -> ()) {
        queue.async {
            do {
                let data = try Data.init(contentsOf: key.url)
                completion(succeed(with: data))
            } catch {
                completion(fail(with: error))
            }
        }
    }
    
    public enum Error : Swift.Error {
        case cantCreatFile
        case cantCreateDirectory(Swift.Error)
    }
    
    public func set(_ value: Data, forKey key: FileURL, completion: @escaping (Result<Void>) -> ()) {
        queue.async {
            do {
                try self.createDirectoryURLIfNotExisting(for: key)
                let path = key.url.path
                if self.fileManager.createFile(atPath: path,
                                               contents: value,
                                               attributes: nil) {
                    completion(.success)
                } else {
                    completion(fail(with: Error.cantCreatFile))
                }
            } catch {
                completion(fail(with: error))
            }
        }
    }
    
    public static func directoryURL(of fileURL: FileURL) -> URL {
        return fileURL.url.deletingLastPathComponent()
    }
    
    fileprivate func createDirectoryURLIfNotExisting(for fileURL: FileURL) throws {
        let directoryURL = DiskStorage.directoryURL(of: fileURL)
        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(at: directoryURL,
                                                withIntermediateDirectories: true,
                                                attributes: nil)
            } catch {
                throw Error.cantCreateDirectory(error)
            }
        }
    }
    
}

extension DiskStorage {
    
    public static let main = DiskStorage(creatingDirectories: true)
    
    public func folder(_ folderName: String,
                       in directory: FileManager.SearchPathDirectory,
                       domainMask: FileManager.SearchPathDomainMask = .userDomainMask,
                       transformFilename: Filename.Transform = .base64) -> DiskFolderStorage {
        return DiskFolderStorage.inDirectory(
            directory,
            appending: folderName,
            diskStorage: self.asStorage(),
            transformFilename: transformFilename
        )
    }
    
}
