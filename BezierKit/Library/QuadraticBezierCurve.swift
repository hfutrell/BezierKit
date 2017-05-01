//
//  QuadraticBezierCurve.swift
//  BezierKit
//
//  Created by Holmes Futrell on 3/3/17.
//  Copyright © 2017 Holmes Futrell. All rights reserved.
//

import Foundation

public struct QuadraticBezierCurve: BezierCurve {
    
    let p0, p1, p2: BKPoint
    
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
    
    public init(p0: BKPoint, p1: BKPoint, p2: BKPoint, t: BKFloat = 0.5) {
        // shortcuts, although they're really dumb
        if t == 0 {
            self.init(p0: p1, p1: p1, p2: p2)
        }
        else if t == 1 {
            self.init(p0: p0, p1: p1, p2: p1)
        }
        else {
            // real fitting.
            let abc = Utils.getABC(n:2, S: p0, B: p1, E: p2, t: t)
            self.init(p0: p0, p1: abc.A, p2: p2)
        }
    }

    public var points: [BKPoint] {
        return [p0, p1, p2]
    }
    
    public var order: Int {
        return 2
    }
    
    public var simple: Bool {
        let n1 = self.normal(0)
        let n2 = self.normal(1)
        let s = n1.dot(n2)
        let angle: BKFloat = BKFloat(abs(acos(Double(s))))
        return angle < (BKFloat.pi / 3.0)
    }
    
    public func derivative(_ t: BKFloat) -> BKPoint {
        let mt: BKFloat = 1-t
        let k: BKFloat = 2
        let p0 = k * (self.p1 - self.p0)
        let p1 = k * (self.p2 - self.p1)
        let a = mt*mt
        let b = mt*t*2
        return a*p0 + b*p1
    }

    // MARK: quadratic specific methods
    
//    public raise() -> CubicBezierCurve {
//    
//    }

}
