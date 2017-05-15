//
//  LineSegmentTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 5/14/17.
//  Copyright © 2017 Holmes Futrell. All rights reserved.
//

import XCTest
import BezierKit

class LineSegmentTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testConstructorList() {
        let l = LineSegment(p0: BKPoint(x: 1.0, y: 1.0), p1: BKPoint(x: 3.0, y: 2.0))
        XCTAssertEqual(l.p0, BKPoint(x: 1.0, y: 1.0))
        XCTAssertEqual(l.p1, BKPoint(x: 3.0, y: 2.0))
        XCTAssertEqual(l.startingPoint, BKPoint(x: 1.0, y: 1.0))
        XCTAssertEqual(l.endingPoint, BKPoint(x: 3.0, y: 2.0))
    }
    
    func testConstructorArray() {
        let l = LineSegment(points: [BKPoint(x: 1.0, y: 1.0), BKPoint(x: 3.0, y: 2.0)])
        XCTAssertEqual(l.p0, BKPoint(x: 1.0, y: 1.0))
        XCTAssertEqual(l.p1, BKPoint(x: 3.0, y: 2.0))
        XCTAssertEqual(l.startingPoint, BKPoint(x: 1.0, y: 1.0))
        XCTAssertEqual(l.endingPoint, BKPoint(x: 3.0, y: 2.0))
    }
    
    func testBasicProperties() {
        let l = LineSegment(p0: BKPoint(x: 1.0, y: 1.0), p1: BKPoint(x: 2.0, y: 5.0))
        XCTAssert(l.simple)
        XCTAssertEqual(l.order, 1)
    }
    
    func testDerivative() {
        let l = LineSegment(p0: BKPoint(x: 1.0, y: 1.0), p1: BKPoint(x: 3.0, y: 2.0))
        XCTAssertEqual(l.derivative(0.23), BKPoint(x: 2.0, y: 1.0))
    }
    
    func testSplitFromTo() {
        let l = LineSegment(p0: BKPoint(x: 1.0, y: 1.0), p1: BKPoint(x: 4.0, y: 7.0))
        let t1: BKFloat = 1.0 / 3.0
        let t2: BKFloat = 2.0 / 3.0
        let s = l.split(from: t1, to: t2)
        XCTAssertEqual(s, LineSegment(p0: BKPoint(x: 2.0, y: 3.0), p1: BKPoint(x: 3.0, y: 5.0)))
    }
    
    func testSplitAt() {
        let l = LineSegment(p0: BKPoint(x: 1.0, y: 1.0), p1: BKPoint(x: 3.0, y: 5.0))
        let (left, right) = l.split(at: 0.5)
        XCTAssertEqual(left, LineSegment(p0: BKPoint(x: 1.0, y: 1.0), p1: BKPoint(x: 2.0, y: 3.0)))
        XCTAssertEqual(right, LineSegment(p0: BKPoint(x: 2.0, y: 3.0), p1: BKPoint(x: 3.0, y: 5.0)))
    }
    
    func testBoundingBox() {
        let l = LineSegment(p0: BKPoint(x: 3.0, y: 5.0), p1: BKPoint(x: 1.0, y: 3.0))
        XCTAssertEqual(l.boundingBox, BoundingBox.init(min: BKPoint(x: 1.0, y: 3.0), max: BKPoint(x: 3.0, y: 5.0)))
    }
    
    func testCompute() {
        let l = LineSegment(p0: BKPoint(x: 3.0, y: 5.0), p1: BKPoint(x: 1.0, y: 3.0))
        XCTAssertEqual(l.compute(0.0), BKPoint(x: 3.0, y: 5.0))
        XCTAssertEqual(l.compute(0.5), BKPoint(x: 2.0, y: 4.0))
        XCTAssertEqual(l.compute(1.0), BKPoint(x: 1.0, y: 3.0))
    }
    
    func testLength() {
        let l = LineSegment(p0: BKPoint(x: 1.0, y: 2.0), p1: BKPoint(x: 4.0, y: 6.0))
        XCTAssertEqual(l.length(), 5.0)
    }
    
    func testExtrema() {
        let l = LineSegment(p0: BKPoint(x: 1.0, y: 2.0), p1: BKPoint(x: 4.0, y: 6.0))
        let (xyz, values) = l.extrema()
        XCTAssert(xyz.count == 2) // one array for each dimension
        XCTAssertEqual(xyz[0].count, 2)
        XCTAssertEqual(xyz[1].count, 2)
        XCTAssertEqual(values.count, 2) // two extrema total
        XCTAssertEqual(values[0], 0.0)
        XCTAssertEqual(values[1], 1.0)
        XCTAssertEqual(xyz[0][0], 0.0)
        XCTAssertEqual(xyz[0][1], 1.0)
        XCTAssertEqual(xyz[1][0], 0.0)
        XCTAssertEqual(xyz[1][1], 1.0)
    }
    
    func testHull() {
        let l = LineSegment(p0: BKPoint(x: 1.0, y: 2.0), p1: BKPoint(x: 3.0, y: 4.0))
        let h = l.hull(0.5)
        XCTAssert(h.count == 3)
        XCTAssertEqual(h[0], BKPoint(x: 1.0, y: 2.0))
        XCTAssertEqual(h[1], BKPoint(x: 3.0, y: 4.0))
        XCTAssertEqual(h[2], BKPoint(x: 2.0, y: 3.0))
    }
    
    /*
 testGenerateLookupTable
 testNormal
 testReduce
 testScaleDistance
 testScaleDistanceFunc
 testOffsetDistance
 testOffsetTimeDistance
 testProject
 testIntersects
 testIntersectsLine
 testIntersectsCurve
 testOuline
 testOutline2
 testOutline3
 testOutlineShapes
 testOutlinesShapes2
 testArcs
    */

}
