//
//  Types.swift
//  BezierKit
//
//  Created by Holmes Futrell on 11/3/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import Foundation

public typealias BKFloat = CGFloat
public typealias BKPoint = Point2<CGFloat>

public struct Intersection {
    var t1: BKFloat
    var t2: BKFloat
}

public struct Line {
    var p1: BKPoint
    var p2: BKPoint
}

public struct Arc {
    struct Interval {
        var start: BKFloat
        var end: BKFloat
    }
    var origin: BKPoint
    var radius: BKFloat
    var start: BKFloat // starting angle
    var end: BKFloat // starting angle
    var interval: Interval // represents t-values [0, 1] on curve
}

public struct Shape {
    struct Cap {
        var curve: CubicBezierCurve
        var virtual: Bool
        init(curve: CubicBezierCurve) {
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

public struct BBox<P> where P: Point {
    var min: BKPoint
    var max: BKPoint
    init() {
        // by setting the min to infinity and the max to -infinity
        // when we union this (invalid) rect with a valid rect, we'll
        // get back the valid rect
        min = BKPointInfinity
        max = -BKPointInfinity
    }
    init(min: BKPoint, max: BKPoint) {
        self.min = min
        self.max = max
    }
    init(first: BoundingBox, second: BoundingBox) {
        var min = first.min
        var max = second.max
        for d in 0..<P.dimensions {
            if first.max[d] > max[d] {
                max[d] = first.min[d]
            }
            if second.min[d] < min[d] {
                min[d] = second.min[d]
            }
        }
        self.min = min
        self.max = max
    }
    var mid: BKPoint {
        return 0.5 * (min + max)
    }
    var size: BKPoint {
        return max - min
    }
    func overlaps(_ other: BoundingBox) -> Bool {
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
    var toCGRect: CGRect {
        let s = self.size
        return CGRect(origin: self.min.toCGPoint(), size: CGSize(width: s.x, height: s.y))
    }
}

public let BKPointZero: BKPoint = BKPoint(x: 0.0, y: 0.0)
public let BKPointInfinity: BKPoint = BKPoint(x: BKFloat.infinity, y: BKFloat.infinity)

