//
//  PathComponentTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 1/13/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import XCTest
@testable import BezierKit

class PathComponentTests: XCTestCase {
    
    let line1 = LineSegment(p0: CGPoint(x: 1.0, y: 2.0), p1: CGPoint(x: 5.0, y: 5.0))   // length = 5
    let line2 = LineSegment(p0: CGPoint(x: 5.0, y: 5.0), p1: CGPoint(x: 13.0, y: -1.0)) // length = 10
    
    func testLength() {
        let p = PathComponent(curves: [line1, line2])
        XCTAssertEqual(p.length, 15.0) // sum of two lengths
    }
    
    func testBoundingBox() {
        let p = PathComponent(curves: [line1, line2])
        XCTAssertEqual(p.boundingBox, BoundingBox(min: CGPoint(x: 1.0, y: -1.0), max: CGPoint(x: 13.0, y: 5.0))) // just the union of the two bounding boxes
    }
    
    func testOffset() {
        // construct a PathComponent from a split cubic
        let q = QuadraticBezierCurve(p0: CGPoint(x: 0.0, y: 0.0), p1: CGPoint(x: 2.0, y: 1.0), p2: CGPoint(x: 4.0, y: 0.0))
        let (ql, qr) = q.split(at: 0.5)
        let p = PathComponent(curves: [ql, qr])
        // test that offset gives us the same result as offsetting the split segments
        let pOffset = p.offset(distance: 1)
        
        for (c1, c2) in zip(pOffset.curves, ql.offset(distance: 1) + qr.offset(distance: 1)) {
            XCTAssert(c1 == c2)
        }
    }
    
    private let p1 = CGPoint(x: 0.0, y: 1.0)
    private let p2 = CGPoint(x: 2.0, y: 1.0)
    private let p3 = CGPoint(x: 2.5, y: 0.5)
    private let p4 = CGPoint(x: 2.0, y: 0.0)
    private let p5 = CGPoint(x: 0.0, y: 0.0)
    private let p6 = CGPoint(x: -0.5, y: 0.25)
    private let p7 = CGPoint(x: -0.5, y: 0.75)
    private let p8 = CGPoint(x: 0.0, y: 1.0)
    
    func testEquatable() {
    
        let l1 = LineSegment(p0: p1, p1: p2)
        let q1 = QuadraticBezierCurve(p0: p2, p1: p3, p2: p4)
        let l2 = LineSegment(p0: p4, p1: p5)
        let c1 = CubicBezierCurve(p0: p5, p1: p6, p2: p7, p3: p8)
        
        let pathComponent1 = PathComponent(curves: [l1, q1, l2, c1])
        let pathComponent2 = PathComponent(curves: [l1, q1, l2])
        let pathComponent3 = PathComponent(curves: [l1, q1, l2, c1])
        
        var altC1 = c1
        altC1.p2.x = -0.25
        let pathComponent4 = PathComponent(curves: [l1, q1, l2, altC1])

        XCTAssertNotEqual(pathComponent1, pathComponent2) // pathComponent2 is missing 4th path element, so not equal
        XCTAssertEqual(pathComponent1, pathComponent3)    // same path elements means equal
        XCTAssertNotEqual(pathComponent1, pathComponent4) // pathComponent4 has an element with a modified path
    }
    
    func testIsEqual() {
        
        let l1 = LineSegment(p0: p1, p1: p2)
        let q1 = QuadraticBezierCurve(p0: p2, p1: p3, p2: p4)
        let l2 = LineSegment(p0: p4, p1: p5)
        let c1 = CubicBezierCurve(p0: p5, p1: p6, p2: p7, p3: p8)
        
        let pathComponent1 = PathComponent(curves: [l1, q1, l2, c1])
        let pathComponent2 = PathComponent(curves: [l1, q1, l2, c1])
        var altC1 = c1
        altC1.p2.x = -0.25
        let pathComponent3 = PathComponent(curves: [l1, q1, l2, altC1])

        let string = "hello!" as NSString
        
        XCTAssertFalse(pathComponent1.isEqual(string))
        XCTAssertFalse(pathComponent1.isEqual(nil))
        XCTAssertTrue(pathComponent1.isEqual(pathComponent1))
        XCTAssertTrue(pathComponent1.isEqual(pathComponent2))
        XCTAssertFalse(pathComponent1.isEqual(pathComponent3))
    }
    
    func testNSCoder() {
        
        let l1 = LineSegment(p0: p1, p1: p2)
        let q1 = QuadraticBezierCurve(p0: p2, p1: p3, p2: p4)
        let l2 = LineSegment(p0: p4, p1: p5)
        let c1 = CubicBezierCurve(p0: p5, p1: p6, p2: p7, p3: p8)
        let pathComponent = PathComponent(curves: [l1, q1, l2, c1])

        let data = NSKeyedArchiver.archivedData(withRootObject: pathComponent)
        let decodedPathComponent = NSKeyedUnarchiver.unarchiveObject(with: data) as! PathComponent
        XCTAssertEqual(pathComponent, decodedPathComponent )
        
    }
    
}

