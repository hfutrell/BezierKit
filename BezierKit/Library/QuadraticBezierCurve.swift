//
//  QuadraticBezierCurve.swift
//  BezierKit
//
//  Created by Holmes Futrell on 3/3/17.
//  Copyright © 2017 Holmes Futrell. All rights reserved.
//

import Foundation

public struct QuadraticBezierCurve: BezierCurve, Equatable, ArcApproximateable {
    
    public var p0, p1, p2: BKPoint
    
    public init(points: [BKPoint]) {
        precondition(points.count == 3)
        self.p0 = points[0]
        self.p1 = points[1]
        self.p2 = points[2]
    }
    
    public init(p0: BKPoint, p1: BKPoint, p2: BKPoint) {
        let points = [p0, p1, p2]
        self.init(points: points)
    }
    
    public init(start: BKPoint, end: BKPoint, mid: BKPoint, t: BKFloat = 0.5) {
        // shortcuts, although they're really dumb
        if t == 0 {
            self.init(p0: mid, p1: mid, p2: end)
        }
        else if t == 1 {
            self.init(p0: start, p1: mid, p2: mid)
        }
        else {
            // real fitting.
            let abc = Utils.getABC(n:2, S: start, B: mid, E: end, t: t)
            self.init(p0: start, p1: abc.A, p2: end)
        }
    }

    public var points: [BKPoint] {
        return [p0, p1, p2]
    }
    
    public var startingPoint: BKPoint {
        return p0
    }
    
    public var endingPoint: BKPoint {
        return p2
    }
    
    public var order: Int {
        return 2
    }
    
    public var simple: Bool {
        let n1 = self.normal(0)
        let n2 = self.normal(1)
        let s = Utils.clamp(n1.dot(n2), -1.0, 1.0)
        let angle: BKFloat = BKFloat(abs(acos(Double(s))))
        return angle < (BKFloat.pi / 3.0)
    }
    
    public func derivative(_ t: BKFloat) -> BKPoint {
        let mt: BKFloat = 1-t
        let k: BKFloat = 2
        let p0 = k * (self.p1 - self.p0)
        let p1 = k * (self.p2 - self.p1)
        let a = mt
        let b = t
        return a*p0 + b*p1
    }

    public func split(from t1: BKFloat, to t2: BKFloat) -> QuadraticBezierCurve {
    
        let h0 = self.p0
        let h1 = self.p1
        let h2 = self.p2
        let h3 = Utils.lerp(t1, h0, h1)
        let h4 = Utils.lerp(t1, h1, h2)
        let h5 = Utils.lerp(t1, h3, h4)
        
        let tr = Utils.map(t2, t1, 1, 0, 1)
        
        let i0 = h5
        let i1 = h4
        let i2 = h2
        let i3 = Utils.lerp(tr, i0, i1)
        let i4 = Utils.lerp(tr, i1, i2)
        let i5 = Utils.lerp(tr, i3, i4)
        
        return QuadraticBezierCurve(p0: i0, p1: i3, p2: i5)
    }

    public func split(at t: BKFloat) -> (left: QuadraticBezierCurve, right: QuadraticBezierCurve) {
        // use "de Casteljau" iteration.
        let h0 = self.p0
        let h1 = self.p1
        let h2 = self.p2
        let h3 = Utils.lerp(t, h0, h1)
        let h4 = Utils.lerp(t, h1, h2)
        let h5 = Utils.lerp(t, h3, h4)
        
        let leftCurve = QuadraticBezierCurve(p0: h0, p1: h3, p2: h5)
        let rightCurve = QuadraticBezierCurve(p0: h5, p1: h4, p2: h2)
    
        return (left: leftCurve, right: rightCurve)
    }

    public var boundingBox: BoundingBox {
        
        let p0: BKPoint = self.p0
        let p1: BKPoint = self.p1
        let p2: BKPoint = self.p2
        
        var mmin: BKPoint = BKPoint.min(p0, p2)
        var mmax: BKPoint = BKPoint.max(p0, p2)
        
        let d0: BKPoint = p1 - p0
        let d1: BKPoint = p2 - p1
        
        for d in 0..<BKPoint.dimensions {
            Utils.droots(d0[d], d1[d]) {(t: BKFloat) in
                if t <= 0.0 || t >= 1.0 {
                    return
                }

                // eval the curve
                // TODO: replacing this code with self.compute(t)[d] crashes in profile mode
                let mt = 1.0 - t
                let a = mt * mt
                let b = mt * t * 2.0
                let c = t * t
                let value = a * p0[d] + b * p1[d] + c * p2[d]
                
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
            return self.p2
        }
        let mt = 1.0 - t
        let mt2: BKFloat    = mt*mt
        let t2: BKFloat     = t*t
        let a = mt2
        let b = mt * t*2
        let c = t2
        // making the final sum one line of code makes XCode take forever to compiler! Hence the temporary variables.
        let temp1 = a * self.p0
        let temp2 = b * self.p1
        let temp3 = c * self.p2
        return temp1 + temp2 + temp3
    }
    
    // -- MARK: Equatable
    
    public static func == (left: QuadraticBezierCurve, right: QuadraticBezierCurve) -> Bool {
        return left.p0 == right.p0 && left.p1 == right.p1 && left.p2 == right.p2
    }

    // MARK: quadratic specific methods
    
//    public raise() -> CubicBezierCurve {
//    
//    }

}
