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
    
    var length: BKFloat {
        return self.curves.reduce(0.0) {(result: BKFloat, curve: BezierCurve) -> BKFloat in
            result + curve.length()
        }
    }
    
    var boundingBox: BoundingBox {
        return self.curves.reduce(BoundingBox()) {(result: BoundingBox, curve: BezierCurve) -> BoundingBox in
            BoundingBox(first: result, second: curve.boundingBox)
        }
    }
    
    public func offset(distance d: BKFloat) -> PolyBezier {
        return PolyBezier(curves: self.curves.reduce([],{
            $0 + $1.offset(distance: d)
        }))
    }
}
