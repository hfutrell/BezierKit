//
//  BezierCurve+ImplicitizationTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 5/10/21.
//  Copyright © 2021 Holmes Futrell. All rights reserved.
//

@testable import BezierKit
import XCTest

class BezierCurve_ImplicitizationTests: XCTestCase {

    func testLineSegmentImplicitization() {
        let lineSegment = LineSegment(p0: CGPoint(x: 1, y: 2), p1: CGPoint(x: 4, y: 3))
        let implicitLine = lineSegment.implicitPolynomial
        XCTAssertEqual(implicitLine.value(at: lineSegment.startingPoint), 0)
        XCTAssertEqual(implicitLine.value(at: lineSegment.endingPoint), 0)
        XCTAssertEqual(implicitLine.value(at: lineSegment.point(at: 0.25)), 0)
        XCTAssertEqual(implicitLine.value(at: CGPoint(x: 0, y: 5)), 10)
        XCTAssertEqual(implicitLine.value(at: CGPoint(x: 2, y: -1)), -10)
        // check the implicit line composed with a parametric line
        let otherLineSegment = LineSegment(p0: CGPoint(x: 0, y: 5), p1: CGPoint(x: 2, y: -1))
        let xPolynomial = BernsteinPolynomialN(coefficients: otherLineSegment.xPolynomial.coefficients)
        let yPolynomial = BernsteinPolynomialN(coefficients: otherLineSegment.yPolynomial.coefficients)
        let polynomialComposedWithLine = implicitLine.value(xPolynomial, yPolynomial)
        XCTAssertEqual(polynomialComposedWithLine.value(at: 0), 10)
        XCTAssertEqual(polynomialComposedWithLine.value(at: 1), -10)
    }

    func testQuadraticCurveImplicitization() {
        let quadraticCurve = QuadraticCurve(p0: CGPoint(x: 0, y: 2),
                                            p1: CGPoint(x: 1, y: 0),
                                            p2: CGPoint(x: 2, y: 2))
        let implicitQuadratic = quadraticCurve.implicitPolynomial
        XCTAssertEqual(implicitQuadratic.value(at: quadraticCurve.startingPoint), 0)
        XCTAssertEqual(implicitQuadratic.value(at: quadraticCurve.endingPoint), 0)
        XCTAssertEqual(implicitQuadratic.value(at: quadraticCurve.point(at: 0.25)), 0)
        let valueAbove = implicitQuadratic.value(at: CGPoint(x: 1, y: 2))
        let valueBelow = implicitQuadratic.value(at: CGPoint(x: 1, y: 0))
        XCTAssertGreaterThan(valueAbove, 0)
        XCTAssertLessThan(valueBelow, 0)
        // check the implicit quadratic composed with an parametric quadratic
        let otherQuadratic = QuadraticCurve(p0: CGPoint(x: 1, y: 2),
                                            p1: CGPoint(x: 1, y: 1),
                                            p2: CGPoint(x: 1, y: 0))
        let polynomialComposedWithQuadratic = implicitQuadratic.value(otherQuadratic.xPolynomial, otherQuadratic.yPolynomial)
        XCTAssertEqual(polynomialComposedWithQuadratic.value(at: 0), valueAbove)
        XCTAssertEqual(polynomialComposedWithQuadratic.value(at: 0.5), 0)
        XCTAssertEqual(polynomialComposedWithQuadratic.value(at: 1), valueBelow)
    }

    func testCubicImplicitization() {
        let cubicCurve = CubicCurve(p0: CGPoint(x: 0, y: 0),
                                    p1: CGPoint(x: 1, y: 1),
                                    p2: CGPoint(x: 2, y: 0),
                                    p3: CGPoint(x: 3, y: 1))
        let implicitCubic = cubicCurve.implicitPolynomial
        XCTAssertEqual(implicitCubic.value(at: cubicCurve.startingPoint), 0)
        XCTAssertEqual(implicitCubic.value(at: cubicCurve.endingPoint), 0)
        XCTAssertEqual(implicitCubic.value(at: cubicCurve.point(at: 0.25)), 0)
        let valueAbove = implicitCubic.value(at: CGPoint(x: 1, y: 1))
        let valueBelow = implicitCubic.value(at: CGPoint(x: 2, y: 0))
        XCTAssertGreaterThan(valueAbove, 0)
        XCTAssertLessThan(valueBelow, 0)
        // check the implicit quadratic composed with a parametric line
        let lineSegment = LineSegment(p0: CGPoint(x: 1, y: 1), p1: CGPoint(x: 2, y: 0))
        let polynomialComposedWithLineSegment = implicitCubic.value(lineSegment.xPolynomial, lineSegment.yPolynomial)
        XCTAssertEqual(polynomialComposedWithLineSegment.value(at: 0), valueAbove)
        XCTAssertEqual(polynomialComposedWithLineSegment.value(at: 1), valueBelow)
        XCTAssertEqual(polynomialComposedWithLineSegment.value(at: 0.5), 0)
    }
}
