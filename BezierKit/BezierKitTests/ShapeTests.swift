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

    let testQuadCurve = QuadraticCurve(p0: CGPoint(x: 0.0, y: 0.0), p1: CGPoint(x: 1.0, y: 1.0), p2: CGPoint(x: 1.0, y: 2.0))

    func testShapeIntersection() {
        let c1 = LineSegment(p0: CGPoint(x: 0.0, y: 1.0), p1: CGPoint(x: 1.0, y: 0.0))
        let c2 = LineSegment(p0: CGPoint(x: 0.0, y: 1.0), p1: CGPoint(x: 1.0, y: 2.0))
        let c3 = LineSegment(p0: CGPoint(x: 0.0, y: 10.0), p1: CGPoint(x: 1.0, y: 5.0))
        let si1 = ShapeIntersection(curve1: c1, curve2: c2, intersections: [Intersection(t1: 0.5, t2: 0.5)])
        let si2 = ShapeIntersection(curve1: c1, curve2: c2, intersections: [Intersection(t1: 0.5, t2: 0.5)])
        XCTAssertEqual(si1, si2)
        var si3 = ShapeIntersection(curve1: c3, curve2: c2, intersections: [Intersection(t1: 0.5, t2: 0.5)])
        XCTAssertNotEqual(si1, si3) // curve 1 doesn't match
        si3 = ShapeIntersection(curve1: c1, curve2: c3, intersections: [Intersection(t1: 0.5, t2: 0.5)])
        XCTAssertNotEqual(si1, si3) // curve 2 doesn't match
        si3 = ShapeIntersection(curve1: c1, curve2: c2, intersections: [])
        XCTAssertNotEqual(si1, si3) // intersections don't match
    }

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
        XCTAssert(s.boundingBox == BoundingBox(first: forward.boundingBox, second: back.boundingBox))
    }

    func testIntersects() {
        let epsilon: CGFloat = 1.0e-4
        let line1 = LineSegment(p0: CGPoint(x: -1, y: -1), p1: CGPoint(x: 1, y: 1))
        let forward1 = line1.offset(distance: sqrt(2))[0]
        let back1 = line1.offset(distance: -sqrt(2))[0].reversed()
        let s1 = Shape(forward1, back1, true, true)

        let line2 = LineSegment(p0: CGPoint(x: 1.0, y: 10.0), p1: CGPoint(x: 1.0, y: -10.0))
        let forward2 = line2.offset(distance: 0.5)[0]
        let back2 = line2.offset(distance: -0.5)[0].reversed()
        let s2 = Shape(forward2, back2, false, false)

        let shapeIntersections = s1.intersects(shape: s2, accuracy: 1.0e-4)
        XCTAssertEqual(shapeIntersections.count, 2)

        // check the first shape intersection
        XCTAssert(shapeIntersections[0].curve1 == s1.back)
        XCTAssert(shapeIntersections[0].curve2 == s2.forward)
        XCTAssertEqual(shapeIntersections[0].intersections.count, 1)
        var p1 = shapeIntersections[0].curve1.point(at: shapeIntersections[0].intersections[0].t1)
        var p2 = shapeIntersections[0].curve2.point(at: shapeIntersections[0].intersections[0].t2)
        XCTAssert(distance(p1, p2) < epsilon)

        // check the 2nd shape intersection
        XCTAssert(shapeIntersections[1].curve1 == s1.back)
        XCTAssert(shapeIntersections[1].curve2 == s2.back)
        XCTAssertEqual(shapeIntersections[1].intersections.count, 1)
        p1 = shapeIntersections[1].curve1.point(at: shapeIntersections[1].intersections[0].t1)
        p2 = shapeIntersections[1].curve2.point(at: shapeIntersections[1].intersections[0].t2)
        XCTAssert(distance(p1, p2) < epsilon)

        // test a non-intersecting case where bounding boxes overlap
        let s3 = LineSegment(p0: CGPoint(x: -3, y: -3), p1: CGPoint(x: 3, y: 3)).outlineShapes(distance: 1)
        XCTAssertEqual(s1.intersects(shape: s3[0]), [])
        // test a non-intersecting case where bounding boxes do not overlap
        let s4 = LineSegment(p0: CGPoint(x: -6, y: -6), p1: CGPoint(x: -4, y: -4)).outlineShapes(distance: sqrt(2))
        XCTAssertEqual(s1.intersects(shape: s4[0]), [])
    }

    func testEquatable() {
        let a = CGPoint(x: -1, y: 1)
        let b = CGPoint(x: 1, y: 1)
        let c = CGPoint(x: -1, y: -1)
        let d = CGPoint(x: 1, y: -1)
        let cap1 = Shape.Cap(curve: LineSegment(p0: a, p1: b), virtual: true)
        let cap2 = Shape.Cap(curve: LineSegment(p0: a, p1: b), virtual: false)
        let cap3 = Shape.Cap(curve: LineSegment(p0: b, p1: a), virtual: true)
        XCTAssertNotEqual(cap1, cap2)
        XCTAssertNotEqual(cap1, cap3)
        XCTAssertEqual(cap1, cap1)
        let shape1 = Shape(LineSegment(p0: a, p1: b), LineSegment(p0: d, p1: c), true, true)
        let shape2 = Shape(LineSegment(p0: a, p1: b), LineSegment(p0: d, p1: c), false, true)
        let shape3 = Shape(LineSegment(p0: a, p1: b), LineSegment(p0: d, p1: c), true, false)
        let shape4 = Shape(LineSegment(p0: d, p1: c), LineSegment(p0: a, p1: b), true, true)
        XCTAssertEqual(shape1, shape1)
        XCTAssertNotEqual(shape1, shape2)
        XCTAssertNotEqual(shape1, shape3)
        XCTAssertNotEqual(shape1, shape4)
    }
}
