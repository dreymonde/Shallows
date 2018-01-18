import Foundation

public protocol FileSystemStorageProtocol : StorageProtocol {
    
    init(directoryURL: URL, qos: DispatchQoS, storageName: String?)
    
}

extension FileSystemStorageProtocol {

    @available(*, deprecated, message: "Use DiskStorage family instead")
    public static func inDirectory(_ directory: FileManager.SearchPathDirectory,
                                   appending pathComponent: String,
                                   domainMask: FileManager.SearchPathDomainMask = .userDomainMask,
                                   qos: DispatchQoS = .default,
                                   storageName: String? = nil) -> Self {
        let urls = FileManager.default.urls(for: directory, in: domainMask)
        let url = urls.first!.appendingPathComponent(pathComponent, isDirectory: true)
        return Self(directoryURL: url, qos: qos, storageName: storageName)
    }
    
}

@available(*, deprecated, message: "Use DiskStorage family instead")
public final class FileSystemStorage : FileSystemStorageProtocol {
    
    public static func validFilename(for key: Filename) -> Filename {
        guard let data = key.rawValue.data(using: .utf8) else { return key }
        return Filename(rawValue: data.base64EncodedString(options: []))
    }
    
    public var directoryURL: URL {
        return raw.directoryURL
    }
    
    public var storageName: String {
        return raw.storageName
    }
    
    internal var pruneOnDeinit: Bool {
        get { return raw.pruneOnDeinit }
        set { raw.pruneOnDeinit = newValue }
    }
    
    public let raw: RawFileSystemStorage
    private let rawMapped: Storage<Filename, Data>
    
    public init(directoryURL: URL, qos: DispatchQoS = .default, storageName: String? = nil) {
        self.raw = RawFileSystemStorage(directoryURL: directoryURL, qos: qos, storageName: storageName)
        self.rawMapped = raw.mapKeys({ RawFileSystemStorage.FileName(validFileName: FileSystemStorage.validFilename(for: $0)) })
    }
    
    public func retrieve(forKey key: Filename, completion: @escaping (Result<Data>) -> ()) {
        rawMapped.retrieve(forKey: key, completion: completion)
    }
    
    public func set(_ value: Data, forKey key: Filename, completion: @escaping (Result<Void>) -> ()) {
        rawMapped.set(value, forKey: key, completion: completion)
    }
    
}

@available(*, deprecated, message: "Use DiskStorage family instead")
public final class RawFileSystemStorage : FileSystemStorageProtocol {
    
    public struct FileName {
        public let fileName: String
        public init(validFileName: Filename) {
            self.fileName = validFileName.rawValue
        }
        
        @available(*, unavailable, renamed: "init(validFileName:)")
        public init(_ fileName: String) {
            self.fileName = fileName
        }
    }
    
    public let storageName: String
    public let directoryURL: URL
    
    internal var pruneOnDeinit: Bool = false
    
    fileprivate let fileManager = FileManager.default
    fileprivate let queue: DispatchQueue
    
    public init(directoryURL: URL, qos: DispatchQoS = .default, storageName: String? = nil) {
        self.directoryURL = directoryURL
        self.storageName = storageName ?? "file-system-storage"
        self.queue = DispatchQueue(label: "\(self.storageName)-file-system-storage-queue", qos: qos)
    }
    
    deinit {
        if pruneOnDeinit {
            do { try fileManager.removeItem(at: directoryURL) } catch { }
        }
    }
    
    public enum Error : ShallowsError {
        case cantCreateDirectory(Swift.Error)
        case cantCreateFile
        
        public var isTransient: Bool {
            switch self {
            case .cantCreateFile:
                return false
            case .cantCreateDirectory:
                return false
            }
        }
    }
    
    public func set(_ value: Data, forKey key: FileName, completion: @escaping (Result<Void>) -> ()) {
        queue.async {
            do {
                try self.createDirectoryURLIfNotExisting()
                let path = self.directoryURL.appendingPathComponent(key.fileName).path
                if self.fileManager.createFile(atPath: path,
                                               contents: value,
                                               attributes: nil) {
                    completion(.success)
                } else {
                    completion(.failure(Error.cantCreateFile))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    fileprivate func createDirectoryURLIfNotExisting() throws {
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
    
    public func retrieve(forKey key: FileName, completion: @escaping (Result<Data>) -> ()) {
        queue.async {
            let path = self.directoryURL.appendingPathComponent(key.fileName)
            do {
                let data = try Data(contentsOf: path)
                completion(.success(data))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
}
