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

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    let accuracy = 1.0e-5

    func testDegree2() {
        let polynomial = PolynomialDegree2(a2: 3, a1: -2, a0: -5)
        let roots = findRoots(of: polynomial, between: -10, and: 10)
        XCTAssertEqual(roots[0], -1, accuracy: accuracy)
        XCTAssertEqual(roots[1], 1.0 + 2.0 / 3.0, accuracy: accuracy)
    }

    func testDegree3() {
        let polynomial = PolynomialDegree3(a3: 1, a2: -6, a1: 11, a0: -6)
        let roots = findRoots(of: polynomial, between: 0, and: 4)
        XCTAssertEqual(roots[0], 1, accuracy: accuracy)
        XCTAssertEqual(roots[1], 2, accuracy: accuracy)
        XCTAssertEqual(roots[2], 3, accuracy: accuracy)
    }

    func testDegree3RepeatedRoot() {
        let polynomial = PolynomialDegree3(a3: 1, a2: -4, a1: 5, a0: -2)
        let roots = findRoots(of: polynomial, between: -1, and: 3)
        XCTAssertEqual(roots[0], 1, accuracy: accuracy)
        XCTAssertEqual(roots[1], 2, accuracy: accuracy)
    }

    func testDegree4() {
        let polynomial = PolynomialDegree4(a4: 1, a3: -2.22045e-16, a2: -2.44, a1: -2.22045e-16, a0: 1.44)
        let roots = findRoots(of: polynomial, between: -2, and: 2)
        XCTAssertEqual(roots[0], -1.2, accuracy: accuracy)
        XCTAssertEqual(roots[1], -1, accuracy: accuracy)
        XCTAssertEqual(roots[2], 1, accuracy: accuracy)
        XCTAssertEqual(roots[3], 1.2, accuracy: accuracy)
    }

    func testDegree5() {
        let polynomial = PolynomialDegree5(a5: 0.2, a4: 0, a3: -0.813333, a2: 0, a1: -8.56, a0: 0)
        let roots = findRoots(of: polynomial, between: -4, and: 4)
        XCTAssertEqual(roots[0], -2.9806382, accuracy: accuracy)
        XCTAssertEqual(roots[1], 0, accuracy: accuracy)
        XCTAssertEqual(roots[2], 2.9806382, accuracy: accuracy)
    }
}
