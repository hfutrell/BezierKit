//
//  AugmentedGraph.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/28/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import CoreGraphics

internal extension PathComponent {
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

internal enum BooleanPathOperation {
    case union
    case difference
    case intersection
}

internal class AugmentedGraph {
    
    func connectNeighbors(_ vertex1: Vertex, _ vertex2: Vertex) {
        vertex1.intersectionInfo.neighbor = vertex2
        vertex2.intersectionInfo.neighbor = vertex1
    }
    
    private var list1: [Vertex]
    private var list2: [Vertex]
    
    private let component1: PathComponent
    private let component2: PathComponent
    
    internal var v1: Vertex {
        return list1.first!
    }
    internal var v2: Vertex {
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
            /*
             TODO: this code assumes t0 < t < t1, which could definitely be false if there are multiple intersections against the same element at the same point
             in the least we need a unit test for that case
             */
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
            insertIntersectionVertex(v, between: start, and: end, at: location.t, for: component.curves[location.elementIndex])
        }
    }
    
    internal init(component1: PathComponent, component2: PathComponent, intersections: [PathComponentIntersection]) {
        
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
        
        self.component1 = component1
        self.component2 = component2
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
    
    internal func booleanOperation(_ operationType: BooleanPathOperation) -> Path {
        
        func moveForwards(_ v: Vertex, _ onFirstCurve: Bool) -> Bool {
            switch operationType {
                case .union:
                    return v.intersectionInfo.isExit
                case .difference:
                    return onFirstCurve ? v.intersectionInfo.isExit : v.intersectionInfo.isEntry
                case .intersection:
                    return v.intersectionInfo.isEntry
            }
        }
        
        var unvisitedCrossings: Set<Vertex> = Set<Vertex>()
        
        var current = self.v1
        repeat {
            if current.isCrossing {
                unvisitedCrossings.insert(current)
            }
            current = current.next
        } while current !== self.v1
        
        if unvisitedCrossings.count == 0 {
            // handle components that do not cross
            switch operationType {
            case .union:
                return Path(subpaths: [component1, component2].filter { $0.curves.count > 0 })
            case .intersection:
                if component1.contains(component2.curves[0].startingPoint, using: .evenOdd) {
                    return Path(subpaths: [component2])
                }
                else if component2.contains(component1.curves[0].startingPoint, using: .evenOdd) {
                    return Path(subpaths: [component1])
                }
                else {
                    return Path()
                }
            case .difference:
                return Path(subpaths: [component1])
            }
        }
        
        // TODO: add all the crossings to the unvisited crossings set
        
        var pathComponents: [PathComponent] = [PathComponent]()
        while unvisitedCrossings.count > 0 {
            
            var v = unvisitedCrossings.first!
            let start = v
            unvisitedCrossings.remove(v)
            
            var curves: [BezierCurve] = [BezierCurve]()
            var isOnFirstCurve = true
            var movingForwards = moveForwards(v, true)
            
            repeat {
                
                repeat {
                    if movingForwards {
                        curves.append(v.emitNext())
                        v = v.next
                    }
                    else {
                        curves.append(v.emitPrevious())
                        v = v.previous
                    }
                } while v.isCrossing == false
                
                if isOnFirstCurve {
                    unvisitedCrossings.remove(v)
                }
                
                v = v.intersectionInfo.neighbor!
                
                isOnFirstCurve = !isOnFirstCurve
                if isOnFirstCurve {
                    unvisitedCrossings.remove(v)
                }
                
                // decide on a (possibly) new direction
                movingForwards = moveForwards(v, isOnFirstCurve)

            } while v !== start
            
            // TODO: non-deterministic behavior from usage of Set when choosing starting vertex
            pathComponents.append(PathComponent(curves: curves))
        }
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
    public let location: CGPoint
    public let isIntersection: Bool
    // pointers must be set after initialization
    
    public struct IntersectionInfo {
        public var isEntry: Bool = false
        public var isExit: Bool = false
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

