//
//  BezierCurve+PolynomialTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 1/22/21.
//  Copyright © 2021 Holmes Futrell. All rights reserved.
//

import BezierKit
import XCTest

class BezierCurve_PolynomialTests: XCTestCase {

    func testExtremaLine() {
        let l1 = LineSegment(p0: CGPoint(x: 1.0, y: 2.0), p1: CGPoint(x: 4.0, y: 6.0))
        let (x1, y1, all1) = l1.extrema()
        XCTAssertTrue(x1.isEmpty)
        XCTAssertTrue(y1.isEmpty)
        XCTAssertTrue(all1.isEmpty)

        let l2 = LineSegment(p0: CGPoint(x: 1.0, y: 2.0), p1: CGPoint(x: 4.0, y: 2.0))
        let (x2, y2, all2) = l2.extrema()
        XCTAssertTrue(x2.isEmpty)
        XCTAssertTrue(y2.isEmpty)
        XCTAssertTrue(all2.isEmpty)
    }

    func testExtremaQuadratic() {
        let f: [CGFloat] = [4, -2, 1] // f(t) = 4t^2 - 2t + 1, which has a local minimum at t = 0.25
        let g: [CGFloat] = [1, -4, 4] // g(t) = t^2 -4t + 4, which has a local minimum at t = 2 (outside parameter range)
        let q = BezierKitTestHelpers.quadraticCurveFromPolynomials(f, g)
        let (x, y, all) = q.extrema()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0], 0.25)
        XCTAssertEqual(x.count, 1)
        XCTAssertEqual(x[0], 0.25)
        XCTAssertTrue(y.isEmpty)
    }

    func testExtremaCubic() {
        let f: [CGFloat] = [1, -1, 0, 0] // f(t) = t^3 - t^2, which has two local minimum at t=0, t=2/3 and an inflection point t=1/3
        let g: [CGFloat] = [0, 3, -2, 0] // g(t) = 3t^2 - 2t, which has a local minimum at t=1/3
        let c = BezierKitTestHelpers.cubicCurveFromPolynomials(f, g)
        let (x, y, all) = c.extrema()
        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(all[0], 0.0)
        XCTAssertEqual(all[1], 1.0 / 3.0)
        XCTAssertEqual(all[2], 2.0 / 3.0)
        XCTAssertEqual(x[0], 0.0)
        XCTAssertEqual(x[1], 1.0 / 3.0)
        XCTAssertEqual(x[2], 2.0 / 3.0)
        XCTAssertEqual(y.count, 1)
        XCTAssertEqual(y[0], 1.0 / 3.0)
    }
}
