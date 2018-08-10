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
    
    private let bvh: BoundingVolumeHierarchy
    
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
        self.bvh = BoundingVolumeHierarchy(objects: curves)
    }
    
    public var length: CGFloat {
        return self.curves.reduce(0.0) {
            $0 + $1.length()
        }
    }
    
    public lazy var boundingBox: BoundingBox = {
        return self.curves.reduce(BoundingBox.empty) {
            BoundingBox(first: $0, second: $1.boundingBox)
        }
    }()
    
    public func offset(distance d: CGFloat) -> PolyBezier {
        return PolyBezier(curves: self.curves.reduce([], {
            $0 + $1.offset(distance: d)
        }))
    }
    
    internal func pointIsWithinDistanceOfBoundary(point p: CGPoint, distance d: CGFloat) -> Bool {
        if self.boundingBox.lowerBoundOfDistance(to: p) > d {
            return false
        }
        else if self.boundingBox.upperBoundOfDistance(to: p) <= d {
            return true
        }
        return self.curves.contains(where: {
            $0.boundingBox.lowerBoundOfDistance(to: p) <= d && distance(p, $0.project(point: p)) <= d
        })
    }
    
    public func intersects(_ other: PolyBezier, threshold: CGFloat = BezierKit.defaultIntersectionThreshold) -> [CGPoint] {
        var intersections: [CGPoint] = []
        self.bvh.intersects(boundingVolumeHierarchy: other.bvh) { o1, o2 in
            let c1 = o1 as! BezierCurve
            let c2 = o2 as! BezierCurve
            intersections += c1.intersects(curve: c2).map { c1.compute($0.t1) }
        }
        return intersections
    }
    
    // TODO: equatable
}
