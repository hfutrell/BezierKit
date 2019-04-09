//
//  CubicBezierCurveTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 7/31/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import XCTest
@testable import BezierKit

class QuadraticBezierCurveTests: XCTestCase {

    // TODO: we still have a LOT of missing unit tests for QuadraticBezierCurve's API entry points

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
//    func testInitializerArray() {
//    }
//
//    func testInitializerIndividualPoints() {
//    }
//
//    func testInitializerLineSegment() {
//    }
//
    func testInitializerStartEndMidT() {
        let q1 = QuadraticBezierCurve(start: CGPoint(x: 1.0, y: 1.0), end: CGPoint(x: 5.0, y: 1.0), mid: CGPoint(x: 3.0, y: 2.0), t: 0.5)
        XCTAssertEqual(q1, QuadraticBezierCurve(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 3.0, y: 3.0), p2: CGPoint(x: 5.0, y: 1.0)))
        // degenerate cases
        let q2 = QuadraticBezierCurve(start: CGPoint(x: 1.0, y: 1.0), end: CGPoint(x: 5.0, y: 1.0), mid: CGPoint(x: 1.0, y: 1.0), t: 0.0)
        XCTAssertEqual(q2, QuadraticBezierCurve(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 1.0, y: 1.0), p2: CGPoint(x: 5.0, y: 1.0)))
        let q3 = QuadraticBezierCurve(start: CGPoint(x: 1.0, y: 1.0), end: CGPoint(x: 5.0, y: 1.0), mid: CGPoint(x: 5.0, y: 1.0), t: 1.0)
        XCTAssertEqual(q3, QuadraticBezierCurve(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 5.0, y: 1.0), p2: CGPoint(x: 5.0, y: 1.0)))
    }
    
    func testBasicProperties() {
        let q = QuadraticBezierCurve(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 3.5, y: 2.0), p2: CGPoint(x: 6.0, y: 1.0))
        XCTAssert(q.simple)
        XCTAssertEqual(q.order, 2)
        XCTAssertEqual(q.startingPoint, CGPoint(x: 1.0, y: 1.0))
        XCTAssertEqual(q.endingPoint, CGPoint(x: 6.0, y: 1.0))
    }
    
    func testSetStartEndPoints() {
        var q = QuadraticBezierCurve(p0: CGPoint(x: 5.0, y: 6.0), p1: CGPoint(x: 6.0, y: 5.0), p2: CGPoint(x: 8.0, y: 7.0))
        q.startingPoint = CGPoint(x: 4.0, y: 5.0)
        XCTAssertEqual(q.p0, q.startingPoint)
        XCTAssertEqual(q.startingPoint, CGPoint(x: 4.0, y: 5.0))
        q.endingPoint = CGPoint(x: 9.0, y: 8.0)
        XCTAssertEqual(q.p2, q.endingPoint)
        XCTAssertEqual(q.endingPoint, CGPoint(x: 9.0, y: 8.0))
    }

//    func testSimple() {
//    }
//
//    func testDerivative() {
//    }
//
//    func testSplitFromTo() {
//    }
//
//    func testSplitAt() {
//    }
//
    func testBoundingBox() {
        // hits codepath where midpoint pushes up y coordinate of bounding box
        let q1 = QuadraticBezierCurve(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 3.0, y: 3.0), p2: CGPoint(x: 5.0, y: 1.0))
        let expectedBoundingBox1 = BoundingBox(p1: CGPoint(x: 1.0, y: 1.0),
                                               p2: CGPoint(x: 5.0, y: 2.0))
        XCTAssertEqual(q1.boundingBox, expectedBoundingBox1)
       
        // hits codepath where midpoint pushes down x coordinate of bounding box
        let q2 = QuadraticBezierCurve(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: -1.0, y: 2.0), p2: CGPoint(x: 1.0, y: 3.0))
        let expectedBoundingBox2 = BoundingBox(p1: CGPoint(x: 0.0, y: 1.0),
                                               p2: CGPoint(x: 1.0, y: 3.0))
        XCTAssertEqual(q2.boundingBox, expectedBoundingBox2)
        // this one is designed to hit an unusual codepath: c3 has an extrema that would expand the bounding box,
        // but it falls outside of the range 0<=t<=1, and therefore must be excluded
        let q3 = q1.split(at: 0.25).left
        let expectedBoundingBox3 = BoundingBox(p1: CGPoint(x: 1.0, y: 1.0),
                                               p2: CGPoint(x: 2.0, y: 1.75))
        XCTAssertEqual(q3.boundingBox, expectedBoundingBox3)
    }
//
//    func testCompute() {
//    }
    
// -- MARK: - methods for which default implementations provided by protocol

//    func testLength() {
//    }
//
//    func testExtrema() {
//    }
//
//    func testHull() {
//    }
//    
//    func testNormal() {
//    }
//    
//    func testReduce() {
//    }
//
//    func testScaleDistanceFunc {
//    }
//
//    func testProject() {
//    }
//
//
    func testIntersectionsQuadratic() {
        let epsilon: CGFloat = 1.0e-5
        let q1: QuadraticBezierCurve = QuadraticBezierCurve(start: CGPoint(x: 0.0, y: 0.0),
                                                            end: CGPoint(x: 2.0, y: 0.0),
                                                            mid: CGPoint(x: 1.0, y: 2.0),
                                                            t: 0.5)
        let q2: QuadraticBezierCurve = QuadraticBezierCurve(start: CGPoint(x: 0.0, y: 2.0),
                                                            end: CGPoint(x: 2.0, y: 2.0),
                                                            mid: CGPoint(x: 1.0, y: 0.0),
                                                            t: 0.5)
        let i = q1.intersections(with: q2, accuracy: epsilon)
        XCTAssertEqual(i.count, 2)
        let root1 = 1.0 - sqrt(2) / 2.0
        let root2 = 1.0 + sqrt(2) / 2.0
        let expectedResult1 = CGPoint(x: root1, y: 1)
        let expectedResult2 = CGPoint(x: root2, y: 1)
        XCTAssertTrue( distance(q1.compute(i[0].t1), expectedResult1) < epsilon)
        XCTAssertTrue( distance(q1.compute(i[1].t1), expectedResult2) < epsilon)
        XCTAssertTrue( distance(q2.compute(i[0].t2), expectedResult1) < epsilon)
        XCTAssertTrue( distance(q2.compute(i[1].t2), expectedResult2) < epsilon)
    }

    // MARK: -
    
    func testEquatable() {
        let p0 = CGPoint(x: 1.0, y: 2.0)
        let p1 = CGPoint(x: 2.0, y: 3.0)
        let p2 = CGPoint(x: 3.0, y: 2.0)

        let c1 = QuadraticBezierCurve(p0: p0, p1: p1, p2: p2)
        let c2 = QuadraticBezierCurve(p0: p0, p1: p1, p2: p2)
        let c3 = QuadraticBezierCurve(p0: CGPoint(x: 5.0, y: 6.0), p1: p1, p2: p2)
        let c4 = QuadraticBezierCurve(p0: p0, p1: CGPoint(x: 1.0, y: 3.0), p2: p2)
        let c5 = QuadraticBezierCurve(p0: p0, p1: p1, p2: CGPoint(x: 3.0, y: 6.0))

        XCTAssertEqual(c1, c1)
        XCTAssertEqual(c1, c2)
        XCTAssertNotEqual(c1, c3)
        XCTAssertNotEqual(c1, c4)
        XCTAssertNotEqual(c1, c5)
    }
}
