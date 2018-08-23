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
    
    internal init(curves: [BezierCurve]) {
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
    
    public func intersects(_ other: PathComponent, threshold: CGFloat = BezierKit.defaultIntersectionThreshold) -> [PathComponentIntersection] {
        var intersections: [PathComponentIntersection] = []
        self.bvh.intersects(node: other.bvh) { o1, o2, i1, i2 in
            let c1 = o1 as! BezierCurve
            let c2 = o2 as! BezierCurve
            let elementIntersections = c1.intersects(curve: c2, threshold: threshold)
            let pathComponentIntersections = elementIntersections.map { (i: Intersection) -> PathComponentIntersection in
                let i1 = IndexedPathComponentLocation(elementIndex: i1, t: i.t1)
                let i2 = IndexedPathComponentLocation(elementIndex: i2, t: i.t2)
                return PathComponentIntersection(indexedComponentLocation1: i1, indexedComponentLocation2: i2)
            }
            intersections += pathComponentIntersections
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
                results += curve.intersects(line: line).map {
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

public enum VertexTransition {
    case line
    case quadCurve(control: CGPoint)
    case curve(control1: CGPoint, control2: CGPoint)
    init(curve: BezierCurve) {
        switch curve {
        case is LineSegment:
            self = .line
        case let quadCurve as QuadraticBezierCurve:
            self = .quadCurve(control: quadCurve.p1)
        case let cubicCurve as CubicBezierCurve:
            self = .curve(control1: cubicCurve.p1, control2: cubicCurve.p2)
        default:
            fatalError("Vertex does not support curve type (\(type(of: curve))")
        }
    }
}

public class Vertex {
    public let location: CGPoint
    public let isIntersection: Bool
    // pointers must be set after initialization
    
    public struct IntersectionInfo {
        public var isEntry: Bool = false
        public var isExit: Bool = false
        public var neighbor: Vertex? = nil
    }
    public var intersectionInfo: IntersectionInfo = IntersectionInfo()
    
    internal struct SplitInfo {
        var t: CGFloat
    }
    internal var splitInfo: SplitInfo? = nil // non-nil only when vertex is inserted by splitting an element
    
    public private(set) var next: Vertex! = nil
    public private(set) weak var previous: Vertex! = nil
    public private(set) var nextTransition: VertexTransition! = nil
    public private(set) var previousTransition: VertexTransition! = nil
    
    public func setNextVertex(_ vertex: Vertex, transition: VertexTransition) {
        self.next = vertex
        self.nextTransition = transition
    }
    
    public func setPreviousVertex(_ vertex: Vertex, transition: VertexTransition) {
        self.previous = vertex
        self.previousTransition = transition
    }

    init(location: CGPoint, isIntersection: Bool) {
        self.location = location
        self.isIntersection = isIntersection
    }
    
    internal func emitTo(_ end: CGPoint, using transition: VertexTransition) -> BezierCurve {
        switch transition {
        case .line:
            return LineSegment(p0: self.location, p1: end)
        case .quadCurve(let c):
            return QuadraticBezierCurve(p0: self.location, p1: c, p2: end)
        case .curve(let c1, let c2):
            return CubicBezierCurve(p0: self.location, p1: c1, p2: c2, p3: end)
        }
    }
    
    public func emitNext() -> BezierCurve {
        return self.emitTo(next.location, using: nextTransition)
    }
    
    public func emitPrevious() -> BezierCurve {
        return self.emitTo(previous.location, using: previousTransition)
    }
}

extension PathComponent {
    func linkedListRepresentation() -> [Vertex] {
        guard self.curves.count > 0 else {
            return []
        }
        assert(self.curves.first!.startingPoint == self.curves.last!.endingPoint, "this method assumes component is closed!")
        var elements: [Vertex] = [] // elements[i] is the first vertex of curves[i]
        let firstPoint: CGPoint = self.curves.first!.startingPoint
        let firstVertex = Vertex(location: firstPoint, isIntersection: false)
        elements.append(firstVertex)
        var lastVertex = firstVertex
        for i in 1..<self.curves.count {
            let v = Vertex(location: self.curves[i].startingPoint, isIntersection: false)
            elements.append(v)
            let curveForTransition = self.curves[i-1]
            // set the forwards reference for starting vertex of curve i-1
            lastVertex.setNextVertex(v, transition: VertexTransition(curve: curveForTransition))
            // set the backwards reference for starting vertex of curve i
            v.setPreviousVertex(lastVertex, transition: VertexTransition(curve: curveForTransition.reversed()))
            // point previous at v for the next iteration
            lastVertex = v
        }
        // connect the forward reference of the last vertex to the first vertex
        let lastCurve = self.curves.last!
        lastVertex.setNextVertex(firstVertex, transition: VertexTransition(curve: lastCurve))
        // connect the backward reference of the first vertex to the last vertex
        firstVertex.setPreviousVertex(lastVertex, transition: VertexTransition(curve: lastCurve.reversed()))
        // return list of vertexes that point to the start of each element
        return elements
    }
}

public class AugmentedGraph {

    func connectNeighbors(_ vertex1: Vertex, _ vertex2: Vertex) {
        vertex1.intersectionInfo.neighbor = vertex2
        vertex2.intersectionInfo.neighbor = vertex1
    }

    private var list1: [Vertex]
    private var list2: [Vertex]
    
    public var v1: Vertex {
        return list1.first!
    }
    public var v2: Vertex {
        return list2.first!
    }
    
    private func insertIntersectionVertex(_ v: Vertex, inList list: inout [Vertex], for component: PathComponent, at location: IndexedPathComponentLocation) {
   
        func insertIntersectionVertex(_ v: Vertex, replacingVertexAtStartOfElementIndex elementIndex: Int, inList list: inout [Vertex]) {
            assert(v.isIntersection)
            let r = list[elementIndex]
            // insert v in the list
            v.setPreviousVertex(r.previous, transition: r.previousTransition)
            v.setNextVertex(r.next, transition: r.nextTransition)
            v.previous.setNextVertex(v, transition: v.previous.nextTransition)
            v.next.setPreviousVertex(v, transition: v.next.previousTransition)
            // replace the list pointer with v
            list[elementIndex] = v
        }
        func insertIntersectionVertex(_ v: Vertex, between start: Vertex, and end: Vertex, at t: CGFloat, for element: BezierCurve) {
            assert(start !== end)
            assert(v.isIntersection)
            v.splitInfo = Vertex.SplitInfo(t: t)
            let t0: CGFloat = (start.splitInfo != nil) ? start.splitInfo!.t : 0.0
            let t1: CGFloat = (end.splitInfo != nil) ? end.splitInfo!.t : 1.0
            // locate the element for the vertex transitions
            let element1 = element.split(from: t0, to: t)
            let element2 = element.split(from: t, to: t1)
            // insert the vertex into the linked list
            v.setPreviousVertex(start, transition: VertexTransition(curve: element1.reversed()))
            v.setNextVertex(end, transition: VertexTransition(curve: element2))
            start.setNextVertex(v, transition: VertexTransition(curve: element1))
            end.setPreviousVertex(v, transition: VertexTransition(curve: element2.reversed()))
        }
        
        assert(v.isIntersection)
        if location.t == 0 {
            // this vertex needs to replace the start vertex of the element
            insertIntersectionVertex(v, replacingVertexAtStartOfElementIndex: location.elementIndex, inList: &list)
        }
        else if location.t == 1 {
            // this vertex needs to replace the end vertex of the element
            insertIntersectionVertex(v, replacingVertexAtStartOfElementIndex: location.elementIndex+1, inList: &list)
        }
        else {
            var start = list[location.elementIndex]
            while ((start.next.splitInfo != nil) && start.next.splitInfo!.t < location.t) {
                start = start.next
            }
            var end = start.next!
            while (end.splitInfo != nil) && end.splitInfo!.t < location.t {
                print("found t = \(end.splitInfo!.t)")
                assert(end !== list[location.elementIndex+1])
                end = end.next
            }
            print("bleh")
            insertIntersectionVertex(v, between: start, and: end, at: location.t, for: component.curves[location.elementIndex])
        }
        
    }

    public init(component1: PathComponent, component2: PathComponent, intersections: [PathComponentIntersection]) {
    
        func markEntryExit(_ v: Vertex, _ component: PathComponent) {
            var current = v
            repeat {
                if current.isIntersection {
                    let previous = current.emitPrevious()
                    let next = current.emitNext()
                    let wasInside = component.contains(previous.compute(0.5))
                    let willBeInside = component.contains(next.compute(0.5))
                    current.intersectionInfo.isEntry = !wasInside && willBeInside
                    current.intersectionInfo.isExit = wasInside && !willBeInside
                }
                current = current.next
            }
            while current !== v
        }
        
        func intersectionVertexForComponent(_ component: PathComponent, at l: IndexedPathComponentLocation) -> Vertex {
            let v = Vertex(location: component.point(at: l), isIntersection: true)
            return v
        }

        print("intersection count = \(intersections.count)")

        self.list1 = component1.linkedListRepresentation()
        self.list2 = component2.linkedListRepresentation()
        intersections.forEach {
            let vertex1 = intersectionVertexForComponent(component1, at: $0.indexedComponentLocation1)
            let vertex2 = intersectionVertexForComponent(component2, at: $0.indexedComponentLocation2)
            connectNeighbors(vertex1, vertex2) // sets the vertex crossing neighbor pointer
            self.insertIntersectionVertex(vertex1, inList: &list1, for: component1, at: $0.indexedComponentLocation1)
            self.insertIntersectionVertex(vertex2, inList: &list2, for: component2, at: $0.indexedComponentLocation2)
        }
        // mark each intersection as either entry or exit
        markEntryExit(self.v1, component2)
        markEntryExit(self.v2, component1)
    }
}
