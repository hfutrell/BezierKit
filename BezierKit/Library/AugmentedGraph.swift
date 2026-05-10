//
//  AugmentedGraph.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/28/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

internal enum BooleanPathOperation {
    case union
    case subtract
    case intersect
    case removeCrossings
}

private class Node {
    let location: IndexedPathLocation
    var componentLocation: IndexedPathComponentLocation {
        return self.location.locationInComponent
    }
    var forwardEdge: Edge?
    var backwardEdge: Edge?
    private(set) var neighbors: [Node] = []
    let path: Path
    var pathComponent: PathComponent {
        return path.components[self.location.componentIndex]
    }
    init(location: IndexedPathLocation, in path: Path) {
        self.location = location
        self.path = path
    }
    func neighborsContain(_ node: Node) -> Bool {
        return self.neighbors.contains(where: { $0 === node })
    }
    func addNeighbor(_ node: Node) {
        assert(self.neighborsContain(node) == false)
        self.neighbors.append(node)
    }
    private func replaceNeighbor(_ node: Node, with replacement: Node) {
        // if replacement is already present, just remove node to avoid creating a duplicate
        let alreadyHasReplacement = neighborsContain(replacement)
        neighbors = neighbors.compactMap {
            guard $0 === node else { return $0 }
            return alreadyHasReplacement ? nil : replacement
        }
    }
    func mergeNeighbors(of node: Node) {
        node.neighbors.forEach {
            guard $0 !== self else { return }  // skip self-referential connections
            $0.replaceNeighbor(node, with: self)
            if !self.neighborsContain($0) {
                self.addNeighbor($0)
            }
        }
        // remove stale reference to node since it's being merged away
        self.neighbors = self.neighbors.filter { $0 !== node }
    }
    /// Nodes can have strong reference cycles either through their neighbors or through their edges, unlinking all nodes when owner no longer holds instance prevents memory leakage
    func unlink() {
        self.neighbors = []
        self.forwardEdge = nil
        self.backwardEdge = nil
    }
}

