//
//  CubicCurveTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 7/31/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import XCTest
@testable import BezierKit

class QuadraticCurveTests: XCTestCase {

    // TODO: we still have a LOT of missing unit tests for QuadraticCurve's API entry points

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
        let q1 = QuadraticCurve(start: CGPoint(x: 1.0, y: 1.0), end: CGPoint(x: 5.0, y: 1.0), mid: CGPoint(x: 3.0, y: 2.0), t: 0.5)
        XCTAssertEqual(q1, QuadraticCurve(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 3.0, y: 3.0), p2: CGPoint(x: 5.0, y: 1.0)))
        // degenerate cases
        let q2 = QuadraticCurve(start: CGPoint(x: 1.0, y: 1.0), end: CGPoint(x: 5.0, y: 1.0), mid: CGPoint(x: 1.0, y: 1.0), t: 0.0)
        XCTAssertEqual(q2, QuadraticCurve(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 1.0, y: 1.0), p2: CGPoint(x: 5.0, y: 1.0)))
        let q3 = QuadraticCurve(start: CGPoint(x: 1.0, y: 1.0), end: CGPoint(x: 5.0, y: 1.0), mid: CGPoint(x: 5.0, y: 1.0), t: 1.0)
        XCTAssertEqual(q3, QuadraticCurve(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 5.0, y: 1.0), p2: CGPoint(x: 5.0, y: 1.0)))
    }

    func testBasicProperties() {
        let q = QuadraticCurve(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 3.5, y: 2.0), p2: CGPoint(x: 6.0, y: 1.0))
        XCTAssert(q.simple)
        XCTAssertEqual(q.order, 2)
        XCTAssertEqual(q.startingPoint, CGPoint(x: 1.0, y: 1.0))
        XCTAssertEqual(q.endingPoint, CGPoint(x: 6.0, y: 1.0))
    }

    func testSetStartEndPoints() {
        var q = QuadraticCurve(p0: CGPoint(x: 5.0, y: 6.0), p1: CGPoint(x: 6.0, y: 5.0), p2: CGPoint(x: 8.0, y: 7.0))
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
        let q1 = QuadraticCurve(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: 3.0, y: 3.0), p2: CGPoint(x: 5.0, y: 1.0))
        let expectedBoundingBox1 = BoundingBox(p1: CGPoint(x: 1.0, y: 1.0),
                                               p2: CGPoint(x: 5.0, y: 2.0))
        XCTAssertEqual(q1.boundingBox, expectedBoundingBox1)

        // hits codepath where midpoint pushes down x coordinate of bounding box
        let q2 = QuadraticCurve(p0: CGPoint(x: 1.0, y: 1.0), p1: CGPoint(x: -1.0, y: 2.0), p2: CGPoint(x: 1.0, y: 3.0))
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

    func testProject() {
        let epsilon: CGFloat = 1.0e-5
        let q = QuadraticCurve(p0: CGPoint(x: 1, y: 1),
                               p1: CGPoint(x: 2, y: 0),
                               p2: CGPoint(x: 4, y: 1))
        let result1 = q.project(CGPoint(x: 2, y: 2))
        XCTAssertEqual(result1.t, 0)
        XCTAssertEqual(result1.point, CGPoint(x: 1, y: 1))
        let result2 = q.project(CGPoint(x: 5, y: 1))
        XCTAssertEqual(result2.t, 1)
        XCTAssertEqual(result2.point, CGPoint(x: 4, y: 1))
        let result3 = q.project(CGPoint(x: 2.25, y: 1))
        XCTAssertEqual(result3.t, 0.5)
        XCTAssertEqual(result3.point, CGPoint(x: 2.25, y: 0.5))
        // test accuracy
        let t: CGFloat = 0.374858262
        let expectedPoint = q.point(at: t)
        let pointToProject = expectedPoint + 0.234 * q.normal(at: t)
        let result4 = q.project(pointToProject)
        XCTAssertEqual(result4.t, t, accuracy: epsilon)
        XCTAssertTrue(distance(result4.point, expectedPoint) < epsilon)
    }

    func testProjectPerformance() {
        let q = QuadraticCurve(p0: CGPoint(x: -1, y: -1),
                               p1: CGPoint(x: 0, y: 2),
                               p2: CGPoint(x: 1, y: -1))
        self.measure {
            // roughly 0.043 -Onone, 0.022 with -Ospeed
            // if comparing with cubic performance, be sure to note `by` parameter in stride
            for theta in stride(from: 0, to: 2*Double.pi, by: 0.0001) {
                _ = q.project(CGPoint(x: cos(theta), y: sin(theta)))
            }
        }
    }

