//
//  LineSegment.swift
//  BezierKit
//
//  Created by Holmes Futrell on 5/14/17.
//  Copyright © 2017 Holmes Futrell. All rights reserved.
//

import Foundation

public struct LineSegment: BezierCurve {

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
        return BoundingBox(min: BezierKit.min(p0, p1), max: BezierKit.max(p0, p1))
    }
    
    public func compute(_ t: BKFloat) -> BKPoint {
        return Utils.lerp(t, self.p0, self.p1)
    }

    
}