private class Edge {
    var visited: Bool = false
    var inSolution: Bool = false
    var isWraparound: Bool = false
    let endingNode: Node
    let startingNode: Node
    init(startingNode: Node, endingNode: Node) {
        self.startingNode = startingNode
        self.endingNode = endingNode
    }
    var needsVisiting: Bool {
        return self.visited == false && self.inSolution == true
    }
    var component: PathComponent {
        let parentComponent = self.endingNode.pathComponent
        if isWraparound {
            let compStartLoc = parentComponent.startingIndexedLocation
            let compEndLoc = parentComponent.endingIndexedLocation
            let startNodeLoc = startingNode.componentLocation
            let endNodeLoc = endingNode.componentLocation
            if startNodeLoc == compEndLoc {
                // Starting at seam end: arc is just start→endNode
                return parentComponent.split(from: compStartLoc, to: endNodeLoc)
            }
            let part1 = parentComponent.split(from: startNodeLoc, to: compEndLoc)
            if endNodeLoc == compStartLoc {
                // Ending at seam start: arc is just startNode→seam end
                return part1
            }
            let part2 = parentComponent.split(from: compStartLoc, to: endNodeLoc)
            var points = part1.points
            points += part2.points[1...]
            let orders = part1.orders + part2.orders
            return PathComponent(points: points, orders: orders)
        }
        var nextLocation = endingNode.componentLocation
        if nextLocation == parentComponent.startingIndexedLocation {
            nextLocation = parentComponent.endingIndexedLocation
        }
        return parentComponent.split(from: startingNode.componentLocation, to: nextLocation)
    }
    func visitCoincidentEdges() {
        let component = self.component
        let location = component.nonDegenerateTestLocation
        let point = component.point(at: location)
        let normal = component.normal(at: location)
        let smallDistance: CGFloat = AugmentedGraph.smallDistance
        let point1 = point + smallDistance * normal
        let point2 = point - smallDistance * normal
        func edgeIsCoincident(_ edge: Edge) -> Bool {
            let rule: PathFillRule = .evenOdd
            let component = edge.startingNode.pathComponent
            return component.contains(point1, using: rule) != component.contains(point2, using: rule)
        }
        func tValueIsIntervalEnd(_ t: CGFloat) -> Bool {
            return t == 0 || t == 1
        }
        for edge in self.startingNode.neighbors.compactMap({ $0.forwardEdge }) {
            // Skip arcs starting at self's ending node — they travel in the opposite direction
            guard edge.startingNode !== self.endingNode && !edge.startingNode.neighborsContain(self.endingNode) else { continue }
            guard !edge.isWraparound else { continue }
            guard edge.visited == false else { continue }
            guard tValueIsIntervalEnd(self.startingNode.location.t) || tValueIsIntervalEnd(edge.startingNode.location.t) else { continue }
            guard tValueIsIntervalEnd(self.endingNode.location.t) || tValueIsIntervalEnd(edge.endingNode.location.t) else { continue }
            if edge.endingNode.neighborsContain(self.endingNode), edgeIsCoincident(edge) {
                edge.visited = true
            }
        }
        for edge in self.startingNode.neighbors.compactMap({ $0.backwardEdge }) {
            // Skip arcs ending at self's ending node — they travel in the opposite direction
            guard edge.endingNode !== self.endingNode && !edge.endingNode.neighborsContain(self.endingNode) else { continue }
            guard !edge.isWraparound else { continue }
            guard edge.visited == false else { continue }
            guard tValueIsIntervalEnd(self.startingNode.location.t) || tValueIsIntervalEnd(edge.endingNode.location.t) else { continue }
            guard tValueIsIntervalEnd(self.endingNode.location.t) || tValueIsIntervalEnd(edge.startingNode.location.t) else { continue }
            if edge.startingNode.neighborsContain(self.endingNode), edgeIsCoincident(edge) {
                edge.visited = true
            }
        }
    }
}

private class PathComponentGraph {
    private let nodes: [Node]
    init(for path: Path, componentIndex: Int, using intersections: [Node], useWraparound: Bool) {
        var nodes = intersections
        let component = path.components[componentIndex]
        let startingLocation = IndexedPathLocation(componentIndex: componentIndex, locationInComponent: component.startingIndexedLocation)
        let endingLocation = IndexedPathLocation(componentIndex: componentIndex, locationInComponent: component.endingIndexedLocation)
        // For removeCrossings on closed components with intersections, skip the seam node and
        // create a single wrap-around edge from the last intersection to the first. This avoids
        // the seam node splitting the wrap-around arc into two edges with inconsistent classifications.
        let isClosedWithIntersections = component.isClosed && !nodes.isEmpty && useWraparound
        if !isClosedWithIntersections {
            if nodes.first?.location != startingLocation {
                nodes.insert(Node(location: startingLocation, in: path), at: 0)
            }
            if nodes.last?.location != endingLocation {
                nodes.append(Node(location: endingLocation, in: path))
            }
        }
        for i in 1..<nodes.count {
            let startingNode = nodes[i-1]
            let endingNode = nodes[i]
            let edge = Edge(startingNode: startingNode, endingNode: endingNode)
            endingNode.backwardEdge = edge
            startingNode.forwardEdge = edge
        }
        if component.isClosed {
            if isClosedWithIntersections, let last = nodes.last, let first = nodes.first {
                let edge = Edge(startingNode: last, endingNode: first)
                edge.isWraparound = true
                last.forwardEdge = edge
                first.backwardEdge = edge
            } else if let last = nodes.last, let first = nodes.first {
                // No intersections (or non-removeCrossings): close the loop through the seam
                if let secondToLast = last.backwardEdge?.startingNode {
                    let edge = Edge(startingNode: secondToLast, endingNode: first)
                    secondToLast.forwardEdge = edge
                    first.backwardEdge = edge
                }
                first.mergeNeighbors(of: last)
                last.unlink()
                nodes.removeLast()
            }
        }
        self.nodes = nodes
    }
    func forEachNode(callback: (_ node: Node) -> Void) {
        self.nodes.forEach { callback($0) }
    }
    deinit {
        self.forEachNode { $0.unlink() }
    }
}

