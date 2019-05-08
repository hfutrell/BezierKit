//
//  CGPointTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 1/4/19.
//  Copyright © 2019 Holmes Futrell. All rights reserved.
//

import XCTest
@testable import BezierKit

class CGPointTests: XCTestCase {

    func testOperators() {
        let p1 = CGPoint(x: 1.25, y: 2.0)
        let p2 = CGPoint(x: -3.0, y: 4.5)
        XCTAssertEqual(p1 + p2, CGPoint(x: -1.75, y: 6.5))
        XCTAssertEqual(p1 - p2, CGPoint(x: 4.25, y: -2.5))
        XCTAssertEqual(2.0 * p1, CGPoint(x: 2.5, y: 4.0))
        XCTAssertEqual(p2 / 0.5, CGPoint(x: -6.0, y: 9.0))
        XCTAssertEqual(-p2, CGPoint(x: 3.0, y: -4.5))
        XCTAssertEqual(p1[0], 1.25)
        XCTAssertEqual(p1[1], 2.0)

        var p3 = CGPoint(x: 5.0, y: 3.0)
        p3 += CGPoint(x: 1.0, y: -2.0)
        XCTAssertEqual(p3, CGPoint(x: 6.0, y: 1.0))
        
        var p4 = CGPoint(x: 2.0, y: 9.0)
        p4 -= CGPoint(x: 2.0, y: 8.0)
        XCTAssertEqual(p4, CGPoint(x: 0.0, y: 1.0))

        var p5 = CGPoint(x: 9.25, y: 4.25)
        p5[0] = 1.25
        p5[1] = 6.25
        XCTAssertEqual(p5[0], 1.25)
        XCTAssertEqual(p5[1], 6.25)
    }
    
    func testFunctions() {
        let a = CGPoint(x: 3, y: 4)
        let b = CGPoint(x: -1, y: 5)
        XCTAssertEqual(a.dot(b), 17)
        XCTAssertEqual(a.cross(b), 19)
        XCTAssertEqual(a.length, 5)
        XCTAssertEqual(a.lengthSquared, 25)
        XCTAssertEqual(a.normalize(), CGPoint(x: 3.0 / 5.0, y: 4.0 / 5.0))
        XCTAssertEqual(distance(a, b), sqrt(17.0))
        XCTAssertEqual(distanceSquared(a, b), 17.0)
        XCTAssertEqual(a.perpendicular, CGPoint(x: -4, y: 3))
    }
}
