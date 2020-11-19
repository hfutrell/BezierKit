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

    let accuracy = 1.0e-5

    func testEvaluation() {
        let point = BerenStein0(b0: 3.0)
        XCTAssertEqual(point.f(0), 3)
        XCTAssertEqual(point.f(0.5), 3)
        XCTAssertEqual(point.f(1), 3)
        //XCTAssertEqual(point.derivative, [])
        XCTAssertEqual(point.analyticalRoots(between: 0, and: 1), [])

        let line = BerenStein1(b0: 2.0, b1: 4.0)
        XCTAssertEqual(line.f(0), 2)
        XCTAssertEqual(line.f(0.5), 3)
        XCTAssertEqual(line.f(1), 4)
        XCTAssertEqual(line.derivative, BerenStein0(b0: 2))
        XCTAssertEqual(line.analyticalRoots(between: -2, and: 1), [-1])
        XCTAssertEqual(line.analyticalRoots(between: 0, and: 1), [])

        let quad = BerenStein2(b0: -1, b1: 1.0, b2: 0.0)
        XCTAssertEqual(quad.f(0), -1)
        XCTAssertEqual(quad.f(0.5), 0.25)
        XCTAssertEqual(quad.f(1), 0)
        XCTAssertEqual(quad.derivative, BerenStein1(b0: 4, b1: -2))
    }

    func testDegree1() {
        let polynomial = BerenStein1(b0: -3, b1: 2)
        let roots = findRoots(of: polynomial, between: -1, and: 1)
        XCTAssertEqual(roots.count, 1)
        XCTAssertEqual(roots[0], 0.6, accuracy: accuracy)
    }

    func testDegree2() {
        let polynomial = BerenStein2(b0: -5, b1: -6, b2: -4)
        let roots = findRoots(of: polynomial, between: -10, and: 10)
        XCTAssertEqual(roots[0], -1, accuracy: accuracy)
        XCTAssertEqual(roots[1], 1.0 + 2.0 / 3.0, accuracy: accuracy)
    }

    func testDegree3() {
        // x^3 - 6x^2 + 11x - 6
        let polynomial = BerenStein3(b0: -6, b1: -7.0 / 3.0, b2: -2.0 / 3.0, b3: 0)
        let roots = findRoots(of: polynomial, between: 0, and: 4)
        XCTAssertEqual(roots[0], 1, accuracy: accuracy)
        XCTAssertEqual(roots[1], 2, accuracy: accuracy)
        XCTAssertEqual(roots[2], 3, accuracy: accuracy)
    }

    func testDegree3RepeatedRoot() {
        // x^3 - 4x^2 + 5x - 2
        // repeated root at x = 1
        let polynomial = BerenStein3(b0: -2, b1: -1.0 / 3.0, b2: 0, b3: 0)
        let roots = findRoots(of: polynomial, between: -1, and: 3)
        XCTAssertEqual(roots[0], 1, accuracy: accuracy)
        XCTAssertEqual(roots[1], 2, accuracy: accuracy)
    }

    func testDegree4() {
        // x^4 - 2.44x^2 + 1.44
        let polynomial = BerenStein4(b0: 1.44, b1: 1.44, b2: 1.44 - 1.22 / 3, b3: 0.22, b4: 0)
        let roots = findRoots(of: polynomial, between: -2, and: 2)
        XCTAssertEqual(roots[0], -1.2, accuracy: accuracy)
        XCTAssertEqual(roots[1], -1, accuracy: accuracy)
        XCTAssertEqual(roots[2], 1, accuracy: accuracy)
        XCTAssertEqual(roots[3], 1.2, accuracy: accuracy)
    }

    func testDegree4RepeatedRoots() {
        // x^4 - 2x^2 + 1
        let polynomial = BerenStein4(b0: 1, b1: 1, b2: 2.0 / 3.0, b3: 0, b4: 0)
        let roots = findRoots(of: polynomial, between: -2, and: 2)
        XCTAssertEqual(roots.count, 2)
        XCTAssertEqual(roots[0], -1, accuracy: accuracy)
        XCTAssertEqual(roots[1], 1, accuracy: accuracy)
    }

    func testDegree5() {
        // 0.2x^5 - 0.813333x^3 - 8.56x
        let polynomial = BerenStein5(b0: 0, b1: -1.712, b2: -3.424, b3: -5.2173333, b4: -7.1733332, b5: -9.173333)
        let roots = findRoots(of: polynomial, between: -4, and: 4)
        XCTAssertEqual(polynomial.analyticalRoots(between: -5, and: 5), nil, "shouldn't be possible to solve analytically")
        XCTAssertEqual(roots[0], -2.9806382, accuracy: accuracy)
        XCTAssertEqual(roots[1], 0, accuracy: accuracy)
        XCTAssertEqual(roots[2], 2.9806382, accuracy: accuracy)
    }

    func testDegree4RealWorldIssue() {
        let polynomial = BerenStein4(b0: 1819945.4373168945, b1: -3353335.8194732666, b2: 3712712.6330566406, b3: -2836657.1703338623, b4: 2483314.5947265625)
        let roots = findRoots(of: polynomial, between: 0, and: 1)
        XCTAssertEqual(roots.count, 2)
        XCTAssertEqual(roots[0], 0.15977874432923783, accuracy: 1.0e-5)
        XCTAssertEqual(roots[1], 0.407811682610126, accuracy: 1.0e-5)
    }
}
