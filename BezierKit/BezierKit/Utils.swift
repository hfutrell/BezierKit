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
