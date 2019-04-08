//
//  ArcApproximateableTests.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/5/17.
//  Copyright © 2017 Holmes Futrell. All rights reserved.
//

import XCTest
import BezierKit

class ArcApproximateableTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func isGoodApproximation(arcs: [Arc], curve: BezierCurve, accuracy: CGFloat) -> Bool {
        // we need at least one arc
        if arcs.count == 0 {
            return false
        }
        // verify that the arc intervals correspond to the full curve
        if arcs.first!.interval.start != 0.0 {
            return false // first interval must start at start of curve
        }
        var lastEnd = arcs.first!.interval.end
        for a: Arc in arcs[1..<arcs.count] {
            if a.interval.start != lastEnd {
                return false // interval doesn't start where last one ended
            }
            if a.interval.end <= a.interval.start {
                return false // zero, or negative length interval
            }
            lastEnd = a.interval.end
        }
        if arcs.last!.interval.end != 1.0 {
            return false // last interval must complete the approximated curve
        }
        // for each arc verify that the discrepency between it an the subcurve it represents falls within the error threshold
        for a: Arc in arcs {
            let subCurve = curve.split(from: a.interval.start, to: a.interval.end)
            // these t1, t2 values and error function come from the way evaluate error internally in ArcApproximateable.swift
            let t1: CGFloat = 0.25
            let t2: CGFloat = 0.75
            let d1: CGFloat = distance(a.origin, subCurve.compute(t1))
            let d2: CGFloat = distance(a.origin, subCurve.compute(t2))
            let error = abs(a.radius - d1) + abs(a.radius - d2)
            if error > accuracy {
                return false
            }
        }
        return true
    }
    
    func testArc() {
        // test the constructor
        let arc = Arc(origin: CGPoint(x: 1.0, y: 1.0), radius: 1.5, startAngle: 0.0, endAngle: CGFloat.pi / 2.0)
        XCTAssertEqual(arc.origin, CGPoint(x: 1.0, y: 1.0))
        XCTAssertEqual(arc.radius, 1.5)
        XCTAssertEqual(arc.startAngle, 0.0)
        XCTAssertEqual(arc.endAngle, CGFloat.pi / 2.0)
        XCTAssertEqual(arc.interval, Interval(start: 0.0, end: 1.0))
        
        // test equality
        let arc2 = Arc(origin: CGPoint(x: 1.0, y: 1.0), radius: 1.5, startAngle: 0.0, endAngle: CGFloat.pi / 2.0, interval: Interval(start: 0.0, end: 1.0))
        XCTAssertEqual(arc, arc2)
        var arc3 = arc
        arc3.origin = arc3.origin + CGPoint(x: 1.0, y: 1.0)
        XCTAssertNotEqual(arc, arc3)
        var arc4 = arc
        arc4.radius = 2
        XCTAssertNotEqual(arc, arc4)
        var arc5 = arc
        arc5.startAngle = 0.2
        XCTAssertNotEqual(arc, arc5)
        var arc6 = arc
        arc6.endAngle = 0.8
        XCTAssertNotEqual(arc, arc6)
        var arc7 = arc
        arc7.interval = Interval(start: 0.1, end: 1.0)
        XCTAssertNotEqual(arc, arc7)

        // test compute
        let epsilon: CGFloat = 1.0e-6
        XCTAssert(distance(arc.compute(0.0), CGPoint(x: 2.5, y: 1.0)) < epsilon)
        XCTAssert(distance(arc.compute(0.5), CGPoint(x: 1.0, y: 1.0) + 0.75 * sqrt(2) * CGPoint(x: 1.0, y: 1.0)) < epsilon)
        XCTAssert(distance(arc.compute(1.0), CGPoint(x: 1.0, y: 2.5)) < epsilon)
    }
    
    func testArcsQuadraticSingleArc() {
        let epsilon: CGFloat = 0.001
        let r: CGFloat = 100.0
        // q is close to a quarter circle centered at 0,0
        let q = QuadraticBezierCurve(start: r * CGPoint(x: 1.0, y: 0.0),
                                     end:   r * CGPoint(x: 0.0, y: 1.0),
                                     mid:   r * CGPoint(x: sqrt(2) / 2.0, y: sqrt(2) / 2.0),
                                     t: 0.5)
        let result = q.arcs(errorThreshold: r)
        // with a big enough error threshold we should just get back one arc
        let expectedResult = Arc(origin: CGPoint(x: 0.0, y: 0.0),
            radius: 100.0,
            startAngle: 0.0,
            endAngle: CGFloat.pi / 2.0,
            interval: Interval(start: 0.0, end: 1.0)
        )
        XCTAssertEqual(result.count, 1)
        XCTAssert((result[0].origin - expectedResult.origin).length < epsilon)
        XCTAssertEqual(result[0].radius, expectedResult.radius, accuracy: epsilon)
        XCTAssertEqual(result[0].startAngle, expectedResult.startAngle, accuracy: epsilon)
        XCTAssertEqual(result[0].endAngle, expectedResult.endAngle, accuracy: epsilon)
        XCTAssertEqual(result[0].interval, expectedResult.interval)
        // just for good measure test that it passes the good approximation test
        XCTAssert(isGoodApproximation(arcs: result, curve: q, accuracy: r))
    }
    
    func testArcsCubicMultipleArcs() {
        // c is just an arc that goes up and comes down
        let c = CubicBezierCurve(p0: CGPoint(x: 0.0, y: 0.0),
                                 p1: CGPoint(x: 0.0, y: 1.0),
                                 p2: CGPoint(x: 4.0, y: 1.0),
                                 p3: CGPoint(x: 4.0, y: 0.0))
        let errorThreshold: CGFloat = 0.01
        let result = c.arcs(errorThreshold: errorThreshold)
        XCTAssert(isGoodApproximation(arcs: result, curve: c, accuracy: errorThreshold))
    }
    
}
