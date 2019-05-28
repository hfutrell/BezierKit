//
//  AugmentedGraph.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/28/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import CoreGraphics

/// - Returns: true if the vector v falls inside the (smaller of the two) angles formed by vectors a and b
internal func between(_ v: CGPoint, _ a: CGPoint, _ b: CGPoint) -> Bool {
    if a.cross(b) > 0 {
        // smaller angle from a to b goes clockwise from a to b
        return a.cross(v) > 0 && b.cross(v) < 0
    } else {
        // smaller angle from a to b goes counter-clockwise from a to b
        return b.cross(v) > 0 && a.cross(v) < 0
    }
}

private func signOrZero<A: FloatingPoint>(_ x: A) -> Int {
    if x > 0 {
        return 1
    } else if x < 0 {
        return -1
    } else {
        return 0 // signOrZero(NaN) returns 0 as well because comparisons with NaN always false
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
    let side1 = between(v1, s1, s2)
    let side2 = between(v2, s1, s2)
    guard side1 != side2 else { return 0 }
    if side1 {
        return signOrZero(v1.cross(s2))
    } else {
        return signOrZero(v2.cross(s1))
    }
}

internal class PathLinkedListRepresentation {

    private var lists: [[Vertex]] = []
    private let path: Path

    private func insertIntersectionVertex(_ v: Vertex, replacingVertexAtStartOfElementIndex elementIndex: Int, inList list: inout [Vertex]) {
        assert(v.isIntersection)
        let r = list[elementIndex]
        // insert v in the list
        if let neighbor = r.intersectionInfo.neighbor {
            neighbor.intersectionInfo.neighbor = nil
        }
        v.setPreviousVertex(r.previous)
        v.setNextVertex(r.next, transition: r.nextTransition)
        v.previous.setNextVertex(v, transition: v.previous.nextTransition)
        v.next.setPreviousVertex(v)
        // replace the list pointer with v
        list[elementIndex] = v
    }

    private func insertIntersectionVertex(_ v: Vertex, between start: Vertex, and end: Vertex, at t: CGFloat, for element: BezierCurve, inList list: inout [Vertex]) {
        assert(start !== end)
        assert(v.isIntersection)
        v.splitInfo = Vertex.SplitInfo(t: t)
        let t0: CGFloat = start.splitInfo?.t ?? 0.0
        let t1: CGFloat = end.splitInfo?.t ?? 1.0
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
            while (start.next.splitInfo != nil) && start.next.splitInfo!.t < location.t {
                start = start.next
            }
            var end = start.next!
            while (end.splitInfo != nil) && end.splitInfo!.t < location.t {
                assert(end !== list[location.elementIndex+1])
                end = end.next
            }
            insertIntersectionVertex(v, between: start, and: end, at: location.t, for: path.elementAtComponentIndex(location.componentIndex, elementIndex: location.elementIndex), inList: &list)
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

            if useRelativeWinding {
                let prev = startingVertex.emitPrevious()
                let p = prev.compute(0.5)
                let n = prev.normal(0.5)
                let line = LineSegment(p0: p, p1: p + n)
                let intersections = Path(curve: line).intersections(with: path)
                let s: CGFloat = 0.5 * (intersections.map({$0.indexedPathLocation1.t}).sorted().first(where: {$0 > CGFloat(Utils.epsilon) }) ?? 1.0)
                initialWinding = path.windingCount(p + s * n)
            } else {
                initialWinding = path.windingCount(startingVertex.emitPrevious().compute(0.5))
            }
            // determine entries / exists based on winding counts around component
            var windingCount = initialWinding
            self.forEachVertexStartingFrom(startingVertex) { v in
                guard v.isIntersection, let neighbor = v.intersectionInfo.neighbor else { return }
                let previous = v.emitPrevious()
                let next = v.emitNext()

                let smallNumber: CGFloat = 0.001
                let n1 = neighbor.emitPrevious().compute(smallNumber) - v.location
                let n2 = neighbor.emitNext().compute(smallNumber) - v.location
                let v1 = previous.compute(smallNumber) - v.location
                let v2 = next.compute(smallNumber) - v.location

                let windingCountChange = windingCountAdjustment(v1, v2, n1, n2)

//                if useRelativeWinding == false {
//                    let altChange = path.windingCount(next.compute(0.05)) - path.windingCount(previous.compute(0.05))
//                    if altChange != windingCountChange {
//                        print("windingCountChange is wrong?")
//                    }
//                }

                if windingCountChange != 0 {
                    var wasInside = windingCountImpliesContainment(windingCount, using: fillRule)
                    if useRelativeWinding {
                        wasInside = wasInside && windingCountImpliesContainment(windingCount+1, using: fillRule)
                    }
                    windingCount += windingCountChange
                    var isInside = windingCountImpliesContainment(windingCount, using: fillRule)
                    if useRelativeWinding {
                        isInside = isInside && windingCountImpliesContainment(windingCount+1, using: fillRule)
                    }
                    v.intersectionInfo.isEntry = wasInside == false && isInside == true
                    v.intersectionInfo.isExit = wasInside == true && isInside == false
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

    func connectNeighbors(_ vertex1: Vertex, _ vertex2: Vertex) {
        vertex1.intersectionInfo.neighbor = vertex2
        vertex2.intersectionInfo.neighbor = vertex1
        let location = 0.5 * (vertex1.location + vertex2.location)
        vertex1.location = location
        vertex2.location = location
    }

    internal var list1: PathLinkedListRepresentation
    internal var list2: PathLinkedListRepresentation

    private let path1: Path
    private let path2: Path

    internal init(path1: Path, path2: Path, intersections: [PathIntersection]) {

        func intersectionVertexForPath(_ path: Path, at l: IndexedPathLocation) -> Vertex {
            let v = Vertex(location: path.point(at: l), isIntersection: true)
            return v
        }

        self.path1 = path1
        self.path2 = path2
        self.list1 = PathLinkedListRepresentation(path1)
        self.list2 = path1 !== path2 ? PathLinkedListRepresentation(path2) : self.list1
        intersections.forEach {
            let vertex1 = intersectionVertexForPath(path1, at: $0.indexedPathLocation1)
            let vertex2 = intersectionVertexForPath(path2, at: $0.indexedPathLocation2)
            connectNeighbors(vertex1, vertex2) // sets the vertex crossing neighbor pointer
            list1.insertIntersectionVertex(vertex1, at: $0.indexedPathLocation1)
            list2.insertIntersectionVertex(vertex2, at: $0.indexedPathLocation2)
        }
        // mark each intersection as either entry or exit
        let useRelativeWinding = (list1 === list2)
        list1.markEntryExit(path2, useRelativeWinding: useRelativeWinding)
        if useRelativeWinding == false {
            list2.markEntryExit(path1, useRelativeWinding: useRelativeWinding)
        }
    }

    private func shouldMoveForwards(fromVertex v: Vertex, forOperation operation: BooleanPathOperation, isOnFirstCurve: Bool) -> Bool {
        switch operation {
        case .removeCrossings:
            fallthrough
        case .union:
            return v.intersectionInfo.isExit
        case .subtract:
            return isOnFirstCurve ? v.intersectionInfo.isExit : v.intersectionInfo.isEntry
        case .intersect:
            return v.intersectionInfo.isEntry
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
            repeat {
                let movingForwards = shouldMoveForwards(fromVertex: v, forOperation: operation, isOnFirstCurve: isOnFirstCurve)
                unvisitedCrossings = unvisitedCrossings.filter { $0 !== v }
                repeat {
                    curves.append(movingForwards ? v.emitNext() : v.emitPrevious())
                    v = movingForwards ? v.next : v.previous
                } while v.isCrossing == false

                unvisitedCrossings = unvisitedCrossings.filter { $0 !== v }
                v = v.intersectionInfo.neighbor!
                isOnFirstCurve = !isOnFirstCurve

                if isOnFirstCurve && unvisitedCrossings.contains(v) == false && v !== start {
                    return nil
                }
            } while v !== start
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
    public var location: CGPoint
    public let isIntersection: Bool
    // pointers must be set after initialization

    public struct IntersectionInfo {
        public var isEntry: Bool = false
        public var isExit: Bool = false
        public weak var neighbor: Vertex?
    }
    public var intersectionInfo: IntersectionInfo = IntersectionInfo()

    public var isCrossing: Bool {
        guard let neighborInfo = self.intersectionInfo.neighbor?.intersectionInfo else {
            return false
        }
        return self.isIntersection && (self.intersectionInfo.isEntry || self.intersectionInfo.isExit) && (neighborInfo.isEntry || neighborInfo.isExit)
    }

    internal struct SplitInfo {
        var t: CGFloat
    }
    internal var splitInfo: SplitInfo? // non-nil only when vertex is inserted by splitting an element

    public private(set) var next: Vertex! = nil
    public private(set) weak var previous: Vertex! = nil
    public private(set) var nextTransition: VertexTransition! = nil

    public func setNextVertex(_ vertex: Vertex, transition: VertexTransition) {
        self.next = vertex
        self.nextTransition = transition
    }

    public func setPreviousVertex(_ vertex: Vertex) {
        self.previous = vertex
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
        return self.previous.emitNext().reversed()
    }

    fileprivate func tearDown() {
        self.next = nil
        self.previous = nil
        self.intersectionInfo.neighbor = nil
    }
}

extension Vertex: Equatable {
    public static func == (left: Vertex, right: Vertex) -> Bool {
        return left === right
    }
}
