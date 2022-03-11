//
//  PolynomialTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 5/15/20.
//  Copyright © 2020 Holmes Futrell. All rights reserved.
//

import XCTest
@testable import BezierKit

class PolynomialTests: XCTestCase {

    let accuracy: CGFloat = 1.0e-5

    func testEvaluation() {
        let point = BernsteinPolynomial0(b0: 3.0)
        XCTAssertEqual(point.reduce(a1: 1, a2: 2), 0)
        XCTAssertEqual(point.value(at: 0), 3)
        XCTAssertEqual(point.value(at: 0.5), 3)
        XCTAssertEqual(point.value(at: 1), 3)
        XCTAssertEqual(point.derivative, BernsteinPolynomial0(b0: 0.0))
        XCTAssertEqual(point.distinctAnalyticalRoots(between: 0, and: 1), [])
        XCTAssertEqual(point.coefficients, [3.0])

        let line = BernsteinPolynomial1(b0: 2.0, b1: 4.0)
        XCTAssertEqual(line.value(at: 0), 2)
        XCTAssertEqual(line.value(at: 0.5), 3)
        XCTAssertEqual(line.value(at: 1), 4)
        XCTAssertEqual(line.derivative, BernsteinPolynomial0(b0: 2))
        XCTAssertEqual(line.distinctAnalyticalRoots(between: -2, and: 1), [-1])
        XCTAssertEqual(line.distinctAnalyticalRoots(between: 0, and: 1), [])
        XCTAssertEqual(line.coefficients, [2, 4])

        let quad = BernsteinPolynomial2(b0: -1, b1: 1.0, b2: 0.0)
        XCTAssertEqual(quad.value(at: 0), -1)
        XCTAssertEqual(quad.value(at: 0.5), 0.25)
        XCTAssertEqual(quad.value(at: 1), 0)
        XCTAssertEqual(quad.derivative, BernsteinPolynomial1(b0: 4, b1: -2))
        XCTAssertEqual(quad.coefficients, [-1, 1, 0])
    }

    func testDegree1() {
        let polynomial = BernsteinPolynomial1(b0: -3, b1: 2)
        let roots = findDistinctRoots(of: polynomial, between: -1, and: 1)
        XCTAssertEqual(roots.count, 1)
        XCTAssertEqual(roots[0], CGFloat(0.6), accuracy: accuracy)
    }

    func testDegree2() {
        let polynomial = BernsteinPolynomial2(b0: -5, b1: -6, b2: -4)
        let roots = findDistinctRoots(of: polynomial, between: -10, and: 10)
        XCTAssertEqual(roots[0], -1, accuracy: accuracy)
        XCTAssertEqual(roots[1], 1.0 + 2.0 / 3.0, accuracy: accuracy)
    }

    func testDegree3() {
        // x^3 - 6x^2 + 11x - 6
        let polynomial = BernsteinPolynomial3(b0: -6, b1: -7.0 / 3.0, b2: -2.0 / 3.0, b3: 0)
        XCTAssertEqual(polynomial.coefficients, [-6, CGFloat(-7.0 / 3.0), CGFloat(-2.0 / 3.0), 0.0])
        let roots = findDistinctRoots(of: polynomial, between: 0, and: 4)
        XCTAssertEqual(roots[0], 1, accuracy: accuracy)
        XCTAssertEqual(roots[1], 2, accuracy: accuracy)
        XCTAssertEqual(roots[2], 3, accuracy: accuracy)
    }

    func testDegree3RepeatedRoot1() {
        // x^3 - 4x^2 + 5x - 2
        // repeated root at x = 1
        let polynomial = BernsteinPolynomial3(b0: -2, b1: -1.0 / 3.0, b2: 0, b3: 0)
        let roots = findDistinctRoots(of: polynomial, between: -1, and: 3)
        XCTAssertEqual(roots[0], 1, accuracy: accuracy)
        XCTAssertEqual(roots[1], 2, accuracy: accuracy)
    }

//    func testDegree3RootExactlyZero() {
//        // root is exactly t = 0 (at the start of unit interval),
//        // so may be accidentally discarded due to numerical precision
//        let polynomial = BernsteinPolynomial3(b0: 0, b1: 96, b2: -24, b3: -36)
//        let roots = findRoots(of: polynomial, between: 0, and: 1)
//        XCTAssertEqual(roots.count, 2)
//        XCTAssertEqual(roots[0], 0.0)
//        XCTAssertEqual(roots[1], 2.0 / 3.0, accuracy: accuracy)
//    }

