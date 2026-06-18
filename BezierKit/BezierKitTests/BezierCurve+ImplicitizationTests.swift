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
// fixed-degree Bézier-clipping root finder, then accepts each candidate root t1 when curve1(t1)
// projects onto curve2 within `accuracy` (the standard project-and-check verification).
//
// Several near-coincident CROSSING cases below are wrapped in expectKnownBug: they document a known
// bug. Their separations sit below `accuracy`, where projecting onto a near-coincident curve always
// lands within `accuracy`, so the engine reports spurious extra intersections. The expectations
// assert the correct count and are kept (rather than deleted or changed to the wrong count) to
// document the bug and to flag if a future change ever fixes it.
//
// These cases are near-coincident to within a few times machine epsilon, so they require 64-bit
// CGFloat: on 32-bit (WASM) the offsets sit at the rounding floor and the genuine-vs-near-miss
// decision is no longer reliable.
#if !os(WASI)
class BezierCurve_ImplicitizationTests: XCTestCase {

    private let d: CGFloat = 5.0e-6

    // Direct validation of the implicit-polynomial math: the implicit polynomial is zero on the
    // curve it implicitizes (start, end, and an interior sample) and has opposite signs on its two
    // sides. This exercises the LineSegment/Quadratic/Cubic implicitPolynomial getters and the
    // ImplicitLine/ImplicitLineProduct algebra directly; composition with a parametric curve is
    // exercised by the intersection fallback tests below.
    func testLineSegmentImplicitization() {
        let lineSegment = LineSegment(p0: CGPoint(x: 1, y: 2), p1: CGPoint(x: 4, y: 3))
        let implicitLine = lineSegment.implicitPolynomial
        XCTAssertEqual(implicitLine.value(at: lineSegment.startingPoint), 0)
        XCTAssertEqual(implicitLine.value(at: lineSegment.endingPoint), 0)
        XCTAssertEqual(implicitLine.value(at: lineSegment.point(at: 0.25)), 0)
        XCTAssertEqual(implicitLine.value(at: CGPoint(x: 0, y: 5)), 10)
        XCTAssertEqual(implicitLine.value(at: CGPoint(x: 2, y: -1)), -10)
    }

    func testQuadraticCurveImplicitization() {
        let quadraticCurve = QuadraticCurve(p0: CGPoint(x: 0, y: 2),
                                            p1: CGPoint(x: 1, y: 0),
                                            p2: CGPoint(x: 2, y: 2))
        let implicitQuadratic = quadraticCurve.implicitPolynomial
        XCTAssertEqual(implicitQuadratic.value(at: quadraticCurve.startingPoint), 0, accuracy: 1.0e-12)
        XCTAssertEqual(implicitQuadratic.value(at: quadraticCurve.endingPoint), 0, accuracy: 1.0e-12)
        XCTAssertEqual(implicitQuadratic.value(at: quadraticCurve.point(at: 0.25)), 0, accuracy: 1.0e-12)
        XCTAssertGreaterThan(implicitQuadratic.value(at: CGPoint(x: 1, y: 2)), 0)
        XCTAssertLessThan(implicitQuadratic.value(at: CGPoint(x: 1, y: 0)), 0)
    }

    func testCubicImplicitization() {
        let cubicCurve = CubicCurve(p0: CGPoint(x: 0, y: 0),
                                    p1: CGPoint(x: 1, y: 1),
                                    p2: CGPoint(x: 2, y: 0),
                                    p3: CGPoint(x: 3, y: 1))
        let implicitCubic = cubicCurve.implicitPolynomial
        XCTAssertEqual(implicitCubic.value(at: cubicCurve.startingPoint), 0, accuracy: 1.0e-12)
        XCTAssertEqual(implicitCubic.value(at: cubicCurve.endingPoint), 0, accuracy: 1.0e-12)
        XCTAssertEqual(implicitCubic.value(at: cubicCurve.point(at: 0.25)), 0, accuracy: 1.0e-12)
        XCTAssertGreaterThan(implicitCubic.value(at: CGPoint(x: 1, y: 1)), 0)
        XCTAssertLessThan(implicitCubic.value(at: CGPoint(x: 2, y: 0)), 0)
    }

    // Two parabola arcs offset by `d` everywhere — near-coincident but never crossing.
    // Exercises the degree-4 (quad×quad) fallback; the projection test must yield 0.
    func testQuadQuadNearCoincidentNoCrossing() {
        let q1 = QuadraticCurve(p0: CGPoint(x: 0, y: 0), p1: CGPoint(x: 1, y: 1), p2: CGPoint(x: 2, y: 0))
        let q2 = QuadraticCurve(p0: CGPoint(x: 0, y: d), p1: CGPoint(x: 1, y: 1 + d), p2: CGPoint(x: 2, y: d))
        XCTAssertEqual(q1.intersections(with: q2, accuracy: 1.0e-5), [])
    }

