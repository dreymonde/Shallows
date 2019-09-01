//
//  DiskStorage.swift
//  Shallows
//
//  Created by Олег on 18.01.2018.
//  Copyright © 2018 Shallows. All rights reserved.
//

import Foundation

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
        let finalForm = filenameEncoder.encodedString(representing: filename)
        return folderURL.appendingPathComponent(finalForm)
    }
    
    public func retrieve(forKey filename: Filename) -> ShallowsFuture<Data> {
        let fileURL = self.fileURL(forFilename: filename)
        return diskStorage.retrieve(forKey: fileURL)
    }
    
    public func set(_ data: Data, forKey filename: Filename) -> ShallowsFuture<Void> {
        let fileURL = self.fileURL(forFilename: filename)
        return diskStorage.set(data, forKey: fileURL)
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
    
    public func retrieve(forKey key: URL) -> ShallowsFuture<Data> {
        return ShallowsFuture { promise in
            queue.async {
                do {
                    let data = try Data.init(contentsOf: key)
                    promise.succeed(value: data)
                } catch {
                    promise.fail(error: error)
                }
            }
        }
    }
    
    public enum Error : Swift.Error {
        case cantCreateFile
        case cantCreateDirectory(Swift.Error)
    }
    
    public func set(_ value: Data, forKey key: URL) -> ShallowsFuture<Void> {
        return ShallowsFuture { promise in
            queue.async {
                do {
                    try self.createDirectoryURLIfNotExisting(for: key)
                    let path = key.path
                    if self.fileManager.createFile(atPath: path,
                                                   contents: value,
                                                   attributes: nil) {
                        promise.succeed(value: ())
                    } else {
                        promise.fail(error: Error.cantCreateFile)
                    }
                } catch {
                    promise.fail(error: error)
                }
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
