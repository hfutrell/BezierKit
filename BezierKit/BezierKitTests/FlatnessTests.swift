//
//  FlatnessTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 3/26/19.
//  Copyright © 2019 Holmes Futrell. All rights reserved.
//

import XCTest
@testable import BezierKit

class FlatnessTests: XCTestCase {

    let line = LineSegment(p0: CGPoint(x: 1, y: 2), p1: CGPoint(x: 3, y: 4))

    let quadratic1 = QuadraticBezierCurve(p0: CGPoint(x: 1, y: 2),
                                          p1: CGPoint(x: 2, y: 3),
                                          p2: CGPoint(x: 3, y: 2))

    let quadratic2 = QuadraticBezierCurve(p0: CGPoint(x: 1, y: 1),
                                          p1: CGPoint(x: 3, y: 2),
                                          p2: CGPoint(x: 1, y: 3))

    let cubic1 = CubicBezierCurve(p0: CGPoint(x: 1, y: 2),
                                  p1: CGPoint(x: 2, y: 3),
                                  p2: CGPoint(x: 3, y: 2),
                                  p3: CGPoint(x: 4, y: 2))

    let cubic2 = CubicBezierCurve(p0: CGPoint(x: 2, y: 1),
                                  p1: CGPoint(x: 2, y: 2),
                                  p2: CGPoint(x: 3, y: 3),
                                  p3: CGPoint(x: 2, y: 4))
    func testLineSegment() {
        XCTAssertEqual(line.flatness, 0)
    }

    func testQuadraticBezierCurve() {
        let quadratic1 = QuadraticBezierCurve(p0: CGPoint(x: 1, y: 2),
                                              p1: CGPoint(x: 2, y: 3),
                                              p2: CGPoint(x: 3, y: 2))
        XCTAssertEqual(quadratic1.flatness, 0.25)
        let quadratic2 = QuadraticBezierCurve(p0: CGPoint(x: 1, y: 1),
                                              p1: CGPoint(x: 3, y: 2),
                                              p2: CGPoint(x: 1, y: 3))
        XCTAssertEqual(quadratic2.flatness, 1.0)

        let quadratic3 = QuadraticBezierCurve(lineSegment: line)
        XCTAssertEqual(quadratic3.flatness, 0.0)
    }

    func testCubicBezierCurve() {
        XCTAssertEqual(cubic1.flatness, 9.0 / 16.0)
        XCTAssertEqual(cubic2.flatness, 9.0 / 16.0)
        XCTAssertEqual(CubicBezierCurve(quadratic: quadratic1).flatness, 0.25)
        XCTAssertEqual(CubicBezierCurve(quadratic: quadratic2).flatness, 1.0)
        XCTAssertEqual(CubicBezierCurve(lineSegment: line).flatness, 0.0)
    }

}