//
//    func testHull() {
//    }
//    

    func testNormalDegenerate() {
        let maxError: CGFloat = 0.01
        let a = CGPoint(x: 2, y: 3)
        let b = CGPoint(x: 3, y: 3)
        let quadratic1 = QuadraticCurve(p0: a, p1: a, p2: b)
        XCTAssertTrue( distance(quadratic1.normal(at: 0), CGPoint(x: 0, y: 1)) < maxError )
        let quadratic2 = QuadraticCurve(p0: a, p1: b, p2: b)
        XCTAssertTrue( distance(quadratic2.normal(at: 1), CGPoint(x: 0, y: 1)) < maxError )
    }

    func testReduce() {
        // already simple curve
        let q1 = QuadraticCurve(p0: CGPoint(x: 0, y: 0),
                                      p1: CGPoint(x: 4, y: 3),
                                      p2: CGPoint(x: 7, y: 7))
        XCTAssertTrue(BezierKitTestHelpers.isSatisfactoryReduceResult(q1.reduce(), for: q1))
        // must remove maxima at 0.5
        let q2 = QuadraticCurve(p0: CGPoint(x: 0, y: 0),
                                      p1: CGPoint(x: 2, y: 1),
                                      p2: CGPoint(x: 4, y: 0))
        XCTAssertTrue(BezierKitTestHelpers.isSatisfactoryReduceResult(q2.reduce(), for: q2))
        // ensure handles degeneracies ok
        let p = CGPoint(x: 2.17, y: 3.14)
        let q3 = QuadraticCurve(p0: p, p1: p, p2: p)
        XCTAssertTrue(BezierKitTestHelpers.isSatisfactoryReduceResult(q3.reduce(), for: q3))
    }
//
//    func testScaleDistanceFunc {
//    }
//
//
//
    func testIntersectionsQuadratic() {
        let epsilon: CGFloat = 1.0e-5
        let q1: QuadraticCurve = QuadraticCurve(start: CGPoint(x: 0.0, y: 0.0),
                                                            end: CGPoint(x: 2.0, y: 0.0),
                                                            mid: CGPoint(x: 1.0, y: 2.0),
                                                            t: 0.5)
        let q2: QuadraticCurve = QuadraticCurve(start: CGPoint(x: 0.0, y: 2.0),
                                                            end: CGPoint(x: 2.0, y: 2.0),
                                                            mid: CGPoint(x: 1.0, y: 0.0),
                                                            t: 0.5)
        let i = q1.intersections(with: q2, accuracy: epsilon)
        XCTAssertEqual(i.count, 2)
        let root1 = 1.0 - sqrt(2) / 2.0
        let root2 = 1.0 + sqrt(2) / 2.0
        let expectedResult1 = CGPoint(x: root1, y: 1)
        let expectedResult2 = CGPoint(x: root2, y: 1)
        XCTAssertTrue( distance(q1.point(at: i[0].t1), expectedResult1) < epsilon)
        XCTAssertTrue( distance(q1.point(at: i[1].t1), expectedResult2) < epsilon)
        XCTAssertTrue( distance(q2.point(at: i[0].t2), expectedResult1) < epsilon)
        XCTAssertTrue( distance(q2.point(at: i[1].t2), expectedResult2) < epsilon)
    }

    func testIntersectionsQuadraticMaxIntersections() {
        let epsilon: CGFloat = 1.0e-5
        let q1: QuadraticCurve = QuadraticCurve(start: CGPoint(x: 0.0, y: 0.0),
                                                            end: CGPoint(x: 2.0, y: 0.0),
                                                            mid: CGPoint(x: 1.0, y: 2.0),
                                                            t: 0.5)
        let q2: QuadraticCurve = QuadraticCurve(start: CGPoint(x: 0.0, y: 0.0),
                                                            end: CGPoint(x: 0.0, y: 2.0),
                                                            mid: CGPoint(x: 2.0, y: 1.0),
                                                            t: 0.5)
        let intersections = q1.intersections(with: q2, accuracy: epsilon)
        let expectedResults = [CGPoint(x: 0.0, y: 0.0),
                               CGPoint(x: 0.69098300, y: 1.8090170),
                               CGPoint(x: 1.5, y: 1.5),
                               CGPoint(x: 1.8090170, y: 0.69098300)]
        XCTAssertEqual(intersections.count, 4)
        for i in 0..<intersections.count {
            XCTAssertTrue(distance(q1.point(at: intersections[i].t1), expectedResults[i]) < epsilon)
            XCTAssertTrue(distance(q2.point(at: intersections[i].t2), expectedResults[i]) < epsilon)
        }
    }

    // MARK: -

    func testEquatable() {
        let p0 = CGPoint(x: 1.0, y: 2.0)
        let p1 = CGPoint(x: 2.0, y: 3.0)
        let p2 = CGPoint(x: 3.0, y: 2.0)

        let c1 = QuadraticCurve(p0: p0, p1: p1, p2: p2)
        let c2 = QuadraticCurve(p0: p0, p1: p1, p2: p2)
        let c3 = QuadraticCurve(p0: CGPoint(x: 5.0, y: 6.0), p1: p1, p2: p2)
        let c4 = QuadraticCurve(p0: p0, p1: CGPoint(x: 1.0, y: 3.0), p2: p2)
        let c5 = QuadraticCurve(p0: p0, p1: p1, p2: CGPoint(x: 3.0, y: 6.0))

        XCTAssertEqual(c1, c1)
        XCTAssertEqual(c1, c2)
        XCTAssertNotEqual(c1, c3)
        XCTAssertNotEqual(c1, c4)
        XCTAssertNotEqual(c1, c5)
    }
}
