//
//  AugmentedGraph.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/28/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import CoreGraphics

internal class PathLinkedListRepresentation {

    private var lists: [[Vertex]] = []
    private let path: Path

    private func insertIntersectionVertex(_ v: Vertex, replacingVertexAtStartOfElementIndex elementIndex: Int, inList list: inout [Vertex]) {
        assert(v.isIntersection)
        let r = list[elementIndex]
        // insert v in the list
        if let neighbor = r.intersectionInfo?.neighbor {
            neighbor.intersectionInfo?.neighbor = nil
        }
        v.setPreviousVertex(r.previous)
        v.setNextVertex(r.next, transition: r.nextTransition)
        v.previous.setNextVertex(v, transition: v.previous.nextTransition)
        v.next.setPreviousVertex(v)
        // replace the list pointer with v
        list[elementIndex] = v
    }

    private func insertIntersectionVertex(_ v: Vertex, between start: Vertex, and end: Vertex, at t: CGFloat, for element: BezierCurve) {
        assert(start !== end)
        assert(v.isIntersection)
        v.intersectionInfo?.splitT = t
        let t0: CGFloat = start.intersectionInfo?.splitT ?? 0.0
        let t1: CGFloat = end.intersectionInfo?.splitT ?? 1.0
        // locate the element for the vertex transitions
        /*
         TODO: this code assumes t0 < t < t1, which could definitely be false if there are multiple intersections against the same element at the same point
         in the least we need a unit test for that case
         */
        let element1 = element.split(from: t0, to: t)
        let element2 = element.split(from: t, to: t1)
        // insert the vertex into the linked list
        v.setPreviousVertex(start)
        v.setNextVertex(end, transition: VertexTransition(curve: element2))
        start.setNextVertex(v, transition: VertexTransition(curve: element1))
        end.setPreviousVertex(v)
    }

    internal func insertIntersectionVertex(_ v: Vertex, at location: IndexedPathLocation) {

        assert(v.isIntersection)

        var list = self.lists[location.componentIndex]

        assert(location.t != 0, "intersects are assumed pre-processed to have a t=1 intersection at the previous path element instead!")

        if location.t == 1 {
            // this vertex needs to replace the end vertex of the element
            insertIntersectionVertex(v, replacingVertexAtStartOfElementIndex: Utils.mod(location.elementIndex+1, list.count), inList: &list)
        } else {
            var start = list[location.elementIndex]
            while let split = start.next.intersectionInfo?.splitT, split < location.t {
                start = start.next
            }
            var end = start.next!
            while let split = end.intersectionInfo?.splitT, split < location.t {
                assert(end !== list[location.elementIndex+1])
                end = end.next
            }
            insertIntersectionVertex(v, between: start, and: end, at: location.t, for: path.elementAtComponentIndex(location.componentIndex, elementIndex: location.elementIndex))
        }
        self.lists[location.componentIndex] = list
    }

    private func createListFor(component: PathComponent) -> [Vertex] {
        assert(component.startingPoint == component.endingPoint, "this method assumes component is closed!")
        var elements: [Vertex] = [] // elements[i] is the first vertex of curves[i]
        let firstPoint: CGPoint = component.startingPoint
        let firstVertex = Vertex(location: firstPoint, isIntersection: false)
        elements.append(firstVertex)
        var lastVertex = firstVertex
        var prev: BezierCurve = component.element(at: 0)
        for i in 1..<component.elementCount {
            let curr = component.element(at: i)
            let v = Vertex(location: curr.startingPoint, isIntersection: false)
            elements.append(v)
            let curveForTransition = prev
            // set the forwards reference for starting vertex of curve i-1
            lastVertex.setNextVertex(v, transition: VertexTransition(curve: curveForTransition))
            // set the backwards reference for starting vertex of curve i
            v.setPreviousVertex(lastVertex)
            // point previous at v for the next iteration
            lastVertex = v
            prev = curr
        }
        // connect the forward reference of the last vertex to the first vertex
        lastVertex.setNextVertex(firstVertex, transition: VertexTransition(curve: prev))
        // connect the backward reference of the first vertex to the last vertex
        firstVertex.setPreviousVertex(lastVertex)
        // return list of vertexes that point to the start of each element
        return elements
    }

