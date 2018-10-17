//
//  ConvexHullTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 10/16/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import XCTest
@testable import BezierKit

class ConvexHullTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testConvexHullEmpty() {
        XCTAssertEqual(computeConvexHull(from: []), [])
    }
    
    func testConvexHullOnePoint() {
        let point = CGPoint(x: 1.0, y: 2.0)
        XCTAssertEqual(computeConvexHull(from: [point]), [point])
    }

    func testConvexHullTwoPoints() {
        let point1 = CGPoint(x: 4.0, y: 2.0)
        let point2 = CGPoint(x: 1.0, y: 2.0)
        XCTAssertEqual(computeConvexHull(from: [point1, point1]), [point1])
        XCTAssertEqual(computeConvexHull(from: [point1, point2]), [point2, point1])
    }
    
    func testConvexHullThreePoints() {
        let point1 = CGPoint(x: 1.0, y: 0.0)
        let point2 = CGPoint(x: 5.0, y: 1.0)
        let point3 = CGPoint(x: 2.0, y: 4.0)
        XCTAssertEqual(computeConvexHull(from: [point3, point2, point1]), [point1, point2, point3])
    }
    
    func testConvexHullThreePointsRealWorldIssue() {
        // this data has caused issues for implementations in practice
        let point1 = CGPoint(x: 0, y: -0.00000027973388228019758)
        let point2 = CGPoint(x: 0.5, y: -0.000000032543709949095501)
        let point3 = CGPoint(x: 1, y: 0.00000021464646238200658)
        XCTAssertEqual(computeConvexHull(from: [point1, point2, point3]), [point1, point3])
    }
    
    func testConvexHullThreePointsColinear() {
        // special edge case
        let point1 = CGPoint(x: 1.0, y: 0.0)
        let point2 = CGPoint(x: 2.0, y: 1.0)
        let point3 = CGPoint(x: 3.0, y: 2.0)
       // XCTAssertEqual(computeConvexHull(from: [point3, point2, point1]), [point1, point3])
        XCTAssertEqual(computeConvexHull(from: [point1, point2, point3]), [point1, point3])
    }
    
    func testConvexHullFourPoints() {
        let point1 = CGPoint(x: 1.0, y: 0.0)
        let point2 = CGPoint(x: 6.0, y: -1.0)
        let point3 = CGPoint(x: 5.0, y: 1.0)
        let point4 = CGPoint(x: 2.0, y: 4.0)
        XCTAssertEqual(computeConvexHull(from: [point3, point4, point2, point1]), [point1, point2, point3, point4])
        XCTAssertEqual(computeConvexHull(from: [point3, CGPoint(x: 2.0, y: 0.0), point2, point1]), [point1, point2, point3])
    }
    
    func testConvexHullFourPointsRealWorldIssue() {
        // this data has caused issues for implementations in practice
        let point1 = CGPoint(x: 0, y: 0.00000249996989509782)
        let point2 = CGPoint(x: 0.33333333333333331, y: 0.0000014691098613184295)
        let point3 = CGPoint(x: 0.66666666666666663, y: 0.00000043824982753903896)
        let point4 = CGPoint(x: 1, y: -0.00000059261020624035154)
        XCTAssertEqual(computeConvexHull(from: [point1, point2, point3, point4]), [point1, point4])
    }

}