    func testDegree4() {
        // x^4 - 2.44x^2 + 1.44
        let polynomial = BernsteinPolynomial4(b0: 1.44, b1: 1.44, b2: CGFloat(1.44 - 1.22 / 3), b3: 0.22, b4: 0)
        XCTAssertEqual(polynomial.coefficients, [1.44, 1.44, CGFloat(1.44 - 1.22 / 3), 0.22, 0])
        let roots = findDistinctRoots(of: polynomial, between: -2, and: 2)
        XCTAssertEqual(roots[0], -1.2, accuracy: accuracy)
        XCTAssertEqual(roots[1], -1, accuracy: accuracy)
        XCTAssertEqual(roots[2], 1, accuracy: accuracy)
        XCTAssertEqual(roots[3], 1.2, accuracy: accuracy)
    }
    #if !os(WASI)
    func testDegree4RepeatedRoots() {
        // x^4 - 2x^2 + 1
        let polynomial = BernsteinPolynomial4(b0: 1, b1: 1, b2: 2.0 / 3.0, b3: 0, b4: 0)
        let roots = findDistinctRoots(of: polynomial, between: -2, and: 2)
        XCTAssertEqual(roots.count, 2)
        XCTAssertEqual(roots[0], -1, accuracy: accuracy)
        XCTAssertEqual(roots[1], 1, accuracy: accuracy)
    }
    #endif
    func testDegree5() {
        // 0.2x^5 - 0.813333x^3 - 8.56x
        let polynomial = BernsteinPolynomial5(b0: 0, b1: -1.712, b2: -3.424, b3: -5.2173333, b4: -7.1733332, b5: -9.173333)
        XCTAssertEqual(polynomial.coefficients, [0, -1.712, -3.424, -5.2173333, -7.1733332, -9.173333])
        let roots = findDistinctRoots(of: polynomial, between: -4, and: 4)
        XCTAssertEqual(roots[0], -2.9806382, accuracy: accuracy)
        XCTAssertEqual(roots[1], 0, accuracy: accuracy)
        XCTAssertEqual(roots[2], 2.9806382, accuracy: accuracy)
    }

    func testDegree4RealWorldIssue() {
        let polynomial = BernsteinPolynomial4(b0: 1819945.4373168945, b1: -3353335.8194732666, b2: 3712712.6330566406, b3: -2836657.1703338623, b4: 2483314.5947265625)
        let roots = findDistinctRootsInUnitInterval(of: polynomial)
        XCTAssertEqual(roots.count, 2)
        XCTAssertEqual(roots[0], 0.15977874432923783, accuracy: 1.0e-5)
        XCTAssertEqual(roots[1], 0.407811682610126, accuracy: 1.0e-5)
    }

    func testDegreeN() {
        // 2x^2 + 2x + 1
        let polynomial = BernsteinPolynomialN(coefficients: [1, 2, 5])
        XCTAssertEqual(polynomial.derivative, BernsteinPolynomialN(coefficients: [2, 6]))
        XCTAssertEqual(polynomial.reversed(), BernsteinPolynomialN(coefficients: [5, 2, 1]))
        // some edge cases
        XCTAssertEqual(BernsteinPolynomialN(coefficients: [42]).split(from: 0.1, to: 0.9),
                       BernsteinPolynomialN(coefficients: [42]))
        XCTAssertEqual(polynomial.split(from: 1, to: 0), polynomial.reversed())
    }

    func testDegreeNRealWorldIssue() {
        // this input would cause a stack overflow if the division step of the interval
        // occurred before checking the interval's size
        // the equation has 1st, 2nd, 3rd, and 4th derivative equal to zero
        // which means that only a small portion of the interval can be clipped
        // off. This means the code always takes the divide and conquer path.
        let accuracy: CGFloat = 1.0e-5
        let polynomial = BernsteinPolynomialN(coefficients: [0, 0, 0, 0, 0, -1])
        let configuration = RootFindingConfiguration(errorThreshold: accuracy)
        let roots = polynomial.distinctRealRootsInUnitInterval(configuration: configuration)
        XCTAssertEqual(roots.count, 1)
        if roots.isEmpty == false {
            XCTAssertEqual(roots[0], 0, accuracy: accuracy)
        }
    }
}
