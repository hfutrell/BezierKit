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

@objc(BezierKitPathFillRule) public enum PathFillRule: NSInteger {
    case winding = 0, evenOdd
}

internal func windingCountImpliesContainment(_ count: Int, using rule: PathFillRule) -> Bool {
    switch rule {
    case .winding:
        return count != 0
    case .evenOdd:
        return count % 2 != 0
    }
}

open class Path: NSObject, @unchecked Sendable {
    /// lock to make external accessing of lazy vars threadsafe
    private let lock = UnfairLock()

    #if canImport(CoreGraphics)
    public var cgPath: CGPath {
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

    public var isEmpty: Bool {
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

    public let components: [PathComponent]

    public func selfIntersects(accuracy: CGFloat = BezierKit.defaultIntersectionAccuracy) -> Bool {
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

    public func intersects(_ other: Path, accuracy: CGFloat = BezierKit.defaultIntersectionAccuracy) -> Bool {
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

    #if os(WASI) || os(Linux)
    public convenience override init() {
        self.init(components: [])
    }
    #else
    @objc public convenience override init() {
        self.init(components: [])
    }
    #endif

    required public init(components: [PathComponent]) {
        self.components = components
    }

    #if canImport(CoreGraphics)
    // swiftlint:disable:next function_body_length
    convenience public init(cgPath: CGPath) {
        guard !cgPath.isEmpty else {
            self.init(components: [])
            return
        }
        // Pass 1: count the exact number of points and orders needed.
        // The callback does only integer arithmetic — no arrays, no function calls —
        // so it can be compiled without callee-saved registers or a stack frame.
        //
        // componentIsEmpty tracks whether the next non-moveTo element would trigger
        // appendCurrentPointIfEmpty (i.e. we are at the implicit start of a new component).
        // This happens after closeSubpath and at the very beginning of the path.
        // componentHasOrder tracks whether the current component has emitted any order.
        // A component with points but no orders (e.g. an isolated moveTo) emits a single
        // forced 0-order in the fill pass; the count pass must reserve room for it.
        struct CountContext { var ptCount = 0; var ordCount = 0; var componentIsEmpty = true; var componentHasOrder = false }
        var counts = CountContext()
        func countApplier(_ raw: UnsafeMutableRawPointer?, _ element: UnsafePointer<CGPathElement>) {
            let ctx = raw!.assumingMemoryBound(to: CountContext.self)
            switch element.pointee.type {
            case .moveToPoint:
                // Close out the previous component: a non-empty component with no orders
                // costs one forced 0-order in the fill pass.
                if !ctx.pointee.componentIsEmpty && !ctx.pointee.componentHasOrder { ctx.pointee.ordCount += 1 }
                ctx.pointee.ptCount += 2           // start point + potential close endpoint
                ctx.pointee.componentIsEmpty = false
                ctx.pointee.componentHasOrder = false
            case .addCurveToPoint:
                if ctx.pointee.componentIsEmpty { ctx.pointee.ptCount += 1 }   // implicit start point
                ctx.pointee.ptCount += 3; ctx.pointee.ordCount += 1
                ctx.pointee.componentIsEmpty = false
                ctx.pointee.componentHasOrder = true
            case .addQuadCurveToPoint:
                if ctx.pointee.componentIsEmpty { ctx.pointee.ptCount += 1 }
                ctx.pointee.ptCount += 2; ctx.pointee.ordCount += 1
                ctx.pointee.componentIsEmpty = false
                ctx.pointee.componentHasOrder = true
            case .addLineToPoint:
                if ctx.pointee.componentIsEmpty { ctx.pointee.ptCount += 1 }
                ctx.pointee.ptCount += 1; ctx.pointee.ordCount += 1
                ctx.pointee.componentIsEmpty = false
                ctx.pointee.componentHasOrder = true
            case .closeSubpath:
                ctx.pointee.ordCount += 1
                ctx.pointee.componentIsEmpty = true   // next non-moveTo starts a new implicit component
                ctx.pointee.componentHasOrder = false
            @unknown default:
                fatalError("unexpected unknown path element type \(element.pointee.type)")
            }
        }
        withUnsafeMutablePointer(to: &counts) {
            cgPath.apply(info: $0, function: countApplier)
        }
        // Close out the final component (same forced-0-order rule as the fill pass).
        if !counts.componentIsEmpty && !counts.componentHasOrder { counts.ordCount += 1 }
        if counts.ordCount == 0 { counts.ordCount = 1 }     // isolated moveTo with no curves

        // Allocate exact-size raw buffers. The fill pass writes directly into these,
        // bypassing Swift array COW: no uniqueness checks, no capacity checks per element.
        let ptsBuf  = UnsafeMutablePointer<CGPoint>.allocate(capacity: counts.ptCount)
        let ordsBuf = UnsafeMutablePointer<Int>.allocate(capacity: counts.ordCount)
        defer { ptsBuf.deallocate(); ordsBuf.deallocate() }

        // Pass 2: fill. The hot path (addCurveToPoint) has zero function calls.
        struct FillContext {
            var ptsBuf: UnsafeMutablePointer<CGPoint>
            var ordsBuf: UnsafeMutablePointer<Int>
            var ptsCount = 0;  var ordsCount = 0
            var startPts = 0;  var startOrds = 0
            var currentPoint: CGPoint?
            var componentStartPoint: CGPoint?
            var components: [PathComponent] = []

            mutating func completeComponentIfNeededAndClearPointsAndOrders() {
                let n = ptsCount - startPts
                guard n > 0 else { return }
                var m = ordsCount - startOrds
                if m == 0 { ordsBuf[ordsCount] = 0; ordsCount += 1; m = 1 }
                components.append(PathComponent(
                    points: Array(UnsafeBufferPointer(start: ptsBuf + startPts, count: n)),
                    orders: Array(UnsafeBufferPointer(start: ordsBuf + startOrds, count: m))))
                startPts = ptsCount; startOrds = ordsCount
            }

            mutating func appendCurrentPointIfEmpty() {
                if ptsCount == startPts {
                    ptsBuf[ptsCount] = currentPoint!
                    ptsCount += 1
                }
            }
        }
        var context = FillContext(ptsBuf: ptsBuf, ordsBuf: ordsBuf)

        func applierFunction(_ raw: UnsafeMutableRawPointer?, _ element: UnsafePointer<CGPathElement>) {
            let ctx = raw!.assumingMemoryBound(to: FillContext.self)
            let points: UnsafeMutablePointer<CGPoint> = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                ctx.pointee.completeComponentIfNeededAndClearPointsAndOrders()
                ctx.pointee.componentStartPoint = points[0]
                ctx.pointee.ptsBuf[ctx.pointee.ptsCount] = points[0]
                ctx.pointee.ptsCount += 1
                ctx.pointee.currentPoint = points[0]
            case .addLineToPoint:
                ctx.pointee.appendCurrentPointIfEmpty()
                ctx.pointee.ordsBuf[ctx.pointee.ordsCount] = 1; ctx.pointee.ordsCount += 1
                ctx.pointee.ptsBuf[ctx.pointee.ptsCount] = points[0]; ctx.pointee.ptsCount += 1
                ctx.pointee.currentPoint = points[0]
            case .addQuadCurveToPoint:
                ctx.pointee.appendCurrentPointIfEmpty()
                ctx.pointee.ordsBuf[ctx.pointee.ordsCount] = 2; ctx.pointee.ordsCount += 1
                ctx.pointee.ptsBuf[ctx.pointee.ptsCount]     = points[0]
                ctx.pointee.ptsBuf[ctx.pointee.ptsCount + 1] = points[1]; ctx.pointee.ptsCount += 2
                ctx.pointee.currentPoint = points[1]
            case .addCurveToPoint:
                ctx.pointee.appendCurrentPointIfEmpty()
                ctx.pointee.ordsBuf[ctx.pointee.ordsCount] = 3; ctx.pointee.ordsCount += 1
                ctx.pointee.ptsBuf[ctx.pointee.ptsCount]     = points[0]
                ctx.pointee.ptsBuf[ctx.pointee.ptsCount + 1] = points[1]
                ctx.pointee.ptsBuf[ctx.pointee.ptsCount + 2] = points[2]; ctx.pointee.ptsCount += 3
                ctx.pointee.currentPoint = points[2]
            case .closeSubpath:
                if ctx.pointee.currentPoint != ctx.pointee.componentStartPoint {
                    ctx.pointee.ordsBuf[ctx.pointee.ordsCount] = 1; ctx.pointee.ordsCount += 1
                    ctx.pointee.ptsBuf[ctx.pointee.ptsCount] = ctx.pointee.componentStartPoint!
                    ctx.pointee.ptsCount += 1
                }
                ctx.pointee.completeComponentIfNeededAndClearPointsAndOrders()
                ctx.pointee.currentPoint = ctx.pointee.componentStartPoint
            @unknown default:
                fatalError("unexpected unknown path element type \(element.pointee.type)")
            }
        }
        withUnsafeMutablePointer(to: &context) {
            cgPath.apply(info: $0, function: applierFunction)
        }
        context.completeComponentIfNeededAndClearPointsAndOrders()
        assert(context.ptsCount  <= counts.ptCount,
               "Path(cgPath:) internal error: wrote \(context.ptsCount) points but allocated \(counts.ptCount)")
        assert(context.ordsCount <= counts.ordCount,
               "Path(cgPath:) internal error: wrote \(context.ordsCount) orders but allocated \(counts.ordCount)")
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

    public func contains(_ point: CGPoint, using rule: PathFillRule = .winding) -> Bool {
        let count = self.windingCount(point)
        return windingCountImpliesContainment(count, using: rule)
    }

    public func contains(_ other: Path, using rule: PathFillRule = .winding, accuracy: CGFloat = BezierKit.defaultIntersectionAccuracy) -> Bool {
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

    public func offset(distance d: CGFloat) -> Path {
        return Path(components: self.components.compactMap {
            $0.offset(distance: d)
        })
    }

    public func disjointComponents() -> [Path] {
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
}

#if !os(WASI)
extension Path: NSSecureCoding {}
#endif

extension Path: Transformable {
    public func copy(using t: CGAffineTransform) -> Self {
        return type(of: self).init(components: self.components.map { $0.copy(using: t)})
    }
}

extension Path: Reversible {
    public func reversed() -> Self {
        return type(of: self).init(components: self.components.map { $0.reversed() })
    }
}

public struct IndexedPathLocation: Equatable, Comparable, Sendable {
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

public struct PathIntersection: Equatable, Sendable {
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
