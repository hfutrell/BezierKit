//
//  BezierPath.swift
//  BezierKit
//
//  Created by Holmes Futrell on 7/31/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

private extension Array {
    /// if an array has unused capacity returns a new array where `self.count == self.capacity`
    /// can save memory when an array is immutable after adding some initial items
    var copyByTrimmingReservedCapacity: Self {
        guard self.capacity > self.count else { return self }
        return withUnsafeBufferPointer { Self($0) }
    }
}

#if os(WASI)
    public enum PathFillRule: NSInteger {
        case winding=0, evenOdd
    }
#else
    @objc(BezierKitPathFillRule) public enum PathFillRule: NSInteger {
        case winding=0, evenOdd
    }
#endif

internal func windingCountImpliesContainment(_ count: Int, using rule: PathFillRule) -> Bool {
    switch rule {
    case .winding:
        return count != 0
    case .evenOdd:
        return count % 2 != 0
    }
}

open class Path: NSObject, NSSecureCoding {
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
                components.append(PathComponent(points: currentComponentPoints.copyByTrimmingReservedCapacity,
                                                orders: currentComponentOrders.copyByTrimmingReservedCapacity))
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

    #if canImport(CoreGraphics)
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
    #endif

    #if os(WASI)
        public var isEmpty: Bool {
            return _isEmpty
        }
    #else
        @objc public var isEmpty: Bool {
            return _isEmpty
        }   
    #endif

    fileprivate var _isEmpty: Bool {
        return self.components.isEmpty // components are not allowed to be empty
    }

    public var boundingBox: BoundingBox {
        return self.lock.sync { self._boundingBox }
    }

    /// the smallest bounding box completely enclosing the points of the path, includings its control points.
    public var boundingBoxOfPath: BoundingBox {
        return self.lock.sync { self._boundingBoxOfPath }
    }

    private lazy var _boundingBox: BoundingBox = {
        return self.components.reduce(BoundingBox.empty) {
            BoundingBox(first: $0, second: $1.boundingBox)
        }
    }()

    private lazy var _boundingBoxOfPath: BoundingBox = {
        return self.components.reduce(BoundingBox.empty) {
            BoundingBox(first: $0, second: $1.boundingBoxOfPath)
        }
    }()

    private var _hash: Int?

    #if os(WASI)
    public let components: [PathComponent]
    #else
    @objc public let components: [PathComponent]
    #endif

    #if os(WASI)
    public func selfIntersects(accuracy: CGFloat = BezierKit.defaultIntersectionAccuracy) -> Bool {
        return _selfIntersects(accuracy: accuracy)
    }
    #else
    @objc(selfIntersectsWithAccuracy:) public func selfIntersects(accuracy: CGFloat = BezierKit.defaultIntersectionAccuracy) -> Bool {
        return _selfIntersects(accuracy: accuracy)
    }
    #endif

