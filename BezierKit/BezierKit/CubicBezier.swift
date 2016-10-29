//
//  CubicBezier.swift
//  BezierKit
//
//  Created by Holmes Futrell on 10/28/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import AppKit

typealias BKPoint = CGPoint
typealias BKFloat = CGFloat
typealias BKRect = CGRect

class CubicBezier {
    
    init(p0: BKPoint, p1: BKPoint, p2: BKPoint, p3: BKPoint) {
        
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
