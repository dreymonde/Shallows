# Shallows

[![Swift][swift-badge]][swift-url]
[![Platform][platform-badge]][platform-url]

**Shallows** is a generic abstraction layer over lightweight data storage and persistence. It provides a `Storage<Key, Value>` type, instances of which can be easily transformed and composed with each other. It gives you an ability to create highly sophisticated, effective and reliable caching/persistence solutions.

**Shallows** is deeply inspired by [Carlos][carlos-github-url] and [this amazing talk][composable-caches-in-swift-url] by [Brandon Kase][brandon-kase-twitter-url].

**Shallows** is a really small, component-based project, so if you need even more controllable solution – build one yourself! Our source code is there to help.

## Usage

### Showcase

Using **Shallows** for two-step JSON storage (memory and disk):

```swift
struct Player : Codable {
    let name: String
    let rating: Int
}

let memoryStorage = MemoryStorage<String, Player>()
let diskStorage = FileSystemStorage.inDirectory(.cachesDirectory, appending: "cache")
    .mapJSONObject(Player.self)
    .usingStringKeys()
let combinedStorage = memoryStorage.combined(with: diskStorage)
combinedStorage.retrieve(forKey: "Higgins") { (result) in
    if let player = result.value {
        print(player.name)
    }
}
combinedStorage.set(Player(name: "Mark", rating: 1), forKey: "Selby") { (result) in
    if result.isSuccess {
        print("Success!")
    }
}
```

### Guide

A main type of **Shallows** is `Storage<Key, Value>`. It's an abstract, type-erased structure which doesn't contain any logic -- it needs to be provided with one. The most basic one is `MemoryStorage`:

```swift
let storage = MemoryStorage<String, Int>().asStorage() // Storage<String, Int>
```

Storage instances have `retrieve` and `set` methods, which are asynhronous and fallible:

```swift
storage.retrieve(forKey: "some-key") { (result) in
    switch result {
    case .success(let value):
        print(value)
    case .failure(let error):
        print(error)
    }
}
storage.set(10, forKey: "some-key") { (result) in
    switch result {
    case .success:
        print("Value set!")
    case .failure(let error):
        print(error)
    }
}
```

#### Transforms

Keys and values can be mapped:

```swift
let stringStorage = storage.mapValues(transformIn: { String($0) },
                                  transformOut: { try Int($0).unwrap() }) // Storage<String, String>
// ...
enum EnumKey : String {
    case first, second, third
}
let keyedStorage: Storage<EnumKey, String> = stringStorage.mapKeys({ $0.rawValue })
```

The concept of keys and values transformations is really powerful and it lies in the core of **Shallows**. For example, `FileSystemStorage` provides a `Storage<String, Data>` instances, and you can easily map `Data` to something useful. For example, `UIImage`:

```swift
// FileSystemStorage is a storage of Filename : Data
let fileSystemStorage = FileSystemStorage.inDirectory(.cachesDirectory, appending: "shallows-caches-1")
let imageStorage = fileSystemStorage.mapValues(transformIn: { try UIImage(data: $0).unwrap() },
                                           transformOut: { try UIImagePNGRepresentation($0).unwrap() })
```

Now you have an instance of type `Storage<String, UIImage>` which can be used to store images without much fuss.

**NOTE:** There are several convenience methods defined on `Storage` with value of `Data`: `.mapString(withEncoding:)`, `.mapJSON()`, `.mapJSONDictionary()`, `.mapJSONObject(_:)` `.mapPlist(format:)`, `.mapPlistDictionary(format:)`, `.mapPlistObject(_:)`.

#### Storages composition

Another core concept of **Shallows** is composition. Hitting a disk every time you request an image can be slow and inefficient. Instead, you can compose `MemoryStorage` and `FileSystemStorage`:

```swift
let efficient = MemoryStorage<String, UIImage>().combined(with: imageStorage)
```

It does several things:

1. When trying to retrieve an image, the memory storage first will be checked first, and if it doesn't contain a value, the request will be made to disk storage.
2. If disk storage stores a value, it will be pulled to memory storage and returned to a user.
3. When setting an image, it will be set both to memory and disk storage.

Great things about composing storages is that in the end, you still has your `Storage<Key, Value>` instance. That means that you can recompose storage layers however you want without breaking the usage code. It also makes the code that depends on `Storage` very easy to test.

The huge advantage of **Shallows** is that it doesn't try to hide the actual mechanism - the behavior of your storages is perfectly clear, and still very simple to understand and easy to use. You control how many layers your storage has, how it acts and what it stores. **Shallows** is not an end-product - instead, it's a tool that will help you build exactly what you need.

#### Read-only storage

If you don't want to expose writing to your storage, you can make it a read-only storage:

```swift
let readOnly = storage.asReadOnlyStorage() // ReadOnlyStorage<Key, Value>
```

Read-only storages can also be mapped and composed:

```swift
let immutableFileStorage = FileSystemStorage.inDirectory(.cachesDirectory, appending: "shallows-immutable")
    .mapString(withEncoding: .utf8)
    .asReadOnlyStorage()
let storage = MemoryStorage<String, String>()
    .combined(with: immutableFileStorage)
    .asReadOnlyStorage() // ReadOnlyStorage<String, String>
```

#### Write-only storage

In similar way, write-only storage is also available:

```swift
let writeOnly = storage.asWriteOnlyStorage() // WriteOnlyStorage<Key, Value>
```

#### Single element storage

