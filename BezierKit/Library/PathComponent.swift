//
//  PathComponent.swift
//  BezierKit
//
//  Created by Holmes Futrell on 11/23/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import CoreGraphics
import Foundation

@objc(BezierKitPathComponent) open class PathComponent: NSObject, Reversible, Transformable {

    private let offsets: [Int]
    public let points: [CGPoint]
    public let orders: [Int]
    /// lock to make external accessing of lazy vars threadsafe
    private let lock = UnfairLock()

    public var curves: [BezierCurve] { // in most cases use element(at:)
        return (0..<self.numberOfElements).map {
            self.element(at: $0)
        }
    }

    private lazy var _bvh: BoundingBoxHierarchy = BoundingBoxHierarchy(boxes: (0..<self.numberOfElements).map { self.element(at: $0).boundingBox })

    internal var bvh: BoundingBoxHierarchy {
        return self.lock.sync { self._bvh }
    }
    public var numberOfElements: Int {
        return self.orders.count
    }

    @objc public var startingPoint: CGPoint {
        return self.points[0]
    }

    @objc public var endingPoint: CGPoint {
        return self.points.last!
    }

    public var startingIndexedLocation: IndexedPathComponentLocation {
        return IndexedPathComponentLocation(elementIndex: 0, t: 0.0)
    }

    public var endingIndexedLocation: IndexedPathComponentLocation {
        return IndexedPathComponentLocation(elementIndex: self.numberOfElements-1, t: 1.0)
    }

    /// if the path component represents a single point
    public var isPoint: Bool {
        return self.points.count == 1
    }

    public func element(at index: Int) -> BezierCurve {
        assert(index >= 0 && index < self.numberOfElements)
        let order = self.orders[index]
        if order == 3 {
            return cubic(at: index)
        } else if order == 2 {
            return quadratic(at: index)
        } else if order == 1 {
            return line(at: index)
        } else {
            // TODO: add Point:BezierCurve
            // for now just return a degenerate line
            let p = self.points[self.offsets[index]]
            return LineSegment(p0: p, p1: p)
        }
    }

    public func startingPointForElement(at index: Int) -> CGPoint {
        return self.points[self.offsets[index]]
    }

    public func endingPointForElement(at index: Int) -> CGPoint {
        return self.points[self.offsets[index] + self.orders[index]]
    }

    internal func cubic(at index: Int) -> CubicCurve {
        assert(self.order(at: index) == 3)
        let offset = self.offsets[index]
        return self.points.withUnsafeBufferPointer { p in
            CubicCurve(p0: p[offset], p1: p[offset+1], p2: p[offset+2], p3: p[offset+3])
        }
    }

    internal func quadratic(at index: Int) -> QuadraticCurve {
        assert(self.order(at: index) == 2)
        let offset = self.offsets[index]
        return self.points.withUnsafeBufferPointer { p in
            return QuadraticCurve(p0: p[offset], p1: p[offset+1], p2: p[offset+2])
        }
    }

    internal func line(at index: Int) -> LineSegment {
        assert(self.order(at: index) == 1)
        let offset = self.offsets[index]
        return self.points.withUnsafeBufferPointer { p in
            return LineSegment(p0: p[offset], p1: p[offset+1])
        }
    }

    internal func order(at index: Int) -> Int {
        return self.orders[index]
    }

    internal func appendPath(to mutablePath: CGMutablePath) {
        mutablePath.move(to: self.startingPoint)
        for i in 0..<self.numberOfElements {
            let order = orders[i]
            let offset = offsets[i]
            if i == self.numberOfElements-1, self.isClosed, order == 1 {
                // special case: if the path ends in a line segment that goes back to the start just emit a closepath
                mutablePath.closeSubpath()
                break
            }
            switch order {
            case 0:
            break // do nothing: we already did the move(to:) at the top of the method
            case 1:
                mutablePath.addLine(to: points[offset+1])
            case 2:
                mutablePath.addQuadCurve(to: points[offset+2], control: points[offset+1])
            case 3:
                mutablePath.addCurve(to: points[offset+3], control1: points[offset+1], control2: points[offset+2])
            default:
                fatalError("CGPath does not support curve of order \(order)")
            }
        }
    }

