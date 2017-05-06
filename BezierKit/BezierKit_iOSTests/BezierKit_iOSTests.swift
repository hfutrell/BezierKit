//
//  BezierKit_iOSTests.swift
//  BezierKit_iOSTests
//
//  Created by Holmes Futrell on 4/27/17.
//  Copyright © 2017 Holmes Futrell. All rights reserved.
//

import XCTest
import BezierKit

class BezierKit_iOSTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExtrema() {
        // should test extrema
        // then bounding box (uses extrema)
        // the intersect (uses bounding box)
    }
    
    func randomPoint() -> BKPoint {
        return BKPoint(x: BKFloat(drand48()), y: BKFloat(drand48()))
    }

    func randomCubicCurve() -> CubicBezierCurve {
        let p0 = self.randomPoint()
        let p1 = self.randomPoint()
        let p2 = self.randomPoint()
        let p3 = self.randomPoint()
        let curve = CubicBezierCurve(p0: p0, p1: p1, p2: p2, p3: p3)
        return curve
    }
    
    func testPerformanceReduce() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
            for _ in 0...1000 {
                let c = self.randomCubicCurve()
                let _: [Subcurve] = c.reduce()
            }
        }
    }
    
    func testPerformanceIntersectsCurve() { // 0.112 s ... now 0.021 s
        self.measure {
            // Put the code you want to measure the time of here.
            var totalIntersections = 0
            for _ in 0...1000 {
                let c1 = self.randomCubicCurve()
                let c2 = self.randomCubicCurve()

                let i = c1.intersects(curve: c2, curveIntersectionThreshold: 0.001)
                totalIntersections += i.count
            }
            NSLog("total intersections = %d", totalIntersections)
        }

    }
    
}
