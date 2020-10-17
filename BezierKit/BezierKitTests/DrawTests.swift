//
//  DrawTest.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/6/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import XCTest
@testable import BezierKit

#if canImport(CoreGraphics)

class DrawTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testHSLToRGB() {

        let epsilon: CGFloat = 1.0e-6

        var (r, g, b): (CGFloat, CGFloat, CGFloat)

        (r, g, b) = Draw.HSLToRGB(h: 0.0, s: 1.0, l: 0.5) // pure red
        XCTAssertEqual(r, 1.0, accuracy: epsilon)
        XCTAssertEqual(g, 0.0, accuracy: epsilon)
        XCTAssertEqual(b, 0.0, accuracy: epsilon)

        (r, g, b) = Draw.HSLToRGB(h: 240.0 / 360.0, s: 1.0, l: 0.25) // dark blue
        XCTAssertEqual(r, 0.0, accuracy: epsilon)
        XCTAssertEqual(g, 0.0, accuracy: epsilon)
        XCTAssertEqual(b, 0.5, accuracy: epsilon)

        (r, g, b) = Draw.HSLToRGB(h: 300.0 / 360.0, s: 1.0, l: 0.5) // magenta
        XCTAssertEqual(r, 1.0, accuracy: epsilon)
        XCTAssertEqual(g, 0.0, accuracy: epsilon)
        XCTAssertEqual(b, 1.0, accuracy: epsilon)

        (r, g, b) = Draw.HSLToRGB(h: 0.5, s: 0.0, l: 0.75) // light gray
        XCTAssertEqual(r, 0.75, accuracy: epsilon)
        XCTAssertEqual(g, 0.75, accuracy: epsilon)
        XCTAssertEqual(b, 0.75, accuracy: epsilon)
    }
}

#endif
