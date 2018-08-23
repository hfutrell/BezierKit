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
    
    public func point(at location: IndexedPathComponentLocation) -> CGPoint {
        return self.curves[location.elementIndex].compute(location.t)
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

enum VertexTransition {
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

internal class Vertex {
    let location: CGPoint
    let isIntersection: Bool
    // pointers must be set after initialization
    
    struct IntersectionInfo {
        var entryExit: Bool = false
        var neighbor: Vertex? = nil
        var t: CGFloat = 0.0 // called alpha in the paper
    }
    var intersectionInfo: IntersectionInfo = IntersectionInfo()
    
    private(set) var next: Vertex! = nil
    private(set) weak var previous: Vertex! = nil
    private(set) var nextTransition: VertexTransition! = nil
    private(set) var previousTransition: VertexTransition! = nil
    
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
            elements[i] = v
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

internal class AugmentedGraph {

    func connectNeighbors(_ vertex1: Vertex, _ vertex2: Vertex) {
        vertex1.intersectionInfo.neighbor = vertex2
        vertex2.intersectionInfo.neighbor = vertex1
    }

    private var list1: [Vertex]
    private var list2: [Vertex]
    
    internal var v1: Vertex {
        return list1.first!
    }
    internal var v2: Vertex {
        return list2.first!
    }
    
    private func intersectionVertexForComponent(_ component: PathComponent, at l: IndexedPathComponentLocation) -> Vertex {
        let v = Vertex(location: component.point(at: l), isIntersection: true)
        v.intersectionInfo.t = l.t
        return v
    }
    
    private func insertIntersectionVertex(_ v: Vertex, between start: Vertex, and end: Vertex, for element: BezierCurve) {
        assert(start !== end)
        assert(v.isIntersection)
        let t0 = start.isIntersection ? start.intersectionInfo.t : 0.0
        let t1 = end.isIntersection ? end.intersectionInfo.t : 1.0
        let t = v.intersectionInfo.t
        // locate the element for the vertex transitions
        let element1 = element.split(from: t0, to: t)
        let element2 = element.split(from: t, to: t1)
        // insert the vertex into the linked list
        v.setPreviousVertex(start, transition: VertexTransition(curve: element1.reversed()))
        v.setNextVertex(end, transition: VertexTransition(curve: element2))
        start.setNextVertex(v, transition: VertexTransition(curve: element1))
        end.setPreviousVertex(v, transition: VertexTransition(curve: element2.reversed()))
    }
    
    private func insertIntersectionVertex(_ v: Vertex, replacingVertexAtStartOfElementIndex elementIndex: Int, inList list: inout [Vertex]) {
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
    
    private func insertIntersectionVertex(_ v: Vertex, inList list: inout [Vertex], for component: PathComponent, at location: IndexedPathComponentLocation) {
        if location.t == 0 {
            // this vertex needs to replace the start vertex of the element
            self.insertIntersectionVertex(v, replacingVertexAtStartOfElementIndex: location.elementIndex, inList: &list)
        }
        else if location.t == 1 {
            // this vertex needs to replace the end vertex of the element
            self.insertIntersectionVertex(v, replacingVertexAtStartOfElementIndex: location.elementIndex+1, inList: &list)
        }
        else {
            let start = list[location.elementIndex]
            var end = start.next!
            while end.isIntersection && end.intersectionInfo.t < location.t {
                end = end.next
            }
            // find the last vertex representing t < location.t
            // this is either the start of the element, or an intersection
            self.insertIntersectionVertex(v, between: start, and: end, for: component.curves[location.elementIndex])
        }
    }

    internal init(component1: PathComponent, component2: PathComponent, intersections: [PathComponentIntersection]) {
        self.list1 = component1.linkedListRepresentation()
        self.list2 = component1.linkedListRepresentation()
        intersections.forEach {
            let vertex1 = intersectionVertexForComponent(component1, at: $0.indexedComponentLocation1)
            let vertex2 = intersectionVertexForComponent(component2, at: $0.indexedComponentLocation2)
            connectNeighbors(vertex1, vertex2) // sets the vertex crossing neighbor pointer
            self.insertIntersectionVertex(vertex1, inList: &list1, for: component1, at: $0.indexedComponentLocation1)
            self.insertIntersectionVertex(vertex2, inList: &list2, for: component2, at: $0.indexedComponentLocation2)
        }
    }
}
