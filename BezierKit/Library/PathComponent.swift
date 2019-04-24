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

@objc(BezierKitPathComponent) open class PathComponent: NSObject, Reversible, Transformable {
    
    private let offsets: [Int]
    public let points: [CGPoint]
    public let orders: [Int]
    
    public var curves: [BezierCurve] { // in most cases use element(at:)
        return (0..<elementCount).map {
            self.element(at: $0)
        }
    }
    
    internal lazy var bvh: BVH = BVH(boxes: (0..<self.elementCount).map { self.element(at: $0).boundingBox })
    
    public var elementCount: Int {
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
        return IndexedPathComponentLocation(elementIndex: self.elementCount-1, t: 1.0)
    }

    /// if the path component represents a single point
    public var isPoint: Bool {
        return self.points.count == 1
    }

    public func element(at index: Int) -> BezierCurve {
        assert(index >= 0 && index < self.elementCount)
        let order = self.orders[index]
        if order == 3 {
            return cubic(at: index)
        }
        else if order == 2 {
            return quadratic(at: index)
        }
        else if order == 1 {
            return line(at: index)
        }
        else {
            // TODO: add Point:BezierCurve
            // for now just return a degenerate line
            let p = self.points[self.offsets[index]]
            return LineSegment(p0: p, p1: p)
        }
    }
    
    internal func cubic(at index: Int) -> CubicBezierCurve {
        assert(self.order(at: index) == 3)
        let offset = self.offsets[index]
        return self.points.withUnsafeBufferPointer { p in
            CubicBezierCurve(p0: p[offset], p1: p[offset+1], p2: p[offset+2], p3: p[offset+3])
        }
    }
    
