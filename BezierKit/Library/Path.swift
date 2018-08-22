//
//  BezierPath.swift
//  BezierKit
//
//  Created by Holmes Futrell on 7/31/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import CoreGraphics
import Foundation

@objc(BezierKitPath) public class Path: NSObject, NSCoding {
    
    private class PathApplierFunctionContext {
        var currentPoint: CGPoint? = nil
        var subpathStartPoint: CGPoint? = nil
        var currentSubpath: [BezierCurve] = []
        var components: [PathComponent] = []
        func finishUp() {
            if currentSubpath.isEmpty == false {
                components.append(PathComponent(curves: currentSubpath))
                currentSubpath = []
            }
        }
    }
    
    @objc public lazy var cgPath: CGPath = {
        let mutablePath = CGMutablePath()
        self.subpaths.forEach {
            mutablePath.addPath($0.cgPath)
        }
        return mutablePath.copy()!
    }()
    
    public lazy var boundingBox: BoundingBox = {
        return self.subpaths.reduce(BoundingBox.empty) {
            BoundingBox(first: $0, second: $1.boundingBox)
        }
    }()
    
    public let subpaths: [PathComponent]
    
    public func pointIsWithinDistanceOfBoundary(point p: CGPoint, distance d: CGFloat) -> Bool {
        return self.subpaths.contains {
            $0.pointIsWithinDistanceOfBoundary(point: p, distance: d)
        }
    }
    
    @objc(intersectsPath:threshold:) public func intersects(path: Path, threshold: CGFloat = BezierKit.defaultIntersectionThreshold) -> [CGPoint] {
        guard self.boundingBox.overlaps(path.boundingBox) else {
            return []
        }
        var intersections: [CGPoint] = []
        for s1 in self.subpaths {
            for s2 in path.subpaths {
                let componentIntersections: [PathComponentIntersection] = s1.intersects(s2, threshold: threshold)
                intersections += componentIntersections.map { s1.point(at: $0.indexedComponentLocation1) }
            }
        }
        return intersections
    }
    
    required public init(subpaths: [PathComponent]) {
        self.subpaths = subpaths
    }
    
    @objc(initWithCGPath:) convenience public init(cgPath: CGPath) {
        var context = PathApplierFunctionContext()
        func applierFunction(_ ctx: UnsafeMutableRawPointer?, _ element: UnsafePointer<CGPathElement>) {
            guard let context = ctx?.assumingMemoryBound(to: PathApplierFunctionContext.self).pointee else {
                fatalError("unexpected applierFunction context")
            }
            let points: UnsafeMutablePointer<CGPoint> = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                if context.currentSubpath.isEmpty == false {
                    context.components.append(PathComponent(curves: context.currentSubpath))
                }
                context.currentPoint = points[0]
                context.subpathStartPoint = points[0]
                context.currentSubpath = []
            case .addLineToPoint:
                let line = LineSegment(p0: context.currentPoint!, p1: points[0])
                context.currentSubpath.append(line)
                context.currentPoint = points[0]
            case .addQuadCurveToPoint:
                let quadCurve = QuadraticBezierCurve(p0: context.currentPoint!, p1: points[0], p2: points[1])
                context.currentSubpath.append(quadCurve)
                context.currentPoint = points[1]
            case .addCurveToPoint:
                let cubicCurve = CubicBezierCurve(p0: context.currentPoint!, p1: points[0], p2: points[1], p3: points[2])
                context.currentSubpath.append(cubicCurve)
                context.currentPoint = points[2]
            case .closeSubpath:
                if context.currentPoint != context.subpathStartPoint {
                    let line = LineSegment(p0: context.currentPoint!, p1: context.subpathStartPoint!)
                    context.currentSubpath.append(line)
                }
                context.components.append(PathComponent(curves: context.currentSubpath))
                context.currentPoint = context.subpathStartPoint!
                context.currentSubpath = []
            }
        }
        let rawContextPointer = UnsafeMutableRawPointer(&context).bindMemory(to: PathApplierFunctionContext.self, capacity: 1)
        cgPath.apply(info: rawContextPointer, function: applierFunction)
        context.finishUp()
        