    init(_ p: Path) {
        self.path = p
        self.lists = p.components.map { self.createListFor(component: $0) }
    }

    fileprivate var coincidentComponents: [PathComponent] {
        return self.componentsWhereAllVerticesSatisfy { $0.forwardEdge == .coincident }
    }

    fileprivate var internalComponents: [PathComponent] {
        return self.componentsWhereAllVerticesSatisfy { $0.forwardEdge == .internal }
    }

    fileprivate var externalComponents: [PathComponent] {
        return self.componentsWhereAllVerticesSatisfy { $0.forwardEdge == .external }
    }

    private func componentsWhereAllVerticesSatisfy(_ satisfy: (Vertex) -> Bool) -> [PathComponent] {
        return (0..<lists.count).compactMap { (i: Int) -> PathComponent? in
            self.allVerticesInComponent(atIndex: i, satisfy: satisfy) ? self.path.components[i] : nil
        }
    }

    private func allVerticesInComponent(atIndex i: Int, satisfy: (Vertex) -> Bool) -> Bool {
        var result = true
        self.forEachVertexInComponent(atIndex: i) {
            if !satisfy($0) {
                result = false
            }
        }
        return result
    }

    /// traverses the list of edges and marks each edge as either .internal, .external, or .coincident with respect to `path`
    fileprivate func classifyEdges(_ path: Path, forCrossingsRemoved: Bool) {
        let fillRule: PathFillRule = forCrossingsRemoved ? .winding : .evenOdd
        func vertexIsIntersection(_ v: Vertex) -> Bool {
            return v.intersectionInfo?.neighbor != nil
        }
        for i in 0..<lists.count {
            let startingVertex: Vertex
            if let firstIntersection = self.firstIntersectionVertex(forComponentindex: i) {
                startingVertex = firstIntersection
            } else {
                // component has no intersections -- we'll classify edges as either all inside or all outside.
                startingVertex = self.startingVertex(forComponentIndex: i, elementIndex: 0)
                startingVertex.previous.forwardEdge = path.contains(startingVertex.location, using: fillRule) ? .internal : .external
            }
            self.forEachVertexStartingFrom(startingVertex) { v in
                guard vertexIsIntersection(v) else {
                    // until we hit an intersection edges continue with same classification as prior edge
                    v.forwardEdge = v.previous.forwardEdge
                    return
                }
                let nextEdge = v.emitNext()
                let point = nextEdge.compute(0.5)
                let normal = nextEdge.normal(0.5)
                let smallDistance: CGFloat = CGFloat(Utils.epsilon)
                let windingCount1 = path.windingCount(point + smallDistance * normal)
                let windingCount2 = path.windingCount(point - smallDistance * normal)
                let contained1 = windingCountImpliesContainment(windingCount1, using: fillRule)
                let contained2 = windingCountImpliesContainment(windingCount2, using: fillRule)
                if forCrossingsRemoved {
                    if contained1, contained2 {
                        v.forwardEdge = .internal
                    } else {
                        v.forwardEdge = .external
                    }
                } else {
                    if windingCount1 == windingCount2 {
                        v.forwardEdge = contained1 ? .internal : .external
                    } else {
                        v.forwardEdge = .coincident
                    }
                }
            }
        }
    }

    private func firstIntersectionVertex(forComponentindex i: Int) -> Vertex? {
        let startingVertex = self.startingVertex(forComponentIndex: i, elementIndex: 0)
        var v = startingVertex
        repeat {
            if v.intersectionInfo?.neighbor != nil { return v }
            v = v.next!
        } while v != startingVertex
        return nil
    }

    private func forEachVertexStartingFrom(_ v: Vertex, _ callback: (Vertex) -> Void) {
        var current = v
        repeat {
            let next = current.next!
            callback(current)
            current = next
        } while current !== v
    }

    private func forEachVertexInComponent(atIndex index: Int, _ callback: (Vertex) -> Void) {
        self.forEachVertexStartingFrom(lists[index].first!, callback)
    }

    internal func startingVertex(forComponentIndex componentIndex: Int, elementIndex: Int) -> Vertex {
        return self.lists[componentIndex][elementIndex]
    }

