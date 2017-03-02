//
//  PolyBezier.swift
//  BezierKit
//
//  Created by Holmes Futrell on 11/23/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import Foundation

public class PolyBezier {
    public let curves: [BezierCurve]
    
    public init(curves: [BezierCurve]) {
        self.curves = curves
    }
    
// TODO: flesh out the rest of this class
    
//    var length: BKFloat {
//        return 0.0
//    }
//    var boundingBox: BKBoundingBox {
//        
//    }
    public func offset(distance d: BKFloat) -> PolyBezier {
        return PolyBezier(curves: self.curves.reduce([],{
            $0 + $1.offset(distance: d)
        }))
    }
}
