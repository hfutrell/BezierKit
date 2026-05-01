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
        XCTAssertEqual(point.value(at: 0), 3)
        XCTAssertEqual(point.value(at: 0.5), 3)
        XCTAssertEqual(point.value(at: 1), 3)
        XCTAssertEqual(point.derivative, BernsteinPolynomial0(b0: 0.0))
        XCTAssertEqual(findDistinctRootsInUnitInterval(of: point), [])
        XCTAssertEqual(point.b0, 3.0)

        let line = BernsteinPolynomial1(b0: 2.0, b1: 4.0)
        XCTAssertEqual(line.value(at: 0), 2)
        XCTAssertEqual(line.value(at: 0.5), 3)
        XCTAssertEqual(line.value(at: 1), 4)
        XCTAssertEqual(line.derivative, BernsteinPolynomial0(b0: 2))
        XCTAssertEqual(findDistinctRootsInUnitInterval(of: line), [])
        XCTAssertEqual(line.b0, 2)
        XCTAssertEqual(line.b1, 4)

        let quad = BernsteinPolynomial2(b0: -1, b1: 1.0, b2: 0.0)
        XCTAssertEqual(quad.value(at: 0), -1)
        XCTAssertEqual(quad.value(at: 0.5), 0.25)
        XCTAssertEqual(quad.value(at: 1), 0)
        XCTAssertEqual(quad.derivative, BernsteinPolynomial1(b0: 4, b1: -2))
        XCTAssertEqual(quad.b0, -1)
        XCTAssertEqual(quad.b1, 1)
        XCTAssertEqual(quad.b2, 0)
    }

    func testDegree3RootExactlyZero() {
        // root is exactly t = 0 (at the start of unit interval),
        // so may be accidentally discarded due to numerical precision
        let polynomial = BernsteinPolynomial3(b0: 0, b1: 96, b2: -24, b3: -36)
        let roots = findDistinctRootsInUnitInterval(of: polynomial)
        XCTAssertEqual(roots.count, 2)
        XCTAssertEqual(roots[0], 0.0)
        XCTAssertEqual(roots[1], 2.0 / 3.0, accuracy: accuracy)
    }

    func testDegree4RealWorldIssue() {
        let polynomial = BernsteinPolynomial4(b0: 1819945.4373168945, b1: -3353335.8194732666, b2: 3712712.6330566406, b3: -2836657.1703338623, b4: 2483314.5947265625)
        let roots = findDistinctRootsInUnitInterval(of: polynomial)
        XCTAssertEqual(roots.count, 2)
        XCTAssertEqual(roots[0], 0.15977874432923783, accuracy: 1.0e-5)
        XCTAssertEqual(roots[1], 0.407811682610126, accuracy: 1.0e-5)
    }

    func testDegree5RealWorldIssue() {
        // Newton iteration does not converge and may return a non-root without the residual check.
        let polynomial = BernsteinPolynomial5(b0: -68686.64586343056,
                                              b1: 102389.02112160496,
                                              b2: -163207.59913132348,
                                              b3: 177077.4933777841,
                                              b4: -108411.70135107233,
                                              b5: 57838.81668210728)
        let roots = findDistinctRootsInUnitInterval(of: polynomial)
        XCTAssertEqual(roots.count, 1)
        XCTAssertEqual(roots[0], 0.44454, accuracy: 1.0e-5)
    }

    func testDegree4RootAtLeftEndpoint() {
        // degree-elevation of 2t(1-2t): roots at t=0 and t=0.5
        let polynomial = BernsteinPolynomial4(b0: 0, b1: 0.5, b2: 1.0 / 3.0, b3: -0.5, b4: -2)
        let roots = findDistinctRootsInUnitInterval(of: polynomial)
        XCTAssertEqual(roots.count, 2)
        XCTAssertEqual(roots[0], 0.0, accuracy: accuracy)
        XCTAssertEqual(roots[1], 0.5, accuracy: accuracy)
    }

    func testDegree4SpuriousRootIssue() {
        let polynomial = BernsteinPolynomial4(b0: -0.14644808172857054,
                                              b1: -0.07322397770821555,
                                              b2: -0.024407908361312264,
                                              b3: 9.473515889812933e-08,
                                              b4: 4.217515225946045e-12)
        let roots = findDistinctRootsInUnitInterval(of: polynomial)
        XCTAssertEqual(roots.count, 1)
        XCTAssertEqual(roots[0], CGFloat(0.9999932), accuracy: 1.0e-5)
    }

    func testBezierClippingNoRootSpuriousHullCrossing() {
        // [1, -1e-11, 1] has no real roots (min value ≈ 0.5), but one control point
        // lies just below y=0. Without the signChanges == 0 early-exit guard the hull
        // sees that tiny dip, converges to an interval of width ~1e-11, and reports a
        // false root at t ≈ 0.5.
        let polynomial = BernsteinPolynomial2(b0: 1.0, b1: -1e-11, b2: 1.0)
        var roots: [CGFloat] = []
        findDistinctRootsCallbackBezierClipping(polynomial) { roots.append($0) }
        XCTAssertTrue(roots.isEmpty)
    }

    func testBezierClippingRealWorldIssue() {
        // this input would cause a stack overflow if the division step of the interval
        // occurred before checking the interval's size:
        // the 1st–4th derivatives are all zero, so only a tiny portion of the interval
        // is clipped each pass, forcing divide-and-conquer every time.
        let polynomial = BernsteinPolynomial5(b0: 0, b1: 0, b2: 0, b3: 0, b4: 0, b5: -1)
        var roots: [CGFloat] = []
        findDistinctRootsCallbackBezierClipping(polynomial) { roots.append($0) }
        XCTAssertEqual(roots.count, 1)
        XCTAssertEqual(roots.first ?? -1, 0, accuracy: 1.0e-5)
    }
}
