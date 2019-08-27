//
//  AugmentedGraph.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/28/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import CoreGraphics

/// - Returns: true if the vector v falls in the positive region of the surface formed by s1 and s2
internal func vectorOnPositiveSide(_ v: CGPoint, _ s1: CGPoint, _ s2: CGPoint) -> Bool {
    if s2.cross(s1) > 0 {
        return s2.cross(v) > 0 && s1.cross(v) < 0
    } else {
        return s2.cross(v) > 0 || s1.cross(v) < 0
    }
}
/// evaluates and returns the amount to increment the winding count when passing through an intersection with a path
///
/// - Parameters:
///   - v1: incoming direction vector passing through path
///   - v2: outgoing direction vector passing through path
///   - s1: incoming direction of path
///   - s2: outgoing direction of path
/// - Returns: the amount to increment the winding count, either +1, 0, or -1
internal func windingCountAdjustment(_ v1: CGPoint, _ v2: CGPoint, _ s1: CGPoint, _ s2: CGPoint) -> Int {
    let positive1 = vectorOnPositiveSide(v1, s1, s2)
    let positive2 = vectorOnPositiveSide(v2, s1, s2)
    // if we go from positive to negative return -1, negative to positive +1, otherwise 0
    guard positive1 != positive2 else { return 0 }
    return positive1 ? -1 : 1
}

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

    fileprivate func nonCrossingComponents() -> [PathComponent] {
        // returns the components of this path that do not cross the path passed as the argument to markEntryExit(_:)
        var result: [PathComponent] = []
        for i in 0..<lists.count {
            var hasCrossing = false
            self.forEachVertexInComponent(atIndex: i) { v in
                if v.isCrossing {
                    hasCrossing = true
                }
            }
            if hasCrossing == false {
                result.append(self.path.components[i])
            }
        }
        return result
    }

    fileprivate func markEntryExit(_ path: Path, useRelativeWinding: Bool = false) {
        let fillRule: PathFillRule = useRelativeWinding ? .winding : .evenOdd
        for i in 0..<lists.count {
            // determine the initial winding count (winding count before first vertex)
            var initialWinding = 0

            // don't start by computing winding count on a tiny element
            var b = startingVertex(forComponentIndex: i, elementIndex: 0)
            while b.previous.emitPrevious().length() > b.emitPrevious().length() {
                b = b.previous!
            }
            let startingVertex = b

           // if useRelativeWinding {
                let prev = startingVertex.emitPrevious()
                let p = prev.compute(0.5)
                let n = prev.normal(0.5)
                let line = LineSegment(p0: p, p1: p + n)
                let intersections = Path(curve: line).intersections(with: path)
                let s: CGFloat = 0.5 * (intersections.map({$0.indexedPathLocation1.t}).sorted().first(where: {$0 > CGFloat(Utils.epsilon) }) ?? 1.0)
                initialWinding = path.windingCount(p + s * n)
                let w1 = path.windingCount(p + s * n)
            let w2 = path.windingCount(p - 1.0e-4 * n)

            initialWinding = w1
            if windingCountImpliesContainment(w2, using: fillRule) && useRelativeWinding == false {
                initialWinding = w2
            }

            #warning("this is wrong")
            if w1 != w2, useRelativeWinding == false {
                startingVertex.previous.forwardEdge = .coincident
            } else {
                startingVertex.previous.forwardEdge = windingCountImpliesContainment(initialWinding, using: fillRule) ? .internal : .external
            }

          //  } else {
          //      initialWinding = path.windingCount(startingVertex.emitPrevious().compute(0.5))
          //  }
            // determine entries / exists based on winding counts around component
            var windingCount = initialWinding

            self.forEachVertexStartingFrom(startingVertex) { v in
                guard let neighbor = v.intersectionInfo?.neighbor else {
                    v.forwardEdge = v.previous.forwardEdge
                    return
                }
                let previous = v.emitPrevious()
                let next = v.emitNext()

                let smallNumber: CGFloat = 0.001
                let n1 = neighbor.emitPrevious().compute(smallNumber) - v.location
                let n2 = neighbor.emitNext().compute(smallNumber) - v.location
                let v1 = previous.compute(smallNumber) - v.location
                let v2 = next.compute(smallNumber) - v.location

                var wasInside = windingCountImpliesContainment(windingCount, using: fillRule)
                if useRelativeWinding {
                    wasInside = wasInside && windingCountImpliesContainment(windingCount+1, using: fillRule)
                }

                var windingCountChange = windingCountAdjustment(v1, v2, n1, n2)

                let wasOnEdge    =  distance(v1.normalize(), n2.normalize()) < 1.0e-5 || distance(v1.normalize(), n1.normalize()) < 1.0e-5
                let isOnEdge     =  distance(v2.normalize(), n2.normalize()) < 1.0e-5 || distance(v2.normalize(), n1.normalize()) < 1.0e-5

                // handle edge changes
                if isOnEdge != wasOnEdge {
                    windingCountChange = 0
                    if wasOnEdge {
                        let onPositiveSide = vectorOnPositiveSide(v2, n1, n2)
                        if onPositiveSide == true && windingCount < 0 {
                            windingCountChange = 1
                        } else if onPositiveSide == false && windingCount > 0 {
                            windingCountChange = -1
                        }
                    } else if !wasInside {
                        windingCountChange = vectorOnPositiveSide(v1, n1, n2) ? -1 : 1
                    }
                }

                windingCount += windingCountChange

                var isInside = windingCountImpliesContainment(windingCount, using: fillRule)
                if useRelativeWinding {
                    isInside = isInside && windingCountImpliesContainment(windingCount+1, using: fillRule)
                }

                if isOnEdge {
                    print("coincident at \(v.location)")
                    v.forwardEdge = .coincident
                } else {
                    if isInside {
                        print("internal at \(v.location)")
                    } else {
                        print("external at \(v.location)")
                    }
                    v.forwardEdge = isInside ? .internal : .external
                }
            }
//            if initialWinding != windingCount {
//                print("warning: winding count found in .markEntryExit() not consistent")
//            }
        }
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

    internal init(path1: Path, path2: Path, intersections: [PathIntersection]) {
        self.path1 = path1
        self.path2 = path2
        self.list1 = PathLinkedListRepresentation(path1)
        self.list2 = path1 !== path2 ? PathLinkedListRepresentation(path2) : self.list1
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
        let useRelativeWinding = (list1 === list2)
        print("doing first path")
        list1.markEntryExit(path2, useRelativeWinding: useRelativeWinding)
        if useRelativeWinding == false {
            print("doing second path")
            list2.markEntryExit(path1, useRelativeWinding: useRelativeWinding)
        }
    }

    // INSTEAD OF THIS WE NEED A PROPERTY ON INTERSECTIONS
    // CALLED LIKE "DIRECTION TOWARDS INTERIOR IS FORWARDS"

    // WE DON'T START AT "CROSSINGS" but rather "MUST INCLUDE"
    // EDGES (for union those are EXTERIOR) edges

    private func shouldMoveForwards(fromVertex v: Vertex, forOperation operation: BooleanPathOperation, isOnFirstCurve: Bool) -> Bool {
        switch operation {
        case .removeCrossings: // todo: investigate further coincident behavior
            fallthrough
        case .union:
            return v.forwardEdge == .external || (v.forwardEdge == .coincident && v.backwardEdge == .internal)
        case .subtract:
            return isOnFirstCurve ? v.isExit : v.isEntry // todo: investigate further coincident behavior
        case .intersect:
            return v.isEntry // todo: investigate further coincident behavior
        }
    }

    internal func booleanOperation(_ operation: BooleanPathOperation) -> Path? {

        // special cases for components which do not cross
        let nonCrossingComponents1: [PathComponent] = self.list1.nonCrossingComponents()
        let nonCrossingComponents2: [PathComponent] = self.list2.nonCrossingComponents()

        func anyPointOnComponent(_ c: PathComponent) -> CGPoint {
            return c.startingPoint
        }
        var pathComponents: [PathComponent] = []
        switch operation {
        case .removeCrossings:
            pathComponents += nonCrossingComponents1
        case .union:
            pathComponents += nonCrossingComponents1.filter { path2.contains(anyPointOnComponent($0), using: .evenOdd) == false }
            pathComponents += nonCrossingComponents2.filter { path1.contains(anyPointOnComponent($0), using: .evenOdd) == false }
        case .subtract:
            pathComponents += nonCrossingComponents1.filter { path2.contains(anyPointOnComponent($0), using: .evenOdd) == false }
            pathComponents += nonCrossingComponents2.filter { path1.contains(anyPointOnComponent($0), using: .evenOdd) == true }
        case .intersect:
            pathComponents += nonCrossingComponents1.filter { path2.contains(anyPointOnComponent($0), using: .evenOdd) == true }
            pathComponents += nonCrossingComponents2.filter { path1.contains(anyPointOnComponent($0), using: .evenOdd) == true }
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
            print("started at \(v.location)")
            repeat {
                let movingForwards = shouldMoveForwards(fromVertex: v, forOperation: operation, isOnFirstCurve: isOnFirstCurve)
                unvisitedCrossings = unvisitedCrossings.filter { $0 !== v }
                repeat {
                    curves.append(movingForwards ? v.emitNext() : v.emitPrevious())
                    v = movingForwards ? v.next : v.previous
                    print("moved to \(v.location)")
                } while v.isIntersection == false || shouldMoveForwards(fromVertex: v, forOperation: operation, isOnFirstCurve: isOnFirstCurve) == movingForwards

                print("found entry or exit at \(v.location)")

                unvisitedCrossings = unvisitedCrossings.filter { $0 !== v }

//                if shouldMoveForwards(fromVertex: v, forOperation: operation, isOnFirstCurve: isOnFirstCurve) != movingForwards {
                    v = v.intersectionInfo!.neighbor!
                    isOnFirstCurve = !isOnFirstCurve
                    print("switched sides")
//                } else {
//                    print("no switch sides")
//                }

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
        guard neighbor.isEntry || neighbor.isExit else { return false }
        return true
    }
    var isEntry: Bool {
        return (self.forwardEdge == .internal || self.forwardEdge == .coincident) && backwardEdge == .external
    }
    var isExit: Bool {
        let backwardEdge = self.backwardEdge
        return self.forwardEdge == .external && (backwardEdge == .internal || backwardEdge == .coincident)
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