    func forEachVertex(_ callback: (Vertex) -> Void) {
        lists.forEach {
            self.forEachVertexStartingFrom($0.first!, callback)
        }
    }
}

internal enum BooleanPathOperation {
    case union
    case subtract
    case intersect
    case removeCrossings
}

internal class AugmentedGraph {
    internal var list1: PathLinkedListRepresentation
    internal var list2: PathLinkedListRepresentation

    private let path1: Path
    private let path2: Path

    internal init(path1: Path, path2: Path, intersections: [PathIntersection], forCrossingsRemoved: Bool = false) {
        self.path1 = path1
        self.path2 = path2
        self.list1 = PathLinkedListRepresentation(path1)
        self.list2 = forCrossingsRemoved ? self.list1 : PathLinkedListRepresentation(path2)
        intersections.forEach {
            let location1 = $0.indexedPathLocation1
            let location2 = $0.indexedPathLocation2
            let averagePosition = 0.5 * (path1.point(at: location1) + path2.point(at: location2))
            let vertex1 = Vertex(location: averagePosition, isIntersection: true)
            let vertex2 = Vertex(location: averagePosition, isIntersection: true)
            vertex1.intersectionInfo?.neighbor = vertex2
            vertex2.intersectionInfo?.neighbor = vertex1
            list1.insertIntersectionVertex(vertex1, at: location1)
            list2.insertIntersectionVertex(vertex2, at: location2)
        }
        // mark each intersection as either entry or exit
        list1.classifyEdges(path2, forCrossingsRemoved: forCrossingsRemoved)
        if forCrossingsRemoved == false {
            list2.classifyEdges(path1, forCrossingsRemoved: forCrossingsRemoved)
        }
    }

    private func shouldMoveForwards(fromVertex v: Vertex, forOperation operation: BooleanPathOperation, isOnFirstCurve: Bool) -> Bool {
        // TODO: investigate coincident behavior with operation types besides `.union`
        switch operation {
        case .union, .removeCrossings:
            return v.forwardEdge == .external || (v.forwardEdge == .coincident && v.backwardEdge == .internal)
        case .subtract:
            return isOnFirstCurve ? v.isExit : v.isEntry
        case .intersect:
            return v.isEntry
        }
    }

    internal func booleanOperation(_ operation: BooleanPathOperation) -> Path? {

        // special cases for components which do not cross
        func anyPointOnComponent(_ c: PathComponent) -> CGPoint {
            return c.startingPoint
        }
        var pathComponents: [PathComponent] = []
        switch operation {
        case .removeCrossings:
            pathComponents += self.list1.internalComponents
            pathComponents += self.list1.externalComponents
            pathComponents += self.list1.coincidentComponents
        case .union:
            pathComponents += self.list1.coincidentComponents
            pathComponents += self.list1.externalComponents
            pathComponents += self.list2.externalComponents
        case .subtract:
            pathComponents += self.list1.externalComponents
            pathComponents += self.list2.internalComponents
        case .intersect:
            pathComponents += self.list1.coincidentComponents
            pathComponents += self.list1.internalComponents
            pathComponents += self.list2.internalComponents
        }

        // handle components that have crossings (the main algorithm)
        var unvisitedCrossings: [Vertex] = []
        list1.forEachVertex {
            if $0.isCrossing && shouldMoveForwards(fromVertex: $0, forOperation: operation, isOnFirstCurve: true) {
                unvisitedCrossings.append($0)
            }
        }
        list1.forEachVertex {
            if $0.isCrossing && !shouldMoveForwards(fromVertex: $0, forOperation: operation, isOnFirstCurve: true) {
                unvisitedCrossings.append($0)
            }
        }
        while let start = unvisitedCrossings.first {
            var curves: [BezierCurve] = []
            var isOnFirstCurve = true
            var v = start
            repeat {
                let movingForwards = shouldMoveForwards(fromVertex: v, forOperation: operation, isOnFirstCurve: isOnFirstCurve)
                unvisitedCrossings = unvisitedCrossings.filter { $0 !== v }
                repeat {
                    curves.append(movingForwards ? v.emitNext() : v.emitPrevious())
                    v = movingForwards ? v.next : v.previous
                } while v.isIntersection == false || shouldMoveForwards(fromVertex: v, forOperation: operation, isOnFirstCurve: isOnFirstCurve) == movingForwards
                unvisitedCrossings = unvisitedCrossings.filter { $0 !== v }
                v = v.intersectionInfo!.neighbor!
                isOnFirstCurve.toggle()
                if isOnFirstCurve && v.isCrossing && unvisitedCrossings.contains(v) == false && v !== start {
                    return nil
                }
            } while v !== start && v.intersectionInfo?.neighbor != start
            pathComponents.append(PathComponent(curves: curves))
        }
        return Path(components: pathComponents)
    }

