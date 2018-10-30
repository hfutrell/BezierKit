//
//  PathComponent.swift
//  BezierKit
//
//  Created by Holmes Futrell on 11/23/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import CoreGraphics
import Foundation

#if os(macOS)
private extension NSValue { // annoying but MacOS (unlike iOS) doesn't have NSValue.cgPointValue available
    var cgPointValue: CGPoint {
        let pointValue: NSPoint = self.pointValue
        return CGPoint(x: pointValue.x, y: pointValue.y)
    }
    convenience init(cgPoint: CGPoint) {
        self.init(point: NSPoint(x: cgPoint.x, y: cgPoint.y))
    }
}
#endif

public final class PathComponent: NSObject, NSCoding {
    
    public let curves: [BezierCurve]
    
    internal lazy var bvh: BVHNode = BVHNode(objects: curves)
    
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
    
    public init(curves: [BezierCurve]) {
        self.curves = curves
    }
    
    public var length: CGFloat {
        return self.curves.reduce(0.0) { $0 + $1.length() }
    }
    
    public var boundingBox: BoundingBox {
        return self.bvh.boundingBox
    }
    
    public func offset(distance d: CGFloat) -> PathComponent {
        return PathComponent(curves: self.curves.reduce([]) {
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
            else if case let .leaf(object, _) = node.nodeType {
                let curve = object as! BezierCurve
                if distance(p, curve.project(point: p)) < d {
                    found = true
                }
            }
            return !found && node.boundingBox.lowerBoundOfDistance(to: p) <= d
        }
        return found
    }
    
    public func intersects(component other: PathComponent, threshold: CGFloat = BezierKit.defaultIntersectionThreshold) -> [PathComponentIntersection] {
        precondition(other !== self, "use intersects(threshold:) for self intersection testing.")
        var intersections: [PathComponentIntersection] = []
        self.bvh.intersects(node: other.bvh) { o1, o2, i1, i2 in
            let c1 = o1 as! BezierCurve
            let c2 = o2 as! BezierCurve
            let elementIntersections = c1.intersects(curve: c2, threshold: threshold)
            let pathComponentIntersections = elementIntersections.compactMap { (i: Intersection) -> PathComponentIntersection? in
                let i1 = IndexedPathComponentLocation(elementIndex: i1, t: i.t1)
                let i2 = IndexedPathComponentLocation(elementIndex: i2, t: i.t2)
                guard i1.t != 0.0 && i2.t != 0.0 else {
                    // we'll get this intersection at t=1 on the neighboring path element(s) instead
                    return nil
                }
                return PathComponentIntersection(indexedComponentLocation1: i1, indexedComponentLocation2: i2)
            }
            intersections += pathComponentIntersections
        }
        return intersections
    }
    
    public func intersects(threshold: CGFloat = BezierKit.defaultIntersectionThreshold) -> [PathComponentIntersection] {
        var intersections: [PathComponentIntersection] = []
        self.bvh.intersects(node: self.bvh) { o1, o2, i1, i2 in
            let c1 = o1 as! BezierCurve
            let c2 = o2 as! BezierCurve
            var elementIntersections: [Intersection] = []
            if i1 == i2 {
                // we are intersecting a path element against itself
                if let c = c1 as? CubicBezierCurve {
                    elementIntersections = c.intersects(threshold: threshold)
                }
            }
            else {
                // we are intersecting two distinct path elements
                elementIntersections = c1.intersects(curve: c2, threshold: threshold).filter {
                    if i1 == Utils.mod(i2+1, self.curves.count) && $0.t1 == 0.0 {
                        return false // exclude intersections of i and i-1 at t=0
                    }
                    if i1 == Utils.mod(i2-1, self.curves.count) && $0.t1 == 1.0 {
                        return false // exclude intersections of i and i+1 at t=1
                    }
                    return true
                }
            }
            intersections += elementIntersections.map {
                return PathComponentIntersection(indexedComponentLocation1: IndexedPathComponentLocation(elementIndex: i1, t: $0.t1),
                                                 indexedComponentLocation2: IndexedPathComponentLocation(elementIndex: i2, t: $0.t2))
            }
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
        guard let curveData = aDecoder.decodeObject() as? [[NSValue]] else {
            return nil
        }
        self.curves = curveData.map { values in
            createCurve(from: values.map { $0.cgPointValue })!
        }
    }
    
    // MARK: -
    
    override public func isEqual(_ object: Any?) -> Bool {
        // override is needed because NSObject implementation of isEqual(_:) uses pointer equality
        guard let otherPathComponent = object as? PathComponent else {
            return false
        }
        guard self.curves.count == otherPathComponent.curves.count else {
            return false
        }
        for i in 0..<self.curves.count { // loop is a little annoying, but BezierCurve cannot conform to Equatable without adding associated type requirements
            guard self.curves[i] == otherPathComponent.curves[i] else {
                return false
            }
        }
        return true
    }
    
    // MARK: -
    
    internal func intersects(line: LineSegment) -> [IndexedPathComponentLocation] {
        let lineBoundingBox = line.boundingBox
        var results: [IndexedPathComponentLocation] = []
        self.bvh.visit { (node: BVHNode, depth: Int) in
            if case let .leaf(object, elementIndex) = node.nodeType {
                let curve = object as! BezierCurve
                results += curve.intersects(line: line).compactMap {
                return IndexedPathComponentLocation(elementIndex: elementIndex, t: $0.t1)
                }
            }
            // TODO: better line box intersection
            return node.boundingBox.overlaps(lineBoundingBox)
        }
        return results
    }

    public func point(at location: IndexedPathComponentLocation) -> CGPoint {
        return self.curves[location.elementIndex].compute(location.t)
    }
    
    internal func windingCount(at point: CGPoint) -> Int {
        // TODO: assumes element.normal() is always defined, which unfortunately it's not (eg degenerate curves as points, cusps, zero derivatives at the end of curves)
        let line = LineSegment(p0: point, p1: CGPoint(x: self.boundingBox.min.x - self.boundingBox.size.x, y: point.y)) // horizontal line from point out of bounding box
        let delta = line.p0 - line.p1
        let intersections = self.intersects(line: line)
        var windingCount = 0
        intersections.forEach {
            let element = self.element(at: $0)
            let t = $0.t
            assert(element.derivative($0.t).length > 1.0e-3, "possible NaN normal vector. Possible data for unit test?")
            let dotProduct = delta.dot(element.normal(t))
            if dotProduct < 0 {
                if t != 0 {
                    windingCount -= 1
                }
            }
            else if dotProduct > 0 {
                if t != 1 {
                    windingCount += 1
                }
            }
        }
        return windingCount
    }
    
    private func element(at location: IndexedPathComponentLocation) -> BezierCurve {
        return self.curves[location.elementIndex]
    }
    
    public func contains(_ point: CGPoint, using rule: PathFillRule = .winding) -> Bool {
        let windingCount = self.windingCount(at: point)
        return windingCountImpliesContainment(windingCount, using: rule)
    }
    
}

extension PathComponent: Transformable {
    public func copy(using t: CGAffineTransform) -> PathComponent {
        return PathComponent(curves: self.curves.map { $0.copy(using: t)} )
    }
}

extension PathComponent: Reversible {
    public func reversed() -> PathComponent {
        return PathComponent(curves: self.curves.reversed().map({$0.reversed()}))
    }
}

public struct IndexedPathComponentLocation {
    let elementIndex: Int
    let t: CGFloat
}

public struct PathComponentIntersection {
    let indexedComponentLocation1, indexedComponentLocation2: IndexedPathComponentLocation
}
