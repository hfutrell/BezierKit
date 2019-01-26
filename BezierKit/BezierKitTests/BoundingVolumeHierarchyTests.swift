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
}
