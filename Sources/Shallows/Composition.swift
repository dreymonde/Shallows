//
//  Composition.swift
//  Shallows
//
//  Created by Олег on 21.02.2018.
//  Copyright © 2018 Shallows. All rights reserved.
//

extension ReadOnlyStorageProtocol {
    
    public func backed<ReadableStorageType : ReadableStorageProtocol>(by storage: ReadableStorageType) -> ReadOnlyStorage<Key, Value> where ReadableStorageType.Key == Key, ReadableStorageType.Value == Value {
        return ReadOnlyStorage(storageName: "\(self.storageName)-\(storage.storageName)", retrieve: { (key) in
            self.retrieve(forKey: key).flatMapError { (error) in
                shallows_print("Storage (\(self.storageName)) miss for key: \(key). Attempting to retrieve from \(storage.storageName)")
                return storage.retrieve(forKey: key)
            }
        })
    }
    
}

extension WritableStorageProtocol {
    
    public func pushing<WritableStorageType : WritableStorageProtocol>(to storage: WritableStorageType) -> WriteOnlyStorage<Key, Value> where WritableStorageType.Key == Key, WritableStorageType.Value == Value {
        return WriteOnlyStorage(storageName: "\(self.storageName)-\(storage.storageName)", set: { (value, key) in
            self.set(value, forKey: key, pushingTo: storage)
        })
    }
    
}

extension StorageProtocol {
        
    public func combined<StorageType : StorageProtocol>(with backStorage: StorageType) -> Storage<Key, Value> where StorageType.Key == Key, StorageType.Value == Value {
        let name = Shallows.storageName(left: self.storageName, right: backStorage.storageName, pullingFromBack: true, pushingToBack: true)
        return Storage(storageName: name, retrieve: { (key) in
            self.retrieve(forKey: key, backedBy: backStorage)
        }, set: { (value, key) in
            self.set(value, forKey: key, pushingTo: backStorage)
        })
    }
    
    public func backed<ReadableStorageType : ReadableStorageProtocol>(by readableStorage: ReadableStorageType) -> Storage<Key, Value> where ReadableStorageType.Key == Key, ReadableStorageType.Value == Value {
        let name = Shallows.storageName(left: storageName, right: readableStorage.storageName, pullingFromBack: true, pushingToBack: false)
        return Storage<Key, Value>(storageName: name, retrieve: { (key) in
            self.retrieve(forKey: key, backedBy: readableStorage)
        }, set: { (value, key) in
            self.set(value, forKey: key)
        })
    }
    
}

extension StorageProtocol {
    
    fileprivate func retrieve<StorageType : ReadableStorageProtocol>(forKey key: Key,
                                                                     backedBy backStorage: StorageType) -> ShallowsFuture<Value> where StorageType.Key == Key, StorageType.Value == Value {
        
        return self.retrieve(forKey: key).flatMapError { (_) -> ShallowsFuture<Value> in
            shallows_print("Storage (\(self.storageName)) miss for key: \(key). Attempting to retrieve from \(backStorage.storageName)")
            
            return backStorage.retrieve(forKey: key)
                .mapError { (error) -> Swift.Error in
                    shallows_print("Storage miss for final destination (\(backStorage.storageName)). Completing with failure result")
                    return error
                }
                .flatMap { (value) -> ShallowsFuture<Value> in
                    shallows_print("Success retrieving \(key) from \(backStorage.storageName). Setting value back to \(self.storageName)")
                    return self.set(value, forKey: key)
                        .map({ value })
                        .flatMapError({ error in ShallowsFuture(value: value) })
                }
        }
    }
    
}

extension WritableStorageProtocol {
    
    fileprivate func set<StorageType : WritableStorageProtocol>(_ value: Value,
                                                                forKey key: Key,
                                                                pushingTo storage: StorageType) -> ShallowsFuture<Void> where StorageType.Key == Key, StorageType.Value == Value {
        
        return self.set(value, forKey: key)
            .mapError { (error) -> Swift.Error in
                shallows_print("Failed setting \(key) to \(self.storageName). Aborting")
                return error
            }
            .flatMap { (_) -> ShallowsFuture<Void> in
                shallows_print("Succesfull set of \(key). Pushing to \(storage.storageName)")
                return storage.set(value, forKey: key)
            }
    }
    
}

extension StorageProtocol {
    
    public var dev: Storage<Key, Value>.Dev {
        return Storage<Key, Value>.Dev(self.asStorage())
    }
    
}

extension Storage {
    
    public struct Dev {
        
        fileprivate let frontStorage: Storage
        
        fileprivate init(_ storage: Storage) {
            self.frontStorage = storage
        }
        
        @discardableResult
        public func set<StorageType : WritableStorageProtocol>(_ value: Value,
                                                               forKey key: Key,
                                                               pushingTo backStorage: StorageType) -> ShallowsFuture<Void> where StorageType.Key == Key, StorageType.Value == Value {
            return frontStorage.set(value, forKey: key, pushingTo: backStorage)
        }
        
        public func retrieve<StorageType : ReadableStorageProtocol>(forKey key: Key,
                                                                    backedBy backStorage: StorageType) -> ShallowsFuture<Value> where StorageType.Key == Key, StorageType.Value == Value{
            return frontStorage.retrieve(forKey: key, backedBy: backStorage)
        }
        
    }
    
}
