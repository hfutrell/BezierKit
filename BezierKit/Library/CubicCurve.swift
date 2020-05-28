//
//  CubicCurve.swift
//  BezierKit
//
//  Created by Holmes Futrell on 10/28/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import CoreGraphics

/**
 Cubic Bézier Curve
 */
public struct CubicCurve: NonlinearBezierCurve, Equatable {

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
        let angle: CGFloat = CGFloat(abs(acos(Double(s))))
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
        // compute the coordinates of a new curve where t' = t1 + (t2 - t1) * t
        // see 'Deriving new hull coordinates' https://pomax.github.io/bezierinfo/#matrixsplit
        // the coefficients q_xy represent the entry at the xth row and yth column of the matrix Q
        // using a computer algebra system is helpful here
        // compute p1
        let t1 = Double(t1)
        let t2 = Double(t2)
        let q10 = CGFloat(1 - 2*t1 - t2 + t1*t1 + 2*t1*t2 - t1*t1*t2)
        let q11 = CGFloat(t2 + 2*t1 + 3*t1*t1*t2 - 2*t1*t1 - 4*t1*t2)
        let q12 = CGFloat(t1*t1 - 3*t1*t1*t2 + 2*t1*t2)
        let q13 = CGFloat(t1*t1*t2)
        let p1 = q10 * self.p0 + q11 * self.p1 + q12 * self.p2 + q13 * self.p3
        // compute p2 (notice that this just flips the role of t1 and t2 from the computation of p1)
        let q20 = CGFloat(1 - 2*t2 - t1 + t2*t2 + 2*t1*t2 - t1*t2*t2)
        let q21 = CGFloat(t1 + 2*t2 + 3*t1*t2*t2 - 2*t2*t2 - 4*t1*t2)
        let q22 = CGFloat(t2*t2 - 3*t1*t2*t2 + 2*t1*t2)
        let q23 = CGFloat(t1*t2*t2)
        let p2 = q20 * self.p0 + q21 * self.p1 + q22 * self.p2 + q23 * self.p3
        return CubicCurve(p0: self.point(at: CGFloat(t1)), p1: p1, p2: p2, p3: self.point(at: CGFloat(t2)))
    }

    public func split(at t: CGFloat) -> (left: CubicCurve, right: CubicCurve) {

        let h0 = self.p0
        let h1 = self.p1
        let h2 = self.p2
        let h3 = self.p3
        let h4 = Utils.lerp(t, h0, h1)
        let h5 = Utils.lerp(t, h1, h2)
        let h6 = Utils.lerp(t, h2, h3)
        let h7 = Utils.lerp(t, h4, h5)
        let h8 = Utils.lerp(t, h5, h6)
        let h9 = Utils.lerp(t, h7, h8)

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
        // ie, the dot product of q and l is equal to zero
        let points: [Double] = [p0.x + p0.y,
                                p1.x + p1.y,
                                p2.x + p2.y,
                                p3.x + p3.y,
                                p4.x + p4.y,
                                p5.x + p5.y].map { Double($0) }
        let scratchPad = UnsafeMutableBufferPointer<Double>.allocate(capacity: points.count)
        for t in findRoots(of: points, between: 0, and: 1, scratchPad: scratchPad) {
            guard t > 0.0, t < 1.0 else { break }
            let point = c.point(at: CGFloat(t))
            let distanceSquared = point.lengthSquared
            if distanceSquared < minimumDistanceSquared {
                minimumDistanceSquared = distanceSquared
                minimumT = CGFloat(t)
            }
        }
        scratchPad.deallocate()
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
