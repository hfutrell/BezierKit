//
//  Path+ProjectionTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 11/23/20.
//  Copyright © 2020 Holmes Futrell. All rights reserved.
//

@testable import BezierKit
import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif

class PathProjectionTests: XCTestCase {
    func testProjection() {
        XCTAssertNil(Path().project(CGPoint.zero), "projection requires non-empty path.")
        let triangle1 = Path(components: [PathComponent(curves: [
            LineSegment(p0: CGPoint(x: 0, y: 2), p1: CGPoint(x: 2, y: 4)),
            LineSegment(p0: CGPoint(x: 2, y: 4), p1: CGPoint(x: 0, y: 4)),
            LineSegment(p0: CGPoint(x: 0, y: 4), p1: CGPoint(x: 0, y: 2))
        ])])
        let triangle2 = Path(components: [PathComponent(curves: [
            LineSegment(p0: CGPoint(x: 2, y: 1), p1: CGPoint(x: 3, y: 1)),
            LineSegment(p0: CGPoint(x: 3, y: 1), p1: CGPoint(x: 3, y: 2)),
            LineSegment(p0: CGPoint(x: 3, y: 2), p1: CGPoint(x: 2, y: 1))
        ])])
        let square = Path(rect: CGRect(x: 3, y: 3, width: 1, height: 1))
        let path = Path(components: triangle1.components + triangle2.components + square.components)
        let projection = path.project(CGPoint(x: 2, y: 2))
        XCTAssertEqual(projection?.location, IndexedPathLocation(componentIndex: 1, elementIndex: 2, t: 0.5))
        XCTAssertEqual(projection?.point, CGPoint(x: 2.5, y: 1.5))
    }

    func testPointIsWithinDistanceOfBoundary() {
        let k: CGFloat = 0.5522847498  // 4/3 * tan(π/8)
        let circlePath = Path(components: [PathComponent(curves: [
            CubicCurve(p0: CGPoint(x: 1, y: 0),  p1: CGPoint(x: 1, y: k),   p2: CGPoint(x: k, y: 1),   p3: CGPoint(x: 0, y: 1)),
            CubicCurve(p0: CGPoint(x: 0, y: 1),  p1: CGPoint(x: -k, y: 1),  p2: CGPoint(x: -1, y: k),  p3: CGPoint(x: -1, y: 0)),
            CubicCurve(p0: CGPoint(x: -1, y: 0), p1: CGPoint(x: -1, y: -k), p2: CGPoint(x: -k, y: -1), p3: CGPoint(x: 0, y: -1)),
            CubicCurve(p0: CGPoint(x: 0, y: -1), p1: CGPoint(x: k, y: -1),  p2: CGPoint(x: 1, y: -k),  p3: CGPoint(x: 1, y: 0))
        ])])

        let d = CGFloat(0.1)
        let p1 = CGPoint(x: -3.0, y: 0.0)
        let p2 = CGPoint(x: -0.9, y: 0.9)
        let p3 = CGPoint(x: 0.75, y: 0.75)
        let p4 = CGPoint(x: 0.5, y: 0.5)

        XCTAssertFalse(circlePath.pointIsWithinDistanceOfBoundary(p1, distance: d))
        XCTAssertFalse(circlePath.pointIsWithinDistanceOfBoundary(p2, distance: d))
        XCTAssertTrue(circlePath.pointIsWithinDistanceOfBoundary(p3, distance: d))
        XCTAssertTrue(circlePath.pointIsWithinDistanceOfBoundary(p3, distance: CGFloat(10.0)))
        XCTAssertFalse(circlePath.pointIsWithinDistanceOfBoundary(p4, distance: d))
    }

#if canImport(CoreGraphics)
    func testPointIsWithinDistanceOfBoundaryNaN() {
        let rectangularCGPathWithNaN = CGPath(rect: CGRect(x: CGFloat.nan, y: 0, width: 1, height: 1), transform: nil)
        let rectangularPathWithNaN = Path(cgPath: rectangularCGPathWithNaN)
        let p1 = CGPoint(x: 2.0, y: 2.0)
        XCTAssertFalse(rectangularPathWithNaN.pointIsWithinDistanceOfBoundary(p1, distance: 2.0))
    }
#endif
}
