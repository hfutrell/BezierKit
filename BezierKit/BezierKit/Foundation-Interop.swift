//
//  Interop.swift
//  BezierKit
//
//  Created by Holmes Futrell on 3/17/17.
//  Copyright © 2017 Holmes Futrell. All rights reserved.
//

import Foundation

// MARK: allows Point2 to be converted back and forth to CGPoint

extension CGFloat: CGFloatable {
    public static func convertFrom(_ x: CGFloat) -> CGFloat {
        return CGFloat(x)
    }
    func convertTo() -> CGFloat {
        return self
    }
}

protocol CGFloatable {
    static func convertFrom(_ x: CGFloat) -> Self
    func convertTo() -> CGFloat
}

// in Swift 3.1 I believe this can be claned up to S == CGFloat (and CGFloatable protocol can be removed)
extension Point2 where S: CGFloatable {
    init(_ p: CGPoint)  {
        self.x = S.convertFrom(p.x)
        self.y = S.convertFrom(p.y)
    }
    func toCGPoint() -> CGPoint {
        return CGPoint(x: x.convertTo(), y: self.y.convertTo())
    }
}

// MARK: allows Point2<CGFloat> and Point2<CGFloat> to be created

extension CGFloat: Scalar {
    public static func sqrt(_ x: CGFloat) -> CGFloat {
        return Foundation.sqrt(x)
    }
}