    fileprivate func _selfIntersects(accuracy: CGFloat = BezierKit.defaultIntersectionAccuracy) -> Bool {
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

    #if os(WASI)
    public func intersects(_ other: Path, accuracy: CGFloat = BezierKit.defaultIntersectionAccuracy) -> Bool {
        return _intersects(other, accuracy: accuracy)
    }
    #else
    @objc(intersectsPath:accuracy:) public func intersects(_ other: Path, accuracy: CGFloat = BezierKit.defaultIntersectionAccuracy) -> Bool {
        return _intersects(other, accuracy: accuracy)
    }
    #endif

    fileprivate func _intersects(_ other: Path, accuracy: CGFloat = BezierKit.defaultIntersectionAccuracy) -> Bool {
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

    #if os(WASI)
    public convenience override init() {
        self.init(components: [])
    }

    required public init(components: [PathComponent]) {
        self.components = components
    }
    #else
    @objc public convenience override init() {
        self.init(components: [])
    }
    
    @objc required public init(components: [PathComponent]) {
        self.components = components
    }
    #endif

    #if canImport(CoreGraphics)
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

    public func apply(info: UnsafeMutableRawPointer?, function: CGPathApplierFunction) {
        self.components.forEach {
            $0.apply(info: info, function: function)
        }
    }

    #endif

    convenience public init(curve: BezierCurve) {
        self.init(components: [PathComponent(curve: curve)])
    }

    convenience internal init(rect: CGRect) {
        let points = [rect.origin,
                      CGPoint(x: rect.origin.x + rect.size.width, y: rect.origin.y),
                      CGPoint(x: rect.origin.x + rect.size.width, y: rect.origin.y + rect.size.height),
                      CGPoint(x: rect.origin.x, y: rect.origin.y + rect.size.height),
                      rect.origin]
        let component = PathComponent(points: points, orders: [Int](repeating: 1, count: 4))
        self.init(components: [component])
    }

    // MARK: - NSCoding
    // (cannot be put in extension because init?(coder:) is a designated initializer)

    public static var supportsSecureCoding: Bool {
        return true
    }
    
    #if !os(WASI)
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(self.data)
    }

    required public convenience init?(coder aDecoder: NSCoder) {
        guard let data = aDecoder.decodeData() else { return nil }
        self.init(data: data)
    }
    #endif

    // MARK: -

    override open func isEqual(_ object: Any?) -> Bool {
        // override is needed because NSObject implementation of isEqual(_:) uses pointer equality
        guard let otherPath = object as? Path else {
            return false
        }
        return self.components == otherPath.components
    }

    private func assertValidComponent(_ location: IndexedPathLocation) {
        assert(location.componentIndex >= 0 && location.componentIndex < self.components.count)
    }

    public func point(at location: IndexedPathLocation) -> CGPoint {
        self.assertValidComponent(location)
        return self.components[location.componentIndex].point(at: location.locationInComponent)
    }

    public func derivative(at location: IndexedPathLocation) -> CGPoint {
        self.assertValidComponent(location)
        return self.components[location.componentIndex].derivative(at: location.locationInComponent)
    }

    public func normal(at location: IndexedPathLocation) -> CGPoint {
        self.assertValidComponent(location)
        return self.components[location.componentIndex].normal(at: location.locationInComponent)
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

    #if os(WASI)
        public func contains(_ point: CGPoint, using rule: PathFillRule = .winding) -> Bool {
            let count = self.windingCount(point)
            return windingCountImpliesContainment(count, using: rule)
        }
    #else
        @objc(containsPoint:usingRule:) public func contains(_ point: CGPoint, using rule: PathFillRule = .winding) -> Bool {
            return _contains(point, using: rule)
        }
    #endif

    fileprivate func _contains(_ point: CGPoint, using rule: PathFillRule = .winding) -> Bool {
        let count = self.windingCount(point)
        return windingCountImpliesContainment(count, using: rule)
    }

    #if os(WASI)
        public func contains(_ other: Path, using rule: PathFillRule = .winding, accuracy: CGFloat = BezierKit.defaultIntersectionAccuracy) -> Bool {
            return _contains(other, using: rule, accuracy: accuracy)
        }
    #else
        @objc(containsPath:usingRule:accuracy:) public func contains(_ other: Path, using rule: PathFillRule = .winding, accuracy: CGFloat = BezierKit.defaultIntersectionAccuracy) -> Bool {
            return _contains(other, using: rule, accuracy: accuracy)
        }
    #endif

    fileprivate func _contains(_ other: Path, using rule: PathFillRule = .winding, accuracy: CGFloat = BezierKit.defaultIntersectionAccuracy) -> Bool {
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

    #if os(WASI)
        public func offset(distance d: CGFloat) -> Path {
            return _offset(distance: d)
        }
    #else
        @objc(offsetWithDistance:) public func offset(distance d: CGFloat) -> Path {
            return _offset(distance: d)
        }
    #endif

    fileprivate func _offset(distance d: CGFloat) -> Path {
        return Path(components: self.components.compactMap {
            $0.offset(distance: d)
        })
    }

    #if os(WASI)
        public func disjointComponents() -> [Path] {
            return _disjointComponents()
        }
    #else
        @objc public func disjointComponents() -> [Path] {
            return _disjointComponents()
        }
    #endif

    fileprivate func _disjointComponents() -> [Path] {
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

    #if !os(WASI)
    public override var hash: Int {
        // override is needed because NSObject hashing is independent of Swift's Hashable
        return lock.sync {
            if let _hash = _hash { return _hash }
            var hasher = Hasher()
            for component in components {
                hasher.combine(component)
            }
            let h = hasher.finalize()
            _hash = h
            return h
        }
    }
    #endif
}

#if !os(WASI)
@objc(BezierKitPath) extension Path { }
#endif

#if canImport(CoreGraphics)
@objc extension Path: Transformable {
    public func copy(using t: CGAffineTransform) -> Self {
        return type(of: self).init(components: self.components.map { $0.copy(using: t)})
    }
}
#endif

#if os(WASI)
extension Path: Reversible {
    public func reversed() -> Self {
        return _reversed()
    }
}
#else
@objc extension Path: Reversible {
    public func reversed() -> Self {
        return _reversed()
    }
}
#endif

fileprivate extension Path {
    func _reversed() -> Self {
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