    deinit {
        self.list1.forEachVertex { $0.tearDown() }
        if list1 !== list2 {
            self.list2.forEachVertex { $0.tearDown() }
        }
    }
}

internal enum VertexTransition {
    case line
    case quadCurve(control: CGPoint)
    case curve(control1: CGPoint, control2: CGPoint)
    init(curve: BezierCurve) {
        switch curve {
        case is LineSegment:
            self = .line
        case let quadCurve as QuadraticCurve:
            self = .quadCurve(control: quadCurve.p1)
        case let cubicCurve as CubicCurve:
            self = .curve(control1: cubicCurve.p1, control2: cubicCurve.p2)
        default:
            fatalError("Vertex does not support curve type (\(type(of: curve))")
        }
    }
}

internal class Vertex: Equatable {
    let location: CGPoint

    struct IntersectionInfo {
        var splitT: CGFloat?
        weak var neighbor: Vertex?
    }
    var intersectionInfo: IntersectionInfo?

    func checkCoincidenceDirection(_ forwards: Bool) -> Bool {
        guard let vertexNeighbor = self.intersectionInfo?.neighbor else { return false }
        guard let nextVertexNeighbor = self.next.intersectionInfo?.neighbor else { return false }
        if forwards {
            return vertexNeighbor.next === nextVertexNeighbor
        } else {
            return vertexNeighbor.previous === nextVertexNeighbor
        }
    }

    enum EdgeType {
        case coincident
        case `internal`
        case external
    }

    fileprivate(set) var forwardEdge: EdgeType = .external
    var backwardEdge: EdgeType { return self.previous.forwardEdge }

    var isCrossing: Bool {
        guard self.isEntry || self.isExit else { return false }
        guard let neighbor = self.intersectionInfo?.neighbor else { return false }
        return neighbor.isEntry || neighbor.isExit
    }
    var isEntry: Bool {
        return self.forwardEdge != .external && backwardEdge == .external
    }
    var isExit: Bool {
        let backwardEdge = self.backwardEdge
        return self.forwardEdge == .external && backwardEdge != .external
    }
    var isIntersection: Bool {
        return self.intersectionInfo != nil
    }

    private(set) var next: Vertex! = nil
    private(set) weak var previous: Vertex! = nil
    private(set) var nextTransition: VertexTransition! = nil

    func setNextVertex(_ vertex: Vertex, transition: VertexTransition) {
        self.next = vertex
        self.nextTransition = transition
    }

    func setPreviousVertex(_ vertex: Vertex) {
        self.previous = vertex
    }

    init(location: CGPoint, isIntersection: Bool) {
        self.location = location
        if isIntersection {
            self.intersectionInfo = IntersectionInfo()
        }
    }

    func emitTo(_ end: CGPoint, using transition: VertexTransition) -> BezierCurve {
        switch transition {
        case .line:
            return LineSegment(p0: self.location, p1: end)
        case .quadCurve(let c):
            return QuadraticCurve(p0: self.location, p1: c, p2: end)
        case .curve(let c1, let c2):
            return CubicCurve(p0: self.location, p1: c1, p2: c2, p3: end)
        }
    }

    func emitNext() -> BezierCurve {
        return self.emitTo(next.location, using: nextTransition)
    }

    func emitPrevious() -> BezierCurve {
        return self.previous.emitNext().reversed()
    }

    fileprivate func tearDown() {
        self.next = nil
        self.previous = nil
        self.intersectionInfo?.neighbor = nil
    }

    static func == (left: Vertex, right: Vertex) -> Bool {
        return left === right
    }
}
