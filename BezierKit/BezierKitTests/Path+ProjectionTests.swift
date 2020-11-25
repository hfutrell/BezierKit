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

class PathProjectionTests: XCTestCase {
    func testProjection() {
        XCTAssertNil(Path().project(CGPoint.zero), "projection requires non-empty path.")
        let triangle1 = { () -> Path in
            let cgPath = CGMutablePath()
            cgPath.addLines(between: [CGPoint(x: 0, y: 2),
                                      CGPoint(x: 2, y: 4),
                                      CGPoint(x: 0, y: 4)])
            cgPath.closeSubpath()
            return Path(cgPath: cgPath)
        }()
        let triangle2 = { () -> Path in
            let cgPath = CGMutablePath()
            cgPath.addLines(between: [CGPoint(x: 2, y: 1),
                                      CGPoint(x: 3, y: 1),
                                      CGPoint(x: 3, y: 2)])
            cgPath.closeSubpath()
            return Path(cgPath: cgPath)
        }()
        let square = Path(rect: CGRect(x: 3, y: 3, width: 1, height: 1))
        let path = Path(components: triangle1.components + triangle2.components + square.components)
        let projection = path.project(CGPoint(x: 2, y: 2))
        XCTAssertEqual(projection?.location, IndexedPathLocation(componentIndex: 1, elementIndex: 2, t: 0.5))
        XCTAssertEqual(projection?.point, CGPoint(x: 2.5, y: 1.5))
    }
    func testPointIsWithinDistanceOfBoundary() {

        let circleCGPath = CGMutablePath()
        circleCGPath.addEllipse(in: CGRect(origin: CGPoint(x: -1.0, y: -1.0), size: CGSize(width: 2.0, height: 2.0)))

        let circlePath = Path(cgPath: circleCGPath) // a circle centered at origin with radius 1

        let d = CGFloat(0.1)
        let p1 = CGPoint(x: -3.0, y: 0.0)
        let p2 = CGPoint(x: -0.9, y: 0.9)
        let p3 = CGPoint(x: 0.75, y: 0.75)
        let p4 = CGPoint(x: 0.5, y: 0.5)

        XCTAssertFalse(circlePath.pointIsWithinDistanceOfBoundary(p1, distance: d)) // no, path bounding box isn't even within that distance
        XCTAssertFalse(circlePath.pointIsWithinDistanceOfBoundary(p2, distance: d)) // no, within bounding box, but no individual curves are within that distance
        XCTAssertTrue(circlePath.pointIsWithinDistanceOfBoundary(p3, distance: d))  // yes, one of the curves that makes up the circle is within that distance
        XCTAssertTrue(circlePath.pointIsWithinDistanceOfBoundary(p3, distance: CGFloat(10.0)))  // yes, so obviously within that distance implementation should early return yes
        XCTAssertFalse(circlePath.pointIsWithinDistanceOfBoundary(p4, distance: d)) // no, we are inside the path but too far from the boundary

    }
}

#endif
