import Foundation

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
