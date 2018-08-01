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
    
    public lazy var cgPath: CGPath = {
        let mutablePath = CGMutablePath()
        guard curves.count > 0 else {
            return mutablePath.copy()!
        }
        mutablePath.move(to: curves[0].startingPoint)
        for curve in self.curves {
            switch curve {
                case let line as LineSegment:
                    mutablePath.addLine(to: line.endingPoint)
                case let quadCurve as QuadraticBezierCurve:
                    mutablePath.addQuadCurve(to: quadCurve.p2, control: quadCurve.p1)
                case let cubicCurve as CubicBezierCurve:
                    mutablePath.addCurve(to: cubicCurve.p3, control1: cubicCurve.p1, control2: cubicCurve.p2)
                default:
                    fatalError("CGPath does not support curve type (\(type(of: curve))")
            }
        }
        mutablePath.closeSubpath()
        return mutablePath.copy()!
    }()
    
    internal init(curves: [BezierCurve]) {
        self.curves = curves
    }
    
    public var perimeter: CGFloat {
        return self.curves.reduce(0.0) {
            $0 + $1.length()
        }
    }
    
    public var boundingBox: BoundingBox {
        return self.curves.reduce(BoundingBox.empty) {
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
