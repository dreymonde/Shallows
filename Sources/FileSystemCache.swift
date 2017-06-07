import Foundation

public protocol FileSystemCacheProtocol : CacheProtocol {
    
    init(directoryURL: URL, qos: DispatchQoS, cacheName: String?)
    
}

extension FileSystemCacheProtocol {
    
    public static func inDirectory(_ directory: FileManager.SearchPathDirectory,
                                   appending pathComponent: String,
                                   domainMask: FileManager.SearchPathDomainMask = .userDomainMask,
                                   qos: DispatchQoS = .default,
                                   cacheName: String? = nil) -> Self {
        let urls = FileManager.default.urls(for: directory, in: domainMask)
        let url = urls.first!.appendingPathComponent(pathComponent, isDirectory: true)
        return Self(directoryURL: url, qos: qos, cacheName: cacheName)
    }
    
}

public final class FileSystemCache : FileSystemCacheProtocol {
    
    public static func fileName(for key: String) -> String {
        guard let data = key.data(using: .utf8) else { return key }
        return data.base64EncodedString(options: [])
    }
    
    public var directoryURL: URL {
        return raw.directoryURL
    }
    
    public var cacheName: String {
        return raw.cacheName
    }
    
    internal var pruneOnDeinit: Bool {
        get { return raw.pruneOnDeinit }
        set { raw.pruneOnDeinit = newValue }
    }
    
    public let raw: RawFileSystemCache
    private let rawMapped: Cache<String, Data>
    
    public init(directoryURL: URL, qos: DispatchQoS = .default, cacheName: String? = nil) {
        self.raw = RawFileSystemCache(directoryURL: directoryURL, qos: qos, cacheName: cacheName)
        self.rawMapped = raw.mapKeys({ RawFileSystemCache.FileName(FileSystemCache.fileName(for: $0)) })
    }
    
    public func retrieve(forKey key: String, completion: @escaping (Result<Data>) -> ()) {
        rawMapped.retrieve(forKey: key, completion: completion)
    }
    
    public func set(_ value: Data, forKey key: String, completion: @escaping (Result<Void>) -> ()) {
        rawMapped.set(value, forKey: key, completion: completion)
    }
    
}

public final class RawFileSystemCache : FileSystemCacheProtocol {
    
    public struct FileName {
        public let fileName: String
        public init(_ fileName: String) {
            self.fileName = fileName
        }
    }
    
    public let cacheName: String
    public let directoryURL: URL
    
    internal var pruneOnDeinit: Bool = false
    
    fileprivate let fileManager = FileManager.default
    fileprivate let queue: DispatchQueue
    
    public init(directoryURL: URL, qos: DispatchQoS = .default, cacheName: String? = nil) {
        self.directoryURL = directoryURL
        self.cacheName = cacheName ?? "file-system-cache"
        self.queue = DispatchQueue(label: "\(self.cacheName)-file-system-cache-queue", qos: qos)
    }
    
    deinit {
        if pruneOnDeinit {
            do { try fileManager.removeItem(at: directoryURL) } catch { }
        }
    }
    
    public enum Error : Swift.Error {
        case cantCreateDirectory(Swift.Error)
        case cantCreateFile
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

extension CacheProtocol where Value == Data {
    
    public func mapJSON() -> Cache<Key, Any> {
        return mapValues(transformIn: { try JSONSerialization.jsonObject(with: $0, options: []) },
                         transformOut: { try JSONSerialization.data(withJSONObject: $0, options: []) })
    }
    
    public func mapJSONDictionary() -> Cache<Key, [String : Any]> {
        return mapJSON().mapValues(transformIn: throwing({ $0 as? [String : Any] }),
                                   transformOut: { $0 })
    }
    
    public func mapPlist(format: PropertyListSerialization.PropertyListFormat = .xml) -> Cache<Key, Any> {
        return mapValues(transformIn: { data in
            var formatRef = format
            return try PropertyListSerialization.propertyList(from: data, options: [], format: &formatRef)
        }, transformOut: { plist in
            return try PropertyListSerialization.data(fromPropertyList: plist, format: format, options: 0)
        })
    }
    
    public func mapPlistDictionary(format: PropertyListSerialization.PropertyListFormat = .xml) -> Cache<Key, [String : Any]> {
        return mapPlist(format: format).mapValues(transformIn: throwing({ $0 as? [String : Any] }),
                                                  transformOut: { $0 })
    }
    
    public func mapString(withEncoding encoding: String.Encoding = .utf8) -> Cache<Key, String> {
        return mapValues(transformIn: throwing({ String(data: $0, encoding: encoding) }),
                         transformOut: throwing({ $0.data(using: encoding) }))
    }
    
}

extension ReadOnlyCache where Value == Data {
    
    public func mapJSON() -> ReadOnlyCache<Key, Any> {
        return mapValues({ try JSONSerialization.jsonObject(with: $0, options: []) })
    }
    
    public func mapJSONDictionary() -> ReadOnlyCache<Key, [String : Any]> {
        return mapJSON().mapValues(throwing({ $0 as? [String : Any] }))
    }
    
    public func mapPlist(format: PropertyListSerialization.PropertyListFormat = .xml) -> ReadOnlyCache<Key, Any> {
        return mapValues({ data in
            var formatRef = format
            return try PropertyListSerialization.propertyList(from: data, options: [], format: &formatRef)
        })
    }
    
    public func mapPlistDictionary(format: PropertyListSerialization.PropertyListFormat = .xml) -> ReadOnlyCache<Key, [String : Any]> {
        return mapPlist(format: format).mapValues(throwing({ $0 as? [String : Any] }))
    }
    
    public func mapString(withEncoding encoding: String.Encoding = .utf8) -> ReadOnlyCache<Key, String> {
        return mapValues(throwing({ String(data: $0, encoding: encoding) }))
    }
    
}
