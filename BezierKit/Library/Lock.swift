//
//  Lock.swift
//  BezierKit
//
//  Created by Holmes Futrell on 5/24/19.
//  Copyright © 2019 Holmes Futrell. All rights reserved.
//

import Foundation

#if canImport(Darwin)
internal final class UnfairLock {
    private let lockPointer: UnsafeMutablePointer<os_unfair_lock>
    init() {
        lockPointer = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        lockPointer.initialize(to: os_unfair_lock())
    }
    deinit {
        lockPointer.deallocate()
    }
    func sync<T>(_ f: () throws -> T) rethrows -> T {
        os_unfair_lock_lock(lockPointer)
        defer { os_unfair_lock_unlock(lockPointer) }
        return try f()
    }
}
#else
internal final class UnfairLock {
    private let lock = NSLock()
    func sync<T>(_ f: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try f()
    }
}
#endif
