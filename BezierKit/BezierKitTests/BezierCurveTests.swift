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

}