    internal func quadratic(at index: Int) -> QuadraticBezierCurve {
        assert(self.order(at: index) == 2)
        let offset = self.offsets[index]
        return self.points.withUnsafeBufferPointer { p in
            return QuadraticBezierCurve(p0: p[offset], p1: p[offset+1], p2: p[offset+2])
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
    
    public lazy var cgPath: CGPath = {
        let mutablePath = CGMutablePath()
        mutablePath.move(to: self.startingPoint)
        for i in 0..<self.elementCount {
            let order = orders[i]
            let offset = offsets[i]
            if i == self.elementCount-1, self.isClosed, order == 1 {
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
        return mutablePath.copy()!
    }()
    
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
    
    private static func computeOffsets(from orders: [Int]) -> [Int] {
        var offsets = [Int]()
        offsets.reserveCapacity(orders.count)
        var sum = 0
        offsets.append(sum)
        for i in 1..<orders.count {
            sum += orders[i-1]
            offsets.append(sum)
        }
        return offsets
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
    
    public func offset(distance d: CGFloat) -> PathComponent {
        var offsetCurves = self.curves.reduce([]) {
            $0 + $1.offset(distance: d)
        }
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
    
    public func pointIsWithinDistanceOfBoundary(point p: CGPoint, distance d: CGFloat, errorThreshold: CGFloat = BezierKit.defaultIntersectionAccuracy) -> Bool {
        var found = false
        self.bvh.visit { node, _ in
            let boundingBox = node.boundingBox
            if boundingBox.upperBoundOfDistance(to: p) <= d {
                found = true
            }
            else if case let .leaf(elementIndex) = node.type {
                let curve = self.element(at: elementIndex)
                if distance(p, curve.project(point: p, errorThreshold: errorThreshold)) < d {
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
        precondition(other !== self, "use selfIntersections(accuracy:) for self intersection testing.")
        var intersections: [PathComponentIntersection] = []
        self.bvh.enumerateIntersections(with: other.bvh) { i1, i2 in
            let elementIntersections = PathComponent.intersectionsBetweenElements(i1, i2, self, other, accuracy: accuracy)
            let pathComponentIntersections = elementIntersections.compactMap { (i: Intersection) -> PathComponentIntersection? in
                let i1 = IndexedPathComponentLocation(elementIndex: i1, t: i.t1)
                let i2 = IndexedPathComponentLocation(elementIndex: i2, t: i.t2)
                guard i1.t != 0.0 && i2.t != 0.0 else {
                    // we'll get this intersection at t=1 on the neighboring path element(s) instead
                    // TODO: in some cases 'see: testContainsEdgeCaseParallelDerivative it's possible to get an intersection at t=0 without an intersection at t=1 of the previous element
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
        self.bvh.enumerateSelfIntersections() { i1, i2 in
            var elementIntersections: [Intersection] = []
            // TODO: fix behavior for `crossingsRemoved` when there are self intersections at t=0 or t=1 and re-enable
            /*if i1 == i2 {
                // we are intersecting a path element against itself
                if let c = c1 as? CubicBezierCurve {
                    elementIntersections = c.selfIntersections(accuracy: accuracy)
                }
            }
            else*/ if i1 < i2 {
                // we are intersecting two distinct path elements
                let areNeighbors = i1 == Utils.mod(i2-1, self.elementCount)
                if areNeighbors, neighborsIntersectOnlyTrivially(i1, i2) {
                    // optimize the very common case of element i intersecting i+1 at its endpoint
                    elementIntersections = []
                }
                else {
                    elementIntersections = PathComponent.intersectionsBetweenElements(i1, i2, self, self, accuracy: accuracy).filter {
                        if areNeighbors, $0.t1 == 1.0 {
                            return false // exclude intersections of i and i+1 at t=1
                        }
                        if $0.t1 == 0.0 || $0.t2 == 0.0 {
                            // use the intersection with the prior path element at t=1 instead
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
    
    internal func intersects(line: LineSegment) -> [IndexedPathComponentLocation] {
        let lineBoundingBox = line.boundingBox
        var results: [IndexedPathComponentLocation] = []
        self.bvh.visit { node, _ in
            if case let .leaf(elementIndex) = node.type {
                results += PathComponent.intersectionsBetweenElementAndLine(elementIndex, line, self).map {
                    IndexedPathComponentLocation(elementIndex: elementIndex, t: $0.t1)
                }
            }
            // TODO: better line box intersection
            return node.boundingBox.overlaps(lineBoundingBox)
        }
        return results
    }

    public func point(at location: IndexedPathComponentLocation) -> CGPoint {
        return self.element(at: location.elementIndex).compute(location.t)
    }
    
    internal func windingCount(at point: CGPoint) -> Int {
        guard self.isClosed, self.boundingBox.contains(point) else {
            return 0
        }
        // TODO: assumes element.normal() is always defined, which unfortunately it's not (eg degenerate curves as points, cusps, zero derivatives at the end of curves)
        let line = LineSegment(p0: point, p1: CGPoint(x: self.boundingBox.min.x - self.boundingBox.size.x, y: point.y)) // horizontal line from point out of bounding box
        let delta = (line.p0 - line.p1).normalize()
        let intersections = self.intersects(line: line)
        var windingCount = 0
        intersections.forEach {
            let element = self.element(at: $0.elementIndex)
            let t = $0.t
            assert(element.derivative($0.t).length > 1.0e-3, "possible NaN normal vector. Possible data for unit test?")
            let dotProduct = Double(delta.dot(element.normal(t)))
            if dotProduct < -Utils.epsilon {
                if t != 0 {
                    windingCount -= 1
                }
            }
            else if dotProduct > Utils.epsilon {
                if t != 1 {
                    windingCount += 1
                }
            }
        }
        return windingCount
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

    open func split(from start: IndexedPathComponentLocation, to end: IndexedPathComponentLocation) -> Self {
        guard end >= start else { return self.split(from: end, to: start).reversed() }
        guard self.points.count > 1 else { return self }
        guard start != self.startingIndexedLocation || end != self.endingIndexedLocation else { return self }
        guard end.t != 0.0 || end.elementIndex == start.elementIndex else {
            // avoids degenerate (zero length) curve at end of component
            return self.split(from: start, to: IndexedPathComponentLocation(elementIndex: end.elementIndex-1, t: 1.0))
        }
        guard start.t != 1.0 || start.elementIndex == end.elementIndex else {
            // avoids degenerate (zero length) curve at start of component
            return self.split(from: IndexedPathComponentLocation(elementIndex: start.elementIndex+1, t: 0.0), to: end)
        }

        var resultPoints = [CGPoint]()
        var resultOrders = [Int]()

        func appendElement(_ index: Int, _ start: CGFloat, _ end: CGFloat, includeStart: Bool, includeEnd: Bool) {
            let element = self.element(at: index).split(from: start, to: end)
            assert(includeStart || includeEnd)
            if !includeStart {
                resultPoints += element.points[1...element.order]
            } else if !includeEnd {
                resultPoints += element.points[0..<element.order]
            } else {
                resultPoints += element.points[0...element.order]
            }
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