    // Two near-coincident parabola arcs that cross once at the symmetric midpoint (t = 0.5).
    // Exercises the degree-4 (quad×quad) fallback. Sub-accuracy separation: documents a known
    // bug (see file header). Expected failure.
    func testQuadQuadNearCoincidentCrossing() {
        let q1 = QuadraticCurve(p0: CGPoint(x: 0, y: 0), p1: CGPoint(x: 1, y: 1), p2: CGPoint(x: 2, y: 0))
        let q2 = QuadraticCurve(p0: CGPoint(x: 0, y: -d), p1: CGPoint(x: 1, y: 1 + d), p2: CGPoint(x: 2, y: -d))
        expectKnownBug("known bug: sub-accuracy near-coincident crossing over-produces intersections") {
            let intersections = q1.intersections(with: q2, accuracy: 1.0e-5)
            XCTAssertEqual(intersections.count, 1)
            XCTAssertEqual(intersections[0].t1, 0.5, accuracy: 1.0e-5)
            XCTAssertEqual(intersections[0].t2, 0.5, accuracy: 1.0e-5)
            XCTAssertLessThan(distance(q1.point(at: intersections[0].t1), q2.point(at: intersections[0].t2)), 1.0e-5)
        }
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
    // Sub-accuracy separation: documents a known bug (see file header). Expected failure.
    func testQuadCubicNearCoincidentCrossing() {
        let (q1, cubic) = nearCoincidentQuadAndCubic()
        expectKnownBug("known bug: sub-accuracy near-coincident crossing over-produces intersections") {
            let intersections = q1.intersections(with: cubic, accuracy: 1.0e-5)
            XCTAssertEqual(intersections.count, 1)
            XCTAssertEqual(intersections[0].t1, 0.5, accuracy: 1.0e-5)
            XCTAssertLessThan(distance(q1.point(at: intersections[0].t1), cubic.point(at: intersections[0].t2)), 1.0e-5)
        }
    }
    // Sub-accuracy separation: documents a known bug (see file header). Expected failure.
    func testCubicQuadNearCoincidentCrossing() {
        let (q1, cubic) = nearCoincidentQuadAndCubic()
        expectKnownBug("known bug: sub-accuracy near-coincident crossing over-produces intersections") {
            let intersections = cubic.intersections(with: q1, accuracy: 1.0e-5)
            XCTAssertEqual(intersections.count, 1)
            XCTAssertEqual(intersections[0].t2, 0.5, accuracy: 1.0e-5)
            XCTAssertLessThan(distance(cubic.point(at: intersections[0].t1), q1.point(at: intersections[0].t2)), 1.0e-5)
        }
    }

    // Two near-coincident cubics whose x-coordinate is linear — i.e. degree-deficient cubics
    // (quadratics raised to cubic form) — crossing twice. The cubic implicitization of such a
    // curve is the zero polynomial, so the fallback must demote it via downgradedIfPossible before
    // implicitizing. At separations comfortably above `accuracy` both crossings are found in both
    // orderings; at δ = 1e-5 (≈ accuracy) the reverse ordering over-produces (4 instead of 2) —
    // a known bug. Expected failure for that case (see file header).
    func testDegreeDeficientCubicMultiCrossing() {
        let c1 = CubicCurve(p0: CGPoint(x: 0, y: 0), p1: CGPoint(x: 1, y: 2), p2: CGPoint(x: 2, y: 2), p3: CGPoint(x: 3, y: 0))
        func curve2(delta: CGFloat) -> CubicCurve {
            CubicCurve(p0: CGPoint(x: 0, y: delta), p1: CGPoint(x: 1, y: 2 - delta),
                       p2: CGPoint(x: 2, y: 2 - delta), p3: CGPoint(x: 3, y: delta))
        }
        for delta: CGFloat in [1e-3, 1e-4] {
            let c2 = curve2(delta: delta)
            let forward = c1.intersections(with: c2, accuracy: 1.0e-5)
            let reverse = c2.intersections(with: c1, accuracy: 1.0e-5)
            XCTAssertEqual(forward.count, 2)
            XCTAssertEqual(reverse.count, 2)
            for ix in forward {
                XCTAssertLessThan(distance(c1.point(at: ix.t1), c2.point(at: ix.t2)), 1.0e-5)
            }
        }
        let c2 = curve2(delta: 1e-5)
        XCTAssertEqual(c1.intersections(with: c2, accuracy: 1.0e-5).count, 2)
        expectKnownBug("known bug: at δ ≈ accuracy the reverse ordering over-produces") {
            XCTAssertEqual(c2.intersections(with: c1, accuracy: 1.0e-5).count, 2)
        }
    }
}
#endif
