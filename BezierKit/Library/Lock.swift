//
//  Lock.swift
//  BezierKit
//
//  Created by Holmes Futrell on 5/24/19.
//  Copyright © 2019 Holmes Futrell. All rights reserved.
//

import Foundation
#if canImport(Darwin)
import os
#endif

/// A mutual-exclusion lock used to make external access of lazy properties threadsafe.
///
/// The backing primitive is chosen by availability via `makeLock()`: where
/// `OSAllocatedUnfairLock` is available (iOS 16 / macOS 13 / tvOS 16 / watchOS 9 and
/// newer) it is the preferred implementation; everywhere else (older Apple OS versions,
/// Linux, WASM) the fallback is `NSLock`.
///
/// The protocol is deliberately not class-bound: both conformers are one word
/// (`OSAllocatedUnfairLock` is a single managed buffer reference, `NSLock` is a class
/// reference), so an `any Lock` stores them inline rather than boxing them.
internal protocol Lock {
    func sync<T>(_ f: () throws -> T) rethrows -> T
}

/// `NSLock` is the fallback used wherever `OSAllocatedUnfairLock` is unavailable.
extension NSLock: Lock {
    func sync<T>(_ f: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try f()
    }
}

#if canImport(Darwin)
@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension OSAllocatedUnfairLock: Lock where State == Void {
    // withLockUnchecked (rather than withLock) because the protected closures capture
    // `self` and return non-Sendable values, which the Sendable-constrained withLock rejects.
    func sync<T>(_ f: () throws -> T) rethrows -> T {
        try withLockUnchecked(f)
    }
}
#endif

/// Returns the preferred `Lock` implementation available on the current platform.
internal func makeLock() -> any Lock {
    #if canImport(Darwin)
    if #available(macOS 13, iOS 16, tvOS 16, watchOS 9, *) {
        return OSAllocatedUnfairLock(initialState: ())
    }
    #endif
    return NSLock()
}
