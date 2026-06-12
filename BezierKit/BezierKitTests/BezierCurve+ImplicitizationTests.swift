//
//  BezierCurve+ImplicitizationTests.swift
//  BezierKit
//
//  Copyright © 2024 Holmes Futrell. All rights reserved.
//

@testable import BezierKit
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import XCTest

// Exercises the implicitization fallback in the curve/curve intersection driver. The fallback runs
// only when monotone subdivision cannot separate a near-coincident pair; it composes one curve's
// implicit polynomial with the other's parametric x/y polynomials and solves the resulting
// degree-(order × order) polynomial (4 for quad×quad, 6 for quad×cubic, 9 for cubic×cubic) with the
// fixed-degree Bézier-clipping root finder, then verifies each candidate with 2D Newton. The
// cubic×cubic (degree-9) path is additionally covered by CubicCurveTests (testRealWorldPrecisionIssue
// and the near-coincident S-curve tests).
//
// These cases are near-coincident to within a few times machine epsilon, so they require 64-bit
// CGFloat: on 32-bit (WASM) the offsets sit at the rounding floor and the genuine-vs-near-miss
// decision is no longer reliable.
#if !os(WASI)
class BezierCurve_ImplicitizationTests: XCTestCase {

    private let d: CGFloat = 5.0e-6

    // Two parabola arcs offset by `d` everywhere — near-coincident but never crossing.
    // Exercises the degree-4 (quad×quad) fallback; Newton genuine-root rejection must yield 0.
    func testQuadQuadNearCoincidentNoCrossing() {
        let q1 = QuadraticCurve(p0: CGPoint(x: 0, y: 0), p1: CGPoint(x: 1, y: 1), p2: CGPoint(x: 2, y: 0))
        let q2 = QuadraticCurve(p0: CGPoint(x: 0, y: d), p1: CGPoint(x: 1, y: 1 + d), p2: CGPoint(x: 2, y: d))
        XCTAssertEqual(q1.intersections(with: q2, accuracy: 1.0e-5), [])
    }

    // Two near-coincident parabola arcs that cross once at the symmetric midpoint (t = 0.5).
    // Exercises the degree-4 (quad×quad) fallback.
    func testQuadQuadNearCoincidentCrossing() {
        let q1 = QuadraticCurve(p0: CGPoint(x: 0, y: 0), p1: CGPoint(x: 1, y: 1), p2: CGPoint(x: 2, y: 0))
        let q2 = QuadraticCurve(p0: CGPoint(x: 0, y: -d), p1: CGPoint(x: 1, y: 1 + d), p2: CGPoint(x: 2, y: -d))
        let intersections = q1.intersections(with: q2, accuracy: 1.0e-5)
        XCTAssertEqual(intersections.count, 1)
        XCTAssertEqual(intersections[0].t1, 0.5, accuracy: 1.0e-5)
        XCTAssertEqual(intersections[0].t2, 0.5, accuracy: 1.0e-5)
        XCTAssertLessThan(distance(q1.point(at: intersections[0].t1), q2.point(at: intersections[0].t2)), 1.0e-5)
    }

    // A cubic that is `q1` elevated to cubic degree and offset by `d`, near-coincident with `q1` and
    // crossing once at the midpoint. Exercises the degree-6 (quad×cubic) fallback in both orderings.
    private func nearCoincidentQuadAndCubic() -> (QuadraticCurve, CubicCurve) {
        let q1 = QuadraticCurve(p0: CGPoint(x: 0, y: 0), p1: CGPoint(x: 1, y: 1), p2: CGPoint(x: 2, y: 0))
        let e1 = q1.p0 + (2.0 / 3.0) * (q1.p1 - q1.p0)
        let e2 = q1.p2 + (2.0 / 3.0) * (q1.p1 - q1.p2)
        let cubic = CubicCurve(p0: CGPoint(x: q1.p0.x, y: q1.p0.y + d), p1: CGPoint(x: e1.x, y: e1.y + d),
                               p2: CGPoint(x: e2.x, y: e2.y - d), p3: CGPoint(x: q1.p2.x, y: q1.p2.y - d))
        return (q1, cubic)
    }
    func testQuadCubicNearCoincidentCrossing() {
        let (q1, cubic) = nearCoincidentQuadAndCubic()
        let intersections = q1.intersections(with: cubic, accuracy: 1.0e-5)
        XCTAssertEqual(intersections.count, 1)
        XCTAssertEqual(intersections[0].t1, 0.5, accuracy: 1.0e-5)
        XCTAssertLessThan(distance(q1.point(at: intersections[0].t1), cubic.point(at: intersections[0].t2)), 1.0e-5)
    }
    func testCubicQuadNearCoincidentCrossing() {
        let (q1, cubic) = nearCoincidentQuadAndCubic()
        let intersections = cubic.intersections(with: q1, accuracy: 1.0e-5)
        XCTAssertEqual(intersections.count, 1)
        XCTAssertEqual(intersections[0].t2, 0.5, accuracy: 1.0e-5)
        XCTAssertLessThan(distance(cubic.point(at: intersections[0].t1), q1.point(at: intersections[0].t2)), 1.0e-5)
    }

    // Two near-coincident cubics whose x-coordinate is linear — i.e. degree-deficient cubics
    // (quadratics raised to cubic form) — crossing twice. The cubic implicitization of such a
    // curve is the zero polynomial, so the fallback must demote it via downgradedIfPossible before
    // implicitizing. Both crossings must be found, and the result must be argument-order symmetric.
    func testDegreeDeficientCubicMultiCrossing() {
        for delta: CGFloat in [1e-3, 1e-4, 1e-5] {
            let c1 = CubicCurve(p0: CGPoint(x: 0, y: 0), p1: CGPoint(x: 1, y: 2), p2: CGPoint(x: 2, y: 2), p3: CGPoint(x: 3, y: 0))
            let c2 = CubicCurve(p0: CGPoint(x: 0, y: delta), p1: CGPoint(x: 1, y: 2 - delta),
                                p2: CGPoint(x: 2, y: 2 - delta), p3: CGPoint(x: 3, y: delta))
            let forward = c1.intersections(with: c2, accuracy: 1.0e-5)
            let reverse = c2.intersections(with: c1, accuracy: 1.0e-5)
            XCTAssertEqual(forward.count, 2)
            XCTAssertEqual(reverse.count, 2)
            for ix in forward {
                XCTAssertLessThan(distance(c1.point(at: ix.t1), c2.point(at: ix.t2)), 1.0e-5)
            }
        }
    }
}
#endif
