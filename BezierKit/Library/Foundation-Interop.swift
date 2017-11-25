//
//  Interop.swift
//  BezierKit
//
//  Created by Holmes Futrell on 3/17/17.
//  Copyright © 2017 Holmes Futrell. All rights reserved.
//

import Foundation

#if os(iOS)
    import CoreGraphics
#endif

// MARK: allows Point2 to be converted back and forth to CGPoint

public extension Point2 where S == CGFloat {
    init(_ p: CGPoint)  {
        self.x = p.x
        self.y = p.y
    }
    func toCGPoint() -> CGPoint {
        return CGPoint(x: self.x, y: self.y)
    }
}

// MARK: allows Point2<CGFloat> and Point3<CGFloat> to be created

extension CGFloat: RealNumber {
    public static func sqrt(_ x: CGFloat) -> CGFloat {
        #if os(macOS)
            return Foundation.sqrt(x)
        #elseif os(iOS)
            return CoreGraphics.sqrt(x)
        #endif
    }
}
