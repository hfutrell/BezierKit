// ArcTests.swift
// BezierKit
//
// Created by Holmes Futrell

import XCTest
@testable import BezierKit

class ArcTests: XCTestCase {

    private let twoPi = 2 * CGFloat.pi

    // MARK: - arcParameter

    func testArcParameterMidArc() {
        // Simple CCW arc from 0 to π/2; point at t=0.5 should map to 0.5.
        let arc = Arc(center: .zero, radius: 1.0, startAngle: 0, endAngle: CGFloat.pi / 2)
        let angle = CGFloat.pi / 4
        let pt = CGPoint(x: cos(angle), y: sin(angle))
        let t = arcParameter(arc, point: pt, tolerance: 1e-4)
        XCTAssertNotNil(t)
        XCTAssertEqual(t!, 0.5, accuracy: 1e-4)
    }

    func testArcParameterStartAndEnd() {
        let arc = Arc(center: .zero, radius: 1.0, startAngle: 0, endAngle: CGFloat.pi / 2)
        let tStart = arcParameter(arc, point: CGPoint(x: 1, y: 0), tolerance: 1e-4)
        let tEnd   = arcParameter(arc, point: CGPoint(x: 0, y: 1), tolerance: 1e-4)
        XCTAssertEqual(tStart!, 0.0, accuracy: 1e-4)
        XCTAssertEqual(tEnd!,   1.0, accuracy: 1e-4)
    }

    func testArcParameterOffArc() {
        // Point not on arc should return nil.
        let arc = Arc(center: .zero, radius: 1.0, startAngle: 0, endAngle: CGFloat.pi / 2)
        XCTAssertNil(arcParameter(arc, point: CGPoint(x: 2, y: 0), tolerance: 1e-4))
    }

    func testArcParameterOutsideAngularRange() {
        // Point on the circle but not within the angular range returns nil.
        let arc = Arc(center: .zero, radius: 1.0, startAngle: 0, endAngle: CGFloat.pi / 2)
        // Angle 3π/4 is on the circle but outside [0, π/2].
        let angle = CGFloat(3) * CGFloat.pi / 4
        let pt = CGPoint(x: cos(angle), y: sin(angle))
        XCTAssertNil(arcParameter(arc, point: pt, tolerance: 1e-4))
    }

    // MARK: - endAngle > π (CCW arc crossing the atan2 branch cut)

    func testArcParameterCCWCrossingBranchCut() {
        // CCW arc: startAngle = 3π/4, endAngle = 5π/4.
        // 5π/4 > π, so the arc end point's atan2 value is wrapped to -3π/4.
        // arcParameter must handle this with the +2π adjustment.
        let startAngle = CGFloat(3) * CGFloat.pi / 4
        let endAngle   = startAngle + CGFloat.pi / 2   // 5π/4 ≈ 3.93 > π
        let arc = Arc(center: .zero, radius: 1.0, startAngle: startAngle, endAngle: endAngle)
        // t=0 → startAngle point
        let ptStart = CGPoint(x: cos(startAngle), y: sin(startAngle))
        XCTAssertEqual(arcParameter(arc, point: ptStart, tolerance: 1e-4)!, 0.0, accuracy: 1e-4)
        // t=1 → endAngle point; atan2 returns endAngle - 2π ≈ -0.785
        let ptEnd = CGPoint(x: cos(endAngle), y: sin(endAngle))
        let tEnd = arcParameter(arc, point: ptEnd, tolerance: 1e-4)
        XCTAssertNotNil(tEnd, "arcParameter must handle endAngle > π via +2π adjustment")
        XCTAssertEqual(tEnd!, 1.0, accuracy: 1e-4)
        // t=0.5 → midpoint
        let midAngle = startAngle + CGFloat.pi / 4
        let ptMid = CGPoint(x: cos(midAngle), y: sin(midAngle))
        XCTAssertEqual(arcParameter(arc, point: ptMid, tolerance: 1e-4)!, 0.5, accuracy: 1e-4)
    }

    // MARK: - endAngle < -π (CW arc crossing the atan2 branch cut)

    func testArcParameterCWCrossingBranchCut() {
        // CW arc: startAngle = -3π/4, endAngle = -5π/4.
        // -5π/4 < -π, so the arc end point's atan2 value is wrapped to 3π/4.
        // arcParameter must handle this with the -2π adjustment.
        let startAngle = CGFloat(-3) * CGFloat.pi / 4
        let endAngle   = startAngle - CGFloat.pi / 2    // -5π/4 ≈ -3.93 < -π
        let arc = Arc(center: .zero, radius: 1.0, startAngle: startAngle, endAngle: endAngle)
        // t=0 → startAngle point
        let ptStart = CGPoint(x: cos(startAngle), y: sin(startAngle))
        XCTAssertEqual(arcParameter(arc, point: ptStart, tolerance: 1e-4)!, 0.0, accuracy: 1e-4)
        // t=1 → endAngle point; atan2 returns endAngle + 2π ≈ 0.785
        let ptEnd = CGPoint(x: cos(endAngle), y: sin(endAngle))
        let tEnd = arcParameter(arc, point: ptEnd, tolerance: 1e-4)
        XCTAssertNotNil(tEnd, "arcParameter must handle endAngle < -π via -2π adjustment")
        XCTAssertEqual(tEnd!, 1.0, accuracy: 1e-4)
        // t=0.5 → midpoint
        let midAngle = startAngle - CGFloat.pi / 4
        let ptMid = CGPoint(x: cos(midAngle), y: sin(midAngle))
        XCTAssertEqual(arcParameter(arc, point: ptMid, tolerance: 1e-4)!, 0.5, accuracy: 1e-4)
    }

    // Point on circle at angle outside the arc's range but close enough that a
    // naive ±2π adjustment would incorrectly admit it — must still return nil.
    func testArcParameterCCWBranchCutOutsideRange() {
        // CCW arc from 3π/4 to 5π/4. A point just before start should return nil.
        let startAngle = CGFloat(3) * CGFloat.pi / 4
        let endAngle   = startAngle + CGFloat.pi / 2
        let arc = Arc(center: .zero, radius: 1.0, startAngle: startAngle, endAngle: endAngle)
        let justBefore = startAngle - 0.1
        let pt = CGPoint(x: cos(justBefore), y: sin(justBefore))
        XCTAssertNil(arcParameter(arc, point: pt, tolerance: 1e-4))
    }
}
