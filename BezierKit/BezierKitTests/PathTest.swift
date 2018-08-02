//
//  PathTest.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/1/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import XCTest
import BezierKit

class PathTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testIntersects() {

        // TODO: improved unit tests ... currently this test is very lax and allows duplicated intersections
        let circleCGPath = CGMutablePath()
        circleCGPath.addEllipse(in: CGRect(origin: CGPoint(x: 2.0, y: 3.0), size: CGSize(width: 2.0, height: 2.0)))
        
        let circlePath = Path(circleCGPath) // a circle centered at (3, 4) with radius 2
        
        let rectangleCGPath = CGMutablePath()
        rectangleCGPath.addRect(CGRect(origin: CGPoint(x: 3.0, y: 4.0), size: CGSize(width: 2.0, height: 2.0)))
        
        let rectanglePath = Path(rectangleCGPath)
        
        let intersections = rectanglePath.intersects(path: circlePath)
        
        XCTAssert(intersections.contains(CGPoint(x: 4.0, y: 4.0)))
        XCTAssert(intersections.contains(CGPoint(x: 3.0, y: 5.0)))
    }
    
}
