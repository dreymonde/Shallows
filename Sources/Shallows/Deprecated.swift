//
//  Deprecated.swift
//  Shallows
//
//  Created by Олег on 21.02.2018.
//  Copyright © 2018 Shallows. All rights reserved.
//

@available(*, unavailable)
public protocol ShallowsError : Swift.Error {
    
    var isTransient: Bool { get }
    
}

public enum StorageCombinationPullStrategy {
    case pullThenComplete
    case completeThenPull
    case neverPull
}

public enum StorageCombinationSetStrategy {
    case backFirst
    case frontFirst
    case frontOnly
    case backOnly
}

extension StorageProtocol {
    
    @available(*, unavailable, message: "strategies are no longer supported")
    public func combined<StorageType : StorageProtocol>(with storage: StorageType,
                                                        pullStrategy: StorageCombinationPullStrategy = .pullThenComplete,
                                                        setStrategy: StorageCombinationSetStrategy = .frontFirst) -> Storage<Key, Value> where StorageType.Key == Key, StorageType.Value == Value {
        fatalError("strategies are no longer supported")
    }
    
    @available(*, unavailable, message: "strategies are no longer supported")
    public func pushing<WritableStorageType : WritableStorageProtocol>(to backStorage: WritableStorageType,
                                                                       strategy: StorageCombinationSetStrategy = .frontFirst) -> Storage<Key, Value> where WritableStorageType.Key == Key, WritableStorageType.Value == Value {
        fatalError("strategies are no longer supported")
    }
    
    @available(*, unavailable, message: "strategies are no longer supported")
    public func backed<ReadableStorageType : ReadableStorageProtocol>(by storage: ReadableStorageType,
                                                                      strategy: StorageCombinationPullStrategy) -> Storage<Key, Value> where ReadableStorageType.Key == Key, ReadableStorageType.Value == Value {
        fatalError("strategies are no longer supported")
    }
    
}
