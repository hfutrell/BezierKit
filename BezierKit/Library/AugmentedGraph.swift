//
//  AugmentedGraph.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/28/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import CoreGraphics

internal enum BooleanPathOperation {
    case union
    case subtract
    case intersect
    case removeCrossings
}

private class Node {
    let location: IndexedPathLocation
    var componentLocation: IndexedPathComponentLocation {
        return IndexedPathComponentLocation(elementIndex: self.location.elementIndex, t: self.location.t)
    }
    var forwardEdge: Edge?
    var backwardEdge: Edge?
    private(set) var neighbors: [Node] = []
    let pathComponent: PathComponent
    init(location: IndexedPathLocation, pathComponent: PathComponent) {
        self.location = location
        self.pathComponent = pathComponent
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
}

private class PathComponentGraph {
    private let nodes: [Node]
    init(for component: PathComponent, componentIndex: Int, using intersections: [Node]) {
        var nodes = intersections
        let startingLocation = IndexedPathLocation(componentIndex: componentIndex, elementIndex: component.startingIndexedLocation.elementIndex, t: component.startingIndexedLocation.t)
        let endingLocation = IndexedPathLocation(componentIndex: componentIndex, elementIndex: component.endingIndexedLocation.elementIndex, t: component.endingIndexedLocation.t)
        if nodes.first?.location != startingLocation {
            nodes.insert(Node(location: startingLocation, pathComponent: component), at: 0)
        }
        if nodes.last?.location != endingLocation {
            nodes.append(Node(location: endingLocation, pathComponent: component))
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
            PathComponentGraph(for: path.components[$0], componentIndex: $0, using: intersectionsByComponent[$0])
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
            let node1 = Node(location: $0.indexedPathLocation1, pathComponent: path1.components[$0.indexedPathLocation1.componentIndex])
            let node2 = Node(location: $0.indexedPathLocation2, pathComponent: path2.components[$0.indexedPathLocation2.componentIndex])
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
        self.classifyEdges(in: self.graph1, isForFirstPath: true)
        if operation != .removeCrossings {
            self.classifyEdges(in: self.graph2, isForFirstPath: false)
        }
    }
    func performOperation() -> Path {
        func performOperation(for graph: PathGraph, appendingToComponents list: inout [PathComponent]) {
            graph.components.forEach {
                $0.forEachNode { node in
                    guard let edge = node.forwardEdge, edge.needsVisiting else { return }
                    list.append(self.createComponent(from: node))
                }
            }
        }
        var components: [PathComponent] = []
        performOperation(for: self.graph1, appendingToComponents: &components)
        performOperation(for: self.graph2, appendingToComponents: &components)
        return Path(components: components)
    }
}

private extension AugmentedGraph {
    func classifyEdges(in graph: PathGraph, isForFirstPath: Bool) {
        func classifyEdge(_ edge: Edge) {
            // TODO: we use a crummy point location
            let component = edge.component
            let nextEdge = component.element(at: 0)
            let point = nextEdge.compute(0.5)
            let normal = nextEdge.normal(0.5)
            let smallDistance: CGFloat = 1.0e-5
            let point1 = point + smallDistance * normal
            let point2 = point - smallDistance * normal
            let included1 = self.pointIsContainedInBooleanResult(point: point1, operation: operation)
            let included2 = self.pointIsContainedInBooleanResult(point: point2, operation: operation)
            edge.inSolution = (included1 != included2)
            if !isForFirstPath, edge.inSolution, operation != .removeCrossings {
                // remove duplicate coincident edges
                let rule: PathFillRule = .evenOdd
                let edge1 = self.graph1.path.contains(point1, using: rule) != self.graph1.path.contains(point2, using: rule)
                let edge2 = self.graph2.path.contains(point1, using: rule) != self.graph2.path.contains(point2, using: rule)
                if edge1, edge2 {
                    edge.inSolution = false
                }
            }
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
    func createComponent(from startingNode: Node) -> PathComponent {
        let firstPoint = startingNode.pathComponent.point(at: startingNode.componentLocation)
        var points: [CGPoint] = [firstPoint]
        var orders: [Int] = []
        func appendComponent(_ component: PathComponent) {
            points += component.points[1...]
            orders += component.orders
        }
        func visitEdge(_ edge: Edge, forwards: Bool) -> Node {
            let component = edge.component
            appendComponent(forwards ? component : component.reversed())
            edge.visited = true
            return forwards ? edge.endingNode : edge.startingNode
        }
        func visitNextNode(from node: Node) -> Node? {
            if let edge = node.forwardEdge, edge.needsVisiting {
                return visitEdge(edge, forwards: true)
            } else if let edge = node.backwardEdge, edge.needsVisiting {
                return visitEdge(edge, forwards: false)
            }
            return node.neighbors.first {
                $0.forwardEdge?.needsVisiting == true || $0.backwardEdge?.needsVisiting == true
            }
        }
        var currentNode = startingNode
        while let nextNode = visitNextNode(from: currentNode) {
            currentNode = nextNode
        }
        if points.count > 1, currentNode !== startingNode {
            // if we ended at a node that's not equal to where we started, we may need
            // to close the current component
            if currentNode.neighborsContain(startingNode) {
                points[points.index(before: points.endIndex)] = firstPoint
            } else {
                points.append(firstPoint)
                orders.append(1)
            }
        }
        return PathComponent(points: points, orders: orders)
    }
}
