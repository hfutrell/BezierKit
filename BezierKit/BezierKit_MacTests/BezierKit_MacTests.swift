//
//  BezierKit_MacTests.swift
//  BezierKit_MacTests
//
//  Created by Holmes Futrell on 4/27/17.
//  Copyright © 2017 Holmes Futrell. All rights reserved.
//

import XCTest
import BezierKit

class BezierKit_MacTests: XCTestCase {

//    you can put Mac specific tests here (empty for now)
    
//    override func setUp() {
//        super.setUp()
//        // Put setup code here. This method is called before the invocation of each test method in the class.
//    }
//    
//    override func tearDown() {
//        // Put teardown code here. This method is called after the invocation of each test method in the class.
//        super.tearDown()
//    }
    
    func randomPoint() -> CGPoint {
        return CGPoint(x: CGFloat(drand48()), y: CGFloat(drand48()))
    }
    
    func randomCubicCurve() -> CubicBezierCurve {
        let p0 = self.randomPoint()
        let p1 = self.randomPoint()
        let p2 = self.randomPoint()
        let p3 = self.randomPoint()
        let curve = CubicBezierCurve(p0: p0, p1: p1, p2: p2, p3: p3)
        return curve
    }

    
    func testPerformanceIntersectsCurve() { // 0.112 s ... now 0.023 s
        
        var totalError: CGFloat = 0
        
        
        self.measure {
            // Put the code you want to measure the time of here.
            var totalIntersections = 0
            for _ in 0...1000 {
                let c1 = self.randomCubicCurve()
                let c2 = self.randomCubicCurve()
                
                let i = c1.intersects(curve: c2, threshold: 1.0e-4)
                i.forEach {
                    totalError += distance(c1.compute($0.t1), c2.compute($0.t2))
                }
                totalIntersections += i.count
            }
            NSLog("total intersections = %d", totalIntersections)
            NSLog("avg error = %.10e", totalError / CGFloat(totalIntersections) )

        }
        
    }

    
}
