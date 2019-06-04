//
//  CubicBezierCurve.swift
//  BezierKit
//
//  Created by Holmes Futrell on 10/28/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import CoreGraphics

/**
 Cubic Bézier Curve
 */
public struct CubicBezierCurve: NonlinearBezierCurve, ArcApproximateable, Equatable {

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

    public init(lineSegment l: LineSegment) {
        let oneThird: CGFloat = 1.0 / 3.0
        let twoThirds: CGFloat = 2.0 / 3.0
        self.init(p0: l.p0, p1: twoThirds * l.p0 + oneThird * l.p1, p2: oneThird * l.p0 + twoThirds * l.p1, p3: l.p1)
    }

    public init(quadratic q: QuadraticBezierCurve) {
        let oneThird: CGFloat = 1.0 / 3.0
        let twoThirds: CGFloat = 2.0 / 3.0
        let p0 = q.p0
        let p1 = twoThirds * q.p1 + oneThird * q.p0
        let p2 = oneThird * q.p2 + twoThirds * q.p1
        let p3 = q.p2
        self.init(p0: p0, p1: p1, p2: p2, p3: p3)
    }
/**
     Returns a CubicBezierCurve which passes through three provided points: a starting point `start`, and ending point `end`, and an intermediate point `mid` at an optional t-value `t`.
     
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

        let d1 = d ?? Utils.dist(b, abc.C)
        let d2 = d1 * oneMinusT / t

        let selen = Utils.dist(start, end)
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
        let n1 = self.normal(0)
        let n2 = self.normal(1)
        let s = Utils.clamp(n1.dot(n2), -1.0, 1.0)
        let angle: CGFloat = CGFloat(abs(acos(Double(s))))
        return angle < (CGFloat.pi / 3.0)
    }

    public func normal(_ t: CGFloat) -> CGPoint {
        var d = self.derivative(t)
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

    public func derivative(_ t: CGFloat) -> CGPoint {
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

    public func split(from t1: CGFloat, to t2: CGFloat) -> CubicBezierCurve {
        guard t1 != 0.0 || t2 != 1.0 else { return self }
        let h0 = self.p0
        let h1 = self.p1
        let h2 = self.p2
        let h3 = self.p3
        let h4 = Utils.lerp(t1, h0, h1)
        let h5 = Utils.lerp(t1, h1, h2)
        let h6 = Utils.lerp(t1, h2, h3)
        let h7 = Utils.lerp(t1, h4, h5)
        let h8 = Utils.lerp(t1, h5, h6)
        let h9 = Utils.lerp(t1, h7, h8)
        let tr = (t2 - t1) / (1.0 - t1)
        let i4 = Utils.lerp(tr, h9, h8)
        let i5 = Utils.lerp(tr, h8, h6)
        let i7 = Utils.lerp(tr, i4, i5)
        return CubicBezierCurve(p0: self.compute(t1), p1: i4, p2: i7, p3: self.compute(t2))
    }

    public func split(at t: CGFloat) -> (left: CubicBezierCurve, right: CubicBezierCurve) {

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

        let leftCurve  = CubicBezierCurve(p0: h0, p1: h4, p2: h7, p3: h9)
        let rightCurve = CubicBezierCurve(p0: h9, p1: h8, p2: h6, p3: h3)

        return (left: leftCurve, right: rightCurve)

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
                let value = self.compute(t)[d]
                if value < mmind {
                    mmin[d] = value
                } else if value > mmaxd {
                    mmax[d] = value
                }
            }
        }
        return BoundingBox(min: mmin, max: mmax)
    }

    public func compute(_ t: CGFloat) -> CGPoint {
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

extension CubicBezierCurve: Transformable {
    public func copy(using t: CGAffineTransform) -> CubicBezierCurve {
        return CubicBezierCurve(p0: self.p0.applying(t), p1: self.p1.applying(t), p2: self.p2.applying(t), p3: self.p3.applying(t))
    }
}

extension CubicBezierCurve: Reversible {
    public func reversed() -> CubicBezierCurve {
        return CubicBezierCurve(p0: self.p3, p1: self.p2, p2: self.p1, p3: self.p0)
    }
}

extension CubicBezierCurve: Flatness {
    public var flatnessSquared: CGFloat {
        let a: CGPoint = 3.0 * self.p1 - 2.0 * self.p0 - self.p3
        let b: CGPoint = 3.0 * self.p2 - self.p0 - 2.0 * self.p3
        let temp1 = max(a.x * a.x, b.x * b.x)
        let temp2 = max(a.y * a.y, b.y * b.y)
        return (1.0 / 16.0) * ( temp1 + temp2 )
    }
}
