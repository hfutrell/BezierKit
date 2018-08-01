//
//  BoudningBoxTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 1/21/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import XCTest
@testable import BezierKit

class BoundingBoxTests: XCTestCase {
    
    let pointNan        = CGPoint(x: CGFloat.nan, y: CGFloat.nan)
    let zeroBox         = BoundingBox(p1: .zero, p2: .zero)
    let infiniteBox     = BoundingBox(p1: -.infinity, p2: .infinity)
    let sampleBox       = BoundingBox(p1: CGPoint(x: -1.0, y: -2.0), p2: CGPoint(x: 3.0, y: -1.0))
    
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
        let e = BoundingBox.empty
        XCTAssert(e.size == .zero)
        XCTAssertTrue(e == BoundingBox.empty)
        
        XCTAssertFalse(e.overlaps(e))
        XCTAssertFalse(e.overlaps(zeroBox))
        XCTAssertFalse(e.overlaps(sampleBox))
        XCTAssertFalse(e.overlaps(infiniteBox))
        XCTAssertFalse(e.overlaps(nanBox))

    }
        
}
