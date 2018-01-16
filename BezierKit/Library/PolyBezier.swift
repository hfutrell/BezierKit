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
    
    public var length: BKFloat {
        return self.curves.reduce(BKFloat(0.0)) {
            $0 + $1.length()
        }
    }
    
    public var boundingBox: BoundingBox {
        return self.curves.reduce(BoundingBox()) {
            BoundingBox(first: $0, second: $1.boundingBox)
        }
    }
    
    public func offset(distance d: BKFloat) -> PolyBezier {
        return PolyBezier(curves: self.curves.reduce([], {
            $0 + $1.offset(distance: d)
        }))
    }
    
    // TODO: equatable
}
