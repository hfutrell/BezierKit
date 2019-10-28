//
//  AugmentedGraph.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/28/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import CoreGraphics

internal class PathLinkedListRepresentation {
    // TODO: investigate access control
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

    fileprivate func allVerticesInComponent(atIndex i: Int, satisfy: (Vertex) -> Bool) -> Bool {
        var result = true
        self.forEachVertexInComponent(atIndex: i) {
            if !satisfy($0) {
                result = false
            }
        }
        return result
    }
    
    fileprivate func firstIntersectionVertex(forComponentindex i: Int) -> Vertex? {
        let startingVertex = self.startingVertex(forComponentIndex: i, elementIndex: 0)
        var v = startingVertex
        repeat {
            if v.intersectionInfo?.neighbor != nil { return v }
            v = v.next!
        } while v != startingVertex
        return nil
    }

    fileprivate func forEachVertexStartingFrom(_ v: Vertex, _ callback: (Vertex) -> Void) {
        var current = v
        repeat {
            let next = current.next!
            callback(current)
            current = next
        } while current !== v
    }

    fileprivate func forEachVertexInComponent(atIndex index: Int, _ callback: (Vertex) -> Void) {
        self.forEachVertexStartingFrom(lists[index].first!, callback)
    }

    internal func startingVertex(forComponentIndex componentIndex: Int, elementIndex: Int) -> Vertex {
        return self.lists[componentIndex][elementIndex]
    }

    internal var numberOfComponents: Int {
        return self.lists.count
    }
    
    func forEachVertex(_ callback: (Vertex) -> Void) {
        lists.forEach {
            self.forEachVertexStartingFrom($0.first!, callback)
        }
    }
}

// TODO: revert public scope
public enum BooleanPathOperation {
    case union
    case subtract
    case intersect
    case removeCrossings
}

// TODO: revert public scope
public class AugmentedGraph {
    internal var list1: PathLinkedListRepresentation
    internal var list2: PathLinkedListRepresentation

    private let operation: BooleanPathOperation
    private let path1: Path
    private let path2: Path

    public func draw(_ context: CGContext) {
        func drawList(_ list: PathLinkedListRepresentation) {
            for i in 0..<list.numberOfComponents {
                let firstVertex = list.startingVertex(forComponentIndex: i, elementIndex: 0)
                var current = firstVertex
                repeat {
                    switch current.forwardEdge {
                    case .shouldExclude:
                        Draw.setColor(context, color: Draw.red)
                    case .toInclude:
                        Draw.setColor(context, color: Draw.green)
                    case .unknown:
                        Draw.setColor(context, color: Draw.blue)
                    case .visited:
                        Draw.setColor(context, color: Draw.black)
                    }
                    Draw.drawCurve(context, curve: current.emitNext())
                    var radius: CGFloat = 1.0
                    if current.isIntersection {
                        radius = 2.0
                        if current.forwardEdge == .shouldExclude {
                            radius += 2.0
                        }
                    } else {
                        Draw.setColor(context, color: Draw.black)
                    }
                    Draw.drawCircle(context, center: current.location, radius: radius)

                    current = current.next
                } while current !== firstVertex
            }
        }
        drawList(self.list1)
        drawList(self.list2)
        Draw.reset(context)
    }

    private func pointIsContainedInBooleanResult(point: CGPoint, operation: BooleanPathOperation) -> Bool {
        let rule: PathFillRule = (operation == .removeCrossings) ? .winding : .evenOdd
        let contained1 = path1.contains(point, using: rule)
        guard operation != .removeCrossings else { return contained1 }
        let contained2 = path2.contains(point, using: rule)
        switch operation {
        case .union:
            return contained1 || contained2
        case .intersect:
            return contained1 && contained2
        case .subtract:
            return contained1 && !contained2
        default:
            assertionFailure()
            return false
        }
    }
    
    /// traverses the list of edges and marks each edge as either .internal, .external, or .coincident with respect to `path`
    private func classifyEdges(in list: PathLinkedListRepresentation) {
        for i in 0..<list.numberOfComponents {
            var previousEdge: Vertex.EdgeType?
            list.forEachVertexInComponent(atIndex: i) { v in
                if v.isIntersection == false, let previousEdge = previousEdge, previousEdge != .unknown {
                    // just take on the value of the previous edge, if possible
                    v.forwardEdge = previousEdge
                    return
                }
                let nextEdge = v.emitNext()
                let point = nextEdge.compute(0.5)
                let normal = nextEdge.normal(0.5)
                let smallDistance = CGFloat(Utils.epsilon)
                let included1 = self.pointIsContainedInBooleanResult(point: point + smallDistance * normal, operation: operation)
                let included2 = self.pointIsContainedInBooleanResult(point: point - smallDistance * normal, operation: operation)
                let edgeType: Vertex.EdgeType = (included1 != included2) ? .toInclude : .shouldExclude
                v.forwardEdge = edgeType
                previousEdge = v.forwardEdge
            }
        }
    }
    
