//
//  LineSegment.swift
//  BezierKit
//
//  Created by Holmes Futrell on 5/14/17.
//  Copyright © 2017 Holmes Futrell. All rights reserved.
//

import CoreGraphics

public struct LineSegment: BezierCurve, Equatable {

    public var p0, p1: CGPoint

    public init(points: [CGPoint]) {
        precondition(points.count == 2)
        self.p0 = points[0]
        self.p1 = points[1]
    }

    public init(p0: CGPoint, p1: CGPoint) {
        self.p0 = p0
        self.p1 = p1
    }

    public var points: [CGPoint] {
        return [p0, p1]
    }

    public var startingPoint: CGPoint {
        get {
            return p0
        }
        set(newValue) {
            p0 = newValue
        }
    }

    public var endingPoint: CGPoint {
        get {
            return p1
        }
        set(newValue) {
            p1 = newValue
        }
    }

    public var order: Int {
        return 1
    }

    public var simple: Bool {
        return true
    }

    public func derivative(at t: CGFloat) -> CGPoint {
        return self.p1 - self.p0
    }

    public func normal(at t: CGFloat) -> CGPoint {
        return (self.p1 - self.p0).perpendicular.normalize()
    }

    public func split(from t1: CGFloat, to t2: CGFloat) -> LineSegment {
        return LineSegment(p0: self.point(at: t1), p1: self.point(at: t2))
    }

    public func split(at t: CGFloat) -> (left: LineSegment, right: LineSegment) {
        let p0  = self.p0
        let p1  = self.p1
        let mid = Utils.lerp(t, p0, p1)
        let left = LineSegment(p0: p0, p1: mid)
        let right = LineSegment(p0: mid, p1: p1)
        return (left: left, right: right)
    }

    public var boundingBox: BoundingBox {
        let p0: CGPoint = self.p0
        let p1: CGPoint = self.p1
        return BoundingBox(min: CGPoint.min(p0, p1), max: CGPoint.max(p0, p1))
    }

    public func point(at t: CGFloat) -> CGPoint {
        if t == 0 {
            return self.p0
        } else if t == 1 {
            return self.p1
        } else {
            return Utils.lerp(t, self.p0, self.p1)
        }
    }

    // -- MARK: - overrides

    public func length() -> CGFloat {
        return (self.p1 - self.p0).length
    }

    public func extrema() -> (x: [CGFloat], y: [CGFloat], all: [CGFloat]) {
        return (x: [], y: [], all: [])
    }

    public func project(_ point: CGPoint) -> (point: CGPoint, t: CGFloat) {
        // optimized implementation for line segments can be directly computed
        // default project implementation is found in BezierCurve protocol extension
        let relativePoint    = point - self.p0
        let delta            = self.p1 - self.p0
        let t                = Utils.clamp(relativePoint.dot(delta) / delta.dot(delta), 0.0, 1.0)
        return (point: self.point(at: t), t: t)
    }
}

extension LineSegment: Transformable {
    public func copy(using t: CGAffineTransform) -> LineSegment {
        return LineSegment(p0: self.p0.applying(t), p1: self.p1.applying(t))
    }
}

extension LineSegment: Reversible {
    public func reversed() -> LineSegment {
        return LineSegment(p0: self.p1, p1: self.p0)
    }
}

extension LineSegment: Flatness {
    public var flatnessSquared: CGFloat { return 0.0 }
    public var flatness: CGFloat { return 0.0 }
}
