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
        for i in self.neighbors.indices where self.neighbors[i] === node {
            self.neighbors[i] = replacement
        }
    }
    func mergeNeighbors(of node: Node) {
        node.neighbors.forEach {
            $0.replaceNeighbor(node, with: self)
            self.addNeighbor($0)
        }
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
        var nextLocation = endingNode.componentLocation
        if nextLocation == parentComponent.startingIndexedLocation {
            nextLocation = parentComponent.endingIndexedLocation
        }
        return self.endingNode.pathComponent.split(from: startingNode.componentLocation, to: nextLocation)
    }
    func visitCoincidentEdges() {
        let component = self.component
        let location = IndexedPathComponentLocation(elementIndex: 0, t: 0.5)
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
            guard edge.visited == false else { continue }
            guard tValueIsIntervalEnd(self.startingNode.location.t) || tValueIsIntervalEnd(edge.startingNode.location.t) else { continue }
            guard tValueIsIntervalEnd(self.endingNode.location.t) || tValueIsIntervalEnd(edge.endingNode.location.t) else { continue }
            if edge.endingNode.neighborsContain(self.endingNode), edgeIsCoincident(edge) {
                edge.visited = true
            }
        }
        for edge in self.startingNode.neighbors.compactMap({ $0.backwardEdge }) {
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
    init(for path: Path, componentIndex: Int, using intersections: [Node]) {
        var nodes = intersections
        let component = path.components[componentIndex]
        let startingLocation = IndexedPathLocation(componentIndex: componentIndex, locationInComponent: component.startingIndexedLocation)
        let endingLocation = IndexedPathLocation(componentIndex: componentIndex, locationInComponent: component.endingIndexedLocation)
        if nodes.first?.location != startingLocation {
            nodes.insert(Node(location: startingLocation, in: path), at: 0)
        }
        if nodes.last?.location != endingLocation {
            nodes.append(Node(location: endingLocation, in: path))
        }
        for i in 1..<nodes.count {
            let startingNode = nodes[i-1]
            let endingNode = nodes[i]
            let edge = Edge(startingNode: startingNode, endingNode: endingNode)
            endingNode.backwardEdge = edge
            startingNode.forwardEdge = edge
        }
        // loop back the end to the start (if needed)
        if component.isClosed, let last = nodes.last, let first = nodes.first {
            if let secondToLast = last.backwardEdge?.startingNode {
                let edge = Edge(startingNode: secondToLast, endingNode: first)
                secondToLast.forwardEdge = edge
                first.backwardEdge = edge
            }
            first.mergeNeighbors(of: last)
            last.unlink()
            nodes.removeLast()
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
    init(for path: Path, using intersections: [Node]) {
        self.path = path
        let intersectionsByComponent = { () -> [[Node]] in
            var temp = [[Node]](repeating: [], count: path.components.count)
            intersections.forEach {
                temp[$0.location.componentIndex].append($0)
            }
            return temp
        }()
        self.components = (0..<path.components.count).map {
            PathComponentGraph(for: path, componentIndex: $0, using: intersectionsByComponent[$0])
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
        self.graph1 = PathGraph(for: path1, using: path1Intersections)
        self.graph2 = (operation != .removeCrossings) ? PathGraph(for: path2, using: path2Intersections) : graph1
        // mark each edge as either included or excluded from the final result
        self.classifyEdgesUsingWindingCount(in: self.graph1, isForFirstPath: true)
        if operation != .removeCrossings {
            self.classifyEdgesUsingWindingCount(in: self.graph2, isForFirstPath: false)
        }
    }
    func performOperation() -> Path {
        func performOperation(for graph: PathGraph, appendingToComponents list: inout [PathComponent]) {
            graph.components.forEach {
                $0.forEachNode { node in
                    guard let path = findUnvisitedPath(from: node, to: node) else { return }
                    guard path.count > 0 else { return }
                    list.append(self.createComponent(using: path))
                }
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

    // MARK: - Winding-count propagation edge classification

    /// The change in the winding count of path2 (at a point just to the left of path1) as we
    /// move forward through an intersection node along path1.
    ///
    /// `n1Out` is the left-perpendicular normal of path1's outgoing edge (the edge that
    /// leaves this node).  When path1 is smooth at the node, n1Out equals the node's own
    /// incoming normal and the original sign(n2 × n1) formula applies.
    ///
    /// When path1 has a corner at the node (n1Out ≠ incoming normal), the tracking point
    /// sweeps an arc from n1In to n1Out in the direction of path1's turn.  A path2 segment
    /// is counted only if its normal n2 lies strictly inside that arc, determined by:
    ///   (n1In × n2) and (n2 × n1Out) both having the same sign as (n1In × n1Out).
    /// This prevents both the false delta from anti-parallel coincident edges and the false
    /// delta from path2 segments that lie outside the swept arc at touching corners.
    static func windingCountDelta(atNode node: Node, fromNeighbors neighbors: [Node], outgoingNormal n1Out: CGPoint) -> Int {
        guard !neighbors.isEmpty else { return 0 }
        let n1In = node.pathComponent.normal(at: node.componentLocation)
        guard n1In.x.isFinite, n1In.y.isFinite else { return 0 }
        guard n1Out.x.isFinite, n1Out.y.isFinite else { return 0 }
        // Detect a corner of path1: cross product of incoming and outgoing normals is nonzero.
        let turnDir = n1In.x * n1Out.y - n1In.y * n1Out.x  // n1In × n1Out; sign encodes CCW vs CW turn
        let isCorner = abs(turnDir) > 1e-10
        return neighbors.reduce(0) { total, neighbor in
            let n2 = neighbor.pathComponent.normal(at: neighbor.componentLocation)
            guard n2.x.isFinite, n2.y.isFinite else { return total }
            if isCorner {
                // Arc-crossing condition: n2 must lie strictly inside the arc swept from
                // n1In to n1Out.  Both intermediate cross products must share the sign of
                // turnDir (the turn direction), which places n2 between the two bounding
                // normals in the correct rotational sense.
                let cross1 = n1In.x * n2.y - n1In.y * n2.x  // n1In × n2
                let cross2 = n2.x * n1Out.y - n2.y * n1Out.x // n2 × n1Out
                guard turnDir * cross1 > 0 && turnDir * cross2 > 0 else { return total }
            }
            let cross = n2.x * n1In.y - n2.y * n1In.x
            if cross > 0 { return total + 1 }
            if cross < 0 { return total - 1 }
            return total
        }
    }

    /// Whether an edge should appear in the boolean result, given the winding count of the
    /// *other* path at a point just to the left of the edge.
    ///
    /// For binary operations the paths use the even-odd fill rule, so containment is
    /// `abs(w) % 2 == 1`.  An edge of path1 is on the solution boundary when crossing it
    /// changes the boolean result value, which simplifies per operation to the rules below.
    func edgeIsInSolution(windingCountOfOther w: Int, isForFirstPath: Bool) -> Bool {
        switch self.operation {
        case .union:
            // Keep path1 edges outside path2, and path2 edges outside path1.
            return w % 2 == 0
        case .subtract:
            // Keep path1 edges outside path2; keep path2 edges inside path1.
            return isForFirstPath ? (w % 2 == 0) : (w % 2 != 0)
        case .intersect:
            // Keep edges that are inside the other path.
            return w % 2 != 0
        case .removeCrossings:
            // Keep edges where the winding count crosses the zero boundary (winding rule).
            // The left-side winding count w and right-side (w−1) must differ in sign of
            // "is nonzero", which happens exactly when w ∈ {0, 1}.
            return w == 0 || w == 1
        }
    }

    func classifyEdgesUsingWindingCount(in graph: PathGraph, isForFirstPath: Bool) {
        let otherPath = isForFirstPath ? self.graph2.path : self.graph1.path
        graph.components.forEach { componentGraph in
            classifyComponentEdgesUsingWindingCount(
                componentGraph,
                otherPath: otherPath,
                isForFirstPath: isForFirstPath
            )
        }
    }

    func classifyComponentEdgesUsingWindingCount(
        _ componentGraph: PathComponentGraph,
        otherPath: Path,
        isForFirstPath: Bool
    ) {
        var nodes: [Node] = []
        componentGraph.forEachNode { nodes.append($0) }
        guard !nodes.isEmpty, let firstEdge = nodes[0].forwardEdge else { return }

        // Determine which path the "other" neighbors belong to so we can filter correctly.
        // For removeCrossings graph2 === graph1, so all neighbors are from the same path.
        let otherGraphPath = isForFirstPath ? self.graph2.path : self.graph1.path

        // Compute the initial winding count of otherPath at a point just to the LEFT of
        // the first edge's midpoint.  We always apply a tiny left-normal offset so that
        // a seed point exactly on otherPath's boundary doesn't return 0 due to the strict
        // inequality in the ray-cast winding algorithm.  The seed is at t=0.5 of the first
        // edge's element, which is in the interior of an edge and far from any intersection.
        let midLocation = IndexedPathComponentLocation(elementIndex: 0, t: 0.5)
        let firstEdgeComponent = firstEdge.component
        let midPoint = firstEdgeComponent.point(at: midLocation)
        let normal = firstEdgeComponent.normal(at: midLocation)
        let seedPoint = normal.x.isFinite && normal.y.isFinite
            ? midPoint + AugmentedGraph.smallDistance * normal
            : midPoint
        let initialWinding = otherPath.windingCount(seedPoint)

        // Walk every edge of this component in order, classifying each one and propagating
        // the winding count across intersection nodes using the crossing-direction formula.
        var windingCount = initialWinding
        var currentNode = nodes[0]
        let startNode = currentNode
        var firstIteration = true

        while firstIteration || currentNode !== startNode {
            firstIteration = false
            guard let edge = currentNode.forwardEdge else { break }

            edge.inSolution = edgeIsInSolution(windingCountOfOther: windingCount,
                                               isForFirstPath: isForFirstPath)

            // Advance to the ending node and update the winding count for any crossings there.
            let endingNode = edge.endingNode
            let otherNeighbors = endingNode.neighbors.filter { $0.path === otherGraphPath }
            // Outgoing normal: the left-perpendicular of path1 at the start of the next edge.
            // For smooth nodes this equals the node's own normal; for corners it differs,
            // enabling the arc-crossing corner correction in windingCountDelta.
            let startLoc = IndexedPathComponentLocation(elementIndex: 0, t: 0.0)
            let n1Out = endingNode.forwardEdge.map { $0.component.normal(at: startLoc) }
                ?? endingNode.pathComponent.normal(at: endingNode.componentLocation)
            windingCount += AugmentedGraph.windingCountDelta(atNode: endingNode,
                                                             fromNeighbors: otherNeighbors,
                                                             outgoingNormal: n1Out)
            currentNode = endingNode
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
    func findUnvisitedPath(from node: Node, to goal: Node) -> [(Edge, Bool)]? {
        func pathUsingEdge(_ edge: Edge?, from node: Node, forwards: Bool) -> [(Edge, Bool)]? {
            guard let edge = edge, edge.needsVisiting else { return nil }
            edge.visited = true
            edge.visitCoincidentEdges()
            let nextNode = forwards ? edge.endingNode : edge.startingNode
            if let path = findUnvisitedPath(from: nextNode, to: goal) {
                return [(edge, forwards)] + path
            } else {
                return nil
            }
        }
        // we prefer to keep the direction of the path the same which is why
        // we try all the possible forward edges before any back edges
        if let result = pathUsingEdge(node.forwardEdge, from: node, forwards: true) { return result }
        for neighbor in node.neighbors {
            if let result = pathUsingEdge(neighbor.forwardEdge, from: neighbor, forwards: true) { return result }
        }
        if let result = pathUsingEdge(node.backwardEdge, from: node, forwards: false) { return result }
        for neighbor in node.neighbors {
            if let result = pathUsingEdge(neighbor.backwardEdge, from: neighbor, forwards: false) { return result }
        }
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
