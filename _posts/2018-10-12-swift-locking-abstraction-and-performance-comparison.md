---
layout: post
title:  "Swift 下各种 Locking Mechanism 的封装及性能比较"
date:   2018-10-12 12:17:05 +0900
categories: Swift iOS Concurrency
---

我们来尝试封装一个 utility，目标是能够轻松地为已有的 property 加上线程安全。

# 封装 Lock api

首先封装一下 lock api，以 unfair lock 为例：

```swift
public final class UnfairLock {
    private var unfairLock = os_unfair_lock()

    public func lock() {
        os_unfair_lock_lock(&unfairLock)
    }

    public func unlock() {
        os_unfair_lock_unlock(&unfairLock)
    }
}
```

这样，我们能够更容易地使用 lock api：

```swift
// declare lock as a property
private var lock = UnfairLock()

// in some methods...
lock.lock()
defer { lock.unlock() }
// do critical things safely
```

# 封装线程安全的 property

然后，我们进一步地封装一个 `LockedPropertyWrapper`：

```swift
public final class LockedPropertyWrapper<T> {
    private var wrapped: T
    private var lock = UnfairLock()

    public init(wrapped: T) {
        self.wrapped = wrapped
    }

    public var value: T {
        get {
            lock.lock()
            defer { lock.unlock() }
            return wrapped
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            wrapped = newValue
        }
    }

    /// Set the wrapped property using a closure
    /// - Parameters:
    ///   - setter: takes in the old value, returns the new value
    ///   - oldValue: the old value
    public func setValue(_ setter: (_ oldValue: T) -> T) {
        lock.lock()
        defer { lock.unlock() }
        wrapped = setter(wrapped)
    }

    /// Mutate the wrapped property using a closure
    /// - Parameters:
    ///   - mutator: takes in the wrapped value, modifications to it can be done safely
    ///   - wrappedValue: the wrapped value
    public func mutateValue(_ mutator: (_ wrappedValue: inout T) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        mutator(&wrapped)
    }
}
```

这样，我们就能够比较轻松地为我们的 property 加上线程安全：

```swift
// declaration
let myPropertyWrapper = LockedPropertyWrapper(wrapped: MyProperty())

// get myProperty safely
let myProperty = myPropertyWrapper.value

// set myProperty safely
myPropertyWrapper.value = newValue
```

如果 `myProperty` 是 private 的，我们可以简单地直接在代码里使用它的 wrapper，如上☝️所示。我们也可以进一步使用一个 computed property 来提供和普通 property 一样的 interface：

```swift
var myProperty: MyProperty {
    get { return myPropertyWrapper.value }
    set { myPropertyWrapper.value = newValue }
}
```

这样，我们就能像普通的 property 一样去使用它了。

⚠️ 需要注意的是，我们的 `LockedPropertyWrapper.value` 以及 `myProperty` 实现的只是 atomic，对它们的操作并不能保证线程安全。例如，从多个线程同时执行 `myProperty += 1` 是线程不安全的，因为这实际上是两个操作：读和写。要确保线程安全，还是需要用 `setValue(_:)` 或者 `mutateValue(_:)`

# 其他各种 locking mechanism 的封装

用上文同样的思路我们可以封装其他 lock 的 api 如下：

```swift
public final class Lock {
    private let nsLock = NSLock()
    public func lock() { nsLock.lock() }
    public func unlock() { nsLock.unlock() }
}

public final class RecrusiveLock {
    private let nsLock = NSRecursiveLock()
    public func lock() { nsLock.lock() }
    public func unlock() { nsLock.unlock() }
}

public final class MutexLock {
    private var mutexLock: pthread_mutex_t = {
        var mutex = pthread_mutex_t()
        pthread_mutex_init(&mutex, nil)
        return mutex
    }()
    public func lock() { pthread_mutex_lock(&mutexLock) }
    public func unlock() { pthread_mutex_unlock(&mutexLock) }
}

public final class ObjcSyncLock {
    private let obj = NSObject()
    public func lock() { objc_sync_enter(obj) }
    public func unlock() { objc_sync_exit(obj) }
}

public final class SemaphoreLock {
    private let sem = DispatchSemaphore(value: 1)
    public func lock() { sem.wait() }
    public func unlock() { sem.signal() }
}
```

当然我们还可以用 `DispatchQueue` 的 `sync` 来实现 locking。

# 各种 locking mechanism 的性能比较

我准备了[一段代码](https://github.com/axl411/LockingMethodsComparison)来测试各种 locking mechanism 的性能，方式是用3个线程同时对一个线程安全的 counter 增1 各300000次。测试结果如下：

```
+++++ UnfairLock +++++
    ✅ elapsed time: 0.43625009059906006

+++++ ObjcSyncLock +++++
    ✅ elapsed time: 0.45990192890167236

+++++ MutexLock +++++
    ✅ elapsed time: 1.0517339706420898

+++++ Lock +++++
    ✅ elapsed time: 1.0154080390930176

+++++ RecrusiveLock +++++
    ✅ elapsed time: 1.3077090978622437

+++++ SemaphoreLock +++++
    ✅ elapsed time: 5.190653085708618

+++++ SyncQueue +++++
    ✅ elapsed time: 7.316784024238586
```

结论：
- 能用 `os_unfair_lock` 的话就用 `os_unfair_lock` 吧。
- `NSLock` 和 `pthread_mutex_t` 的性能差不多，并没有因为 `pthread_mutex_t` 是下层 api 就更快。
- 单纯地用 `DispatchSemaphore` 甚至是 `DispatchQueue.sync` 来实现一个 property 的安全是不合适的，慢太多了，它们应该被用在有更复杂需求的场景。
