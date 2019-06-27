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

    let quadratic1 = QuadraticCurve(p0: CGPoint(x: 1, y: 2),
                                          p1: CGPoint(x: 2, y: 3),
                                          p2: CGPoint(x: 3, y: 2))

    let quadratic2 = QuadraticCurve(p0: CGPoint(x: 1, y: 1),
                                          p1: CGPoint(x: 3, y: 2),
                                          p2: CGPoint(x: 1, y: 3))

    let cubic1 = CubicCurve(p0: CGPoint(x: 1, y: 2),
                                  p1: CGPoint(x: 2, y: 3),
                                  p2: CGPoint(x: 3, y: 2),
                                  p3: CGPoint(x: 4, y: 2))

    let cubic2 = CubicCurve(p0: CGPoint(x: 2, y: 1),
                                  p1: CGPoint(x: 2, y: 2),
                                  p2: CGPoint(x: 3, y: 3),
                                  p3: CGPoint(x: 2, y: 4))
    func testLineSegment() {
        XCTAssertEqual(line.flatness, 0)
        XCTAssertEqual(line.flatnessSquared, 0)
    }

    func testQuadraticCurve() {
        let quadratic1 = QuadraticCurve(p0: CGPoint(x: 1, y: 2),
                                              p1: CGPoint(x: 2, y: 3),
                                              p2: CGPoint(x: 3, y: 2))
        XCTAssertEqual(quadratic1.flatnessSquared, 0.25)
        XCTAssertEqual(quadratic1.flatness, 0.5)
        let quadratic2 = QuadraticCurve(p0: CGPoint(x: 1, y: 1),
                                              p1: CGPoint(x: 3, y: 2),
                                              p2: CGPoint(x: 1, y: 3))
        XCTAssertEqual(quadratic2.flatnessSquared, 1.0)

        let quadratic3 = QuadraticCurve(lineSegment: line)
        XCTAssertEqual(quadratic3.flatnessSquared, 0.0)
    }

    func testCubicCurve() {
        XCTAssertEqual(cubic1.flatnessSquared, 9.0 / 16.0)
        XCTAssertEqual(cubic2.flatnessSquared, 9.0 / 16.0)
        XCTAssertEqual(cubic1.flatness, 3.0 / 4.0)
        XCTAssertEqual(cubic2.flatness, 3.0 / 4.0)
        XCTAssertEqual(CubicCurve(quadratic: quadratic1).flatnessSquared, 0.25)
        XCTAssertEqual(CubicCurve(quadratic: quadratic2).flatnessSquared, 1.0)
        XCTAssertEqual(CubicCurve(lineSegment: line).flatnessSquared, 0.0)
    }
}
