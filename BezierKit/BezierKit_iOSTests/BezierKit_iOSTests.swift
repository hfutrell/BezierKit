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
    
    let threshold: BKFloat = 0.001
    
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
    
    func testCubicCubicIntersection() {
        let cubic1 = CubicBezierCurve(p0: BKPoint(x: 0.0, y: 0.0),
                                      p1: BKPoint(x: 1.0, y: 1.0),
                                      p2: BKPoint(x: 2.0, y: 1.0),
                                      p3: BKPoint(x: 3.0, y: 0.0))
        let cubic2 = CubicBezierCurve(p0: BKPoint(x: 0.0, y: 1.0),
                                      p1: BKPoint(x: 1.0, y: 0.0),
                                      p2: BKPoint(x: 2.0, y: 0.0),
                                      p3: BKPoint(x: 3.0, y: 1.0))
        let i = cubic1.intersects(curve: cubic2, curveIntersectionThreshold: threshold)
        XCTAssertEqual(i.count, 2, "wrong number of intersections!")
        XCTAssert(i[1].t1 > i[0].t1, "intersections improperly ordered!")
        for ii in i {
            XCTAssert( (cubic1.compute(ii.t1) - cubic2.compute(ii.t2)).length < threshold, "wrong or inaccurate intersection!" )
        }
    }
    
    func testCubicCubicIntersectionEndpoints() {
        // these two cubics intersect only at the endpoints
        let cubic1 = CubicBezierCurve(p0: BKPoint(x: 0.0, y: 0.0),
                                      p1: BKPoint(x: 1.0, y: 1.0),
                                      p2: BKPoint(x: 2.0, y: 1.0),
                                      p3: BKPoint(x: 3.0, y: 0.0))
        let cubic2 = CubicBezierCurve(p0: BKPoint(x: 3.0, y: 0.0),
                                      p1: BKPoint(x: 2.0, y: -1.0),
                                      p2: BKPoint(x: 1.0, y: -1.0),
                                      p3: BKPoint(x: 0.0, y: 0.0))
        let i = cubic1.intersects(curve: cubic2, curveIntersectionThreshold: threshold)
        XCTAssertEqual(i.count, 2, "start and end points should intersect!")
        XCTAssertEqual(i[0].t1, 0.0)
        XCTAssertEqual(i[0].t2, 1.0)
        XCTAssertEqual(i[1].t1, 1.0)
        XCTAssertEqual(i[1].t2, 0.0)
    }
    
    func testCubicSelfIntersection() {
        let curve = CubicBezierCurve(p0: BKPoint(x: 0.0, y: 0.0),
                                     p1: BKPoint(x: 2.0, y: 1.0),
                                     p2: BKPoint(x: -1.0, y: 1.0),
                                     p3: BKPoint(x: 1.0, y: 0.0))
        let i = curve.intersects(curveIntersectionThreshold: threshold)
        XCTAssertEqual(i.count, 1, "wrong number of intersections!")
        XCTAssert( (curve.compute(i[0].t1) - curve.compute(i[0].t2)).length < threshold, "wrong or inaccurate intersection!" )
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
    
    func testPerformanceIntersectsCurve() { // 0.112 s ... now 0.023 s
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
