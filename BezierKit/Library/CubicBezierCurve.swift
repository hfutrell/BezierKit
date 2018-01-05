//
//  CubicBezierCurve.swift
//  BezierKit
//
//  Created by Holmes Futrell on 10/28/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import Foundation

/**
 Cubic Bézier Curve
 */
public struct CubicBezierCurve: BezierCurve, Equatable, ArcApproximateable {
 
    public var p0, p1, p2, p3: BKPoint
    
    public var points: [BKPoint] {
        return [p0, p1, p2, p3]
    }
    
    public var order: Int {
        return 3
    }

    public var startingPoint: BKPoint {
        return p0
    }
    
    public var endingPoint: BKPoint {
        return p3
    }
    
    // MARK: - Initializers
    
    public init(points: [BKPoint]) {
        precondition(points.count == 4)
        self.p0 = points[0]
        self.p1 = points[1]
        self.p2 = points[2]
        self.p3 = points[3]
    }
    
    public init(p0: BKPoint, p1: BKPoint, p2: BKPoint, p3: BKPoint) {
        let points = [p0, p1, p2, p3]
        self.init(points: points)
    }
    
    public init(lineSegment l: LineSegment) {
        let oneThird: BKFloat = 1.0 / 3.0
        let twoThirds: BKFloat = 2.0 / 3.0
        self.init(p0: l.p0, p1: twoThirds * l.p0 + oneThird * l.p1, p2: oneThird * l.p0 + twoThirds * l.p1, p3: l.p1)
    }
    
    public init(quadratic q: QuadraticBezierCurve) {
        let oneThird: BKFloat = 1.0 / 3.0
        let twoThirds: BKFloat = 2.0 / 3.0
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
    public init(start: BKPoint, end: BKPoint, mid: BKPoint, t: BKFloat = 0.5, d: BKFloat? = nil) {
        
        let s = start
        let b = mid
        let e = end
        
        let abc = Utils.getABC(n: 3, S: s, B: b, E: e, t: t)
        
        let d1 = (d != nil) ? d! : Utils.dist(b, abc.C)
        let d2 = d1 * (1.0-t) / t
        
        let selen = Utils.dist(start, end)
        let lx = (e.x-s.x) / selen
        let ly = (e.y-s.y) / selen
        let bx1 = d1 * lx
        let by1 = d1 * ly
        let bx2 = d2 * lx
        let by2 = d2 * ly
        
        // derivation of new hull coordinates
        let e1  = BKPoint( x: b.x - bx1, y: b.y - by1 )
        let e2  = BKPoint( x: b.x + bx2, y: b.y + by2 )
        let A   = abc.A
        let oneMinusT = 1.0 - t
        let v1  = A + (e1-A) / oneMinusT
        let v2  = A + (e2-A) / t
        let nc1 = s + (v1-s) / t
        let nc2 = e + (v2-e) / oneMinusT
        // ...done
        self.init(p0:s, p1: nc1, p2: nc2, p3: e)
    }
    
    // MARK: -
    
    public var simple: Bool {
        let a1 = Utils.angle(o: self.p0, v1: self.p3, v2: self.p1)
        let a2 = Utils.angle(o: self.p0, v1: self.p3, v2: self.p2)
        if a1>0 && a2<0 || a1<0 && a2>0 {
            return false
        }
        let n1 = self.normal(0)
        let n2 = self.normal(1)
        let s = Utils.clamp(n1.dot(n2), -1.0, 1.0)
        let angle: BKFloat = BKFloat(abs(acos(Double(s))))
        return angle < (BKFloat.pi / 3.0)
    }
    
    public func derivative(_ t: BKFloat) -> BKPoint {
        let mt: BKFloat = 1-t
        let k: BKFloat = 3
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
    
    public func split(from t1: BKFloat, to t2: BKFloat) -> CubicBezierCurve {
        
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
        
        let tr = Utils.map(t2, t1, 1, 0, 1)
        
        let i0 = h9
        let i1 = h8
        let i2 = h6
        let i3 = h3
        let i4 = Utils.lerp(tr, i0, i1)
        let i5 = Utils.lerp(tr, i1, i2)
        let i6 = Utils.lerp(tr, i2, i3)
        let i7 = Utils.lerp(tr, i4, i5)
        let i8 = Utils.lerp(tr, i5, i6)
        let i9 = Utils.lerp(tr, i7, i8)
        
        return CubicBezierCurve(p0: i0, p1: i4, p2: i7, p3: i9)
        
    }

    public func split(at t: BKFloat) -> (left: CubicBezierCurve, right: CubicBezierCurve) {
        
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

        let p0: BKPoint = self.p0
        let p1: BKPoint = self.p1
        let p2: BKPoint = self.p2
        let p3: BKPoint = self.p3
        
        var mmin = BKPoint.min(p0, p3)
        var mmax = BKPoint.max(p0, p3)
        
        let d0 = p1 - p0
        let d1 = p2 - p1
        let d2 = p3 - p2

        for d in 0..<BKPoint.dimensions {
            Utils.droots(d0[d], d1[d], d2[d]) {(r: BKFloat) in
                if r <= 0.0 || r >= 1.0 {
                    return
                }
                let value = self.compute(r)[d]
                if value < mmin[d] {
                    mmin[d] = value
                }
                else if value > mmax[d] {
                    mmax[d] = value
                }
            }
        }
        return BoundingBox(min: mmin, max: mmax)
    }
    
    public func compute(_ t: BKFloat) -> BKPoint {
        if t == 0 {
            return self.p0
        }
        else if t == 1 {
            return self.p3
        }
        let mt = 1.0 - t
        let mt2: BKFloat    = mt*mt
        let t2: BKFloat     = t*t
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
    
    // MARK: - Equatable
    
    public static func == (left: CubicBezierCurve, right: CubicBezierCurve) -> Bool {
        return left.p0 == right.p0 && left.p1 == right.p1 && left.p2 == right.p2 && left.p3 == right.p3
    }
    
}