You can have a storage with keys `Void`. That means that you can store only one element there. **Shallows** provides a convenience `.singleKey` method to create it:

```swift
let settingsStorage = FileSystemStorage.inDirectory(.documentDirectory, appending: "settings")
    .mapJSONDictionary()
    .singleKey("settings") // Storage<Void, [String : Any]>
settingsStorage.retrieve { (result) in
    // ...
}
```

#### Synchronous storage

Storages in **Shallows** are asynchronous by it's nature. However, in some situations (for example, when scripting or testing) it could be useful to have synchronous storages. You can make any storage synchronous by calling `.makeSyncStorage()` on it:

```swift
let strings = FileSystemStorage.inDirectory(.cachesDirectory, appending: "strings")
    .mapString(withEncoding: .utf8)
    .makeSyncStorage() // SyncStorage<String, String>
let existing = try strings.retrieve(forKey: "hello")
try strings.set(existing.uppercased(), forKey: "hello")
```

However, be careful with that: some storages may be designed to complete more than one time (for example, some storages may quickly return value stored in a local storage and then ask the server for an update). Making a storage like this synchronous will kill that functionality.

#### Mutating value for key

**Shallows** provides a convenient `.update` method on storages:

```swift
let arrays = MemoryStorage<String, [Int]>()
arrays.update(forKey: "some-key", { $0.append(10) }) { (result) in
    // ...
}
```

#### Zipping storages

Zipping is a very powerful feature of **Shallows**. It allows you to compose your storages in a way that you get result only when both of them completes for your request. For example:

```swift
let strings = MemoryStorage<String, String>()
let numbers = MemoryStorage<String, Int>()
let zipped = zip(strings, numbers) // Storage<String, (String, Int)>
zipped.retrieve(forKey: "some-key") { (result) in
    if let (string, number) = result.value {
        print(string)
        print(number)
    }
}
zipped.set(("shallows", 3), forKey: "another-key") { (result) in
    if result.isSuccess {
        print("Yay!")
    }
}
```

Isn't it nice?

#### Different ways of composition

Storages can be composed in different ways. If you look at the `combined` method, it actually looks like this:

```swift
public func combined<StorageType : StorageProtocol>(with storage: StorageType,
                     pullStrategy: StorageCombinationPullStrategy,
                     setStrategy: StorageCombinationSetStrategy) -> Storage<Key, Value> where StorageType.Key == Key, StorageType.Value == Value
```

Where `pullStrategy` defaults to `.pullThenComplete` and `setStrategy` defaults to `.frontFirst`. Available options are:

```swift
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
```

You can change these parameters to accomplish a behavior you want.

#### Recovering from errors

You can protect your storage instance from failures using `fallback(with:)` or `defaulting(to:)` methods:

```swift
let storage = MemoryStorage<String, Int>()
let protected = storage.fallback(with: { error in
    switch error {
    case MemoryStorageError.noValue:
        return 15
    default:
        return -1
    }
})
```

```swift
let storage = MemoryStorage<String, Int>()
let defaulted = storage.defaulting(to: -1)
```

This is _especially_ useful when using `update` method:

```swift
let storage = MemoryStorage<String, [Int]>()
storage.defaulting(to: []).update(forKey: "first", { $0.append(10) })
```

That means that in case of failure retrieving existing value, `update` will use default value of `[]` instead of just failing the whole update.

#### Using `NSCacheStorage`

`NSCache` is a tricky class: it supports only reference types, so you're forced to use, for example, `NSData` instead of `Data` and so on. To help you out, **Shallows** provides a set of convenience extensions for legacy Foundation types:

```swift
let nscache = NSCacheStorage<NSURL, NSData>()
    .toNonObjCKeys()
    .toNonObjCValues() // Storage<URL, Data>
```

### Making your own storage

To create your own caching layer, you should conform to `StorageProtocol`. That means that you should define these two methods:

```swift
func retrieve(forKey key: Key, completion: @escaping (Result<Value>) -> ())
func set(_ value: Value, forKey key: Key, completion: @escaping (Result<Void>) -> ())
```

Where `Key` and `Value` are associated types.

**NOTE:** Please be aware that you should care about thread-safety of your implementation. Very often `retrieve` and `set` will not be called from the main thread, so you should make sure that no race conditions will occur.

To use it as `Storage<Key, Value>` instance, simply call `.asStorage()` on it:

```swift
let storage = MyStorage().asStorage()
```

You can also conform to a `ReadableStorageProtocol` only. That way, you only need to define a `retrieve(forKey:completion:)` method.

## Installation
**Shallows** is available through [Carthage][carthage-url]. To install, just write into your Cartfile:

```ruby
github "dreymonde/Shallows" ~> 0.7.0
```

[carthage-url]: https://github.com/Carthage/Carthage
[swift-badge]: https://img.shields.io/badge/Swift-4.0-orange.svg?style=flat
[swift-url]: https://swift.org
[platform-badge]: https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20watchOS%20%7C%20tvOS-lightgrey.svg
[platform-url]: https://developer.apple.com/swift/
[carlos-github-url]: https://github.com/WeltN24/Carlos
[composable-caches-in-swift-url]: https://www.youtube.com/watch?v=8uqXuEZLyUU
[brandon-kase-twitter-url]: https://twitter.com/bkase_
[avenues-github-url]: https://github.com/dreymonde/Avenues
[avenues-shallows-github-url]: https://github.com/dreymonde/Avenues-Shallows