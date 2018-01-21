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

public typealias BKFloat = CGFloat
public typealias BKPoint = Point2<CGFloat>

public struct Intersection: Equatable, Comparable {
    public var t1: BKFloat
    public var t2: BKFloat
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
    public var start: BKFloat
    public var end: BKFloat
    public init(start: BKFloat, end: BKFloat) {
        self.start = start
        self.end = end
    }
    public static func == (left: Interval, right: Interval) -> Bool {
        return (left.start == right.start && left.end == right.end)
    }
}

public typealias BoundingBox = BBox<BKPoint>

public struct BBox<P>: Equatable where P: Point {
    public var min: BKPoint
    public var max: BKPoint
    public static func empty() -> BBox<P> {
        return BBox<P>(min: BKPointInfinity, max: -BKPointInfinity)
    }
    internal init(min: BKPoint, max: BKPoint) {
        self.min = min
        self.max = max
    }
    public init(p1: BKPoint, p2: BKPoint) {
        self.min = BKPoint.min(p1, p2)
        self.max = BKPoint.max(p1, p2)
    }
    public init(first: BoundingBox, second: BoundingBox) {
        self.min = BKPoint.min(first.min, second.min)
        self.max = BKPoint.max(first.max, second.max)
    }
    public var size: BKPoint {
        return BKPoint.max(max - min, BKPointZero)
    }
    public func overlaps(_ other: BoundingBox) -> Bool {
        let p1 = BKPoint.max(self.min, other.min)
        let p2 = BKPoint.min(self.max, other.max)
        for i in 0..<P.dimensions {
            let difference = p2[i] - p1[i]
            if difference.isNaN || difference < 0 {
                return false
            }
        }
        return true
    }
    public static func == (left: BBox<P>, right: BBox<P>) -> Bool {
        return (left.min == right.min && left.max == right.max)
    }
}

public let BKPointZero: BKPoint = BKPoint(x: 0.0, y: 0.0)
public let BKPointInfinity: BKPoint = BKPoint(x: BKFloat.infinity, y: BKFloat.infinity)

