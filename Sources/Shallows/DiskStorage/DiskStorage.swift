//
//  DiskStorage.swift
//  Shallows
//
//  Created by Олег on 18.01.2018.
//  Copyright © 2018 Shallows. All rights reserved.
//

import Foundation

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
            print("Something is very, very wrong: string \(rawValue) cannot be encoded with utf8")
            return rawValue
        }
        return data.base64EncodedString()
    }
    
    public struct Encoder {
        
        private let encode: (Filename) -> String
        
        private init(encode: @escaping (Filename) -> String) {
            self.encode = encode
        }
        
        public static let base64: Encoder = Encoder(encode: { $0.base64Encoded() })
        public static let noEncoding: Encoder = Encoder(encode: { $0.rawValue })
        public static func custom(_ encode: @escaping (Filename) -> String) -> Encoder {
            return Encoder(encode: encode)
        }
        
        public func finalForm(of filename: Filename) -> String {
            return encode(filename)
        }
        
    }
    
}

public final class DiskFolderStorage : StorageProtocol {
    
    public let storageName: String
    public let folderURL: URL
    
    private let diskStorage: Storage<URL, Data>
    
    public let filenameEncoder: Filename.Encoder
    
    public var clearsOnDeinit = false
    
    public init(folderURL: URL,
                diskStorage: Storage<URL, Data> = DiskStorage.main.asStorage(),
                filenameEncoder: Filename.Encoder = .base64) {
        self.diskStorage = diskStorage
        self.folderURL = folderURL
        self.filenameEncoder = filenameEncoder
        self.storageName = "disk-\(folderURL.lastPathComponent)"
    }
    
    deinit {
        if clearsOnDeinit {
            clear()
        }
    }
    
    public func clear() {
        do {
            try FileManager.default.removeItem(at: folderURL)
        } catch { }
    }
    
    public func fileURL(forFilename filename: Filename) -> URL {
        let finalForm = filenameEncoder.finalForm(of: filename)
        return folderURL.appendingPathComponent(finalForm)
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
    
    fileprivate init(directory: FileManager.SearchPathDirectory, domainMask: FileManager.SearchPathDomainMask = .userDomainMask) {
        let urls = FileManager.default.urls(for: directory, in: domainMask)
        self = urls[0]
    }
    
}

extension DiskFolderStorage {
    
    public static func url(forFolder folderName: String, in directory: FileManager.SearchPathDirectory, domainMask: FileManager.SearchPathDomainMask = .userDomainMask) -> URL {
        let folderURL = URL(directory: directory, domainMask: domainMask).appendingPathComponent(folderName, isDirectory: true)
        return folderURL
    }
    
    public static func inDirectory(_ directory: FileManager.SearchPathDirectory,
                                   folderName: String,
                                   domainMask: FileManager.SearchPathDomainMask = .userDomainMask,
                                   diskStorage: Storage<URL, Data>,
                                   filenameEncoder: Filename.Encoder) -> DiskFolderStorage {
        let directoryURL = url(forFolder: folderName, in: directory, domainMask: domainMask)
        return DiskFolderStorage(folderURL: directoryURL,
                                 diskStorage: diskStorage,
                                 filenameEncoder: filenameEncoder)
    }
    
}

public final class DiskStorage : StorageProtocol {
    
    public var storageName: String {
        return "disk"
    }
    
    private let queue: DispatchQueue = DispatchQueue(label: "disk-storage-queue", qos: .userInitiated)
    private let fileManager = FileManager.default
    
    internal let creatingDirectories: Bool
    
    public init(creatingDirectories: Bool = true) {
        self.creatingDirectories = creatingDirectories
    }
    
    public func retrieve(forKey key: URL, completion: @escaping (Result<Data>) -> ()) {
        queue.async {
            do {
                let data = try Data.init(contentsOf: key)
                completion(succeed(with: data))
            } catch {
                completion(fail(with: error))
            }
        }
    }
    
    public enum Error : Swift.Error {
        case cantCreateFile
        case cantCreateDirectory(Swift.Error)
    }
    
    public func set(_ value: Data, forKey key: URL, completion: @escaping (Result<Void>) -> ()) {
        queue.async {
            do {
                try self.createDirectoryURLIfNotExisting(for: key)
                let path = key.path
                if self.fileManager.createFile(atPath: path,
                                               contents: value,
                                               attributes: nil) {
                    completion(.success)
                } else {
                    completion(fail(with: Error.cantCreateFile))
                }
            } catch {
                completion(fail(with: error))
            }
        }
    }
    
    public static func directoryURL(of fileURL: URL) -> URL {
        return fileURL.deletingLastPathComponent()
    }
    
    fileprivate func createDirectoryURLIfNotExisting(for fileURL: URL) throws {
        guard creatingDirectories else {
            return
        }
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
    
    public static func folder(_ folderName: String,
                              in directory: FileManager.SearchPathDirectory,
                              domainMask: FileManager.SearchPathDomainMask = .userDomainMask,
                              filenameEncoder: Filename.Encoder = .base64) -> DiskFolderStorage {
        return DiskStorage.main.folder(folderName, in: directory, domainMask: domainMask, filenameEncoder: filenameEncoder)
    }
    
    public func folder(_ folderName: String,
                       in directory: FileManager.SearchPathDirectory,
                       domainMask: FileManager.SearchPathDomainMask = .userDomainMask,
                       filenameEncoder: Filename.Encoder = .base64) -> DiskFolderStorage {
        return DiskFolderStorage.inDirectory(
            directory,
            folderName: folderName,
            diskStorage: self.asStorage(),
            filenameEncoder: filenameEncoder
        )
    }
    
}
