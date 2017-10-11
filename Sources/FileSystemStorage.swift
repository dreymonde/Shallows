import Foundation

public protocol FileSystemStorageProtocol : StorageProtocol {
    
    init(directoryURL: URL, qos: DispatchQoS, storageName: String?)
    
}

extension FileSystemStorageProtocol {
    
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

public struct Filename : RawRepresentable, ExpressibleByStringLiteral {
    
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
    
}

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

extension StorageProtocol where Value == Data {
    
    public func mapJSON(readingOptions: JSONSerialization.ReadingOptions = [], writingOptions: JSONSerialization.WritingOptions = []) -> Storage<Key, Any> {
        return mapValues(transformIn: { try JSONSerialization.jsonObject(with: $0, options: readingOptions) },
                         transformOut: { try JSONSerialization.data(withJSONObject: $0, options: writingOptions) })
    }
    
    public func mapJSONDictionary(readingOptions: JSONSerialization.ReadingOptions = [], writingOptions: JSONSerialization.WritingOptions = []) -> Storage<Key, [String : Any]> {
        return mapJSON(readingOptions: readingOptions, writingOptions: writingOptions).mapValues(transformIn: throwing({ $0 as? [String : Any] }),
                                                                                                 transformOut: { $0 })
    }
    
    public func mapJSONObject<JSONObject : Codable>(_ objectType: JSONObject.Type,
                                                    decoder: JSONDecoder = JSONDecoder(),
                                                    encoder: JSONEncoder = JSONEncoder()) -> Storage<Key, JSONObject> {
        return mapValues(transformIn: { try decoder.decode(objectType, from: $0) },
                         transformOut: { try encoder.encode($0) })
    }
    
    public func mapPlist(format: PropertyListSerialization.PropertyListFormat = .xml) -> Storage<Key, Any> {
        return mapValues(transformIn: { data in
            var formatRef = format
            return try PropertyListSerialization.propertyList(from: data, options: [], format: &formatRef)
        }, transformOut: { plist in
            return try PropertyListSerialization.data(fromPropertyList: plist, format: format, options: 0)
        })
    }
    
    public func mapPlistDictionary(format: PropertyListSerialization.PropertyListFormat = .xml) -> Storage<Key, [String : Any]> {
        return mapPlist(format: format).mapValues(transformIn: throwing({ $0 as? [String : Any] }),
                                                  transformOut: { $0 })
    }
    
    public func mapPlistObject<PlistObject : Codable>(_ objectType: PlistObject.Type,
                                                      decoder: PropertyListDecoder = PropertyListDecoder(),
                                                      encoder: PropertyListEncoder = PropertyListEncoder()) -> Storage<Key, PlistObject> {
        return mapValues(transformIn: { try decoder.decode(objectType, from: $0) },
                         transformOut: { try encoder.encode($0) })
    }
    
    public func mapString(withEncoding encoding: String.Encoding = .utf8) -> Storage<Key, String> {
        return mapValues(transformIn: throwing({ String(data: $0, encoding: encoding) }),
                         transformOut: throwing({ $0.data(using: encoding) }))
    }
    
}

extension ReadOnlyStorageProtocol where Value == Data {
    
    public func mapJSON(options: JSONSerialization.ReadingOptions = []) -> ReadOnlyStorage<Key, Any> {
        return mapValues({ try JSONSerialization.jsonObject(with: $0, options: options) })
    }
    
    public func mapJSONDictionary(options: JSONSerialization.ReadingOptions = []) -> ReadOnlyStorage<Key, [String : Any]> {
        return mapJSON(options: options).mapValues(throwing({ $0 as? [String : Any] }))
    }
    
    public func mapJSONObject<JSONObject : Decodable>(_ objectType: JSONObject.Type,
                                                      decoder: JSONDecoder = JSONDecoder()) -> ReadOnlyStorage<Key, JSONObject> {
        return mapValues({ try decoder.decode(objectType, from: $0) })
    }
    
    public func mapPlist(format: PropertyListSerialization.PropertyListFormat = .xml, options: PropertyListSerialization.ReadOptions = []) -> ReadOnlyStorage<Key, Any> {
        return mapValues({ data in
            var formatRef = format
            return try PropertyListSerialization.propertyList(from: data, options: options, format: &formatRef)
        })
    }
    
    public func mapPlistDictionary(format: PropertyListSerialization.PropertyListFormat = .xml, options: PropertyListSerialization.ReadOptions = []) -> ReadOnlyStorage<Key, [String : Any]> {
        return mapPlist(format: format, options: options).mapValues(throwing({ $0 as? [String : Any] }))
    }
    
    public func mapPlistObject<PlistObject : Decodable>(_ objectType: PlistObject.Type,
                                                        decoder: PropertyListDecoder = PropertyListDecoder()) -> ReadOnlyStorage<Key, PlistObject> {
        return mapValues({ try decoder.decode(objectType, from: $0) })
    }
    
    public func mapString(withEncoding encoding: String.Encoding = .utf8) -> ReadOnlyStorage<Key, String> {
        return mapValues(throwing({ String(data: $0, encoding: encoding) }))
    }
    
}

extension WriteOnlyStorageProtocol where Value == Data {
    
    public func mapJSON(options: JSONSerialization.WritingOptions = []) -> WriteOnlyStorage<Key, Any> {
        return mapValues({ try JSONSerialization.data(withJSONObject: $0, options: options) })
    }
    
    public func mapJSONDictionary(options: JSONSerialization.WritingOptions = []) -> WriteOnlyStorage<Key, [String : Any]> {
        return mapJSON(options: options).mapValues({ $0 as Any })
    }
    
    public func mapJSONObject<JSONObject : Encodable>(_ objectType: JSONObject.Type,
                                                      encoder: JSONEncoder = JSONEncoder()) -> WriteOnlyStorage<Key, JSONObject> {
        return mapValues({ try encoder.encode($0) })
    }
    
    public func mapPlist(format: PropertyListSerialization.PropertyListFormat = .xml, options: PropertyListSerialization.WriteOptions = 0) -> WriteOnlyStorage<Key, Any> {
        return mapValues({ try PropertyListSerialization.data(fromPropertyList: $0, format: format, options: options) })
    }
    
    public func mapPlistDictionary(format: PropertyListSerialization.PropertyListFormat = .xml, options: PropertyListSerialization.WriteOptions = 0) -> WriteOnlyStorage<Key, [String : Any]> {
        return mapPlist(format: format, options: options).mapValues({ $0 as Any })
    }
    
    public func mapPlistObject<PlistObject : Encodable>(_ objectType: PlistObject.Type,
                                                        encoder: PropertyListEncoder = PropertyListEncoder()) -> WriteOnlyStorage<Key, PlistObject> {
        return mapValues({ try encoder.encode($0) })
    }
    
    public func mapString(withEncoding encoding: String.Encoding = .utf8) -> WriteOnlyStorage<Key, String> {
        return mapValues(throwing({ $0.data(using: encoding) }))
    }
    
}

extension StorageProtocol where Key == Filename {
    
    public func usingStringKeys() -> Storage<String, Value> {
        return mapKeys(Filename.init(rawValue:))
    }
    
}

extension ReadOnlyStorageProtocol where Key == Filename {
    
    public func usingStringKeys() -> ReadOnlyStorage<String, Value> {
        return mapKeys(Filename.init(rawValue:))
    }
    
}

extension WriteOnlyStorageProtocol where Key == Filename {
    
    public func usingStringKeys() -> WriteOnlyStorage<String, Value> {
        return mapKeys(Filename.init(rawValue:))
    }
    
}