        self.init(subpaths: context.components)
    }
    
    // MARK: - NSCoding
    // (cannot be put in extension because init?(coder:) is a designated initializer)
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(self.subpaths)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        guard let array = aDecoder.decodeObject() as? Array<PathComponent> else {
            return nil
        }
        self.subpaths = array
    }
    
    // MARK: -
    
    override public func isEqual(_ object: Any?) -> Bool {
        // override is needed because NSObject implementation of isEqual(_:) uses pointer equality
        guard let otherPath = object as? Path else {
            return false
        }
        return self.subpaths == otherPath.subpaths
    }
    
    // MARK: -
    
    public func point(at location: IndexedPathLocation) -> CGPoint {
        return self.element(at: location).compute(location.t)
    }
    
    private func element(at location: IndexedPathLocation) -> BezierCurve {
        return self.subpaths[location.componentIndex].curves[location.elementIndex]
    }
    
    internal func intersects(line: LineSegment) -> [IndexedPathLocation] {
        let lineBoundingBox = line.boundingBox
        var results: [IndexedPathLocation] = []
        for i in 0..<subpaths.count {
            let subpath: PathComponent = self.subpaths[i]
            subpath.bvh.visit { (node: BVHNode, depth: Int) in
                if case let .leaf(object, elementIndex) = node.nodeType {
                    let curve = object as! BezierCurve
                    results += curve.intersects(line: line).map {
                        return IndexedPathLocation(componentIndex: i, elementIndex: elementIndex, t: $0.t1)
                    }
                }
                // TODO: better line box intersection
                return node.boundingBox.overlaps(lineBoundingBox)
            }
        }
        return results
    }
    
    @objc public func contains(_ point: CGPoint, using rule: PathFillRule = .winding) -> Bool {
        // TODO: assumes element.normal() is always defined, which unfortunately it's not (eg degenerate curves as points, cusps, zero derivatives at the end of curves)
        let line = LineSegment(p0: point, p1: CGPoint(x: self.boundingBox.min.x - self.boundingBox.size.x, y: point.y)) // horizontal line from point out of bounding box
        let delta = line.p1 - line.p0
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
        switch rule {
            case .winding:
                return windingCount != 0
            case .evenOdd:
                return abs(windingCount) % 2 == 1
        }
    }
    
//    @objc public func simplifyToEvenOdd() -> Path {
//        
//        for element in self.pathElements {
//            
//            let intersection = self.intersect(element)
//            
//            // let's pretend for a second that these intersections are de-duped so it's just a set of t-values
//            
//            
//            
//        }
//        
//        // ok, let's pretend now we have a sorted list of path locations that represent intersections
//        // ok, why does 1 location have an array of others? because the same t-value might intersect multiple curves
//        [ location1 : [other1, other2, other3]]
//        
//        // ok, next we proceed around the locations and start doing splits and isertions and things
//        
//        // TODO: lol, it's a stub! you need to actually write this
//        return self
//    }
}

@objc public enum PathFillRule: NSInteger {
    case winding=0, evenOdd
};

@objc extension Path: Transformable {
    @objc(copyUsingTransform:) public func copy(using t: CGAffineTransform) -> Self {
        return type(of: self).init(subpaths: self.subpaths.map { $0.copy(using: t)})
    }
}

@objc extension Path: Reversible {
    public func reversed() -> Self {
        return type(of: self).init(subpaths: self.subpaths.map { $0.reversed() })
    }
}

//@objc(BezierKitPathIntersection) public class PathIntersection: NSObject {
//    let indices: [IndexedPathLocation]
//    init(indices: [IndexedPathLocation]) {
//        self.indices = indices
//    }
//}

@objc(BezierKitPathIndex) public class IndexedPathLocation: NSObject {
    fileprivate let componentIndex: Int
    fileprivate let elementIndex: Int
    fileprivate let t: CGFloat
    init(componentIndex: Int, elementIndex: Int, t: CGFloat) {
        self.componentIndex = componentIndex
        self.elementIndex = elementIndex
        self.t = t
    }
}
