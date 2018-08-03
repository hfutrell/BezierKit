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
    
    func testDistanceFromPoint() {
        let box = BoundingBox(p1: CGPoint(x: 2.0, y: 3.0), p2: CGPoint(x: 3.0, y: 5.0))
        XCTAssertEqual(box.distance(from: CGPoint(x: 2.0, y: 4.0)), 0.0)    // on the boundary
        XCTAssertEqual(box.distance(from: CGPoint(x: 2.5, y: 3.2)), 0.0)    // fully inside
        XCTAssertEqual(box.distance(from: CGPoint(x: 1.0, y: 4.0)), 1.0)    // outside (straight horizontally)
        XCTAssertEqual(box.distance(from: CGPoint(x: 3.0, y: 7.0)), 2.0)    // outside (straight vertically)
        XCTAssertEqual(box.distance(from: CGPoint(x: -1.0, y: -1.0)), 5.0)  // outside (nearest bottom left corner)
    }
}
