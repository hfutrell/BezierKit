//
//  LineSegment.swift
//  BezierKit
//
//  Created by Holmes Futrell on 5/14/17.
//  Copyright © 2017 Holmes Futrell. All rights reserved.
//

import Foundation

public struct LineSegment: BezierCurve, Equatable {

    public var p0, p1: BKPoint
    
    public init(points: [BKPoint]) {
        precondition(points.count == 2)
        self.p0 = points[0]
        self.p1 = points[1]
    }
    
    public init(p0: BKPoint, p1: BKPoint) {
        self.p0 = p0
        self.p1 = p1
    }
    
    public var points: [BKPoint] {
        return [p0, p1]
    }
    
    public var startingPoint: BKPoint {
        return p0
    }
    
    public var endingPoint: BKPoint {
        return p1
    }
    
    public var order: Int {
        return 1
    }
    
    public var simple: Bool {
        return true
    }
    
    public func derivative(_ t: BKFloat) -> BKPoint {
        return self.p1 - self.p0
    }
    
    public func split(from t1: BKFloat, to t2: BKFloat) -> LineSegment {
        let p0 = self.p0
        let p1 = self.p1
        return LineSegment(p0: Utils.lerp(t1, p0, p1),
                           p1: Utils.lerp(t2, p0, p1))
    }
    
    public func split(at t: BKFloat) -> (left: LineSegment, right: LineSegment) {
        let p0  = self.p0
        let p1  = self.p1
        let mid = Utils.lerp(t, p0, p1)
        let left = LineSegment(p0: p0, p1: mid)
        let right = LineSegment(p0: mid, p1: p1)
        return (left: left, right: right)
    }
    
    public var boundingBox: BoundingBox {
        let p0: BKPoint = self.p0
        let p1: BKPoint = self.p1
        return BoundingBox(min: BKPoint.min(p0, p1), max: BKPoint.max(p0, p1))
    }
    
    public func compute(_ t: BKFloat) -> BKPoint {
        return Utils.lerp(t, self.p0, self.p1)
    }
    
    // -- MARK: Equatable
    
    public static func == (left: LineSegment, right: LineSegment) -> Bool {
        return left.p0 == right.p0 && left.p1 == right.p1
    }
    
    // -- MARK: - overrides
    
    public func length() -> BKFloat {
        return (self.p1 - self.p0).length
    }
    
    public func extrema() -> (xyz: [[BKFloat]], values: [BKFloat] ) {
        // for a line segment the extrema are trivially just the start and end points
        // which have t = 0.0 and 1.0
        var xyz: [[BKFloat]] = []
        for _ in 0..<BKPoint.dimensions {
            xyz.append([0.0, 1.0])
        }
        return (xyz: xyz, [0.0, 1.0])
    }
        
    public func intersects(curve: BezierCurve, curveIntersectionThreshold: BKFloat = LineSegment.defaultCurveIntersectionThreshold) -> [Intersection] {
        if let l = curve as? LineSegment {
            // use fast line / line intersection algorithm
            return self.intersects(line: l)
        }
        // call into the curve's line intersection algorithm
        let intersections = curve.intersects(line: self)
        // invert and re-sort the order of the intersections since
        // intersects was called on the line and not the curve
        return intersections.map({(i: Intersection) in
            return Intersection(t1: i.t2, t2: i.t1)
        }).sorted()
    }
    
    public func intersects(line: LineSegment) -> [Intersection] {
        let a1 = self.p0
        let b1 = self.p1 - self.p0
        let a2 = line.p0
        let b2 = line.p1 - line.p0
        
        let _a = b1.x
        let _b = -b2.x
        let _c = b1.y
        let _d = -b2.y
        
        // by Cramer's rule we have
        // t1 = ed - bf / ad - bc
        // t2 = af - ec / ad - bc
        let det = _a * _d - _b * _c
        
        let _e = -a1.x + a2.x
        let _f = -a1.y + a2.y
        
        let inv_det = 1.0 / det
        let t1 = ( _e * _d - _b * _f ) * inv_det
        if t1 > 1.0 || t1 < 0.0  {
            return [] // t1 out of interval [0, 1]
        }
        let t2 = ( _a * _f - _e * _c ) * inv_det
        if t2 > 1.0 || t2 < 0.0 {
            return [] // t2 out of interval [0, 1]
        }
        return [Intersection(t1: t1, t2: t2)]
    }
    
    public func project(point: BKPoint) -> BKPoint {
        // optimized implementation for line segments can be directly computed
        // default project implementation is found in BezierCurve protocol extension
        let relativePoint    = point - self.p0
        let delta            = self.p1 - self.p0
        var t                = relativePoint.dot(delta) / delta.dot(delta)
        if t < 0.0 {
            t = 0.0
        }
        else if t > 1.0 {
            t = 1.0
        }
        return self.compute(t)
    }

    
}
