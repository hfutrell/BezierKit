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

@objc(BezierKitPath) open class Path: NSObject, NSCoding {

    /// lock to make external accessing of lazy vars threadsafe
    private let lock = UnfairLock()

    private class PathApplierFunctionContext {
        var currentPoint: CGPoint?
        var componentStartPoint: CGPoint?

        var currentComponentPoints: [CGPoint] = []
        var currentComponentOrders: [Int] = []

        var components: [PathComponent] = []
        func completeComponentIfNeededAndClearPointsAndOrders() {
            if currentComponentPoints.isEmpty == false {
                if currentComponentOrders.isEmpty == true {
                    currentComponentOrders.append(0)
                }
                components.append(PathComponent(points: currentComponentPoints, orders: currentComponentOrders))
            }
            currentComponentPoints = []
            currentComponentOrders = []
        }
        func appendCurrentPointIfEmpty() {
            if currentComponentPoints.isEmpty {
                currentComponentPoints = [self.currentPoint!]
            }
        }
    }

    @objc(CGPath) public var cgPath: CGPath {
        return self.lock.sync { self._cgPath }
    }

    private lazy var _cgPath: CGPath = {
        let mutablePath = CGMutablePath()
        self.components.forEach {
            $0.appendPath(to: mutablePath)
        }
        return mutablePath.copy()!
    }()

    @objc public var isEmpty: Bool {
        return self.components.isEmpty // components are not allowed to be empty
    }

    public var boundingBox: BoundingBox {
        return self.lock.sync { self._boundingBox }
    }

    private lazy var _boundingBox: BoundingBox = {
        return self.components.reduce(BoundingBox.empty) {
            BoundingBox(first: $0, second: $1.boundingBox)
        }
    }()

    @objc public let components: [PathComponent]

    @objc(point:isWithinDistanceOfBoundary:) public func pointIsWithinDistanceOfBoundary(point p: CGPoint, distance d: CGFloat) -> Bool {
        return self.components.contains {
            $0.pointIsWithinDistanceOfBoundary(point: p, distance: d)
        }
    }

    @objc(selfIntersectsWithAccuracy:) public func selfIntersects(accuracy: CGFloat = BezierKit.defaultIntersectionAccuracy) -> Bool {
        return !self.selfIntersections(accuracy: accuracy).isEmpty
    }

    public func selfIntersections(accuracy: CGFloat = BezierKit.defaultIntersectionAccuracy) -> [PathIntersection] {
        var intersections: [PathIntersection] = []
        for i in 0..<self.components.count {
            for j in i..<self.components.count {
                let componentIntersectionToPathIntersection = {(componentIntersection: PathComponentIntersection) -> PathIntersection in
                    PathIntersection(componentIntersection: componentIntersection, componentIndex1: i, componentIndex2: j)
                }
                if i == j {
                    intersections += self.components[i].selfIntersections(accuracy: accuracy).map(componentIntersectionToPathIntersection)
                } else {
                    intersections += self.components[i].intersections(with: self.components[j], accuracy: accuracy).map(componentIntersectionToPathIntersection)
                }
            }
        }
        return intersections
    }

    @objc(intersectsPath:accuracy:) public func intersects(_ other: Path, accuracy: CGFloat = BezierKit.defaultIntersectionAccuracy) -> Bool {
        return !self.intersections(with: other, accuracy: accuracy).isEmpty
    }

