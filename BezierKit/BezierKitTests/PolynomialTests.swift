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
        let scratchPad = UnsafeMutableBufferPointer<Double>.allocate(capacity: 5)
        defer { scratchPad.deallocate() }
        let line = [2.0, 4.0]
        XCTAssertEqual(line.f(0, scratchPad), 2)
        XCTAssertEqual(line.f(0.5, scratchPad), 3)
        XCTAssertEqual(line.f(1, scratchPad), 4)
        XCTAssertEqual(line.derivative, [2])

        let quad = [-1, 1.0, 0.0]
        XCTAssertEqual(quad.f(0, scratchPad), -1)
        XCTAssertEqual(quad.f(0.5, scratchPad), 0.25)
        XCTAssertEqual(quad.f(1, scratchPad), 0)
        XCTAssertEqual(quad.derivative, [4, -2])
    }

    func testDegree2() {
        let scratchPad = UnsafeMutableBufferPointer<Double>.allocate(capacity: 3)
        defer { scratchPad.deallocate() }
        let polynomial: [Double] = [-5, -6, -4]
        let roots = findRoots(of: polynomial, between: -10, and: 10, scratchPad: scratchPad)
        XCTAssertEqual(roots[0], -1, accuracy: accuracy)
        XCTAssertEqual(roots[1], 1.0 + 2.0 / 3.0, accuracy: accuracy)
    }

    func testDegree3() {
        // x^3 - 6x^2 + 11x - 6
        let scratchPad = UnsafeMutableBufferPointer<Double>.allocate(capacity: 4)
        defer { scratchPad.deallocate() }
        let polynomial: [Double] = [-6, -7.0 / 3.0, -2.0 / 3.0, 0]
        let roots = findRoots(of: polynomial, between: 0, and: 4, scratchPad: scratchPad)
        XCTAssertEqual(roots[0], 1, accuracy: accuracy)
        XCTAssertEqual(roots[1], 2, accuracy: accuracy)
        XCTAssertEqual(roots[2], 3, accuracy: accuracy)
    }

    func testDegree3RepeatedRoot() {
        // x^3 - 4x^2 + 5x - 2
        // repeated root at x = 1
        let scratchPad = UnsafeMutableBufferPointer<Double>.allocate(capacity: 4)
        defer { scratchPad.deallocate() }
        let polynomial = [-2, -1.0 / 3.0, 0, 0]
        let roots = findRoots(of: polynomial, between: -1, and: 3, scratchPad: scratchPad)
        XCTAssertEqual(roots[0], 1, accuracy: accuracy)
        XCTAssertEqual(roots[1], 2, accuracy: accuracy)
    }

    func testDegree4() {
        // x^4 - 2.44x^2 + 1.44
        let scratchPad = UnsafeMutableBufferPointer<Double>.allocate(capacity: 5)
        defer { scratchPad.deallocate() }
        let polynomial = [1.44, 1.44, 1.44 - 1.22 / 3, 0.22, 0]
        let roots = findRoots(of: polynomial, between: -2, and: 2, scratchPad: scratchPad)
        XCTAssertEqual(roots[0], -1.2, accuracy: accuracy)
        XCTAssertEqual(roots[1], -1, accuracy: accuracy)
        XCTAssertEqual(roots[2], 1, accuracy: accuracy)
        XCTAssertEqual(roots[3], 1.2, accuracy: accuracy)
    }

    func testDegree5() {
        let scratchPad = UnsafeMutableBufferPointer<Double>.allocate(capacity: 6)
        defer { scratchPad.deallocate() }
        // 0.2x^5 - 0.813333x^3 - 8.56x
        let polynomial = [0, -1.712, -3.424, -5.2173333, -7.1733332, -9.173333]
        let roots = findRoots(of: polynomial, between: -4, and: 4, scratchPad: scratchPad)
        XCTAssertEqual(roots[0], -2.9806382, accuracy: accuracy)
        XCTAssertEqual(roots[1], 0, accuracy: accuracy)
        XCTAssertEqual(roots[2], 2.9806382, accuracy: accuracy)
    }
}