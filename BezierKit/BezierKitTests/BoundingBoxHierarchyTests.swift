//
//  BoundingBoxHierarchyTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 1/25/19.
//  Copyright © 2019 Holmes Futrell. All rights reserved.
//

import XCTest
@testable import BezierKit

 // because Swift tuples don't work with `Equatable` in Swift 4
private struct Tuple: Equatable, Hashable {
    var first: Int
    var second: Int
}

class BoundingBoxHierarchyTests: XCTestCase {

    // initializer
    // intersects()
    // intersects(node:)

    func testIntersectsVisitsEachOnce() {
        // in this test each bounding box is identical and therefore
        // each bounding box overlaps. What we are testing here is that
        // the callback is invoked exactly once for each i <= j
        let box = BoundingBox(p1: CGPoint(x: 1, y: 2),
                              p2: CGPoint(x: 4, y: 5))
        let bvh = BoundingBoxHierarchy(boxes: [BoundingBox](repeating: box, count: 5))
        var visitedSet = Set<Tuple>()
        bvh.enumerateSelfIntersections { i, j in
            let tuple = Tuple(first: i, second: j)
            XCTAssertFalse(visitedSet.contains(tuple), "we already visited (\(i), \(j))!")
            visitedSet.insert(tuple)
        }
        let expectedSet = { () -> Set<Tuple> in
            var set = Set<Tuple>()
            for i in 0...4 {
                for j in i...4 {
                    set.insert(Tuple(first: i, second: j))
                }
            }
            return set
        }()
        XCTAssertEqual(visitedSet, expectedSet)
    }

    func testBoundingBoxForElement() {
        let boxes: [BoundingBox] = [BoundingBox(p1: CGPoint(x: 1, y: 2), p2: CGPoint(x: 3, y: 4)),
                                    BoundingBox(p1: CGPoint(x: 5, y: 6), p2: CGPoint(x: 7, y: 8)),
                                    BoundingBox(p1: CGPoint(x: 9, y: 10), p2: CGPoint(x: 11, y: 12))]
        let bvh = BoundingBoxHierarchy(boxes: boxes)
        XCTAssertEqual(bvh.boundingBox(forElementIndex: 0), boxes[0])
        XCTAssertEqual(bvh.boundingBox(forElementIndex: 1), boxes[1])
        XCTAssertEqual(bvh.boundingBox(forElementIndex: 2), boxes[2])
    }

    func testLeafNodeToElementIndex() {
        // check the simple case of a 1 element tree
        XCTAssertEqual(BoundingBoxHierarchy.leafNodeIndexToElementIndex(0, elementCount: 1, lastRowIndex: 0), 0)
        // check the case of a 3 element tree
        XCTAssertEqual(BoundingBoxHierarchy.leafNodeIndexToElementIndex(3, elementCount: 3, lastRowIndex: 3), 0)
        XCTAssertEqual(BoundingBoxHierarchy.leafNodeIndexToElementIndex(4, elementCount: 3, lastRowIndex: 3), 1)
        XCTAssertEqual(BoundingBoxHierarchy.leafNodeIndexToElementIndex(2, elementCount: 3, lastRowIndex: 3), 2)
    }

    func testElementIndexToNodeIndex() {
        // check the simple case of a 1 element tree
        XCTAssertEqual(BoundingBoxHierarchy.elementIndexToNodeIndex(0, elementCount: 1, lastRowIndex: 0), 0)
        // check the case of a 3 element tree
        XCTAssertEqual(BoundingBoxHierarchy.elementIndexToNodeIndex(0, elementCount: 3, lastRowIndex: 3), 3)
        XCTAssertEqual(BoundingBoxHierarchy.elementIndexToNodeIndex(1, elementCount: 3, lastRowIndex: 3), 4)
        XCTAssertEqual(BoundingBoxHierarchy.elementIndexToNodeIndex(2, elementCount: 3, lastRowIndex: 3), 2)
    }

    /// constructs a test hierarchy with a given number of leaf nodes, all using the same bounding box
    /// useful for testing that leaf node elementIndex and internal node startingElementIndex and endingElementIndex are correct
    private func constructTestHierarchy(leafNodeCount: Int, repeatingBoundingBox: BoundingBox) -> BoundingBoxHierarchy {
        return BoundingBoxHierarchy(boxes: [BoundingBox](repeating: repeatingBoundingBox, count: leafNodeCount))
    }

    private func createListFromAllNodesVisited(in boundingBoxHierarchy: BoundingBoxHierarchy) -> [BoundingBoxHierarchy.Node] {
        var result: [BoundingBoxHierarchy.Node] = []
        boundingBoxHierarchy.visit { (node: BoundingBoxHierarchy.Node, depth: Int) -> Bool in
            result.append(node)
            return true
        }
        return result
    }

    private func internalNode(start: Int, end: Int, box: BoundingBox) -> BoundingBoxHierarchy.Node {
        return BoundingBoxHierarchy.Node(boundingBox: box, type: .internal(startingElementIndex: start, endingElementIndex: end))
    }

    private func leafNode(elementIndex: Int, box: BoundingBox) -> BoundingBoxHierarchy.Node {
        return BoundingBoxHierarchy.Node(boundingBox: box, type: .leaf(elementIndex: elementIndex))
    }

    /// test that when we visit a bounding volume hierarchy the leaf node elementIndex and internal node start and end element indexes are correct
    func testVisitElementIndexes() {
        let sampleBox = BoundingBox(min: CGPoint.zero, max: CGPoint.zero)

        // simplest possible case (1 leaf node)
        let bvh1 = self.constructTestHierarchy(leafNodeCount: 1, repeatingBoundingBox: sampleBox)
        let result1 = createListFromAllNodesVisited(in: bvh1)
        XCTAssertEqual(result1, [leafNode(elementIndex: 0, box: sampleBox)])

        // simplest case with internal node
        let bvh2 = self.constructTestHierarchy(leafNodeCount: 2, repeatingBoundingBox: sampleBox)
        let result2 = createListFromAllNodesVisited(in: bvh2)
        XCTAssertEqual(result2, [internalNode(start: 0, end: 1, box: sampleBox),
                                 leafNode(elementIndex: 0, box: sampleBox),
                                 leafNode(elementIndex: 1, box: sampleBox)])

        // a more complex case where leaf nodes exist on different levels of the tree
        let bvh3 = self.constructTestHierarchy(leafNodeCount: 5, repeatingBoundingBox: sampleBox)
        let result3 = createListFromAllNodesVisited(in: bvh3)
        XCTAssertEqual(result3, [internalNode(start: 0, end: 4, box: sampleBox),
                                 internalNode(start: 0, end: 2, box: sampleBox),
                                 internalNode(start: 0, end: 1, box: sampleBox),
                                 leafNode(elementIndex: 0, box: sampleBox),
                                 leafNode(elementIndex: 1, box: sampleBox),
                                 leafNode(elementIndex: 2, box: sampleBox),
                                 internalNode(start: 3, end: 4, box: sampleBox),
                                 leafNode(elementIndex: 3, box: sampleBox),
                                 leafNode(elementIndex: 4, box: sampleBox)])
    }
}
