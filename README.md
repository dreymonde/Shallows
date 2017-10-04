# Shallows

[![Swift][swift-badge]][swift-url]
[![Platform][platform-badge]][platform-url]

**Shallows** is a generic abstraction layer over lightweight data storage and persistence. It provides a `Cache<Key, Value>` type, instances of which can be easily transformed and composed with each other. It gives you an ability to create highly sophisticated, effective and reliable caching/persistence solutions.

**Shallows** is deeply inspired by [Carlos][carlos-github-url] and [this amazing talk][composable-caches-in-swift-url] by [Brandon Kase][brandon-kase-twitter-url].

**Shallows** is a really small, component-based project, so if you need even more controllable solution – build one yourself! Our source code is there to help.

## Usage

### Showcase

Using **Shallows** for two-step JSON cache (memory and disk):

```swift
struct Player : Codable {
    let name: String
    let rating: Int
}

let memoryCache = MemoryCache<String, Player>()
let diskCache = FileSystemCache.inDirectory(.cachesDirectory, appending: "cache")
    .mapJSONObject(Player.self)
    .usingStringKeys()
let combinedCache = memoryCache.combined(with: diskCache)
combinedCache.retrieve(forKey: "Higgins") { (result) in
    if let player = result.value {
        print(player.name)
    }
}
combinedCache.set(Player(name: "Mark", rating: 1), forKey: "Selby") { (result) in
    if result.isSuccess {
        print("Success!")
    }
}
```

### Guide

A main type of **Shallows** is `Cache<Key, Value>`. It's an abstract, type-erased structure which doesn't contain any logic -- it needs to be provided with one. The most basic one is `MemoryCache`:

```swift
let cache = MemoryCache<String, Int>().asCache() // Cache<String, Int>
```

Cache instances have `retrieve` and `set` methods, which are asynhronous and fallible:

```swift
cache.retrieve(forKey: "some-key") { (result) in
    switch result {
    case .success(let value):
        print(value)
    case .failure(let error):
        print(error)
    }
}
cache.set(10, forKey: "some-key") { (result) in
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
let stringCache = cache.mapValues(transformIn: { String($0) },
                                  transformOut: { try Int($0).unwrap() }) // Cache<String, String>
// ...
enum EnumKey : String {
    case first, second, third
}
let keyedCache: Cache<EnumKey, String> = stringCache.mapKeys({ $0.rawValue })
```

The concept of keys and values transformations is really powerful and it lies in the core of **Shallows**. For example, `FileSystemCache` provides a `Cache<String, Data>` instances, and you can easily map `Data` to something useful. For example, `UIImage`:

```swift
// FileSystemCache is a cache of String : Data
let fileSystemCache = FileSystemCache.inDirectory(.cachesDirectory, appending: "shallows-caches-1")
let imageCache = fileSystemCache.mapValues(transformIn: { try UIImage(data: $0).unwrap() },
                                           transformOut: { try UIImagePNGRepresentation($0).unwrap() })
```

Now you have an instance of type `Cache<String, UIImage>` which can be used to store images without much fuss.

**NOTE:** There are several convenience methods defined on `Cache` with value of `Data`: `.mapString(withEncoding:)`, `.mapJSON()`, `.mapJSONDictionary()`, `.mapJSONObject(_:)` `.mapPlist(format:)`, `.mapPlistDictionary(format:)`, `.mapPlistObject(_:)`.

#### Caches composition

Another core concept of **Shallows** is composition. Hitting a disk every time you request an image can be slow and inefficient. Instead, you can compose `MemoryCache` and `FileSystemCache`:

```swift
let efficient = MemoryCache<String, UIImage>().combined(with: imageCache)
```

It does several things:

1. When trying to retrieve an image, the memory cache first will be checked first, and if it doesn't contain a value, the request will be made to disk cache.
2. If disk cache stores a value, it will be pulled to memory cache and returned to a user.
3. When setting an image, it will be set both to memory and disk cache.

Great things about composing caches is that in the end, you still has your `Cache<Key, Value>` instance. That means that you can recompose cache layers however you want without breaking the usage code. It also makes the code that depends on `Cache` very easy to test.

The huge advantage of **Shallows** is that it doesn't try to hide the actual mechanism - the behavior of your caches is perfectly clear, and still very simple to understand and easy to use. You control how many layers your cache has, how it acts and what it stores. **Shallows** is not an end-product - instead, it's a tool that will help you build exactly what you need.

#### Read-only cache

If you don't want to expose writing to your cache, you can make it a read-only cache:

```swift
let readOnly = cache.asReadOnlyCache() // ReadOnlyCache<Key, Value>
```

Read-only caches can also be mapped and composed:

```swift
let immutableFileCache = FileSystemCache.inDirectory(.cachesDirectory, appending: "shallows-immutable")
    .mapString(withEncoding: .utf8)
    .asReadOnlyCache()
let cache = MemoryCache<String, String>()
    .combined(with: immutableFileCache)
    .asReadOnlyCache() // ReadOnlyCache<String, String>
```

#### Write-only cache

In similar way, write-only cache is also available:

```swift
let writeOnly = cache.asWriteOnlyCache() // WriteOnlyCache<Key, Value>
```

#### Single element cache

You can have a cache with keys `Void`. That means that you can store only one element there. **Shallows** provides a convenience `.singleKey` method to create it:

```swift
let settingsCache = FileSystemCache.inDirectory(.documentDirectory, appending: "settings")
    .mapJSONDictionary()
    .singleKey("settings") // Cache<Void, [String : Any]>
settingsCache.retrieve { (result) in
    // ...
}
```

#### Synchronous cache

Caches in **Shallows** are asynchronous by it's nature. However, in some situations (for example, when scripting or testing) it could be useful to have synchronous caches. You can make any cache synchronous by calling `.makeSyncCache()` on it:

```swift
let strings = FileSystemCache.inDirectory(.cachesDirectory, appending: "strings")
    .mapString(withEncoding: .utf8)
    .makeSyncCache() // SyncCache<String, String>
let existing = try strings.retrieve(forKey: "hello")
try strings.set(existing.uppercased(), forKey: "hello")
```

However, be careful with that: some caches may be designed to complete more than one time (for example, some caches may quickly return value stored in a local cache and then ask the server for an update). Making a cache like this synchronous will kill that functionality.

#### Mutating value for key

**Shallows** provides a convenient `.update` method on caches:

```swift
let arrays = MemoryCache<String, [Int]>()
arrays.update(forKey: "some-key", { $0.append(10) }) { (result) in
    // ...
}
```

#### Zipping caches

Zipping is a very powerful feature of **Shallows**. It allows you to compose your caches in a way that you get result only when both of them completes for your request. For example:

```swift
let strings = MemoryCache<String, String>()
let numbers = MemoryCache<String, Int>()
let zipped = zip(strings, numbers) // Cache<String, (String, Int)>
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

Caches can be composed in different ways. If you look at the `combined` method, it actually looks like this:

```swift
public func combined<CacheType : CacheProtocol>(with cache: CacheType,
                     pullStrategy: CacheCombinationPullStrategy,
                     setStrategy: CacheCombinationSetStrategy) -> Cache<Key, Value> where CacheType.Key == Key, CacheType.Value == Value
```

Where `pullStrategy` defaults to `.pullThenComplete` and `setStrategy` defaults to `.frontFirst`. Available options are:

```swift
public enum CacheCombinationPullStrategy {
    case pullThenComplete
    case completeThenPull
    case neverPull
}

public enum CacheCombinationSetStrategy {
    case backFirst
    case frontFirst
    case frontOnly
    case backOnly
}
```

You can change these parameters to accomplish a behavior you want.

#### Recovering from errors

You can protect your cache instance from failures using `fallback(with:)` or `defaulting(to:)` methods:

```swift
let cache = MemoryCache<String, Int>()
let protected = cache.fallback(with: { error in
    switch error {
    case MemoryCacheError.noValue:
        return 15
    default:
        return -1
    }
})
```

```swift
let cache = MemoryCache<String, Int>()
let defaulted = cache.defaulting(to: -1)
```

This is _especially_ useful when using `update` method:

```swift
let cache = MemoryCache<String, [Int]>()
cache.defaulting(to: []).update(forKey: "first", { $0.append(10) })
```

That means that in case of failure retrieving existing value, `update` will use default value of `[]` instead of just failing the whole update.

#### Using `NSCacheCache`

`NSCache` is a tricky class: it supports only reference types, so you're forced to use, for example, `NSData` instead of `Data` and so on. To help you out, **Shallows** provides a set of convenience extensions for legacy Foundation types:

```swift
let nscache = NSCacheCache<NSURL, NSData>()
    .toNonObjCKeys()
    .toNonObjCValues() // Cache<URL, Data>
```

### Making your own cache

To create your own caching layer, you should conform to `CacheProtocol`. That means that you should define these two methods:

```swift
func retrieve(forKey key: Key, completion: @escaping (Result<Value>) -> ())
func set(_ value: Value, forKey key: Key, completion: @escaping (Result<Void>) -> ())
```

Where `Key` and `Value` are associated types.

**NOTE:** Please be aware that you should care about thread-safety of your implementation. Very often `retrieve` and `set` will not be called from the main thread, so you should make sure that no race conditions will occur.

To use it as `Cache<Key, Value>` instance, simply call `.asCache()` on it:

```swift
let cache = MyCache().asCache()
```

You can also conform to a `ReadableCacheProtocol` only. That way, you only need to define a `retrieve(forKey:completion:)` method.

### Using Shallows with images in `UITableView`

Well, you shouldn't really do that. Technically you can, but really **Shallows** is not the best option for this task. Instead, you should use [Avenues][avenues-github-url], which is designed exactly for this. Saying more, **Shallows** and **Avenues** complement each other very well - **Shallows** can be used to cache fetched images on disk (which **Avenues** doesn't do). You can check out the [Avenues+Shallows][avenues-shallows-github-url] repo for more details.

## Installation
**Shallows** is available through [Carthage][carthage-url]. To install, just write into your Cartfile:

```ruby
github "dreymonde/Shallows" ~> 0.5.0
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