    required public init(points: [CGPoint], orders: [Int]) {
        // TODO: I don't like that this constructor is exposed, but for certain performance critical things you need it
        self.points = points
        self.orders = orders
        let expectedPointsCount = orders.reduce(1) { result, value in
            return result + value
        }
        assert(points.count == expectedPointsCount)
        self.offsets = PathComponent.computeOffsets(from: self.orders)
    }

    convenience public init(curve: BezierCurve) {
        self.init(curves: [curve])
    }

    private static func computeOffsets(from orders: [Int]) -> [Int] {
        return [Int](unsafeUninitializedCapacity: orders.count) { buffer, initializedCount in
            var sum = 0
            buffer[0] = 0
            for i in 1..<orders.count {
                sum += orders[i-1]
                buffer[i] = sum
            }
            initializedCount = orders.count
        }
    }

    public init(curves: [BezierCurve]) {
        precondition(curves.isEmpty == false, "Path components are by definition non-empty.")

        self.orders = curves.map { $0.order }
        self.offsets = PathComponent.computeOffsets(from: self.orders)

        var temp: [CGPoint] = [curves.first!.startingPoint]
        temp.reserveCapacity(self.offsets.last! + self.orders.last! + 1)
        curves.forEach {
            assert($0.startingPoint == temp.last!, "curves are not contiguous.")
            temp += $0.points[1...]
        }
        self.points = temp
    }

    public var length: CGFloat {
        return self.curves.reduce(0.0) { $0 + $1.length() }
    }

    public var boundingBox: BoundingBox {
        return self.bvh.boundingBox
    }

    public var isClosed: Bool {
        return self.startingPoint == self.endingPoint
    }

    public func offset(distance d: CGFloat) -> PathComponent? {
        var offsetCurves = self.curves.reduce([]) {
            $0 + $1.offset(distance: d)
        }
        guard offsetCurves.isEmpty == false else { return nil }
        // force the set of curves to be contiguous
        for i in 0..<offsetCurves.count-1 {
            let start = offsetCurves[i+1].startingPoint
            let end = offsetCurves[i].endingPoint
            let average = Utils.lerp(0.5, start, end)
            offsetCurves[i].endingPoint = average
            offsetCurves[i+1].startingPoint = average
        }
        // we've touched everything but offsetCurves[0].startingPoint and offsetCurves[count-1].endingPoint
        // if we are a closed componenet, keep the offset component closed as well
        if self.isClosed {
            let start = offsetCurves[0].startingPoint
            let end = offsetCurves[offsetCurves.count-1].endingPoint
            let average = Utils.lerp(0.5, start, end)
            offsetCurves[0].startingPoint = average
            offsetCurves[offsetCurves.count-1].endingPoint = average
        }
        return PathComponent(curves: offsetCurves)
    }

    public func pointIsWithinDistanceOfBoundary(point p: CGPoint, distance d: CGFloat) -> Bool {
        var found = false
        self.bvh.visit { node, _ in
            let boundingBox = node.boundingBox
            if boundingBox.upperBoundOfDistance(to: p) <= d {
                found = true
            } else if case let .leaf(elementIndex) = node.type {
                let curve = self.element(at: elementIndex)
                if distance(p, curve.project(p).point) < d {
                    found = true
                }
            }
            return !found && node.boundingBox.lowerBoundOfDistance(to: p) <= d
        }
        return found
    }

