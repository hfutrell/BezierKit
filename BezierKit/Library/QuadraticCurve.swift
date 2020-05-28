//
//  QuadraticCurve.swift
//  BezierKit
//
//  Created by Holmes Futrell on 3/3/17.
//  Copyright © 2017 Holmes Futrell. All rights reserved.
//

import CoreGraphics

public struct QuadraticCurve: NonlinearBezierCurve, Equatable {

    public var p0, p1, p2: CGPoint

    public init(points: [CGPoint]) {
        precondition(points.count == 3)
        self.p0 = points[0]
        self.p1 = points[1]
        self.p2 = points[2]
    }

    public init(p0: CGPoint, p1: CGPoint, p2: CGPoint) {
        self.p0 = p0
        self.p1 = p1
        self.p2 = p2
    }

    public init(lineSegment l: LineSegment) {
        self.init(p0: l.p0, p1: 0.5 * (l.p0 + l.p1), p2: l.p1)
    }

    public init(start: CGPoint, end: CGPoint, mid: CGPoint, t: CGFloat = 0.5) {
        // shortcuts, although they're really dumb
        if t == 0 {
            self.init(p0: mid, p1: mid, p2: end)
        } else if t == 1 {
            self.init(p0: start, p1: mid, p2: mid)
        } else {
            // real fitting.
            let abc = Utils.getABC(n: 2, S: start, B: mid, E: end, t: t)
            self.init(p0: start, p1: abc.A, p2: end)
        }
    }

