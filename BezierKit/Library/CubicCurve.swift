//
//  CubicCurve.swift
//  BezierKit
//
//  Created by Holmes Futrell on 10/28/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

#if canImport(CoreGraphics)
import CoreGraphics
#else
@preconcurrency import Foundation
#endif

/**
 Cubic Bézier Curve
 */
public struct CubicCurve: NonlinearBezierCurve, Equatable, Sendable {

    public var p0, p1, p2, p3: CGPoint

    public var points: [CGPoint] {
        return [p0, p1, p2, p3]
    }

    public var order: Int {
        return 3
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
            return p3
        }
        set(newValue) {
            p3 = newValue
        }
    }

    // MARK: - Initializers

    public init(points: [CGPoint]) {
        precondition(points.count == 4)
        self.p0 = points[0]
        self.p1 = points[1]
        self.p2 = points[2]
        self.p3 = points[3]
    }

    public init(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint) {
        self.p0 = p0
        self.p1 = p1
        self.p2 = p2
        self.p3 = p3
    }

    public init(lineSegment: LineSegment) {
        let oneThird: CGFloat = 1.0 / 3.0
        let twoThirds: CGFloat = 2.0 / 3.0
        self.init(p0: lineSegment.p0,
                  p1: twoThirds * lineSegment.p0 + oneThird * lineSegment.p1,
                  p2: oneThird * lineSegment.p0 + twoThirds * lineSegment.p1,
                  p3: lineSegment.p1)
    }

    public init(quadratic: QuadraticCurve) {
        let oneThird: CGFloat = 1.0 / 3.0
        let twoThirds: CGFloat = 2.0 / 3.0
        self.init(p0: quadratic.p0,
                  p1: twoThirds * quadratic.p1 + oneThird * quadratic.p0,
                  p2: oneThird * quadratic.p2 + twoThirds * quadratic.p1,
                  p3: quadratic.p2)
    }

    var downgradedToQuadratic: (quadratic: QuadraticCurve, error: CGFloat) {
        let line = LineSegment(p0: self.startingPoint, p1: self.endingPoint)
        let d1 = self.p1 - line.point(at: 1.0 / 3.0)
        let d2 = self.p2 - line.point(at: 2.0 / 3.0)
        let d = 0.5 * d1 + 0.5 * d2
        let p1 = 1.5 * d + line.point(at: 0.5)
        let error = 0.144334 * (d1 - d2).length
        let quadratic = QuadraticCurve(p0: line.startingPoint,
                                       p1: p1,
                                       p2: line.endingPoint)
        return (quadratic: quadratic, error: error)
    }

    var downgradedToLineSegment: (lineSegment: LineSegment, error: CGFloat) {
        let line = LineSegment(p0: self.startingPoint, p1: self.endingPoint)
        let d1 = self.p1 - line.point(at: 1.0 / 3.0)
        let d2 = self.p2 - line.point(at: 2.0 / 3.0)
        let dmaxx = max(d1.x * d1.x, d2.x * d2.x)
        let dmaxy = max(d1.y * d1.y, d2.y * d2.y)
        let error = 3 / 4 * sqrt(dmaxx + dmaxy)
        return (lineSegment: line, error: error)
    }

