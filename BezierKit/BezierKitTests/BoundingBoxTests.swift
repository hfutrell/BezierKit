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
    
    let pointNan        = CGPoint(x: CGFloat.nan, y: CGFloat.nan)
    let zeroBox         = CGRect(p1: .zero, p2: .zero)
    let infiniteBox     = CGRect(p1: -.infinity, p2: .infinity)
    let sampleBox       = CGRect(p1: CGPoint(x: -1.0, y: -2.0), p2: CGPoint(x: 3.0, y: -1.0))
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testEmpty() {
        let nanBox = CGRect(p1: pointNan, p2: pointNan)
        let e = CGRect.null
        XCTAssert(e.size == .zero)
        XCTAssertTrue(e == .null)
        
        XCTAssertFalse(e.overlaps(e))
        XCTAssertFalse(e.overlaps(zeroBox))
        XCTAssertFalse(e.overlaps(sampleBox))
        XCTAssertFalse(e.overlaps(infiniteBox))
        XCTAssertFalse(e.overlaps(nanBox))
    }
}
