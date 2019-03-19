//
//  BoundingVolumeHierarchyTests.swift
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

class BoundingVolumeHierarchyTests: XCTestCase {
    
    // initializer
    // intersects()
    // intersects(node:)
    
    func testIntersectsVisitsEachOnce() {
        // in this test each bounding box is identical and therefore
        // each bounding box overlaps. What we are testing here is that
        // the callback is invoked exactly once for each i <= j
        let box = BoundingBox(p1: CGPoint(x: 1, y: 2),
                              p2: CGPoint(x: 4, y: 5))
        let bvh = BVH(boxes: [BoundingBox](repeating: box, count: 5))
        var visitedSet = Set<Tuple>()
        bvh.intersects { i, j in
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
        let bvh = BVH(boxes: boxes)
        XCTAssertEqual(bvh.boundingBox(forElementIndex: 0), boxes[0])
        XCTAssertEqual(bvh.boundingBox(forElementIndex: 1), boxes[1])
        XCTAssertEqual(bvh.boundingBox(forElementIndex: 2), boxes[2])
    }

    func testLeafNodeToElementIndex() {
        // check the simple case of a 1 element tree
        XCTAssertEqual(BVH.leafNodeIndexToElementIndex(0, elementCount: 1, lastRowIndex: 0), 0)
        // check the case of a 3 element tree
        XCTAssertEqual(BVH.leafNodeIndexToElementIndex(3, elementCount: 3, lastRowIndex: 3), 0)
        XCTAssertEqual(BVH.leafNodeIndexToElementIndex(4, elementCount: 3, lastRowIndex: 3), 1)
        XCTAssertEqual(BVH.leafNodeIndexToElementIndex(2, elementCount: 3, lastRowIndex: 3), 2)
    }

    func testElementIndexToNodeIndex() {
        // check the simple case of a 1 element tree
        XCTAssertEqual(BVH.elementIndexToNodeIndex(0, elementCount: 1, lastRowIndex: 0), 0)
        // check the case of a 3 element tree
        XCTAssertEqual(BVH.elementIndexToNodeIndex(0, elementCount: 3, lastRowIndex: 3), 3)
        XCTAssertEqual(BVH.elementIndexToNodeIndex(1, elementCount: 3, lastRowIndex: 3), 4)
        XCTAssertEqual(BVH.elementIndexToNodeIndex(2, elementCount: 3, lastRowIndex: 3), 2)
    }
}
