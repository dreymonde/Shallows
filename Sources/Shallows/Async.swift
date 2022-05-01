import Foundation

#if swift(>=5.5)
@available(iOS 13.0.0, *)
@available(macOS 10.15.0, *)
@available(watchOS 6.0, *)
@available(tvOS 13.0.0, *)
extension ReadableStorageProtocol {
    public func retrieve(forKey key: Key) async throws -> Value {
        return try await withCheckedThrowingContinuation({ (continuation) in
            self.retrieve(forKey: key) { result in
                continuation.resume(with: result)
            }
        })
    }
}

@available(iOS 13.0.0, *)
@available(macOS 10.15.0, *)
@available(watchOS 6.0, *)
@available(tvOS 13.0.0, *)
extension ReadableStorageProtocol where Key == Void {
    public func retrieve() async throws -> Value {
        return try await withCheckedThrowingContinuation({ (continuation) in
            self.retrieve() { result in
                continuation.resume(with: result)
            }
        })
    }
}

@available(iOS 13.0.0, *)
@available(macOS 10.15.0, *)
@available(watchOS 6.0, *)
@available(tvOS 13.0.0, *)
extension WritableStorageProtocol {
    public func set(_ value: Value, forKey key: Key) async throws -> Void {
        return try await withCheckedThrowingContinuation({ (continuation) in
            self.set(value, forKey: key) { result in
                continuation.resume(with: result)
            }
        })
    }
}

@available(iOS 13.0.0, *)
@available(macOS 10.15.0, *)
@available(watchOS 6.0, *)
@available(tvOS 13.0.0, *)
extension WritableStorageProtocol where Key == Void {
    public func set(_ value: Value) async throws -> Void {
        return try await withCheckedThrowingContinuation({ (continuation) in
            self.set(value) { result in
                continuation.resume(with: result)
            }
        })
    }
}

public struct ValueValidationError: Error {
    public init() { }
}

@available(iOS 13.0.0, *)
@available(macOS 10.15.0, *)
@available(watchOS 6.0, *)
@available(tvOS 13.0.0, *)
extension ReadOnlyStorageProtocol {
    public func asyncMapValues<OtherValue>(
        to type: OtherValue.Type = OtherValue.self,
        _ transform: @escaping (Value) async throws -> OtherValue
    ) -> ReadOnlyStorage<Key, OtherValue> {
        return ReadOnlyStorage<Key, OtherValue>(storageName: storageName, retrieve: { (key, completion) in
            self.retrieve(forKey: key, completion: { (result) in
                switch result {
                case .success(let value):
                    Task {
                        do {
                            let newValue = try await transform(value)
                            completion(.success(newValue))
                        } catch {
                            completion(.failure(error))
                        }
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            })
        })
    }

    public func validate(_ isValid: @escaping (Value) async throws -> Bool) -> ReadOnlyStorage<Key, Value> {
        return asyncMapValues(to: Value.self) { value in
            if try await isValid(value) {
                return value
            } else {
                throw ValueValidationError()
            }
        }
    }
}

@available(iOS 13.0.0, *)
@available(macOS 10.15.0, *)
@available(watchOS 6.0, *)
@available(tvOS 13.0.0, *)
extension WriteOnlyStorageProtocol {
    public func asyncMapValues<OtherValue>(
        to type: OtherValue.Type = OtherValue.self,
        _ transform: @escaping (OtherValue) async throws -> Value
    ) -> WriteOnlyStorage<Key, OtherValue> {
        return WriteOnlyStorage<Key, OtherValue>(storageName: storageName, set: { (value, key, completion) in
            Task {
                do {
                    let newValue = try await transform(value)
                    self.set(newValue, forKey: key, completion: completion)
                } catch {
                    completion(.failure(error))
                }
            }
        })
    }

    public func validate(_ isValid: @escaping (Value) async throws -> Bool) -> WriteOnlyStorage<Key, Value> {
        return asyncMapValues(to: Value.self) { value in
            if try await isValid(value) {
                return value
            } else {
                throw ValueValidationError()
            }
        }
    }
}

@available(iOS 13.0.0, *)
@available(macOS 10.15.0, *)
@available(watchOS 6.0, *)
@available(tvOS 13.0.0, *)
extension StorageProtocol {
    public func asyncMapValues<OtherValue>(to type: OtherValue.Type = OtherValue.self,
                                      transformIn: @escaping (Value) async throws -> OtherValue,
                                      transformOut: @escaping (OtherValue) async throws -> Value) -> Storage<Key, OtherValue> {
        return Storage(read: asReadOnlyStorage().asyncMapValues(transformIn),
                       write: asWriteOnlyStorage().asyncMapValues(transformOut))
    }

    public func validate(_ isValid: @escaping (Value) async throws -> Bool) -> Storage<Key, Value> {
        return asyncMapValues(
            to: Value.self,
            transformIn: { value in
                if try await isValid(value) {
                    return value
                } else {
                    throw ValueValidationError()
                }
            },
            transformOut: { value in
                if try await isValid(value) {
                    return value
                } else {
                    throw ValueValidationError()
                }
            }
        )
    }
}
#endif
