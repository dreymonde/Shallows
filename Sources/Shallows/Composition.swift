//
//  Composition.swift
//  Shallows
//
//  Created by Олег on 21.02.2018.
//  Copyright © 2018 Shallows. All rights reserved.
//

extension ReadOnlyStorageProtocol {
    
    public func backed<ReadableStorageType : ReadableStorageProtocol>(by storage: ReadableStorageType) -> ReadOnlyStorage<Key, Value> where ReadableStorageType.Key == Key, ReadableStorageType.Value == Value {
        return ReadOnlyStorage(storageName: "\(self.storageName)-\(storage.storageName)", retrieve: { (key, completion) in
            self.retrieve(forKey: key, completion: { (firstResult) in
                if firstResult.isFailure {
                    shallows_print("Storage (\(self.storageName)) miss for key: \(key). Attempting to retrieve from \(storage.storageName)")
                    storage.retrieve(forKey: key, completion: completion)
                } else {
                    completion(firstResult)
                }
            })
        })
    }
    
}

extension WritableStorageProtocol {
    
    public func pushing<WritableStorageType : WritableStorageProtocol>(to storage: WritableStorageType) -> WriteOnlyStorage<Key, Value> where WritableStorageType.Key == Key, WritableStorageType.Value == Value {
        return WriteOnlyStorage(storageName: "\(self.storageName)-\(storage.storageName)", set: { (value, key, completion) in
            self.set(value, forKey: key, pushingTo: storage, completion: completion)
        })
    }
    
}

extension StorageProtocol {
        
    public func combined<StorageType : StorageProtocol>(with backStorage: StorageType) -> Storage<Key, Value> where StorageType.Key == Key, StorageType.Value == Value {
        let name = Shallows.storageName(left: self.storageName, right: backStorage.storageName, pullingFromBack: true, pushingToBack: true)
        return Storage(storageName: name, retrieve: { (key, completion) in
            self.retrieve(forKey: key, backedBy: backStorage, completion: completion)
        }, set: { (value, key, completion) in
            self.set(value, forKey: key, pushingTo: backStorage, completion: completion)
        })
    }
    
    public func backed<ReadableStorageType : ReadableStorageProtocol>(by readableStorage: ReadableStorageType) -> Storage<Key, Value> where ReadableStorageType.Key == Key, ReadableStorageType.Value == Value {
        let name = Shallows.storageName(left: storageName, right: readableStorage.storageName, pullingFromBack: true, pushingToBack: false)
        return Storage<Key, Value>(storageName: name, retrieve: { (key, completion) in
            self.retrieve(forKey: key, backedBy: readableStorage, completion: completion)
        }, set: { (value, key, completion) in
            self.set(value, forKey: key, completion: completion)
        })
    }
    
}

extension StorageProtocol {
    
    fileprivate func retrieve<StorageType : ReadableStorageProtocol>(forKey key: Key,
                                                                     backedBy storage: StorageType,
                                                                     completion: @escaping (ShallowsResult<Value>) -> ()) where StorageType.Key == Key, StorageType.Value == Value {
        self.retrieve(forKey: key, completion: { (firstResult) in
            if firstResult.isFailure {
                shallows_print("Storage (\(self.storageName)) miss for key: \(key). Attempting to retrieve from \(storage.storageName)")
                storage.retrieve(forKey: key, completion: { (secondResult) in
                    if let value = secondResult.value {
                        shallows_print("Success retrieving \(key) from \(storage.storageName). Setting value back to \(self.storageName)")
                        self.set(value, forKey: key, completion: { _ in completion(secondResult) })
                    } else {
                        shallows_print("Storage miss for final destination (\(storage.storageName)). Completing with failure result")
                        completion(secondResult)
                    }
                })
            } else {
                completion(firstResult)
            }
        })
    }
    
}

extension WritableStorageProtocol {
    
    fileprivate func set<StorageType : WritableStorageProtocol>(_ value: Value,
                                                                forKey key: Key,
                                                                pushingTo storage: StorageType,
                                                                completion: @escaping (ShallowsResult<Void>) -> ()) where StorageType.Key == Key, StorageType.Value == Value {
        self.set(value, forKey: key, completion: { (result) in
            if result.isFailure {
                shallows_print("Failed setting \(key) to \(self.storageName). Aborting")
                completion(result)
            } else {
                shallows_print("Succesfull set of \(key). Pushing to \(storage.storageName)")
                storage.set(value, forKey: key, completion: completion)
            }
        })
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
        
        public func set<StorageType : WritableStorageProtocol>(_ value: Value,
                                                               forKey key: Key,
                                                               pushingTo backStorage: StorageType,
                                                               completion: @escaping (ShallowsResult<Void>) -> ()) where StorageType.Key == Key, StorageType.Value == Value {
            frontStorage.set(value, forKey: key, pushingTo: backStorage, completion: completion)
        }
        
        public func retrieve<StorageType : ReadableStorageProtocol>(forKey key: Key,
                                                                    backedBy backStorage: StorageType,
                                                                    completion: @escaping (ShallowsResult<Value>) -> ()) where StorageType.Key == Key, StorageType.Value == Value{
            frontStorage.retrieve(forKey: key, backedBy: backStorage, completion: completion)
        }
        
    }
    
}
