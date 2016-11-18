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
    let order: Int = 3
    private let threeD: Bool = false // todo: fix this
    private let linear: Bool = false // todo: fix this
    
    var points: [BKPoint] {
        get {
            return [p0, p1, p2, p3]
        }
    }
    
    init(points: [BKPoint]) {
        // todo: implement
        assert(false, "constructor not yet supported")
        self.p0 = BKPointZero
        self.p1 = BKPointZero
        self.p2 = BKPointZero
        self.p3 = BKPointZero
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
    
    func compute(_ t: BKFloat) -> BKPoint {
        // shortcuts
        if(t==0) {
            return self.points[0]
        }
        if(t==1) {
            return self.points[self.order]
        }
        
        var p = self.points
        let mt = 1-t;
        
        // linear?
        if self.order == 1 {
            var value = BKPoint(
                x: mt*p[0].x + t*p[1].x,
                y: mt*p[0].y + t*p[1].y
            )
            if self.threeD {
                value.z = mt*p[0].z + t*p[1].z
            }
            return value
        }
        
        // quadratic/cubic curve?
        if self.order < 4 {
            let mt2: BKFloat = mt*mt
            let t2: BKFloat = t*t
            var a: BKFloat = 0
            var b: BKFloat = 0
            var c: BKFloat = 0
            var d: BKFloat = 0
            if self.order == 2 {
                p = [p[0], p[1], p[2], BKPointZero]
                a = mt2
                b = mt * t*2
                c = t2
            }
            else if self.order == 3 {
                a = mt2 * mt
                b = mt2 * t * 3.0
                c = mt * t2 * 3.0
                d = t * t2
            }
            var ret = BKPoint(
                x: a*p[0].x + b*p[1].x + c*p[2].x + d*p[3].x,
                y: a*p[0].y + b*p[1].y + c*p[2].y + d*p[3].y
            )
            if self.threeD {
                ret.z = a*p[0].z + b*p[1].z + c*p[2].z + d*p[3].z;
            }
            return ret
        }
        
// todo: implement me
        // higher order curves: use de Casteljau's computation
//        var dCpts = JSON.parse(JSON.stringify(this.points));
//        while dCpts.length > 1 {
//            for (var i=0; i<dCpts.length-1; i++) {
//                dCpts[i] = {
//                    x: dCpts[i].x + (dCpts[i+1].x - dCpts[i].x) * t,
//                    y: dCpts[i].y + (dCpts[i+1].y - dCpts[i].y) * t
//                };
//                if (typeof dCpts[i].z !== "undefined") {
//                    dCpts[i] = dCpts[i].z + (dCpts[i+1].z - dCpts[i].z) * t
//                }
//            }
//            dCpts.splice(dCpts.length-1, 1);
//        }
//        return dCpts[0];
        assert(false)  // todo: higher order unsupported for now
        return BKPointZero
    }
    
    func generateLookupTable(withSteps steps: Int = 100) -> [BKPoint] {
        assert(steps >= 0)
        var table: [BKPoint] = []
        for i in 0 ... steps {
            let t = BKFloat(i) / BKFloat(steps)
            table.append(self.compute(t))
        }
        
        return table
    }
    
    func normal(_ t: BKFloat) -> BKPoint {
        return BKPointZero
    }
    
    /*
        Reduces a curve to a collection of "simple" subcurves, where a simpleness is defined as having all control points on the same side of the baseline (cubics having the additional constraint that the control-to-end-point lines may not cross), and an angle between the end point normals no greater than 60 degrees.
     
        The main reason this function exists is to make it possible to scale curves. As mentioned in the offset function, curves cannot be offset without cheating, and the cheating is implemented in this function. The array of simple curves that this function yields can safely be scaled.
     

    */
    func reduce() -> [CubicBezier] {
        return []
    }
    
    /*
        Scales a curve with respect to the intersection between the end point normals. Note that this will only work if that point exists, which is only guaranteed for simple segments.
     */
    func scale(distance d: BKFloat) -> CubicBezier {
        // todo: implement me
        return CubicBezier(points: [])
    }
    
    func offset(distance d: BKFloat) -> [CubicBezier] {
        if self.linear {
            let n = self.normal(0);
            let coords: [BKPoint] = self.points.map({(p: BKPoint) -> BKPoint in
                return p + n * d
            })
            return [CubicBezier(points: coords)]
        }
        // for non-linear curves we need to create a set of curves
        let reduced: [CubicBezier] = self.reduce()
        return reduced.map({(s: CubicBezier) -> CubicBezier in
            return s.scale(distance: d)
        })
    }
    
    func offset(t: BKFloat, distance d: BKFloat) -> BKPoint {
        let c = self.compute(t);
        let n = self.normal(t);
        return c + n * d
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
