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
    
    private let offsets: [Int]
    internal let points: [CGPoint]
    internal let orders: [Int]
    
    public var curves: [BezierCurve] { // in most cases use element(at:)
        return (0..<elementCount).map {
            self.element(at: $0)
        }
    }
    
    internal lazy var bvh: BVH = BVH(boxes: (0..<self.elementCount).map { self.element(at: $0).boundingBox })
    
    public var elementCount: Int {
        return self.orders.count
    }
    
    public var startingPoint: CGPoint {
        return self.points[0]
    }
    
    public var endingPoint: CGPoint {
        return self.points.last!
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
        else {
            return line(at: index)
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
    
    internal init(points: [CGPoint], orders: [Int]) {
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
        
        self.points = curves.reduce([CGPoint]()) { result, value in
            var temp = result
            if temp.isEmpty {
                temp.append(contentsOf: value.points)
            }
            else {
                assert(temp.last! == value.startingPoint)
                temp.append(contentsOf: value.points[1...value.order])
            }
            return temp
        }
        
        self.orders = curves.map { $0.order }
        self.offsets = PathComponent.computeOffsets(from: self.orders)
    }
    
    public var length: CGFloat {
        return self.curves.reduce(0.0) { $0 + $1.length() }
    }
    
    public var boundingBox: BoundingBox {
        return self.bvh.boundingBox
    }
    
    internal var isClosed: Bool {
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
    
    public func pointIsWithinDistanceOfBoundary(point p: CGPoint, distance d: CGFloat) -> Bool {
        var found = false
        self.bvh.visit { node, _ in
            let boundingBox = node.boundingBox
            if boundingBox.upperBoundOfDistance(to: p) <= d {
                found = true
            }
            else if case let .leaf(elementIndex) = node.type {
                let curve = self.element(at: elementIndex)
                if distance(p, curve.project(point: p)) < d {
                    found = true
                }
            }
            return !found && node.boundingBox.lowerBoundOfDistance(to: p) <= d
        }
        return found
    }
    
    private static func intersectionBetween<U>(_ c1: U, _ i2: Int, _ p2: PathComponent, threshold: CGFloat) -> [Intersection] where U: BezierCurve {
        let order2 = p2.order(at: i2)
        if order2 == 1 {
            let c2 = p2.line(at: i2)
            return c1.intersects(line: c2)
        }
        if order2 == 2 {
            let c2 = p2.quadratic(at: i2)
            return c1.intersects(curve: c2, threshold: threshold)
        }
        else if order2 == 3 {
            let c2 = p2.cubic(at: i2)
            return c1.intersects(cubic: c2, threshold: threshold)
        }
        else {
            fatalError("unsupported")
        }
    }
    
    private static func intersectionsBetweenElements(_ i1: Int, _ i2: Int, _ p1: PathComponent, _ p2: PathComponent, threshold: CGFloat) -> [Intersection] {
        let order1 = p1.order(at: i1)
        if order1 == 1 {
            let c1 = p1.line(at: i1)
            return PathComponent.intersectionBetween(c1, i2, p2, threshold: threshold)
        }
        if order1 == 2 {
            let c1 = p1.quadratic(at: i1)
            return PathComponent.intersectionBetween(c1, i2, p2, threshold: threshold)
        }
        else if order1 == 3 {
            let c1 = p1.cubic(at: i1)
            return PathComponent.intersectionBetween(c1, i2, p2, threshold: threshold)
        }
        else {
            fatalError("unsupported")
        }
    }
    
    public func intersects(component other: PathComponent, threshold: CGFloat = BezierKit.defaultIntersectionThreshold) -> [PathComponentIntersection] {
        precondition(other !== self, "use intersects(threshold:) for self intersection testing.")
        var intersections: [PathComponentIntersection] = []
        self.bvh.intersects(node: other.bvh) { i1, i2 in
            let elementIntersections = PathComponent.intersectionsBetweenElements(i1, i2, self, other, threshold: threshold)
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
    
    private func neighborsIntersectOnlyTrivially(_ c1: BezierCurve, _ c2: BezierCurve) -> Bool {
        let boundingBox = c1.boundingBox
        guard boundingBox.intersection(c2.boundingBox).area == 0 else {
            return false
        }
        for i in 1..<c2.points.count {
            if boundingBox.contains(c2.points[i]) {
                return false
            }
        }
        return true
    }
    
    public func intersects(threshold: CGFloat = BezierKit.defaultIntersectionThreshold) -> [PathComponentIntersection] {
        var intersections: [PathComponentIntersection] = []
        self.bvh.intersects() { i1, i2 in
            var elementIntersections: [Intersection] = []
            // TODO: fix behavior for `crossingsRemoved` when there are self intersections at t=0 or t=1 and re-enable
            /*if i1 == i2 {
                // we are intersecting a path element against itself
                if let c = c1 as? CubicBezierCurve {
                    elementIntersections = c.intersects(threshold: threshold)
                }
            }
            else*/ if i1 < i2 {
                // we are intersecting two distinct path elements
                let c1 = self.element(at: i1)
                let c2 = self.element(at: i2)
                let areNeighbors = i1 == Utils.mod(i2-1, self.elementCount)
                if areNeighbors, neighborsIntersectOnlyTrivially(c1, c2) {
                    // optimize the very common case of element i intersecting i+1 at its endpoint
                    elementIntersections = []
                }
                else {
                    elementIntersections = c1.intersects(curve: c2, threshold: threshold).filter {
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
    
    // MARK: - NSCoding
    // (cannot be put in extension because init?(coder:) is a designated initializer)
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(self.orders)
        aCoder.encode(self.points)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        self.orders = aDecoder.decodeObject() as! [Int]
        self.points = aDecoder.decodeObject() as! [CGPoint]
        self.offsets = PathComponent.computeOffsets(from: self.orders)
    }
    
    // MARK: -
    
    override public func isEqual(_ object: Any?) -> Bool {
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
                let curve = self.element(at: elementIndex)
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
    
}

extension PathComponent: Transformable {
    public func copy(using t: CGAffineTransform) -> PathComponent {
        return PathComponent(points: self.points.map { $0.applying(t)}, orders: self.orders )
    }
}

extension PathComponent: Reversible {
    public func reversed() -> PathComponent {
        return PathComponent(points: self.points.reversed(), orders: self.orders.reversed())
    }
}

public struct IndexedPathComponentLocation {
    let elementIndex: Int
    let t: CGFloat
}

public struct PathComponentIntersection {
    let indexedComponentLocation1, indexedComponentLocation2: IndexedPathComponentLocation
}
