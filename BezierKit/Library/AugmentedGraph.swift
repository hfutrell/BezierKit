//
//  AugmentedGraph.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/28/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import CoreGraphics

internal class IntersectionNode {
    let location: IndexedPathLocation
    var componentLocation: IndexedPathComponentLocation { return IndexedPathComponentLocation(elementIndex: self.location.elementIndex, t: self.location.t) }
    var next: IntersectionNode?
    var previous: IntersectionNode?
    var edge: Edge?
    var isIntersection: Bool
    /// links to locations on neighboring paths, indexed by path number
    var neighbors: [Int: [IntersectionNode]] = [:]
    init(location: IndexedPathLocation, isIntersection: Bool) {
        self.location = location
        self.isIntersection = isIntersection
    }
    func addNeighbor(_ neighbor: IntersectionNode, pathNumber: Int) {
        if neighbors[pathNumber] == nil { neighbors[pathNumber] = [] }
        neighbors[pathNumber]!.append(neighbor)
    }
    func mergeNeighbors(of node: IntersectionNode) {
        // TODO: point the links from node.neighbors.neighbors back to self

        // point the links from self.neighbors to node.neighbors
        for (key, value) in node.neighbors {
            for node in value {
                self.addNeighbor(node, pathNumber: key)
            }
        }
    }
}

internal class Edge {
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
    private let graph1: [IntersectionNode]
    private let graph2: [IntersectionNode]

