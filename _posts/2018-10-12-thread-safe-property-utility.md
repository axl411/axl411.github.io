---
layout: post
title:  "封装一个 Thread Safe 的 Property"
date:   2018-10-12 12:17:05 +0900
categories: Swift iOS Concurrency
---

我们来尝试封装一个 utility，目标是能够轻松地为已有的 property 加上线程安全。

首先封装一下 lock api：

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

这样，我们就能像普通的 property 一样去使用我们的线程安全的 property 了。
