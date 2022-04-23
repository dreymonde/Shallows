# Shallows

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fdreymonde%2FShallows%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/dreymonde/Shallows) [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fdreymonde%2FShallows%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/dreymonde/Shallows)

**Shallows** is a generic abstraction layer over lightweight data storage and persistence. It provides a `Storage<Key, Value>` type, instances of which can be easily transformed and composed with each other. It gives you an ability to create highly sophisticated, effective and reliable caching/persistence solutions.

**Shallows** is deeply inspired by [Carlos][carlos-github-url] and [this amazing talk][composable-caches-in-swift-url] by [Brandon Kase][brandon-kase-twitter-url].

**Shallows** is a really small, component-based project, so if you need even more controllable solution – build one yourself! Our source code is there to help.

## Usage

```swift
struct City : Codable {
    let name: String
    let foundationYear: Int
}

let diskStorage = DiskStorage.main.folder("cities", in: .cachesDirectory)
    .mapJSONObject(City.self) // Storage<Filename, City>

let kharkiv = City(name: "Kharkiv", foundationYear: 1654)
diskStorage.set(kharkiv, forKey: "kharkiv")

diskStorage.retrieve(forKey: "kharkiv") { (result) in
    if let city = try? result.get() { print(city) }
}

// or

let city = try await diskStorage.retrieve(forKey: "kharkiv")

```

## Guide

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

### Transforms

Keys and values can be mapped:

```swift
let storage = DiskStorage.main.folder("images", in: .cachesDirectory) // Storage<Filename, Data>
let images = storage
    .mapValues(to: UIImage.self,
               transformIn: { data in try UIImage.init(data: data).unwrap() },
               transformOut: { image in try UIImagePNGRepresentation(image).unwrap() }) // Storage<Filename, UIImage>

enum ImageKeys : String {
    case kitten, puppy, fish
}

let keyedImages = images
    .usingStringKeys()
    .mapKeys(toRawRepresentableType: ImageKeys.self) // Storage<ImageKeys, UIImage>

keyedImages.retrieve(forKey: .kitten, completion: { result in /* .. */ })
```

**NOTE:** There are several convenience methods defined on `Storage` with value of `Data`: `.mapString(withEncoding:)`, `.mapJSON()`, `.mapJSONDictionary()`, `.mapJSONObject(_:)` `.mapPlist(format:)`, `.mapPlistDictionary(format:)`, `.mapPlistObject(_:)`.

### Storages composition

Another core concept of **Shallows** is composition. Hitting a disk every time you request an image can be slow and inefficient. Instead, you can compose `MemoryStorage` and `FileSystemStorage`:

```swift
let efficient = MemoryStorage<Filename, UIImage>().combined(with: imageStorage)
```

It does several things:

1. When trying to retrieve an image, the memory storage first will be checked first, and if it doesn't contain a value, the request will be made to disk storage.
2. If disk storage stores a value, it will be pulled to memory storage and returned to a user.
3. When setting an image, it will be set both to memory and disk storage.

### Read-only storage

If you don't want to expose writing to your storage, you can make it a read-only storage:

```swift
let readOnly = storage.asReadOnlyStorage() // ReadOnlyStorage<Key, Value>
```

Read-only storages can also be mapped and composed:

```swift
let immutableFileStorage = DiskStorage.main.folder("immutable", in: .applicationSupportDirectory)
    .mapString(withEncoding: .utf8)
    .asReadOnlyStorage()
let storage = MemoryStorage<Filename, String>()
    .backed(by: immutableFileStorage)
    .asReadOnlyStorage() // ReadOnlyStorage<Filename, String>
```

### Write-only storage

In similar way, write-only storage is also available:

```swift
let writeOnly = storage.asWriteOnlyStorage() // WriteOnlyStorage<Key, Value>
```

### Different ways of composition

**Compositions available for `Storage`**:

