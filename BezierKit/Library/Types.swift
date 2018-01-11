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

public struct Arc: Equatable {
    public var origin: BKPoint
    public var radius: BKFloat
    public var start: BKFloat // starting angle (in radians)
    public var end: BKFloat // ending angle (in radians)
    public var interval: Interval // represents t-values [0, 1] on curve
    public init(origin: BKPoint, radius: BKFloat, start: BKFloat, end: BKFloat, interval: Interval = Interval(start: 0.0, end: 1.0)) {
        self.origin = origin
        self.radius = radius
        self.start = start
        self.end = end
        self.interval = interval
    }
    public static func == (left: Arc, right: Arc) -> Bool {
        return (left.origin == right.origin && left.radius == right.radius && left.start == right.start && left.end == right.end && left.interval == right.interval)
    }
    public func compute(_ t: BKFloat) -> BKPoint {
        // computes a value on the arc with t in [0, 1]
        let theta: BKFloat = t * self.end + (1.0 - t) * self.start
        return self.origin + self.radius * BKPoint(x: cos(theta), y: sin(theta))
    }
}

public struct Shape {
    struct Cap {
        var curve: BezierCurve
        var virtual: Bool
        init(curve: BezierCurve) {
            self.curve = curve
            self.virtual = false
        }
    }
    var startcap: Cap
    var endcap: Cap
    var forward: BezierCurve
    var back: BezierCurve
    func boundingBox() -> BoundingBox {
        var result: BoundingBox = BoundingBox()
        for s: BezierCurve? in [startcap.virtual ? nil : startcap.curve, forward, back, endcap.virtual ? nil : endcap.curve] {
            if s != nil {
                let bbox: BoundingBox = s!.boundingBox
                result = BoundingBox(first: result, second: bbox)
            }
        }
        return result
    }
}

public typealias BoundingBox = BBox<BKPoint>

public struct BBox<P>: Equatable where P: Point {
    public var min: BKPoint
    public var max: BKPoint
    init() {
        
        // TODO: I really dislike this function
        
        // by setting the min to infinity and the max to -infinity
        // when we union this (invalid) rect with a valid rect, we'll
        // get back the valid rect
        min = BKPointInfinity
        max = -BKPointInfinity
    }
    public init(min: BKPoint, max: BKPoint) {
        self.min = min
        self.max = max
    }
    public init(first: BoundingBox, second: BoundingBox) {
        self.min = BKPoint.min(first.min, second.min)
        self.max = BKPoint.max(first.max, second.max)
    }
    public var mid: BKPoint {
        return 0.5 * (min + max)
    }
    public var size: BKPoint {
        return max - min
    }
    public func overlaps(_ other: BoundingBox) -> Bool {
        for i in 0..<P.dimensions {
            if self.min[i] > other.max[i] {
                return false
            }
            if self.max[i] < other.min[i] {
                return false
            }
        }
        return true
    }
    public var toCGRect: CGRect {
        let s = self.size
        return CGRect(origin: self.min.toCGPoint(), size: CGSize(width: s.x, height: s.y))
    }
    public static func == (left: BBox<P>, right: BBox<P>) -> Bool {
        return (left.min == right.min && left.max == right.max)
    }
}

public let BKPointZero: BKPoint = BKPoint(x: 0.0, y: 0.0)
public let BKPointInfinity: BKPoint = BKPoint(x: BKFloat.infinity, y: BKFloat.infinity)