private class PathGraph {
    let path: Path
    let components: [PathComponentGraph]
    init(for path: Path, using intersections: [Node], useWraparound: Bool) {
        self.path = path
        let intersectionsByComponent = { () -> [[Node]] in
            var temp = [[Node]](repeating: [], count: path.components.count)
            intersections.forEach {
                temp[$0.location.componentIndex].append($0)
            }
            return temp
        }()
        self.components = (0..<path.components.count).map {
            PathComponentGraph(for: path, componentIndex: $0, using: intersectionsByComponent[$0], useWraparound: useWraparound)
        }
    }
}

internal class AugmentedGraph {
    private let operation: BooleanPathOperation
    private let graph1: PathGraph
    private let graph2: PathGraph
    init(path1: Path, path2: Path, intersections: [PathIntersection], operation: BooleanPathOperation) {
        // take the pairwise intersections and make two mutually linked lists of intersections, one for each path
        self.operation = operation
        var path1Intersections: [Node] = []
        var path2Intersections: [Node] = []
        intersections.forEach {
            let node1 = Node(location: $0.indexedPathLocation1, in: path1)
            let node2 = Node(location: $0.indexedPathLocation2, in: path2)
            node1.addNeighbor(node2)
            node2.addNeighbor(node1)
            path1Intersections.append(node1)
            if operation != .removeCrossings {
                path2Intersections.append(node2)
            } else {
                path1Intersections.append(node2)
            }
        }
        // sort each list of intersections and merge intersections that share the same location together
        AugmentedGraph.sortAndMergeDuplicates(of: &path1Intersections)
        if operation != .removeCrossings {
            AugmentedGraph.sortAndMergeDuplicates(of: &path2Intersections)
        }
        // create graph representations of the two paths
        let useWraparound = operation == .removeCrossings
        self.graph1 = PathGraph(for: path1, using: path1Intersections, useWraparound: useWraparound)
        self.graph2 = (operation != .removeCrossings) ? PathGraph(for: path2, using: path2Intersections, useWraparound: false) : graph1
        // mark each edge as either included or excluded from the final result
        self.classifyEdges(in: self.graph1, isForFirstPath: true)
        if operation != .removeCrossings {
            self.classifyEdges(in: self.graph2, isForFirstPath: false)
        }
    }
    func performOperation() -> Path {
        func performOperation(for graph: PathGraph, appendingToComponents list: inout [PathComponent]) {
            graph.components.forEach { componentGraph in
                func findComponent(startingFrom node: Node) {
                    guard let path = findUnvisitedPath(from: node, to: node, preferNeighbors: operation == .removeCrossings) else { return }
                    guard path.count > 0 else { return }
                    list.append(createComponent(using: path))
                }
                // for removeCrossings, process intersection nodes first within each component;
                // this prevents the start node from consuming edges that intersection traversals need.
                // Within intersection nodes, process gap nodes (whose own forward arc is not in solution)
                // before other intersection nodes, so they find their cycles before those arcs are consumed.
                if operation == .removeCrossings {
                    var hasIntersections = false
                    componentGraph.forEachNode { if !$0.neighbors.isEmpty { hasIntersections = true } }
                    if hasIntersections {
                        componentGraph.forEachNode {
                            guard !$0.neighbors.isEmpty else { return }
                            guard $0.forwardEdge?.inSolution != true else { return }
                            findComponent(startingFrom: $0)
                        }
                        componentGraph.forEachNode { guard !$0.neighbors.isEmpty else { return }; findComponent(startingFrom: $0) }
                        componentGraph.forEachNode { guard $0.neighbors.isEmpty else { return }; findComponent(startingFrom: $0) }
                        return
                    }
                }
                componentGraph.forEachNode { findComponent(startingFrom: $0) }
            }
        }
        var components: [PathComponent] = []
        performOperation(for: self.graph1, appendingToComponents: &components)
        if operation != .removeCrossings {
            performOperation(for: self.graph2, appendingToComponents: &components)
        }
        return Path(components: components)
    }
}

