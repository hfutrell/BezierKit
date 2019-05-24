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

        XCTAssertFalse(infiniteBox.isEmpty)
        XCTAssertFalse(zeroBox.isEmpty)
        XCTAssertFalse(sampleBox.isEmpty)
        XCTAssertTrue(BoundingBox.empty.isEmpty)
        XCTAssertTrue(BoundingBox(min: CGPoint(x: 5, y: 3), max: CGPoint(x: 4, y: 4)).isEmpty)
    }

    func testLowerAndUpperBounds() {
        let box = BoundingBox(p1: CGPoint(x: 2.0, y: 3.0), p2: CGPoint(x: 3.0, y: 5.0))

        let p1 = CGPoint(x: 2.0, y: 4.0)
        let p2 = CGPoint(x: 2.5, y: 3.5)
        let p3 = CGPoint(x: 1.0, y: 4.0)
        let p4 = CGPoint(x: 3.0, y: 7.0)
        let p5 = CGPoint(x: -1.0, y: -1.0)

        XCTAssertEqual(box.lowerBoundOfDistance(to: p1), 0.0)    // on the boundary
        XCTAssertEqual(box.lowerBoundOfDistance(to: p2), 0.0)    // fully inside
        XCTAssertEqual(box.lowerBoundOfDistance(to: p3), 1.0)    // outside (straight horizontally)
        XCTAssertEqual(box.lowerBoundOfDistance(to: p4), 2.0)    // outside (straight vertically)
        XCTAssertEqual(box.lowerBoundOfDistance(to: p5), 5.0)    // outside (nearest bottom left corner)

        XCTAssertEqual(box.upperBoundOfDistance(to: p1), sqrt(2.0))
        XCTAssertEqual(box.upperBoundOfDistance(to: p2), sqrt(2.5))
        XCTAssertEqual(box.upperBoundOfDistance(to: p3), sqrt(5))
        XCTAssertEqual(box.upperBoundOfDistance(to: p4), sqrt(17.0))
        XCTAssertEqual(box.upperBoundOfDistance(to: p5), sqrt(52.0))
    }

    func testArea() {
        let box = BoundingBox(p1: CGPoint(x: 2.0, y: 3.0), p2: CGPoint(x: 3.0, y: 5.0))
        XCTAssertEqual(box.area, 2.0)
        let emptyBox = BoundingBox.empty
        XCTAssertEqual(emptyBox.area, 0.0)
    }

    func testOverlaps() {
        let box1 = BoundingBox(p1: CGPoint(x: 2.0, y: 3.0), p2: CGPoint(x: 3.0, y: 5.0))
        let box2 = BoundingBox(p1: CGPoint(x: 2.5, y: 6.0), p2: CGPoint(x: 3.0, y: 8.0))
        let box3 = BoundingBox(p1: CGPoint(x: 2.5, y: 4.0), p2: CGPoint(x: 3.0, y: 8.0))
        XCTAssertFalse(box1.overlaps(box2))
        XCTAssertTrue(box1.overlaps(box3))
        XCTAssertFalse(box1.overlaps(BoundingBox.empty))
    }

    func testUnionEmpty1() {
        var empty1 = BoundingBox.empty
        let empty2 = BoundingBox.empty
        XCTAssertEqual(empty1.union(empty2), BoundingBox.empty)
    }

    func testUnionEmpty2() {
        var empty = BoundingBox.empty
        let box = BoundingBox(p1: CGPoint(x: 2.0, y: 3.0), p2: CGPoint(x: 3.0, y: 5.0))
        XCTAssertEqual(empty.union(box), box)
    }

    func testUnion() {
        var box1 = BoundingBox(p1: CGPoint(x: 2.0, y: 3.0), p2: CGPoint(x: 3.0, y: 5.0))
        let box2 = BoundingBox(p1: CGPoint(x: 2.5, y: 6.0), p2: CGPoint(x: 3.0, y: 8.0))
        XCTAssertEqual(box1.union(box2), BoundingBox(p1: CGPoint(x: 2.0, y: 3.0), p2: CGPoint(x: 3.0, y: 8.0)))
    }

    func testCGRect() {
        // test a standard box
        let box1 = BoundingBox(p1: CGPoint(x: 2.0, y: 3.0), p2: CGPoint(x: 3.0, y: 5.0))
        XCTAssertEqual(box1.cgRect, CGRect(origin: CGPoint(x: 2.0, y: 3.0), size: CGSize(width: 1.0, height: 2.0)))
        // test the empty box
        XCTAssertEqual(BoundingBox.empty.cgRect, CGRect.null)
    }

    func testInitFirstSecond() {
        let box1 = BoundingBox(p1: CGPoint(x: 2.0, y: 3.0), p2: CGPoint(x: 3.0, y: 5.0))
        let box2 = BoundingBox(p1: CGPoint(x: 1.0, y: 1.0), p2: CGPoint(x: 2.0, y: 2.0))
        let result = BoundingBox(first: box1, second: box2)
        XCTAssertEqual(result, BoundingBox(p1: CGPoint(x: 1.0, y: 1.0), p2: CGPoint(x: 3.0, y: 5.0)))
    }

    func testIntersection() {
        let box1 = BoundingBox(p1: CGPoint(x: 0, y: 0), p2: CGPoint(x: 3, y: 2))
        let box2 = BoundingBox(p1: CGPoint(x: 2, y: 1), p2: CGPoint(x: 4, y: 5))      // overlaps box1
        let box3 = BoundingBox(p1: CGPoint(x: 2, y: 4), p2: CGPoint(x: 4, y: 5))      // does not overlap box1
        let box4 = BoundingBox(p1: CGPoint(x: 3, y: 0), p2: CGPoint(x: 5, y: 2))      // overlaps box1 exactly on x edge
        let box5 = BoundingBox(p1: CGPoint(x: 0, y: 2), p2: CGPoint(x: 3, y: 4))      // overlaps box1 exactly on y edge
        let box6 = BoundingBox(p1: CGPoint(x: 0, y: 0), p2: CGPoint(x: -5, y: -5))    // overlaps box1 only at (0,0)
        let expectedBox = BoundingBox(p1: CGPoint(x: 2, y: 1), p2: CGPoint(x: 3, y: 2))
        XCTAssertEqual(box1.intersection(box2), expectedBox)
        XCTAssertEqual(box2.intersection(box1), expectedBox)
        XCTAssertEqual(box1.intersection(box3), BoundingBox.empty)
        XCTAssertEqual(box1.intersection(BoundingBox.empty), BoundingBox.empty)
        XCTAssertEqual(BoundingBox.empty.intersection(box1), BoundingBox.empty)
        XCTAssertEqual(BoundingBox.empty.intersection(BoundingBox.empty), BoundingBox.empty)
        XCTAssertEqual(box1.intersection(box4), BoundingBox(p1: CGPoint(x: 3, y: 0), p2: CGPoint(x: 3, y: 2)))
        XCTAssertEqual(box1.intersection(box5), BoundingBox(p1: CGPoint(x: 0, y: 2), p2: CGPoint(x: 3, y: 2)))
        XCTAssertEqual(box1.intersection(box6), BoundingBox(p1: CGPoint.zero, p2: CGPoint.zero))
    }
}
