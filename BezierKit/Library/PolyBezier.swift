//
//  PolyBezier.swift
//  BezierKit
//
//  Created by Holmes Futrell on 11/23/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import CoreGraphics
import Foundation

public class PolyBezier: NSObject, NSCoding {
    
    public let curves: [BezierCurve]
    
    internal lazy var bvh: BoundingVolumeHierarchy = BoundingVolumeHierarchy(objects: curves)
    
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
    
    public var length: CGFloat {
        return self.curves.reduce(0.0) { $0 + $1.length() }
    }
    
    public var boundingBox: BoundingBox {
        return self.bvh.boundingBox
    }
    
    public func offset(distance d: CGFloat) -> PolyBezier {
        return PolyBezier(curves: self.curves.reduce([]) {
            $0 + $1.offset(distance: d)
        })
    }
    
    public func pointIsWithinDistanceOfBoundary(point p: CGPoint, distance d: CGFloat) -> Bool {
        var found = false
        self.bvh.visit { node, _ in
            let boundingBox = node.boundingBox
            if boundingBox.upperBoundOfDistance(to: p) <= d {
                found = true
            }
            else if case let .leaf(object) = node.nodeType {
                let curve = object as! BezierCurve
                if distance(p, curve.project(point: p)) < d {
                    found = true
                }
            }
            return !found && node.boundingBox.lowerBoundOfDistance(to: p) <= d
        }
        return found
    }
    
    public func intersects(_ other: PolyBezier, threshold: CGFloat = BezierKit.defaultIntersectionThreshold) -> [CGPoint] {
        var intersections: [CGPoint] = []
        self.bvh.intersects(boundingVolumeHierarchy: other.bvh) { o1, o2 in
            let c1 = o1 as! BezierCurve
            let c2 = o2 as! BezierCurve
            intersections += c1.intersects(curve: c2, threshold: threshold).map { c1.compute($0.t1) }
        }
        return intersections
    }
    
    // MARK: - NSCoding
    // (cannot be put in extension because init?(coder:) is a designated initializer)
    
    public func encode(with aCoder: NSCoder) {
        let values: [[NSValue]] = self.curves.map { (curve: BezierCurve) -> [NSValue] in
            return curve.points.map { return NSValue(cgPoint: $0) }
        }
        aCoder.encode(values)
    }
    required public init?(coder aDecoder: NSCoder) {
        guard let curveData = aDecoder.decodeObject() as? [[NSValue]] else { return nil }
        self.curves = curveData.map { values in
            createCurve(from: values.map { $0.cgPointValue })!
        }
    }
    
    // MARK: - Equatable and isEqual override
    
    override public func isEqual(_ object: Any?) -> Bool {
        guard let otherPolyBezier = object as? PolyBezier else { return false }
        return self == otherPolyBezier
    }
    
    public static func == (lhs: PolyBezier, rhs: PolyBezier) -> Bool {
        if lhs.curves.count != rhs.curves.count {
            return false
        }
        for i in 0..<lhs.curves.count { // loop is a little annoying, but BezierCurve cannot conform to Equatable without adding associated type requirements
            guard lhs.curves[i] == rhs.curves[i] else {
                return false
            }
        }
        return true
    }
}
