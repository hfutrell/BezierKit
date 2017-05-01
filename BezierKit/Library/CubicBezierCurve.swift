//
//  CubicBezierCurve.swift
//  BezierKit
//
//  Created by Holmes Futrell on 10/28/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import Foundation

public struct CubicBezierCurve: BezierCurve {
 
    let p0, p1, p2, p3: BKPoint
    
    public var points: [BKPoint] {
        return [p0, p1, p2, p3]
    }
    
    public var order: Int {
        return 3
    }
    
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

    public init(fromPointsWithS S: BKPoint, B: BKPoint, E: BKPoint, t: BKFloat = 0.5, d1 tempD1: BKFloat? = nil) {
                
        let abc = Utils.getABC(n: 3, S: S, B: B, E: E, t: t)
        
        let d1 = (tempD1 != nil) ? tempD1! : Utils.dist(B,abc.C)
        let d2 = d1 * (1-t) / t
        
        let selen = Utils.dist(S,E)
        let lx = (E.x-S.x) / selen
        let ly = (E.y-S.y) / selen
        let bx1 = d1 * lx
        let by1 = d1 * ly
        let bx2 = d2 * lx
        let by2 = d2 * ly
        
        // derivation of new hull coordinates
        let e1  = BKPoint( x: B.x - bx1, y: B.y - by1 )
        let e2  = BKPoint( x: B.x + bx2, y: B.y + by2 )
        let A   = abc.A
        let v1  = BKPoint( x: A.x + (e1.x-A.x)/(1-t), y: A.y + (e1.y-A.y)/(1-t) )
        let v2  = BKPoint( x: A.x + (e2.x-A.x)/(t), y: A.y + (e2.y-A.y)/(t) )
        let nc1 = BKPoint( x: S.x + (v1.x-S.x)/(t), y: S.y + (v1.y-S.y)/(t) )
        let nc2 = BKPoint( x: E.x + (v2.x-E.x)/(1-t), y: E.y + (v2.y-E.y)/(1-t) )
        // ...done
        self.init(p0:S, p1: nc1, p2: nc2, p3: E)
        
    }
    
    public var simple: Bool {
        let a1 = Utils.angle(o: self.p0, v1: self.p3, v2: self.p1)
        let a2 = Utils.angle(o: self.p0, v1: self.p3, v2: self.p2)
        if a1>0 && a2<0 || a1<0 && a2>0 {
            return false
        }
        let n1 = self.normal(0)
        let n2 = self.normal(1)
        let s = n1.dot(n2)
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
        return a*p0 + b*p1 + c*p2
    }

    
}
