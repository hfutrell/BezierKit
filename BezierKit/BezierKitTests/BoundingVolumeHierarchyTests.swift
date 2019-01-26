//
//  BoundingVolumeHierarchyTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 1/25/19.
//  Copyright © 2019 Holmes Futrell. All rights reserved.
//

import XCTest
@testable import BezierKit

fileprivate func !=<T: Equatable>(lhs: [(T, T)], rhs: [(T, T)]) -> Bool {
    return (lhs == rhs) == false
}

fileprivate func ==<T: Equatable>(lhs: [(T, T)], rhs: [(T, T)]) -> Bool {
    if lhs.count != rhs.count {
        return false
    }
    for (index, value) in lhs.enumerated() {
        if !(value == rhs[index]) {
            return false
        }
    }
    return true
}

class BoundingVolumeHierarchyTests: XCTestCase {
    
    // initializer
    // intersects()
    // intersects(node:)
    
    func testTupleArrayEqualityTooling() {
        // tests that our tuple array equality check is working, which is needed for subsequent tests
        XCTAssert([(1,1)] != [(1,1),(1,2)])
        XCTAssert([(1,1)] == [(1,1)])
        XCTAssert([(1,1),(2,2),(3,3)] == [(1,1),(2,2),(3,3)])
        XCTAssert([(1,1),(2,2),(3,3)] != [(1,1),(3,3),(2,2)])
    }
    
    func testIntersectsVisitationOrder() {
        
        // in this test each bounding box is identical and therefore
        // each bounding box overlaps. What we are testing here is that
        // the callback is invoked exactly once for each i <= j
        // and that the callbacks occur in the expected order
        
        let box = BoundingBox(p1: CGPoint(x: 1, y: 2),
                              p2: CGPoint(x: 4, y: 5))
        
        let bvh = BVH(boxes: [BoundingBox](repeating: box, count: 5))
        
        var visitationOrder: [(Int, Int)] = []
        bvh.intersects { i, j in
            visitationOrder.append((i, j))
        }
        let expectedOrder: [(Int, Int)] = [(0,0),(0,1),(0,2),(0,3),(0,4),(1,1),(1,2),(1,3),(1,4),(2,2),(2,3),(2,4),(3,3),(3,4),(4,4)]
        XCTAssert(visitationOrder == expectedOrder, "\(visitationOrder) not equal to \(expectedOrder)")
    }
    
}
