//
//  ShapeTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 1/13/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import XCTest
@testable import BezierKit

class ShapeTests: XCTestCase {
    
    let testQuadCurve = QuadraticBezierCurve(p0: BKPoint(x: 0.0, y: 0.0), p1: BKPoint(x: 1.0, y: 1.0), p2: BKPoint(x: 1.0, y:  2.0))
    
    func testInitializer() {
        let forward = testQuadCurve.offset(distance: 2)[0]
        let back = testQuadCurve.offset(distance: -2)[0]
        let s = Shape(forward, back, false, false)
        XCTAssert(s.forward == forward)
        XCTAssert(s.back == back)
        XCTAssert(s.startcap.virtual == false)
        XCTAssert(s.startcap.curve == LineSegment(p0: back.endingPoint, p1: forward.startingPoint))
        XCTAssert(s.endcap.virtual == false)
        XCTAssert(s.endcap.curve == LineSegment(p0: forward.endingPoint, p1: back.startingPoint))
    }
    
    func testBoundingBox() {
        let forward = testQuadCurve.offset(distance: 2)[0]
        let back = testQuadCurve.offset(distance: -2)[0]
        let s = Shape(forward, back, false, false)
        XCTAssert(s.boundingBox() == BoundingBox(first: forward.boundingBox, second: back.boundingBox))
    }

    func testIntersects() {
        let epsilon: BKFloat = 1.0e-4
        let line1 = LineSegment(p0: BKPoint(x: -1, y: -1), p1: BKPoint(x: 1, y: 1))
        let forward1 = line1.offset(distance: sqrt(2))[0]
        let back1 = line1.offset(distance: -sqrt(2))[0].reversed()
        let s1 = Shape(forward1, back1, true, true)
        
        let line2 = LineSegment(p0: BKPoint(x: 1.0, y: 10.0), p1: BKPoint(x: 1.0, y: -10.0))
        let forward2 = line2.offset(distance: 0.5)[0]
        let back2 = line2.offset(distance: -0.5)[0].reversed()
        let s2 = Shape(forward2, back2, false, false)

        let shapeIntersections = s1.intersects(shape: s2, 1.0e-4)
        XCTAssertEqual(shapeIntersections.count, 2)
        
        // check the first shape intersection
        XCTAssert(shapeIntersections[0].curve1 == s1.back)
        XCTAssert(shapeIntersections[0].curve2 == s2.forward)
        XCTAssertEqual(shapeIntersections[0].intersections.count, 1)
        var p1 = shapeIntersections[0].curve1.compute(shapeIntersections[0].intersections[0].t1)
        var p2 = shapeIntersections[0].curve2.compute(shapeIntersections[0].intersections[0].t2)
        XCTAssert(distance(p1, p2) < epsilon)

        // check the 2nd shape intersection
        XCTAssert(shapeIntersections[1].curve1 == s1.back)
        XCTAssert(shapeIntersections[1].curve2 == s2.back)
        XCTAssertEqual(shapeIntersections[1].intersections.count, 1)
        p1 = shapeIntersections[1].curve1.compute(shapeIntersections[1].intersections[0].t1)
        p2 = shapeIntersections[1].curve2.compute(shapeIntersections[1].intersections[0].t2)
        XCTAssert(distance(p1, p2) < epsilon)
    }
    
}