    public func draw(_ context: CGContext) {
        func drawList(_ list: [IntersectionNode]) {
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

    private func pointIsContainedInBooleanResult(point: CGPoint, operation: BooleanPathOperation) -> Bool {
        let rule: PathFillRule = (operation == .removeCrossings) ? .winding : .evenOdd
        let contained1 = self.path1.contains(point, using: rule)
        guard operation != .removeCrossings else { return contained1 }
        let contained2 = self.path2.contains(point, using: rule)
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

    private func classifyEdge(_ edge: Edge) {
        // TODO: we use a crummy point location
        let nextEdge = edge.component.element(at: 0)
        let point = nextEdge.compute(0.5)
        let normal = nextEdge.normal(0.5)
        let smallDistance = CGFloat(Utils.epsilon)
        let included1 = self.pointIsContainedInBooleanResult(point: point + smallDistance * normal, operation: operation)
        let included2 = self.pointIsContainedInBooleanResult(point: point - smallDistance * normal, operation: operation)
        edge.inSolution = (included1 != included2)
    }

    private func classifyEdges(in component: IntersectionNode) {
        self.forEachNode(in: component) { node, _ in
            let edge = node.edge
            self.classifyEdge(edge!)
        }
    }

    /// traverses the list of edges and marks each edge as either .internal, .external, or .coincident with respect to `path`
    private func classifyEdges(in graph: [IntersectionNode]) {
        graph.forEach { self.classifyEdges(in: $0) }
    }

    private func firstNode(in component: IntersectionNode, where callback: (_ node: IntersectionNode) -> Bool) -> IntersectionNode? {
        var value: IntersectionNode?
        self.forEachNode(in: component) { node, stop in
            if callback(node) {
                stop = true
                value = node
            }
        }
        return value
    }

    private func forEachNode(in component: IntersectionNode, callback: (_ node: IntersectionNode, _ stop: inout Bool) -> Void) {
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

    func findNeighbor(for node: IntersectionNode, in graph: [IntersectionNode], at locationInNeighbor: IndexedPathLocation ) -> IntersectionNode? {
        let neighborComponent = graph[locationInNeighbor.componentIndex]
        return self.firstNode(in: neighborComponent) { node in
            node.location.elementIndex == locationInNeighbor.elementIndex && node.location.t == locationInNeighbor.t
        }
    }

    /// Create the graph representing the component and return the first node (which represents the start of the first edge)
    static func createGraph(for component: PathComponent, componentIndex: Int, using intersections: [IntersectionNode]) -> IntersectionNode {
        var endCappedIntersections = intersections
        
        let startingLocation = IndexedPathLocation(componentIndex: componentIndex, elementIndex: component.startingIndexedLocation.elementIndex, t: component.startingIndexedLocation.t)
        let endingLocation = IndexedPathLocation(componentIndex: componentIndex, elementIndex: component.endingIndexedLocation.elementIndex, t: component.endingIndexedLocation.t)

        if endCappedIntersections.isEmpty || endCappedIntersections.first!.location != startingLocation {
            endCappedIntersections.insert(IntersectionNode(location: startingLocation, isIntersection: false), at: 0)
        }
        if endCappedIntersections.last!.location != endingLocation {
            endCappedIntersections.append(IntersectionNode(location: endingLocation, isIntersection: false))
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
            first.isIntersection = first.isIntersection || last.isIntersection
            endCappedIntersections.removeLast()
        }
        return endCappedIntersections.first!
    }

    static func createGraph(for path: Path, using intersections: [IntersectionNode]) -> [IntersectionNode] {
        // first file each intersection by component index
        let intersectionsByComponent = { () -> [[IntersectionNode]] in
            var temp = [[IntersectionNode]](repeating: [], count: path.components.count)
            intersections.forEach {
                temp[$0.location.componentIndex].append($0)
            }
            return temp
        }()
        return (0..<path.components.count).map {
            AugmentedGraph.createGraph(for: path.components[$0], componentIndex: $0, using: intersectionsByComponent[$0])
        }
    }

    static func sortAndMergeDuplicates(of nodes: inout [IntersectionNode]) {
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

    public init(path1: Path, path2: Path, intersections: [PathIntersection], operation: BooleanPathOperation) {
        self.operation = operation
        self.path1 = path1
        self.path2 = path2

        // create intersection nodes for each intersection
        var path1Intersections: [IntersectionNode] = []
        var path2Intersections: [IntersectionNode] = []
        intersections.forEach {
            let node1 = IntersectionNode(location: $0.indexedPathLocation1, isIntersection: true)
            let node2 = IntersectionNode(location: $0.indexedPathLocation2, isIntersection: true)
            node1.addNeighbor(node2, pathNumber: 1)
            node2.addNeighbor(node1, pathNumber: 0)
            path1Intersections.append(node1)
            if operation != .removeCrossings {
                path2Intersections.append(node2)
            } else {
                path1Intersections.append(node1)
            }
        }
        AugmentedGraph.sortAndMergeDuplicates(of: &path1Intersections)
        if operation != .removeCrossings {
            AugmentedGraph.sortAndMergeDuplicates(of: &path2Intersections)
        }
        // create graph representations of the two paths
        self.graph1 = AugmentedGraph.createGraph(for: self.path1, using: path1Intersections)
        self.graph2 = (operation != .removeCrossings) ? AugmentedGraph.createGraph(for: self.path2, using: path2Intersections) : graph1
        // mark each intersection as either entry or exit
        self.classifyEdges(in: graph1)
        if operation != .removeCrossings {
            self.classifyEdges(in: graph2)
        }
    }

    private func createComponent(from node: IntersectionNode) -> PathComponent {
        var points: [CGPoint] = [node.edge!.component.startingPoint]
        var orders = [Int]()

        func visit(_ component: PathComponent) {
            points += component.points[1..<component.points.count]
            orders += component.orders
        }
        var nextNode: IntersectionNode? = node
        while let currentNode = nextNode {
            nextNode = nil
            if currentNode.edge?.inSolution == true, currentNode.edge?.visited == false {
                visit(node.edge!.component)
                currentNode.edge?.visited = true
                nextNode = currentNode.next
            } else if currentNode.previous?.edge?.inSolution == true, currentNode.previous?.edge?.visited == false {
                currentNode.previous?.edge?.visited = true
                visit(currentNode.previous!.edge!.component.reversed())
                nextNode = currentNode.previous
            } else {

                for neighbor in currentNode.neighbors.values.joined() {
                    if nextNode != nil {
                        break
                    }
                    if neighbor.edge!.inSolution == true, neighbor.edge!.visited == false {
                        visit(neighbor.edge!.component)
                        neighbor.edge!.visited = true
                        nextNode = neighbor.next
                    } else if neighbor.previous!.edge!.inSolution == true, neighbor.previous!.edge!.visited == false {
                        neighbor.previous!.edge!.visited = true
                        visit(neighbor.previous!.edge!.component.reversed())
                        nextNode = neighbor.previous
                    }
                }

            }
        }

        if points.last != points.first {
//            points.append(points.first!)
//            orders.append(1)
        }

        return PathComponent(points: points, orders: orders)
    }

    internal func performOperation(for components: [IntersectionNode], appendingToComponents list: inout [PathComponent]) {
        for component in components {
            self.forEachNode(in: component) { node, _ in
                guard node.edge?.inSolution == true, node.edge?.visited == false else { return }
                list.append(self.createComponent(from: node))
            }
        }
    }

    internal func performOperation() -> Path {
        var components: [PathComponent] = []
        self.performOperation(for: self.graph1, appendingToComponents: &components)
        self.performOperation(for: self.graph2, appendingToComponents: &components)
        return Path(components: components)
    }
}
