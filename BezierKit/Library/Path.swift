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
        var componentStartPoint: CGPoint? = nil
        
        var currentComponentPoints: [CGPoint] = []
        var currentComponentOrders: [Int] = []
        
        var components: [PathComponent] = []
        func finishUp() {
            if currentComponentPoints.isEmpty == false {
                components.append(PathComponent(points: currentComponentPoints, orders: currentComponentOrders))
                currentComponentPoints = []
                currentComponentOrders = []
            }
        }
    }
    
    @objc(CGPath) public lazy var cgPath: CGPath = {
        let mutablePath = CGMutablePath()
        self.components.forEach {
            mutablePath.addPath($0.cgPath)
        }
        return mutablePath.copy()!
    }()
    
    @objc public var isEmpty: Bool {
        return self.components.isEmpty // components are not allowed to be empty
    }
    
    public lazy var boundingBox: BoundingBox = {
        return self.components.reduce(BoundingBox.empty) {
            BoundingBox(first: $0, second: $1.boundingBox)
        }
    }()
    
    public let components: [PathComponent]
    
    @objc(point:isWithinDistanceOfBoundary:errorThreshold:) public func pointIsWithinDistanceOfBoundary(point p: CGPoint, distance d: CGFloat, errorThreshold: CGFloat = BezierKit.defaultIntersectionThreshold) -> Bool {
        return self.components.contains {
            $0.pointIsWithinDistanceOfBoundary(point: p, distance: d, errorThreshold: errorThreshold)
        }
    }
    
    @objc(intersectsWithThreshold:) public func intersects(threshold: CGFloat = BezierKit.defaultIntersectionThreshold) -> [PathIntersection] {
        var intersections: [PathIntersection] = []
        for i in 0..<self.components.count {
            for j in i..<self.components.count {
                let componentIntersectionToPathIntersection = {(componentIntersection: PathComponentIntersection) -> PathIntersection in
                    PathIntersection(componentIntersection: componentIntersection, componentIndex1: i, componentIndex2: j)
                }
                if i == j {
                    intersections += self.components[i].intersects(threshold: threshold).map(componentIntersectionToPathIntersection)
                }
                else {
                    intersections += self.components[i].intersects(component: self.components[j], threshold: threshold).map(componentIntersectionToPathIntersection)
                }
            }
        }
        return intersections
    }
    
    @objc(intersectsWithPath:threshold:) public func intersects(path other: Path, threshold: CGFloat = BezierKit.defaultIntersectionThreshold) -> [PathIntersection] {
        guard self.boundingBox.overlaps(other.boundingBox) else {
            return []
        }
        var intersections: [PathIntersection] = []
        for i in 0..<self.components.count {
            for j in 0..<other.components.count {
                let componentIntersectionToPathIntersection = {(componentIntersection: PathComponentIntersection) -> PathIntersection in
                    PathIntersection(componentIntersection: componentIntersection, componentIndex1: i, componentIndex2: j)
                }
                let s1 = self.components[i]
                let s2 = other.components[j]
                let componentIntersections: [PathComponentIntersection] = s1.intersects(component: s2, threshold: threshold)
                intersections += componentIntersections.map(componentIntersectionToPathIntersection)
            }
        }
        return intersections
    }
    
    @objc public convenience override init() {
        self.init(components: [])
    }
    
    required public init(components: [PathComponent]) {
        self.components = components
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
                if context.currentComponentOrders.isEmpty == false {
                    context.components.append(PathComponent(points: context.currentComponentPoints, orders: context.currentComponentOrders))
                }
                context.componentStartPoint = points[0]
                context.currentComponentOrders = []
                context.currentComponentPoints = [points[0]]
                context.currentPoint = points[0]
            case .addLineToPoint:
                context.currentComponentOrders.append(1)
                context.currentComponentPoints.append(points[0])
                context.currentPoint = points[0]
            case .addQuadCurveToPoint:
                context.currentComponentOrders.append(2)
                context.currentComponentPoints.append(points[0])
                context.currentComponentPoints.append(points[1])
                context.currentPoint = points[1]
            case .addCurveToPoint:
                context.currentComponentOrders.append(3)
                context.currentComponentPoints.append(points[0])
                context.currentComponentPoints.append(points[1])
                context.currentComponentPoints.append(points[2])
                context.currentPoint = points[2]
            case .closeSubpath:
                if context.currentPoint != context.componentStartPoint {
                    context.currentComponentOrders.append(1)
                    context.currentComponentPoints.append(context.componentStartPoint!)
                }
                if context.currentComponentOrders.isEmpty == false {
                    context.components.append(PathComponent(points: context.currentComponentPoints, orders: context.currentComponentOrders))
                }
                context.currentPoint = context.componentStartPoint!
                context.currentComponentPoints = []
                context.currentComponentOrders = []
            }
        }
        let rawContextPointer = UnsafeMutableRawPointer(&context).bindMemory(to: PathApplierFunctionContext.self, capacity: 1)
        cgPath.apply(info: rawContextPointer, function: applierFunction)
        context.finishUp()
        
        self.init(components: context.components)
    }
    
    // MARK: - NSCoding
    // (cannot be put in extension because init?(coder:) is a designated initializer)
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(self.components)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        guard let array = aDecoder.decodeObject() as? Array<PathComponent> else {
            return nil
        }
        self.components = array
    }
    
    // MARK: -
    
    override public func isEqual(_ object: Any?) -> Bool {
        // override is needed because NSObject implementation of isEqual(_:) uses pointer equality
        guard let otherPath = object as? Path else {
            return false
        }
        return self.components == otherPath.components
    }
    
    // MARK: - vector boolean operations
    
    public func point(at location: IndexedPathLocation) -> CGPoint {
        return self.elementAtComponentIndex(location.componentIndex, elementIndex: location.elementIndex).compute(location.t)
    }
    
    internal func elementAtComponentIndex(_ componentIndex: Int, elementIndex: Int) -> BezierCurve {
        return self.components[componentIndex].element(at: elementIndex)
    }
    
    internal func windingCount(_ point: CGPoint, ignoring: PathComponent? = nil) -> Int {
        let windingCount = self.components.reduce(0) {
            if $1 !== ignoring {
                return $0 + $1.windingCount(at: point)
            }
            else {
                return $0
            }
        }
        return windingCount
    }

    @objc(containsPoint:usingRule:) public func contains(_ point: CGPoint, using rule: PathFillRule = .winding) -> Bool {
        let count = self.windingCount(point)
        return windingCountImpliesContainment(count, using: rule)
    }

    @objc(containsPath:) public func contains(_ other: Path) -> Bool {
        // first, check that each component of `other` starts inside self
        for component in other.components {
            let p = component.startingPoint
            guard self.contains(p) else {
                return false
            }
        }
        // next, for each intersection (if there are any) check that we stay inside the path
        // TODO: use enumeration over intersections so we don't have to necessarily have to find each one
        // TODO: make this work with winding fill rule and intersections that don't cross (suggestion, use AugmentedGraph)
        return self.intersects(path: other).isEmpty
    }
    
    @objc(offsetWithDistance:) public func offset(distance d: CGFloat) -> Path {
        return Path(components: self.components.map {
            $0.offset(distance: d)
        })
    }
    
    private func performBooleanOperation(_ operation: BooleanPathOperation, withPath other: Path, threshold: CGFloat) -> Path? {
        let intersections = self.intersects(path: other, threshold: threshold)
        let augmentedGraph = AugmentedGraph(path1: self, path2: other, intersections: intersections)
        return augmentedGraph.booleanOperation(operation)
    }
    
    @objc(subtractingPath:threshold:) public func subtracting(_ other: Path, threshold: CGFloat=BezierKit.defaultIntersectionThreshold) -> Path? {
        return self.performBooleanOperation(.difference, withPath: other.reversed(), threshold: threshold)
    }
    
    @objc(unionedWithPath:threshold:) public func `union`(_ other: Path, threshold: CGFloat=BezierKit.defaultIntersectionThreshold) -> Path? {
        guard self.isEmpty == false else {
            return other
        }
        guard other.isEmpty == false else {
            return self
        }
        return self.performBooleanOperation(.union, withPath: other, threshold: threshold)
    }
    
    @objc(intersectedWithPath:threshold:) public func intersecting(_ other: Path, threshold: CGFloat=BezierKit.defaultIntersectionThreshold) -> Path? {
        return self.performBooleanOperation(.intersection, withPath: other, threshold: threshold)
    }
    
    @objc(crossingsRemovedWithThreshold:) public func crossingsRemoved(threshold: CGFloat=BezierKit.defaultIntersectionThreshold) -> Path? {
        let intersections = self.intersects(threshold: threshold)
        let augmentedGraph = AugmentedGraph(path1: self, path2: self, intersections: intersections)
        return augmentedGraph.booleanOperation(.removeCrossings)
    }

    @objc public func disjointComponents() -> [Path] {
        
        var paths: [Path] = []
        var componentWindingCounts: [Path: Int] = [:]
        let componentsAsPaths = self.components.map { Path(components: [$0]) }
        for component in componentsAsPaths {
            let windingCount = self.windingCount(component.components[0].startingPoint, ignoring: component.components[0])
            if windingCount == 0 {
                paths.append(component)
            }
            componentWindingCounts[component] = windingCount
        }
        
        var pathsWithHoles: [Path: Path] = [:]
        for path in paths {
            pathsWithHoles[path] = path
        }
        
        for component in componentsAsPaths {
            guard componentWindingCounts[component] != 0 else {
                continue
            }
            var owner: Path? = nil
            for path in paths {
                guard path.contains(component) else {
                    continue
                }
                if owner != nil {
                    if owner!.contains(path) {
                        owner = path
                    }
                }
                else {
                    owner = path
                }
            }
            if let owner = owner {
                pathsWithHoles[owner] = Path(components: pathsWithHoles[owner]!.components + component.components)
            }
        }
        return Array(pathsWithHoles.values)
    }
}

