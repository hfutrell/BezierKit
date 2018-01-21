//
//  BoudningBoxTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 1/21/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import XCTest
import BezierKit

class BoudningBoxTests: XCTestCase {
    
    let pointNan        = BKPoint(x: BKFloat.nan, y: BKFloat.nan)
    let zeroBox         = BoundingBox(p1: BKPointZero, p2: BKPointZero)
    let infiniteBox     = BoundingBox(p1: -BKPointInfinity, p2: BKPointInfinity)
    let sampleBox       = BoundingBox(p1: BKPoint(x: -1.0, y: -2.0), p2: BKPoint(x: 3.0, y: -1.0))
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testEmpty() {
        let nanBox = BoundingBox(p1: pointNan, p2: pointNan)
        let e = BoundingBox.empty()
        XCTAssert(e.size == BKPointZero)
        XCTAssertTrue(e == BoundingBox.empty())
        
        XCTAssertFalse(e.overlaps(e))
        XCTAssertFalse(e.overlaps(zeroBox))
        XCTAssertFalse(e.overlaps(sampleBox))
        XCTAssertFalse(e.overlaps(infiniteBox))
        XCTAssertFalse(e.overlaps(nanBox))

    }
        
}
