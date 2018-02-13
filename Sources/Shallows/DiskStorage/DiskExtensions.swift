//
//  DiskExtensions.swift
//  Shallows
//
//  Created by Олег on 18.01.2018.
//  Copyright © 2018 Shallows. All rights reserved.
//

import Foundation

extension StorageProtocol where Value == Data {
    
    public func mapJSON(readingOptions: JSONSerialization.ReadingOptions = [],
                        writingOptions: JSONSerialization.WritingOptions = []) -> Storage<Key, Any> {
        return Storage(readStorage: asReadOnlyStorage().mapJSON(options: readingOptions),
                       writeStorage: asWriteOnlyStorage().mapJSON(options: writingOptions))
    }
    
    public func mapJSONDictionary(readingOptions: JSONSerialization.ReadingOptions = [],
                                  writingOptions: JSONSerialization.WritingOptions = []) -> Storage<Key, [String : Any]> {
        return Storage(readStorage: asReadOnlyStorage().mapJSONDictionary(options: readingOptions),
                       writeStorage: asWriteOnlyStorage().mapJSONDictionary(options: writingOptions))
    }
    
    public func mapJSONObject<JSONObject : Codable>(_ objectType: JSONObject.Type,
                                                    decoder: JSONDecoder = JSONDecoder(),
                                                    encoder: JSONEncoder = JSONEncoder()) -> Storage<Key, JSONObject> {
        return Storage(readStorage: asReadOnlyStorage().mapJSONObject(objectType, decoder: decoder),
                       writeStorage: asWriteOnlyStorage().mapJSONObject(objectType, encoder: encoder))
    }
    
    public func mapPlist(format: PropertyListSerialization.PropertyListFormat = .xml,
                         readOptions: PropertyListSerialization.ReadOptions = [],
                         writeOptions: PropertyListSerialization.WriteOptions = 0) -> Storage<Key, Any> {
        return Storage(readStorage: asReadOnlyStorage().mapPlist(format: format, options: readOptions),
                       writeStorage: asWriteOnlyStorage().mapPlist(format: format, options: writeOptions))
    }
    
    public func mapPlistDictionary(format: PropertyListSerialization.PropertyListFormat = .xml,
                                   readOptions: PropertyListSerialization.ReadOptions = [],
                                   writeOptions: PropertyListSerialization.WriteOptions = 0) -> Storage<Key, [String : Any]> {
        return Storage(readStorage: asReadOnlyStorage().mapPlistDictionary(format: format, options: readOptions),
                       writeStorage: asWriteOnlyStorage().mapPlistDictionary(format: format, options: writeOptions))
    }
    
    public func mapPlistObject<PlistObject : Codable>(_ objectType: PlistObject.Type,
                                                      decoder: PropertyListDecoder = PropertyListDecoder(),
                                                      encoder: PropertyListEncoder = PropertyListEncoder()) -> Storage<Key, PlistObject> {
        return Storage(readStorage: asReadOnlyStorage().mapPlistObject(objectType, decoder: decoder),
                       writeStorage: asWriteOnlyStorage().mapPlistObject(objectType, encoder: encoder))
    }
    
    public func mapString(withEncoding encoding: String.Encoding = .utf8) -> Storage<Key, String> {
        return Storage(readStorage: asReadOnlyStorage().mapString(withEncoding: encoding),
                       writeStorage: asWriteOnlyStorage().mapString(withEncoding: encoding))
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
    
    public func mapPlist(format: PropertyListSerialization.PropertyListFormat = .xml,
                         options: PropertyListSerialization.ReadOptions = []) -> ReadOnlyStorage<Key, Any> {
        return mapValues({ data in
            var formatRef = format
            return try PropertyListSerialization.propertyList(from: data, options: options, format: &formatRef)
        })
    }
    
    public func mapPlistDictionary(format: PropertyListSerialization.PropertyListFormat = .xml,
                                   options: PropertyListSerialization.ReadOptions = []) -> ReadOnlyStorage<Key, [String : Any]> {
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
    
    public func mapPlist(format: PropertyListSerialization.PropertyListFormat = .xml,
                         options: PropertyListSerialization.WriteOptions = 0) -> WriteOnlyStorage<Key, Any> {
        return mapValues({ try PropertyListSerialization.data(fromPropertyList: $0, format: format, options: options) })
    }
    
    public func mapPlistDictionary(format: PropertyListSerialization.PropertyListFormat = .xml,
                                   options: PropertyListSerialization.WriteOptions = 0) -> WriteOnlyStorage<Key, [String : Any]> {
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