    private static func intersectionBetween<U>(_ curve: U, _ i2: Int, _ p2: PathComponent, accuracy: CGFloat) -> [Intersection] where U: NonlinearBezierCurve {
        switch p2.order(at: i2) {
        case 0:
            return []
        case 1:
            return helperIntersectsCurveLine(curve, p2.line(at: i2))
        case 2:
            return helperIntersectsCurveCurve(Subcurve(curve: curve), Subcurve(curve: p2.quadratic(at: i2)), accuracy: accuracy)
        case 3:
            return helperIntersectsCurveCurve(Subcurve(curve: curve), Subcurve(curve: p2.cubic(at: i2)), accuracy: accuracy)
        default:
            fatalError("unsupported")
        }
    }

    private static func intersectionsBetweenElementAndLine(_ index: Int, _ line: LineSegment, _ component: PathComponent, reversed: Bool = false) -> [Intersection] {
        switch component.order(at: index) {
        case 0:
            return []
        case 1:
            let element = component.line(at: index)
            return reversed ? line.intersections(with: component.line(at: index)) : element.intersections(with: line)
        case 2:
            return helperIntersectsCurveLine(component.quadratic(at: index), line, reversed: reversed)
        case 3:
            return helperIntersectsCurveLine(component.cubic(at: index), line, reversed: reversed)
        default:
            fatalError("unsupported")
        }
    }

    private static func intersectionsBetweenElements(_ i1: Int, _ i2: Int, _ p1: PathComponent, _ p2: PathComponent, accuracy: CGFloat) -> [Intersection] {
        switch p1.order(at: i1) {
        case 0:
            return []
        case 1:
            return PathComponent.intersectionsBetweenElementAndLine(i2, p1.line(at: i1), p2, reversed: true)
        case 2:
            return PathComponent.intersectionBetween(p1.quadratic(at: i1), i2, p2, accuracy: accuracy)
        case 3:
            return PathComponent.intersectionBetween(p1.cubic(at: i1), i2, p2, accuracy: accuracy)
        default:
            fatalError("unsupported")
        }
    }

    public func intersections(with other: PathComponent, accuracy: CGFloat = BezierKit.defaultIntersectionAccuracy) -> [PathComponentIntersection] {
        var intersections: [PathComponentIntersection] = []
        let isClosed1 = self.isClosed
        let isClosed2 = other.isClosed
        self.bvh.enumerateIntersections(with: other.bvh) { i1, i2 in
            let elementIntersections = PathComponent.intersectionsBetweenElements(i1, i2, self, other, accuracy: accuracy)
            let pathComponentIntersections = elementIntersections.compactMap { (i: Intersection) -> PathComponentIntersection? in
                let i1 = IndexedPathComponentLocation(elementIndex: i1, t: i.t1)
                let i2 = IndexedPathComponentLocation(elementIndex: i2, t: i.t2)
                if i1.t == 0.0, (isClosed1 || i1.elementIndex > 0) {
                    // handle this intersection instead at i1.elementIndex-1 w/ t=1
                    return nil
                }
                if i2.t == 0.0, (isClosed2 || i2.elementIndex > 0) {
                    // handle this intersection instead at i2.elementIndex-1 w/ t=1
                    return nil
                }
                return PathComponentIntersection(indexedComponentLocation1: i1, indexedComponentLocation2: i2)
            }
            intersections += pathComponentIntersections
        }
        return intersections
    }

    private func neighborsIntersectOnlyTrivially(_ i1: Int, _ i2: Int) -> Bool {
        let b1 = self.bvh.boundingBox(forElementIndex: i1)
        let b2 = self.bvh.boundingBox(forElementIndex: i2)
        guard b1.intersection(b2).area == 0 else {
            return false
        }
        let numPoints = self.order(at: i2) + 1
        let offset = self.offsets[i2]
        for i in 1..<numPoints {
            if b1.contains(self.points[offset+i]) {
                return false
            }
        }
        return true
    }

