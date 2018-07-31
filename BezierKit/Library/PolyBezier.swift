//
//  PolyBezier.swift
//  BezierKit
//
//  Created by Holmes Futrell on 11/23/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import CoreGraphics

public class PolyBezier {
    
    public let curves: [BezierCurve]
    
    internal init(curves: [BezierCurve]) {
        self.curves = curves
    }
    
    public var length: CGFloat {
        return self.curves.reduce(0.0) {
            $0 + $1.length()
        }
    }
    
    public var boundingBox: BoundingBox {
        return self.curves.reduce(BoundingBox.empty()) {
            BoundingBox(first: $0, second: $1.boundingBox)
        }
    }
    
    public func offset(distance d: CGFloat) -> PolyBezier {
        return PolyBezier(curves: self.curves.reduce([], {
            $0 + $1.offset(distance: d)
        }))
    }
    
    // TODO: equatable
}
