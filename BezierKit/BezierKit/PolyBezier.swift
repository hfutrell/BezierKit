//
//  PolyBezier.swift
//  BezierKit
//
//  Created by Holmes Futrell on 11/23/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import Foundation

class PolyBezier {
    let curves: [CubicBezier]
    
    init(curves: [CubicBezier]) {
        self.curves = curves
    }
    
//    var length: BKFloat {
//        return 0.0
//    }
//    var boundingBox: BKBoundingBox {
//        
//    }
    func offset(distance d: BKFloat) -> PolyBezier {
        return PolyBezier(curves: self.curves.reduce([],{
            $0 + $1.offset(distance: d)
        }))
        
//        let curves: [CubicBezier] = []
//        for curve in self.curves {
//            curves.append(
//        }
        
    }
}