    public init(path1: Path, path2: Path, intersections: [PathIntersection], operation: BooleanPathOperation) {
        self.operation = operation
        self.path1 = path1
        self.path2 = path2
        self.list1 = PathLinkedListRepresentation(path1)
        self.list2 = operation != .removeCrossings ? PathLinkedListRepresentation(path2) : self.list1
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
        self.classifyEdges(in: self.list1)
        if list1 !== list2 {
            self.classifyEdges(in: self.list2)
        }
    }

    private func shouldContinue(fromVertex v: Vertex, inForwardsDirection forwards: Bool) -> Bool {
        if forwards {
            return v.forwardEdge == .toInclude
        } else {
            return v.backwardEdge == .toInclude
        }
    }
    
    private func crossableNeighbor(fromVertex v: Vertex) -> Vertex? {
        guard let neighbor = v.intersectionInfo?.neighbor else { return nil }
        guard neighbor.forwardEdge == .toInclude || neighbor.backwardEdge == .toInclude else { return nil }
        return neighbor
    }
    
    internal func performOperation() -> Path? {
        func pathComponent(startingFrom startingVertex: Vertex) -> PathComponent {
            assert(startingVertex.forwardEdge == .toInclude)
            var curves: [BezierCurve] = []
            var currentVertex = startingVertex
            var movingForwards = true
            // TODO: when we visit a coincident edge we must mark the other edge visited too
            while true {
                repeat {
                    curves.append(movingForwards ? currentVertex.emitNext() : currentVertex.emitPrevious())
                    if movingForwards {
                        assert(currentVertex.forwardEdge == .toInclude)
                        currentVertex.forwardEdge = .visited
                    } else {
                        assert(currentVertex.backwardEdge == .toInclude)
                        currentVertex.previous.forwardEdge = .visited
                        assert(currentVertex.backwardEdge == .visited)
                    }
                    let nextVertex = movingForwards ? currentVertex.next : currentVertex.previous
                    // UGH:
                    // SO this *appears* to work to mark duplicate coincident edges as visited
                    // BUT it doesn't really because it's based on vertex coordinates and not coincidence
                    // which works for lines, but not curves
                    //
                    // maybe just mark one set of coincident edges as visited ahead of time? I don't know.
                    //
                    if let neighbor = currentVertex.intersectionInfo?.neighbor {
                        if neighbor.next.intersectionInfo?.neighbor === nextVertex {
                         //   neighbor.forwardEdge = .visited
                        }
                        if neighbor.previous.intersectionInfo?.neighbor === nextVertex {
                        //    neighbor.previous.forwardEdge = .visited
                        }
                    }
                    currentVertex = nextVertex!
                } while shouldContinue(fromVertex: currentVertex, inForwardsDirection: movingForwards)
                if let neighbor = crossableNeighbor(fromVertex: currentVertex) {
                    currentVertex = neighbor
                    movingForwards = (currentVertex.forwardEdge == .toInclude)
                } else {
                    if currentVertex.location != startingVertex.location {
                        // TODO: we need to check if this is hit in cases that actually worked correctly before
                        print("oh no")
                        curves.append(LineSegment(p0: currentVertex.location, p1: startingVertex.location))
                    }
                    return PathComponent(curves: curves)
                }
            }
        }
        func pathComponents(forList list: PathLinkedListRepresentation) -> [PathComponent] {
            var components = [PathComponent]()
            for i in 0..<list.numberOfComponents {
                list.forEachVertexInComponent(atIndex: i) { v in
                    guard v.forwardEdge == .toInclude else { return }
                    components.append(pathComponent(startingFrom: v))
                }
            }
            return components
        }
        return Path(components: pathComponents(forList: self.list1) + pathComponents(forList: self.list2))
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

    enum EdgeType {
        case unknown         /* edge classifications are unknown until `classifyEdges` is run */
        case toInclude       /* the edge must be included in the result */
        case shouldExclude   /* the edge must be excluded from the result */
        case visited         /* the edge was previous toInclude but has been marked as visited */
    }

    fileprivate(set) var forwardEdge: EdgeType = .unknown
    var backwardEdge: EdgeType { return self.previous.forwardEdge }

    var isCrossing: Bool {
        assert(self.forwardEdge != .unknown)
        return self.forwardEdge != self.backwardEdge
    }

    var isIntersection: Bool {
        // TODO: assert consistency
        return self.intersectionInfo?.neighbor?.intersectionInfo?.neighbor === self
    }

    private(set) public var next: Vertex! = nil
    private(set) public weak var previous: Vertex! = nil
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
