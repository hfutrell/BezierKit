//
//  BezierKitTests.swift
//  BezierKitTests
//
//  Created by Holmes Futrell on 10/28/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import XCTest
@testable import BezierKit

class BezierKitTests: XCTestCase {
    
    static internal func intersections(_ intersections: [Intersection], betweenCurve c1: BezierCurve, andOtherCurve c2: BezierCurve, areWithinTolerance epsilon: BKFloat) -> Bool {
        for i in intersections {
            let p1 = c1.compute(i.t1)
            let p2 = c2.compute(i.t2)
            if (p1 - p2).length > epsilon {
                return false
            }
        }
        return true
    }
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
//    func testExample() {
//        // This is an example of a functional test case.
//        // Use XCTAssert and related functions to verify your tests produce the correct results.
//    }
//    
//    func testPerformanceExample() {
//        // This is an example of a performance test case.
//        self.measure {
//            // Put the code you want to measure the time of here.
//        }
//    }
    
}
