//
//  BezierCurveTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 12/31/17.
//  Copyright © 2017 Holmes Futrell. All rights reserved.
//

import XCTest
import BezierKit

class BezierCurveTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testScaleDistance() {
        // line segment
        let epsilon: BKFloat = 1.0e-6
        let l = LineSegment(p0: BKPoint(x: 1.0, y: 2.0), p1: BKPoint(x: 5.0, y: 6.0))
        let ls = l.scale(distance: sqrt(2)) // (moves line up and left by 1,1)
        let expectedLine = LineSegment(p0: BKPoint(x: 0.0, y: 3.0), p1: BKPoint(x: 4.0, y: 7.0))
        XCTAssert(BezierKitTests.curveControlPointsEqual(curve1: ls, curve2: expectedLine, accuracy: epsilon))
        // quadratic
        let q = QuadraticBezierCurve(p0: BKPoint(x: 1.0, y: 1.0),
                                     p1: BKPoint(x: 2.0, y: 2.0),
                                     p2: BKPoint(x: 3.0, y: 1.0))
        let qs = q.scale(distance: sqrt(2))
        let expectedQuadratic = QuadraticBezierCurve(p0: BKPoint(x: 0.0, y: 2.0),
                                                p1: BKPoint(x: 2.0, y: 4.0),
                                                p2: BKPoint(x: 4.0, y: 2.0))
        XCTAssert(BezierKitTests.curveControlPointsEqual(curve1: qs, curve2: expectedQuadratic, accuracy: epsilon))
        // cubic
        let c = CubicBezierCurve(p0: BKPoint(x: -4.0, y: +0.0),
                                 p1: BKPoint(x: -2.0, y: +2.0),
                                 p2: BKPoint(x: +2.0, y: +2.0),
                                 p3: BKPoint(x: +4.0, y: +0.0))
        let cs = c.scale(distance: 2.0 * sqrt(2))
        let expectedCubic = CubicBezierCurve(p0: BKPoint(x: -6.0, y: +2.0),
                                p1: BKPoint(x: -3.0, y: +5.0),
                                p2: BKPoint(x: +3.0, y: +5.0),
                                p3: BKPoint(x: +6.0, y: +2.0))
        XCTAssert(BezierKitTests.curveControlPointsEqual(curve1: cs, curve2: expectedCubic, accuracy: epsilon))
    }
    
    func testOffsetTimeDistance() {
        let epsilon: BKFloat = 1.0e-6
        let q = QuadraticBezierCurve(p0: BKPoint(x: 1.0, y: 1.0),
                                     p1: BKPoint(x: 2.0, y: 2.0),
                                     p2: BKPoint(x: 3.0, y: 1.0))
        let p0 = q.offset(t: 0.0, distance: sqrt(2))
        let p1 = q.offset(t: 0.5, distance: 1.5)
        let p2 = q.offset(t: 1.0, distance: sqrt(2))
        XCTAssert(distance(p0, BKPoint(x: 0.0, y: 2.0)) < epsilon)
        XCTAssert(distance(p1, BKPoint(x: 2.0, y: 3.0)) < epsilon)
        XCTAssert(distance(p2, BKPoint(x: 4.0, y: 2.0)) < epsilon)
    }

    func testOffsetDistance() {
        // line segments (or isLinear) have a separate codepath, so be sure to test those
        let epsilon: BKFloat = 1.0e-6
        let c1 = CubicBezierCurve(lineSegment: LineSegment(p0: BKPoint(x: 0.0, y: 0.0), p1: BKPoint(x: 1.0, y: 1.0)))
        let c1Offset = c1.offset(distance: sqrt(2))
        let expectedOffset1 = CubicBezierCurve(lineSegment: LineSegment(p0: BKPoint(x: -1.0, y: 1.0), p1: BKPoint(x: 0.0, y: 2.0)))
        XCTAssertEqual(c1Offset.count, 1)
        XCTAssert(BezierKitTests.curveControlPointsEqual(curve1: c1Offset[0] as! CubicBezierCurve, curve2: expectedOffset1, accuracy: epsilon))
        // next test a non-simple curve
        let c2 = CubicBezierCurve(p0: BKPoint(x: 1.0, y: 1.0), p1: BKPoint(x: 2.0, y: 2.0), p2: BKPoint(x: 3.0, y: 2.0), p3: BKPoint(x: 4.0, y: 1.0))
        let c2Offset = c2.offset(distance: sqrt(2))
        for i in 0..<c2Offset.count {
            let c = c2Offset[i]
            XCTAssert(c.simple)
            if i == 0 {
                // segment starts where un-reduced segment started (after ofsetting)
                XCTAssert(distance(c.startingPoint, BKPoint(x: 0.0, y: 2.0)) < epsilon)
            }
            else {
                // segment starts where last ended
                XCTAssertEqual(c.startingPoint, c2Offset[i-1].endingPoint)
            }
            if i == c2Offset.count - 1 {
                // segment ends where un-reduced segment ended (after ofsetting)
                XCTAssert(distance(c.endingPoint, BKPoint(x: 5.0, y: 2.0)) < epsilon)
            }
        }
        // TODO: fix reduce behavior for cusps (cannot be simplified because derivative is zero so normal is zero at cusp)
        // let c2 = CubicBezierCurve(p0: BKPoint(x: 1.0, y: 1.0), p1: BKPoint(x: 2.0, y: 2.0), p2: BKPoint(x: 1.0, y: 2.0), p3: BKPoint(x: 2.0, y: 1.0))
    }
    
    func testProject() {
        // line segments override the project implementation, so test them specifically
        let epsilon: BKFloat = 1.0e-3 // TODO: notice that this epsilon value is actually pretty big? it's because project uses a fixed number of iterations. See the flatness-project branch for a potential better solution.
        let l = LineSegment(p0: BKPoint(x: 1.0, y: 2.0), p1: BKPoint(x: 5.0, y: 6.0))
        let p1 = l.project(point: BKPoint(x: 0.0, y: 0.0)) // should project to p0
        XCTAssertEqual(p1, BKPoint(x: 1.0, y: 2.0))
        let p2 = l.project(point: BKPoint(x: 1.0, y: 4.0)) // should project to l.compute(0.25)
        XCTAssertEqual(p2, BKPoint(x: 2.0, y: 3.0))
        let p3 = l.project(point: BKPoint(x: 6.0, y: 7.0))
        XCTAssertEqual(p3, BKPoint(x: 5.0, y: 6.0)) // should project to p1
        // test a cubic
        let c = CubicBezierCurve(p0: BKPoint(x: 1.0, y: 1.0), p1: BKPoint(x: 2.0, y: 2.0), p2: BKPoint(x: 4.0, y: 2.0), p3: BKPoint(x: 5.0, y: 1.0))
        let p4 = c.project(point: BKPoint(x: 0.95, y: 1.05)) // should project to p0
        XCTAssertEqual(p4, BKPoint(x: 1.0, y: 1.0))
        let p5 = c.project(point: BKPoint(x: 5.05, y: 1.05)) // should project to p3
        XCTAssertEqual(p5, BKPoint(x: 5.0, y: 1.0))
        let p6 = c.project(point: BKPoint(x: 3.0, y: 2.0)) // should project to center of curve
        XCTAssertEqual(p6, BKPoint(x: 3.0, y: 1.75))
        let p7 = c.project(point: c.compute(0.831211) + c.normal(0.831211)) // should project back to (roughly) c.compute(0.831211)
        XCTAssert(distance(p7, c.compute(0.831211)) < epsilon)

    }

    
}
