//
//  UtilsTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 5/12/19.
//  Copyright © 2019 Holmes Futrell. All rights reserved.
//

import XCTest
@testable import BezierKit

class UtilsTests: XCTestCase {

    func testClamp() {
        XCTAssertEqual(1.0, Utils.clamp(1.0, -1.0, 1.0))
        XCTAssertEqual(0.0, Utils.clamp(0.0, -1.0, 1.0))
        XCTAssertEqual(-1.0, Utils.clamp(-1.0, -1.0, 1.0))
        XCTAssertEqual(1.0, Utils.clamp(2.0, -1.0, 1.0))
        XCTAssertEqual(-1.0, Utils.clamp(-2.0, -1.0, 1.0))
        XCTAssertEqual(-1.0, Utils.clamp(-CGFloat.infinity, -1.0, 1.0))
        XCTAssertEqual(1.0, Utils.clamp(+CGFloat.infinity, -1.0, 1.0))
        XCTAssertEqual(-20.0, Utils.clamp(-20.0, -CGFloat.infinity, 0.0))
        XCTAssertEqual(20.0, Utils.clamp(20.0, 0.0, CGFloat.infinity))
        XCTAssertTrue(Utils.clamp(CGFloat.nan, -1.0, 1.0).isNaN)
    }

    func testRootsRealWorldIssue() {
        let points: [CGPoint] = [
            CGPoint(x:523.4257521858988, y: 691.8949684622992),
            CGPoint(x:523.1393916834338, y: 691.8714265856051),
            CGPoint(x:522.8595588275791, y: 691.7501129962762),
            CGPoint(x:522.6404735257349, y: 691.531027694432)
        ]
        let curve = CubicBezierCurve(points: points)
        let y: CGFloat = 691.87778055040201
        let line = LineSegment(p0: CGPoint(x: 0, y: y), p1: CGPoint(x: 1, y: y))
        let r = Utils.roots(points: points, line: line)
        let filtered = r.filter { $0 >= 0 && $0 <= 1 }
        XCTAssertEqual(curve.compute(CGFloat(filtered[0])).y, y, accuracy: CGFloat(1.0e-5))
    }

}
