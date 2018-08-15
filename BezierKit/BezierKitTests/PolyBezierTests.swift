//
//  PolyBezierTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 1/13/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import XCTest
@testable import BezierKit

class PolyBezierTests: XCTestCase {
    
    let line1 = LineSegment(p0: CGPoint(x: 1.0, y: 2.0), p1: CGPoint(x: 5.0, y: 5.0))   // length = 5
    let line2 = LineSegment(p0: CGPoint(x: 5.0, y: 5.0), p1: CGPoint(x: 13.0, y: -1.0)) // length = 10
    
    func testLength() {
        let p = PolyBezier(curves: [line1, line2])
        XCTAssertEqual(p.length, 15.0) // sum of two lengths
    }
    
    func testBoundingBox() {
        let p = PolyBezier(curves: [line1, line2])
        XCTAssertEqual(p.boundingBox, BoundingBox(min: CGPoint(x: 1.0, y: -1.0), max: CGPoint(x: 13.0, y: 5.0))) // just the union of the two bounding boxes
    }
    
    func testOffset() {
        // construct a PolyBezier from a split cubic
        let q = QuadraticBezierCurve(p0: CGPoint(x: 0.0, y: 0.0), p1: CGPoint(x: 2.0, y: 1.0), p2: CGPoint(x: 4.0, y: 0.0))
        let (ql, qr) = q.split(at: 0.5)
        let p = PolyBezier(curves: [ql, qr])
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
        
        let polyBezier1 = PolyBezier(curves: [l1, q1, l2, c1])
        let polyBezier2 = PolyBezier(curves: [l1, q1, l2])
        let polyBezier3 = PolyBezier(curves: [l1, q1, l2, c1])
        
        var altC1 = c1
        altC1.p2.x = -0.25
        let polyBezier4 = PolyBezier(curves: [l1, q1, l2, altC1])

        XCTAssertNotEqual(polyBezier1, polyBezier2) // polyBezier2 is missing 4th path element, so not equal
        XCTAssertEqual(polyBezier1, polyBezier3)    // same path elements means equal
        XCTAssertNotEqual(polyBezier1, polyBezier4) // polyBezier4 has an element with a modified path
    }
    
    func testIsEqual() {
        
        let l1 = LineSegment(p0: p1, p1: p2)
        let q1 = QuadraticBezierCurve(p0: p2, p1: p3, p2: p4)
        let l2 = LineSegment(p0: p4, p1: p5)
        let c1 = CubicBezierCurve(p0: p5, p1: p6, p2: p7, p3: p8)
        
        let polyBezier1 = PolyBezier(curves: [l1, q1, l2, c1])
        let polyBezier2 = PolyBezier(curves: [l1, q1, l2, c1])
        var altC1 = c1
        altC1.p2.x = -0.25
        let polyBezier3 = PolyBezier(curves: [l1, q1, l2, altC1])

        let string = "hello!" as NSString
        
        XCTAssertFalse(polyBezier1.isEqual(string))
        XCTAssertFalse(polyBezier1.isEqual(nil))
        XCTAssertTrue(polyBezier1.isEqual(polyBezier1))
        XCTAssertTrue(polyBezier1.isEqual(polyBezier2))
        XCTAssertFalse(polyBezier1.isEqual(polyBezier3))
    }
    
    func testNSCoder() {
        
        let l1 = LineSegment(p0: p1, p1: p2)
        let q1 = QuadraticBezierCurve(p0: p2, p1: p3, p2: p4)
        let l2 = LineSegment(p0: p4, p1: p5)
        let c1 = CubicBezierCurve(p0: p5, p1: p6, p2: p7, p3: p8)
        let polyBezier = PolyBezier(curves: [l1, q1, l2, c1])

        let data = NSKeyedArchiver.archivedData(withRootObject: polyBezier)
        let decodedPolyBezier = NSKeyedUnarchiver.unarchiveObject(with: data) as! PolyBezier
        XCTAssertEqual(polyBezier, decodedPolyBezier )
        
    }
    
}