- `.combined(with:)` (see [Storages composition](#Storages-composition))
- `.backed(by:)` will work the same as `combined(with:)`, but it will not push the value to the back storage
- `.pushing(to:)` will not retrieve the value from the back storage, but will push to it on `set`

**Compositions available for `ReadOnlyStorage`**:

- `.backed(by:)`

**Compositions available for `WriteOnlyStorage`**:

- `.pushing(to:)`

### Single element storage

You can have a storage with keys `Void`. That means that you can store only one element there. **Shallows** provides a convenience `.singleKey` method to create it:

```swift
let settings = DiskStorage.main.folder("settings", in: .applicationSupportDirectory)
    .mapJSONDictionary()
    .singleKey("settings") // Storage<Void, [String : Any]>
settings.retrieve { (result) in
    // ...
}
```

### Synchronous storage

Storages in **Shallows** are asynchronous by design. However, in some situations (for example, when scripting or testing) it could be useful to have synchronous storages. You can make any storage synchronous by calling `.makeSyncStorage()` on it:

```swift
let strings = DiskStorage.main.folder("strings", in: .cachesDirectory)
    .mapString(withEncoding: .utf8)
    .makeSyncStorage() // SyncStorage<Filename, String>
let existing = try strings.retrieve(forKey: "hello")
try strings.set(existing.uppercased(), forKey: "hello")
```

### Mutating value for key

**Shallows** provides a convenient `.update` method on storages:

```swift
let arrays = MemoryStorage<String, [Int]>()
arrays.update(forKey: "some-key", { $0.append(10) })
```

### Zipping storages

Zipping is a very powerful feature of **Shallows**. It allows you to compose your storages in a way that you get result only when both of them completes for your request. For example:

```swift
let strings = MemoryStorage<String, String>()
let numbers = MemoryStorage<String, Int>()
let zipped = zip(strings, numbers) // Storage<String, (String, Int)>
zipped.retrieve(forKey: "some-key") { (result) in
    if let (string, number) = try? result.get() {
        print(string)
        print(number)
    }
}
zipped.set(("shallows", 3), forKey: "another-key")
```

Isn't it nice?

### Recovering from errors

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

### Using `NSCacheStorage`

`NSCache` is a tricky class: it supports only reference types, so you're forced to use, for example, `NSData` instead of `Data` and so on. To help you out, **Shallows** provides a set of convenience extensions for legacy Foundation types:

```swift
let nscache = NSCacheStorage<NSURL, NSData>()
    .toNonObjCKeys()
    .toNonObjCValues() // Storage<URL, Data>
```

### Making your own storage

To create your own caching layer, you should conform to `StorageProtocol`. That means that you should define these two methods:

```swift
func retrieve(forKey key: Key, completion: @escaping (Result<Value, Error>) -> ())
func set(_ value: Value, forKey key: Key, completion: @escaping (Result<Void, Error>) -> ())
```

Where `Key` and `Value` are associated types.

**NOTE:** Please be aware that you are responsible for the thread-safety of your implementation. Very often `retrieve` and `set` will not be called from the main thread, so you should make sure that no race conditions will occur.

To use it as `Storage<Key, Value>` instance, simply call `.asStorage()` on it:

```swift
let storage = MyStorage().asStorage()
```

You can also conform to a `ReadOnlyStorageProtocol` only. That way, you only need to define a `retrieve(forKey:completion:)` method.

## Installation

#### Swift Package Manager

Starting with Xcode 11, **Shallows** is officially available *only* via Swift Package Manager.

In Xcode 11 or greater, in you project, select: `File > Swift Packages > Add Pacakage Dependency`

In the search bar type

```
https://github.com/dreymonde/Shallows
``` 

Then proceed with installation.

> If you can't find anything in the panel of the Swift Packages you probably haven't added yet your github account.
You can do that under the **Preferences** panel of your Xcode, in the **Accounts** section.

For command-line based apps, you can just add this directly to your **Package.swift** file:

```swift
dependencies: [
    .package(url: "https://github.com/dreymonde/Shallows", from: "0.11.0"),
]
```

#### Manual

Of course, you always have an option of just copying-and-pasting the code.

#### Deprecated dependency managers

Last **Shallows** version to support [Carthage][carthage-url] and [Cocoapods][cocoapods-url] is **0.10.0**. Carthage and Cocoapods will no longer be officially supported.

Carthage:

```ruby
github "dreymonde/Shallows" ~> 0.10.0
```

Cocoapods:

```ruby
pod 'Shallows', '~> 0.10.0'
```

[carthage-url]: https://github.com/Carthage/Carthage
[swift-badge]: https://img.shields.io/badge/Swift-5.1-orange.svg?style=flat
[swift-url]: https://swift.org
[platform-badge]: https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20watchOS%20%7C%20tvOS-lightgrey.svg
[platform-url]: https://developer.apple.com/swift/
[carlos-github-url]: https://github.com/WeltN24/Carlos
[composable-caches-in-swift-url]: https://www.youtube.com/watch?v=8uqXuEZLyUU
[brandon-kase-twitter-url]: https://twitter.com/bkase_
[avenues-github-url]: https://github.com/dreymonde/Avenues
[avenues-shallows-github-url]: https://github.com/dreymonde/Avenues-Shallows
[cocoapods-url]: https://github.com/CocoaPods/CocoaPods
