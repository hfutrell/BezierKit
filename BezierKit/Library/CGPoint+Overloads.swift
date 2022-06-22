//
//  Point.swift
//  BezierKit
//
//  Created by Holmes Futrell on 3/17/17.
//  Copyright © 2017 Holmes Futrell. All rights reserved.
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

// swiftlint:disable shorthand_operator

public extension CGPoint {
    var length: Double {
        return sqrt(self.lengthSquared)
    }
    internal var lengthSquared: Double {
        return self.dot(self)
    }
    func normalize() -> CGPoint {
        return self / self.length
    }
    internal static func min(_ p1: CGPoint, _ p2: CGPoint) -> CGPoint {
        return CGPoint(x: p1.x < p2.x ? p1.x : p2.x,
                       y: p1.y < p2.y ? p1.y : p2.y)
    }
    internal static func max(_ p1: CGPoint, _ p2: CGPoint) -> CGPoint {
        return CGPoint(x: p1.x > p2.x ? p1.x : p2.x,
                       y: p1.y > p2.y ? p1.y : p2.y)
    }
    internal var perpendicular: CGPoint {
        return CGPoint(x: -self.y, y: self.x)
    }
}

public func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
    return (p1 - p2).length
}

public func distanceSquared(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
    return (p1 - p2).lengthSquared
}

private let badSubscriptError = "bad subscript (out of bounds)"

public extension CGPoint {
    static internal let infinity: CGPoint = CGPoint(x: CGFloat.infinity, y: CGFloat.infinity)

    static internal var dimensions: Int {
        return 2
    }
    func dot(_ other: CGPoint) -> Double {
        return self.x * other.x + self.y * other.y
    }
    func cross(_ other: CGPoint) -> CGFloat {
        return self.x * other.y - self.y * other.x
    }
    subscript(index: Int) -> CGFloat {
        get {
            assert(index == 0 || index == 1)
            if index == 0 {
                return self.x
            } else {
                return self.y
            }
        }
        set(newValue) {
            assert(index == 0 || index == 1)
            if index == 0 {
                self.x = newValue
            } else {
                self.y = newValue
            }
        }
    }
    static func + (left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x + right.x, y: left.y + right.y)
    }
    static func - (left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x - right.x, y: left.y - right.y)
    }
    static func += (left: inout CGPoint, right: CGPoint) {
        left = left + right
    }
    static func -= (left: inout CGPoint, right: CGPoint) {
        left = left - right
    }
    static func / (left: CGPoint, right: Double) -> CGPoint {
        return CGPoint(x: left.x / right, y: left.y / right)
    }
    static func * (left: Double, right: CGPoint) -> CGPoint {
        return CGPoint(x: left * right.x, y: left * right.y)
    }
    static prefix func - (point: CGPoint) -> CGPoint {
        return CGPoint(x: -point.x, y: -point.y)
    }
}
