//
//  UtilsTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 5/12/19.
//  Copyright © 2019 Holmes Futrell. All rights reserved.
//

import XCTest
@testable import BezierKit

class UtilsTests: XCTestCase {

    func testClamp() {
        XCTAssertEqual(1.0, Utils.clamp(1.0, -1.0, 1.0))
        XCTAssertEqual(0.0, Utils.clamp(0.0, -1.0, 1.0))
        XCTAssertEqual(-1.0, Utils.clamp(-1.0, -1.0, 1.0))
        XCTAssertEqual(1.0, Utils.clamp(2.0, -1.0, 1.0))
        XCTAssertEqual(-1.0, Utils.clamp(-2.0, -1.0, 1.0))
        XCTAssertEqual(-1.0, Utils.clamp(-CGFloat.infinity, -1.0, 1.0))
        XCTAssertEqual(1.0, Utils.clamp(+CGFloat.infinity, -1.0, 1.0))
        XCTAssertEqual(-20.0, Utils.clamp(-20.0, -CGFloat.infinity, 0.0))
        XCTAssertEqual(20.0, Utils.clamp(20.0, 0.0, CGFloat.infinity))
        XCTAssertTrue(Utils.clamp(CGFloat.nan, -1.0, 1.0).isNaN)
    }

}
