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
    var componentLocation: IndexedPathComponentLocation { return IndexedPathComponentLocation(elementIndex: self.location.elementIndex, t: self.location.t) }
    var next: Node?
    var previous: Node?
    var edge: Edge?
    /// links to locations on neighboring paths, indexed by path number
    var neighbors = [Node]()
    init(location: IndexedPathLocation) {
        self.location = location
    }
    func addNeighbor(_ neighbor: Node) {
        guard self.neighbors.allSatisfy({ $0 !== neighbor }) else { return }
        neighbors.append(neighbor)
    }
    func replaceNeighborReference(_ node: Node, with replacement: Node) {
        for i in neighbors.indices where neighbors[i] === node {
            neighbors[i] = replacement
        }
    }
    func mergeNeighbors(of node: Node) {
        for neighbor in node.neighbors {
            neighbor.replaceNeighborReference(node, with: self)
            self.addNeighbor(neighbor)
        }
    }
}

private class Edge {
    var visited: Bool = false
    var inSolution: Bool = false
    let component: PathComponent
    init(component: PathComponent) {
        self.component = component
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
public final class AugmentedGraph {

    private let operation: BooleanPathOperation
    private let path1: Path
    private let path2: Path
    private let graph1: [Node]
    private let graph2: [Node]

    public init(path1: Path, path2: Path, intersections: [PathIntersection], operation: BooleanPathOperation) {
        self.operation = operation
        self.path1 = path1
        self.path2 = path2
        // take the pairwise intersections and make two mutually linked lists of intersections, one for each path
        var path1Intersections: [Node] = []
        var path2Intersections: [Node] = []
        intersections.forEach {
            let node1 = Node(location: $0.indexedPathLocation1)
            let node2 = Node(location: $0.indexedPathLocation2)
            node1.addNeighbor(node2 /*, pathNumber: 1 */)
            node2.addNeighbor(node1 /*, pathNumber: 0 */)
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
        self.graph1 = AugmentedGraph.createGraph(for: self.path1, using: path1Intersections)
        self.graph2 = (operation != .removeCrossings) ? AugmentedGraph.createGraph(for: self.path2, using: path2Intersections) : graph1
        // mark each edge as either included or excluded from the final result
        self.classifyEdges(in: graph1)
        if operation != .removeCrossings {
            self.classifyEdges(in: graph2)
        }
    }

    public func draw(_ context: CGContext) {
        func drawList(_ list: [Node]) {
            for i in 0..<list.count {
                self.forEachNode(in: list[i]) { node, _ in

                    switch node.edge!.inSolution {
                    case true:
                        Draw.setColor(context, color: Draw.red)
                    case false:
                        Draw.setColor(context, color: Draw.green)
                    }

                    for curve in node.edge!.component.curves {
                        Draw.drawCurve(context, curve: curve)
                    }
                }
            }
        }
        drawList(self.graph1)
        drawList(self.graph2)
        Draw.reset(context)
    }

    internal func performOperation() -> Path {
        func performOperation(for components: [Node], appendingToComponents list: inout [PathComponent]) {
            components.forEach {
                self.forEachNode(in: $0) { node, _ in
                    guard node.edge?.inSolution == true, node.edge?.visited == false else { return }
                    list.append(self.createComponent(from: node))
                }
            }
        }
        var components = [PathComponent]()
        performOperation(for: self.graph1, appendingToComponents: &components)
        performOperation(for: self.graph2, appendingToComponents: &components)
        return Path(components: components)
    }
}

private extension AugmentedGraph {

    func pointIsContainedInBooleanResult(point: CGPoint, operation: BooleanPathOperation) -> Bool {
        let rule: PathFillRule = (operation == .removeCrossings) ? .winding : .evenOdd
        let contained1 = self.path1.contains(point, using: rule)
        let contained2 = operation != .removeCrossings ? self.path2.contains(point, using: rule) : contained1
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

    /// traverses the list of edges and marks each edge as either .internal, .external, or .coincident with respect to `path`
    func classifyEdges(in graph: [Node]) {
        func classifyEdge(_ edge: Edge) {
            // TODO: we use a crummy point location
            let nextEdge = edge.component.element(at: 0)
            let point = nextEdge.compute(0.5)
            let normal = nextEdge.normal(0.5)
            let smallDistance = CGFloat(Utils.epsilon)
            let included1 = self.pointIsContainedInBooleanResult(point: point + smallDistance * normal, operation: operation)
            let included2 = self.pointIsContainedInBooleanResult(point: point - smallDistance * normal, operation: operation)
            edge.inSolution = (included1 != included2)
        }
        func classifyEdges(in component: Node) {
            self.forEachNode(in: component) { node, _ in
                classifyEdge(node.edge!)
            }
        }
        graph.forEach { classifyEdges(in: $0) }
    }

    func forEachNode(in component: Node, callback: (_ node: Node, _ stop: inout Bool) -> Void) {
        var currentNode = component
        var stop: Bool = false
        repeat {
            callback(currentNode, &stop)
            guard stop == false else { return }
            guard let nextNode = currentNode.next else { return }
            guard nextNode !== component else { return }
            currentNode = nextNode
        } while true
    }

    /// Create the graph representing the component and return the first node (which represents the start of the first edge)
    static func createGraph(for component: PathComponent, componentIndex: Int, using intersections: [Node]) -> Node {
        var endCappedIntersections = intersections
        let startingLocation = IndexedPathLocation(componentIndex: componentIndex, elementIndex: component.startingIndexedLocation.elementIndex, t: component.startingIndexedLocation.t)
        let endingLocation = IndexedPathLocation(componentIndex: componentIndex, elementIndex: component.endingIndexedLocation.elementIndex, t: component.endingIndexedLocation.t)

        if endCappedIntersections.first?.location != startingLocation {
            endCappedIntersections.insert(Node(location: startingLocation), at: 0)
        }
        if endCappedIntersections.last?.location != endingLocation {
            endCappedIntersections.append(Node(location: endingLocation))
        }

        for i in 0..<endCappedIntersections.count {
            if i > 0 {
                endCappedIntersections[i].previous = endCappedIntersections[i-1]
            }
            if i < endCappedIntersections.count-1 {
                endCappedIntersections[i].next = endCappedIntersections[i+1]
            }
        }

        // create the components for the edges
        let subcomponents = (0..<endCappedIntersections.count-1).map { (index: Int) -> PathComponent in
            let range = PathComponentRange(start: endCappedIntersections[index].componentLocation, end: endCappedIntersections[index + 1].componentLocation)
            return component.split(range: range)
        }
        // create the edges between the intersections
        for index in 0..<endCappedIntersections.count-1 {
            let edge = Edge(component: subcomponents[index])
            endCappedIntersections[index].edge = edge
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
        return endCappedIntersections.first!
    }

    static func createGraph(for path: Path, using intersections: [Node]) -> [Node] {
        // first file each intersection by component index
        let intersectionsByComponent = { () -> [[Node]] in
            var temp = [[Node]](repeating: [], count: path.components.count)
            intersections.forEach {
                temp[$0.location.componentIndex].append($0)
            }
            return temp
        }()
        return (0..<path.components.count).map {
            AugmentedGraph.createGraph(for: path.components[$0], componentIndex: $0, using: intersectionsByComponent[$0])
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

    func createComponent(from node: Node) -> PathComponent {
        var points: [CGPoint] = [node.edge!.component.startingPoint]
        var orders = [Int]()
        func visit(from node: Node) -> Node? {
            guard let forwardEdge = node.edge else {
                assertionFailure("consistency failure")
                return nil
            }
            guard let backwardsEdge = node.previous?.edge else {
                assertionFailure("consistency failure")
                return nil
            }
            if forwardEdge.inSolution, forwardEdge.visited == false {
                visit(forwardEdge.component)
                forwardEdge.visited = true
                return node.next
            } else if backwardsEdge.inSolution, backwardsEdge.visited == false {
                visit(backwardsEdge.component.reversed())
                backwardsEdge.visited = true
                return node.previous
            } else {
                return nil
            }
        }
        func visit(_ component: PathComponent) {
            points += component.points[1..<component.points.count]
            orders += component.orders
        }
        var nextNode: Node? = node
        while let currentNode = nextNode {
            nextNode = nil
            if let temp = visit(from: currentNode) {
                nextNode = temp
            } else {
                for neighbor in currentNode.neighbors {
                    if let temp = visit(from: neighbor) {
                        nextNode = temp
                        break
                    }
                }
            }
        }
        if points.last != points.first {
            points.append(points.first!)
            orders.append(1)
        }
        return PathComponent(points: points, orders: orders)
    }
}