/**
     Returns a CubicCurve which passes through three provided points: a starting point `start`, and ending point `end`, and an intermediate point `mid` at an optional t-value `t`.
     
- parameter start: the starting point of the curve
- parameter end: the ending point of the curve
- parameter mid: an intermediate point falling on the curve
- parameter t: optional t-value at which the curve will pass through the point `mid` (default = 0.5)
- parameter d: optional strut length with the full strut being length d * (1-t)/t. If omitted or `nil` the distance from `mid` to the baseline (line from `start` to `end`) is used.
*/
    public init(start: CGPoint, end: CGPoint, mid: CGPoint, t: CGFloat = 0.5, d: CGFloat? = nil) {

        let s = start
        let b = mid
        let e = end
        let oneMinusT = 1.0 - t

        let abc = Utils.getABC(n: 3, S: s, B: b, E: e, t: t)

        let d1 = d ?? distance(b, abc.C)
        let d2 = d1 * oneMinusT / t

        let selen = distance(start, end)
        let l = (1.0 / selen) * (e - s)
        let b1 = d1 * l
        let b2 = d2 * l

        // derivation of new hull coordinates
        let e1  = b - b1
        let e2  = b + b2
        let A   = abc.A
        let v1  = A + (e1 - A) / oneMinusT
        let v2  = A + (e2 - A) / t
        let nc1 = s + (v1 - s) / t
        let nc2 = e + (v2 - e) / oneMinusT
        // ...done
        self.init(p0: s, p1: nc1, p2: nc2, p3: e)
    }

    // MARK: -

    public var simple: Bool {
        guard p0 != p1 || p1 != p2 || p2 != p3 else { return true }
        let a1 = Utils.angle(o: self.p0, v1: self.p3, v2: self.p1)
        let a2 = Utils.angle(o: self.p0, v1: self.p3, v2: self.p2)
        if a1>0 && a2<0 || a1<0 && a2>0 {
            return false
        }
        let n1 = self.normal(at: 0)
        let n2 = self.normal(at: 1)
        let s = Utils.clamp(n1.dot(n2), -1.0, 1.0)
        let angle: CGFloat = CGFloat(Swift.abs(acos(Double(s))))
        return angle < (CGFloat.pi / 3.0)
    }

    public func normal(at t: CGFloat) -> CGPoint {
        var d = self.derivative(at: t)
        if d == CGPoint.zero, t == 0.0 || t == 1.0 {
            if t == 0.0 {
                d = p2 - p0
            } else {
                d = p3 - p1
            }
            if d == CGPoint.zero {
                d = p3 - p0
            }
        }
        return d.perpendicular.normalize()
    }

    public func derivative(at t: CGFloat) -> CGPoint {
        let mt: CGFloat = 1-t
        let k: CGFloat = 3
        let p0 = k * (self.p1 - self.p0)
        let p1 = k * (self.p2 - self.p1)
        let p2 = k * (self.p3 - self.p2)
        let a = mt*mt
        let b = mt*t*2
        let c = t*t
        // making the final sum one line of code makes XCode take forever to compiler! Hence the temporary variables.
        let temp1 = a*p0
        let temp2 = b*p1
        let temp3 = c*p2
        return temp1 + temp2 + temp3
    }

    public func split(from t1: CGFloat, to t2: CGFloat) -> CubicCurve {
        guard t1 != 0.0 || t2 != 1.0 else { return self }
        let k = (t2 - t1) / 3.0
        let p0 = self.point(at: t1)
        let p3 = self.point(at: t2)
        let p1 = p0 + k * self.derivative(at: t1)
        let p2 = p3 - k * self.derivative(at: t2)
        return CubicCurve(p0: p0, p1: p1, p2: p2, p3: p3)
    }

    public func split(at t: CGFloat) -> (left: CubicCurve, right: CubicCurve) {

        let h0 = self.p0
        let h1 = self.p1
        let h2 = self.p2
        let h3 = self.p3
        let h4 = Utils.linearInterpolate(h0, h1, t)
        let h5 = Utils.linearInterpolate(h1, h2, t)
        let h6 = Utils.linearInterpolate(h2, h3, t)
        let h7 = Utils.linearInterpolate(h4, h5, t)
        let h8 = Utils.linearInterpolate(h5, h6, t)
        let h9 = Utils.linearInterpolate(h7, h8, t)

        let leftCurve  = CubicCurve(p0: h0, p1: h4, p2: h7, p3: h9)
        let rightCurve = CubicCurve(p0: h9, p1: h8, p2: h6, p3: h3)

        return (left: leftCurve, right: rightCurve)

    }

    public func project(_ point: CGPoint) -> (point: CGPoint, t: CGFloat) {
        func mul(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            return CGPoint(x: a.x * b.x, y: a.y * b.y)
        }
        let c = self.copy(using: CGAffineTransform(translationX: -point.x, y: -point.y))
        let q = QuadraticCurve(p0: self.p1 - self.p0, p1: self.p2 - self.p1, p2: self.p3 - self.p2)
        // p0, p1, p2, p3 form the control points of a Cubic Bezier Curve formed
        // by multiplying the polynomials q and l
        let p0 = 10 * mul(c.p0, q.p0)
        let p1 = p0 + 4 * mul(c.p0, q.p1 - q.p0) + 6 * mul(c.p1 - c.p0, q.p0)
        let dd0 = 3 * mul(c.p2 - 2 * c.p1 + c.p0, q.p0) + 6 * mul(c.p1 - c.p0, q.p1 - q.p0) + mul(c.p0, q.p2 - 2 * q.p1 + q.p0)
        let p2 = 2 * p1 - p0 + dd0
        //
        let p5 = 10 * mul(c.p3, q.p2)
        let p4 = p5 - 4 * mul(c.p3, q.p2 - q.p1) - 6 * mul(c.p3 - c.p2, q.p2)
        let dd1 = 3 * mul(c.p1 - 2 * c.p2 + c.p3, q.p2) + 6 * mul(c.p3 - c.p2, q.p2 - q.p1) + mul(c.p3, q.p2 - 2 * q.p1 + q.p0)
        let p3 = 2 * p4 - p5 + dd1

        let lengthSquaredStart  = c.p0.lengthSquared
        let lengthSquaredEnd    = c.p3.lengthSquared
        var minimumT: CGFloat = 0.0
        var minimumDistanceSquared = lengthSquaredStart
        if lengthSquaredEnd < lengthSquaredStart {
            minimumT = 1.0
            minimumDistanceSquared = lengthSquaredEnd
        }
        // the roots represent the values at which the curve and its derivative are perpendicular
        // ie, the dot product of c and q is equal to zero
        let polynomial = BernsteinPolynomial5(b0: p0.x + p0.y,
                                              b1: p1.x + p1.y,
                                              b2: p2.x + p2.y,
                                              b3: p3.x + p3.y,
                                              b4: p4.x + p4.y,
                                              b5: p5.x + p5.y)
        for t in findDistinctRootsInUnitInterval(of: polynomial) {
            guard t > 0.0, t < 1.0 else { break }
            let point = c.point(at: CGFloat(t))
            let distanceSquared = point.lengthSquared
            if distanceSquared < minimumDistanceSquared {
                minimumDistanceSquared = distanceSquared
                minimumT = CGFloat(t)
            }
        }
        return (point: self.point(at: minimumT), t: minimumT)
    }

    public var boundingBox: BoundingBox {

        let p0: CGPoint = self.p0
        let p1: CGPoint = self.p1
        let p2: CGPoint = self.p2
        let p3: CGPoint = self.p3

        var mmin = CGPoint.min(p0, p3)
        var mmax = CGPoint.max(p0, p3)

        let d0 = p1 - p0
        let d1 = p2 - p1
        let d2 = p3 - p2

        for d in 0..<CGPoint.dimensions {
            let mmind = mmin[d]
            let mmaxd = mmax[d]
            let value1 = p1[d]
            let value2 = p2[d]
            guard value1 < mmind || value1 > mmaxd || value2 < mmind || value2 > mmaxd else {
                continue
            }
            Utils.droots(d0[d], d1[d], d2[d]) {(t: CGFloat) in
                guard t > 0.0, t < 1.0 else { return }
                let value = self.point(at: t)[d]
                if value < mmind {
                    mmin[d] = value
                } else if value > mmaxd {
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
            return self.p3
        }
        let mt = 1.0 - t
        let mt2: CGFloat    = mt*mt
        let t2: CGFloat     = t*t
        let a = mt2 * mt
        let b = mt2 * t * 3.0
        let c = mt * t2 * 3.0
        let d = t * t2
        // usage of temp variables are because of Swift Compiler error 'Expression was too complex to be solved in reasonable time; consider breaking up the expression into distinct sub extpressions'
        let temp1 = a * self.p0
        let temp2 = b * self.p1
        let temp3 = c * self.p2
        let temp4 = d * self.p3
        return temp1 + temp2 + temp3 + temp4
    }
}

extension CubicCurve: Transformable {
    public func copy(using t: CGAffineTransform) -> CubicCurve {
        return CubicCurve(p0: self.p0.applying(t), p1: self.p1.applying(t), p2: self.p2.applying(t), p3: self.p3.applying(t))
    }
}

extension CubicCurve: Reversible {
    public func reversed() -> CubicCurve {
        return CubicCurve(p0: self.p3, p1: self.p2, p2: self.p1, p3: self.p0)
    }
}

extension CubicCurve: Flatness {
    public var flatnessSquared: CGFloat {
        let a: CGPoint = 3.0 * self.p1 - 2.0 * self.p0 - self.p3
        let b: CGPoint = 3.0 * self.p2 - self.p0 - 2.0 * self.p3
        let temp1 = max(a.x * a.x, b.x * b.x)
        let temp2 = max(a.y * a.y, b.y * b.y)
        return (1.0 / 16.0) * ( temp1 + temp2 )
    }
}