    public func intersections(with other: Path, accuracy: CGFloat = BezierKit.defaultIntersectionAccuracy) -> [PathIntersection] {
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
                let componentIntersections: [PathComponentIntersection] = s1.intersections(with: s2, accuracy: accuracy)
                intersections += componentIntersections.map(componentIntersectionToPathIntersection)
            }
        }
        return intersections
    }

    @objc public convenience override init() {
        self.init(components: [])
    }

    @objc required public init(components: [PathComponent]) {
        self.components = components
    }

    @objc(initWithCGPath:) convenience public init(cgPath: CGPath) {
        let context = PathApplierFunctionContext()
        func applierFunction(_ ctx: UnsafeMutableRawPointer?, _ element: UnsafePointer<CGPathElement>) {
            guard let context = ctx?.assumingMemoryBound(to: PathApplierFunctionContext.self).pointee else {
                fatalError("unexpected applierFunction context")
            }
            let points: UnsafeMutablePointer<CGPoint> = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                context.completeComponentIfNeededAndClearPointsAndOrders()
                context.componentStartPoint = points[0]
                context.currentComponentOrders = []
                context.currentComponentPoints = [points[0]]
                context.currentPoint = points[0]
            case .addLineToPoint:
                context.appendCurrentPointIfEmpty()
                context.currentComponentOrders.append(1)
                context.currentComponentPoints.append(points[0])
                context.currentPoint = points[0]
            case .addQuadCurveToPoint:
                context.appendCurrentPointIfEmpty()
                context.currentComponentOrders.append(2)
                context.currentComponentPoints.append(points[0])
                context.currentComponentPoints.append(points[1])
                context.currentPoint = points[1]
            case .addCurveToPoint:
                context.appendCurrentPointIfEmpty()
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
                context.completeComponentIfNeededAndClearPointsAndOrders()
                context.currentPoint = context.componentStartPoint!
            @unknown default:
                fatalError("unexpected unknown path element type \(element.pointee.type)")
            }
        }
        withUnsafePointer(to: context) {
            let rawPointer = UnsafeMutableRawPointer(mutating: $0)
            cgPath.apply(info: rawPointer, function: applierFunction)
        }
        context.completeComponentIfNeededAndClearPointsAndOrders()
        self.init(components: context.components)
    }

    convenience public init(curve: BezierCurve) {
        self.init(components: [PathComponent(curve: curve)])
    }

    // MARK: - NSCoding
    // (cannot be put in extension because init?(coder:) is a designated initializer)

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(self.data)
    }

    required public convenience init?(coder aDecoder: NSCoder) {
        guard let data = aDecoder.decodeData() else { return nil }
        self.init(data: data)
    }

    // MARK: -

    override open func isEqual(_ object: Any?) -> Bool {
        // override is needed because NSObject implementation of isEqual(_:) uses pointer equality
        guard let otherPath = object as? Path else {
            return false
        }
        return self.components == otherPath.components
    }

    // MARK: - vector boolean operations

    public func point(at location: IndexedPathLocation) -> CGPoint {
        return self.elementAtComponentIndex(location.componentIndex, elementIndex: location.elementIndex).point(at: location.t)
    }

    internal func elementAtComponentIndex(_ componentIndex: Int, elementIndex: Int) -> BezierCurve {
        return self.components[componentIndex].element(at: elementIndex)
    }

    internal func windingCount(_ point: CGPoint, ignoring: PathComponent? = nil) -> Int {
        let windingCount = self.components.reduce(0) {
            if $1 !== ignoring {
                return $0 + $1.windingCount(at: point)
            } else {
                return $0
            }
        }
        return windingCount
    }

    @objc(containsPoint:usingRule:) public func contains(_ point: CGPoint, using rule: PathFillRule = .winding) -> Bool {
        let count = self.windingCount(point)
        return windingCountImpliesContainment(count, using: rule)
    }

    @objc(containsPath:usingRule:accuracy:) public func contains(_ other: Path, using rule: PathFillRule = .winding, accuracy: CGFloat = BezierKit.defaultIntersectionAccuracy) -> Bool {
        // first, check that each component of `other` starts inside self
        for component in other.components {
            let p = component.startingPoint
            guard self.contains(p, using: rule) else {
                return false
            }
        }
        // next, for each intersection (if there are any) check that we stay inside the path
        // TODO: use enumeration over intersections so we don't have to necessarily have to find each one
        // TODO: make this work with winding fill rule and intersections that don't cross (suggestion, use AugmentedGraph)
        return !self.intersects(other, accuracy: accuracy)
    }

    @objc(offsetWithDistance:) public func offset(distance d: CGFloat) -> Path {
        return Path(components: self.components.compactMap {
            $0.offset(distance: d)
        })
    }

    private func performBooleanOperation(_ operation: BooleanPathOperation, with other: Path, accuracy: CGFloat) -> Path {
        let intersections = self.intersections(with: other, accuracy: accuracy)
        let augmentedGraph = AugmentedGraph(path1: self, path2: other, intersections: intersections, operation: operation)
        return augmentedGraph.performOperation()
    }

    @objc(subtractPath:accuracy:) public func subtract(_ other: Path, accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
        return self.performBooleanOperation(.subtract, with: other.reversed(), accuracy: accuracy)
    }

    @objc(unionPath:accuracy:) public func `union`(_ other: Path, accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
        guard self.isEmpty == false else {
            return other
        }
        guard other.isEmpty == false else {
            return self
        }
        return self.performBooleanOperation(.union, with: other, accuracy: accuracy)
    }

    @objc(intersectPath:accuracy:) public func intersect(_ other: Path, accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
        return self.performBooleanOperation(.intersect, with: other, accuracy: accuracy)
    }

    @objc(crossingsRemovedWithAccuracy:) public func crossingsRemoved(accuracy: CGFloat=BezierKit.defaultIntersectionAccuracy) -> Path {
        let intersections = self.selfIntersections(accuracy: accuracy)
        let augmentedGraph = AugmentedGraph(path1: self, path2: self, intersections: intersections, operation: .removeCrossings)
        return augmentedGraph.performOperation()
    }

    @objc public func disjointComponents() -> [Path] {
        let rule: PathFillRule = .evenOdd
        var outerComponents: [PathComponent: [PathComponent]] = [:]
        var innerComponents: [PathComponent] = []
        // determine which components are outer and which are inner
        for component in self.components {
            let windingCount = self.windingCount(component.startingPoint, ignoring: component)
            if windingCountImpliesContainment(windingCount, using: rule) {
                innerComponents.append(component)
            } else {
                outerComponents[component] = [component]
            }
        }
        // file the inner components into their "owning" outer components
        for component in innerComponents {
            var owner: PathComponent?
            for outer in outerComponents.keys {
                if let owner = owner {
                    guard outer.boundingBox.intersection(owner.boundingBox) == outer.boundingBox else { continue }
                }
                if outer.contains(component.startingPoint, using: rule) {
                    owner = outer
                }
            }
            if let owner = owner {
                outerComponents[owner]?.append(component)
            }
        }
        return outerComponents.values.map { Path(components: $0) }
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

public struct IndexedPathLocation: Equatable, Comparable {
    public let componentIndex: Int
    public let elementIndex: Int
    public let t: CGFloat
    public init(componentIndex: Int, elementIndex: Int, t: CGFloat) {
        self.componentIndex = componentIndex
        self.elementIndex = elementIndex
        self.t = t
    }
    public init(componentIndex: Int, locationInComponent: IndexedPathComponentLocation) {
        self.init(componentIndex: componentIndex, elementIndex: locationInComponent.elementIndex, t: locationInComponent.t)
    }
    public static func < (lhs: IndexedPathLocation, rhs: IndexedPathLocation) -> Bool {
        if lhs.componentIndex < rhs.componentIndex {
            return true
        } else if lhs.componentIndex > rhs.componentIndex {
            return false
        }
        if lhs.elementIndex < rhs.elementIndex {
            return true
        } else if lhs.elementIndex > rhs.elementIndex {
            return false
        }
        return lhs.t < rhs.t
    }
    public var locationInComponent: IndexedPathComponentLocation {
        return IndexedPathComponentLocation(elementIndex: self.elementIndex, t: self.t)
    }
}

public struct PathIntersection: Equatable {
    public let indexedPathLocation1, indexedPathLocation2: IndexedPathLocation
    internal init(indexedPathLocation1: IndexedPathLocation, indexedPathLocation2: IndexedPathLocation) {
        self.indexedPathLocation1 = indexedPathLocation1
        self.indexedPathLocation2 = indexedPathLocation2
    }
    fileprivate init(componentIntersection: PathComponentIntersection, componentIndex1: Int, componentIndex2: Int) {
        self.indexedPathLocation1 = IndexedPathLocation(componentIndex: componentIndex1, locationInComponent: componentIntersection.indexedComponentLocation1)
        self.indexedPathLocation2 = IndexedPathLocation(componentIndex: componentIndex2, locationInComponent: componentIntersection.indexedComponentLocation2)
    }
}
