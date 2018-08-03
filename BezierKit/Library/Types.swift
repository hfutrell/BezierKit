//
//  Types.swift
//  BezierKit
//
//  Created by Holmes Futrell on 11/3/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import Foundation

#if os(iOS)
    import CoreGraphics
#endif

public struct Intersection: Equatable, Comparable {
    public var t1: CGFloat
    public var t2: CGFloat
    public static func == (lhs: Intersection, rhs: Intersection) -> Bool {
        return lhs.t1 == rhs.t1 && lhs.t2 == rhs.t2
    }
    public static func < (lhs: Intersection, rhs: Intersection ) -> Bool {
        if lhs.t1 < rhs.t1 {
            return true
        }
        else if lhs.t1 == rhs.t1 {
            return lhs.t2 < rhs.t2
        }
        else {
            return false
        }
    }
}

public struct Interval: Equatable {
    public var start: CGFloat
    public var end: CGFloat
    public init(start: CGFloat, end: CGFloat) {
        self.start = start
        self.end = end
    }
    public static func == (left: Interval, right: Interval) -> Bool {
        return (left.start == right.start && left.end == right.end)
    }
}

public struct BoundingBox: Equatable {
    public var min: CGPoint
    public var max: CGPoint
    public var cgRect: CGRect {
        let s = self.size
        return CGRect(origin: self.min, size: CGSize(width: s.x, height: s.y))
    }
    public static let empty: BoundingBox = BoundingBox(min: .infinity, max: -.infinity)
    internal init(min: CGPoint, max: CGPoint) {
        self.min = min
        self.max = max
    }
    public init(p1: CGPoint, p2: CGPoint) {
        self.min = CGPoint.min(p1, p2)
        self.max = CGPoint.max(p1, p2)
    }
    public init(first: BoundingBox, second: BoundingBox) {
        self.min = CGPoint.min(first.min, second.min)
        self.max = CGPoint.max(first.max, second.max)
    }
    public var size: CGPoint {
        return CGPoint.max(max - min, .zero)
    }
    public func overlaps(_ other: BoundingBox) -> Bool {
        let p1 = CGPoint.max(self.min, other.min)
        let p2 = CGPoint.min(self.max, other.max)
        for i in 0..<CGPoint.dimensions {
            let difference = p2[i] - p1[i]
            if difference.isNaN || difference < 0 {
                return false
            }
        }
        return true
    }
    public func distance(from point: CGPoint) -> CGFloat {
    }
    public static func == (left: BoundingBox, right: BoundingBox) -> Bool {
        return (left.min == right.min && left.max == right.max)
    }
}
