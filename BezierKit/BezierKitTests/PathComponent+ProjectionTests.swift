//
//  PathComponent+ProjectionTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 11/23/20.
//  Copyright © 2020 Holmes Futrell. All rights reserved.
//

@testable import BezierKit
import XCTest

#if canImport(CoreGraphics)
import CoreGraphics

class PathComponentProjectionTests: XCTestCase {
    func testProject() {
        let line = PathComponent(curve: LineSegment(p0: CGPoint(x: 1, y: 1), p1: CGPoint(x: 2, y: 2)))
        let point1 = CGPoint(x: 1, y: 2)
        let result1 = line.project(point1)
        XCTAssertEqual(result1.point, CGPoint(x: 1.5, y: 1.5))
        XCTAssertEqual(result1.location.t, 0.5)
        XCTAssertEqual(result1.location.elementIndex, 0)
        XCTAssertTrue(line.pointIsWithinDistanceOfBoundary(point1, distance: 2))
        XCTAssertFalse(line.pointIsWithinDistanceOfBoundary(point1, distance: 0.5))

        let rectangle = Path(rect: CGRect(x: 1, y: 2, width: 8, height: 4))
        let component = rectangle.components.first!
        let point2 = CGPoint(x: 3, y: 5)
        let result2 = component.project(point2)
        XCTAssertEqual(result2.point, CGPoint(x: 3, y: 6))
        XCTAssertEqual(result2.location.t, 0.75)
        XCTAssertEqual(result2.location.elementIndex, 2)
        XCTAssertTrue(component.pointIsWithinDistanceOfBoundary(point2, distance: 10))
        XCTAssertTrue(component.pointIsWithinDistanceOfBoundary(point2, distance: 2))
        XCTAssertFalse(component.pointIsWithinDistanceOfBoundary(point2, distance: 0.5))
    }
}

#endif
