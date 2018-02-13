//
//  Zip.swift
//  Shallows
//
//  Created by Олег on 07.05.17.
//  Copyright © 2017 Shallows. All rights reserved.
//

import Dispatch

fileprivate final class CompletionContainer<Left, Right> {
    
    private var left: Left?
    private var right: Right?
    private let queue = DispatchQueue(label: "container-completion")
    
    private let completion: (Left, Right) -> ()
    
    fileprivate init(completion: @escaping (Left, Right) -> ()) {
        self.completion = completion
    }
    
    fileprivate func completeLeft(with left: Left) {
        queue.async {
            self.left = left
            self.check()
        }
    }
    
    fileprivate func completeRight(with right: Right) {
        queue.async {
            self.right = right
            self.check()
        }
    }

    private func check() {
        if let left = left, let right = right {
            completion(left, right)
        }
    }
    
}

public struct ZippedResultError : Error {
    
    public let left: Error?
    public let right: Error?
    
    public init(left: Error?, right: Error?) {
        self.left = left
        self.right = right
    }
    
}

public func zip<Value1, Value2>(_ lhs: Result<Value1>, _ rhs: Result<Value2>) -> Result<(Value1, Value2)> {
    switch (lhs, rhs) {
    case (.success(let left), .success(let right)):
        return Result.success((left, right))
    default:
        return Result.failure(ZippedResultError(left: lhs.error, right: rhs.error))
    }
}

public func zip<Key, Value1, Value2>(_ lhs: ReadOnlyStorage<Key, Value1>, _ rhs: ReadOnlyStorage<Key, Value2>) -> ReadOnlyStorage<Key, (Value1, Value2)> {
    return ReadOnlyStorage(storageName: lhs.storageName + "+" + rhs.storageName, retrieve: { (key, completion) in
        let container = CompletionContainer<Result<Value1>, Result<Value2>>() { left, right in
            completion(zip(left, right))
        }
        lhs.retrieve(forKey: key, completion: { container.completeLeft(with: $0) })
        rhs.retrieve(forKey: key, completion: { container.completeRight(with: $0) })
    })
}

public func zip<Key, Value1, Value2>(_ lhs: WriteOnlyStorage<Key, Value1>, _ rhs: WriteOnlyStorage<Key, Value2>) -> WriteOnlyStorage<Key, (Value1, Value2)> {
    return WriteOnlyStorage(storageName: lhs.storageName + "+" + rhs.storageName, set: { (value, key, completion) in
        let container = CompletionContainer<Result<Void>, Result<Void>>(completion: { (left, right) in
            let zipped = zip(left, right)
            switch zipped {
            case .success:
                completion(.success)
            case .failure(let error):
                completion(.failure(error))
            }
        })
        lhs.set(value.0, forKey: key, completion: { container.completeLeft(with: $0) })
        rhs.set(value.1, forKey: key, completion: { container.completeRight(with: $0) })
    })
}

public func zip<Storage1 : StorageProtocol, Storage2 : StorageProtocol>(_ lhs: Storage1, _ rhs: Storage2) -> Storage<Storage1.Key, (Storage1.Value, Storage2.Value)> where Storage1.Key == Storage2.Key {
    let readOnlyZipped = zip(lhs.asReadOnlyStorage(), rhs.asReadOnlyStorage())
    let writeOnlyZipped = zip(lhs.asWriteOnlyStorage(), rhs.asWriteOnlyStorage())
    return Storage(readStorage: readOnlyZipped, writeStorage: writeOnlyZipped)
}
