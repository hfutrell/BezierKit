//
//  CubicBezier.swift
//  BezierKit
//
//  Created by Holmes Futrell on 10/28/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import AppKit

class CubicBezier {
    
    let p0, p1, p2, p3: BKPoint
    
    var points: [BKPoint] {
        get {
            return [p0, p1, p2, p3]
        }
    }
    
    init(p0: BKPoint, p1: BKPoint, p2: BKPoint, p3: BKPoint) {
        self.p0 = p0
        self.p1 = p1
        self.p2 = p2
        self.p3 = p3
    }
 
    private static func getABC(n: Int, S: BKPoint, B: BKPoint, E: BKPoint, t: BKFloat = 0.5) -> (A: BKPoint, B: BKPoint, C: BKPoint) {
        let u = Utils.projectionRatio(n: n, t: t)
        let um = 1-u
        let C = BKPoint(
            x: u*S.x + um*E.x,
            y: u*S.y + um*E.y
        )
        let s = Utils.abcRatio(n: n, t: t)
        let A = BKPoint(
            x: B.x + (B.x-C.x)/s,
            y: B.y + (B.y-C.y)/s
        )
        return ( A:A, B:B, C:C );
    }

    convenience init(fromPointsWithS S: BKPoint, B: BKPoint, E: BKPoint, t: BKFloat = 0.5, d1 tempD1: BKFloat? = nil) {
        
        let abc = CubicBezier.getABC(n: 3, S: S, B: B, E: E, t: t);

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
        self.init(p0:S, p1: nc1, p2: nc2, p3: E);
        
    }
    
    /*
        Calculates the length of this Bezier curve. Length is calculated using numerical approximation, specifically the Legendre-Gauss quadrature algorithm.
     */
    func length() -> BKFloat {
        return 0.0
    }
    
    func eval(t: BKFloat) -> BKFloat {
    /*
        Calculates the point on the curve for a given t value between 0 and 1 (inclusive)
     */
        return 0.0
    }
    
//    func derivative(t: BKFloat) -> BKPoint {
//    /*
//        Calculates the curve tangent at the specified t value. Note that this yields a not-normalized vector {x: dx, y: dy}.
//     */
//        return BKPoint(x: 0.0, y: 0.0)
//    }
    
//    func normal(t: BKFloat) -> BKPoint {
//        
//    }
//    
//    func split(t: BKFloat) -> (b1: CubicBezier, b2: CubicBezier) {
//        
//    }
//    
//    func horizontalExtrema() -> BKPoint {
//        
//    }
//    
//    func verticalExtrema() -> BKPoint {
//        
//    }
//    
//    func boundingRect() -> BKRect {
//        
//    }
//    
//    func project(p: BKPoint) -> (t: BKFloat, p: BKPoint) {
//        
//    }
    
}
