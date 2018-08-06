//
//  DrawTest.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/6/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import XCTest
@testable import BezierKit

class DrawTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testHSLToRGB() {
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        
        Draw.HSLToRGB(h: 0.0, s: 1.0, l: 0.5, outR: &r, outG: &g, outB: &b) // pure red
        XCTAssertEqual([r, g, b], [1.0, 0.0, 0.0])
        
        Draw.HSLToRGB(h: 240.0 / 360.0, s: 1.0, l: 0.25, outR: &r, outG: &g, outB: &b) // dark blue
        XCTAssertEqual([r, g, b], [0.0, 0.0, CGFloat(0.5)])

        Draw.HSLToRGB(h: 300.0 / 360.0, s: 1.0, l: 0.5, outR: &r, outG: &g, outB: &b) // magenta
        XCTAssertEqual(r, 1.0, accuracy: 1.0e-6)
        XCTAssertEqual(g, 0.0, accuracy: 1.0e-6)
        XCTAssertEqual(b, 1.0, accuracy: 1.0e-6)
        
        Draw.HSLToRGB(h: 0.5, s: 0.0, l: 0.75, outR: &r, outG: &g, outB: &b) // light gray
        XCTAssertEqual([r, g, b], [0.75, 0.75, 0.75])
    }
}