private extension AugmentedGraph {
    static var smallDistance: CGFloat {
        return MemoryLayout<CGFloat>.size > 4 ? 1.0e-6 : 1.0e-4
    }
    func classifyEdges(in graph: PathGraph, isForFirstPath: Bool) {
        func classifyEdge(_ edge: Edge) {
            let component = edge.component
            let location = component.nonDegenerateTestLocation
            let point = component.point(at: location)
            let normal = component.normal(at: location)
            // Try progressively larger offsets to handle cases where the test point is
            // very close to another boundary and the small offset cannot distinguish sides.
            let distances: [CGFloat] = MemoryLayout<CGFloat>.size > 4
                ? [1.0e-6, 1.0e-4, 5.0e-3, 5.0e-2]
                : [1.0e-4, 5.0e-3, 5.0e-2]
            for d in distances {
                let point1 = point + d * normal
                let point2 = point - d * normal
                let included1 = self.pointIsContainedInBooleanResult(point: point1, operation: operation)
                let included2 = self.pointIsContainedInBooleanResult(point: point2, operation: operation)
                if included1 != included2 {
                    edge.inSolution = true
                    return
                }
            }
            edge.inSolution = false
        }
        func classifyComponentEdges(in component: PathComponentGraph) {
            component.forEachNode {
                if let edge = $0.forwardEdge {
                    classifyEdge(edge)
                }
            }
        }
        graph.components.forEach { classifyComponentEdges(in: $0) }
    }
    func pointIsContainedInBooleanResult(point: CGPoint, operation: BooleanPathOperation) -> Bool {
        let rule: PathFillRule = (operation == .removeCrossings) ? .winding : .evenOdd
        let contained1 = self.graph1.path.contains(point, using: rule)
        let contained2 = operation != .removeCrossings ? self.graph2.path.contains(point, using: rule) : contained1
        switch operation {
        case .union:
            return contained1 || contained2
        case .intersect:
            return contained1 && contained2
        case .subtract:
            return contained1 && !contained2
        case .removeCrossings:
            return contained1
        }
    }
    static func sortAndMergeDuplicates(of nodes: inout [Node]) {
        guard nodes.count > 1 else { return }
        nodes.sort(by: { $0.location < $1.location })
        var currentUniqueIndex = 0
        for i in 1..<nodes.count {
            let node = nodes[i]
            if node.location == nodes[currentUniqueIndex].location {
                nodes[currentUniqueIndex].mergeNeighbors(of: node)
            } else {
                currentUniqueIndex += 1
                nodes[currentUniqueIndex] = node
            }
        }
        nodes = Array(nodes[0...currentUniqueIndex])
    }
    func findUnvisitedPath(from node: Node, to goal: Node, preferNeighbors: Bool = false) -> [(Edge, Bool)]? {
        func pathUsingEdge(_ edge: Edge?, forwards: Bool) -> [(Edge, Bool)]? {
            guard let edge = edge, edge.needsVisiting else { return nil }
            edge.visited = true
            edge.visitCoincidentEdges()
            let nextNode = forwards ? edge.endingNode : edge.startingNode
            if let path = findUnvisitedPath(from: nextNode, to: goal, preferNeighbors: preferNeighbors) {
                return [(edge, forwards)] + path
            } else {
                edge.visited = false
                return nil
            }
        }
        // We prefer to keep the direction of the path the same which is why
        // we try all the possible forward edges before any back edges.
        // For removeCrossings (preferNeighbors=true), try neighbor edges before own forward edges so that
        // cross-component arcs are explored first, ensuring all in-solution arcs can form valid cycles.
        // Arcs whose next node is the goal (or a neighbor of the goal) are deferred to last: taking them
        // early can close a short inner-face cycle when the correct outer boundary still needs traversal.
        func leadsToGoal(_ edge: Edge?, forwards: Bool) -> Bool {
            guard let edge = edge else { return false }
            let next = forwards ? edge.endingNode : edge.startingNode
            return next === goal || next.neighborsContain(goal)
        }
        func tryForwardEdges() -> [(Edge, Bool)]? {
            if preferNeighbors {
                for neighbor in node.neighbors where !leadsToGoal(neighbor.forwardEdge, forwards: true) {
                    if let result = pathUsingEdge(neighbor.forwardEdge, forwards: true) { return result }
                }
                if !leadsToGoal(node.forwardEdge, forwards: true) {
                    if let result = pathUsingEdge(node.forwardEdge, forwards: true) { return result }
                }
                for neighbor in node.neighbors where leadsToGoal(neighbor.forwardEdge, forwards: true) {
                    if let result = pathUsingEdge(neighbor.forwardEdge, forwards: true) { return result }
                }
                if leadsToGoal(node.forwardEdge, forwards: true) {
                    if let result = pathUsingEdge(node.forwardEdge, forwards: true) { return result }
                }
                return nil
            }
            if let result = pathUsingEdge(node.forwardEdge, forwards: true) { return result }
            for neighbor in node.neighbors {
                if let result = pathUsingEdge(neighbor.forwardEdge, forwards: true) { return result }
            }
            return nil
        }
        func tryBackwardEdges() -> [(Edge, Bool)]? {
            if preferNeighbors {
                for neighbor in node.neighbors where !leadsToGoal(neighbor.backwardEdge, forwards: false) {
                    if let result = pathUsingEdge(neighbor.backwardEdge, forwards: false) { return result }
                }
                if !leadsToGoal(node.backwardEdge, forwards: false) {
                    if let result = pathUsingEdge(node.backwardEdge, forwards: false) { return result }
                }
                for neighbor in node.neighbors where leadsToGoal(neighbor.backwardEdge, forwards: false) {
                    if let result = pathUsingEdge(neighbor.backwardEdge, forwards: false) { return result }
                }
                if leadsToGoal(node.backwardEdge, forwards: false) {
                    if let result = pathUsingEdge(node.backwardEdge, forwards: false) { return result }
                }
                return nil
            }
            if let result = pathUsingEdge(node.backwardEdge, forwards: false) { return result }
            for neighbor in node.neighbors {
                if let result = pathUsingEdge(neighbor.backwardEdge, forwards: false) { return result }
            }
            return nil
        }
        if let result = tryForwardEdges() { return result }
        if let result = tryBackwardEdges() { return result }
        if node === goal || node.neighborsContain(goal) { return [] }
        return nil
    }
    func createComponent(using path: [(Edge, Bool)]) -> PathComponent {
        var points: [CGPoint] = []
        var orders: [Int] = []
        func appendComponent(_ component: PathComponent) {
            if points.isEmpty { points.append(component.startingPoint) }
            points += component.points[1...]
            orders += component.orders
        }
        for (edge, forwards) in path {
            let component = edge.component
            appendComponent(forwards ? component : component.reversed())
        }
        points[points.count - 1] = points[0]
        return PathComponent(points: points, orders: orders)
    }
}

private extension PathComponent {
    var nonDegenerateTestLocation: IndexedPathComponentLocation {
        for i in 0..<numberOfElements {
            let loc = IndexedPathComponentLocation(elementIndex: i, t: 0.5)
            let n = normal(at: loc)
            if n.x.isFinite && n.y.isFinite && n != .zero { return loc }
        }
        return IndexedPathComponentLocation(elementIndex: 0, t: 0.5)
    }
}
