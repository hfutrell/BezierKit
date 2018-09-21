//
//  BezierPath.swift
//  BezierKit
//
//  Created by Holmes Futrell on 7/31/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import CoreGraphics
import Foundation

@objc(BezierKitPathFillRule) public enum PathFillRule: NSInteger {
    case winding=0, evenOdd
}

internal func windingCountImpliesContainment(_ count: Int, using rule: PathFillRule) -> Bool {
    switch rule {
    case .winding:
        return count != 0
    case .evenOdd:
        return count % 2 != 0
    }
}

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
    
    @objc(intersectsWithPath:threshold:) public func intersects(path other: Path, threshold: CGFloat = BezierKit.defaultIntersectionThreshold) -> [PathIntersection] {
        guard self.boundingBox.overlaps(other.boundingBox) else {
            return []
        }
        var intersections: [PathIntersection] = []
        for i in 0..<self.subpaths.count {
            for j in 0..<other.subpaths.count {
                let s1 = self.subpaths[i]
                let s2 = other.subpaths[j]
                let componentIntersections: [PathComponentIntersection] = s1.intersects(component: s2, threshold: threshold)
                intersections += componentIntersections.map { PathIntersection(indexedPathLocation1: IndexedPathLocation(componentIndex: i, elementIndex: $0.indexedComponentLocation1.elementIndex, t: $0.indexedComponentLocation1.t),
                                                                               indexedPathLocation2: IndexedPathLocation(componentIndex: j, elementIndex: $0.indexedComponentLocation2.elementIndex, t: $0.indexedComponentLocation2.t)) }
            }
        }
        return intersections
    }
    
    @objc public convenience override init() {
        self.init(subpaths: [])
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
    
    // MARK: - vector boolean operations
    
    public func point(at location: IndexedPathLocation) -> CGPoint {
        return self.element(at: location).compute(location.t)
    }
    
    internal func element(at location: IndexedPathLocation) -> BezierCurve {
        return self.subpaths[location.componentIndex].curves[location.elementIndex]
    }
    
    internal func windingCount(_ point: CGPoint, ignoring: PathComponent? = nil) -> Int {
        let windingCount = self.subpaths.reduce(0) {
            if $1 !== ignoring {
                return $0 + $1.windingCount(at: point)
            }
            else {
                return $0
            }
        }
        return windingCount
    }

    private func contains(_ other: Path) -> Bool {
        guard other.subpaths.isEmpty == false else {
            return true
        }
        guard self.intersects(path: other).isEmpty else {
            return false
        }
        return other.subpaths.reduce(true) {
            $0 && self.contains($1.curves[0].startingPoint)
        }
    }
    
    @objc public func contains(_ point: CGPoint, using rule: PathFillRule = .winding) -> Bool {
        let count = self.windingCount(point)
        return windingCountImpliesContainment(count, using: rule)
    }
    
    private func performBooleanOperation(_ operation: BooleanPathOperation, withPath other: Path, threshold: CGFloat) -> Path {
        let intersections = self.intersects(path: other, threshold: threshold)
        let augmentedGraph = AugmentedGraph(path1: self, path2: other, intersections: intersections)
        return augmentedGraph.booleanOperation(operation)
    }
    
    @objc(subtractingPath:threshold:) public func subtracting(_ other: Path, threshold: CGFloat=BezierKit.defaultIntersectionThreshold) -> Path {
        return self.performBooleanOperation(.difference, withPath: other.reversed(), threshold: threshold)
    }
    
    @objc(unionedWithPath:threshold:) public func `union`(_ other: Path, threshold: CGFloat=BezierKit.defaultIntersectionThreshold) -> Path {
        return self.performBooleanOperation(.union, withPath: other, threshold: threshold)
    }
    
    @objc(intersectedWithPath:threshold:) public func intersecting(_ other: Path, threshold: CGFloat=BezierKit.defaultIntersectionThreshold) -> Path {
        return self.performBooleanOperation(.intersection, withPath: other, threshold: threshold)
    }
    
    @objc(crossingsRemovedWithThreshold:) public func crossingsRemoved(threshold: CGFloat=BezierKit.defaultIntersectionThreshold) -> Path {
        assert(self.subpaths.count <= 1, "todo: support multi-component paths")
        guard self.subpaths.count > 0 else {
            return Path()
        }
        let component = self.subpaths[0]
        let intersections = component.intersects(threshold: threshold).compactMap { (i: PathComponentIntersection) -> PathIntersection? in
            guard i.indexedComponentLocation1.elementIndex <= i.indexedComponentLocation2.elementIndex else {
                return nil
            }
            return PathIntersection(indexedPathLocation1: IndexedPathLocation(componentIndex: 0, elementIndex: i.indexedComponentLocation1.elementIndex, t: i.indexedComponentLocation1.t),
                                    indexedPathLocation2: IndexedPathLocation(componentIndex: 0, elementIndex: i.indexedComponentLocation2.elementIndex, t: i.indexedComponentLocation2.t))
        }
        if intersections.count == 0 {
            return self
        }
        let augmentedGraph = AugmentedGraph(path1: self, path2: self, intersections: intersections)
        return augmentedGraph.booleanOperation(.union)
    }
    
    @objc public func disjointSubpaths() -> [Path] {
        
        var paths: Set<Path> = Set<Path>()
        let subpathsAsPaths = self.subpaths.map { Path(subpaths: [$0]) }
        for subpath in subpathsAsPaths {
            if self.windingCount(subpath.subpaths[0].curves[0].startingPoint, ignoring: subpath.subpaths[0]) == 0 {
                paths.insert(subpath)
            }
        }
        
        var pathsWithHoles: [Path: Path] = [:]
        for path in paths {
            pathsWithHoles[path] = path
        }
        
        for subpath in subpathsAsPaths {
            if self.windingCount(subpath.subpaths[0].curves[0].startingPoint, ignoring: subpath.subpaths[0]) != 0 {
                for other in paths {
                    if other.contains(subpath) {
                        pathsWithHoles[other] = Path(subpaths: pathsWithHoles[other]!.subpaths + subpath.subpaths)
                        break
                    }
                }
            }
        }
        
        return Array(pathsWithHoles.values)
    }

}

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

@objc(BezierKitPathPosition) public class IndexedPathLocation: NSObject {
    internal let componentIndex: Int
    internal let elementIndex: Int
    internal let t: CGFloat
    init(componentIndex: Int, elementIndex: Int, t: CGFloat) {
        self.componentIndex = componentIndex
        self.elementIndex = elementIndex
        self.t = t
    }
}

@objc(BezierKitPathIntersection) public class PathIntersection: NSObject {
    public let indexedPathLocation1, indexedPathLocation2: IndexedPathLocation
    init(indexedPathLocation1: IndexedPathLocation, indexedPathLocation2: IndexedPathLocation) {
        self.indexedPathLocation1 = indexedPathLocation1
        self.indexedPathLocation2 = indexedPathLocation2
    }
}
