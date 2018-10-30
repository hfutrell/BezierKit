//
//  AugmentedGraph.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/28/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import CoreGraphics

public func signedAngle(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
    return atan2(CGPoint.cross(a, b), a.dot(b))
}

public func between(_ v: CGPoint, _ a: CGPoint, _ b: CGPoint) -> Bool {
    let signedAngleAB = signedAngle(a, b)
    let signedAngleAV = signedAngle(a, v)
    if signedAngleAB > 0 {
        return signedAngleAV > 0 && signedAngleAV < signedAngleAB
    }
    else if signedAngleAB < 0 {
        return signedAngleAV < 0 && signedAngleAV > signedAngleAB
    }
    else {
        return signedAngleAV == 0
    }
}

extension CGPoint {
    static func cross(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        return p1.x * p2.y - p1.y * p2.x
    }
}

internal class PathLinkedListRepresentation {
    
    private var lists: [[Vertex]] = []
    private let path: Path
    
    private func insertIntersectionVertex(_ v: Vertex, replacingVertexAtStartOfElementIndex elementIndex: Int, inList list: inout [Vertex]) {
        assert(v.isIntersection)
        let r = list[elementIndex]
        // insert v in the list
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
        let t0: CGFloat = (start.splitInfo != nil) ? start.splitInfo!.t : 0.0
        let t1: CGFloat = (end.splitInfo != nil) ? end.splitInfo!.t : 1.0
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
        }
        else {
            var start = list[location.elementIndex]
            while (start.next.splitInfo != nil) && start.next.splitInfo!.t < location.t {
                start = start.next
            }
            var end = start.next!
            while (end.splitInfo != nil) && end.splitInfo!.t < location.t {
                assert(end !== list[location.elementIndex+1])
                end = end.next
            }
            insertIntersectionVertex(v, between: start, and: end, at: location.t, for: path.element(at: location), inList: &list)
        }
        self.lists[location.componentIndex] = list
    }
    
    private func createListFor(component: PathComponent) -> [Vertex] {
        guard component.curves.count > 0 else {
            return []
        }
        assert(component.curves.first!.startingPoint == component.curves.last!.endingPoint, "this method assumes component is closed!")
        var elements: [Vertex] = [] // elements[i] is the first vertex of curves[i]
        let firstPoint: CGPoint = component.curves.first!.startingPoint
        let firstVertex = Vertex(location: firstPoint, isIntersection: false)
        elements.append(firstVertex)
        var lastVertex = firstVertex
        for i in 1..<component.curves.count {
            let v = Vertex(location: component.curves[i].startingPoint, isIntersection: false)
            elements.append(v)
            let curveForTransition = component.curves[i-1]
            // set the forwards reference for starting vertex of curve i-1
            lastVertex.setNextVertex(v, transition: VertexTransition(curve: curveForTransition))
            // set the backwards reference for starting vertex of curve i
            v.setPreviousVertex(lastVertex)
            // point previous at v for the next iteration
            lastVertex = v
        }
        // connect the forward reference of the last vertex to the first vertex
        let lastCurve = component.curves.last!
        lastVertex.setNextVertex(firstVertex, transition: VertexTransition(curve: lastCurve))
        // connect the backward reference of the first vertex to the last vertex
        firstVertex.setPreviousVertex(lastVertex)
        // return list of vertexes that point to the start of each element
        return elements
    }
    
    init(_ p: Path) {
        self.path = p
        self.lists = p.subpaths.map { self.createListFor(component: $0) }
    }
    
    fileprivate func markEntryExit(_ path: Path, _ nonCrossingComponents: inout [PathComponent], useRelativeWinding: Bool = false) {
        let fillRule = PathFillRule.winding
        for i in 0..<lists.count {
            
            // determine winding counts relative to the first vertex
            var relativeWindingCount = 0
            self.forEachVertexInComponent(atIndex: i) { v in
                guard v.isIntersection else {
                    return
                }
                let previous = v.emitPrevious()
                let next = v.emitNext()
                
                let n1 = v.intersectionInfo.neighbor!.emitPrevious().derivative(0)
                let n2 = v.intersectionInfo.neighbor!.emitNext().derivative(0)
                
                let v1 = previous.derivative(0)
                let v2 = next.derivative(0)
                
                let side1 = between(v1, n1, n2)
                let side2 = between(v2, n1, n2)
                
                let cross = (side1 != side2)
                
                if cross {
                    // TODO: there's an issue when corners intersect (try AugmentedGraphTests.testCornersIntersect which has this problem, even though it passes)
                    // the relative winding count can be decremented both for entry and for exit. This is not an issue with the even-odd winding rule, but using
                    // winding it can be an issue
                    let c = CGPoint.cross(v2, n2)
                    if c < 0 {
                        relativeWindingCount += 1
                    }
                    else if c > 0 {
                        relativeWindingCount -= 1
                    }
                }
                v.intersectionInfo.nextWinding = relativeWindingCount
            }
            
            // determine the initial winding count (winding count before first vertex)
            var initialWinding = 0
            if useRelativeWinding {
                var minimumWinding = Int.max
                self.forEachVertexInComponent(atIndex: i) { v in
                    guard v.isIntersection else {
                        return
                    }
                    if v.intersectionInfo.nextWinding < minimumWinding {
                        minimumWinding = v.intersectionInfo.nextWinding
                    }
                }
                initialWinding = -minimumWinding
                
                let prev = lists[i][0].emitPrevious()
                let a = prev.compute(0.5)
                let b = a + 1.0e-5 * prev.normal(0.5)
                let c = a - 1.0e-5 * prev.normal(0.5)
                
                let w1 = path.windingCount(b)
                let w2 = path.windingCount(c)
                
                print("w1 = \(w1)")
                print("w2 = \(w2)")
                
                if w1 < initialWinding {
                    initialWinding = w1
                }
                

            }
            else {
                initialWinding = path.windingCount(lists[i][0].emitPrevious().compute(0.5))
            }
            
            // adjust winding counts based on the initial winding count
            self.forEachVertexInComponent(atIndex: i) { v in
                guard v.isIntersection else {
                    return
                }
                v.intersectionInfo.nextWinding += initialWinding
            }
            
            // for each intersection, determine isEntry / isExit based on winding count
            var hasCrossing: Bool = false
            var windingCount: Int = initialWinding
            self.forEachVertexInComponent(atIndex: i) { v in
                guard v.isIntersection else {
                    return
                }
                var wasInside = windingCountImpliesContainment(windingCount, using: fillRule)
                if useRelativeWinding {
                    wasInside = windingCountImpliesContainment(windingCount, using: fillRule) && windingCountImpliesContainment(windingCount+1, using: fillRule)
                }
                windingCount = v.intersectionInfo.nextWinding
                var isInside = windingCountImpliesContainment(windingCount, using: fillRule)  || (useRelativeWinding && windingCountImpliesContainment(windingCount+1, using: fillRule))
                if useRelativeWinding {
                    isInside = windingCountImpliesContainment(windingCount, using: fillRule) && windingCountImpliesContainment(windingCount+1, using: fillRule)
                }

                v.intersectionInfo.isEntry = wasInside == false && isInside == true
                v.intersectionInfo.isExit = wasInside == true && isInside == false
                if v.intersectionInfo.isEntry || v.intersectionInfo.isExit {
                    hasCrossing = true
                }
            }
            if !hasCrossing {
                nonCrossingComponents.append(self.path.subpaths[i])
            }
        }
    }

    private func forEachVertexStartingFrom(_ v: Vertex, _ callback: (Vertex) -> Void) {
        var current = v
        repeat {
            callback(current)
            current = current.next
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
    case difference
    case intersection
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
    
    private var nonCrossingComponents1: [PathComponent] = []
    private var nonCrossingComponents2: [PathComponent] = []
    
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
        list1.markEntryExit(path2, &nonCrossingComponents1, useRelativeWinding: useRelativeWinding)
        if useRelativeWinding == false {
            list2.markEntryExit(path1, &nonCrossingComponents2, useRelativeWinding: useRelativeWinding)
        }
    }
    
    private func shouldMoveForwards(fromVertex v: Vertex, forOperation operation: BooleanPathOperation, isOnFirstCurve: Bool) -> Bool {
        switch operation {
        case .removeCrossings:
            fallthrough
        case .union:
            return v.intersectionInfo.isExit
        case .difference:
            return isOnFirstCurve ? v.intersectionInfo.isExit : v.intersectionInfo.isEntry
        case .intersection:
            return v.intersectionInfo.isEntry
        }
    }
    
    internal func booleanOperation(_ operation: BooleanPathOperation) -> Path {
        // handle components that have no crossings
        func anyPointOnComponent(_ c: PathComponent) -> CGPoint {
            return c.curves[0].startingPoint
        }
        var pathComponents: [PathComponent] = []
        switch operation {
        case .removeCrossings:
            pathComponents += nonCrossingComponents1 // TODO: hmm7
        case .union:
            pathComponents += nonCrossingComponents1.filter { path2.contains(anyPointOnComponent($0)) == false }
            pathComponents += nonCrossingComponents2.filter { path1.contains(anyPointOnComponent($0)) == false }
        case .difference:
            pathComponents += nonCrossingComponents1.filter { path2.contains(anyPointOnComponent($0)) == false }
            pathComponents += nonCrossingComponents2.filter { path1.contains(anyPointOnComponent($0)) == true }
        case .intersection:
            pathComponents += nonCrossingComponents1.filter { path2.contains(anyPointOnComponent($0)) == true }
            pathComponents += nonCrossingComponents2.filter { path1.contains(anyPointOnComponent($0)) == true }
        }
        // handle components that have crossings
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
                //                if isOnFirstCurve && unvisitedCrossings.contains(v) == false {
                //                    print("already visited this crossing! bailing out to avoid infinite loop! Needs debugging.")
                //                    break
                //                }
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
                    print("already visited this crossing! bailing out to avoid infinite loop! Needs debugging.")
                    if let last = curves.last?.endingPoint, let first = curves.first?.startingPoint, last != first {
                        curves.append(LineSegment(p0: last, p1: first)) // close the component before we bail out
                    }
                    break
                }
                
                unvisitedCrossings = unvisitedCrossings.filter { $0 !== v }
                
                if !v.isCrossing {
                    print("consistency error detected -- bailing out. Needs debugging.")
                    v = v.intersectionInfo.neighbor! // jump back to avoid infinite loop
                    isOnFirstCurve = !isOnFirstCurve
                }
            } while v !== start
            pathComponents.append(PathComponent(curves: curves))
        }
        // TODO: non-deterministic behavior from usage of Set when choosing starting vertex
        return Path(subpaths: pathComponents)
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
        public var nextWinding: Int = 0
        public var neighbor: Vertex? = nil
    }
    public var intersectionInfo: IntersectionInfo = IntersectionInfo()
    
    public var isCrossing: Bool {
        return self.isIntersection && (self.intersectionInfo.isEntry || self.intersectionInfo.isExit)
    }
    
    internal struct SplitInfo {
        var t: CGFloat
    }
    internal var splitInfo: SplitInfo? = nil // non-nil only when vertex is inserted by splitting an element
    
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
}

extension Vertex: Equatable {
    public static func == (left: Vertex, right: Vertex) -> Bool {
        return left === right
    }
}

extension Vertex: Hashable {
    public var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
}
