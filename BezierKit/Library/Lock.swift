//
//  Lock.swift
//  BezierKit
//
//  Created by Holmes Futrell on 5/24/19.
//  Copyright © 2019 Holmes Futrell. All rights reserved.
//

import Foundation

internal extension os_unfair_lock_s {
    mutating func sync<T>(_ f: () throws -> T) rethrows -> T {
        os_unfair_lock_lock(&self)
        defer { os_unfair_lock_unlock(&self) }
        return try f()
    }
}
