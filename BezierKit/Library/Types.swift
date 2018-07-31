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

public extension CGRect {
    private var min: CGPoint {
        return CGPoint(x: self.minX, y: self.minY)
    }
    private var max: CGPoint {
        return CGPoint(x: self.maxX, y: self.maxY)
    }
    public func overlaps(_ other: CGRect) -> Bool {
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
    public init(p1: CGPoint, p2: CGPoint) {
        let origin = p1
        let size = CGSize(width: p2.x - p1.x, height: p2.y - p1.y)
        let standardizedRect = CGRect(origin: origin, size: size).standardized
        self.init(origin: standardizedRect.origin, size: standardizedRect.size)
    }
}
