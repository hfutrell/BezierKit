//
//  AugmentedGraph.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/28/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import CoreGraphics

private class Node {
    let location: IndexedPathLocation
    var componentLocation: IndexedPathComponentLocation {
        return IndexedPathComponentLocation(elementIndex: self.location.elementIndex, t: self.location.t)
    }
    var next: Node?
    var previous: Node?
    var edge = Edge()
    var neighbors: [Node] = []
    unowned var pathComponent: PathComponent
    init(location: IndexedPathLocation, pathComponent: PathComponent) {
        self.location = location
        self.pathComponent = pathComponent
    }
    func neighborsContain(_ node: Node) -> Bool {
        return self.neighbors.contains(where: { $0 === node })
    }
    func addNeighbor(_ node: Node) {
        guard self.neighborsContain(node) == false else { return }
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
    func forwardComponent(to node: Node) -> PathComponent {
        var nextLocation = node.componentLocation
        if nextLocation == self.pathComponent.startingIndexedLocation {
            nextLocation = self.pathComponent.endingIndexedLocation
        }
        return self.pathComponent.split(from: self.componentLocation, to: nextLocation)
    }
    func backwardComponent(to node: Node) -> PathComponent {
        var startingLocation = self.componentLocation
        if startingLocation == self.pathComponent.startingIndexedLocation {
            startingLocation = self.pathComponent.endingIndexedLocation
        }
        return self.pathComponent.split(from: startingLocation, to: node.componentLocation)
    }
}

private class Edge {
    var visited: Bool = false
    var inSolution: Bool = false
    init() {
        self.visited = false
        self.inSolution = false
    }
}

// TODO: revert public scope
public enum BooleanPathOperation {
    case union
    case subtract
    case intersect
    case removeCrossings
}

private class PathComponentGraph {
    /// Create the graph representing the component and return the first node (which represents the start of the first edge)
    private let nodes: [Node]
    init(for component: PathComponent, componentIndex: Int, using intersections: [Node]) {
        var endCappedIntersections = intersections
        let startingLocation = IndexedPathLocation(componentIndex: componentIndex, elementIndex: component.startingIndexedLocation.elementIndex, t: component.startingIndexedLocation.t)
        let endingLocation = IndexedPathLocation(componentIndex: componentIndex, elementIndex: component.endingIndexedLocation.elementIndex, t: component.endingIndexedLocation.t)
        if endCappedIntersections.first?.location != startingLocation {
            endCappedIntersections.insert(Node(location: startingLocation, pathComponent: component), at: 0)
        }
        if endCappedIntersections.last?.location != endingLocation {
            endCappedIntersections.append(Node(location: endingLocation, pathComponent: component))
        }
        for i in 0..<endCappedIntersections.count {
            if i > 0 {
                endCappedIntersections[i].previous = endCappedIntersections[i-1]
            }
            if i < endCappedIntersections.count-1 {
                endCappedIntersections[i].next = endCappedIntersections[i+1]
            }
        }
        // loop back the end to the start (if needed)
        if component.isClosed {
            // if the component is closed then the first and last nodes are really the same node
            let last = endCappedIntersections.last!
            let first = endCappedIntersections.first!
            first.previous = last.previous
            last.previous?.next = first
            first.mergeNeighbors(of: last)
            endCappedIntersections.removeLast()
        }
        self.nodes = endCappedIntersections
    }
    func forEachNode(callback: (_ node: Node, _ stop: inout Bool) -> Void) {
        var stop = false
        for node in self.nodes {
            callback(node, &stop)
            guard stop == false else { return }
        }
    }
}

private class PathGraph {
    let path: Path
    let components: [PathComponentGraph]
    init(for path: Path, using intersections: [Node]) {
        // first file each intersection by component index
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

// TODO: revert public scope
public final class AugmentedGraph {
    private let operation: BooleanPathOperation
    private let graph1: PathGraph
    private let graph2: PathGraph
    public init(path1: Path, path2: Path, intersections: [PathIntersection], operation: BooleanPathOperation) {
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
        self.classifyEdges(for: self.graph1, isForFirstPath: true)
        if operation != .removeCrossings {
            self.classifyEdges(for: self.graph2, isForFirstPath: false)
        }
    }
    public func draw(_ context: CGContext) {
        func drawGraph(_ graph: PathGraph) {
            for i in 0..<graph.components.count {
                graph.components[i].forEachNode { node, _ in
                    guard let nextNode = node.next else { return }
                    switch node.edge.inSolution {
                    case true:
                        Draw.setColor(context, color: Draw.red)
                    case false:
                        Draw.setColor(context, color: Draw.green)
                    }
                    for curve in node.forwardComponent(to: nextNode).curves {
                        Draw.drawCurve(context, curve: curve)
                    }
                }
            }
        }
        drawGraph(self.graph1)
        drawGraph(self.graph2)
        Draw.reset(context)
    }
    internal func performOperation() -> Path {
        func performOperation(for graph: PathGraph, appendingToComponents list: inout [PathComponent]) {
            graph.components.forEach {
                $0.forEachNode { node, _ in
                    guard node.edge.inSolution == true, node.edge.visited == false else { return }
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
    /// traverses the list of edges and marks each edge as either .internal, .external, or .coincident with respect to `self.path`
    func classifyEdges(for graph: PathGraph, isForFirstPath: Bool) {
        func classifyEdge(for node: Node) {
            // TODO: we use a crummy point location
            guard let nextNode = node.next else { return }
            let component = node.forwardComponent(to: nextNode)
            let nextEdge = component.element(at: 0)
            let point = nextEdge.compute(0.5)
            let normal = nextEdge.normal(0.5)
            let smallDistance = CGFloat(Utils.epsilon)
            let point1 = point + smallDistance * normal
            let point2 = point - smallDistance * normal
            let included1 = self.pointIsContainedInBooleanResult(point: point1, operation: operation)
            let included2 = self.pointIsContainedInBooleanResult(point: point2, operation: operation)
            node.edge.inSolution = (included1 != included2)
            if !isForFirstPath, node.edge.inSolution, operation != .removeCrossings {
                // remove duplicate coincident edges
                let rule: PathFillRule = .evenOdd
                let edge1 = self.graph1.path.contains(point1, using: rule) != self.graph1.path.contains(point2, using: rule)
                let edge2 = self.graph2.path.contains(point1, using: rule) != self.graph2.path.contains(point2, using: rule)
                if edge1, edge2 {
                    node.edge.inSolution = false
                }
            }
        }
        func classifyEdges(for component: PathComponentGraph) {
            component.forEachNode { node, _ in
                classifyEdge(for: node)
            }
        }
        graph.components.forEach { classifyEdges(for: $0) }
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
        var duplicatesRemoved = [nodes[0]]
        duplicatesRemoved.reserveCapacity(nodes.count)
        for i in 1..<nodes.count {
            if nodes[i].location == duplicatesRemoved.last!.location {
                duplicatesRemoved.last!.mergeNeighbors(of: nodes[i])
            } else {
                duplicatesRemoved.append(nodes[i])
            }
        }
        nodes = duplicatesRemoved
    }
    func createComponent(from startingNode: Node) -> PathComponent {
        let firstPoint = startingNode.pathComponent.point(at: startingNode.componentLocation)
        var points: [CGPoint] = [firstPoint]
        var orders: [Int] = []
        func visit(from node: Node) -> Node? {
            if let next = node.next {
                let forwardEdge = node.edge
                if forwardEdge.inSolution, forwardEdge.visited == false {
                    let component = node.forwardComponent(to: next)
                    visit(component)
                    forwardEdge.visited = true
                    return next
                }
            } else {
                assert(node.pathComponent.isClosed == false, "expected next node to exist")
            }
            if let previous = node.previous {
                let backwardsEdge = previous.edge
                if backwardsEdge.inSolution, backwardsEdge.visited == false {
                    let component = node.backwardComponent(to: previous)
                    visit(component)
                    backwardsEdge.visited = true
                    return previous
                }
            } else {
                assert(node.pathComponent.isClosed == false, "expected previous node to exist")
            }
            return nil
        }
        func visit(_ component: PathComponent) {
            points += component.points[1..<component.points.count]
            orders += component.orders
        }
        var currentNode = startingNode
        repeat {
            var nextNode = visit(from: currentNode)
            if nextNode == nil {
                for neighbor in currentNode.neighbors {
                    nextNode = visit(from: neighbor)
                    if nextNode != nil { break }
                }
            }
            if let nextNode = nextNode {
                currentNode = nextNode
            } else {
                break
            }
        } while true
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
