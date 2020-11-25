//
//  PathComponent+ProjectionTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 11/23/20.
//  Copyright © 2020 Holmes Futrell. All rights reserved.
//

@testable import BezierKit
import Foundation
import XCTest

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

    func parametricPath(numCurves: Int,
                        theta: (_: CGFloat) -> CGFloat,
                        dthetadt: (_: CGFloat) -> CGFloat,
                        r: (_: CGFloat) -> CGFloat,
                        drdt: (_: CGFloat) -> CGFloat) -> Path {
        func p(_ t: CGFloat) -> CGPoint {
            return CGPoint(x: r(t) * cos(theta(t)), y: r(t) * sin(theta(t)))
        }
        func d(_ t: CGFloat) -> CGPoint {
            return CGPoint(x: drdt(t) * cos(theta(t)) - r(t) * sin(theta(t)) * dthetadt(t),
                           y: drdt(t) * sin(theta(t)) + r(t) * cos(theta(t)) * dthetadt(t))
        }
        let cgPath = CGMutablePath()
        var previousT: CGFloat = 0.0
        var previousPoint = p(previousT)
        cgPath.move(to: previousPoint)
        let delta = 1.0 / CGFloat(numCurves)
        for i in 1...numCurves {
            let nextT = CGFloat(i) / CGFloat(numCurves)
            let nextPoint = p(nextT)
            cgPath.addCurve(to: nextPoint, control1: previousPoint + delta / 3.0 * d(previousT), control2: nextPoint - delta / 3.0 * d(nextT))
            previousPoint = nextPoint
            previousT = nextT
        }
        return Path(cgPath: cgPath)
    }

    func testProjectPerformance() {
        let k: CGFloat = 2.0 * CGFloat.pi * 10
        let maxRadius: CGFloat = 100.0
        func theta(_ t: CGFloat) -> CGFloat {
            return k * t
        }
        func r(_ t: CGFloat) -> CGFloat {
            return t * maxRadius
        }
        func drdt(_ t: CGFloat) -> CGFloat {
            return maxRadius
        }
        func dthetadt(_ t: CGFloat) -> CGFloat {
            return k
        }
        let spiral = parametricPath(numCurves: 100, theta: theta, dthetadt: dthetadt, r: r, drdt: drdt)
        // about 0.31s in -Onone, 0.033s in -Ospeed
        self.measure {
            var pointsTested = 0
            var totalDistance: CGFloat = 0.0
            for x in stride(from: -maxRadius, through: maxRadius, by: 10) {
                for y in stride(from: -maxRadius, through: maxRadius, by: 10) {
                   // print("(\(x), \(y))")
                    let point = CGPoint(x: x, y: y)
                    let projection = spiral.project(point)!.point
                    pointsTested += 1
                    totalDistance += distance(projection, point)
                }
            }
            // print("tested \(pointsTested) points, average distance from spiral = \(totalDistance / CGFloat(pointsTested))")
        }
    }
}
