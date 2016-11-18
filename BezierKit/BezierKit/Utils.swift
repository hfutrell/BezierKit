//
//  Utils.swift
//  BezierKit
//
//  Created by Holmes Futrell on 11/3/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import Foundation

class Utils {
    
    static func abcRatio(n: Int, t: CGFloat = 0.5) -> BKFloat {
        // see ratio(t) note on http://pomax.github.io/bezierinfo/#abc
        assert(n == 2 || n == 3)
        if ( t == 0 || t == 1) {
            return t
        }
        let bottom = pow(t, CGFloat(n)) + pow(1 - t, CGFloat(n))
        let top = bottom - 1
        return abs(top/bottom);
    }
    
    static func projectionRatio(n: Int, t: CGFloat = 0.5) -> BKFloat {
        // see u(t) note on http://pomax.github.io/bezierinfo/#abc
        assert(n == 2 || n == 3)
        if (t == 0 || t == 1) {
            return t
        }
        let top = pow(1.0 - t, CGFloat(n))
        let bottom = pow(t, CGFloat(n)) + top
        return top/bottom;

    }
    
    static func map(_ v: BKFloat,_ ds: BKFloat,_ de: BKFloat,_ ts: BKFloat,_ te: BKFloat) -> BKFloat {
        let d1 = de-ds
        let d2 = te-ts
        let v2 =  v-ds
        let r = v2/d1
        return ts + d2*r
    }
    
    static func lli8(_ x1: BKFloat,_ y1: BKFloat,_ x2: BKFloat,_ y2: BKFloat,_ x3: BKFloat,_ y3: BKFloat,_ x4: BKFloat,_ y4: BKFloat) -> BKPoint? {
        let nx = (x1*y2-y1*x2)*(x3-x4)-(x1-x2)*(x3*y4-y3*x4)
        let ny = (x1*y2-y1*x2)*(y3-y4)-(y1-y2)*(x3*y4-y3*x4)
        let d = (x1-x2)*(y3-y4)-(y1-y2)*(x3-x4)
        if d==0 {
            return nil
        }
        return BKPoint( x: nx/d, y: ny/d );
    }
    
    static func lli4(_ p1: BKPoint,_ p2: BKPoint,_ p3: BKPoint,_ p4: BKPoint) -> BKPoint? {
        let x1 = p1.x; let y1 = p1.y
        let x2 = p2.x; let y2 = p2.y
        let x3 = p3.x; let y3 = p3.y
        let x4 = p4.x; let y4 = p4.y
        return Utils.lli8(x1,y1,x2,y2,x3,y3,x4,y4)
    }
    
//    static func lli(_ v1: BKFloat,_ v2: BKFloat) -> BKPoint? {
//        return Utils.lli4(v1,v1.c,v2,v2.c)
//    }

    
    static func lerp(_ r: BKFloat, _ v1: BKPoint, _ v2: BKPoint) -> BKPoint {
        return v1 + (v2 - v1) * r;
    }
    
    static func dist(_ p1: BKPoint,_ p2: BKPoint) -> BKFloat {
        return (p1 - p2).length
    }
    
    static func angle(o: BKPoint, v1: BKPoint, v2: BKPoint) -> BKFloat {
        var dx1 = v1.x - o.x
        var dy1 = v1.y - o.y
        var dx2 = v2.x - o.x
        var dy2 = v2.y - o.y
        let cross = dx1*dy2 - dy1*dx2
        let m1 = sqrt(dx1*dx1+dy1*dy1)
        let m2 = sqrt(dx2*dx2+dy2*dy2)
        dx1 /= m1
        dy1 /= m1
        dx2 /= m2
        dy2 /= m2
        let dot = dx1*dx2 + dy1*dy2;
        return atan2(cross, dot)
    }
    
}
