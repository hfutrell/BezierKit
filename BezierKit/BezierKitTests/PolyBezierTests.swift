//
//  PolyBezierTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 1/13/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import XCTest
import BezierKit

class PolyBezierTests: XCTestCase {
    
    let line1 = LineSegment(p0: BKPoint(x: 1.0, y: 2.0), p1: BKPoint(x: 5.0, y: 5.0))   // length = 5
    let line2 = LineSegment(p0: BKPoint(x: 5.0, y: 5.0), p1: BKPoint(x: 13.0, y: -1.0)) // length = 10
    
    func testLength() {
        let p = PolyBezier(curves: [line1, line2])
        XCTAssertEqual(p.length, 15.0) // sum of two lengths
    }
    
    func testBoundingBox() {
        let p = PolyBezier(curves: [line1, line2])
        XCTAssertEqual(p.boundingBox, BoundingBox(min: BKPoint(x: 1.0, y: -1.0), max: BKPoint(x: 13.0, y: 5.0))) // just the union of the two bounding boxes
    }
    
    func testOffset() {
        // construct a PolyBezier from a split cubic
        let q = QuadraticBezierCurve(p0: BKPoint(x: 0.0, y: 0.0), p1: BKPoint(x: 2.0, y: 1.0), p2: BKPoint(x: 4.0, y: 0.0))
        let (ql, qr) = q.split(at: 0.5)
        let p = PolyBezier(curves: [ql, qr])
        // test that offset gives us the same result as offsetting the split segments
        let pOffset = p.offset(distance: 1)
        
        for (c1, c2) in zip(pOffset.curves, ql.offset(distance: 1) + qr.offset(distance: 1)) {
            XCTAssert(c1 == c2)
        }
    }
    
}

