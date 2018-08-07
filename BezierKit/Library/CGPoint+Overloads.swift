//
//  Point.swift
//  BezierKit
//
//  Created by Holmes Futrell on 3/17/17.
//  Copyright © 2017 Holmes Futrell. All rights reserved.
//

import CoreGraphics

extension CGPoint {
    public var length: CGFloat {
        return sqrt(self.lengthSquared)
    }
    private var lengthSquared: CGFloat {
        return self.dot(self)
    }
    public func normalize() -> CGPoint {
        return self / self.length
    }
    static func min(_ p1: CGPoint, _ p2: CGPoint) -> CGPoint {
        return CGPoint(x: p1.x < p2.x ? p1.x : p2.x,
                       y: p1.y < p2.y ? p1.y : p2.y)
    }
    static func max(_ p1: CGPoint, _ p2: CGPoint) -> CGPoint {
        return CGPoint(x: p1.x > p2.x ? p1.x : p2.x,
                       y: p1.y > p2.y ? p1.y : p2.y)
    }
}

public func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
    return (p1 - p2).length
}

private let badSubscriptError = "bad subscript (out of bounds)"

public extension CGPoint {
    static internal let infinity: CGPoint = CGPoint(x: CGFloat.infinity, y: CGFloat.infinity)
    
    static internal var dimensions: Int {
        return 2
    }
    public func dot(_ other: CGPoint) -> CGFloat {
        return self.x * other.x + self.y * other.y
    }
    public subscript(index: Int) -> CGFloat {
        get {
            if index == 0 {
                return self.x
            }
            else if index == 1 {
                return self.y
            }
            else {
                fatalError(badSubscriptError)
            }
        }
        set(newValue) {
            if index == 0 {
                self.x = newValue
            }
            else if index == 1 {
                self.y = newValue
            }
            else {
                fatalError(badSubscriptError)
            }
        }
    }
    public static func + (left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x + right.x, y: left.y + right.y)
    }
    public static func - (left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x - right.x, y: left.y - right.y)
    }
    public static func / (left: CGPoint, right: CGFloat) -> CGPoint {
        return CGPoint(x: left.x / right, y: left.y / right)
    }
    public static func * (left: CGFloat, right: CGPoint) -> CGPoint {
        return CGPoint(x: left * right.x, y: left * right.y)
    }
    public static prefix func - (point: CGPoint) -> CGPoint {
        return CGPoint(x: -point.x, y: -point.y)
    }
}