    public func selfIntersections(accuracy: CGFloat = BezierKit.defaultIntersectionAccuracy) -> [PathComponentIntersection] {
        var intersections: [PathComponentIntersection] = []
        let isClosed = self.isClosed
        self.bvh.enumerateSelfIntersections { i1, i2 in
            var elementIntersections: [Intersection] = []
            if i1 == i2 {
                // we are intersecting a path element against itself (only possible with cubic or higher order)
                if self.order(at: i1) == 3 {
                    elementIntersections = self.cubic(at: i1).selfIntersections(accuracy: accuracy)
                }
            } else if i1 < i2 {
                // we are intersecting two distinct path elements
                let areNeighbors = (i1 == i2-1) || (isClosed && i1 == 0 && i2 == self.numberOfElements-1)
                if areNeighbors, neighborsIntersectOnlyTrivially(i1, i2) {
                    // optimize the very common case of element i intersecting i+1 at its endpoint
                    elementIntersections = []
                } else {
                    elementIntersections = PathComponent.intersectionsBetweenElements(i1, i2, self, self, accuracy: accuracy).filter {
                        if i1 == i2-1, $0.t1 == 1.0, $0.t2 == 0.0 {
                            return false // exclude intersections of i and i+1 at t=1
                        }
                        if i1 == 0, i2 == self.numberOfElements-1, $0.t1 == 0.0, $0.t2 == 1.0 {
                            assert(self.isClosed) // how else can that happen?
                            return false // exclude intersections of endpoint and startpoint
                        }
                        if $0.t1 == 0.0, (i1 > 0 || isClosed) {
                            // handle the intersections instead at i1-1, t=1
                            return false
                        }
                        if $0.t2 == 0.0 {
                            // handle the intersections instead at i2-1, t=1 (we know i2 > 0 because i2 > i1)
                            return false
                        }
                        return true
                    }
                }
            }
            intersections += elementIntersections.map {
                return PathComponentIntersection(indexedComponentLocation1: IndexedPathComponentLocation(elementIndex: i1, t: $0.t1),
                                                 indexedComponentLocation2: IndexedPathComponentLocation(elementIndex: i2, t: $0.t2))
            }
        }
        return intersections
    }

    // MARK: -

    override open func isEqual(_ object: Any?) -> Bool {
        // override is needed because NSObject implementation of isEqual(_:) uses pointer equality
        guard let otherPathComponent = object as? PathComponent else {
            return false
        }
        return self.orders == otherPathComponent.orders && self.points == otherPathComponent.points
    }

    // MARK: -

    public func point(at location: IndexedPathComponentLocation) -> CGPoint {
        return self.element(at: location.elementIndex).point(at: location.t)
    }

    public func contains(_ point: CGPoint, using rule: PathFillRule = .winding) -> Bool {
        let windingCount = self.windingCount(at: point)
        return windingCountImpliesContainment(windingCount, using: rule)
    }

    @objc(enumeratePointsIncludingControlPoints:usingBlock:) public func enumeratePoints(includeControlPoints: Bool, using block: (CGPoint) -> Void) {
        if includeControlPoints {
            for p in points {
                block(p)
            }
        } else {
            for o in self.offsets {
                block(points[o])
            }
            if points.count > 1 {
                block(points.last!)
            }
        }
    }