    public var points: [CGPoint] {
        return [p0, p1, p2]
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
            return p2
        }
        set(newValue) {
            p2 = newValue
        }
    }

    public var order: Int {
        return 2
    }

    public var simple: Bool {
        guard p0 != p1 || p1 != p2 else { return true }
        let n1 = self.normal(at: 0)
        let n2 = self.normal(at: 1)
        let s = Utils.clamp(n1.dot(n2), -1.0, 1.0)
        let angle: CGFloat = CGFloat(abs(acos(Double(s))))
        return angle < (CGFloat.pi / 3.0)
    }

    public func normal(at t: CGFloat) -> CGPoint {
        var d = self.derivative(at: t)
        if d == CGPoint.zero, t == 0.0 || t == 1.0 {
            if t == 0.0 {
                d = p2 - p1
            } else {
                d = p1 - p0
            }
        }
        return d.perpendicular.normalize()
    }

    public func derivative(at t: CGFloat) -> CGPoint {
        let mt: CGFloat = 1-t
        let k: CGFloat = 2
        let p0 = k * (self.p1 - self.p0)
        let p1 = k * (self.p2 - self.p1)
        let a = mt
        let b = t
        return a*p0 + b*p1
    }

    public func split(from t1: CGFloat, to t2: CGFloat) -> QuadraticCurve {
        guard t1 != 0.0 || t2 != 1.0 else { return self }
        // compute the coordinates of a new curve where t' = t1 + (t2 - t1) * t
        // the coefficients q_xy represent the entry at the xth row and yth column of the matrix Q
        // see 'Deriving new hull coordinates' https://pomax.github.io/bezierinfo/#matrixsplit
        let t1 = Double(t1)
        let t2 = Double(t2)
        let q10 = CGFloat(1 - t1 - t2 + t1*t2)
        let q11 = CGFloat(t1 + t2 - 2*t1*t2)
        let q12 = CGFloat(t1*t2)
        let p1 = q10 * self.p0 + q11 * self.p1 + q12 * self.p2
        return QuadraticCurve(p0: self.point(at: CGFloat(t1)), p1: p1, p2: self.point(at: CGFloat(t2)))
    }

    public func split(at t: CGFloat) -> (left: QuadraticCurve, right: QuadraticCurve) {
        // use "de Casteljau" iteration.
        let h0 = self.p0
        let h1 = self.p1
        let h2 = self.p2
        let h3 = Utils.lerp(t, h0, h1)
        let h4 = Utils.lerp(t, h1, h2)
        let h5 = Utils.lerp(t, h3, h4)

        let leftCurve = QuadraticCurve(p0: h0, p1: h3, p2: h5)
        let rightCurve = QuadraticCurve(p0: h5, p1: h4, p2: h2)

        return (left: leftCurve, right: rightCurve)
    }

    public func project(_ point: CGPoint) -> (point: CGPoint, t: CGFloat) {
        func multiplyCoordinates(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            return CGPoint(x: a.x * b.x, y: a.y * b.y)
        }
        let q = self.copy(using: CGAffineTransform(translationX: -point.x, y: -point.y))
        // p0, p1, p2, p3 form the control points of a cubic Bezier curve
        // created by multiplying the curve with its derivative
        let qd0 = q.p1 - q.p0
        let qd1 = q.p2 - q.p1
        let p0 = 3 * multiplyCoordinates(q.p0, qd0)
        let p1 = multiplyCoordinates(q.p0, qd1) + 2 * multiplyCoordinates(q.p1, qd0)
        let p2 = multiplyCoordinates(q.p2, qd0) + 2 * multiplyCoordinates(q.p1, qd1)
        let p3 = 3 * multiplyCoordinates(q.p2, qd1)
        let lengthSquaredStart  = q.startingPoint.lengthSquared
        let lengthSquaredEnd    = q.endingPoint.lengthSquared
        var minimumT: CGFloat = 0.0
        var minimumDistanceSquared = lengthSquaredStart
        if lengthSquaredEnd < lengthSquaredStart {
            minimumT = 1.0
            minimumDistanceSquared = lengthSquaredEnd
        }
        // the roots represent the values at which the curve and its derivative are perpendicular
        // ie, the dot product of q and l is equal to zero
        Utils.droots(p0.x + p0.y, p1.x + p1.y, p2.x + p2.y, p3.x + p3.y) { (t: CGFloat) in
            guard t > 0.0, t < 1.0 else { return }
            let point = q.point(at: t)
            let distanceSquared = point.lengthSquared
            if distanceSquared < minimumDistanceSquared {
                minimumDistanceSquared = distanceSquared
                minimumT = t
            }
        }
        return (point: self.point(at: minimumT), t: minimumT)
    }

    public var boundingBox: BoundingBox {

        let p0: CGPoint = self.p0
        let p1: CGPoint = self.p1
        let p2: CGPoint = self.p2

        var mmin: CGPoint = CGPoint.min(p0, p2)
        var mmax: CGPoint = CGPoint.max(p0, p2)

        let d0: CGPoint = p1 - p0
        let d1: CGPoint = p2 - p1

        for d in 0..<CGPoint.dimensions {
            Utils.droots(d0[d], d1[d]) {(t: CGFloat) in
                guard t > 0.0, t < 1.0 else {
                    return
                }
                let value = self.point(at: t)[d]
                if value < mmin[d] {
                    mmin[d] = value
                } else if value > mmax[d] {
                    mmax[d] = value
                }
            }
        }
        return BoundingBox(min: mmin, max: mmax)
    }

    public func point(at t: CGFloat) -> CGPoint {
        if t == 0 {
            return self.p0
        } else if t == 1 {
            return self.p2
        }
        let mt = 1.0 - t
        let mt2: CGFloat    = mt*mt
        let t2: CGFloat     = t*t
        let a = mt2
        let b = mt * t*2
        let c = t2
        // making the final sum one line of code makes XCode take forever to compiler! Hence the temporary variables.
        let temp1 = a * self.p0
        let temp2 = b * self.p1
        let temp3 = c * self.p2
        return temp1 + temp2 + temp3
    }
}

extension QuadraticCurve: Transformable {
    public func copy(using t: CGAffineTransform) -> QuadraticCurve {
        return QuadraticCurve(p0: self.p0.applying(t), p1: self.p1.applying(t), p2: self.p2.applying(t))
    }
}

extension QuadraticCurve: Reversible {
    public func reversed() -> QuadraticCurve {
        return QuadraticCurve(p0: self.p2, p1: self.p1, p2: self.p0)
    }
}

extension QuadraticCurve: Flatness {
    public var flatnessSquared: CGFloat {
        let a: CGPoint = 2.0 * self.p1 - self.p0 - self.p2
        return (1.0 / 16.0) * (a.x * a.x + a.y * a.y)
    }
}
