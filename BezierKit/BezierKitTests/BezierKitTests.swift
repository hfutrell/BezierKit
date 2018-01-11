//
//  BezierKitTests.swift
//  BezierKitTests
//
//  Created by Holmes Futrell on 10/28/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import XCTest
@testable import BezierKit

class BezierKitTests: XCTestCase {
    
    static internal func intersections(_ intersections: [Intersection], betweenCurve c1: BezierCurve, andOtherCurve c2: BezierCurve, areWithinTolerance epsilon: BKFloat) -> Bool {
        for i in intersections {
            let p1 = c1.compute(i.t1)
            let p2 = c2.compute(i.t2)
            if (p1 - p2).length > epsilon {
                return false
            }
        }
        return true
    }
    
    static internal func curveControlPointsEqual(curve1 c1: BezierCurve, curve2 c2: BezierCurve, accuracy epsilon: BKFloat) -> Bool {
        if c1.order != c2.order {
            return false
        }
        for i in 0...c1.order {
            if (c1.points[i] - c2.points[i]).length > epsilon {
                return false
            }
        }
        return true
    }
    
    static internal func curve(_ c1: BezierCurve, matchesCurve c2: BezierCurve, overInterval interval: Interval, accuracy: BKFloat) -> Bool {
        // checks if c1 over [0, 1] matches c2 over [interval.start, interval.end]
        // useful for checking if splitting a curve over a given interval worked correctly
        let numPointsToCheck = 10
        for i in 0..<numPointsToCheck {
            let t1 = BKFloat(i) / BKFloat(numPointsToCheck-1)
            let t2 = interval.start * (1.0 - t1) + interval.end * t1
            if (distance(c1.compute(t1), c2.compute(t2)) > accuracy) {
                return false
            }
        }
        return true
    }
    
    private static func evaluatePolynomial(_ p: [BKFloat], at t: BKFloat) -> BKFloat {
        var sum: BKFloat = 0.0
        for n in 0..<p.count {
            sum += p[p.count - n - 1] * pow(t, BKFloat(n))
        }
        return sum
    }

    static func cubicBezierCurveFromPolynomials(_ f: [BKFloat], _ g: [BKFloat]) -> CubicBezierCurve {
        precondition(f.count == 4 && g.count == 4)
        // create a cubic bezier curve from two polynomials
        // the first polynomial f[0] t^3 + f[1] t^2 + f[2] t + f[3] defines x(t) for the Bezier curve
        // the second polynomial g[0] t^3 + g[1] t^2 + g[2] t + g[3] defines y(t) for the Bezier curve
        let p = BKPoint(x: f[0], y: g[0])
        let q = BKPoint(x: f[1], y: g[1])
        let r = BKPoint(x: f[2], y: g[2])
        let s = BKPoint(x: f[3], y: g[3])
        let a = s
        let b = r / 3.0 + a
        let c = q / 3.0 + 2.0 * b - a
        let d = p + a - 3.0 * b + 3.0 * c
        // check that it worked
        let curve = CubicBezierCurve(p0: a, p1: b, p2: c, p3: d)
        for t: BKFloat in stride(from: 0, through: 1, by: 0.1) {
            assert(distance(curve.compute(t), BKPoint(x: evaluatePolynomial(f, at: t), y: evaluatePolynomial(g, at: t))) < 0.001, "internal error! failed to fit polynomial!")
        }
        return curve
    }
    
//    static func quadraticBezierCurveFromPolynomials(_ f: [BKFloat], _ g: [BKFloat]) -> QuadraticBezierCurve {
//        precondition(f.count == 3 && g.count == 3)
//        // create a quadratic bezier curve from two polynomials
//        // the first polynomial f[0] t^2 + f[1] t + f[2] defines x(t) for the Bezier curve
//        // the second polynomial g[0] t^2 + g[1] t + g[2] defines y(t) for the Bezier curve
//        let q = BKPoint(x: f[0], y: g[0])
//        let r = BKPoint(x: f[1], y: g[1])
//        let s = BKPoint(x: f[2], y: g[2])
//        let a = s
//        let b = r / 3.0 + a
//        let c = q / 3.0 + 2.0 * b - a
//        // check that it worked
//        let curve = QuadraticBezierCurve(p0: a, p1: b, p2: c)
//        for t: BKFloat in stride(from: 0, through: 1, by: 0.1) {
//            assert(distance(curve.compute(t), BKPoint(x: evaluatePolynomial(f, at: t), y: evaluatePolynomial(g, at: t))) < 0.001, "internal error! failed to fit polynomial!")
//        }
//        return curve
//    }
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
//    func testExample() {
//        // This is an example of a functional test case.
//        // Use XCTAssert and related functions to verify your tests produce the correct results.
//    }
//    
//    func testPerformanceExample() {
//        // This is an example of a performance test case.
//        self.measure {
//            // Put the code you want to measure the time of here.
//        }
//    }
    
}