@objc extension Path: Transformable {
    @objc(copyUsingTransform:) public func copy(using t: CGAffineTransform) -> Self {
        return type(of: self).init(components: self.components.map { $0.copy(using: t)})
    }
}

@objc extension Path: Reversible {
    public func reversed() -> Self {
        return type(of: self).init(components: self.components.map { $0.reversed() })
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
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? IndexedPathLocation else {
            return false
        }
        return self.componentIndex == other.componentIndex && self.elementIndex == other.elementIndex && self.t == other.t
    }
}

@objc(BezierKitPathIntersection) public class PathIntersection: NSObject {
    public let indexedPathLocation1, indexedPathLocation2: IndexedPathLocation
    internal init(indexedPathLocation1: IndexedPathLocation, indexedPathLocation2: IndexedPathLocation) {
        self.indexedPathLocation1 = indexedPathLocation1
        self.indexedPathLocation2 = indexedPathLocation2
    }
    fileprivate init(componentIntersection: PathComponentIntersection, componentIndex1: Int, componentIndex2: Int) {
        self.indexedPathLocation1 = IndexedPathLocation(componentIndex: componentIndex1,
                                                        elementIndex: componentIntersection.indexedComponentLocation1.elementIndex,
                                                        t: componentIntersection.indexedComponentLocation1.t)
        self.indexedPathLocation2 = IndexedPathLocation(componentIndex: componentIndex2,
                                                        elementIndex: componentIntersection.indexedComponentLocation2.elementIndex,
                                                        t: componentIntersection.indexedComponentLocation2.t)

    }
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? PathIntersection else {
            return false
        }
        return self.indexedPathLocation1 == other.indexedPathLocation1 && self.indexedPathLocation2 == other.indexedPathLocation2
    }
}