    open func split(standardizedRange range: PathComponentRange) -> Self {
        assert(range.isStandardized)

        guard !self.isPoint else { return self }

        let start = range.start
        let end   = range.end

        var resultPoints: [CGPoint] = []
        var resultOrders: [Int] = []

        func appendElement(_ index: Int, _ start: CGFloat, _ end: CGFloat, includeStart: Bool, includeEnd: Bool) {
            assert(includeStart || includeEnd)
            let element = self.element(at: index).split(from: start, to: end)
            let startIndex  = includeStart ? 0 : 1
            let endIndex    = includeEnd ? element.order : element.order - 1
            resultPoints    += element.points[startIndex...endIndex]
            resultOrders.append(self.orders[index])
        }

        if start.elementIndex == end.elementIndex {
            // we just need to go from start.t to end.t
            appendElement(start.elementIndex, start.t, end.t, includeStart: true, includeEnd: true)
        } else {
            // if end.t = 1, append from start.elementIndex+1 through end.elementIndex, otherwise to end.elementIndex
            let lastFullElementIndex = end.t != 1.0 ? (end.elementIndex-1) : end.elementIndex
            let firstFullElementIndex = start.t != 0.0 ? (start.elementIndex+1) : start.elementIndex
            // if needed, append start.elementIndex from t=start.t to t=1
            if firstFullElementIndex != start.elementIndex {
                appendElement(start.elementIndex, start.t, 1.0, includeStart: true, includeEnd: false)
            }
            // if there exist full elements to copy, use the fast path to get them all in one fell swoop
            let hasFullElements = firstFullElementIndex <= lastFullElementIndex
            if hasFullElements {
                resultPoints        += self.points[self.offsets[firstFullElementIndex] ... self.offsets[lastFullElementIndex] + self.orders[lastFullElementIndex]]
                resultOrders        += self.orders[firstFullElementIndex ... lastFullElementIndex]
            }
            // if needed, append from end.elementIndex from t=0, to t=end.t
            if lastFullElementIndex != end.elementIndex {
                appendElement(end.elementIndex, 0.0, end.t, includeStart: !hasFullElements, includeEnd: true)
            }
        }
        return type(of: self).init(points: resultPoints, orders: resultOrders)
    }

    public func split(range: PathComponentRange) -> Self {
        let reverse = range.end < range.start
        let result = self.split(standardizedRange: range.standardized)
        return reverse ? result.reversed() : result
    }

    public func split(from start: IndexedPathComponentLocation, to end: IndexedPathComponentLocation) -> Self {
        return self.split(range: PathComponentRange(start: start, end: end))
    }

    open func reversed() -> Self {
        return type(of: self).init(points: self.points.reversed(), orders: self.orders.reversed())
    }

    open func copy(using t: CGAffineTransform) -> Self {
        return type(of: self).init(points: self.points.map { $0.applying(t) }, orders: self.orders )
    }
}

public struct IndexedPathComponentLocation: Equatable, Comparable {
    public let elementIndex: Int
    public let t: CGFloat
    public init(elementIndex: Int, t: CGFloat) {
        self.elementIndex = elementIndex
        self.t = t
    }
    public static func < (lhs: IndexedPathComponentLocation, rhs: IndexedPathComponentLocation) -> Bool {
        if lhs.elementIndex < rhs.elementIndex {
            return true
        } else if lhs.elementIndex > rhs.elementIndex {
            return false
        }
        return lhs.t < rhs.t
    }
}

public struct PathComponentIntersection {
    let indexedComponentLocation1, indexedComponentLocation2: IndexedPathComponentLocation
}

public struct PathComponentRange: Equatable {
    public let start: IndexedPathComponentLocation
    public let end: IndexedPathComponentLocation
    var isStandardized: Bool {
        return self == self.standardized
    }
    /// the range standardized so that end >= start and adjusted to avoid possible degeneracies when splitting components
    public var standardized: PathComponentRange {
        var start = self.start
        var end = self.end
        if end < start {
            swap(&start, &end)
        }
        if start.elementIndex < end.elementIndex {
            if start.t == 1.0 {
                let candidate = IndexedPathComponentLocation(elementIndex: start.elementIndex+1, t: 0.0)
                if candidate <= end {
                    start = candidate
                }
            }
            if end.t == 0.0 {
                let candidate = IndexedPathComponentLocation(elementIndex: end.elementIndex-1, t: 1.0)
                if candidate >= start {
                    end = candidate
                }
            }
        }
        return PathComponentRange(start: start, end: end)
    }
}
